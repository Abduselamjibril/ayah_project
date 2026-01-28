import 'package:flutter/material.dart';
import '../../../../core/quran/qcf_quran.dart';
import '../../../../core/services/audio_player_service.dart';
import 'package:quran_app/core/i18n/app_localizations.dart';
import 'package:quran_app/core/utils/localization_helper.dart';

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

class _PlayRangeDialogState extends State<PlayRangeDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late int _currentPage;
  late int _endOfSurah;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _currentPage = getPageNumber(widget.startSurah, widget.startVerse);
    _endOfSurah = getVerseCount(widget.startSurah);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      (AppLocalizations.of(context)?.translate('play_from') ??
                              'Play from {surah} : {verse}')
                          .replaceAll('{surah}',
                              getBilingualSurahName(context, widget.startSurah))
                          .replaceAll('{verse}', '${widget.startVerse}'),
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    _buildQuickActions(theme),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Tabs
              TabBar(
                controller: _tabController,
                tabs: [
                  Tab(
                      text: AppLocalizations.of(context)
                              ?.translate('tab_verse') ??
                          'Verse'),
                  Tab(
                      text:
                          AppLocalizations.of(context)?.translate('tab_page') ??
                              'Page'),
                  Tab(
                      text: AppLocalizations.of(context)
                              ?.translate('tab_surah') ??
                          'Surah'),
                ],
              ),

              // Tab Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildVerseList(scrollController),
                    _buildPageList(scrollController),
                    _buildSurahList(scrollController),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickActions(ThemeData theme) {
    return Column(
      children: [
        _buildQuickActionItem(
          icon: Icons.article_outlined,
          labelLeft: AppLocalizations.of(context)?.translate('end_of_page') ??
              'End of Page',
          labelRight: (AppLocalizations.of(context)?.translate('page_label') ??
                  'Page {number}')
              .replaceAll('{number}', '$_currentPage'),
          onTap: () {
            final pageData = getPageData(_currentPage);
            if (pageData.isNotEmpty) {
              final last = pageData.last;
              _playTo(int.parse(last['surah'].toString()),
                  int.parse(last['end'].toString()));
            }
          },
        ),
        const SizedBox(height: 8),
        _buildQuickActionItem(
          icon: Icons.format_align_right,
          labelLeft: AppLocalizations.of(context)?.translate('end_of_surah') ??
              'End of Surah',
          labelRight: getBilingualSurahName(context, widget.startSurah),
          onTap: () => _playTo(widget.startSurah, _endOfSurah),
        ),
        const SizedBox(height: 8),
        _buildQuickActionItem(
          icon: Icons.all_inclusive,
          labelLeft:
              AppLocalizations.of(context)?.translate('continuous_playback') ??
                  'Continuous Playback',
          labelRight: '∞',
          onTap: () => _playTo(114, 6),
        ),
      ],
    );
  }

  Widget _buildQuickActionItem({
    required IconData icon,
    required String labelLeft,
    required String labelRight,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 12),
            Text(labelLeft,
                style: const TextStyle(fontWeight: FontWeight.w500)),
            const Spacer(),
            Text(labelRight,
                style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildVerseList(ScrollController scrollController) {
    final totalVerses = _endOfSurah;
    final startVerse = widget.startVerse;
    final count = totalVerses - startVerse + 1;

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.all(8),
      itemCount: count,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final verseNum = startVerse + index;
        final isStartVerse = verseNum == widget.startVerse;

        return Container(
          color: isStartVerse
              ? Theme.of(context).primaryColor.withOpacity(0.1)
              : null,
          child: ListTile(
            onTap: () => _playTo(widget.startSurah, verseNum),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${getBilingualSurahName(context, widget.startSurah)} : $verseNum',
                  style: isStartVerse
                      ? const TextStyle(fontWeight: FontWeight.bold)
                      : null,
                ),
                Icon(Icons.play_circle_outline,
                    size: 20,
                    color: isStartVerse
                        ? Theme.of(context).primaryColor
                        : Colors.grey),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: ShaderMask(
                shaderCallback: (Rect bounds) {
                  return const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Colors.transparent, Colors.white],
                    stops: [
                      0.0,
                      0.12
                    ], // Approx 40px fade on left side for RTL text
                  ).createShader(bounds);
                },
                blendMode: BlendMode.dstIn,
                child: Text(
                  getVerse(widget.startSurah, verseNum, verseEndSymbol: true),
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow
                      .clip, // Using clip because mask handles the fade visual
                  style: const TextStyle(
                    fontSize: 20,
                    fontFamily: 'Amiri',
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPageList(ScrollController scrollController) {
    final startPage = _currentPage + 1;
    if (startPage > 604) {
      return Center(
          child: Text(
              AppLocalizations.of(context)!.translate('no_subsequent_pages')));
    }
    final count = 604 - startPage + 1;

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.all(8),
      itemCount: count,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final pageNum = startPage + index;
        String pageInfo = '';
        try {
          final pageData = getPageData(pageNum);
          if (pageData.isNotEmpty) {
            final last = pageData.last;
            pageInfo =
                '${getBilingualSurahName(context, int.parse(last['surah'].toString()))} : ${last['end']}';
          }
        } catch (_) {}

        return ListTile(
          onTap: () {
            final pageData = getPageData(pageNum);
            if (pageData.isNotEmpty) {
              final last = pageData.last;
              _playTo(int.parse(last['surah'].toString()),
                  int.parse(last['end'].toString()));
            }
          },
          leading: const Icon(Icons.auto_stories_outlined),
          title: Text(
            (AppLocalizations.of(context)?.translate('page_label') ??
                    'Page {number}')
                .replaceAll('{number}', '$pageNum'),
          ),
          trailing: Text(pageInfo),
        );
      },
    );
  }

  Widget _buildSurahList(ScrollController scrollController) {
    final startSurah = widget.startSurah + 1;
    if (startSurah > 114) {
      return Center(
          child: Text(
              AppLocalizations.of(context)?.translate('no_subsequent_surahs') ??
                  'No subsequent surahs'));
    }
    final count = 114 - startSurah + 1;

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.all(8),
      itemCount: count,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final surahNum = startSurah + index;
        int endPage = 0;
        try {
          final totalV = getVerseCount(surahNum);
          endPage = getPageNumber(surahNum, totalV);
        } catch (_) {}

        return ListTile(
          onTap: () {
            final totalV = getVerseCount(surahNum);
            _playTo(surahNum, totalV);
          },
          leading:
              Text('$surahNum', style: const TextStyle(color: Colors.grey)),
          title: Text(getBilingualSurahName(context, surahNum)),
          trailing: Text(
            (AppLocalizations.of(context)?.translate('ends_page') ??
                    'Ends Page {number}')
                .replaceAll('{number}', '$endPage'),
          ),
        );
      },
    );
  }
}
