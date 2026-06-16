// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:convert'; //json
import 'dart:math'; //random
import 'package:flutter/foundation.dart'; //debug prints
import 'package:flutter/services.dart'; //loads rules from assets

class OutfitEngine {
  Map<String, dynamic>? clothes;
  Map<String, dynamic>? rules;
  Map<String, dynamic>? eventRules;
  Map<String, dynamic>? eventLayerRules;
  Map<String, dynamic>? weatherRules;
  Map<String, dynamic>? occupationRules;
  Map<String, dynamic>? compatibilityRules;
  Map<String, dynamic>? healthRules;
  Map<String, dynamic>? layeringRules; 

  bool _isLoaded = false;
  final Random _rng = Random();
  
  Map<String, String?> _lastOutfit = {};

  final List<String> formalEvents = [
    "meeting",
    "interview",
    "wedding",
    "office",
    "work",
    "presentation"
  ];

  // ─────────────────────────────────────────────
  // LOADERS
  // ─────────────────────────────────────────────

  Future<void> loadForUserGender(String gender) async {
    if (_isLoaded) return;
    final g = gender.toLowerCase().trim();

    try {
      if (g == "male") {
        clothes = await _loadJson("assets/data/clothes_male.json");
        rules = await _loadJson("assets/data/rules_male.json");
      } else {
        clothes = await _loadJson("assets/data/clothes_female.json");
        rules = await _loadJson("assets/data/rules_female.json");
      }

      eventRules = await _loadJson("assets/data/event_rules.json");
      eventLayerRules = await _loadJson("assets/data/event_layer_rules.json");
      weatherRules = await _loadJson("assets/data/weather_rules.json");
      compatibilityRules = await _loadJson("assets/data/compatibility_rules.json");
      healthRules = await _loadJson("assets/data/health_rules.json");
      layeringRules = await _loadJson("assets/data/layering_rules.json"); 

      _isLoaded = true;
      debugPrint("✅ OutfitEngine JSONs loaded successfully");
    } catch (e) {
      debugPrint("⚠️ [ENGINE ERROR] Failed loading JSONs: $e");
    }
  }

  Future<Map<String, dynamic>> _loadJson(String path) async {
    final data = await rootBundle.loadString(path);
    return Map<String, dynamic>.from(jsonDecode(data));
  }

