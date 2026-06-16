// ignore_for_file: deprecated_member_use

import 'dart:math';
import 'package:flutter/material.dart';

// 1. The Data Class for a single drop/snowflake
class WeatherParticle {
  double x;
  double y;
  double speed;
  double size;
  double opacity;

  WeatherParticle({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.opacity,
  });
}

// 2. The Master Painter that draws everything
class WeatherEffectPainter extends CustomPainter {
  final List<WeatherParticle> particles;
  final String type; // "rain" or "snow"
  final double windSpeed; // -1.0 to 1.0 (negative = left, positive = right)

  WeatherEffectPainter({
    required this.particles,
    required this.type,
    this.windSpeed = 0.2, // Default slight breeze
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    for (var particle in particles) {
      // Update Position (Move down)
      particle.y += particle.speed;
      
      // Apply Wind (Move sideways)
      particle.x += windSpeed * (type == "rain" ? 2.0 : 0.5); // Rain is heavier/faster

      // Recycle: If particle goes off screen, reset to top
      if (particle.y > size.height) {
        particle.y = -10.0;
        particle.x = Random().nextDouble() * size.width;
      }
      // Recycle: If particle goes off side due to wind, wrap around
      if (particle.x > size.width) particle.x = 0;
      if (particle.x < 0) particle.x = size.width;

      // Draw based on type
      if (type == "rain") {
        _drawRainDrop(canvas, particle, paint);
      } else if (type == "snow") {
        _drawSnowFlake(canvas, particle, paint);
      }
    }
  }

  void _drawRainDrop(Canvas canvas, WeatherParticle p, Paint paint) {
    paint.color = Colors.white.withOpacity(0.4);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.5;

    // Draw line with slight slant based on wind
    double slant = windSpeed * 5; 
    canvas.drawLine(
      Offset(p.x, p.y),
      Offset(p.x + slant, p.y + p.size), // p.size is length of drop
      paint,
    );
  }

  void _drawSnowFlake(Canvas canvas, WeatherParticle p, Paint paint) {
    paint.color = Colors.white.withOpacity(p.opacity);
    paint.style = PaintingStyle.fill;
    
    // Draw soft circle
    canvas.drawCircle(Offset(p.x, p.y), p.size, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true; // Always repaint for animation
}