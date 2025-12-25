import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';
import '../../../core/quran/widgets/quran_pageview.dart';
import '../../../core/quran/qcf_quran.dart';
import '../../../core/services/audio_player_service.dart';
import '../../audio_player/audio_player_screen.dart';
import '../../downloads/audio_surah_list_page.dart';
import 'package:quran_app/core/services/audio_service.dart';
import 'package:quran_app/data/models/audio_model.dart';
import 'package:quran_app/features/bookmarks/state/bookmark_notes_notifier.dart';
import '../controller/mushaf_controller.dart';
import '../screens/verse_details_screen.dart';

class HorizontalMushafView extends StatefulWidget {
  final MushafController controller;
  final ValueChanged<bool>? onOverlayVisibilityChanged;
  final VoidCallback? onDragDown;

  const HorizontalMushafView({
    super.key,
    required this.controller,
    this.onOverlayVisibilityChanged,
    this.onDragDown,
  });

  @override
  State<HorizontalMushafView> createState() => _HorizontalMushafViewState();
}

class _HorizontalMushafViewState extends State<HorizontalMushafView> {
  late PageController _pageController;
  double? _sliderValue;
  bool _isSliderActive = false;
  bool _isPlaying = false;
  String _audioName = 'Select audio';
  late final AudioPlayerService _audioPlayer;
  late final VoidCallback _playerStateListener;
  late final VoidCallback _labelListener;
  AudioRecitation? _selectedRecitation;
  final Map<int, String> _surahNameCache = {};
  bool _overlayVisible = true;
  Timer? _autoHideTimer;
  bool _isSequentialMode = false;
  int _sequenceToken = 0;
  final ScreenshotController _screenshotController = ScreenshotController();
  double _downloadProgress = 0.0;

