import 'package:flutter/material.dart';

enum AppSnackType { success, error, info }

void showAppSnack(
  BuildContext context,
  String message, {
  AppSnackType type = AppSnackType.info,
  Duration duration = const Duration(seconds: 2),
}) {
  final theme = Theme.of(context);
  final isLight = theme.brightness == Brightness.light;

  final background = theme.colorScheme.surface;
  Color foreground;

  switch (type) {
    case AppSnackType.success:
      foreground = const Color(0xFF2E7D32);
      break;
    case AppSnackType.error:
      foreground = const Color(0xFFC62828);
      break;
    case AppSnackType.info:
    default:
      foreground = theme.colorScheme.onSurface;
      if (!isLight) {
        foreground = theme.colorScheme.onSurface;
      }
      break;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: TextStyle(color: foreground, fontWeight: FontWeight.w600),
      ),
      backgroundColor: background,
      duration: duration,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
