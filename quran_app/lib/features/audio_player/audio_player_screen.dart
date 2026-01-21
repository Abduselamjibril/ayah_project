import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:quran_app/core/services/audio_service.dart';
import 'package:quran_app/data/models/audio_model.dart';
import 'package:quran_app/features/downloads/audio_surah_list_page.dart';
import 'package:quran_app/core/services/audio_player_service.dart';
import 'package:quran_app/core/i18n/app_localizations.dart';
import 'package:quran_app/core/utils/localization_helper.dart';
import 'package:quran_app/features/mushaf/widgets/mushaf_audio_navigation.dart';
import '../../core/quran/qcf_quran.dart';
import '../mushaf/controller/mushaf_controller.dart';
import 'package:quran_app/app/app.dart';

/// Reusable audio player card used by mushaf views.
class AudioPlayerCard extends StatefulWidget {
  final MushafController controller;
  const AudioPlayerCard({Key? key, required this.controller}) : super(key: key);

  @override
  State<AudioPlayerCard> createState() => _AudioPlayerCardState();
}

class _AudioPlayerCardState extends State<AudioPlayerCard> {
  late final AudioPlayerService _audioPlayer;
  late final VoidCallback _playerStateListener;
  late final VoidCallback _labelListener;
  late final VoidCallback _downloadingListener;
  late final VoidCallback _downloadProgressListener;
  late final VoidCallback _reciterListener;
  late final VoidCallback _verseListener;

  bool _isPlaying = false;
  String _audioName = '';

  AudioRecitation? _selectedRecitation;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _reciterName = '';

  String get _labelText => _audioName.isEmpty
      ? (AppLocalizations.of(context)?.translate('select_recitation') ??
          'Select Recitation')
      : _audioName;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayerService.instance;
    _isPlaying = _audioPlayer.isPlaying.value;
    _audioName = _audioPlayer.currentLabel.value;

    _reciterName = _audioPlayer.recitationName;

    _playerStateListener = () {
      if (!mounted) return;
      setState(() => _isPlaying = _audioPlayer.isPlaying.value);
    };
    _labelListener = () {
      if (!mounted) return;
      setState(() => _audioName = _audioPlayer.currentLabel.value);
    };
    _downloadingListener = () {
      if (!mounted) return;
      setState(() => _isDownloading = _audioPlayer.isDownloading.value);
    };
    _downloadProgressListener = () {
      if (!mounted) return;
      setState(() => _downloadProgress = _audioPlayer.downloadProgress.value);
    };
    _reciterListener = () {
      if (!mounted) return;
      setState(() => _reciterName = _audioPlayer.recitationName);
    };
    _verseListener = () {
      if (!mounted) return;
      final surah = _audioPlayer.currentSurah.value;
      final ayah = _audioPlayer.currentAyah.value;
      if (surah != null && ayah != null) {
        widget.controller.setHighlightedVerse(surah, ayah);
      } else {
        // Only clear if we stopped playback or finished sequence
        if (!_audioPlayer.hasSource) {
          widget.controller.clearHighlight();
        }
      }
    };

