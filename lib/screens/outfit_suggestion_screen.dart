// ignore_for_file: deprecated_member_use
import 'dart:ui'; //visual effects
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:outfit_app/screens/edit_profile_screen.dart';
import 'package:outfit_app/screens/meet_sunny_page.dart';
import 'package:outfit_app/screens/previous_outfits_screen.dart';
import 'package:outfit_app/screens/favorites_screen.dart';
import 'package:outfit_app/services/voice_service.dart'; 
import '../services/stylist_ai_service.dart'; 
import '../services/outfit_engine.dart';
import '../widgets/weather_background.dart';
import '../widgets/avatar_builder.dart';
import '../services/weather_service.dart';
import '../services/ml_service.dart';
import '../screens/welcome_screen.dart';
import '../services/background_audio_service.dart';


class OutfitSuggestionScreen extends StatefulWidget {
  const OutfitSuggestionScreen({super.key});
  @override
  State<OutfitSuggestionScreen> createState() => _OutfitSuggestionScreenState();
}

class _OutfitSuggestionScreenState extends State<OutfitSuggestionScreen> with WidgetsBindingObserver{
  final StylistAIService _aiService = StylistAIService(); 
  final WeatherService _weatherService = WeatherService();
  final MlService _mlService = MlService();
  final OutfitEngine _outfitEngine = OutfitEngine();
  final TextEditingController _textController = TextEditingController();
  final VoiceService _voiceService = VoiceService();

  int currentStep = 1; 
  String? selectedActivity;
  List<String> selectedUserItems = [];
  String? gender;
  String? userName;
  String? displayCity; 
  Map<String, dynamic>? weatherFeatures;
  int? weatherLayer;
  bool isAwaitingDelayedFeedback = false; 
  
  // Audio State
  bool isVoiceMuted = false;
  bool isMusicMuted = false;

  bool isHijabi = false;
  int _layerIndex = 1; // 0=Base, 1=Top, 2=Outerwear

  String _baseMsg = "";
  String _mainMsg = "";
  String _outerMsg = "";
  bool _isViewingLayers = true;

  Map<String, String> currentOutfit = {"top": "hoodie", "bottom": "jeans", "shoes": "sneakers"};
  String avatarMessage = "Where are you going today?";
  bool isLoading = false;
  bool showFeedbackButtons = false;

 @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); 
    BackgroundAudioService().start();
    _loadInitialData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); 
    _voiceService.stop();
    _textController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      BackgroundAudioService().stop(); 
    } else if (state == AppLifecycleState.resumed) {
      if (!isMusicMuted) {
        BackgroundAudioService().start();
      }
    }
  }

  // Helper for voice triggers to respect mute state
  void _speakIfAllowed(String text) {
    if (!isVoiceMuted) {
      _voiceService.speak(text);
    }
  }

