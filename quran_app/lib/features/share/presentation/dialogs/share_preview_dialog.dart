import 'package:flutter/material.dart';

import 'package:quran_app/core/services/theme_service.dart';
import 'package:quran_app/features/share/presentation/widgets/share_card.dart';
import 'package:quran_app/features/share/services/share_service.dart';

Future<void> showSharePreviewDialog({
  required BuildContext context,
  required int surahNumber,
  required int ayahNumber,
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => ShareOptionsDialog(
      surahNumber: surahNumber,
      ayahNumber: ayahNumber,
    ),
  );
}

class ShareOptionsDialog extends StatefulWidget {
  final int surahNumber;
  final int ayahNumber;

  const ShareOptionsDialog({
    super.key,
    required this.surahNumber,
    required this.ayahNumber,
  });

  @override
  State<ShareOptionsDialog> createState() => _ShareOptionsDialogState();
}

class _ShareOptionsDialogState extends State<ShareOptionsDialog> {
  bool _isSharing = false;

  // Toggles
  bool _showSurahName = true;
  bool _showPageNumber = false;

  // Range (future proofing, currently defaults to single)
  int? _endAyahNumber;

  Future<void> _shareAsImage() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      // 1. Determine current theme from ThemeService
      final themeService = ThemeService();
      final brightness = Theme.of(context).brightness;
      final isDarkMode = brightness == Brightness.dark;

      // 2. Map AppTheme to ShareCardBackground and proper configuration
      ShareCardBackground background;

      if (isDarkMode) {
        // "Night Blue" preset vibe
        background = ShareCardBackground.gradient(
          const LinearGradient(
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        );
      } else {
        background = ShareCardBackground.solid(const Color(0xFFFFF4DA));
      }

      // 3. Trigger ShareService off-screen capture
      // We use size: 400 to mimic a phone width layout, preventing fonts from looking too small
      await ShareService.instance.shareVerseImage(
        surahNumber: widget.surahNumber,
        ayahNumber: widget.ayahNumber,
        background: background,
        isDark: isDarkMode,
        size: 400,
        frameAsset: themeService.getResponsiveMainframePath(brightness),
        showSurahName: _showSurahName,
        showPageNumber: _showPageNumber,
        endAyahNumber: _endAyahNumber,
        pixelRatio: 3.0, // High resolution output
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
    await ShareService.instance.shareVerseText(
      surahNumber: widget.surahNumber,
      ayahNumber: widget.ayahNumber,
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Share Verse',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Options
            SwitchListTile(
              title: const Text('Show Surah Name'),
              value: _showSurahName,
              onChanged: (val) => setState(() => _showSurahName = val),
              dense: true,
            ),
            SwitchListTile(
              title: const Text('Show Page Number'),
              value: _showPageNumber,
              onChanged: (val) => setState(() => _showPageNumber = val),
              dense: true,
            ),

            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _ShareOptionButton(
                    icon: Icons.text_fields,
                    label: 'Share Text',
                    onTap: _shareAsText,
                    isOutlined: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _ShareOptionButton(
                    icon: Icons.image,
                    label: 'Share Image',
                    isLoading: _isSharing,
                    onTap: _isSharing ? null : _shareAsImage,
                    isOutlined: false,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareOptionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isOutlined;
  final bool isLoading;

  const _ShareOptionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isOutlined,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );

    if (isLoading) {
      return FilledButton(
        onPressed: null,
        style: style,
        child: const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }

    if (isOutlined) {
      return OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }

    return FilledButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
      style: style,
    );
  }
}
