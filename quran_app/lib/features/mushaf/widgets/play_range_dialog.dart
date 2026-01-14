import 'package:flutter/material.dart';
import '../../../../core/quran/qcf_quran.dart';
import '../../../../core/services/audio_player_service.dart';

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
                      'Play from ${getSurahName(widget.startSurah)} : ${widget.startVerse}',
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
                tabs: const [
                  Tab(text: 'Verse'),
                  Tab(text: 'Page'),
                  Tab(text: 'Surah'),
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
          labelLeft: 'End of Page',
          labelRight: 'Page $_currentPage',
          onTap: () {
            // Find last ayah of current page
            final pageData = getPageData(_currentPage);
            if (pageData.isNotEmpty) {
              final last = pageData.last;
              _playTo(int.parse(last['surah'].toString()),
                  int.parse(last['end'].toString()) // Correct key: 'end'
                  );
            }
          },
        ),
        const SizedBox(height: 8),
        _buildQuickActionItem(
          icon: Icons.format_align_right,
          labelLeft: 'End of Surah',
          labelRight: getSurahName(widget.startSurah),
          onTap: () => _playTo(widget.startSurah, _endOfSurah),
        ),
        const SizedBox(height: 8),
        _buildQuickActionItem(
          icon: Icons.all_inclusive,
          labelLeft: 'Continuous Playback',
          labelRight: '∞',
          onTap: () => _playTo(114, 6), // Play till end of Quran
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
    // Show all verses of the surah
    final totalVerses = _endOfSurah;

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.all(8),
      itemCount: totalVerses,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final verseNum = index + 1;
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
                  '${getSurahName(widget.startSurah)} : $verseNum',
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
              child: Text(
                // Use standard text getter, NOT QCF glyphs
                getVerse(widget.startSurah, verseNum, verseEndSymbol: true),
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  fontSize: 20,
                  // Standard arabic font if available, or system text
                  fontFamily: 'Amiri',
                  height: 1.5,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPageList(ScrollController scrollController) {
    // List pages from current page to 604
    final startPage = _currentPage;
    final count = 604 - startPage + 1;

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.all(8),
      itemCount: count,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final pageNum = startPage + index;

        // Get page info from the LAST segment on the page, as requested
        String pageInfo = '';
        try {
          final pageData = getPageData(pageNum);
          if (pageData.isNotEmpty) {
            final last = pageData.last;
            // Use 'surah' and 'end' keys
            pageInfo =
                '${getSurahName(int.parse(last['surah'].toString()))} : ${last['end']}';
          }
        } catch (_) {}

        return ListTile(
          onTap: () {
            final pageData = getPageData(pageNum);
            if (pageData.isNotEmpty) {
              final last = pageData.last;
              _playTo(int.parse(last['surah'].toString()),
                  int.parse(last['end'].toString()) // Use correct 'end' key
                  );
            }
          },
          leading: const Icon(Icons.auto_stories_outlined),
          title: Text('Page $pageNum'),
          trailing: Text(pageInfo),
        );
      },
    );
  }

  Widget _buildSurahList(ScrollController scrollController) {
    // List surahs from current surah to 114
    final startSurah = widget.startSurah;
    final count = 114 - startSurah + 1;

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.all(8),
      itemCount: count,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final surahNum = startSurah + index;
        // Find end page
        int endPage = 0;
        try {
          final totalV = getVerseCount(surahNum);
          endPage = getPageNumber(surahNum, totalV);
        } catch (_) {}

        return ListTile(
          onTap: () {
            // Play to end of this surah
            final totalV = getVerseCount(surahNum);
            _playTo(surahNum, totalV);
          },
          leading:
              Text('$surahNum', style: const TextStyle(color: Colors.grey)),
          title: Text(getSurahName(surahNum)),
          trailing: Text('Ends Page $endPage'),
        );
      },
    );
  }
}
