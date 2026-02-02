import 'package:flutter/cupertino.dart'; // Required for the Wheel Picker
import 'package:flutter/material.dart';
import 'package:quran_app/core/utils/localization_helper.dart';
import 'package:quran_app/features/share/services/share_service.dart';
import 'package:quran_app/app/app.dart';
// Assuming this is where verse count logic lives,
// if not, replace with your app's specific verse count utility
import 'package:quran_app/core/quran/qcf_quran.dart';

enum _ShareFormat { image, text, textWithoutDiacritics }

class ShareOptionsSheet extends StatefulWidget {
  final int surah;
  final int verse;
  final VoidCallback? onBackToVerseOptions;

  const ShareOptionsSheet({
    super.key,
    required this.surah,
    required this.verse,
    this.onBackToVerseOptions,
  });

  @override
  State<ShareOptionsSheet> createState() => _ShareOptionsSheetState();
}

class _ShareOptionsSheetState extends State<ShareOptionsSheet> {
  late _ShareFormat format;
  late int fromVerse;
  late int toVerse;
  late bool includeBadge;
  late bool isSharing;

  // Picker Toggles
  bool showFromPicker = false;
  bool showToPicker = false;
  int totalVerses = 0;

  @override
  void initState() {
    super.initState();
    format = _ShareFormat.image;
    fromVerse = widget.verse;
    toVerse = widget.verse;
    includeBadge = true;
    isSharing = false;

    // Use the correct function for QCF Quran utility
    totalVerses = getVerseCount(widget.surah);
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _handleShare() async {
    if (isSharing) return;
    setState(() => isSharing = true);
    try {
      if (format == _ShareFormat.image) {
        final shareTheme = ShareService.resolveShareCardTheme(context);
        await ShareService.instance.shareVerseImage(
          surahNumber: widget.surah,
          ayahNumber: fromVerse,
          endAyahNumber: toVerse,
          background: shareTheme.background,
          isDark: shareTheme.isDark,
          frameAsset: shareTheme.frameAsset,
          showSurahName: false,
          showPageNumber: true,
          showBadge: includeBadge,
          size: 1080,
          pixelRatio: 2.5,
        );
      } else {
        await ShareService.instance.shareVerseText(
          surahNumber: widget.surah,
          ayahNumber: fromVerse,
          endAyahNumber: toVerse,
          stripDiacritics: format == _ShareFormat.textWithoutDiacritics,
          includeSurahName: false,
          includeReference: true,
          includeBadge: includeBadge,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showSnack('Could not share: $e');
    } finally {
      if (mounted) {
        setState(() => isSharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark ? Colors.black : const Color(0xFFF2F2F7);
    final cardColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final dividerColor =
        isDark ? const Color(0xFF38383A) : Colors.grey.shade300;
    final accentColor = BrandColors.accent;

    final verseCount = (toVerse - fromVerse + 1);
    final verseCountLabel = verseCount == 1 ? '1 Verse' : '$verseCount Verses';

    final bilingualName = getBilingualSurahName(context, widget.surah);
    final englishSurahName = bilingualName.split(' / ').first;
    // Removed verseReference from top bar

    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Center(
                    child: Text(
                      'Share',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: Icon(Icons.chevron_left,
                          color: accentColor, size: 28),
                      onPressed: () {
                        if (widget.onBackToVerseOptions != null) {
                          widget.onBackToVerseOptions!();
                        } else {
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: CircleAvatar(
                          radius: 15,
                          backgroundColor:
                              isDark ? Colors.white10 : Colors.black12,
                          child: Icon(Icons.close,
                              size: 18,
                              color: isDark ? Colors.white60 : Colors.black54),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('SHARE AS'),
                    _buildCardWrapper(
                      cardColor,
                      [
                        _buildShareAsOption('Image', _ShareFormat.image),
                        Divider(height: 1, indent: 16, color: dividerColor),
                        _buildShareAsOption('Text', _ShareFormat.text),
                        Divider(height: 1, indent: 16, color: dividerColor),
                        _buildShareAsOption('Text Without Diacritics',
                            _ShareFormat.textWithoutDiacritics),
                      ],
                    ),
                    _buildSectionHeader('RANGE'),
                    _buildCardWrapper(
                      cardColor,
                      [
                        _buildRangeItem(
                          'From',
                          '$englishSurahName: $fromVerse',
                          accentColor,
                          isActive: showFromPicker,
                          onTap: () => setState(() {
                            showFromPicker = !showFromPicker;
                            showToPicker = false;
                          }),
                        ),
                        if (showFromPicker)
                          _buildInlinePicker(
                              isFrom: true, englishName: englishSurahName),
                        Divider(height: 1, indent: 16, color: dividerColor),
                        _buildRangeItem(
                          'To',
                          '$englishSurahName: $toVerse',
                          accentColor,
                          isActive: showToPicker,
                          onTap: () => setState(() {
                            showToPicker = !showToPicker;
                            showFromPicker = false;
                          }),
                        ),
                        if (showToPicker)
                          _buildInlinePicker(
                              isFrom: false, englishName: englishSurahName),
                      ],
                    ),
                    _buildSectionHeader('APP BADGE'),
                    _buildCardWrapper(
                      cardColor,
                      [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Add App Badge',
                                  style: TextStyle(fontSize: 17)),
                              Switch.adaptive(
                                value: includeBadge,
                                onChanged: (v) =>
                                    setState(() => includeBadge = v),
                                activeColor: accentColor,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 34),
              decoration: BoxDecoration(
                color: bgColor,
                border:
                    Border(top: BorderSide(color: dividerColor, width: 0.5)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isSharing ? null : _handleShare,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isSharing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text('Share $verseCountLabel',
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
            color: Colors.grey, fontWeight: FontWeight.w700, fontSize: 14),
      ),
    );
  }

  Widget _buildCardWrapper(Color color, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildRangeItem(String label, String value, Color accent,
      {required bool isActive, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
            Text(value,
                style: TextStyle(
                    color: accent, fontSize: 17, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildInlinePicker(
      {required bool isFrom, required String englishName}) {
    int min, max, initial;
    if (isFrom) {
      min = 1;
      max = toVerse;
      initial = fromVerse < min ? min : (fromVerse > max ? max : fromVerse);
    } else {
      min = fromVerse;
      max = totalVerses;
      initial = toVerse < min ? min : (toVerse > max ? max : toVerse);
    }
    return SizedBox(
      height: 180,
      child: CupertinoPicker(
        scrollController: FixedExtentScrollController(
          initialItem: initial - min,
        ),
        itemExtent: 40,
        selectionOverlay: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onSelectedItemChanged: (index) {
          setState(() {
            int newVerse = min + index;
            if (isFrom) {
              fromVerse = newVerse;
              if (fromVerse > toVerse) toVerse = fromVerse;
            } else {
              toVerse = newVerse;
              if (toVerse < fromVerse) fromVerse = toVerse;
            }
          });
        },
        children: List.generate(max - min + 1, (index) {
          int verseNum = min + index;
          return Center(
            child: Text(
              "$englishName: $verseNum",
              style: const TextStyle(fontSize: 19, color: Colors.white),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildShareAsOption(String title, _ShareFormat value) {
    bool isSelected = format == value;
    return InkWell(
      onTap: () => setState(() => format = value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
            if (isSelected)
              const Icon(Icons.check, color: Colors.green, size: 22),
          ],
        ),
      ),
    );
  }
}
