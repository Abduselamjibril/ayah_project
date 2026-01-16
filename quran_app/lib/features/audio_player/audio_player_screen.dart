import 'dart:async';
import 'package:flutter/material.dart';
import 'package:quran_app/core/services/audio_service.dart';
import 'package:quran_app/data/models/audio_model.dart';
import 'package:quran_app/features/downloads/audio_surah_list_page.dart';
import 'package:quran_app/core/services/audio_player_service.dart';
import 'package:quran_app/core/i18n/app_localizations.dart';
import 'package:quran_app/core/utils/localization_helper.dart';

import '../../core/quran/qcf_quran.dart';
import '../mushaf/controller/mushaf_controller.dart';

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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
            Theme.of(context).colorScheme.surface.withOpacity(0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Card(
        elevation: 0,
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: _audioPlayer.hasSource
              ? _buildExpandedPlayer(context)
              : _buildCompactPlayer(context),
        ),
      ),
    );
  }

  /// Compact player (shown when not playing)
  Widget _buildCompactPlayer(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            ),
            child: IconButton(
              iconSize: 30,
              icon: _isDownloading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        value: _downloadProgress > 0 ? _downloadProgress : null,
                        strokeWidth: 3,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  : Icon(
                      Icons.play_arrow_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              onPressed: _togglePlayPause,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _reciterName.isNotEmpty
                      ? _reciterName
                      : (AppLocalizations.of(context)
                              ?.translate('select_reciter_tooltip') ??
                          'Select Reciter'),
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              Icons.queue_music_rounded,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            onPressed: _openAudioPicker,
            tooltip: AppLocalizations.of(context)
                    ?.translate('select_reciter_tooltip') ??
                'Select reciter',
          ),
        ],
      ),
    );
  }

  /// Expanded player (shown when playing)
  Widget _buildExpandedPlayer(BuildContext context) {
    final currentSurah = _audioPlayer.currentSurah.value;
    final canGoPrevious = currentSurah != null && currentSurah > 1;
    final canGoNext = currentSurah != null && currentSurah < 114;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Info section
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                _audioName.isEmpty
                    ? (AppLocalizations.of(context)
                            ?.translate('select_audio') ??
                        'Select audio')
                    : _audioName,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              if (_reciterName.isNotEmpty)
                Text(
                  _reciterName,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.7),
                      ),
                ),
            ],
          ),
        ),
        // Controls section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Previous button
            IconButton(
              icon: Icon(
                Icons.skip_previous_rounded,
                size: 32,
                color: canGoPrevious
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
              ),
              onPressed: canGoPrevious ? _onPrevious : null,
              tooltip: 'Previous Surah',
            ),
            // Play/Pause button
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              ),
              child: IconButton(
                iconSize: 36,
                icon: Icon(
                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                onPressed: _togglePlayPause,
                tooltip: _isPlaying ? 'Pause' : 'Play',
              ),
            ),
            // Stop button
            IconButton(
              icon: Icon(
                Icons.stop_rounded,
                size: 32,
                color: Theme.of(context).colorScheme.error,
              ),
              onPressed: _onStop,
              tooltip: 'Stop',
            ),
            // Next button
            IconButton(
              icon: Icon(
                Icons.skip_next_rounded,
                size: 32,
                color: canGoNext
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
              ),
              onPressed: canGoNext ? _onNext : null,
              tooltip: 'Next Surah',
            ),
          ],
        ),
      ],
    );
  }

  // Button handlers
  Future<void> _onPrevious() async {
    await _audioPlayer.playPreviousSurah();
  }

  Future<void> _onNext() async {
    await _audioPlayer.playNextSurah();
  }

  Future<void> _onStop() async {
    await _audioPlayer.stop();
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

      // If playing from specific highlighted verse
      if (hs != null && hv != null) {
        startSurah = hs;
        startAyah = hv;
        // End at the end of the page
        endSurah = pageEndSurah;
        endAyah = pageEndAyah;
      } else {
        // Play whole page
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
    final chosen = await showModalBottomSheet<AudioRecitation>(
      context: context,
      builder: (context) {
        final maxHeight = MediaQuery.of(context).size.height * 0.7 > 520.0
            ? 520.0
            : MediaQuery.of(context).size.height * 0.7;
        return SafeArea(
          child: SizedBox(
            height: maxHeight,
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                      AppLocalizations.of(context)
                              ?.translate('choose_reciter_title') ??
                          'Choose Reciter',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
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

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
