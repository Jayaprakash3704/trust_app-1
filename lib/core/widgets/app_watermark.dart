import 'package:flutter/material.dart';

class AppWatermark extends StatefulWidget {
  const AppWatermark({super.key});

  @override
  State<AppWatermark> createState() => _AppWatermarkState();
}

class _AppWatermarkState extends State<AppWatermark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  late final Animation<double> _scale = Tween<double>(
    begin: 0.98,
    end: 1.05,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  late final Animation<double> _opacity = Tween<double>(
    begin: 0.05,
    end: 0.1,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final baseSize = constraints.biggest.shortestSide * 0.85;
          final dimension = baseSize.clamp(220.0, 560.0).toDouble();
          return Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: _opacity.value,
                  child: Transform.scale(scale: _scale.value, child: child),
                );
              },
              child: Image.asset(
                'assets/images/app_logo.png',
                width: dimension,
                height: dimension,
                fit: BoxFit.contain,
              ),
            ),
          );
        },
      ),
    );
  }
}
