import 'package:flutter/material.dart';
import '../../../../core/quran/qcf_quran.dart';
import '../../../../core/services/audio_player_service.dart';
import 'package:quran_app/core/i18n/app_localizations.dart';
import 'package:quran_app/core/utils/localization_helper.dart';
import 'package:quran_app/app/app.dart'; // For BrandColors

class PlayRangeDialog extends StatefulWidget {
  final int startSurah;
  final int startVerse;

  const PlayRangeDialog({
    super.key,
    required this.startSurah,
    required this.startVerse,
  });

  @override
  State<PlayRangeDialog> createState() => _PlayRangeDialogState();
}

class _PlayRangeDialogState extends State<PlayRangeDialog> {
  int _selectedTabIndex = 0; // 0: Verse, 1: Page, 2: Surah
  late int _currentPage;
  late int _endOfSurah;

  @override
  void initState() {
    super.initState();
    _currentPage = getPageNumber(widget.startSurah, widget.startVerse);
    _endOfSurah = getVerseCount(widget.startSurah);
  }

  void _playTo(int endSurah, int endAyah) {
    Navigator.pop(context);
    AudioPlayerService.instance.playRangeSequenceWithDownload(
      context,
      startSurah: widget.startSurah,
      startAyah: widget.startVerse,
      endSurah: endSurah,
      endAyah: endAyah,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.9,
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                // 1. Custom Header matching Screenshot
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios,
                            size: 18, color: BrandColors.accent),
                        label: Text(
                          '${getBilingualSurahName(context, widget.startSurah)}: ${widget.startVerse}',
                          style: const TextStyle(
                            color: BrandColors.accent,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const Expanded(
                        child: Center(
                          child: Text(
                            "Play To",
                            style: TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 18),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isLight
                                ? theme.colorScheme.surfaceContainerHighest
                                : theme.colorScheme.onSurface.withOpacity(0.1),
                          ),
                          child: Icon(
                            Icons.close,
                            size: 20,
                            color: isLight
                                ? theme.colorScheme.onSurface.withOpacity(0.7)
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),

                        // 2. Quick Actions Card
                        _buildQuickActionsBox(theme),

                        const SizedBox(height: 24),

                        // 3. Segmented Toggle Tab Bar
                        _buildSegmentedControl(theme),

                        const SizedBox(height: 16),

                        // 4. Dynamic Content List
                        _buildActiveListContent(theme),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionsBox(ThemeData theme) {
    final isLight = theme.brightness == Brightness.light;
    return Container(
      decoration: BoxDecoration(
        color: isLight
            ? theme.scaffoldBackgroundColor
            : theme.colorScheme.onSurface.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildQuickRow(
            label: AppLocalizations.of(context)?.translate('end_of_page') ??
                'End of Page',
            value: "Page $_currentPage",
            onTap: () {
              final pageData = getPageData(_currentPage);
              if (pageData.isNotEmpty) {
                final last = pageData.last;
                _playTo(int.parse(last['surah'].toString()),
                    int.parse(last['end'].toString()));
              }
            },
          ),
          Divider(
              height: 1,
              color: isLight
                ? theme.colorScheme.surface
                : theme.colorScheme.onSurface.withOpacity(0.05),
              indent: 16,
              endIndent: 16),
          _buildQuickRow(
            label: AppLocalizations.of(context)?.translate('end_of_surah') ??
                'End of Surah',
            value: getBilingualSurahName(context, widget.startSurah),
            onTap: () => _playTo(widget.startSurah, _endOfSurah),
          ),
          Divider(
              height: 1,
              color: isLight
                ? theme.colorScheme.surface
                : theme.colorScheme.onSurface.withOpacity(0.05),
              indent: 16,
              endIndent: 16),
          _buildQuickRow(
            label: AppLocalizations.of(context)
                    ?.translate('continuous_playback') ??
                'Continuous Playback',
            value: "∞",
            onTap: () => _playTo(114, 6),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickRow(
      {required String label,
      required String value,
      required VoidCallback onTap}) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isLight
                        ? theme.colorScheme.onSurface.withOpacity(0.7)
                        : Colors.white.withOpacity(0.7))),
            Text(value,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isLight
                        ? theme.colorScheme.onSurface.withOpacity(0.5)
                        : Colors.white.withOpacity(0.5))),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentedControl(ThemeData theme) {
    final isLight = theme.brightness == Brightness.light;
    return Container(
      height: 45,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isLight
            ? theme.scaffoldBackgroundColor
            : theme.colorScheme.onSurface.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildTabItem(0,
              AppLocalizations.of(context)?.translate('tab_verse') ?? 'Verse'),
          _buildTabItem(
              1, AppLocalizations.of(context)?.translate('tab_page') ?? 'Page'),
          _buildTabItem(2,
              AppLocalizations.of(context)?.translate('tab_surah') ?? 'Sūrah'),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String label) {
    bool isActive = _selectedTabIndex == index;
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTabIndex = index),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive
                ? (isLight
                    ? theme.colorScheme.surfaceContainerHighest
                    : Colors.grey.withOpacity(0.3))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isActive
                  ? (isLight
                      ? theme.colorScheme.onSurface
                      : Colors.white)
                  : (isLight
                      ? theme.colorScheme.onSurface.withOpacity(0.5)
                      : Colors.white.withOpacity(0.5)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveListContent(ThemeData theme) {
    Widget child;
    switch (_selectedTabIndex) {
      case 0:
        child = _buildVerseList(theme);
        break;
      case 1:
        child = _buildPageList(theme);
        break;
      case 2:
        child = _buildSurahList(theme);
        break;
      default:
        child = const SizedBox();
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      child: KeyedSubtree(
        key: ValueKey(_selectedTabIndex),
        child: child,
      ),
    );
  }

  Widget _buildVerseList(ThemeData theme) {
    final isLight = theme.brightness == Brightness.light;
    final startVerse = widget.startVerse;
    final count = _endOfSurah - startVerse + 1;

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      itemBuilder: (context, index) {
        final verseNum = startVerse + index;
        final page = getPageNumber(widget.startSurah, verseNum);

        return InkWell(
          onTap: () => _playTo(widget.startSurah, verseNum),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$verseNum',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: isLight
                            ? theme.colorScheme.onSurface.withOpacity(0.8)
                            : Colors.white.withOpacity(0.8),
                      ),
                    ),
                    Text(
                      '$page',
                      style: TextStyle(
                        color: isLight
                            ? theme.colorScheme.onSurface.withOpacity(0.4)
                            : Colors.white.withOpacity(0.4),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  getVerse(widget.startSurah, verseNum, verseEndSymbol: true),
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    color: isLight
                        ? theme.colorScheme.onSurface.withOpacity(0.8)
                        : Colors.white70,
                    fontSize: 22,
                    fontFamily: 'Amiri',
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPageList(ThemeData theme) {
    final startPage = _currentPage + 1;
    if (startPage > 604) return const Center(child: Text("No more pages"));
    final count = 604 - startPage + 1;

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      itemBuilder: (context, index) {
        final pageNum = startPage + index;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          onTap: () {
            final pageData = getPageData(pageNum);
            if (pageData.isNotEmpty) {
              final last = pageData.last;
              _playTo(int.parse(last['surah'].toString()),
                  int.parse(last['end'].toString()));
            }
          },
          title: Text("Page $pageNum",
              style: const TextStyle(fontWeight: FontWeight.w600)),
          trailing: const Icon(Icons.chevron_right, size: 18),
        );
      },
    );
  }

  Widget _buildSurahList(ThemeData theme) {
    final startSurah = widget.startSurah + 1;
    if (startSurah > 114) return const Center(child: Text("No more surahs"));
    final count = 114 - startSurah + 1;

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      itemBuilder: (context, index) {
        final surahNum = startSurah + index;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          onTap: () {
            final totalV = getVerseCount(surahNum);
            _playTo(surahNum, totalV);
          },
          title: Text(getBilingualSurahName(context, surahNum),
              style: const TextStyle(fontWeight: FontWeight.w600)),
          trailing: const Icon(Icons.chevron_right, size: 18),
        );
      },
    );
  }
}
