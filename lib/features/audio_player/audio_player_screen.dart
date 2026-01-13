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

const _brandGreen = Color(0xFF0B7743);

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
                          style: const TextStyle(
                            color: _brandGreen,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.expand_more_rounded,
                        color: _brandGreen,
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
                      .surfaceVariant
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
                            value:
                                _downloadProgress > 0 ? _downloadProgress : null,
                            strokeWidth: 3,
                            color: _brandGreen,
                          ),
                        )
                      : Icon(
                          _isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: _brandGreen,
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
    final surahLabel = getLocalizedSurahName(context, surah);

    // Step 3: Check if audio is downloaded, if not download it
    final hasLocal =
        await AudioService.instance.isSurahDownloaded(recitationId, surah);
    if (!hasLocal) {
      final downloadTitle =
          (AppLocalizations.of(context)?.translate('downloading_surah') ??
                  'Downloading Surah {number} ({reciter})')
              .replaceAll('{number}', '$surah')
              .replaceAll('{reciter}', recitation.reciterName);

      final ok = await _audioPlayer.downloadSurahIfNeeded(recitation, surah,
          notificationTitle: downloadTitle);
      if (!ok) {
        _showSnack(
            (AppLocalizations.of(context)?.translate('download_surah_error') ??
                    'Could not download audio for Surah {surah}')
                .replaceAll('{surah}', '$surah'));

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
