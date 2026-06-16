// ignore_for_file: deprecated_member_use
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:outfit_app/services/weather_service.dart';
import '../services/openai_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:country_picker/country_picker.dart'; 
import '../screens/outfit_suggestion_screen.dart';
import 'main_navigation_wrapper.dart'; 

class MeetSunnyPage extends StatefulWidget {
  final bool isUpdate;
  const MeetSunnyPage({super.key, this.isUpdate = false});

  @override
  State<MeetSunnyPage> createState() => _MeetSunnyPageState();
}

class _MeetSunnyPageState extends State<MeetSunnyPage> with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final OpenAIService aiService = OpenAIService();
  final WeatherService weatherService = WeatherService();
  late AnimationController _jumpController;

  String sunnyMessage = "Hi! I am Sunny ☀️! Nice to meet you! What’s your name?";
  bool isLoading = false;
  
  // --- LOCAL STATE FOR SPEED ---
  int currentStep = 1;
  String currentUserName = "";

  String selectedCountryName = "Select Country";
  String selectedCountryCode = ""; 
  String selectedCountryEmoji = "🌍";

  @override
  void initState() {
    super.initState();
    _jumpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _loadInitialState();
  }

  // Optimized: Load state once, then manage locally
  Future<void> _loadInitialState() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('user_preferences').doc(user.uid).get();
      if (doc.exists) {
        setState(() {
          currentUserName = doc.data()?['name'] ?? "";
          if (widget.isUpdate) {
             currentStep = 3; 
             sunnyMessage = "Welcome back! Ready to tweak your style profile? How would you describe your clothing style today?";
          } else {
             currentStep = doc.data()?['step'] ?? 1;
             _updateSunnyMessage();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _jumpController.dispose();
    _controller.dispose();
    _cityController.dispose();
    super.dispose();
  }

  // --- QUESTIONS MAP ---
  Map<int, Map<String, dynamic>> questions(String name) {
    return {
      1: {
        "question": "Hi! I am Sunny ☀️! Nice to meet you! What’s your name?",
        "type": "name",
        "field": "name"
      },
      2: {
        "question": "Nice to meet you${name.isNotEmpty ? ', $name' : ''}! What’s your gender?",
        "type": "gender",
        "field": "gender",
        "options": ["Male", "Female"]
      },
      3: {
        "question": "How would you describe your clothing style?",
        "type": "text",
        "field": "style",
        "options": ["Comfy", "Casual", "Formal", "Smart Casual"]
      },
      4: {
        "question": "Do you prefer to dress modestly?",
        "type": "yes_no",
        "field": "modesty",
        "options": ["Yes", "No"]
      },
      5: {
        "question": "And do you wear a hijab? I'll make sure to style it with your look! 🧕",
        "type": "yes_no",
        "field": "hijab",
        "options": ["Yes", "No"]
      },
      6: {
        "question": "What do you do for work?",
        "type": "occupation",
        "field": "occupation"
      },
      7: {
        "question": "In winter, do you tend to feel the cold more than most people?",
        "type": "sensitivity",
        "field": "cold_sensitivity",
        "options": ["No", "Yes"]
      },
      8: {
        "question": "In summer, do you usually find yourself feeling hotter than everyone else?",
        "type": "sensitivity",
        "field": "heat_sensitivity",
        "options": ["No", "Yes"]
      },
      9: {
        "question": "Do you have asthma or allergies?",
        "type": "yes_no",
        "field": "allergies",
        "options": ["Yes", "No"]
      },
      10: {
        "question": "Is there anything you absolutely hate wearing? I'll make sure to leave it out!",
        "type": "text",
        "field": "disliked_items"
      },
    };
  }

  void _setSunnyMessage(String msg) {
    setState(() => sunnyMessage = msg);
  }

  void _updateSunnyMessage() {
    final qMap = questions(currentUserName);
    final nextQ = qMap[currentStep];

    if (nextQ == null) {
      if (widget.isUpdate) {
        _setSunnyMessage("Yay 🎉 I've updated your style profile! Tap the arrow to head back. ☀️👕");
      } else {
        _setSunnyMessage("Yay 🎉 We’re all done! One last thing: Where are you located so I can check the weather? ☀️👕");
      }
    } else {
      _setSunnyMessage(nextQ["question"]!);
    }
  }

  // --- BUTTON HANDLER ---
  // --- BUTTON HANDLER ---
  Future<void> _handleOptionSelection(String uiValue) async {
    if (isLoading) return;
    setState(() => isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final qMap = questions(currentUserName);
      final currentQ = qMap[currentStep];
      if (currentQ == null) return;

      // 1. Map UI to DB Value
      String dbValue = uiValue;
      if (currentQ["field"] == "cold_sensitivity" || currentQ["field"] == "heat_sensitivity") {
        if (uiValue == "No") {
          dbValue = "no";
        } else {
          dbValue = "yes";
        }
      }

      // 2. Determine Next Step & Prepare Data
      int nextStep = currentStep + 1;
      
      // Create a map to hold what we want to save
      Map<String, dynamic> dataToSave = {
        currentQ["field"]!: dbValue,
      };
      
      // Modesty Logic
      if (currentQ["field"] == "modesty") {
        if (dbValue == "No") {
           nextStep = 6; 
           // 🔥 THE FIX: If you say "No" to modesty, we force Hijab to "no"
           dataToSave["hijab"] = "no"; 
        } else {
           final doc = await FirebaseFirestore.instance.collection('user_preferences').doc(user.uid).get();
           String gender = doc.data()?['gender']?.toString().toLowerCase() ?? '';
           if (gender != 'female') nextStep = 6; 
        }
      }

      // Add the next step to the save data
      dataToSave["step"] = nextStep;

      // 3. Save
      // We save the main answer AND the forced "no" for hijab if applicable
      FirebaseFirestore.instance.collection('user_preferences').doc(user.uid).set(
        dataToSave, 
        SetOptions(merge: true)
      );

      // 4. Update Local State
      setState(() {
        if (currentQ["field"] == "name") currentUserName = dbValue;
        currentStep = nextStep;
        isLoading = false;
        _updateSunnyMessage();
      });

    } catch (e) {
      debugPrint("🔴 RED ALERT - API ERROR: $e");
      _setSunnyMessage("Oops! Something went wrong.");
      setState(() => isLoading = false);
    }
  }



  // --- CHAT HANDLER ---
  Future<void> _sendMessage() async {
    final userMessage = _controller.text.trim();
    if (userMessage.isEmpty || isLoading) return;
    setState(() => isLoading = true);
    _controller.clear();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final qMap = questions(currentUserName);
      final currentQ = qMap[currentStep];
      if (currentQ == null) return;

      // --- 🔥 FIX 1: INTERCEPT "NO" ANSWERS ---
      if (currentQ["field"] == "disliked_items") {
        String lower = userMessage.toLowerCase();
        if (lower.contains("no") || lower.contains("nothing") || lower.contains("don't") || lower.contains("none")) {
           int nextStep = currentStep + 1;
           FirebaseFirestore.instance.collection('user_preferences').doc(user.uid).set({
             currentQ["field"]!: "none",
             "step": nextStep,
           }, SetOptions(merge: true));

           setState(() {
             currentStep = nextStep;
             isLoading = false;
             _updateSunnyMessage();
           });
           return; 
        }
      }

      // --- NORMAL FLOW (CALL AI) ---
      final result = await aiService.sendValidatedMessage(
        question: currentQ["question"]!,
        userAnswer: userMessage,
        type: currentQ["type"]!,
      );

      if (result["valid"] != true) {
        String retryHint = result["retry"] ?? "I didn't quite catch that.";
        _setSunnyMessage("$retryHint ${currentQ["question"]}");
        setState(() => isLoading = false);
        return;
      }

      String extractedValue = result["value"].toString();
      int nextStep = currentStep + 1;
      
      FirebaseFirestore.instance.collection('user_preferences').doc(user.uid).set({
        currentQ["field"]!: extractedValue,
        "step": nextStep,
      }, SetOptions(merge: true));

      setState(() {
        if (currentQ["field"] == "name") currentUserName = extractedValue;
        currentStep = nextStep;
        isLoading = false;
        _updateSunnyMessage();
      });

    } catch (e) {
      _setSunnyMessage("My brain froze! ☁️ Try again.");
      setState(() => isLoading = false);
    }
  }

  // --- SAVE & FINISH ---
  Future<void> _saveAndFinish() async {
    if (selectedCountryName == "Select Country" || _cityController.text.isEmpty) {
      _setSunnyMessage("I need both a country and a city to work my magic! 📍");
      return;
    }
    setState(() => isLoading = true); 
    try {
      final isValid = await weatherService.validateCity(
        _cityController.text.trim(), 
        selectedCountryCode
      );
      if (isValid == null) {
        _setSunnyMessage("Hmm, I can't find that city in $selectedCountryName. Check the spelling? 🧐");
        setState(() => isLoading = false);
        return;
      }
      final uid = FirebaseAuth.instance.currentUser!.uid;
      //here save user's anaswer's
      await FirebaseFirestore.instance.collection('user_preferences').doc(uid).update({
        'country': selectedCountryName,
        'countryCode': selectedCountryCode,
        'city': isValid,
        //add the ML initialization  
        'comfort_offsets': {
          'default': 0.0,
          'windy': 0.0,
          'night': 0.0,
        },
        'comfort_feedback_count': 0, 
      });
      await FirebaseFirestore.instance.collection('users').doc(uid).update({'hasSeenMeetSunny': true});
      
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainNavigationWrapper()));
      }
    } catch (e) {
      _setSunnyMessage("My weather sensor is acting up! Try again. ☁️");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }






  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final w = MediaQuery.of(context).size.width;
    
    final qMap = questions(currentUserName);
    final currentQ = qMap[currentStep];
    bool isFinished = currentQ == null;

    bool isFinishedSetup = isFinished && !widget.isUpdate;
    bool isFinishedUpdate = isFinished && widget.isUpdate;

    // Detect if Keyboard is open
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardOpen = keyboardHeight > 0;

    // Check if we are showing buttons or text input
    final bool isButtonMode = currentQ != null && currentQ.containsKey("options");

    return Scaffold(
      resizeToAvoidBottomInset: true, 
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(image: AssetImage('assets/images/closet_bg.png'), fit: BoxFit.cover),
            ),
          ),
          
          if (widget.isUpdate)
            Positioned(top: MediaQuery.of(context).padding.top + 10, left: 20, child: _buildHeaderButton(Icons.arrow_back_ios_new_rounded, () => Navigator.pop(context))),

          Positioned(top: MediaQuery.of(context).padding.top + 10, left: widget.isUpdate ? 80 : 20, child: _buildHeaderButton(Icons.refresh, () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                await FirebaseFirestore.instance.collection('user_preferences').doc(user.uid).delete();
                setState(() {
                  currentStep = 1;
                  currentUserName = "";
                  sunnyMessage = "Hi! ☀️ I am Sunny! Nice to meet you! What’s your name?";
                });
              }
          })),

          // Next Arrow Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 20,
            child: AnimatedBuilder(
              animation: _jumpController,
              builder: (context, child) {
                double offset = (isFinishedSetup || isFinishedUpdate) ? (_jumpController.value * 10) : 0;
                return Transform.translate(offset: Offset(0, -offset), child: child);
              },
              child: GestureDetector(
                onTap: () async {
                  if (isFinishedUpdate) {
                     // 🔥🔥 CRITICAL FIX: SEND TO WRAPPER, NOT SINGLE SCREEN 🔥🔥
                     Navigator.pushAndRemoveUntil(
                       context, 
                       MaterialPageRoute(builder: (_) => const MainNavigationWrapper()), 
                       (route) => false
                     );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: (isFinishedSetup || isFinishedUpdate) ? const LinearGradient(colors: [Color(0xFFFF9800), Color(0xFFFF5722)]) : null,
                    color: (isFinishedSetup || isFinishedUpdate) ? null : Colors.black.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 24),
                ),
              ),
            ),
          ),

          Stack(
            alignment: Alignment.center,
            children: [
              Positioned(top: h * 0.36, child: Image.asset('assets/images/sunny/sunny_idle.png', width: w * 0.65)),
              
              AnimatedPositioned(
                duration: const Duration(milliseconds: 450),
                top: sunnyMessage.length > 100 ? h * 0.16 : h * 0.22,
                left: 30, right: 30,
                child: Column(
                  children: [
                    _buildGlassBubble(sunnyMessage),
                    CustomPaint(size: const Size(20, 12), painter: SpeechBubbleTriangle()),
                  ],
                ),
              ),

              // --- DYNAMIC INPUT AREA ---
              Positioned(
                // 🔥 FIX 2: CHAT INPUT STAYS LOW (40), BUTTONS STAY HIGH (150)
                bottom: isFinishedSetup 
                    ? 40 
                    : (isKeyboardOpen 
                        ? keyboardHeight + 20 
                        : (isButtonMode ? 150 : 40)), 
                
                left: 20, right: 20,
                child: isFinishedSetup 
                    ? _buildLocationPickerCard() 
                    : (isFinishedUpdate ? const SizedBox.shrink() : _buildDynamicInputArea()), 
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicInputArea() {
    final qMap = questions(currentUserName);
    final currentQ = qMap[currentStep];
    
    if (currentQ == null) return const SizedBox.shrink();

    if (currentQ.containsKey("options")) {
      return _buildOptionButtons(currentQ["options"] as List<String>);
    } else {
      return _buildChatInput();
    }
  }

  // --- 🔥 FIX 3: CENTER ALIGNMENT WITH WRAP ---
  Widget _buildOptionButtons(List<String> options) {
    return Wrap(
      alignment: WrapAlignment.center, 
      spacing: 12,
      runSpacing: 12,
      children: options.map((option) {
        return GestureDetector(
          onTap: () => _handleOptionSelection(option),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFF5722),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(color: const Color(0xFFFF5722).withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))
              ],
            ),
            child: Text(
              option,
              style: GoogleFonts.rubik(
                fontSize: 18, 
                fontWeight: FontWeight.bold, 
                color: Colors.white 
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGlassBubble(String text) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.white.withOpacity(0.5)),
          ),
          child: Text(text, textAlign: TextAlign.center, style: GoogleFonts.rubik(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFFFF5722))),
        ),
      ),
    );
  }

  Widget _buildChatInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.7), borderRadius: BorderRadius.circular(30)),
      child: Row(
        children: [
          Expanded(child: TextField(controller: _controller, enabled: !isLoading, decoration: const InputDecoration(hintText: 'Message Sunny...', border: InputBorder.none))),
          isLoading 
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A4D9E)))
            : IconButton(icon: const Icon(Icons.arrow_upward_rounded, color: Color(0xFF1A4D9E)), onPressed: _sendMessage),
        ],
      ),
    );
  }
  
  Widget _buildLocationPickerCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.8),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: isLoading ? null : () {
                  showCountryPicker(
                    context: context,
                    showPhoneCode: false,
                    onSelect: (Country country) {
                      setState(() {
                        selectedCountryName = country.name;
                        selectedCountryCode = country.countryCode;
                        selectedCountryEmoji = country.flagEmoji;
                      });
                    },
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
                  child: Row(
                    children: [
                      Text(selectedCountryEmoji, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 15),
                      Text(selectedCountryName, style: GoogleFonts.rubik(color: Colors.black87)),
                      const Spacer(),
                      const Icon(Icons.keyboard_arrow_down, color: Colors.orange),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
                child: TextField(
                  controller: _cityController,
                  enabled: !isLoading,
                  decoration: const InputDecoration(hintText: "Type your City...", border: InputBorder.none),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: isLoading ? null : _saveAndFinish,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5722),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: isLoading 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text("Confirm & Start", style: GoogleFonts.rubik(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class SpeechBubbleTriangle extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.85);
    final path = Path();
    path.moveTo(0, 0); path.lineTo(size.width, 0); path.lineTo(size.width / 2, size.height); path.close();
    canvas.drawPath(path, paint);
  }
  @override bool shouldRepaint(CustomPainter oldDelegate) => false;
}