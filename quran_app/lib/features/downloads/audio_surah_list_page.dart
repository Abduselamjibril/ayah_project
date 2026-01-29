// lib/features/downloads/audio_surah_list_page.dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:quran_app/data/models/audio_model.dart';
import 'package:quran_app/data/models/chapter_model.dart';
import 'package:quran_app/data/sources/remote/chapter_api.dart';
import 'package:quran_app/core/services/audio_service.dart';
import 'package:quran_app/core/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quran_app/core/i18n/app_localizations.dart';
import 'package:quran_app/core/utils/localization_helper.dart';

class AudioSurahListPage extends StatefulWidget {
  final AudioRecitation recitation;
  const AudioSurahListPage({super.key, required this.recitation});

  @override
  State<AudioSurahListPage> createState() => _AudioSurahListPageState();
}

class _AudioSurahListPageState extends State<AudioSurahListPage> {
  final ChapterApi _chapterApi = ChapterApi();
  final AudioService _audioService = AudioService.instance;

  bool _loading = true;
  List<Chapter> _chapters = [];
  final Set<int> _downloadingSurahs = {};
  final Map<int, double> _progress = {}; // surahNumber -> progress
  Set<int> _downloadedSurahs = {};
  bool _isBulkDownloading = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _loading = true);
    try {
      await _audioService.initialize();
      final language =
          AppLocalizations.of(context)?.locale.languageCode ?? 'en';
      final chapters = await _chapterApi.getChapters(language: language);
      final downloaded =
          await _audioService.getDownloadedSurahs(widget.recitation.id);
      setState(() {
        _chapters = chapters;
        _downloadedSurahs = downloaded
            .map((s) => int.tryParse(s) ?? 0)
            .where((n) => n > 0)
            .toSet();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text((AppLocalizations.of(context)
                        ?.translate('failed_load_surahs') ??
                    'Failed to load surahs: {error}')
                .replaceAll('{error}', '$e'))),
      );
    }
  }

  Future<bool> _canDownload() async {
    final prefs = await SharedPreferences.getInstance();
    final wifiOnly = prefs.getBool('download_wifi_only') ?? false;

    final connectivity = await Connectivity().checkConnectivity();
    final hasConnection = connectivity.isNotEmpty &&
        connectivity.any((e) => e != ConnectivityResult.none);
    if (!hasConnection) {
      await _showNoInternetDialog();
      return false;
    }

    final onWifi = connectivity.contains(ConnectivityResult.wifi);
    final onMobile = connectivity.contains(ConnectivityResult.mobile);
    if (wifiOnly && !onWifi && onMobile) {
      _showSnack(AppLocalizations.of(context)?.translate('wifi_only_warning') ??
          'WiFi-only enabled. Connect to WiFi to download.');
      return false;
    }

    return true;
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _showNoInternetDialog() async {
    if (!mounted) return;
    final title = AppLocalizations.of(context)?.translate('offline') ??
        'No internet connection';
    final message = AppLocalizations.of(context)?.translate('no_internet') ??
        'Please connect to the internet and try again.';

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)?.translate('ok') ?? 'OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _download(int surahNumber) async {
    final canDownload = await _canDownload();
    if (!canDownload) return;
    await _downloadSingle(surahNumber);
  }

  Future<void> _downloadSingle(int surahNumber) async {
    if (_downloadingSurahs.contains(surahNumber)) return;
    setState(() {
      _downloadingSurahs.add(surahNumber);
      _progress[surahNumber] = 0.0;
    });

    final notifId =
        ('audio-${widget.recitation.id}-$surahNumber').hashCode & 0x7fffffff;
    await AppNotificationService.instance.initialize();
    await AppNotificationService.instance.requestPermissionsIfNeeded();

    try {
      final ok = await _audioService.downloadSurahAudio(
        widget.recitation,
        surahNumber,
        onProgress: (p) {
          setState(() => _progress[surahNumber] = p);
        },
      );
      if (ok) {
        setState(() => _downloadedSurahs.add(surahNumber));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text((AppLocalizations.of(context)
                          ?.translate('downloaded_surah') ??
                      'Downloaded Surah {number}')
                  .replaceAll('{number}', '$surahNumber'))),
        );
        await AppNotificationService.instance.complete(
            notifId,
            (AppLocalizations.of(context)?.translate('downloading_surah') ??
                    'Downloading Surah {number} ({reciter})')
                .replaceAll('{number}', '$surahNumber')
                .replaceAll('{reciter}', widget.recitation.reciterName),
            success: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  AppLocalizations.of(context)?.translate('download_failed') ??
                      'Audio download failed.')),
        );
        await AppNotificationService.instance.complete(
            notifId,
            (AppLocalizations.of(context)?.translate('downloading_surah') ??
                    'Downloading Surah {number} ({reciter})')
                .replaceAll('{number}', '$surahNumber')
                .replaceAll('{reciter}', widget.recitation.reciterName),
            success: false);
      }
    } finally {
      setState(() {
        _downloadingSurahs.remove(surahNumber);
        _progress.remove(surahNumber);
      });
      await AppNotificationService.instance.cancel(notifId);
    }
  }

  Future<void> _downloadAll() async {
    if (_isBulkDownloading) return;
    final canDownload = await _canDownload();
    if (!canDownload) return;

    final pending = _chapters
        .map((c) => c.id)
        .where((id) => !_downloadedSurahs.contains(id))
        .toList();
    if (pending.isEmpty) return;

    setState(() => _isBulkDownloading = true);
    try {
      for (final surahNumber in pending) {
        if (!mounted) return;
        await _downloadSingle(surahNumber);
      }
    } finally {
      if (mounted) setState(() => _isBulkDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text((AppLocalizations.of(context)?.translate('surahs_title') ??
                'Surahs - {reciter}')
            .replaceAll('{reciter}', widget.recitation.reciterName)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _chapters.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  final pendingCount = _chapters
                      .where((c) => !_downloadedSurahs.contains(c.id))
                      .length;
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: FilledButton.icon(
                      onPressed: pendingCount == 0 || _isBulkDownloading
                          ? null
                          : _downloadAll,
                      icon: _isBulkDownloading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download),
                      label: Text(
                        AppLocalizations.of(context)
                                ?.translate('download_all') ??
                            'Download all',
                      ),
                    ),
                  );
                }

                final c = _chapters[index - 1];
                final surahNumber = c.id;
                final isDownloading = _downloadingSurahs.contains(surahNumber);
                final progress = _progress[surahNumber];
                final isDownloaded = _downloadedSurahs.contains(surahNumber);
                final surahName = getBilingualSurahName(context, c.id);
                return ListTile(
                  title: Text(
                      '${surahNumber.toString().padLeft(3, '0')} - $surahName'),
                  subtitle: isDownloading
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LinearProgressIndicator(value: progress),
                            const SizedBox(height: 4),
                            Text(
                                '${((progress ?? 0) * 100).toStringAsFixed(0)}%'),
                          ],
                        )
                      : Text(isDownloaded
                          ? (AppLocalizations.of(context)
                                  ?.translate('downloaded') ??
                              'Downloaded')
                          : (AppLocalizations.of(context)
                                      ?.translate('verses_count') ??
                                  '{count} verses')
                              .replaceAll('{count}', '${c.versesCount}')),
                  trailing: isDownloading
                      ? const SizedBox.shrink()
                      : isDownloaded
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : IconButton(
                              icon: const Icon(Icons.download),
                              onPressed: () => _download(surahNumber),
                            ),
                );
              },
            ),
    );
  }
}
