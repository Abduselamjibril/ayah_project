import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:quran_app/app/app.dart';
import 'package:quran_app/core/i18n/app_localizations.dart';
import 'package:quran_app/core/quran/qcf_quran.dart';
import 'package:quran_app/core/services/audio_player_service.dart';
import 'package:quran_app/core/services/audio_service.dart';
import 'package:quran_app/core/utils/localization_helper.dart';
import 'package:quran_app/data/models/audio_model.dart';
import 'package:quran_app/features/downloads/audio_surah_list_page.dart';
import 'package:quran_app/features/mushaf/controller/mushaf_controller.dart';
import 'package:quran_app/features/mushaf/widgets/mushaf_audio_navigation.dart';

/// Reusable audio player card used by mushaf views.
class AudioPlayerCard extends StatefulWidget {
  final MushafController controller;
  final ValueChanged<bool>? onExpandChanged;
  const AudioPlayerCard(
      {Key? key, required this.controller, this.onExpandChanged})
      : super(key: key);

  @override
  State<AudioPlayerCard> createState() => _AudioPlayerCardState();
}

class _AudioPlayerCardState extends State<AudioPlayerCard> {
  bool? _lastReportedExpanded;
  late final AudioPlayerService _audioPlayer;
  late final VoidCallback _playerStateListener;
  late final VoidCallback _labelListener;
  late final VoidCallback _downloadingListener;
  late final VoidCallback _downloadProgressListener;
  late final VoidCallback _reciterListener;
  late final VoidCallback _verseListener;
  late final VoidCallback _hasSourceListener;
  late final VoidCallback _speedListener;
  late final VoidCallback _loopListener;

  bool _isPlaying = false;
  String _audioName = '';

  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _reciterName = '';
  bool _hasSource = false;
  double _playbackSpeed = 1.0;
  LoopMode _loopMode = LoopMode.off;
  bool _showExpanded = false;

  String get _labelText => _audioName.isEmpty
      ? (AppLocalizations.of(context)?.translate('select_recitation') ??
          'Select Recitation')
      : _audioName;

  String get _statusText {
    if (_isDownloading) {
      final pct = (_downloadProgress * 100).clamp(0, 100).toInt();
      return 'Downloading${_downloadProgress > 0 ? ' $pct%' : '...'}';
    }
    if (_reciterName.isNotEmpty) return _reciterName;
    return AppLocalizations.of(context)?.translate('select_recitation') ??
        'Select Recitation';
  }

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayerService.instance;
    _initAudioService();
    _isPlaying = _audioPlayer.isPlaying.value;
    _audioName = _audioPlayer.currentLabel.value;
    _hasSource = _audioPlayer.hasSourceNotifier.value;
    _isDownloading = _audioPlayer.isDownloading.value;
    _downloadProgress = _audioPlayer.downloadProgress.value;
    _playbackSpeed = _audioPlayer.playbackSpeed.value;
    _loopMode = _audioPlayer.loopMode.value;

    _reciterName = _audioPlayer.recitationName;
    // Always expand if downloading, playing, or has source
    _showExpanded = _isDownloading || _isPlaying || _hasSource;

    void notifyExpand() {
      widget.onExpandChanged?.call(_showExpanded);
    }

    _playerStateListener = () {
      if (!mounted) return;
      final playing = _audioPlayer.isPlaying.value;
      final hasSource = _audioPlayer.hasSourceNotifier.value;
      setState(() {
        _isPlaying = playing;
        _hasSource = hasSource;
        // Keep expanded when downloading, playing, or hasSource
        if (playing || hasSource || _isDownloading) {
          _showExpanded = true;
        } else if (!_isDownloading) {
          _showExpanded = false;
        }
        notifyExpand();
      });
    };
    _labelListener = () {
      if (!mounted) return;
      setState(() => _audioName = _audioPlayer.currentLabel.value);
    };
    _downloadingListener = () {
      if (!mounted) return;
      final downloading = _audioPlayer.isDownloading.value;
      setState(() {
        _isDownloading = downloading;
        if (downloading) {
          _showExpanded = true;
        } else if (!_isPlaying && !_hasSource) {
          _showExpanded = false;
        }
        notifyExpand();
      });
    };
    _downloadProgressListener = () {
      if (!mounted) return;
      setState(() => _downloadProgress = _audioPlayer.downloadProgress.value);
    };
    _reciterListener = () {
      if (!mounted) return;
      setState(() => _reciterName = _audioPlayer.recitationName);
    };
    _hasSourceListener = () {
      if (!mounted) return;
      setState(() => _hasSource = _audioPlayer.hasSourceNotifier.value);
    };
    _speedListener = () {
      if (!mounted) return;
      setState(() => _playbackSpeed = _audioPlayer.playbackSpeed.value);
    };
    _loopListener = () {
      if (!mounted) return;
      setState(() => _loopMode = _audioPlayer.loopMode.value);
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
    _audioPlayer.hasSourceNotifier.addListener(_hasSourceListener);
    _audioPlayer.playbackSpeed.addListener(_speedListener);
    _audioPlayer.loopMode.addListener(_loopListener);
  }

