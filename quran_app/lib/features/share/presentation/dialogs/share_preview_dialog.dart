import 'package:flutter/material.dart';

import 'package:quran_app/features/share/presentation/widgets/share_card.dart';
import 'package:quran_app/features/share/services/share_service.dart';

class ShareThemePreset {
  final String label;
  final ShareCardBackground background;
  final bool isDark;

  const ShareThemePreset({
    required this.label,
    required this.background,
    required this.isDark,
  });
}

Future<void> showSharePreviewDialog({
  required BuildContext context,
  required int surahNumber,
  required int ayahNumber,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => SharePreviewDialog(
      surahNumber: surahNumber,
      ayahNumber: ayahNumber,
    ),
  );
}

class SharePreviewDialog extends StatefulWidget {
  final int surahNumber;
  final int ayahNumber;

  const SharePreviewDialog({
    super.key,
    required this.surahNumber,
    required this.ayahNumber,
  });

  @override
  State<SharePreviewDialog> createState() => _SharePreviewDialogState();
}

class _SharePreviewDialogState extends State<SharePreviewDialog> {
  int _selected = 0;

  late final List<ShareThemePreset> _presets = [
    ShareThemePreset(
      label: 'Night Blue',
      isDark: true,
      background: ShareCardBackground.gradient(
        LinearGradient(
          colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    ),
    ShareThemePreset(
      label: 'Midnight',
      isDark: true,
      background: ShareCardBackground.solid(Color(0xFF101417)),
    ),
    ShareThemePreset(
      label: 'Olive',
      isDark: true,
      background: ShareCardBackground.gradient(
        LinearGradient(
          colors: [Color(0xFF0B1A17), Color(0xFF1C3A2F)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    ),
    ShareThemePreset(
      label: 'Parchment',
      isDark: false,
      background: ShareCardBackground.solid(Color(0xFFFFF4DA)),
    ),
    ShareThemePreset(
      label: 'Desert',
      isDark: false,
      background: ShareCardBackground.gradient(
        LinearGradient(
          colors: [Color(0xFFFFE9C2), Color(0xFFF7DDB4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final preset = _presets[_selected];
    final screenWidth = MediaQuery.sizeOf(context).width;
    final previewSize = screenWidth < 520 ? screenWidth - 48 : 520.0;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                constraints: BoxConstraints(
                  maxWidth: previewSize,
                  maxHeight: MediaQuery.sizeOf(context).height * 0.6,
                ),
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: ShareCard(
                    surahNumber: widget.surahNumber,
                    ayahNumber: widget.ayahNumber,
                    isDark: preset.isDark,
                    background: preset.background,
                    size: 1400,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Themes',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_presets.length, (index) {
                  final item = _presets[index];
                  final isSelected = index == _selected;
                  return ChoiceChip(
                    label: Text(item.label),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selected = index),
                  );
                }),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final navigator = Navigator.of(context);
                        await ShareService.instance.shareVerseText(
                          surahNumber: widget.surahNumber,
                          ayahNumber: widget.ayahNumber,
                        );
                        if (navigator.mounted) {
                          navigator.pop();
                        }
                      },
                      child: const Text('Share Text'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        final navigator = Navigator.of(context);
                        await ShareService.instance.shareVerseImage(
                          surahNumber: widget.surahNumber,
                          ayahNumber: widget.ayahNumber,
                          background: preset.background,
                          isDark: preset.isDark,
                        );
                        if (navigator.mounted) {
                          navigator.pop();
                        }
                      },
                      child: const Text('Share Image'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
