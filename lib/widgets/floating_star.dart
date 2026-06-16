import 'package:flutter/material.dart';

class FloatingStar extends StatefulWidget {
  final String assetPath;
  final double size;
  final Duration duration;

  const FloatingStar(
    this.assetPath, {
    super.key,
    this.size = 26,
    this.duration = const Duration(seconds: 2),
  });

  @override
  State<FloatingStar> createState() => _FloatingStarState();
}

class _FloatingStarState extends State<FloatingStar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(reverse: true); // up-down-up-down forever

    _animation = Tween<double>(begin: -6, end: 6).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: Image.asset(
            widget.assetPath,
            width: widget.size,
            height: widget.size,
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
