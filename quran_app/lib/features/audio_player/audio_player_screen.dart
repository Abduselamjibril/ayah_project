import 'dart:async';
import 'package:flutter/material.dart';
import 'package:quran_app/core/services/audio_service.dart';
import 'package:quran_app/data/models/audio_model.dart';
import 'package:quran_app/features/downloads/audio_surah_list_page.dart';
import 'package:quran_app/core/services/audio_player_service.dart';
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
  String _audioName = 'Select audio';
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
    return Card(
      elevation: 12,
      color: Theme.of(context).colorScheme.surface.withOpacity(0.95),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Row(
            children: [
              IconButton(
                iconSize: 28,
                icon: _isDownloading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          value:
                              _downloadProgress > 0 ? _downloadProgress : null,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                onPressed: _togglePlayPause,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _audioName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_reciterName.isNotEmpty)
                      Text(
                        _reciterName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.menu),
                onPressed: _openAudioPicker,
                color: Theme.of(context).colorScheme.onSurface,
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

    // Step 2: Determine which surah to play
    // Highlighted verse has priority
    final hs = widget.controller.highlightedSurah;
    final hv = widget.controller.highlightedVerse;
    int surah;
    int startAyah = 1;

    if (hs != null && hv != null) {
      surah = hs;
      startAyah = hv;
    } else {
      // Use current page
      await AudioService.instance.initialize();
      final currentPage = widget.controller.currentPage;
      final pd = getPageData(currentPage);
      surah = 1;
      if (pd.isNotEmpty) {
        surah = int.tryParse(pd.first['surah'].toString()) ?? 1;
      }
    }

    final recitationId = recitation.id;
    final surahLabel = getSurahName(surah);

    // Step 3: Check if audio is downloaded, if not download it
    final hasLocal =
        await AudioService.instance.isSurahDownloaded(recitationId, surah);
    if (!hasLocal) {
      final ok = await _audioPlayer.downloadSurahIfNeeded(recitation, surah);
      if (!ok) {
        _showSnack('Could not download audio for Surah $surah');
        return;
      }
    }

    // Step 4: Play the audio
    try {
      await _audioPlayer.playSurahSequence(
        surah: surah,
        startAyah: startAyah,
        surahLabel: surahLabel,
        reciterName: recitation.reciterName,
      );
    } catch (e) {
      _showSnack('Audio failed to start: $e');
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

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
