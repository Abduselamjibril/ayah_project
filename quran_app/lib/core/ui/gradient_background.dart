import 'package:flutter/material.dart';

/// A themed gradient background widget
class GradientBackground extends StatelessWidget {
  final Widget child;
  final List<Color>? colors;
  final AlignmentGeometry begin;
  final AlignmentGeometry end;

  const GradientBackground({
    super.key,
    required this.child,
    this.colors,
    this.begin = Alignment.topLeft,
    this.end = Alignment.bottomRight,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultColors = [
      theme.scaffoldBackgroundColor,
      theme.colorScheme.surface,
    ];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors ?? defaultColors,
          begin: begin,
          end: end,
        ),
      ),
      child: child,
    );
  }
}

/// A subtle animated gradient background
class AnimatedGradientBackground extends StatefulWidget {
  final Widget child;
  final List<Color> colors;
  final Duration duration;

  const AnimatedGradientBackground({
    super.key,
    required this.child,
    required this.colors,
    this.duration = const Duration(seconds: 3),
  });

  @override
  State<AnimatedGradientBackground> createState() =>
      _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState extends State<AnimatedGradientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat(reverse: true);
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
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.colors,
              begin: Alignment.lerp(
                Alignment.topLeft,
                Alignment.topRight,
                _controller.value,
              )!,
              end: Alignment.lerp(
                Alignment.bottomRight,
                Alignment.bottomLeft,
                _controller.value,
              )!,
            ),
          ),
          child: widget.child,
        );
      },
    );
  }
}
