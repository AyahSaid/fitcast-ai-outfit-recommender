// ignore_for_file: deprecated_member_use

import 'dart:math';
import 'dart:ui'; // For blur effect
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; 
import '../widgets/weather_painters.dart'; 
import '../services/weather_service.dart';

// Helper classes for data
class DailyWeather {
  final String dayName;
  final int high;
  final int low;
  final String condition;
  DailyWeather({required this.dayName, required this.high, required this.low, required this.condition});
}

class HourlyWeather {
  final String time;
  final int temp;
  final String condition;
  HourlyWeather({required this.time, required this.temp, required this.condition});
}

class WeatherOverviewScreen extends StatefulWidget {
  const WeatherOverviewScreen({super.key});

  @override
  State<WeatherOverviewScreen> createState() => _WeatherOverviewScreenState();
}

class _WeatherOverviewScreenState extends State<WeatherOverviewScreen> with TickerProviderStateMixin {
  final WeatherService _weatherService = WeatherService();
  late AnimationController _rainSnowController;
  late AnimationController _starController;
  
  // Weather State
  String city = "Loading...";
  String condition = "Clear";
  int temp = 0;
  bool isWindy = false;
  
  // Detailed State Variables
  String humidity = "--%";
  String windSpeedStr = "-- km/h";
  int feelsLike = 0;

  // Forecast Lists
  List<DailyWeather> dailyForecast = [];
  List<HourlyWeather> hourlyForecast = [];
  
