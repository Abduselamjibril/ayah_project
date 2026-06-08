// lib/features/downloads/downloads_audio_screen.dart
import 'package:flutter/material.dart';
import 'package:quran_app/app/app.dart';
import '../../core/i18n/app_localizations.dart';
import 'package:quran_app/features/settings/widgets/settings_app_bar.dart';
import '../../core/services/audio_service.dart';
import '../../data/models/audio_model.dart';
import 'audio_surah_list_page.dart';

class DownloadsAudioScreen extends StatefulWidget {
  const DownloadsAudioScreen({super.key});

  @override
  State<DownloadsAudioScreen> createState() => _DownloadsAudioScreenState();
}

class _DownloadsAudioScreenState extends State<DownloadsAudioScreen> {
  final AudioService _audioService = AudioService.instance;
  List<AudioRecitation> _availableRecitations = [];
  final Map<int, List<String>> _downloadedAudioSurahs =
      {}; // recitationId -> [surahNumbers]
  bool _isLoadingAudio = true;
  final Map<String, double> _downloadProgress = {};
  final Map<String, bool> _isDownloading = {};
  bool _downloadedSectionExpanded = true;

  @override
  void initState() {
    super.initState();
    _loadAvailableRecitations();
  }

  Future<void> _loadAvailableRecitations() async {
    setState(() => _isLoadingAudio = true);
    try {
      await _audioService.initialize();
      final recitations = await _audioService.getAvailableRecitations();
      setState(() {
        _availableRecitations = recitations;
        _isLoadingAudio = false;
      });
      await _loadDownloadedAudio();
    } catch (_) {
      setState(() => _isLoadingAudio = false);
    }
  }

  Future<void> _loadDownloadedAudio() async {
    try {
      _downloadedAudioSurahs.clear();
      if (_availableRecitations.isEmpty) return;
      for (final r in _availableRecitations) {
        final surahs = await _audioService.getDownloadedSurahs(r.id);
        _downloadedAudioSurahs[r.id] = surahs;
      }
      if (mounted) setState(() {});
    } catch (_) {
      // non-fatal
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final cardBackground = isLight
        ? theme.scaffoldBackgroundColor
        : theme.cardColor.withOpacity(0.5);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: SettingsAppBar(
        title: AppLocalizations.of(context)?.translate('tab_audio') ?? 'Audio',
        leadingLabel: AppLocalizations.of(context)?.translate('storage_title') ??
            'Storage',
      ),
      body: _isLoadingAudio
          ? const Center(child: CircularProgressIndicator())
          : _availableRecitations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(AppLocalizations.of(context)
                              ?.translate('unable_load_audio') ??
                          'Unable to load audio recitations'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadAvailableRecitations,
                        child: Text(
                            AppLocalizations.of(context)?.translate('retry') ??
                                'Retry'),
                      ),
                    ],
                  ),
                )
              : _buildAudioList(cardBackground),
    );
  }

  Widget _buildAudioList(Color cardBackground) {
    final theme = Theme.of(context);
    final dividerColor = theme.dividerColor.withOpacity(0.15);

    final downloadedReciters = _availableRecitations
        .where((r) => (_downloadedAudioSurahs[r.id] ?? []).isNotEmpty)
        .toList();

    Widget buildReciterRow(AudioRecitation r) {
      final keyPrefix = '${r.id}-';
      final isAnyDownloading = _isDownloading.entries
          .any((e) => e.key.startsWith(keyPrefix) && e.value == true);
      final latestProgress = _downloadProgress.entries
          .where((e) => e.key.startsWith(keyPrefix))
          .map((e) => e.value)
          .fold<double>(0.0, (a, b) => b);
      final downloadedSurahs = _downloadedAudioSurahs[r.id] ?? [];

      return InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AudioSurahListPage(recitation: r),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      r.reciterName,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                (AppLocalizations.of(context)
                            ?.translate('downloaded_surahs_label') ??
                        'Downloaded surahs: {list}')
                    .replaceAll(
                        '{list}',
                        downloadedSurahs.isEmpty
                            ? 'None'
                            : downloadedSurahs.join(', ')),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)),
              ),
              if (isAnyDownloading) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(value: latestProgress),
              ],
            ],
          ),
        ),
      );
    }

    Widget buildGroupCard(List<AudioRecitation> reciters) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: dividerColor),
          ),
          child: Column(
            children: [
              for (var i = 0; i < reciters.length; i++) ...[
                buildReciterRow(reciters[i]),
                if (i != reciters.length - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Divider(height: 1, thickness: 1, color: dividerColor),
                  ),
              ],
            ],
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (downloadedReciters.isNotEmpty) ...[
          InkWell(
            onTap: () {
              setState(() {
                _downloadedSectionExpanded = !_downloadedSectionExpanded;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Text(
                    AppLocalizations.of(context)?.translate('downloaded') ??
                        'Downloaded',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _downloadedSectionExpanded ? 0.0 : 0.5,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.expand_more),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: buildGroupCard(downloadedReciters),
            secondChild: const SizedBox.shrink(),
            crossFadeState: _downloadedSectionExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 200),
          ),
          const SizedBox(height: 16),
        ],
        Text(
          AppLocalizations.of(context)?.translate('available') ?? 'Available',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 8),
        buildGroupCard(_availableRecitations),
      ],
    );
  }
}
