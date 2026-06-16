
import 'dart:convert';      // gives access to json.decode()
import 'package:http/http.dart' as http;

/// This service is responsible ONLY for:
/// 1) Calling OpenWeather FREE Current Weather API
/// 2) Extracting & converting weather data
/// 3) Returning clean features for the ML model
/// 4) Geocoding services for city validation and coordinate retrieval

class WeatherService {
  // Centralized API Key
  static const String _apiKey = "d2908dcde83b3026ac4a2df47fc38ead";

  /// 1. Geocoding: Validate city existence and return the official name
  Future<String?> validateCity(String city, String countryCode) async {
    final url =
        'https://api.openweathermap.org/geo/1.0/direct?q=${Uri.encodeComponent(city)},$countryCode&limit=1&appid=$_apiKey';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        List data = json.decode(response.body);
        if (data.isNotEmpty) {
          // Returns the official correctly spelled name (e.g., "london" -> "London")
          return data[0]['name'];
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 2. Geocoding: Get full location data (lat/lon) for weather fetching
  Future<Map<String, dynamic>?> getLocationCoords(String city, String countryCode) async {
    final url =
        'https://api.openweathermap.org/geo/1.0/direct?q=${Uri.encodeComponent(city)},$countryCode&limit=1&appid=d2908dcde83b3026ac4a2df47fc38ead';

    try {
      final response = await http.get(Uri.parse(url)); //Send HTTP request//Sends a network request ->Pauses function execution (await)->Resumes when data arrives
      if (response.statusCode == 200) {                //200 = success  , Anything else = network error 
        List data = json.decode(response.body);
        if (data.isNotEmpty) {
          return {
            'name': data[0]['name'],
            'lat': data[0]['lat'],
            'lon': data[0]['lon']
          };
        }
      }
    } catch (e) {
      print("Error fetching coords: $e");
    }
    return null;
  }

  /// 3. Fetch raw weather data from OpenWeather (FREE endpoint)
  Future<Map<String, dynamic>> fetchWeather({
    required double lat,
    required double lon,
  }) async {
    final url = "https://api.openweathermap.org/data/2.5/weather"
        "?lat=$lat&lon=$lon"
        "&units=metric"
        "&appid=$_apiKey";

    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      throw Exception(
        "Failed to fetch weather data: ${response.statusCode}",
      );
    }

    return jsonDecode(response.body);
  }

  /// 4. Extract exactly the features needed by the Python ML model
  Map<String, dynamic> extractWeatherFeatures(Map<String, dynamic> data) {
    // Rain / snow volume (mm per hour)
    final double rainMm = data["rain"]?["1h"]?.toDouble() ?? 0.0;  //If rain exists use it , if not assume 0.0 
    final double snowMm = data["snow"]?["1h"]?.toDouble() ?? 0.0; 

    // Weather condition code (for rain_type mapping) 
    final int weatherCode = data["weather"][0]["id"];   //OpenWeather uses numeric codes 300–399 drizzle , so we use this to know rain, drizzle,snow

    // Wind handling (avoid 0.0 for ML model stability)
    final double rawWindSpeed = data["wind"]?["speed"]?.toDouble() ?? 0.0;
    final double windSpeed = rawWindSpeed < 0.5 ? 0.5 : rawWindSpeed;   //numerical stabilization. force minimum windspeed cuz we use math.sqrt(wind) in ml 
    final double gustSpeed = data["wind"]?["gust"]?.toDouble() ?? windSpeed;

    //ML input 

    return {
      "temp": data["main"]["temp"].toDouble(),   //raw temperature, not perceived.
      "wind": windSpeed,
      "gust": gustSpeed,
      "condition": data["weather"][0]["main"],   //Used mainly for: ui and explinataion not ml 
      "humidity": data["main"]["humidity"].toDouble(),
      "pressure": data["main"]["pressure"].toDouble(),
      "cloud": data["clouds"]["all"].toDouble(),

      // UV not available in free API → neutral default
      "uv": 0.0,

      // Rain logic
      "rain_intensity": _rainIntensityFromMm(rainMm + snowMm),
      "rain_type": _mapRainType(weatherCode),

      // User sensitivity placeholders
      "cold_sensitivity": 0,
      "heat_sensitivity": 0,
    };
  }

  /// Helper: Convert OpenWeather condition code → ML rain_type
  String _mapRainType(int code) {
    if (code >= 300 && code < 400) return "drizzle";
    if (code == 500) return "light_rain";
    if (code == 501) return "moderate_rain";
    if (code == 502) return "heavy_rain";
    if (code >= 503 && code <= 504) return "very_heavy_rain";
    if (code == 511) return "freezing_rain";
    if (code >= 600 && code < 700) return "snow";
    return "none";
  }
// Inside WeatherService class...

Future<Map<String, dynamic>> fetchForecast({required double lat, required double lon}) async {
  // ⚠️ Make sure to use your real API Key here
  final String apiKey = 'd2908dcde83b3026ac4a2df47fc38ead'; 
  final url = 'https://api.openweathermap.org/data/2.5/forecast?lat=$lat&lon=$lon&appid=$apiKey&units=metric';
  
  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    throw Exception('Failed to load forecast');
  }
}
  /// Helper: Convert mm/hour → percentage (0–100)
  double _rainIntensityFromMm(double mmPerHour) {
    final intensity = (mmPerHour / 10.0) * 100;
    return intensity.clamp(0, 100);
  }
}