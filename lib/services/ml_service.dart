import 'dart:convert';
import 'package:http/http.dart' as http;

class MlService {
  static const String _baseUrl = "http://127.0.0.1:8000";

  Future<int> predictLayer(Map<String, dynamic> features) async {
    final url = Uri.parse("$_baseUrl/predict-layer");

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode(features),
    );

    if (response.statusCode != 200) {
      throw Exception(
        "ML API error: ${response.statusCode} ${response.body}",
      );
    }

    final decoded = jsonDecode(response.body);
    return decoded["layer"];
  }
}