  Map<String, dynamic> _asMap(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : {};

  // ─────────────────────────────────────────────
  // MAIN ENGINE(GENERATE SMART OUTFIT)
  // ─────────────────────────────────────────────

  Map<String, dynamic> generateSmartOutfit({
    required Map<String, dynamic> profile,
    required int weatherLayer,
    required String event,
    required List<String> userItems, 
    required Map<String, dynamic> weatherData,
    double mlOffset = 0.0,
  }) {
    debugPrint("🚀 --- START OUTFIT GENERATION ---");
    debugPrint("📋 User Profile: Modesty=${profile['modesty']}, Hijab=${profile['hijab']}, Allergies=${profile['allergies']}");
    debugPrint("🌍 Weather Input: Layer=$weatherLayer, Condition=${weatherData['condition']}, Wind=${weatherData['wind']}");
    
    // weatherData = Map.from(weatherData); // Unlock the map
    // weatherData['condition'] = 'Rain';   // Force the name
    // weatherData['rain'] = 10.0;          // Force volume (triggers logic)
    
    // --- HARDCODED TESTING BLOCK START ---
    //weatherLayer = 4; // Use for manual testing if needed
    // --- HARDCODED TESTING BLOCK END ---

    final gender = (profile["gender"] ?? "female").toLowerCase();
    final style = (profile["style"] ?? "casual").toLowerCase();
    final disliked = (profile["disliked_items"] ?? "").toLowerCase();
    final modestPref = (profile["modesty"].toString().toLowerCase() == "yes" || profile["modesty"] == true)
        ? "yes"
        : "no";

    final isColdSensitive = (profile["cold_sensitivity"] ?? "").toString().toLowerCase().contains("yes");
    final isHeatSensitive = (profile["heat_sensitivity"] ?? "").toString().toLowerCase().contains("yes");
    
    // --- 1. Start with the baseline ---
    int adjustedWeatherLayer = weatherLayer;
    
    // --- 2. WEIGHTED PRIORITY LOGIC ---
    // This allows ML feedback and Profile sensitivity to work together
    int shift = 0; 
    debugPrint("🌡️ Start Calculation: Baseline=$weatherLayer | ML Offset=$mlOffset");

    // A. Check ML Behavioral Authority
    if (mlOffset >= 0.8) {
      shift += 1;
      debugPrint("🧠 ML AUTHORITY: Increasing warmth (+1)");
    } else if (mlOffset <= -0.8) {
      shift -= 1;
      debugPrint("🧠 ML AUTHORITY: Decreasing warmth (-1)");
    }

    // B. Check Profile Sensitivity (Independent check)
    if (isColdSensitive) {
      shift += 1;
      debugPrint("🥶 Profile: Cold Sensitive (+1)");
    } else if (isHeatSensitive) {
      shift -= 1;
      debugPrint("🥵 Profile: Heat Sensitive (-1)");
    }

    // 1. Calculate the Adjusted Layer
    adjustedWeatherLayer = (weatherLayer + shift).clamp(1, 5);

    // 2. SAFETY CLAMP (Keep this from your original code to prevent extreme jumps)
    int maxShift = 2; 
    int minAllowed = (weatherLayer - maxShift).clamp(1, 5);
    int maxAllowed = (weatherLayer + maxShift).clamp(1, 5);
    adjustedWeatherLayer = adjustedWeatherLayer.clamp(minAllowed, maxAllowed);

    // 3. Define the "Soft Constraint" Flag
    // We check if ML specifically tried to lower the layer (make it colder)
    bool mlReducedWarmth = (mlOffset <= -0.8); 

    debugPrint("🌡 Weather=$weatherLayer | Final Adjusted=$adjustedWeatherLayer | ML Reduced Warmth? $mlReducedWarmth");

    var eventData = eventRules?["events"]?[event]?[gender];
    if (eventData == null) {
      debugPrint("⚠️ Event '$event' not found. Using Fallback.");
      String userStyle = (profile["style"] ?? "casual").toLowerCase();
      String fallbackKey = "casual"; 
      if (userStyle.contains("formal")) fallbackKey = "formal";
      else if (userStyle.contains("comfy") || userStyle.contains("relaxed")) fallbackKey = "comfy";
      else if (userStyle.contains("casual")) fallbackKey = "casual";
      eventData = eventRules?["events"]?[fallbackKey]?[gender];
    }
    //style-based fallback

    if (eventData == null) eventData = eventRules?["events"]?["university"]?[gender];

   final eventConfig = _asMap(eventData);
    final allowedCats = List<String>.from(eventConfig["allowed_categories"] ?? []);

    // 🎯 MODESTY & HIJABI ASSET SELECTOR
    bool isHijabi =
    profile['hijab'].toString().toLowerCase() == 'yes' ||
    profile['hijab'] == true;

final bool isStrictEvent = formalEvents.contains(event);

// 🎯 MODESTY & HIJABI CATEGORY CONTROL
if (isHijabi) {
  debugPrint("🧕 Hijabi Profile Detected");

  if (isStrictEvent) {
    debugPrint("🔒 Strict event ($event): respecting event categories only");

  } else {
    debugPrint("🌿 Flexible event: allowing hijabi_modest_tops");
    allowedCats.insert(0, "hijabi_modest_tops");
  }
}
else if (modestPref == "yes") {
  debugPrint("👗 Modest Profile Detected: Prioritizing 'modest_tops'");
  allowedCats.insert(0, "modest_tops");
}
else {
  debugPrint("👕 Standard Profile: Prioritizing 'tops'");
  allowedCats.insert(0, "tops");
}

    // 🟢 Handle Outerwear for Hijabis
   // 🟢 Handle Outerwear for Hijabis (event-aware)
    if (isHijabi && !isStrictEvent) {
      debugPrint("🧕 Adding hijabi_outwear for flexible event");
      allowedCats.insert(0, "hijabi_outwear");
    } else if (isHijabi && isStrictEvent) {
      debugPrint("🔒 Strict event: using event-defined outerwear only");
    }


    final forbiddenByEvent = [
      ...List<String>.from(eventConfig["forbidden_items"] ?? []),
      ...List<String>.from(eventConfig["avoid_categories"] ?? []),
      ...List<String>.from(eventConfig["excluded_items"] ?? [])
    ];
    final preferredByEvent = Map<String, dynamic>.from(eventConfig["preferred_items"] ?? {});
    // 🎨 STYLE FALLBACK (only if event has no preferences)
    if (preferredByEvent.isEmpty && style.isNotEmpty) {
      final styleEvent = eventRules?["events"]?[style]?[gender];
      if (styleEvent != null && styleEvent["preferred_items"] != null) {
        debugPrint("🎨 Style fallback applied: $style");
        preferredByEvent.addAll(
          Map<String, dynamic>.from(styleEvent["preferred_items"])
        );
      }
    }

    // ⚖️ HYBRID BALANCE LOGIC
    final eventLayerConfig = _asMap(eventLayerRules?["event_layer_rules"]?[event]);
    final maxLayer = eventLayerConfig["max_layer"] ?? 5;
    
    // 1. activityLayer is for the indoor look (capped by event)
    final activityLayer = adjustedWeatherLayer.clamp(0, maxLayer);
    final activityRules = _asMap(rules?["layer_rules"]?[activityLayer.toString()]);
 debugPrint("🎯 Event Rules Selected: '$event' | Indoor activity layer: $activityLayer");
    // 2. validationLayer is for the commute/user requests (the real weather)
    final validationRules = _asMap(rules?["layer_rules"]?[adjustedWeatherLayer.toString()]);

    // Create expanded validation lists
    List<String> validationTops = [
      ...List<String>.from(activityRules["tops"] ?? []),
      ...List<String>.from(validationRules["tops"] ?? [])
    ];
    List<String> validationBottoms = [
      ...List<String>.from(activityRules["bottoms"] ?? []),
      ...List<String>.from(validationRules["bottoms"] ?? [])
    ];
    List<String> validationShoes = [
      ...List<String>.from(activityRules["shoes"] ?? []),
      ...List<String>.from(validationRules["shoes"] ?? [])
    ];

    final outfit = <String, dynamic>{
      "base_top": null, "base_bottom": null, "top": null, "bottom": null,
      "outerwear": null, "shoes": null, "accessories": <String>[],
      "socks": _getSocks(adjustedWeatherLayer), "reasoning": <String>[],
    };

    // ─── 1. PICK BOTTOM ──────────────────
    List<String> bottomCandidates = [];
    bool strictBottomEvent = false;
    for (String cat in allowedCats) {
      if (cat.endsWith("_bottoms") && cat != "bottoms") { 
        bottomCandidates.addAll(List<String>.from(clothes?[cat] ?? []));
        strictBottomEvent = true;
      }
    }
    if (!strictBottomEvent) bottomCandidates = List<String>.from(activityRules["bottoms"] ?? []);

    final bottomResult = _pickBestItem(
      "bottom",
      allowedCats,
      bottomCandidates,
      disliked,
      style,
      forbiddenByEvent,
      event,
      List<String>.from(preferredByEvent["bottoms"] ?? []),
      userItems,
      outfit["reasoning"],
      _lastOutfit["bottom"],
      validationBottoms,
    );
    outfit["bottom"] = bottomResult["item"];

    if (bottomResult["rejectedItem"] != null) {
  outfit["rejectedItem"] = bottomResult["rejectedItem"];
  outfit["reason"] = bottomResult["reason"];

  
}


    // ─── 2. PICK TOP (FIXED VERSION) ──────────
    List<String> topCandidates = [];
    bool strictTopEvent = false;

    for (String cat in allowedCats) {
      if (cat.endsWith("_tops") && cat != "tops") { 
        topCandidates.addAll(List<String>.from(clothes?[cat] ?? []));
        strictTopEvent = true;
      }
    }

    if (!strictTopEvent) {
  topCandidates = List<String>.from(activityRules["tops"] ?? []);

  // 🚫 DO NOT inject user items for strict events
  if (!isStrictEvent && userItems.isNotEmpty) {
    for (var req in userItems) {
      if (validationTops.any((v) =>
    v.toLowerCase().contains(req) || req.contains(v.toLowerCase()))) {
        topCandidates.add(req);
      }
    }
  }
}


    List<String> matchedTops = [];
    if (outfit["bottom"] != null) {
      var anchorData = compatibilityRules?[gender]["anchors"]?[outfit["bottom"]];
      if (anchorData != null && anchorData["tops"] != null) {
        matchedTops = (anchorData["tops"] as List)
            .where((t) => t["strength"] == "strong" || t["strength"] == "medium")
            .map((t) => t["item"].toString()).toList();
      }
    }

    final topResult = _pickBestItem(
        "top",
        allowedCats,
        topCandidates,
        disliked,
        style,
        forbiddenByEvent,
        event,
        [...matchedTops, ...List<String>.from(preferredByEvent["tops"] ?? [])],
        userItems,
        outfit["reasoning"],
        _lastOutfit["top"],
        validationTops,
      );

      // ✅ assign picked item
      outfit["top"] = topResult["item"];

      // ✅ capture rejection reason (only once)
      if (topResult["rejectedItem"] != null) {
        outfit["rejectedItem"] ??= topResult["rejectedItem"];
        outfit["reason"] ??= topResult["reason"];
      }

    // ─── 3. PICK SHOES ────────────────────
    List<String> shoeCandidates = [];
    bool strictShoeEvent = false;
    for (String cat in allowedCats) {
      if (cat.endsWith("_shoes") && cat != "shoes") {
        shoeCandidates.addAll(List<String>.from(clothes?[cat] ?? []));
        strictShoeEvent = true;
      }
    }
    if (!strictShoeEvent) shoeCandidates = List<String>.from(activityRules["shoes"] ?? []);

    final shoeResult = _pickBestItem(
        "shoe",
        allowedCats,
        shoeCandidates,
        disliked,
        style,
        forbiddenByEvent,
        event,
        [],
        userItems,
        outfit["reasoning"],
        _lastOutfit["shoes"],
        validationShoes,
      );

      // ✅ assign picked item
      outfit["shoes"] = shoeResult["item"];

      // ✅ capture rejection reason (only once)
      if (shoeResult["rejectedItem"] != null) {
        outfit["rejectedItem"] ??= shoeResult["rejectedItem"];
        outfit["reason"] ??= shoeResult["reason"];
      }


    debugPrint("👔 Item Selection Results:");
    debugPrint("   - Top picked: ${outfit['top']}");
    debugPrint("   - Bottom picked: ${outfit['bottom']}");
    debugPrint("   - Shoes picked: ${outfit['shoes']}");

// ─── 4. REFINED THERMAL LOGIC (Gym-Aware) ───────────────────────────────
    final lr = _asMap(layeringRules?["layering_rules"]);
    final minLayer = lr["base_layer_allowed_from_layer"] ?? 3;
    final genderRules = _asMap(lr[gender]);
    final notLayerable = List<String>.from(genderRules["tops_not_layerable"] ?? []);
    final warmItems = List<String>.from(genderRules["warm_items"] ?? []);
    final baseByWeather = Map<String, dynamic>.from(genderRules["base_layer_by_weather"] ?? {});

    if (outfit["top"] != null && adjustedWeatherLayer >= minLayer) {
      final String topName = outfit["top"].toString().toLowerCase();
      bool isBlocked = notLayerable.any((k) => topName.contains(k));
      bool isWarm = warmItems.any((k) => topName.contains(k));

      debugPrint("🔍 Layering Check | Top: $topName | IsWarm: $isWarm | Weather: $adjustedWeatherLayer");

      String? selectedBase;

      // 🔥 FIX: Skip base layers if the event is the GYM
      if (!isBlocked && event != "gym") {
        if (adjustedWeatherLayer == 3) {
          if (!isWarm) selectedBase = baseByWeather["3"]; 
        } else if (adjustedWeatherLayer == 4) {
          selectedBase = isWarm ? baseByWeather["4_warm"] : baseByWeather["4_light"];
        } else if (adjustedWeatherLayer >= 5) {
          selectedBase = "thermal_top";
        }
      } else if (event == "gym") {
        debugPrint("🏋️ Gym detected: Skipping thermal top to prevent overheating.");
      }

      if (selectedBase != null && (clothes?["base_layers"] ?? []).contains(selectedBase)) {
        outfit["base_top"] = selectedBase;
      }
    }

    // 🔥 FIX: Skip thermal leggings if the event is the GYM
    if (outfit["bottom"] != null && adjustedWeatherLayer >= 5 && event != "gym") {
       outfit["base_bottom"] = "thermal_leggings";
       debugPrint("🦵 Layer 5: Adding thermal leggings.");
    } else if (event == "gym" && adjustedWeatherLayer >= 5) {
       debugPrint("🏋️ Gym detected: Skipping thermal leggings.");
    }
   if (outfit["base_top"] != null) debugPrint("🔥 Thermal Base Added: ${outfit['base_top']}");

    // ─── 5. OUTERWEAR logic (Personalized Commute Rule) ─────────
   // ─── 5. OUTERWEAR logic (Personalized Commute Rule) ─────────
    
    // 👇 NEW LOGIC: Decide which layer to use for the jacket
    int outerwearLookupLayer = adjustedWeatherLayer;

    // If ML removed warmth (mlReducedWarmth), but the REAL weather is cold (4+),
    // force the engine to look at the original weatherLayer for the jacket.
    if (mlReducedWarmth && weatherLayer >= 4) {
       outerwearLookupLayer = weatherLayer; 
       debugPrint("🧥 Soft Constraint: Keeping outerwear despite ML reduction.");
    }

    // 👇 UPDATED CHECK: Use 'outerwearLookupLayer' instead of 'adjustedWeatherLayer'
    if (outerwearLookupLayer > activityLayer) {
      
      // 👇 UPDATED LOOKUP: Use 'outerwearLookupLayer' to fetch the list
      final outdoorRules = _asMap(rules?["layer_rules"]?[outerwearLookupLayer.toString()]);
      
      List<String> outdoorCandidates = List<String>.from(outdoorRules["outerwear"] ?? []);
      
      // 🔒 STRICT EVENT SAFETY FILTER (This is UNCHANGED)
      if (isStrictEvent) {
        outdoorCandidates = outdoorCandidates.where((item) {
          return allowedCats.any((cat) =>
              (clothes?[cat] ?? []).contains(item));
        }).toList();

        debugPrint("🔒 Filtered commute outerwear for strict event: $outdoorCandidates");
      }
      
      final List<String> commuteOuterCats =
        isStrictEvent
            ? allowedCats // meeting_outerwear / office_outerwear
            : ["outerwear", "jackets", "coats", "puffer_jackets"];

      final outerResult = _pickBestItem(
        "outerwear",
        commuteOuterCats,
        outdoorCandidates,
        disliked,
        style,
        [],
        event,
        [],
        userItems,
        outfit["reasoning"],
        _lastOutfit["outerwear"],
        outdoorCandidates,
      );

      // ✅ assign picked item
      outfit["outerwear"] = outerResult["item"];

      // ✅ capture rejection reason (only once)
      if (outerResult["rejectedItem"] != null) {
        outfit["rejectedItem"] ??= outerResult["rejectedItem"];
        outfit["reason"] ??= outerResult["reason"];
      }

      if (outfit["outerwear"] != null) {
        // Just updated the debug print to show the logic variable
        debugPrint("🧥 Commute Rule Triggered: Bypassing $event restrictions for outdoor safety ($outerwearLookupLayer > $activityLayer)");
      }
    }
   // ─────────────────────────────────────────────────────────────
    // 🛡️ SANITY CHECK (Fix for False Rejections)
    // ─────────────────────────────────────────────────────────────
    // Logic: If "jeans" were rejected by the TOP picker (because jeans aren't a top),
    // but accepted by the BOTTOM picker, we must clear the error message.
    
    if (outfit["rejectedItem"] != null) {
      // 1. Get the raw text of the rejected item (e.g., "jeans")
      final String rejectedRaw = outfit["rejectedItem"].toString().toLowerCase();

      // 2. Gather all the items we actually successfully picked
      final List<String> allPickedItems = [
        outfit["top"],
        outfit["bottom"],
        outfit["shoes"],
        outfit["outerwear"],
        outfit["base_top"],
        outfit["base_bottom"],
      ].where((e) => e != null)
       .map((e) => e.toString().toLowerCase().replaceAll('_', ' '))
       .toList();

      // 3. Check if the "rejected" item is actually inside the "picked" list
      bool wasActuallyUsed = allPickedItems.any((picked) => 
          picked.contains(rejectedRaw) || rejectedRaw.contains(picked)
      );

      // 4. If we used it, clear the rejection error!
      if (wasActuallyUsed) {
        debugPrint("✅ Correction: Item '$rejectedRaw' was technically rejected by one slot, but used in another. Clearing error.");
        outfit["rejectedItem"] = null;
        outfit["reason"] = null;
      }
    }
    // ─────────────────────────────────────────────────────────────
   
   // 🧣 COMMUTE ACCESSORIES
    final String condition = (weatherData['condition'] ?? "").toString().toLowerCase();
    bool isDay = weatherData['is_day'] == true || weatherData['is_day'] == 1;
    // Add Sunglasses if Sunny
    if (isDay && (condition.contains("clear") || condition.contains("sun"))) {
      // FIX: These must match the keys we extract in the Screen
      String sunItem = isHijabi ? "glasses_hijabi" : "glasses";
      outfit["accessories"].add(sunItem);
      debugPrint("🕶️ Sunny Day: Recommending $sunItem");
    }

    // Add Beanie and Scarf for Freezing Weather
    if (adjustedWeatherLayer > 4) {
      String scarfItem = isHijabi ? "scarf_hijabi" : "scarf";
      String beanieItem = isHijabi ? "beanie_hijabi" : "beanie";
      
      outfit["accessories"].add(scarfItem);
      outfit["accessories"].add(beanieItem);
      
      debugPrint("🧣 Freezing Commute: Adding $beanieItem and $scarfItem");
    }

    _applyHealthLogic(outfit, profile, weatherData, outfit["reasoning"]);

    _lastOutfit = {"top": outfit["top"], "bottom": outfit["bottom"], "shoes": outfit["shoes"], "outerwear": outfit["outerwear"]};


    // 3️⃣ ML explainability (BEFORE final advice generation)
    if (mlOffset.abs() >= 0.8) {
      outfit["reasoning"].add(
        "I've adjusted today's outfit based on your past comfort feedback. 🧠"
      );
    }

    // 4️⃣ Generate final user-facing advice ONCE
    outfit["reasoning"] = _generateAdvice(
      adjustedWeatherLayer,
      List<String>.from(outfit["reasoning"]),
      isColdSensitive,
      outfit["socks"],
      outfit["outerwear"],
    );
    
    debugPrint("✨ --- FINAL OUTFIT SUMMARY ---");
    debugPrint("Final Map: $outfit");
    debugPrint("Advice: ${outfit['reasoning']}");
    debugPrint("🚀 --- GENERATION COMPLETE ---");


    return {"outfit": outfit};

  }






  // ─────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────

// ... inside OutfitEngine class ...

  Map<String, dynamic> _pickBestItem(
    String slotType,
    List<String> allowedCats,
    dynamic layerList,
    String disliked, // This comes in as a raw string, e.g., "boots, heels"
    String style,
    List<String> forbiddenItems,
    String event,
    List<String>? preferredItems,
    List<String> userItems,
    List<String> reasoningLog,
    String? lastItem,
    List<String> validationList,
  ) {
    if (layerList == null) {
      return {"item": null};
    }

    List<String> candidates = List<String>.from(layerList);

    List<String> dislikedList = [];
if (disliked.isNotEmpty) {
  dislikedList = disliked
      // normalize connectors
      .replaceAll('&', ',')
      .replaceAll(' and ', ',')
      .replaceAll(' i hate ', ',')
      .replaceAll(' hate ', ',')
      .replaceAll(' don\'t like ', ',')
      .replaceAll(' dislike ', ',')
      // split safely
      .split(',')
      .map((e) => e.trim().toLowerCase().replaceAll('_', ' '))
      .where((e) => e.isNotEmpty)
      .toSet() // prevent duplicates
      .toList();
}
debugPrint("❌ Disliked parsed list: $dislikedList");


    // ─────────────────────────────
    // 1️⃣ USER REQUESTS (MULTI-ITEM SAFE)
    // ─────────────────────────────
    List<Map<String, String>> rejectedRequests = [];
    List<String> validForcedItems = [];

    for (final req in userItems) {
      final cleanReq = req.toLowerCase().trim();

      // ❌ Forbidden by event
      if (forbiddenItems.any((b) => cleanReq.contains(b.toLowerCase()))) {
        rejectedRequests.add({
          "item": req,
          "reason": "It's not suitable for $event."
        });
        continue;
      }

      // ❌ Not valid for weather
      final validForWeather = validationList.any((v) {
        final c = v.toLowerCase();
        return c == cleanReq || c.contains(cleanReq) || cleanReq.contains(c);
      });

      if (!validForWeather) {
        rejectedRequests.add({
          "item": req,
          "reason": "It's not comfortable for this weather."
        });
        continue;
      }

      // ✅ Valid → try to match DB
      for (final cat in allowedCats) {
        final items = List<String>.from(clothes?[cat] ?? []);
        for (final item in items) {
          if (item.toLowerCase().contains(cleanReq) ||
              cleanReq.contains(item.toLowerCase())) {
            validForcedItems.add(item);
          }
        }
      }
    }
    
    // ✅ Force user request ONLY if event is NOT strict
    final bool isStrictEvent = formalEvents.contains(event);

    if (validForcedItems.isNotEmpty && !isStrictEvent) {
      return {
        "item": validForcedItems.first,
        "rejectedItem": rejectedRequests.isNotEmpty ? rejectedRequests.first["item"] : null,
        "reason": rejectedRequests.isNotEmpty ? rejectedRequests.first["reason"] : null,
      };
    }

    // ─────────────────────────────
    // 2️⃣ FILTERING (The Fix is Here)
    // ─────────────────────────────
    candidates.removeWhere((item) {
      final itemID = item.toLowerCase();
      final itemCleanName = itemID.replaceAll('_', ' '); // Turn "ankle_boots" -> "ankle boots"

      // 🔍 Check against Disliked List
      for (String badThing in dislikedList) {
        // Direct match: "ankle boots" contains "boots"
        if (itemCleanName.contains(badThing)) {
          debugPrint("🚫 Removed '$item' because user dislikes '$badThing'");
          return true; 
        }
        
        // Singular/Plural safety (e.g., user hates "boot", item is "boots")
        if (badThing.endsWith('s')) {
           // User hates "boots", check against "boot"
           String singular = badThing.substring(0, badThing.length - 1);
           if (itemCleanName.contains(singular)) return true;
        } else {
           // User hates "boot", check against "boots"
           if (itemCleanName.contains('${badThing}s')) return true;
        }
      }

      // 🔍 Check against Event Constraints
      if (forbiddenItems.any((b) => itemID.contains(b.toLowerCase()))) return true;
      
      // 🔍 Avoid repeating exact last outfit item (variety)
      if (lastItem != null && item == lastItem && _rng.nextDouble() < 0.9) return true;
      
      return false;
    });

    if (candidates.isEmpty) {
      return {"item": null};
    }

    // ─────────────────────────────
    // 3️⃣ PREFERRED vs STANDARD
    // ─────────────────────────────
    List<String> preferred = [];
    List<String> standard = [];

    for (final item in candidates) {
      if (preferredItems != null && preferredItems.contains(item)) {
        preferred.add(item);
      } else {
        standard.add(item);
      }
    }

    preferred.shuffle(_rng);
    standard.shuffle(_rng);

    candidates = _rng.nextDouble() < 0.8
        ? [...preferred, ...standard]
        : [...standard, ...preferred];

    // ─────────────────────────────
    // 4️⃣ FINAL PICK + REJECTION REPORTING
    // ─────────────────────────────

    // Track first rejection (if any)
    final rejectedItem = rejectedRequests.isNotEmpty ? rejectedRequests.first["item"] : null;
    final rejectedReason = rejectedRequests.isNotEmpty ? rejectedRequests.first["reason"] : null;

    // Try to pick a valid item
    for (final item in candidates) {
      if (_existsInDB(slotType, item, allowedCats)) {
        return {
          "item": item,
          "rejectedItem": rejectedItem,
          "reason": rejectedReason,
        };
      }
    }

    // Nothing picked
    return {
      "item": null,
      "rejectedItem": rejectedItem,
      "reason": rejectedReason,
    };
  }

  
  bool _existsInDB(String slot, String item, List<String> allowedCats) {
    for (final cat in allowedCats) if ((clothes?[cat] ?? []).contains(item)) return true;
    return false;
  }

 String _getSocks(int layer) {
    if (layer <= 2) return "light_socks"; 
    if (layer == 3) return "warm_socks";  
    return "wool_socks"; // This is just for the speech logic                  
  }

  String _generateAdvice(int layer, List<String> logs, bool cold, String? socks, String? outerwear) {
  List<String> lines = [];
  
  // 1. Only keep health/sensitivity alerts for the main message
  if (cold) lines.add("I've added extra warmth for you! 🧣");
  
  // 2. Add health alerts (Mask) if they exist in logs
  for (var log in logs) {
    if (log.contains("mask") || log.contains("allergies")) {
      lines.add(log);
    }
  }

  // 3. Final Fallback if empty
  if (lines.isEmpty) {
    return "Click on the buttons to see all the layers I've picked for you! ✨";
  }

  return lines.toSet().toList().join(" ");
}
  
 void _applyHealthLogic(Map<String, dynamic> outfit, Map<String, dynamic> profile, Map<String, dynamic> weather, List<String> logs) {
  // 1. Extract health and weather data
  final bool hasAllergies = profile['allergies'] == 'yes' || profile['allergies'] == true;
  final String condition = (weather['condition'] ?? "").toLowerCase();
  final double windSpeed = (weather['wind'] ?? 0.0).toDouble();

  // 2. Define "Mask Required" conditions
  // Dusty condition OR Windy + Allergies
  bool needsMask = condition.contains("dust") || condition.contains("sand");
  
  if (hasAllergies && (windSpeed > 20 || condition.contains("wind"))) {
    needsMask = true;
  }

  // 3. Inject Mask if required
  if (needsMask) {
    outfit["accessories"] ??= <String>[];
    if (!outfit["accessories"].contains("mask")) {
      outfit["accessories"].add("mask");
      
      // Add user-facing advice
      logs.add("It's dusty or windy today! Since you have allergies, please take a mask with you. 😷");
    }
    
    // Add internal flag for the visual builder
    outfit["force_mask"] = true; 
  }
}


}