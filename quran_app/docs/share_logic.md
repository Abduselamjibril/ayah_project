# Share Logic

This doc walks through the verse sharing flow (text and image), the UI entry points, and the render pipeline for the exported card.

## Entry point: share dialog

- `showSharePreviewDialog` shows a modal with two actions: Share Text / Share Image; it wires buttons to text/image flows and closes on success. See [lib/features/share/presentation/dialogs/share_preview_dialog.dart#L7-L176](lib/features/share/presentation/dialogs/share_preview_dialog.dart#L7-L176).
- Loading state: `_isSharing` disables the image button and shows a spinner while capture/share runs. See [lib/features/share/presentation/dialogs/share_preview_dialog.dart#L35-L120](lib/features/share/presentation/dialogs/share_preview_dialog.dart#L35-L120).

## Text share flow

- Implementation: [shareVerseText](lib/features/share/services/share_service.dart#L20-L36).
- Steps:
  - Resolve surah name and verse text via `getSurahName` and `getVerse`, including verse-end symbol. See [lib/features/share/services/share_service.dart#L25-L27](lib/features/share/services/share_service.dart#L25-L27).
  - Build message: `<Surah> (<surah>:<ayah>)`, verse text, "Shared via Ayah App", and a link (defaults to `defaultAppLink`). Joined with blank lines. See [lib/features/share/services/share_service.dart#L28-L33](lib/features/share/services/share_service.dart#L28-L33).
  - Invoke `Share.share` with the composed text. See [lib/features/share/services/share_service.dart#L35-L36](lib/features/share/services/share_service.dart#L35-L36).
- Defaults/constants: app name `Ayah App`, icon `assets/images/Icon.jpg`, link placeholder `https://app-link.example.com` (TODO to replace). See [lib/features/share/services/share_service.dart#L15-L18](lib/features/share/services/share_service.dart#L15-L18).

## Image share flow

- Implementation: [shareVerseImage](lib/features/share/services/share_service.dart#L38-L72).
- Inputs: `surahNumber`, `ayahNumber`, `ShareCardBackground background`, `size` (logical width/height), `isDark`, optional `appName`, `appIconAsset`, `frameAsset`, `pixelRatio` (defaults 2.0).
- Steps:
  - Render an off-screen `ShareCard` widget at requested `size` and `pixelRatio` using `ScreenshotController.captureFromWidget`. See [lib/features/share/services/share_service.dart#L49-L62](lib/features/share/services/share_service.dart#L49-L62).
  - Save bytes to a temp JPEG file named `ayah_<surah>_<ayah>.jpg`. See [lib/features/share/services/share_service.dart#L64-L66](lib/features/share/services/share_service.dart#L64-L66).
  - Share the file via `Share.shareXFiles`, with share text set to the surah reference. See [lib/features/share/services/share_service.dart#L68-L71](lib/features/share/services/share_service.dart#L68-L71).

## Dialog → image configuration

- The image button maps the current theme to a `ShareCardBackground` and darkness flag, then delegates to `shareVerseImage`. See [lib/features/share/presentation/dialogs/share_preview_dialog.dart#L38-L110](lib/features/share/presentation/dialogs/share_preview_dialog.dart#L38-L110).
- Theme mapping:
  - `goldenParchment`: solid `0xFFFFF4DA`, light text. See [lib/features/share/presentation/dialogs/share_preview_dialog.dart#L52-L55](lib/features/share/presentation/dialogs/share_preview_dialog.dart#L52-L55).
  - `midnightBlueprint`: solid `0xFF101417`, dark mode. See [lib/features/share/presentation/dialogs/share_preview_dialog.dart#L56-L59](lib/features/share/presentation/dialogs/share_preview_dialog.dart#L56-L59).
  - `mintGarden`: dark green vertical gradient; marked dark (comment notes alternative light option). See [lib/features/share/presentation/dialogs/share_preview_dialog.dart#L60-L85](lib/features/share/presentation/dialogs/share_preview_dialog.dart#L60-L85).
  - `ornateTwilight`: deep blue/green diagonal gradient, dark. See [lib/features/share/presentation/dialogs/share_preview_dialog.dart#L86-L97](lib/features/share/presentation/dialogs/share_preview_dialog.dart#L86-L97).
- Frame art: passes `ThemeService.mainframeImagePath` so the frame matches the active theme. See [lib/features/share/presentation/dialogs/share_preview_dialog.dart#L103-L109](lib/features/share/presentation/dialogs/share_preview_dialog.dart#L103-L109) and frame mapping in [lib/core/services/theme_service.dart#L15-L37](lib/core/services/theme_service.dart#L15-L37).
- Render size: 400 logical px with `pixelRatio` 3.0 for higher-resolution export. See [lib/features/share/presentation/dialogs/share_preview_dialog.dart#L101-L110](lib/features/share/presentation/dialogs/share_preview_dialog.dart#L101-L110).

## Share card layout

- Wrapper: `ShareCard` is a thin wrapper that forwards props to `ShareCardDesign`; accepts optional translation/reference text and frame asset overrides. See [lib/features/share/presentation/widgets/share_card.dart#L33-L76](lib/features/share/presentation/widgets/share_card.dart#L33-L76).
- Background API: `ShareCardBackground` supports solid colors, gradients, or image assets with optional overlay opacity to darken the image. See [lib/features/share/presentation/widgets/share_card.dart#L4-L31](lib/features/share/presentation/widgets/share_card.dart#L4-L31).
- Overall layout: `ShareCardDesign` builds a fixed-width card with background, optional image/overlay, padding proportional to size, and a column of header, body, footer. See [lib/features/share/presentation/widgets/share_card_design.dart#L7-L103](lib/features/share/presentation/widgets/share_card_design.dart#L7-L103).
  - Header: themed frame image plus centered surah number text (font `arsura`), scaled to container width. See [lib/features/share/presentation/widgets/share_card_design.dart#L106-L156](lib/features/share/presentation/widgets/share_card_design.dart#L106-L156).
  - Body: renders the Arabic verse via `QcfVerse`; optional translation text with 0.7 alpha; optional reference text (disabled in current usage). See [lib/features/share/presentation/widgets/share_card_design.dart#L158-L216](lib/features/share/presentation/widgets/share_card_design.dart#L158-L216).
  - Footer: app icon (30px, rounded) and faint app name label. See [lib/features/share/presentation/widgets/share_card_design.dart#L219-L256](lib/features/share/presentation/widgets/share_card_design.dart#L219-L256).
- Default frame if none provided: dark/light mainframe images keyed off `isDark`. See [lib/features/share/presentation/widgets/share_card_design.dart#L37-L41](lib/features/share/presentation/widgets/share_card_design.dart#L37-L41).

## Customization hooks

- Caller can override `appName`, `appIconAsset`, `frameAsset`, `translationText`, `referenceText`, `showReference`, `size`, and `pixelRatio` when invoking `shareVerseImage`. See [lib/features/share/presentation/widgets/share_card.dart#L38-L59](lib/features/share/presentation/widgets/share_card.dart#L38-L59) and [lib/features/share/services/share_service.dart#L38-L48](lib/features/share/services/share_service.dart#L38-L48).
- A custom `ShareCardBackground` lets the caller switch between solid/gradient/image backgrounds per theme or user choice.

## Notes and gaps

- `defaultAppLink` is a placeholder and should be replaced before production sharing. See [lib/features/share/services/share_service.dart#L17-L18](lib/features/share/services/share_service.dart#L17-L18).
- Current Mint Garden mapping uses a dark gradient despite the app theme being light; comments in code suggest reconsidering a light variant for consistency. See [lib/features/share/presentation/dialogs/share_preview_dialog.dart#L60-L85](lib/features/share/presentation/dialogs/share_preview_dialog.dart#L60-L85).
- The dialog shares immediately without previewing the generated image; if preview is required, hook the captured bytes before `Share.shareXFiles`.

## Full reference copies (for quick reapply if lost)

### lib/features/share/services/share_service.dart

```dart
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';

import 'package:quran_app/core/quran/qcf_quran.dart';
import 'package:quran_app/features/share/presentation/widgets/share_card.dart';

class ShareService {
  ShareService._();

  static final ShareService instance = ShareService._();

  static const String defaultAppName = 'Ayah App';
  static const String defaultAppIconAsset = 'assets/images/Icon.jpg';
  // TODO: Replace with the production app link once deployed.
  static const String defaultAppLink = 'https://app-link.example.com';

  Future<void> shareVerseText({
    required int surahNumber,
    required int ayahNumber,
    String? appLink,
  }) async {
    final surahName = getSurahName(surahNumber);
    final verseText = getVerse(surahNumber, ayahNumber, verseEndSymbol: true);
    final link = appLink ?? defaultAppLink;
    final text = [
      '$surahName ($surahNumber:$ayahNumber)',
      verseText,
      'Shared via Ayah App',
      link,
    ].join('\n\n');

    await Share.share(text);
  }

  Future<void> shareVerseImage({
    required int surahNumber,
    required int ayahNumber,
    required ShareCardBackground background,
    required double size,
    bool isDark = true,
    String? appName,
    String? appIconAsset,
    String? frameAsset,
    double pixelRatio = 2.0,
  }) async {
    final controller = ScreenshotController();
    final bytes = await controller.captureFromWidget(
      ShareCard(
        surahNumber: surahNumber,
        ayahNumber: ayahNumber,
        isDark: isDark,
        background: background,
        appName: appName ?? defaultAppName,
        appIconAsset: appIconAsset ?? defaultAppIconAsset,
        size: size,
        frameAsset: frameAsset,
      ),
      pixelRatio: pixelRatio,
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/ayah_${surahNumber}_$ayahNumber.jpg');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: '${getSurahName(surahNumber)} ($surahNumber:$ayahNumber)',
    );
  }
}
```

### lib/features/share/presentation/dialogs/share_preview_dialog.dart

```dart
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

  Future<void> _shareAsImage() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      // 1. Determine current theme from ThemeService
      final themeService = ThemeService();
      final currentTheme = themeService.currentTheme;

      // 2. Map AppTheme to ShareCardBackground and proper configuration
      ShareCardBackground background;
      bool isDark = true;

      switch (currentTheme) {
        case AppTheme.goldenParchment:
          background = ShareCardBackground.solid(const Color(0xFFFFF4DA));
          isDark = false;
          break;
        case AppTheme.midnightBlueprint:
          background = ShareCardBackground.solid(const Color(0xFF101417));
          isDark = true;
          break;
        case AppTheme.mintGarden:
          background = ShareCardBackground.gradient(
            const LinearGradient(
              colors: [Color(0xFF0B1A17), Color(0xFF1C3A2F)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          );
          isDark = true;
          break;
        case AppTheme.ornateTwilight:
          background = ShareCardBackground.gradient(
            const LinearGradient(
              colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          );
          isDark = true;
          break;
      }

      // 3. Trigger ShareService off-screen capture
      await ShareService.instance.shareVerseImage(
        surahNumber: widget.surahNumber,
        ayahNumber: widget.ayahNumber,
        background: background,
        isDark: isDark,
        size: 400,
        frameAsset: themeService.mainframeImagePath,
        pixelRatio: 3.0,
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
            const SizedBox(height: 24),
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
```

### lib/features/share/presentation/widgets/share_card.dart

```dart
import 'package:flutter/material.dart';
import 'package:quran_app/features/share/presentation/widgets/share_card_design.dart';

class ShareCardBackground {
  final Color? color;
  final Gradient? gradient;
  final String? imageAsset;
  final double overlayOpacity;

  const ShareCardBackground({
    this.color,
    this.gradient,
    this.imageAsset,
    this.overlayOpacity = 0,
  });

  factory ShareCardBackground.solid(Color color) =>
      ShareCardBackground(color: color);

  factory ShareCardBackground.gradient(Gradient gradient) =>
      ShareCardBackground(gradient: gradient);

  factory ShareCardBackground.image(
    String asset, {
    double overlayOpacity = 0.45,
  }) =>
      ShareCardBackground(
        imageAsset: asset,
        overlayOpacity: overlayOpacity,
      );
}

class ShareCard extends StatelessWidget {
  final int surahNumber;
  final int ayahNumber;
  final bool isDark;
  final ShareCardBackground background;
  final String appName;
  final String appIconAsset;
  final String? translationText;
  final String? referenceText;
  final bool showReference;
  final double size;
  final String? frameAsset;

  const ShareCard({
    super.key,
    required this.surahNumber,
    required this.ayahNumber,
    required this.isDark,
    required this.background,
    this.appName = 'Ayah App',
    this.appIconAsset = 'assets/images/Icon.jpg',
    this.translationText,
    this.referenceText,
    this.showReference = true,
    this.size = 1080,
    this.frameAsset,
  });

  @override
  Widget build(BuildContext context) {
    return ShareCardDesign(
      surahNumber: surahNumber,
      ayahNumber: ayahNumber,
      isDark: isDark,
      background: background,
      appName: appName,
      appIconAsset: appIconAsset,
      translationText: translationText,
      referenceText: referenceText,
      showReference: showReference,
      size: size,
      frameAsset: frameAsset,
    );
  }
}
```

### lib/features/share/presentation/widgets/share_card_design.dart

```dart
import 'package:flutter/material.dart';
import 'package:quran_app/core/quran/qcf_quran.dart';
import 'package:quran_app/core/quran/widgets/qcf_verse.dart';

import 'share_card.dart';

class ShareCardDesign extends StatelessWidget {
  final int surahNumber;
  final int ayahNumber;
  final bool isDark;
  final ShareCardBackground background;
  final String appName;
  final String appIconAsset;
  final String? frameAsset;
  final String? translationText;
  final String? referenceText;
  final bool showReference;
  final double size;

  const ShareCardDesign({
    super.key,
    required this.surahNumber,
    required this.ayahNumber,
    required this.isDark,
    required this.background,
    required this.appName,
    required this.appIconAsset,
    required this.translationText,
    required this.referenceText,
    required this.showReference,
    required this.size,
    this.frameAsset,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : Colors.black;
    final effectiveFrameAsset = frameAsset ??
        (isDark
            ? 'assets/images/mainframe_dark.png'
            : 'assets/images/mainframe.png');
    final safePadding = size * 0.025;

    return SizedBox(
      width: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background.color ?? (isDark ? const Color(0xFF101417) : null),
          gradient: background.gradient,
        ),
        child: Stack(
          children: [
            if (background.imageAsset != null)
              Positioned.fill(
                child: Image.asset(
                  background.imageAsset!,
                  fit: BoxFit.cover,
                ),
              ),
            if (background.overlayOpacity > 0)
              Positioned.fill(
                child: Container(
                  color:
                      Colors.black.withValues(alpha: background.overlayOpacity),
                ),
              ),
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: safePadding, vertical: safePadding * 0.8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SurahHeader(
                    frameAsset: effectiveFrameAsset,
                    surahNumber: surahNumber,
                    size: size,
                    textColor: textColor,
                  ),
                  const SizedBox(height: 0),
                  Transform.translate(
                    offset: Offset(0, -size * 0.03),
                    child: _AyahBody(
                      surahNumber: surahNumber,
                      ayahNumber: ayahNumber,
                      translationText: translationText,
                      textColor: textColor,
                      isDark: isDark,
                      showReference: false,
                      referenceText: '',
                    ),
                  ),
                  const SizedBox(height: 18),
                  _ShareFooter(
                    appName: appName,
                    appIconAsset: appIconAsset,
                    textColor: textColor,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SurahHeader extends StatelessWidget {
  final String frameAsset;
  final int surahNumber;
  final double size;
  final Color textColor;

  const _SurahHeader({
    required this.frameAsset,
    required this.surahNumber,
    required this.size,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final imageWidth = constraints.maxWidth;
        final fontSize = 37 * (imageWidth / 430);

        return SizedBox(
          height: imageWidth * 0.22,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.asset(
                frameAsset,
                width: imageWidth,
                fit: BoxFit.contain,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 0),
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    text: '$surahNumber',
                    style: TextStyle(
                      fontFamily: 'arsura',
                      fontSize: fontSize,
                      color: textColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AyahBody extends StatelessWidget {
  final int surahNumber;
  final int ayahNumber;
  final String? translationText;
  final Color textColor;
  final bool isDark;
  final String referenceText;
  final bool showReference;

  const _AyahBody({
    required this.surahNumber,
    required this.ayahNumber,
    required this.translationText,
    required this.textColor,
    required this.isDark,
    required this.referenceText,
    required this.showReference,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        QcfVerse(
          surahNumber: surahNumber,
          verseNumber: ayahNumber,
          textColor: textColor,
          fontSize: 23,
        ),
        if (translationText != null) ...[
          const SizedBox(height: 8),
          Text(
            translationText!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: textColor.withValues(alpha: 0.7),
            ),
          ),
        ],
        if (showReference) ...[
          const SizedBox(height: 8),
          Text(
            referenceText,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              letterSpacing: 0.4,
              color: textColor.withValues(alpha: 0.75),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

class _ShareFooter extends StatelessWidget {
  final String appName;
  final String appIconAsset;
  final Color textColor;

  const _ShareFooter({
    required this.appName,
    required this.appIconAsset,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            appIconAsset,
            width: 30,
            height: 30,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          appName,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: textColor.withValues(alpha: 0.3),
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}
```
