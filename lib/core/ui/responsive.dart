import 'package:flutter/widgets.dart';

/// Lightweight responsive helpers to scale UI for phones and tablets while
/// keeping the original layout proportions intact.
class ResponsiveLayout {
  /// Base logical width the UI was originally designed for (roughly iPhone 12).
  static const double _designWidth = 390.0;

  /// Returns a clamped scale factor based on the current shortest side.
  /// Keeps the scale between [minScale, maxScale] to avoid extreme jumps.
  static double scaleForWidth(
    BuildContext context, {
    double minScale = 0.9,
    double maxScale = 1.15,
  }) {
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    final raw = shortestSide / _designWidth;
    return raw.clamp(minScale, maxScale);
  }

  /// Scales a raw size using [scaleForWidth] while optionally clamping output.
  static double scaled(
    BuildContext context,
    double base, {
    double? min,
    double? max,
    double minScale = 0.9,
    double maxScale = 1.15,
  }) {
    final factor = scaleForWidth(
      context,
      minScale: minScale,
      maxScale: maxScale,
    );
    double value = base * factor;
    if (min != null) value = value < min ? min : value;
    if (max != null) value = value > max ? max : value;
    return value;
  }

  /// Helper for symmetric insets that scale gently with screen width.
  static EdgeInsets scaledSymmetric(
    BuildContext context, {
    double horizontal = 0,
    double vertical = 0,
  }) {
    final factor = scaleForWidth(context);
    return EdgeInsets.symmetric(
      horizontal: horizontal * factor,
      vertical: vertical * factor,
    );
  }
}
