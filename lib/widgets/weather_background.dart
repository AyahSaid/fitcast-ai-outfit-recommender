// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../utils/background_manager.dart';
import 'floating_star.dart';
import 'floating_cloud.dart';
import 'dart:math' as math; // Added for randomness

class WeatherBackground extends StatefulWidget {
  final Widget? child;
  final String? condition;

  const WeatherBackground({super.key, this.child, this.condition});

  @override
  State<WeatherBackground> createState() => _WeatherBackgroundState();
}

class _WeatherBackgroundState extends State<WeatherBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Default duration; this will be overridden in the build method
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final currentPeriod = BackgroundManager.getTimePeriod();
    final basePath = "assets/images/Suggestion_bg/$currentPeriod/";
    final bool isDay = currentPeriod == "morning_bg" || currentPeriod == "sunrise_bg";
    
    final cond = widget.condition?.toLowerCase() ?? "";

    // 🕒 Logic to slow down snow specifically
    // Rain is faster (3s), Snow is slow and drifty (7s)
    Duration targetDuration = cond.contains("snow") 
        ? const Duration(seconds: 7) 
        : const Duration(seconds: 3);

    // Only update and repeat if the duration has actually changed
    if (_controller.duration != targetDuration) {
      _controller.duration = targetDuration;
      if (_controller.isAnimating) {
        _controller.repeat();
      }
    }

    return Container(
      width: screenWidth,
      height: screenHeight,
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ⭐ 1) SKY
          Image.asset(
            basePath + _getBackgroundFile(currentPeriod),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),

          // ⭐ 2) CLOUDS
          if (isDay) ...[
            _buildCloud(screenHeight * 0.08, screenWidth * 0.12, 18),
            _buildCloud(screenHeight * 0.04, screenWidth * 0.60, 18),
            _buildCloud(screenHeight * 0.15, null, 10, right: screenWidth * 0.65),
            _buildCloud(screenHeight * 0.12, screenWidth * 0.65, 35),
          ],

          // ⭐ 3) WEATHER EFFECTS (MIDDLE LAYER)
          // Rain / Drizzle / Thunderstorm
          if (cond.contains("rain") || cond.contains("drizzle") || cond.contains("thunderstorm"))
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => CustomPaint(
                painter: RainPainter(_controller.value),
              ),
            ),

          // Snow
          if (cond.contains("snow"))
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => CustomPaint(
                painter: SnowPainter(_controller.value),
              ),
            ),

          // ⭐ 4) WINDOW + HILLS (FOREGROUND)
          Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: screenWidth,
              height: screenHeight,
              child: FittedBox(
                fit: BoxFit.fill,
                alignment: Alignment.bottomCenter,
                child: Transform.scale(
                  scaleY: _getHillsScale(currentPeriod),
                  alignment: Alignment.bottomCenter,
                  child: Image.asset(basePath + _getHillsFile(currentPeriod)),
                ),
              ),
            ),
          ),

          // ⭐ 5) NIGHT ELEMENTS
          if (currentPeriod == "night_bg") ...[
            Positioned(top: screenHeight * 0.07, right: 40, child: Image.asset("${basePath}moon.png", width: screenWidth * 0.25)),
            Positioned(top: screenHeight * 0.13, left: 35, child: FloatingStar("${basePath}star1.png")),
            Positioned(top: screenHeight * 0.18, right: 70, child: FloatingStar("${basePath}star2.png")),
            Positioned(top: screenHeight * 0.27, left: 120, child: FloatingStar("${basePath}star1.png")),
          ],

          if (widget.child != null) widget.child!,
        ],
      ),
    );
  }

  Widget _buildCloud(double top, double? left, int seconds, {double? right}) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      child: FloatingCloud(
        "assets/images/smallcloud1.png",
        width: 90,
        duration: Duration(seconds: seconds),
        movement: const Offset(10, 2),
      ),
    );
  }

  // --- Helpers ---
  double _getHillsScale(String p) => (p == "sunrise_bg") ? 1.11 : (p == "sunset_bg") ? 1.10 : 1.0;
  String _getBackgroundFile(String p) => "${p}.png";
  String _getHillsFile(String p) => "${p.split('_')[0]}_hills.png";
}

//------------------------------------------------------------
// ⭐ PAINTERS
//------------------------------------------------------------

class RainPainter extends CustomPainter {
  final double animationValue;
  RainPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 60; i++) {
      double scatter = (math.sin(i.toDouble() * 1234.5) * 0.5 + 0.5); 
      double x = (size.width * scatter);
      double verticalOffset = (math.cos(i.toDouble() * 567.8) * 0.5 + 0.5);
      double y = (size.height * (animationValue + verticalOffset)) % size.height;

      canvas.drawLine(Offset(x, y), Offset(x - 0.5, y + 15), paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class SnowPainter extends CustomPainter {
  final double animationValue;
  SnowPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.7);

    for (int i = 0; i < 50; i++) {
      double scatter = (math.sin(i.toDouble() * 999.9) * 0.5 + 0.5);
      double verticalOffset = (math.cos(i.toDouble() * 444.4) * 0.5 + 0.5);
      
      // Keep the smooth horizontal sway
      double sway = math.sin(animationValue * 6.28 + i) * 10;
      double x = (size.width * scatter + sway) % size.width;
      double y = (size.height * (animationValue + verticalOffset)) % size.height;

      canvas.drawCircle(Offset(x, y), 2.2, paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}