import 'dart:async';
import 'package:flutter/material.dart';
import 'package:quran_app/core/services/audio_service.dart';
import 'package:quran_app/data/models/audio_model.dart';
import 'package:quran_app/features/downloads/audio_surah_list_page.dart';
import 'package:quran_app/core/services/audio_player_service.dart';
import '../../core/quran/qcf_quran.dart';
import '../../features/bookmarks/state/bookmark_notes_notifier.dart';
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
  bool _isPlaying = false;
  String _audioName = 'Select audio';
  AudioRecitation? _selectedRecitation;
  bool _isSequentialMode = false;
  int _sequenceToken = 0;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayerService.instance;
    _isPlaying = _audioPlayer.isPlaying.value;
    _audioName = _audioPlayer.currentLabel.value;
    _playerStateListener = () {
      if (!mounted) return;
      setState(() => _isPlaying = _audioPlayer.isPlaying.value);
    };
    _labelListener = () {
      if (!mounted) return;
      setState(() => _audioName = _audioPlayer.currentLabel.value);
    };
    _audioPlayer.isPlaying.addListener(_playerStateListener);
    _audioPlayer.currentLabel.addListener(_labelListener);
  }

  @override
  void dispose() {
    _audioPlayer.isPlaying.removeListener(_playerStateListener);
    _audioPlayer.currentLabel.removeListener(_labelListener);
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
                icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                onPressed: _togglePlayPause,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _audioName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
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
        // fall through to surah logic
      }
    }

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

  Future<void> _openAudioPicker() async {
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
                              trailing: const Icon(Icons.play_arrow),
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
  }) {
    final token = ++_sequenceToken;
    _isSequentialMode = true;
    Future.microtask(() => _runSurahSequence(
          token: token,
          surah: surah,
          surahLabel: surahLabel,
          reciterName: reciterName,
        ));
  }

  Future<void> _runSurahSequence({
    required int token,
    required int surah,
    required String surahLabel,
    required String reciterName,
  }) async {
    await _audioPlayer.stop();
    final totalAyat = getVerseCount(surah);
    for (var ayah = 1; ayah <= totalAyat; ayah++) {
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

  Future<void> _playAudio(int surah, int verse) async {
    final recitation = await _ensureReciterSelected();
    if (recitation == null) return;
    try {
      await _audioPlayer.playAyahPreferLocal(
        surah: surah,
        ayah: verse,
        surahName: getSurahName(surah),
        reciterName: recitation.reciterName,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio not available for this verse')),
      );
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