  // Particle System
  final List<WeatherParticle> _particles = [];
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    // 1. Rain/Snow Animation Loop
    _rainSnowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1), 
    )..repeat(); 

    // 2. Star Twinkle Animation Loop
    _starController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4), 
    )..repeat(reverse: true); 

    _fetchWeather();
  }

  @override
  void dispose() {
    _rainSnowController.dispose();
    _starController.dispose();
    super.dispose();
  }

  // ⭐ UPDATED: Now fetches coordinates dynamically based on user profile
  Future<void> _fetchWeather() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      
      // Default fallback coordinates (Amman) if no user data found
      double lat = 31.9539; 
      double lon = 35.9106;

      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('user_preferences').doc(user.uid).get();
        
        if (doc.exists) {
          final data = doc.data()!;
          String savedCity = data['city'] ?? "";
          String savedCountryCode = data['countryCode'] ?? "";

          // If user has a saved city, get its real coordinates
          if (savedCity.isNotEmpty) {
            // Check the API for this city's Lat/Lon
            final locationData = await _weatherService.getLocationCoords(savedCity, savedCountryCode);
            
            if (locationData != null) {
              lat = locationData['lat'];
              lon = locationData['lon'];
            }
          }
        }
      }

      // 1. Fetch Current Weather using the DYNAMIC lat/lon
      final currentData = await _weatherService.fetchWeather(lat: lat, lon: lon);
      // 2. Fetch Forecast
      final forecastData = await _weatherService.fetchForecast(lat: lat, lon: lon);

      if (!mounted) return;

      setState(() {
        city = currentData['name']; 
        temp = (currentData['main']['temp'] as num).round();
        condition = currentData['weather'][0]['main']; 
        
        isWindy = (currentData['wind']?['speed'] ?? 0) > 5.0;
        feelsLike = (currentData['main']['feels_like'] as num).round();
        humidity = "${currentData['main']['humidity']}%";
        windSpeedStr = "${(currentData['wind']['speed'] as num).round()} km/h";
        
        // Pass current temp/condition to start the hourly list correctly
        _processForecastData(forecastData['list'], temp, condition);
        
        _initializeParticles();
      });
    } catch (e) {
      debugPrint("Weather Error: $e");
    }
  }

  void _processForecastData(List<dynamic> list, int currentTemp, String currentCond) {
    DateTime now = DateTime.now();
    
    // --- 1. Hourly Logic: Start with "Now", then find future slots ---
    hourlyForecast = [];
    
    // Add "Now" first
    hourlyForecast.add(HourlyWeather(
      time: "Now",
      temp: currentTemp,
      condition: currentCond
    ));

    // Add next 7 slots from API that are in the future
    int count = 0;
    for (var item in list) {
      if (count >= 7) break;
      DateTime itemTime = DateTime.parse(item['dt_txt']);
      
      // Only add if time is in the future
      if (itemTime.isAfter(now)) {
        hourlyForecast.add(HourlyWeather(
          time: DateFormat.j().format(itemTime), // e.g. "6 PM"
          temp: (item['main']['temp'] as num).round(),
          condition: item['weather'][0]['main'],
        ));
        count++;
      }
    }

    // --- 2. Daily Logic: Group by Day ---
    Map<String, List<dynamic>> grouped = {};
    for (var item in list) {
      String dayKey = item['dt_txt'].toString().split(' ')[0];
      if (!grouped.containsKey(dayKey)) grouped[dayKey] = [];
      grouped[dayKey]!.add(item);
    }

    dailyForecast = [];
    grouped.forEach((key, items) {
      int max = -100;
      int min = 100;
      for (var i in items) {
        int t = (i['main']['temp'] as num).round();
        if (t > max) max = t;
        if (t < min) min = t;
      }
      var mid = items.length > 4 ? items[4] : items[0];
      DateTime date = DateTime.parse(key);
      
      dailyForecast.add(DailyWeather(
        dayName: DateFormat.E().format(date), 
        high: max,
        low: min,
        condition: mid['weather'][0]['main'],
      ));
    });
    
    dailyForecast = dailyForecast.take(5).toList();
  }

  void _initializeParticles() {
    _particles.clear();
    int count = 0;
    if (condition.toLowerCase().contains("rain")) count = 150; 
    else if (condition.toLowerCase().contains("snow")) count = 80; 
    else if (condition.toLowerCase().contains("drizzle")) count = 50; 

    for (int i = 0; i < count; i++) {
      _particles.add(WeatherParticle(
        x: _rng.nextDouble() * 400, 
        y: _rng.nextDouble() * 800, 
        speed: condition.contains("snow") ? _rng.nextDouble() * 2 + 1 : _rng.nextDouble() * 10 + 10, 
        size: condition.contains("snow") ? _rng.nextDouble() * 3 + 2 : _rng.nextDouble() * 10 + 10, 
        opacity: _rng.nextDouble() * 0.5 + 0.2,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final isNight = hour >= 19 || hour < 6;
    
    // Cloud Logic
    bool isCloudy = condition.toLowerCase().contains('cloud') && 
                    !condition.toLowerCase().contains('rain');

    return Scaffold(
      backgroundColor: Colors.transparent, 
      body: Stack(
        children: [
          // 1. Fixed Background
          Positioned.fill(child: _buildDynamicBackground(hour)),

          // 2. Fixed Stars
          if (isNight && !condition.toLowerCase().contains("rain") && !isCloudy)
             Positioned.fill(
               child: AnimatedBuilder(
                animation: _starController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: StarPainter(_starController.value),
                  );
                },
              ),
             ),

          // 3. Fixed Floating Clouds
          if (isCloudy) ...[
            _buildFloatingCloud(top: 60, alignLeft: true, driftRange: 50, duration: 25, scale: 0.6, opacity: 0.5),
            _buildFloatingCloud(top: 150, alignLeft: false, driftRange: -80, duration: 20, scale: 0.9, opacity: 0.7),
            _buildFloatingCloud(top: 320, alignLeft: true, driftRange: 120, duration: 18, scale: 1.4, opacity: 0.85),
          ],

          // 4. Fixed Rain/Snow
          if (_particles.isNotEmpty)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _rainSnowController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: WeatherEffectPainter(
                      particles: _particles,
                      type: condition.toLowerCase().contains("snow") ? "snow" : "rain",
                      windSpeed: isWindy ? 0.8 : 0.2, 
                    ),
                  );
                },
              ),
            ),
            
          // 5. SCROLLABLE CONTENT LAYER
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 60),
                    
                    // Header Data
                    Text(city, style: GoogleFonts.rubik(fontSize: 32, color: Colors.white, fontWeight: FontWeight.w500)),
                    Text("$temp°", style: GoogleFonts.rubik(fontSize: 100, color: Colors.white, fontWeight: FontWeight.w200)),
                    Text(condition, style: GoogleFonts.rubik(fontSize: 24, color: Colors.white70)),
                    
                    const SizedBox(height: 40),

                    // --- Hourly Forecast ---
                    if (hourlyForecast.isNotEmpty)
                      _buildHourlyForecast(),
                    
                    const SizedBox(height: 20),

                    // --- Daily Forecast ---
                    if (dailyForecast.isNotEmpty)
                      _buildDailyForecast(),

                    const SizedBox(height: 20),
                    
                    // --- Details Grid ---
                    _buildGlassCard(
                       child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildWeatherDetail(Icons.water_drop_outlined, "Humidity", humidity),
                          _buildDivider(),
                          _buildWeatherDetail(Icons.air, "Wind", windSpeedStr),
                          _buildDivider(),
                          _buildWeatherDetail(Icons.thermostat, "Feels Like", "$feelsLike°"),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
          
          // Button REMOVED here
        ],
      ),
    );
  }

  // --- NEW WIDGETS ---

  // 1. Hourly Scroll View
  Widget _buildHourlyForecast() {
    return _buildGlassCard(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text("HOURLY FORECAST", style: GoogleFonts.rubik(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 15),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: hourlyForecast.map((hour) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Column(
                    children: [
                      Text(hour.time, style: GoogleFonts.rubik(color: Colors.white, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      Icon(_getIcon(hour.condition), color: Colors.white, size: 24),
                      const SizedBox(height: 8),
                      Text("${hour.temp}°", style: GoogleFonts.rubik(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
                );
              }).toList(),
            ),
          )
        ],
      ),
    );
  }

  // 2. Daily Vertical List
  Widget _buildDailyForecast() {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month, color: Colors.white70, size: 15),
              const SizedBox(width: 8),
              Text("5-DAY FORECAST", style: GoogleFonts.rubik(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 10),
          
          ...dailyForecast.map((day) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  SizedBox(width: 50, child: Text(day.dayName, style: GoogleFonts.rubik(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 15))),
                  const SizedBox(width: 10),
                  Icon(_getIcon(day.condition), color: Colors.white, size: 20),
                  const SizedBox(width: 15),
                  SizedBox(width: 30, child: Text("${day.low}°", style: GoogleFonts.rubik(color: Colors.white54, fontSize: 15))),
                  
                  // Temperature Bar
                  Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), color: Colors.white12),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft, 
                        widthFactor: 0.7, 
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            gradient: const LinearGradient(colors: [Colors.greenAccent, Colors.orangeAccent]),
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  SizedBox(width: 30, child: Text("${day.high}°", textAlign: TextAlign.end, style: GoogleFonts.rubik(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600))),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // --- REUSABLE COMPONENTS ---

  Widget _buildGlassCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.2), 
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildWeatherDetail(IconData icon, String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white70, size: 24),
        const SizedBox(height: 8),
        Text(label, style: GoogleFonts.rubik(color: Colors.white60, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.rubik(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.white.withValues(alpha: 0.2),
    );
  }

  IconData _getIcon(String cond) {
    cond = cond.toLowerCase();
    if (cond.contains('rain')) return Icons.water_drop;
    if (cond.contains('snow')) return Icons.ac_unit;
    if (cond.contains('cloud')) return Icons.cloud;
    if (cond.contains('clear')) return Icons.wb_sunny_rounded;
    return Icons.wb_cloudy_rounded;
  }
  
  // 🎨 Updated Background Logic with Reference Colors
  Widget _buildDynamicBackground(int hour) {
    List<Color> colors;
    bool isNight = hour >= 19 || hour < 6;
    bool isSunset = hour >= 17 && hour < 19;
    
    String cond = condition.toLowerCase();

    if (cond.contains('rain') || cond.contains('storm')) {
      // 🌧 Rain: Deep Blue -> Dark Grey
      colors = [const Color(0xFF2C3E50), const Color(0xFF4B79A1)]; 
    } else if (cond.contains('snow')) {
      // ❄️ Snow: Cold White -> Grey
      colors = isNight 
          ? [const Color(0xFF1c2329), const Color(0xFF3b4952)] 
          : [const Color(0xFFE6DADA), const Color(0xFF274046)]; 
    } else if (cond.contains('cloud')) {
      if (isNight) {
        // Night Clouds
        colors = [const Color(0xFF2C3E50), const Color(0xFF000000)]; 
      } else {
        // ☁️ Cloudy Day: "Soft Peach & Blue" (from your reference image)
        // This is Card 2 from the image_f180d7.png
        colors = [const Color(0xFF89CFF0), const Color(0xFFFFDAB9)]; 
      }
    } else if (cond.contains('fog') || cond.contains('haze')) {
       // 🌫 Fog: Muted Teal -> Beige
       colors = [const Color(0xFF3E5151), const Color(0xFFDECBA4)];
    } else {
      // ☀️ Clear Sky
      if (isNight) {
        // Night Clear: Deep Blue/Black
        colors = [const Color(0xFF0f2027), const Color(0xFF203a43)];
      } else if (isSunset) {
        // 🌅 Sunset: Orange -> Red (Card 4 from reference)
        colors = [const Color(0xFFFFD200), const Color(0xFFF7971E)];
      } else {
        // ☀️ Day Clear: Vibrant Blue -> Cyan (Card 3 from reference)
        colors = [const Color(0xFF2980B9), const Color(0xFF6DD5FA)];
      }
    }
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: colors,
        ),
      ),
    );
  }

  Widget _buildFloatingCloud({required double top, required bool alignLeft, required double driftRange, required int duration, double scale = 1.0, double opacity = 1.0}) {
    return Positioned(
      top: top,
      left: alignLeft ? -50 : null,  
      right: alignLeft ? null : -50, 
      height: 200,
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          child: _FloatingCloud(duration: duration, driftRange: driftRange),
        ),
      ),
    );
  }
}

class _FloatingCloud extends StatefulWidget {
  final int duration;
  final double driftRange;
  const _FloatingCloud({required this.duration, required this.driftRange});

  @override
  State<_FloatingCloud> createState() => _FloatingCloudState();
}

class _FloatingCloudState extends State<_FloatingCloud> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: Duration(seconds: widget.duration))..repeat(reverse: true); 
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double xOffset = _controller.value * widget.driftRange;
        return Transform.translate(
          offset: Offset(xOffset, 0),
          child: Image.asset('assets/images/smallcloud1.png', width: 300, fit: BoxFit.contain),
        );
      },
    );
  }
}

class StarPainter extends CustomPainter {
  final double opacity;
  StarPainter(this.opacity);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.6 + (sin(opacity * pi) * 0.4));
    final random = Random(42); 
    for (int i = 0; i < 50; i++) {
      double x = random.nextDouble() * size.width;
      double y = random.nextDouble() * size.height * 0.6;
      double r = random.nextDouble() * 2 + 1;
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}