  static const List<String> _bookmarkColors = [
    '#FFB300',
    '#4DB6AC',
    '#29B6F6',
    '#AB47BC',
    '#EF5350',
    '#8D6E63',
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: widget.controller.currentPage - 1,
    );
    _sliderValue = widget.controller.currentPage.toDouble();
    _audioPlayer = AudioPlayerService.instance;
    _isPlaying = _audioPlayer.isPlaying.value;
    _audioName = _audioPlayer.currentLabel.value;
    _playerStateListener = () {
      if (!mounted) return;
      setState(() {
        _isPlaying = _audioPlayer.isPlaying.value;
      });
    };
    _labelListener = () {
      if (!mounted) return;
      setState(() {
        _audioName = _audioPlayer.currentLabel.value;
      });
    };
    _audioPlayer.isPlaying.addListener(_playerStateListener);
    _audioPlayer.currentLabel.addListener(_labelListener);
    widget.controller.addListener(_onControllerChanged);
    _scheduleAutoHide();
    widget.onOverlayVisibilityChanged?.call(true);
  }

  @override
  void dispose() {
    _audioPlayer.isPlaying.removeListener(_playerStateListener);
    _audioPlayer.currentLabel.removeListener(_labelListener);
    widget.controller.removeListener(_onControllerChanged);
    _pageController.dispose();
    _autoHideTimer?.cancel();
    super.dispose();
  }

  void _onControllerChanged() {
    final targetPage = widget.controller.currentPage - 1;
    if (!_isSliderActive && _pageController.hasClients) {
      if ((_pageController.page?.round() ?? -1) != targetPage) {
        _sliderValue = null;
        _isSliderActive = false;
        _pageController.animateToPage(
          targetPage,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookmarkState = context.watch<BookmarkNotesNotifier>();
    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _toggleOverlay,
          onVerticalDragUpdate: _handleVerticalDrag,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = min(constraints.maxWidth, 900.0);
              final topMargin =
                  MediaQuery.of(context).padding.top + kToolbarHeight + 8;
              return Center(
                child: Padding(
                  padding: EdgeInsets.only(top: topMargin),
                  child: SizedBox(
                    width: maxWidth,
                    height: constraints.maxHeight - topMargin,
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: PageviewQuran(
                        controller: _pageController,
                        initialPageNumber: widget.controller.currentPage,
                        scrollMode: ScrollMode.horizontal,
                        onPageChanged: (page) {
                          widget.controller.setPage(page);
                        },
                        textColor: Theme.of(context).colorScheme.onSurface,
                        pageBackgroundColor:
                            Theme.of(context).scaffoldBackgroundColor,
                        verseBackgroundColor: (s, v) =>
                            _getVerseBackgroundColor(bookmarkState, s, v),
                        onLongPress: (surah, verse) => _showVerseOptions(
                            context, bookmarkState, surah, verse),
                        onLongPressStart: (surah, verse, details) =>
                            widget.controller.setHighlightedVerse(surah, verse),
                        onLongPressCancel: (surah, verse) =>
                            widget.controller.clearHighlight(),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        _buildPageOverlay(),
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          right: 12,
          child: _buildRibbon(bookmarkState),
        ),
      ],
    );
  }

  Color? _getVerseBackgroundColor(
      BookmarkNotesNotifier state, int surah, int verse) {
    final b = state.bookmarkForVerse(surah, verse);
    if (b != null) {
      if (b.isKhatmahPin) {
        // Last read: no verse-level highlight (represents whole page)
        return null;
      }
      final color = Color(_parseColor(b.colorHex));
      return color.withValues(alpha: 0.25);
    }
    return null;
  }

  Widget _buildRibbon(BookmarkNotesNotifier state) {
    final currentPage = widget.controller.currentPage;
    bool isPinned = false;
    final pin = state.khatmahPin;
    if (pin != null) {
      try {
        final pinPage = getPageNumber(pin.surahId, pin.ayahId);
        isPinned = pinPage == currentPage;
      } catch (_) {}
    }
    final color = Theme.of(context).colorScheme.primary;
    final onColor = Theme.of(context).colorScheme.onPrimary;
    return Material(
      color: color.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => _bookmarkCurrentPageAsLastRead(state),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Icon(
            isPinned ? Icons.bookmark : Icons.bookmark_border,
            size: 20,
            color: onColor,
          ),
        ),
      ),
    );
  }

  Future<void> _bookmarkCurrentPageAsLastRead(
      BookmarkNotesNotifier state) async {
    final page = widget.controller.currentPage;
    final data = getPageData(page);
    if (data.isEmpty) return;
    final surah = int.tryParse(data.first['surah'].toString()) ?? 1;
    final ayah = int.tryParse(data.first['start'].toString()) ?? 1;
    final pin = state.khatmahPin;
    if (pin != null) {
      try {
        final pinPage = getPageNumber(pin.surahId, pin.ayahId);
        if (pinPage == page) {
          await state.clearKhatmahPin();
          if (!mounted) return;
          _showSnack('Removed last read for page $page');
          return;
        }
      } catch (_) {}
    }
    await state.setKhatmahPin(
      surahId: surah,
      ayahId: ayah,
      colorHex: '#4DB6AC',
      category: 'Last read',
    );
    if (!mounted) return;
    final name = getSurahName(surah);
    _showSnack('Saved last read: Page $page • $name:$ayah');
  }

  Widget _buildPageOverlay() {
    if (!_overlayVisible) {
      return const SizedBox.shrink();
    }
    return Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, child) {
          final currentDouble = ((_isSliderActive && _sliderValue != null)
                  ? _sliderValue!
                  : widget.controller.currentPage.toDouble())
              .clamp(1.0, 604.0);
          final currentPage = currentDouble.round();
          final surahName = _surahNameForPage(currentPage);
          final isSliding = _isSliderActive;

          return RepaintBoundary(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: isSliding
                      ? Card(
                          elevation: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .surface
                              .withValues(alpha: 0.95),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  surahName,
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Page ${currentPage.toString().padLeft(2, '0')}',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 8),
                _buildAudioPlayerCard(),
                const SizedBox(height: 4),
                Card(
                  elevation: 16,
                  color:
                      Theme.of(context).colorScheme.surface.withOpacity(0.95),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: Slider(
                        min: 1,
                        max: 604,
                        divisions: 603,
                        value: currentDouble,
                        onChangeStart: (value) {
                          setState(() {
                            _isSliderActive = true;
                            _sliderValue = value;
                            _overlayVisible = true;
                          });
                          _scheduleAutoHide();
                        },
                        onChanged: (value) {
                          setState(() {
                            _overlayVisible = true;
                            _sliderValue = value;
                          });
                          _scheduleAutoHide();
                        },
                        onChangeEnd: (value) {
                          final page = value.round();
                          setState(() {
                            _isSliderActive = false;
                            _sliderValue = null;
                          });
                          _navigateToPage(page);
                          _scheduleAutoHide();
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAudioPlayerCard() {
    return AudioPlayerCard(controller: widget.controller);
  }

  Future<void> _togglePlayPause() async {
    _showOverlay();
    final recitation = await _ensureReciterSelected();
    if (recitation == null) return;
    if (_audioPlayer.isPlaying.value) {
      await _audioPlayer.pause();
      return;
    }
    if (_isSequentialMode && _audioPlayer.hasSource) {
      await _audioPlayer.resume();
      return;
    }
    await _cancelSequence();
    // Decide what to play: highlighted verse or current surah
    final hs = widget.controller.highlightedSurah;
    final hv = widget.controller.highlightedVerse;
    if (hs != null && hv != null) {
      try {
        await _audioPlayer.playAyahPreferLocal(
          surah: hs,
          ayah: hv,
          surahName: getSurahName(hs),
          reciterName: recitation.reciterName,
        );
        return;
      } catch (_) {
        // fallthrough to surah logic
      }
    }
    // No verse selected: attempt local surah; if not downloaded, navigate to downloads
    final recitationId = recitation.id;
    await AudioService.instance.initialize();
    final currentPage = widget.controller.currentPage;
    final pd = getPageData(currentPage);
    int surah = 1;
    if (pd.isNotEmpty) {
      surah = int.tryParse(pd.first['surah'].toString()) ?? 1;
    }
    final surahLabel = getSurahName(surah);
    final hasLocal =
        await AudioService.instance.isSurahDownloaded(recitationId, surah);
    if (!hasLocal) {
      _navigateToDownloadSurah(recitationId);
      return;
    }
    try {
      _startSurahSequence(
        surah: surah,
        surahLabel: surahLabel,
        reciterName: recitation.reciterName,
      );
    } catch (e) {
      _showSnack('Audio failed to start: $e');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _updateKhatmahPinForPage(
      BookmarkNotesNotifier state, int page) async {
    final pin = state.khatmahPin;
    final data = getPageData(page);
    if (data.isEmpty) return;
    final surah = int.tryParse(data.first['surah'].toString()) ?? 1;
    final ayah = int.tryParse(data.first['start'].toString()) ?? 1;
    if (pin != null && pin.surahId == surah && pin.ayahId == ayah) return;
    await state.setKhatmahPin(
      surahId: surah,
      ayahId: ayah,
      colorHex: '#4DB6AC',
      category: 'Last read',
    );
  }

  void _openAudioPicker() async {
    _showOverlay();
    final recitation = await _ensureReciterSelected();
    if (recitation == null) return;
    final recitationId = recitation.id;
    await AudioService.instance.initialize();
    final downloaded =
        await AudioService.instance.getDownloadedSurahs(recitationId);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final maxHeight = min(MediaQuery.of(context).size.height * 0.7, 520.0);
        return SafeArea(
          child: SizedBox(
            height: maxHeight,
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Text('Downloaded Audios',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: downloaded.isEmpty
                      ? const Center(child: Text('No downloaded surahs'))
                      : ListView.builder(
                          itemCount: downloaded.length,
                          itemBuilder: (context, index) {
                            final s = downloaded[index];
                            final n = int.tryParse(s) ?? 0;
                            final name = getSurahName(n);
                            return ListTile(
                              title: Text('${s.padLeft(3, '0')} - $name'),
                              subtitle: Text(_audioPlayer.recitationName),
                              trailing: ValueListenableBuilder<int?>(
                                valueListenable: AudioPlayerService
                                    .instance.downloadingSurah,
                                builder: (context, downloading, _) {
                                  final isThis = downloading != null &&
                                      downloading == n &&
                                      AudioPlayerService
                                          .instance.isDownloading.value;
                                  if (isThis) {
                                    return const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2.5),
                                    );
                                  }
                                  return const Icon(Icons.play_arrow);
                                },
                              ),
                              onTap: () async {
                                Navigator.pop(context);
                                await _cancelSequence();
                                _startSurahSequence(
                                  surah: n,
                                  surahLabel: name,
                                  reciterName: _audioPlayer.recitationName,
                                );
                              },
                            );
                          },
                        ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.switch_account),
                  title: const Text('Change Reciter'),
                  onTap: () async {
                    Navigator.pop(context);
                    _selectedRecitation = null;
                    final recitation =
                        await _ensureReciterSelected(force: true);
                    if (!mounted) return;
                    if (recitation != null) {
                      _openAudioPicker();
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('Open Audio Downloads'),
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToDownloadSurah(recitationId);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _cancelSequence() async {
    _isSequentialMode = false;
    _sequenceToken++;
    widget.controller.clearHighlight();
    await _audioPlayer.stop();
  }

  void _startSurahSequence({
    required int surah,
    required String surahLabel,
    required String reciterName,
    int startAyah = 1,
  }) {
    final token = ++_sequenceToken;
    _isSequentialMode = true;
    Future.microtask(() => _runSurahSequence(
          token: token,
          surah: surah,
          surahLabel: surahLabel,
          reciterName: reciterName,
          startAyah: startAyah,
        ));
  }

  Future<void> _runSurahSequence({
    required int token,
    required int surah,
    required String surahLabel,
    required String reciterName,
    int startAyah = 1,
  }) async {
    await _audioPlayer.stop();
    final totalAyat = getVerseCount(surah);
    for (var ayah = startAyah; ayah <= totalAyat; ayah++) {
      if (!mounted || token != _sequenceToken) break;
      widget.controller.setHighlightedVerse(surah, ayah);
      try {
        await _audioPlayer.playAyahPreferLocal(
          surah: surah,
          ayah: ayah,
          surahName: surahLabel,
          reciterName: reciterName,
        );
      } catch (_) {
        break;
      }
      await _audioPlayer.waitForCompleteOrStop();
      if (token != _sequenceToken) {
        await _audioPlayer.stop();
        break;
      }
    }
    if (!mounted) return;
    if (token == _sequenceToken) {
      _isSequentialMode = false;
      widget.controller.clearHighlight();
    }
  }

  Future<void> _navigateToDownloadSurah(int recitationId) async {
    // Build minimal recitation model; alternatively fetch full list and find matching
    final recitation = AudioRecitation(
        id: recitationId,
        reciterName:
            _selectedRecitation?.reciterName ?? _audioPlayer.recitationName);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => AudioSurahListPage(recitation: recitation)),
    );
  }

  Future<AudioRecitation?> _ensureReciterSelected({bool force = false}) async {
    if (!force && _selectedRecitation != null) return _selectedRecitation;
    await AudioService.instance.initialize();
    final recitations = await AudioService.instance.getAvailableRecitations();
    if (!mounted) return null;
    final chosen = await showModalBottomSheet<AudioRecitation>(
      context: context,
      builder: (context) {
        final maxHeight = min(MediaQuery.of(context).size.height * 0.7, 520.0);
        return SafeArea(
          child: SizedBox(
            height: maxHeight,
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Text('Choose Reciter',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: recitations.length,
                    itemBuilder: (context, index) {
                      final r = recitations[index];
                      return ListTile(
                        title: Text(r.reciterName),
                        subtitle: r.style != null ? Text(r.style!) : null,
                        onTap: () => Navigator.pop(context, r),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (chosen != null) {
      _selectedRecitation = chosen;
      _audioPlayer.setRecitationInfo(id: chosen.id, name: chosen.reciterName);
    }
    return _selectedRecitation;
  }

  String _surahNameForPage(int page) {
    // Memoize to avoid recomputation during rapid slider updates
    final cached = _surahNameCache[page];
    if (cached != null) return cached;
    try {
      final pd = getPageData(page);
      if (pd.isEmpty) return '';
      final first = pd[0];
      final surahNum = int.parse(first['surah'].toString());
      final name = getSurahName(surahNum);
      _surahNameCache[page] = name;
      return name;
    } catch (e) {
      return '';
    }
  }

  // Navigation buttons and page number removed in favor of slider

  void _navigateToPage(int page) {
    if (page >= 1 && page <= 604) {
      widget.controller.setPage(page);
    }
  }

  void _scheduleAutoHide() {
    _autoHideTimer?.cancel();
    _autoHideTimer = Timer(const Duration(seconds: 10), () {
      if (!mounted) return;
      setState(() {
        _overlayVisible = false;
      });
      widget.onOverlayVisibilityChanged?.call(false);
    });
  }

  void _showOverlay() {
    if (!_overlayVisible) {
      setState(() {
        _overlayVisible = true;
      });
      widget.onOverlayVisibilityChanged?.call(true);
    }
    _scheduleAutoHide();
  }

  void _hideOverlay() {
    if (_overlayVisible) {
      setState(() {
        _overlayVisible = false;
      });
      widget.onOverlayVisibilityChanged?.call(false);
    }
    _autoHideTimer?.cancel();
    _autoHideTimer = null;
  }

  void _toggleOverlay() {
    if (_overlayVisible) {
      _hideOverlay();
    } else {
      _showOverlay();
    }
  }

  void _handleVerticalDrag(DragUpdateDetails details) {
    final delta = details.primaryDelta;
    if (delta != null && delta > 8) {
      widget.onDragDown?.call();
      _showOverlay();
    }
  }

  int _parseColor(String value) {
    try {
      final normalized = value.replaceAll('#', '').padLeft(6, '0');
      return int.parse('FF$normalized', radix: 16);
    } catch (_) {
      return int.parse('FFFFC107', radix: 16);
    }
  }

  void _showVerseOptions(
    BuildContext context,
    BookmarkNotesNotifier bookmarkState,
    int surah,
    int verse,
  ) {
    final isBookmarked = bookmarkState.isBookmarked(surah, verse);
    final hasNote = bookmarkState.hasNote(surah, verse);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildOptionTile(
                  icon: Icons.push_pin,
                  title: 'Pin here (Khatmah)',
                  onTap: () async {
                    await bookmarkState.setKhatmahPin(
                      surahId: surah,
                      ayahId: verse,
                      colorHex: '#4DB6AC',
                      category: 'Khatmah',
                    );
                    if (mounted) {
                      Navigator.pop(context);
                      _showSnack('Pinned Surah $surah:$verse for Khatmah');
                    }
                  },
                ),
                _buildOptionTile(
                  icon:
                      isBookmarked ? Icons.bookmark_remove : Icons.bookmark_add,
                  title:
                      isBookmarked ? 'Remove bookmark' : 'Add colored bookmark',
                  onTap: () async {
                    Navigator.pop(context);
                    if (isBookmarked) {
                      await bookmarkState.toggleBookmark(
                          surahId: surah, ayahId: verse);
                      _showBookmarkSnackbar(context, true);
                    } else {
                      await _openBookmarkDialog(
                        context,
                        bookmarkState,
                        surah,
                        verse,
                      );
                    }
                  },
                ),
                _buildOptionTile(
                  icon: hasNote ? Icons.edit_note : Icons.note_add,
                  title: hasNote ? 'Edit note' : 'Write note',
                  onTap: () async {
                    Navigator.pop(context);
                    await _openNoteSheet(context, bookmarkState, surah, verse);
                  },
                ),
                _buildOptionTile(
                  icon: Icons.volume_up,
                  title: 'Play Audio',
                  onTap: () {
                    Navigator.pop(context);
                    AudioPlayerService.instance.playSurahSequenceWithDownload(
                      context,
                      surah,
                      verse,
                    );
                  },
                ),
                _buildOptionTile(
                  icon: Icons.menu_book,
                  title: 'View Tafsir',
                  onTap: () {
                    Navigator.pop(context);
                    _viewTafsir(context, surah, verse);
                  },
                ),
                _buildOptionTile(
                  icon: Icons.share,
                  title: 'Share Verse Image',
                  onTap: () {
                    Navigator.pop(context);
                    _shareVerseCard(surah, verse);
                  },
                ),
                _buildOptionTile(
                  icon: Icons.copy,
                  title: 'Copy Verse Text',
                  onTap: () {
                    Navigator.pop(context);
                    _copyVerseText(surah, verse);
                  },
                ),
                const Divider(),
                _buildOptionTile(
                  icon: Icons.close,
                  title: 'Cancel',
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  ListTile _buildOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: onTap,
    );
  }

  void _showBookmarkSnackbar(BuildContext context, bool wasBookmarked) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(wasBookmarked ? 'Bookmark removed' : 'Verse bookmarked'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openBookmarkDialog(
    BuildContext context,
    BookmarkNotesNotifier state,
    int surah,
    int verse,
  ) async {
    final existing = state.bookmarkForVerse(surah, verse);
    String selectedColor = existing?.colorHex ?? _bookmarkColors.first;
    final categoryController =
        TextEditingController(text: existing?.categoryName ?? '');

    final result = await showModalBottomSheet<Map<String, String?>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add colored bookmark',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: _bookmarkColors.map((hex) {
                        final color = Color(_parseColor(hex));
                        final isSelected = hex == selectedColor;
                        return ChoiceChip(
                          label: Icon(
                            isSelected ? Icons.check : Icons.circle,
                            size: isSelected ? 16 : 10,
                            color: isSelected
                                ? Theme.of(context).colorScheme.onPrimary
                                : color,
                          ),
                          selected: isSelected,
                          selectedColor: color,
                          backgroundColor: color.withOpacity(0.25),
                          labelPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          shape: StadiumBorder(
                            side: BorderSide(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : color,
                              width: 2,
                            ),
                          ),
                          onSelected: (_) =>
                              setModalState(() => selectedColor = hex),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: categoryController,
                      decoration: const InputDecoration(
                        labelText: 'Category (optional)',
                        hintText: 'e.g. To Memorize',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.check),
                          label: const Text('Save'),
                          onPressed: () {
                            Navigator.pop<Map<String, String?>>(context, {
                              'color': selectedColor,
                              'category': categoryController.text.trim(),
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null || !mounted) return;
    final color = result['color'] ?? _bookmarkColors.first;
    final category =
        (result['category']?.isEmpty ?? true) ? null : result['category'];

    await state.saveBookmark(
      surahId: surah,
      ayahId: verse,
      colorHex: color,
      category: category,
    );
    _showBookmarkSnackbar(context, false);
  }

  Future<void> _openNoteSheet(
    BuildContext context,
    BookmarkNotesNotifier state,
    int surah,
    int verse,
  ) async {
    final existing = state.noteForVerse(surah, verse);
    final controller = TextEditingController(text: existing?.content ?? '');

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Note for $surah:$verse',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 6,
                decoration: const InputDecoration(
                  hintText: 'Write your reflection here',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (existing != null)
                    TextButton.icon(
                      onPressed: () async {
                        await state.deleteNoteForVerse(surah, verse);
                        if (context.mounted) {
                          Navigator.pop(context, true);
                        }
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                    ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await state.upsertNote(
                        surahId: surah,
                        ayahId: verse,
                        content: controller.text.trim(),
                      );
                      if (context.mounted) {
                        Navigator.pop(context, true);
                      }
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (saved == true && mounted) {
      _showSnack('Note saved for $surah:$verse');
    }
  }

  Future<void> _shareVerseCard(int surah, int verse) async {
    final surahName = getSurahName(surah);
    final verseText = getVerseQCF(surah, verse, verseEndSymbol: true);
    try {
      final bytes = await _screenshotController.captureFromWidget(
        _VerseShareCard(
          surah: surah,
          verse: verse,
          surahName: surahName,
          verseText: verseText,
        ),
        pixelRatio: 2.5,
      );

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/ayah_${surah}_$verse.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Surah $surahName ($surah:$verse)',
      );
    } catch (e) {
      _showSnack('Could not share verse: $e');
    }
  }

  Future<void> _playAudio(int surah, int verse) async {
    final recitation = await _ensureReciterSelected();
    if (recitation == null) return;
    // Ensure storage initialized and surah downloaded; UI shows inline spinner
    final ok = await AudioPlayerService.instance
        .downloadSurahIfNeeded(recitation, surah);
    if (!ok) {
      _showSnack('Could not download audio for Surah $surah');
      return;
    }
    // Start sequential playback from this ayah
    try {
      await _cancelSequence();
      _startSurahSequence(
        surah: surah,
        surahLabel: getSurahName(surah),
        reciterName: recitation.reciterName,
        startAyah: verse,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio not available for this verse')),
      );
    }
  }

  void _viewTafsir(BuildContext context, int surah, int verse) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VerseDetailsScreen(
          surahNumber: surah,
          ayahNumber: verse,
        ),
      ),
    );
  }

  void _shareVerse(int surah, int verse) {
    _shareVerseCard(surah, verse);
  }

  void _copyVerseText(int surah, int verse) {
    final text = getVerseQCF(surah, verse, verseEndSymbol: true);
    Clipboard.setData(ClipboardData(text: text));
    _showSnack('Copied Surah $surah:$verse');
  }
}

class _VerseShareCard extends StatelessWidget {
  final int surah;
  final int verse;
  final String surahName;
  final String verseText;

  const _VerseShareCard({
    required this.surah,
    required this.verse,
    required this.surahName,
    required this.verseText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData.dark();
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 1080,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$surahName — $surah:$verse',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                verseText,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  height: 1.8,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.bedtime, color: Colors.white70, size: 18),
                SizedBox(width: 8),
                Text(
                  'Ayah App • Offline bookmark',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