    _audioPlayer.isPlaying.addListener(_playerStateListener);
    _audioPlayer.currentLabel.addListener(_labelListener);
    _audioPlayer.isDownloading.addListener(_downloadingListener);
    _audioPlayer.downloadProgress.addListener(_downloadProgressListener);
    _audioPlayer.reciterNameNotifier.addListener(_reciterListener);
    _audioPlayer.currentSurah.addListener(_verseListener);
    _audioPlayer.currentAyah.addListener(_verseListener);
  }

  @override
  void dispose() {
    _audioPlayer.isPlaying.removeListener(_playerStateListener);
    _audioPlayer.currentLabel.removeListener(_labelListener);
    _audioPlayer.isDownloading.removeListener(_downloadingListener);
    _audioPlayer.downloadProgress.removeListener(_downloadProgressListener);
    _audioPlayer.reciterNameNotifier.removeListener(_reciterListener);
    _audioPlayer.currentSurah.removeListener(_verseListener);
    _audioPlayer.currentAyah.removeListener(_verseListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withOpacity(0.92),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _openAudioPicker,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          _labelText,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: BrandColors.accent,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.expand_more_rounded,
                        color: BrandColors.accent,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest // Using the blended UI fix
                      .withOpacity(0.5),
                ),
                child: IconButton(
                  iconSize: 26,
                  padding: const EdgeInsets.all(10),
                  icon: _isDownloading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            value: _downloadProgress > 0
                                ? _downloadProgress
                                : null,
                            strokeWidth: 3,
                            color: BrandColors.accent,
                          ),
                        )
                      : Icon(
                          _isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: BrandColors.accent,
                        ),
                  onPressed: _togglePlayPause,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _togglePlayPause() async {
    // If currently playing -> pause immediately without prompting
    if (_audioPlayer.isPlaying.value) {
      await _audioPlayer.pause();
      return;
    }

    // If we have a source loaded (paused), just resume
    if (_audioPlayer.hasSource) {
      await _audioPlayer.resume();
      return;
    }

    // No source loaded - need to start playback
    // Step 1: Ensure reciter is selected
    AudioRecitation? recitation = _selectedRecitation;
    if (recitation == null && _audioPlayer.userSelectedReciter) {
      recitation = _audioPlayer.getSelectedRecitation();
    }
    // If still null, prompt user to choose a reciter
    if (recitation == null) {
      recitation = await _ensureReciterSelected();
      if (recitation == null) return; // User cancelled
    }

    // Step 2: Determine playback range from current page
    // Highlighted verse has priority
    final hs = widget.controller.highlightedSurah;
    final hv = widget.controller.highlightedVerse;

    int startSurah;
    int startAyah;
    int endSurah;
    int endAyah;

    // Use current page data helper
    await AudioService.instance.initialize();
    final currentPage = widget.controller.currentPage;
    final pd = getPageData(currentPage);

    // If page is empty (shouldn't happen for valid pages), default to Surah 1
    if (pd.isEmpty) {
      startSurah = 1;
      startAyah = 1;
      endSurah = 1;
      endAyah = 7;
    } else {
      // Determine range from page content
      final firstVerse = pd.first;
      final lastVerse = pd.last;

      final pageStartSurah = int.tryParse(firstVerse['surah'].toString()) ?? 1;
      final pageStartAyah = int.tryParse(firstVerse['start'].toString()) ?? 1;
      final pageEndSurah = int.tryParse(lastVerse['surah'].toString()) ?? 1;
      final pageEndAyah = int.tryParse(lastVerse['end'].toString()) ?? 1;

      // Check if highlighted verse belongs to current page
      bool isHighlightOnCurrentPage = false;
      if (hs != null && hv != null) {
        try {
          final p = getPageNumber(hs, hv);
          if (p == currentPage) {
            isHighlightOnCurrentPage = true;
          }
        } catch (_) {}
      }

      // If playing from specific highlighted verse ON THIS PAGE
      if (isHighlightOnCurrentPage && hs != null && hv != null) {
        startSurah = hs;
        startAyah = hv;
        // End at the end of the page
        endSurah = pageEndSurah;
        endAyah = pageEndAyah;
      } else {
        // Play whole page from start
        startSurah = pageStartSurah;
        startAyah = pageStartAyah;
        endSurah = pageEndSurah;
        endAyah = pageEndAyah;
      }
    }

    // Step 3: Play Range Sequence (handling downloads automatically)
    try {
      await _audioPlayer.playRangeSequenceWithDownload(
        context,
        startSurah: startSurah,
        startAyah: startAyah,
        endSurah: endSurah,
        endAyah: endAyah,
        forceReciter: false,
      );
    } catch (e) {
      _showSnack(
          (AppLocalizations.of(context)?.translate('audio_start_error') ??
                  'Audio failed to start: {error}')
              .replaceAll('{error}', '$e'));
    }
  }

  Future<void> _openAudioPicker() async {
    _selectedRecitation = null;
    await _ensureReciterSelected(force: true);
  }

  Future<void> _navigateToDownloadSurah(int recitationId) async {
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
    final chosen = await showReciterPickerSheet(context, recitations);
    if (chosen != null) {
      _selectedRecitation = chosen;
      _audioPlayer.setRecitationInfo(id: chosen.id, name: chosen.reciterName);
    }
    return _selectedRecitation;
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
