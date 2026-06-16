// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'package:http/http.dart' as http;

class StylistAIService {
  // 🔑 Your OpenAI API Key
  final String apiKey = "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";


  Future<Map<String, dynamic>> sendValidatedMessage({
    required String question,
    required String userAnswer,
    required String type, 
  }) async {
    const endpoint = "https://api.openai.com/v1/chat/completions";

    const String availableItems = """
      tshirt, long_sleeve, blouse, light_sweater, heavy_sweater, basic_long_sleeve_top, high_neck_top, 
      short_sleeve_top, hoodie, linen_shirt, satin_blouse, button-up_shirt, structured_long_sleeve_top, 
      polo-style_knit_top, ribbed_long_sleeve_top, linen_pants, light_pants, jeans, warm_pants, long_skirt, 
      midi_skirt, tailored_pants, straight_trousers, cargo_pants, soft_flowy_pants, shorts, jean_shorts, 
      sheer_tights, opaque_tights, thermal_leggings, denim_jacket, jacket, blazer, trench_coat, 
      waterproof_trench_coat, wool_coat, puffer_jacket, waterproof_puffer_jacket, windbreaker, vest, 
      light_cardigan, thick_cardigan, oversized_blazer, tailored_blazer, long-line_blazer, cropped_jacket, 
      fur-lined_winter_coat, long_dress, midi_dress, sweater_dress, abaya_dress, knit_long_dress, 
      shirt_dress_(long), shirt_dress_(midi), two-piece_modest_co-ord_set, long_formal_dress, 
      formal_maxi_skirt, sneakers, boots, ankle_boots, loafers, heels, sandals, low_heels, classic_heels, 
      winter_boots, running_shoes, training_sneakers, bag, scarf, light_scarf, winter_scarf, beanie, cap, 
      earmuffs, bucket_hat, wide-brim_hat, fedora_hat, gloves, winter_gloves, sunglasses, mask, watch, 
      minimal_jewelry, hijab, arm_sleeves, undershirt, thermal_top, heat-tech_undershirt, heat-tech_leggings, 
      oversized_cotton_tee, sports_long_sleeve_top, sports_short_sleeve_top, lightweight_hoodie, 
      zip-up_sports_jacket, breathable_mesh_training_top, loose_joggers, wide-leg_sports_pants, 
      modest_leggings_under_shorts, sports_leggings, training_pants, yoga_pants, sports_bag, hair_tie, 
      headband, gym_gloves, water_bottle, fitness_tracker, gym_flat_shoes, t-shirt, long_sleeve_shirt, 
      oxford_shirt, polo_shirt, knit_sweater, high_neck-top, overshirt, flannel_shirt, sports_tshirt, 
      straight_pants, slim_pants, dress_trousers, sports_joggers, sport_shorts, casual_jacket, 
      bomber_jacket, coat, long_wool_coat, overshirt_jacket, waterproof_jacket, waterproof_coat, 
      rain_jacket, dress_shirt, suit_jacket, formal_trousers, full_suit_set, tie, formal_coat, 
      oxford_shoes, dress_shoes, sports_shoes, sports_cap, belt, backpack, crossbody_bag, 
      sports_tank_top, compression_top, compression_leggings, gym_bag, wrist_straps, lifting_gloves, 
      towel, lifting_shoes
    """;

    String systemPrompt = "";

    if (type == "item_extraction") {
      systemPrompt = """
        You are a Fashion Item Mapper. Your goal is to map the user's natural language to the closest matching item from this list: [$availableItems].
        
        RULES:
        1. Return exactly this JSON: {"valid": true, "value": ["matched_item_key"]}
        2. The "value" must be a JSON ARRAY of strings.
        3. If the user mentions an item generically (e.g., "sweater"), map it to the "root" version (e.g., "heavy_sweater" or "light_sweater"). 
        4. Fix spelling and underscores (e.g., "button up" -> "button-up_shirt").
        5. If the user says "no", "nothing", "idk", or "don't know", return {"valid": true, "value": []}.
        6. Use ONLY keys from the provided list.
      """;
    }
    
    
     else if (type == "outfit_plan") {
      systemPrompt = """
        You are an Event Classifier. Your job is to map the user's input to ONE of these valid event keys: 
        [gym, office, university, airport, dinner, meeting, party, casual, formal, comfy].

        RULES:
        1. Return exactly this JSON: {"valid": true, "value": "matched_event_key", "label": "specific_event_name"}
        2. "value": The strict key from the list above (e.g., "party").
        3. "label": The specific event the user actually mentioned (e.g., "concert", "rave", "festival"). 
           - Use the user's terminology for the label.
           - If they just said "party", label is "party".
        4. If the input is completely misspelled or gibberish (e.g., "asdfg", "wrok"), try to guess the closest match. 
           - If it is unrecognizable, return {"valid": false, "retry": "I didn't quite catch that. Where are you going?"}
        
        MAPPING GUIDE:
        - "concert", "festival", "club", "birthday" -> "party"
        - "date", "brunch", "lunch", "restaurant" -> "dinner"
        - "class", "library", "school", "hanging out", "shopping" -> "university" (or "casual")
        - "interview", "business", "presentation" -> "meeting"
        - "work", "job", "corporate" -> "office"
        - "home", "sleeping", "movie night", "netflix" -> "comfy"
        - "funeral", "gala", "wedding" -> "formal"
        - "travel", "plane", "flying" -> "airport"
        - "workout", "yoga", "pilates", "running" -> "gym"
        
        If vague, pick the closest from [casual, formal, comfy].
      """;
    } 
    
    else if (type == "explanation") {
      systemPrompt = """
        You are a polite, helpful Fashion Stylist. 
        The system has rejected a user's clothing choice based on technical rules (weather or activity appropriateness).
        
        TASK:
        Take the technical 'Question' (which contains the item and the reason) and turn it into a friendly 1-sentence explanation for the avatar to say.
        - If the reason is 'weather', mention it's too cold or warm.
        - If the reason is 'event', mention it's not suitable for the activity.
        
        Example: "I know you wanted a dress, but it's a bit too cold today, so I've picked some warm pants instead!"
        Return exactly: {"valid": true, "value": "Your friendly explanation here"}
      """;
    }

    try {
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          "model": "gpt-4o-mini",
          "messages": [
            {"role": "system", "content": systemPrompt},
            {"role": "user", "content": "Question: \"$question\"\nUser Answer: \"$userAnswer\""}
          ],
          "response_format": {"type": "json_object"}, 
          "temperature": 0.7, 
        }),
      );

      final Map<String, dynamic> parsed = jsonDecode(jsonDecode(response.body)["choices"][0]["message"]["content"]);
      return parsed;
    } catch (e) {
      return {"valid": false, "retry": "Something went wrong."};
    }
  }
}