 import 'dart:convert';
import 'package:http/http.dart' as http;

class OpenAIService {

  // API key removed for public repository

  Future<Map<String, dynamic>> sendValidatedMessage({
    required String question,
    required String userAnswer,
    required String type, 
  }) async {
    const endpoint = "https://api.openai.com/v1/chat/completions";

    final systemPrompt = """
You are a Data Classifier for a fashion app. Your job is to extract database values from user answers.

STRICT VALIDATION RULES (CRITICAL):
1. **Sanity Check:** If the user's answer is nonsense, an insult, gibberish, or completely unrelated to the question, return {"valid": false, "retry": "Please give a serious answer."}.
   - Example: Question: "Occupation?", Answer: "Cow" -> INVALID.
   - Example: Question: "Disliked items?", Answer: "I hate you" -> INVALID.

2. 'occupation':
   - Map to a standard job title (e.g., "I study at school" -> "student").
   - If the input is not a human job/role (like "potato", "cow", "table"), mark it INVALID.

3. 'disliked_items' / 'text':
   - Extract clothing items ONLY. 
   - If the text contains insults or no clothing items, mark it INVALID.
   - Example: "I hate boots" -> "boots".
   - Example: "You are stupid" -> INVALID.

4. 'name':
   - Extract the name. If it looks like a fake name or random characters, mark INVALID.

OUTPUT FORMAT:
Return ONLY the JSON: {"valid": true, "value": "extracted_value"} or {"valid": false, "retry": "Reason for rejection"}
""";






    // --- 🟢 READABLE START LOG ---
    print("\n" + "="*50);
    print("🚀 [LOG] NEW AI VALIDATION REQUEST");
    print("❓ Question: $question");
    print("👤 User Said: \"$userAnswer\"");
    print("🏷️ Expected Type: $type");
    print("-" * 50);

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
            {
              "role": "user", 
              "content": "Question: \"$question\"\nExpected Type: \"$type\"\nUser Answer: \"$userAnswer\""
            }
          ],
          "response_format": {"type": "json_object"}, 
          "temperature": 0, 
        }),
      );

      if (response.statusCode != 200) {
        print("❌ [ERROR] Status: ${response.statusCode}");
        print("📝 Body: ${response.body}");
        print("="*50 + "\n");
        return {"valid": false, "retry": "Service error."};
      }

      final data = jsonDecode(response.body);
      final String rawText = data["choices"][0]["message"]["content"];
      final Map<String, dynamic> parsed = jsonDecode(rawText);

      // --- 🟢 READABLE RESULT LOG ---
      print("✅ [RESULT] Extracted Data:");
      print("   ➤ Valid: ${parsed['valid']}");
      print("   ➤ Value: ${parsed['value']}");
      if (parsed['valid'] == false) {
        print("   ➤ Retry: ${parsed['retry']}");
      }
      print("="*50 + "\n");

      return parsed;
    } catch (e) {
      print("❌ [CRASH] Service encountered an error: $e");
      print("="*50 + "\n");
      return {"valid": false, "retry": "Something went wrong."};
    }
  }
}