  Future<void> _initAudioService() async {
    try {
      await _audioPlayer.init();
      if (!mounted) return;
      setState(() {
        _reciterName = _audioPlayer.recitationName;
      });
    } catch (_) {
      // ignore init errors here
    }
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
    _audioPlayer.hasSourceNotifier.removeListener(_hasSourceListener);
    _audioPlayer.playbackSpeed.removeListener(_speedListener);
    _audioPlayer.loopMode.removeListener(_loopListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = BrandColors.accent;

    // Always show expanded view if downloading, playing, or has source
    final showExpanded =
        _isDownloading || _isPlaying || _hasSource || _showExpanded;

    // Notify parent if expanded/collapsed state changes
    if (_lastReportedExpanded != showExpanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onExpandChanged?.call(showExpanded);
      });
      _lastReportedExpanded = showExpanded;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.transparent,
      child: showExpanded
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: colorScheme.surface,
                border: Border.all(
                  color: colorScheme.onSurface.withOpacity(0.25),
                  width: 1.2,
                ),
              ),
              child: _buildExpandedPlayer(colorScheme, accent),
            )
          : _buildCompactSelector(colorScheme, accent),
    );
  }

  Widget _buildCompactSelector(ColorScheme colorScheme, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(50),
        color: colorScheme.surface,
        border: Border.all(
          color: colorScheme.onSurface.withOpacity(0.25),
          width: 1.2,
        ),
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
                      _statusText,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down,
                    size: 18,
                    color: colorScheme.onSurface.withOpacity(0.65),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            iconSize: 26,
            padding: const EdgeInsets.all(10),
            icon: Icon(
              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: accent,
            ),
            onPressed: _isDownloading
                ? null
                : () async {
                    // pressing play from compact expands and starts/resumes
                    await _togglePlayPause();
                    setState(() => _showExpanded = true);
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedPlayer(ColorScheme colorScheme, Color accent) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header with close button
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _openAudioPicker,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _labelText,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: _isDownloading
                            ? Row(
                                key: const ValueKey('downloading'),
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      value: _downloadProgress > 0
                                          ? _downloadProgress
                                          : null,
                                      strokeWidth: 2.5,
                                      color: accent,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      _statusText,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: colorScheme.onSurface
                                            .withOpacity(0.75),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                key: const ValueKey('ready'),
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      _statusText,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: colorScheme.onSurface
                                            .withOpacity(0.75),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.keyboard_arrow_down,
                                    size: 18,
                                    color:
                                        colorScheme.onSurface.withOpacity(0.65),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              iconSize: 20,
              padding: const EdgeInsets.all(8),
              tooltip: 'Stop',
              icon: Icon(
                Icons.close_rounded,
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
              onPressed: () async {
                await _audioPlayer.stop();
                setState(() => _showExpanded = false);
              },
            ),
          ],
        ),
        if (_isDownloading)
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: _downloadProgress > 0 ? _downloadProgress : null,
                minHeight: 6,
                color: accent,
                backgroundColor: colorScheme.onSurface.withOpacity(0.08),
              ),
            ),
          )
        else
          const SizedBox(height: 6),
        Row(
          children: [
            _buildSpeedBadge(accent),
            const Spacer(),
            _roundControlButton(
              icon: Icons.skip_previous_rounded,
              onPressed: _hasSource
                  ? () => _audioPlayer.playPreviousSurah(context)
                  : null,
              colorScheme: colorScheme,
            ),
            const SizedBox(width: 10),
            _roundControlButton(
              icon: _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              onPressed: _isDownloading ? null : _togglePlayPause,
              colorScheme: colorScheme,
              filled: true,
              showProgress: _isDownloading,
            ),
            const SizedBox(width: 10),
            _roundControlButton(
              icon: Icons.skip_next_rounded,
              onPressed:
                  _hasSource ? () => _audioPlayer.playNextSurah(context) : null,
              colorScheme: colorScheme,
            ),
            const SizedBox(width: 10),
            _roundControlButton(
              icon: Icons.repeat_rounded,
              onPressed: _toggleLoop,
              colorScheme: colorScheme,
              active: _loopMode != LoopMode.off,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSpeedBadge(Color accent) {
    final speedLabel =
        _playbackSpeed.toStringAsFixed(_playbackSpeed % 1 == 0 ? 0 : 2);
    return InkWell(
      onTap: _showSpeedPicker,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: accent.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '${speedLabel}x',
          style: TextStyle(
            color: accent,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _roundControlButton({
    required IconData icon,
    required ColorScheme colorScheme,
    VoidCallback? onPressed,
    bool filled = false,
    bool showProgress = false,
    bool active = false,
  }) {
    final isDisabled = onPressed == null;
    final bgColor = filled
        ? BrandColors.accent.withOpacity(0.95)
        : active
            ? BrandColors.accent.withOpacity(0.18)
            : colorScheme.surfaceContainerHighest.withOpacity(0.55);
    final iconColor = filled
        ? colorScheme.onPrimary
        : active
            ? BrandColors.accent
            : colorScheme.onSurface.withOpacity(isDisabled ? 0.35 : 0.85);

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor,
        border: active
            ? Border.all(color: BrandColors.accent.withOpacity(0.6))
            : null,
      ),
      child: IconButton(
        iconSize: filled ? 28 : 24,
        padding: const EdgeInsets.all(10),
        onPressed: isDisabled || showProgress ? null : onPressed,
        icon: showProgress
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  value: _downloadProgress > 0 ? _downloadProgress : null,
                  strokeWidth: 3,
                  color: BrandColors.accent,
                ),
              )
            : Icon(icon, color: iconColor),
      ),
    );
  }

  Future<void> _showSpeedPicker() async {
    final speeds = <double>[0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    final selected = await showModalBottomSheet<double>(
      context: context,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: speeds
                .map(
                  (s) => ListTile(
                    title: Text('${s.toStringAsFixed(s % 1 == 0 ? 0 : 2)}x'),
                    trailing: s == _playbackSpeed
                        ? Icon(Icons.check, color: scheme.primary)
                        : null,
                    onTap: () => Navigator.of(ctx).pop(s),
                  ),
                )
                .toList(),
          ),
        );
      },
    );

    if (selected != null) {
      await _audioPlayer.setSpeed(selected);
    }
  }

  Future<void> _toggleLoop() async {
    final next = _loopMode == LoopMode.off ? LoopMode.all : LoopMode.off;
    await _audioPlayer.setLoopMode(next);
  }

  Future<void> _openDownloads() async {
    await _navigateToDownloadSurah(_audioPlayer.recitationId);
  }

  Future<void> _startPlaybackFromCurrentPage() async {
    // Ensure reciter selection
    AudioRecitation? recitation;
    if (_audioPlayer.userSelectedReciter) {
      recitation = _audioPlayer.getSelectedRecitation();
    }
    if (recitation == null) {
      recitation = await _ensureReciterSelected();
      if (recitation == null) return;
    }

    // Determine playback range from current page
    final hs = widget.controller.highlightedSurah;
    final hv = widget.controller.highlightedVerse;

    int startSurah;
    int startAyah;
    int endSurah;
    int endAyah;

    await AudioService.instance.initialize();
    final currentPage = widget.controller.currentPage;
    final pd = getPageData(currentPage);

    if (pd.isEmpty) {
      startSurah = 1;
      startAyah = 1;
      endSurah = 1;
      endAyah = 7;
    } else {
      final firstVerse = pd.first;
      final lastVerse = pd.last;

      final pageStartSurah = int.tryParse(firstVerse['surah'].toString()) ?? 1;
      final pageStartAyah = int.tryParse(firstVerse['start'].toString()) ?? 1;
      final pageEndSurah = int.tryParse(lastVerse['surah'].toString()) ?? 1;
      final pageEndAyah = int.tryParse(lastVerse['end'].toString()) ?? 1;

      bool isHighlightOnCurrentPage = false;
      if (hs != null && hv != null) {
        try {
          final p = getPageNumber(hs, hv);
          if (p == currentPage) {
            isHighlightOnCurrentPage = true;
          }
        } catch (_) {}
      }

      if (isHighlightOnCurrentPage && hs != null && hv != null) {
        startSurah = hs;
        startAyah = hv;
        endSurah = pageEndSurah;
        endAyah = pageEndAyah;
      } else {
        startSurah = pageStartSurah;
        startAyah = pageStartAyah;
        endSurah = pageEndSurah;
        endAyah = pageEndAyah;
      }
    }

    try {
      await _audioPlayer.playRangeSequenceWithDownload(
        context,
        startSurah: startSurah,
        startAyah: startAyah,
        endSurah: endSurah,
        endAyah: endAyah,
        forceReciter: true,
      );
    } catch (e) {
      _showSnack(
          (AppLocalizations.of(context)?.translate('audio_start_error') ??
                  'Audio failed to start: {error}')
              .replaceAll('{error}', '$e'));
    }
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

    // No source loaded - start playback for current page with selected reciter
    await _startPlaybackFromCurrentPage();
  }

  Future<void> _openAudioPicker() async {
    await _ensureReciterSelected(force: true);
  }

  Future<void> _navigateToDownloadSurah(int recitationId) async {
    final recitation = AudioRecitation(
        id: recitationId, reciterName: _audioPlayer.recitationName);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => AudioSurahListPage(recitation: recitation)),
    );
  }

  Future<AudioRecitation?> _ensureReciterSelected({bool force = false}) async {
    await AudioService.instance.initialize();
    final recitations = await AudioService.instance.getAvailableRecitations();
    if (!mounted) return null;
    final chosen = await showReciterPickerSheet(context, recitations);
    if (chosen != null) {
      final wasPlaying = _audioPlayer.isPlaying.value || _audioPlayer.hasSource;
      _audioPlayer.setRecitationInfo(id: chosen.id, name: chosen.reciterName);
      if (wasPlaying) {
        await _audioPlayer.stop();
        if (!mounted) return chosen;
        setState(() => _showExpanded = false);
      }
    }
    return chosen;
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
