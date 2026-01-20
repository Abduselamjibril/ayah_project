import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:quran_app/core/quran/qcf_quran.dart';
import 'package:quran_app/features/share/presentation/widgets/share_card.dart';

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
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  bool _isSharing = false;

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

  Future<void> _shareAsImage() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      final boundary = _repaintBoundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      // Capture at high resolution (3x for quality)
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/ayah_${widget.surahNumber}_${widget.ayahNumber}.jpg');
      await file.writeAsBytes(pngBytes);

      final surahName = getSurahName(widget.surahNumber);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '$surahName (${widget.surahNumber}:${widget.ayahNumber})',
      );

      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  Future<void> _shareAsText() async {
    final surahName = getSurahName(widget.surahNumber);
    final verseText =
        getVerse(widget.surahNumber, widget.ayahNumber, verseEndSymbol: true);
    const appLink = 'https://app-link.example.com';
    final text = [
      '$surahName (${widget.surahNumber}:${widget.ayahNumber})',
      verseText,
      'Shared via Ayah App',
      appLink,
    ].join('\n\n');

    await Share.share(text);

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

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
                child: RepaintBoundary(
                  key: _repaintBoundaryKey,
                  child: ShareCard(
                    surahNumber: widget.surahNumber,
                    ayahNumber: widget.ayahNumber,
                    isDark: preset.isDark,
                    background: preset.background,
                    size: previewSize,
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
                      onPressed: _shareAsText,
                      child: const Text('Share Text'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isSharing ? null : _shareAsImage,
                      child: _isSharing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Share Image'),
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