Future<void> _loadInitialData() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final doc = await FirebaseFirestore.instance
      .collection("user_preferences")
      .doc(user.uid)
      .get();
  
  final data = doc.data() ?? {};

  bool needsFeedback = data["has_pending_feedback"] == true;
  final String savedCity = data["city"] ?? "London";
  final String savedCountryCode = data["countryCode"] ?? "GB";

  final locationData = await _weatherService.getLocationCoords(savedCity, savedCountryCode);
  
  if (locationData != null) {
    final rawWeather = await _weatherService.fetchWeather(
      lat: locationData['lat'], 
      lon: locationData['lon']
    );
    weatherFeatures = _weatherService.extractWeatherFeatures(rawWeather);
    
    // Force "allergies" to true for demo
    //data["allergies"] = "yes";

    // ==========================================
    // 1. CALCULATE FEATURES (MOVED UP)
    // ==========================================
    String cSens = (data['cold_sensitivity'] ?? 'no').toString().toLowerCase();
    int coldSense = 0;
    if (cSens.contains('lot') || cSens == 'high') coldSense = 2;
    else if (cSens.contains('bit') || cSens == 'low') coldSense = 1;

    String hSens = (data['heat_sensitivity'] ?? 'no').toString().toLowerCase();
    int heatSense = 0;
    if (hSens.contains('lot') || hSens == 'high') heatSense = 2;
    else if (hSens.contains('bit') || hSens == 'low') heatSense = 1;

    double temp = (weatherFeatures?['temp'] as num? ?? 15).toDouble();
    double wind = (weatherFeatures?['wind'] as num? ?? 10).toDouble();
    double humidity = (weatherFeatures?['humidity'] as num? ?? 50).toDouble();

    // Calculate Perceived Temp (pTemp) HERE so we can send it to ML
    double pTemp = temp;
    if (wind > 10 && temp < 20) pTemp -= (wind / 5);
    if (humidity > 70 && temp > 20) pTemp += (humidity - 70) / 5;
    
    // ==========================================
    // 2. TRY ML SERVICE (With Corrected Input)
    // ==========================================
    try {
      debugPrint("🤖 Calling ML Service...");
      
      // ✅ FIX: Construct the Exact Map the Model Expects
      final Map<String, dynamic> mlInput = {
        "perceived_temp": pTemp,      // Calculated above
        "temp": temp,
        "wind": wind,
        "humidity": humidity,
        "rain": weatherFeatures!['rain'] ?? 0,
        "sensitivity": coldSense - heatSense, // Net sensitivity
        "rain_type": weatherFeatures!['condition'] ?? "clear",
      };

      // Pass the FORMATTED mlInput, not the raw weatherFeatures
      int? predictedLayer = await _mlService.predictLayer(mlInput);
      
      if (predictedLayer != null) {
        weatherLayer = predictedLayer;
        debugPrint("✅ ML SUCCESS: Model chose Layer $weatherLayer");
      }
    } catch (e) {
      debugPrint("❌ ML ERROR: $e");
      // Don't crash, just continue to fallback logic below
    }

    // ==========================================
    // 3. FALLBACK LOGIC (Runs if ML failed)
    // ==========================================
    if (weatherLayer == null) {
        debugPrint("⚠️ ML FAILED/SKIPPED. USING MANUAL LOGIC.");
        
        // Add sensitivity to pTemp for manual logic
        double manualPTemp = pTemp - (coldSense * 2) + (heatSense * 2);
        
        if (manualPTemp < 5) weatherLayer = 5;      
        else if (manualPTemp < 12) weatherLayer = 4; 
        else if (manualPTemp < 18) weatherLayer = 3; 
        else if (manualPTemp < 25) weatherLayer = 2; 
        else weatherLayer = 1;               
    }
  }

  if (!mounted) return;

  setState(() {
    gender = (data["gender"] ?? "female").toString().toLowerCase().trim();
    userName = data["name"] ?? "User";
    String hijabVal = data["hijab"]?.toString().toLowerCase() ?? "no";
    isHijabi = (hijabVal == "yes");
    
    if (needsFeedback) {
      isAwaitingDelayedFeedback = true;
      avatarMessage = "Welcome back! How did the outfit I picked for you earlier feel?";
    } else {
      avatarMessage = "Where are you going today?";
    }

    if (data["last_outfit"] != null) {
      currentOutfit = Map<String, String>.from(data["last_outfit"]);
    }
  });

  _speakIfAllowed(avatarMessage);
  
  if (gender != null) {
    await _outfitEngine.loadForUserGender(gender!);
  }
}
  
  
  Future<void> _handleSend() async {
    
    final input = _textController.text.trim();
    if (input.isEmpty || isLoading) return;
    debugPrint("USER INPUT: \"$input\"");

    setState(() => isLoading = true);
    _textController.clear();

    if (currentStep == 1) {
      await _processActivityStep(input);
    } else {
      await _processItemStep(input);
    }
  }

 Future<void> _processActivityStep(String input) async {
    final validation = await _aiService.sendValidatedMessage(
      question: "Where are you going?", 
      userAnswer: input, 
      type: "outfit_plan"
    );
    
    if (!mounted) return;

    if (validation["valid"] != true) {
      setState(() { 
        avatarMessage = validation["retry"] ?? "Tell me more!"; 
        isLoading = false; 
      });
      _speakIfAllowed(avatarMessage); 
      return;
    }

    String logicKey = validation["value"] is Map ? validation["value"]["activity"] : validation["value"];
    String displayLabel = validation["label"] ?? logicKey;

    setState(() {
      selectedActivity = logicKey; 
      currentStep = 2;
      avatarMessage = "Got it, styling you for your $displayLabel! Is there a specific item you'd like to wear?";
      isLoading = false;
    });

    _speakIfAllowed(avatarMessage); 
  }

 Future<void> _processItemStep(String input) async {

  debugPrint("🗣️ USER ITEM INPUT (raw text): \"$input\"");

  
  if (!input.toLowerCase().contains("no") && !input.toLowerCase().contains("nothing")) {
    
    final itemVal = await _aiService.sendValidatedMessage(
      question: "What to wear?", 
      userAnswer: input, 
      type: "item_extraction"
    );

    debugPrint("🤖 AI EXTRACTION RESULT:");
    debugPrint("   valid: ${itemVal['valid']}");
    debugPrint("   value: ${itemVal['value']}");
    debugPrint("   label: ${itemVal['label']}");

    if (itemVal["valid"] == true) {
      selectedUserItems = itemVal["value"] is List 
          ? List<String>.from(itemVal["value"]) 
          : [itemVal["value"].toString()];
    }
     debugPrint("🧺 USER REQUESTED ITEMS (final): $selectedUserItems");
  }

  final uid = FirebaseAuth.instance.currentUser!.uid;
  final doc = await FirebaseFirestore.instance.collection("user_preferences").doc(uid).get();
  
  double mlOffset = 0.0;
  final offsets = Map<String, dynamic>.from((doc.data()?['comfort_offsets'] ?? {'default': 0.0}));
  String contextKey = "default";
  if ((weatherFeatures?['wind'] ?? 0) > 15) contextKey = "windy";
  mlOffset = (offsets[contextKey] ?? 0.0).toDouble();

  
final result = _outfitEngine.generateSmartOutfit(
    profile: doc.data() ?? {}, 
    weatherLayer: weatherLayer ?? 1,
    event: selectedActivity ?? "casual", 
    userItems: selectedUserItems, 
    weatherData: weatherFeatures ?? {},
    mlOffset: mlOffset, 
);

  final generated = result["outfit"] as Map<String, dynamic>;
  final List<String> accs =
    List<String>.from(generated["accessories"] ?? []);
  
  String outerName = generated["outerwear"]?.toString().replaceAll("_", " ") ?? "jacket";
  String sockName = generated["socks"]?.toString() ?? "socks";
  
  String healthAdvice = generated['reasoning']?.toString() ?? "";
    if (healthAdvice.contains("mask") || healthAdvice.contains("allergies")) {
       avatarMessage = healthAdvice; // Show only the mask reminder
    } else {
       avatarMessage = "I've generated your outfit! Press the buttons to see all the layers. ✨";
    }

  List<String> baseItems = [];
  if (generated["base_top"] != null && generated["base_top"].toString().isNotEmpty) {
    baseItems.add(generated["base_top"].toString().replaceAll("_", " "));
  }
  if (generated["base_bottom"] != null && generated["base_bottom"].toString().isNotEmpty) {
    baseItems.add(generated["base_bottom"].toString().replaceAll("_", " "));
  }
  
  if (baseItems.isNotEmpty) {
    _baseMsg = "I suggested a ${baseItems.join(' and ')} for extra warmth, plus $sockName! 🌡️";
  } else {
    _baseMsg = "No extra base layers needed, but don't forget your $sockName! 🧦";
  }

  if (generated["outerwear"] != null && generated["outerwear"].toString().isNotEmpty) {
    _outerMsg = "I suggested to take a $outerName with you for the commute. You can take it off indoors! 🧥";
  } else {
    _outerMsg = "No jacket needed right now.";
  }

  bool isColdSensitive = (doc.data()?['cold_sensitivity'] ?? '').toString().contains('yes');
  String initialMsg = isColdSensitive 
      ? "Since you are sensitive to cold, I've added extra layers for you! ❄️ Use the buttons to see."
      : "Here is a look styled for your $selectedActivity! ✨";

// 🎯 REJECTION UI MESSAGE (if any)
if (generated["rejectedItem"] != null && generated["reason"] != null) {
  final rejected =
      generated["rejectedItem"].toString().replaceAll("_", " ");
  final reason = generated["reason"].toString();

  initialMsg =
      "I know you wanted to wear $rejected, but $reason 😊 "
      "So I picked the best alternative for you instead.";
}



  if (!mounted) return;

  setState(() {
    currentOutfit = {
      "base_top": generated["base_top"]?.toString() ?? "", 
      "top": generated["top"]?.toString() ?? "hoodie",
      "outerwear": generated["outerwear"]?.toString() ?? "", 
      "base_bottom": generated["base_bottom"]?.toString() ?? "", 
      "bottom": generated["bottom"]?.toString() ?? "jeans",
      "shoes": generated["shoes"]?.toString() ?? "sneakers",
      
      "socks": "socks", 
      "sock_label": generated["socks"]?.toString() ?? "socks", // For speech
      
      "mask": accs.contains("mask") || accs.contains("mask_hijabi") ? (isHijabi ? "mask_hijabi" : "mask") : "",
      "beanie": accs.contains("beanie_hijabi") ? "beanie_hijabi" : (accs.contains("beanie") ? "beanie" : ""),
      "scarf": accs.contains("scarf_hijabi") ? "scarf_hijabi" : (accs.contains("scarf") ? "scarf" : ""),
     "sunglasses": accs.firstWhere((a) => a.contains("glasses"), orElse: () => ""), };

    String extraAdvice = generated['reasoning']?.toString() ?? "";
    avatarMessage = "$initialMsg $extraAdvice";

    currentStep = 1; 
    isLoading = false;
    showFeedbackButtons = true; 
    _isViewingLayers = true;
    _layerIndex = 1; 
  });

  await FirebaseFirestore.instance.collection('outfit_history').add({
    'userId': uid,
    'timestamp': FieldValue.serverTimestamp(),
    'outfit': currentOutfit,
    'gender': gender,
    'activity': selectedActivity,
  });

  await FirebaseFirestore.instance.collection("user_preferences").doc(uid).set({
    "last_outfit": currentOutfit
  }, SetOptions(merge: true));

  _speakIfAllowed(avatarMessage);
}

 Future<void> _handleThermalFeedback(String type) async {
  setState(() => isLoading = true);
  final uid = FirebaseAuth.instance.currentUser!.uid;
  final docRef = FirebaseFirestore.instance.collection("user_preferences").doc(uid);
  final snapshot = await docRef.get();
  final data = snapshot.data() ?? {};

  String contextKey = "default";
  if ((weatherFeatures?['wind'] ?? 0) > 15) contextKey = "windy";

  int count = data['comfort_feedback_count'] ?? 0;
  double step = 0.85;
  Map<String, dynamic> offsets = Map<String, dynamic>.from(data['comfort_offsets'] ?? {"default": 0.0});
  double currentOffset = (offsets[contextKey] ?? 0.0).toDouble();

  // 1. Only adjust offsets if it was uncomfortable
  if (type == "too_cold") currentOffset += step;
  else if (type == "too_hot") currentOffset -= step;

  offsets[contextKey] = currentOffset;

  // 2. Update Firebase
  await docRef.update({
    "comfort_offsets": offsets,
    "comfort_feedback_count": count + 1,
    "has_pending_feedback": false 
  });

  // 3. CHECK IF "PERFECT" WAS SELECTED
  if (type == "just_right") {
    // Stop loading so the UI is responsive
    setState(() => isLoading = false);
    
    // Trigger the Favorite Dialog
    await _handleFavorite();

    // After the dialog closes, update the UI to move on
    if (mounted) {
      setState(() {
        isAwaitingDelayedFeedback = false;
        // If they didn't save it (canceled), show a generic nice message
        if (!avatarMessage.contains("saved")) { 
           avatarMessage = "I'm glad I got it right! Where are you going today?";
        }
      });
    }
  } else {
    // 4. Standard logic for Cold/Hot
    setState(() {
      isAwaitingDelayedFeedback = false;
      avatarMessage = "Got it! I've adjusted my brain for your comfort. 🧠 Where are you going today?";
      isLoading = false;
    });
  }

  _speakIfAllowed(avatarMessage);
}
 
  Widget _feedbackAction(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10), 
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), 
            child: Icon(Icons.touch_app, color: color, size: 20)
          ),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.rubik(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Future<void> _handleFavorite() async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white.withOpacity(0.9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Add to Favorites?", style: GoogleFonts.rubik(fontWeight: FontWeight.w700, color: const Color(0xFF1A4D9E))),
        content: Text("Would you like to save this outfit to your favorites list?", style: GoogleFonts.rubik()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text("Cancel", style: GoogleFonts.rubik(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text("Yes, Save!", style: GoogleFonts.rubik(color: Colors.green, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('favorites').add({
        'userId': FirebaseAuth.instance.currentUser!.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'outfit': currentOutfit,
        'activity': selectedActivity ?? "Casual",
        'gender': gender,
        'temperature': weatherFeatures?['temp'] ?? 0, 
        'isHijabi': isHijabi,
      });
      
      if (!mounted) return;

      setState(() {
        
        avatarMessage = "Outfit saved to your favorites! ❤️ Where are you going today?";
        showFeedbackButtons = false;
        currentStep = 1;
      });
      _speakIfAllowed(avatarMessage);
    }
  }

 Map<String, String> _getVisibleOutfit() {
 
  Map<String, String> visible = Map.from(currentOutfit);

  if (_layerIndex == 2) {
    // 🧥 OUTERWEAR VIEW
    if (currentOutfit["outerwear"]?.isNotEmpty == true) {
      visible["top"] = currentOutfit["outerwear"]!;
    }
    // Remove items that shouldn't show on top of the coat
    visible.remove("socks");
    
    // Add commute accessories
    if (currentOutfit["beanie"] != null) visible["beanie"] = currentOutfit["beanie"]!;
    if (currentOutfit["scarf"] != null) visible["scarf"] = currentOutfit["scarf"]!;
    if (currentOutfit["sunglasses"] != null) visible["sunglasses"] = currentOutfit["sunglasses"]!;
  } 
  else if (_layerIndex == 0) {
    visible.remove("beanie");
    visible.remove("scarf");
    visible.remove("sunglasses");
    // 🌡️ BASE LAYER VIEW
    visible["socks"] = currentOutfit["socks"] ?? ""; // Show socks here
    visible.remove("shoes"); // Hide shoes to see the socks
    
    if (currentOutfit["base_top"]?.isNotEmpty == true) {
      visible["top"] = currentOutfit["base_top"]!;
    }
    if (currentOutfit["base_bottom"]?.isNotEmpty == true) {
      visible["bottom"] = currentOutfit["base_bottom"]!;
    }
  } 
  else {
    visible.remove("beanie");
    visible.remove("scarf");
    visible.remove("sunglasses");
    // 👕 MAIN OUTFIT VIEW (Layer 1)
    visible["top"] = currentOutfit["top"]!;
    // 🔥 CRITICAL: Remove socks so they don't peek out under the jeans
    visible.remove("socks"); 
  }
  
  return visible;
}
 void _changeLayer(int delta) {
    int newIndex = _layerIndex + delta;
    if (newIndex < 0 || newIndex > 2) return;

//layer
    setState(() {
      _layerIndex = newIndex;
      
       if (_layerIndex == 0) {
        // 🌡️ BASE LAYER
        // Use 'sock_label' for text (says "wool sock"), but Avatar uses 'socks' (loads socks.png)
        String sockLabel = currentOutfit["sock_label"]?.replaceAll('_', ' ') ?? "socks";
        String baseTop = currentOutfit["base_top"] ?? "";
        
        _baseMsg = "Don't forget your $sockLabel for extra warmth! 🧦";
        if (baseTop.isNotEmpty) {
          _baseMsg = "I added a ${baseTop.replaceAll('_', ' ')} and $sockLabel for maximum insulation. 🌡️";
        }
        avatarMessage = _baseMsg;
      }
     else if (_layerIndex == 1) {
        // 👕 MAIN LAYER: UPDATE THIS PART 👇
        
        // 1. Get clean names for the items
        String top = currentOutfit["top"]?.replaceAll("_", " ") ?? "top";
        String bottom = currentOutfit["bottom"]?.replaceAll("_", " ") ?? "bottom";
        String shoes = currentOutfit["shoes"]?.replaceAll("_", " ") ?? "shoes";

        // 2. Update the message to describe the pieces
        _mainMsg = "For the main look, I've styled a $top with $bottom and $shoes! ✨";
        avatarMessage = _mainMsg;
      }
      else if (_layerIndex == 2) {
        // 🧥 OUTER LAYER: Jackets plus Accessories (Sunglasses/Beanie/Scarf)
        String outer = currentOutfit["outerwear"] ?? "";
        List<String> extras = [];
        if (currentOutfit["beanie"]?.isNotEmpty == true) extras.add("beanie");
        if (currentOutfit["scarf"]?.isNotEmpty == true) extras.add("scarf");
        if (currentOutfit["sunglasses"]?.isNotEmpty == true) extras.add("sunglasses");

        if (outer.isNotEmpty) {
          _outerMsg = "Don't forget your ${outer.replaceAll('_', ' ')} for the commute! 🧥";
          if (extras.isNotEmpty) _outerMsg += " Plus your ${extras.join(' and ')}.";
        } else {
          _outerMsg = extras.isNotEmpty 
              ? "Take your ${extras.join(' and ')} for protection outdoors! 🕶️"
              : "No outer layers needed right now.";
        }
        avatarMessage = _outerMsg;
      }
    });
    
    _speakIfAllowed(avatarMessage);
}
  void _finishViewing() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance.collection("user_preferences").doc(uid).update({
      "has_pending_feedback": true
    });

    setState(() {
      _isViewingLayers = false; 
      avatarMessage = "Enjoy your day! I'll check back with you later to see how the outfit felt. ☀️";
      showFeedbackButtons = false;
      _layerIndex = 1; 
    });
    _speakIfAllowed(avatarMessage);
  }


//DRAWER 
  @override
  Widget build(BuildContext context) {
    if (gender == null || weatherLayer == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    
    return Scaffold(
      drawer: _buildDrawer(context),
      body: WeatherBackground(
       condition: weatherFeatures?['condition']?.toString().toLowerCase() ?? "clear",
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                _buildOutfitContent(context, constraints.maxHeight),

                // 2. Menu Button (Top Left)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 3,
                  left: 30,
                  child: Builder(
                    builder: (context) => Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFA89357).withOpacity(0.9),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.menu_rounded),
                        color: Colors.black.withOpacity(0.6),
                        onPressed: () => Scaffold.of(context).openDrawer(),
                      ),
                    ),
                  ),
                ),

                // 3. City Tag & Audio Controls (Top Right)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 12,
                  right: 30,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (displayCity != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_on_rounded, size: 14, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                displayCity!,
                                style: GoogleFonts.rubik(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _smallAudioButton(
                            icon: isVoiceMuted ? Icons.volume_off_rounded : Icons.record_voice_over_rounded,
                            isMuted: isVoiceMuted,
                            onTap: () {
                              setState(() => isVoiceMuted = !isVoiceMuted);
                              if (isVoiceMuted) _voiceService.stop();
                            },
                          ),
                          const SizedBox(width: 8),
                          _smallAudioButton(
                            icon: isMusicMuted ? Icons.music_off_rounded : Icons.music_note_rounded,
                            isMuted: isMusicMuted,
                            onTap: () {
                              setState(() => isMusicMuted = !isMusicMuted);
                              if (isMusicMuted) {
                                BackgroundAudioService().stop();
                              } else {
                                BackgroundAudioService().start();
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
        ),
      ),
    );
  }



  Widget _buildOutfitContent(BuildContext context, double maxHeight) {
   bool canGoUp = _layerIndex < 2;
   bool canGoDown = _layerIndex > 0;

    return Stack(
      children: [
        Positioned.fill(
          child: Align(
            alignment: const Alignment(0.0, -0.15),
            child: AvatarBuilder.build(
              gender: gender!, 
              outfit: _getVisibleOutfit(), 
              height: maxHeight * 0.55, 
              offsetY: 0, 
              isHijabi: isHijabi,
            ),
          ),
        ),

        Positioned(
          top: MediaQuery.of(context).padding.top + 70, 
          left: 0, 
          right: 0,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.70), 
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: Colors.white.withOpacity(0.4)),
                      ),
                      child: Text(
                        avatarMessage, 
                        textAlign: TextAlign.center, 
                        style: GoogleFonts.rubik(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
                      ),
                    ),
                  ),
                ),
                CustomPaint(size: const Size(20, 12), painter: SpeechBubbleTriangleDown()),
              ],
            ),
          ),
        ),

        if (showFeedbackButtons)
          Positioned(
            bottom: 115, 
            left: 30,
            right: 30,
            child: _isViewingLayers
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end, 
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _layerButton(Icons.arrow_upward_rounded, canGoUp, () => _changeLayer(1)),
                        const SizedBox(height: 10),
                        Text(
                          _layerIndex == 2 ? "Outer" : (_layerIndex == 0 ? "Base" : "Main"),
                          style: GoogleFonts.rubik(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12, shadows: [BoxShadow(color: Colors.black26, blurRadius: 4)])
                        ),
                        const SizedBox(height: 10),
                        _layerButton(Icons.arrow_downward_rounded, canGoDown, () => _changeLayer(-1)),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: _finishViewing,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.95),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        elevation: 5,
                      ),
                      child: Text("Done", style: GoogleFonts.rubik(color: Colors.black87, fontWeight: FontWeight.bold)),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _feedbackButton(Icons.thumb_down_rounded, Colors.redAccent, () {
                      setState(() => showFeedbackButtons = false);
                    }),
                    const SizedBox(width: 40),
                    _feedbackButton(Icons.thumb_up_rounded, Colors.greenAccent, _handleFavorite),
                  ],
                ),
          ),

        if (isAwaitingDelayedFeedback)
          Positioned(
            bottom: 120, 
            left: 30, right: 30,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _feedbackAction("Too Cold 🥶", Colors.blue, () => _handleThermalFeedback("too_cold")),
                      _feedbackAction("Perfect 👍", Colors.green, () => _handleThermalFeedback("just_right")),
                      _feedbackAction("Too Hot 🔥", Colors.orange, () => _handleThermalFeedback("too_hot")),
                    ],
                  ),
                ),
              ),
            ),
          ),

        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildInputField(),
        ),
      ],
    );
  }

  Widget _layerButton(IconData icon, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12), 
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFF8D6E63) : Colors.brown.withOpacity(0.3), 
          shape: BoxShape.circle,
          boxShadow: enabled ? [BoxShadow(color: Colors.black38, blurRadius: 6, offset: const Offset(0, 3))] : [],
          border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
        ),
        child: Icon(icon, size: 24, color: Colors.white), 
      ),
    );
  }

  Widget _feedbackButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Icon(icon, color: color, size: 28),
      ),
    );
  }

  Widget _buildInputField() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFB8A675).withOpacity(0.8), 
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Row(children: [
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _textController, 
                style: GoogleFonts.rubik(fontSize: 16, color: Colors.black87),
                decoration: InputDecoration(
                  hintText: "Let's generate an outfit...", 
                  hintStyle: GoogleFonts.rubik(color: Colors.black54, fontSize: 15),
                  border: InputBorder.none,
                ),
              ),
            ),
            isLoading 
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)),
                )
              : Container(
                  margin: const EdgeInsets.only(right: 4),
                  decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_upward_rounded, size: 22), 
                    color: Colors.black,
                    onPressed: _handleSend,
                  ),
                ),
          ]),
        ),
      ),
    ),
  );

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFFB3E5FC), 
      child: Stack(
        children: [
          Positioned(top: 30, right: 20, child: Opacity(opacity: 0.8, child: Image.asset("assets/images/Suggestion_bg/night_bg/star1.png", width: 45))),
          Positioned(top: 150, left: 10, child: Opacity(opacity: 0.7, child: Image.asset("assets/images/Suggestion_bg/night_bg/star1.png", width: 35))),
          Positioned(top: 300, right: 40, child: Opacity(opacity: 0.6, child: Image.asset("assets/images/Suggestion_bg/night_bg/star1.png", width: 30))),
          Positioned(top: 80, right: -80, child: Opacity(opacity: 0.5, child: Image.asset("assets/images/smallcloud1.png", width: 220))),
          Positioned(bottom: 140, left: 110, child: Opacity(opacity: 0.6, child: Image.asset("assets/images/smallcloud1.png", width: 200))),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 30),
                _buildAvatarHeader(), 
                const SizedBox(height: 30),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _section("Style & Preferences"),
                        _item(
                          "Edit Profile", 
                          icon: Icons.person_outline_rounded, 
                          onTap: () async {
                            Navigator.pop(context); 
                            final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => EditProfileScreen()));
                            if (result == true) _loadInitialData();
                          }
                        ),
                        _item(
                          "Update Style Questions", 
                          icon: Icons.quiz_outlined, 
                          onTap: () {
                            Navigator.pop(context); 
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const MeetSunnyPage(isUpdate: true)));
                          }
                        ),
                        Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: _divider()),
                        _section("Outfit History"),
                        _item(
                          "Previous Outfits", 
                          icon: Icons.history_rounded, 
                          onTap: () {
                            Navigator.pop(context); 
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const PreviousOutfitsScreen()));
                          }
                        ),
                        _item(
                          "Saved / Favorites", 
                          icon: Icons.favorite_border_rounded,
                          onTap: () {
                            Navigator.pop(context); 
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const FavoritesScreen()));
                          }
                        ),
                      ],
                    ),
                  ),
                ),
                _divider(),
                _item(
                  "Logout", 
                  danger: true, 
                  icon: Icons.logout_rounded, 
                  onTap: () async {
                    await BackgroundAudioService().stop();
                    await FirebaseAuth.instance.signOut();
                    if (!mounted) return;
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                      (route) => false,
                    );
                  }
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarHeader() {
    return Column(
      children: [
        Container(
          width: 110, height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFFF59D), 
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: [BoxShadow(color: const Color(0xFFFBC02D).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 4))],
          ),
          child: ClipOval(
            child: Align(
              alignment: Alignment.topCenter,
              child: AvatarBuilder.build(
                gender: gender ?? "female", 
                outfit: {}, 
                height: 250, 
                offsetY: 10,
                isHijabi: isHijabi,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(userName?.toLowerCase() ?? "user", style: GoogleFonts.rubik(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF1A4D9E))),
      ],
    );
  }

  Widget _item(String text, {IconData? icon, bool danger = false, VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: danger ? Colors.redAccent : const Color(0xFF1A4D9E).withOpacity(0.7), size: 22),
      title: Text(text, style: GoogleFonts.rubik(color: danger ? Colors.redAccent : Colors.black87, fontWeight: FontWeight.w500, fontSize: 15)),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
    );
  }

  Widget _section(String text) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    child: Align(alignment: Alignment.centerLeft, child: Text(text, style: GoogleFonts.rubik(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black.withOpacity(0.6)))),
  );

  Widget _divider() => Divider(color: Colors.black.withOpacity(0.1), indent: 20, endIndent: 20);

  // --- Audio Control Helper Method ---
  Widget _smallAudioButton({required IconData icon, required bool isMuted, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isMuted ? Colors.redAccent.withOpacity(0.6) : Colors.white.withOpacity(0.2),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Icon(icon, size: 16, color: Colors.white),
      ),
    );
  }
}

class SpeechBubbleTriangleDown extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.70); 
    final path = Path();
    path.moveTo(0, 0); 
    path.lineTo(size.width, 0); 
    path.lineTo(size.width / 2, size.height); 
    path.close();
    canvas.drawPath(path, paint);
  }
  @override
 bool shouldRepaint(CustomPainter oldDelegate) => false;

}