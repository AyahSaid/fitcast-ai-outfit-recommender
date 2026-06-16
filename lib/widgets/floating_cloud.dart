import 'package:flutter/material.dart';

class FloatingCloud extends StatefulWidget {
  final String assetPath;
  final double width;
  final Duration duration;

  /// How far the cloud moves (pixels)
  final Offset movement;

  final double opacity;

  const FloatingCloud(
    this.assetPath, {
    super.key,
    this.width = 120,
    this.duration = const Duration(seconds: 0),
    this.movement = const Offset(4, 1),
    this.opacity = 0.85,
  });

  @override
  State<FloatingCloud> createState() => _FloatingCloudState();
}

class _FloatingCloudState extends State<FloatingCloud>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _animation;

  @override
  void initState() {
    super.initState();

    // Slow back-and-forth drift (needed for visibility)
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(reverse: true);

    // Move from -movement → +movement
    _animation = Tween<Offset>(
      begin: Offset(
        -widget.movement.dx,
        -widget.movement.dy,
      ),
      end: Offset(
        widget.movement.dx,
        widget.movement.dy,
      ),
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutSine, // soft + natural
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) {
        return Transform.translate(
          offset: _animation.value,
          child: child,
        );
      },
      child: Opacity(
        opacity: widget.opacity,
        child: Image.asset(
          widget.assetPath,
          width: widget.width,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
