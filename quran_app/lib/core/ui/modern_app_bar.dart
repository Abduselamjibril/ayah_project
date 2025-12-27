import 'dart:ui';
import 'package:flutter/material.dart';

/// A modern floating app bar with glassmorphic effect
class ModernFloatingAppBar extends StatelessWidget {
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final Widget? leading;
  final double elevation;
  final bool floating;
  final EdgeInsetsGeometry? margin;

  const ModernFloatingAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.actions,
    this.leading,
    this.elevation = 4.0,
    this.floating = true,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final container = Container(
      margin: margin ??
          EdgeInsets.only(
            left: floating ? 16 : 0,
            right: floating ? 16 : 0,
            top: floating ? 12 : 0,
          ),
      decoration: BoxDecoration(
        borderRadius: floating ? BorderRadius.circular(20) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: elevation * 2,
            offset: Offset(0, elevation),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: floating ? BorderRadius.circular(20) : BorderRadius.zero,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withOpacity(0.85),
              border: floating
                  ? Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.2),
                      width: 1.5,
                    )
                  : null,
              borderRadius: floating ? BorderRadius.circular(20) : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: titleWidget ??
                      Text(
                        title ?? '',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                ),
                if (actions != null) ...actions!,
              ],
            ),
          ),
        ),
      ),
    );

    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: 64,
        child: container,
      ),
    );
  }
}

/// A search bar variant of the modern app bar
class ModernSearchBar extends StatelessWidget {
  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final Widget? leading;
  final List<Widget>? actions;
  final bool autofocus;

  const ModernSearchBar({
    super.key,
    this.controller,
    this.hintText = 'Search...',
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.leading,
    this.actions,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withOpacity(0.9),
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.2),
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                if (leading != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: leading!,
                  ),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Icon(
                      Icons.search,
                      color: theme.colorScheme.primary,
                      size: 22,
                    ),
                  ),
                ],
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: controller,
                    autofocus: autofocus,
                    onChanged: onChanged,
                    onSubmitted: onSubmitted,
                    style: theme.textTheme.bodyLarge,
                    decoration: InputDecoration(
                      hintText: hintText,
                      border: InputBorder.none,
                      hintStyle: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                if (controller != null && controller!.text.isNotEmpty) ...[
                  IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: onClear ??
                        () {
                          controller!.clear();
                          onChanged?.call('');
                        },
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ],
                if (actions != null) ...actions!,
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
