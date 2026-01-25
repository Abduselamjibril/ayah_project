// lib/features/downloads/downloads_screen.dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quran_app/app/app.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/services/notification_service.dart';

import '../../core/services/translation_service.dart';
import '../../core/services/tafsir_service.dart';
import '../../core/services/audio_service.dart';
import '../../data/models/translation_model.dart';
import '../../data/models/tafsir_model.dart';
import '../../data/models/audio_model.dart';
import '../../core/utils/language_utils.dart';
import '../../data/sources/remote/translation_api.dart';
import 'download_settings_page.dart';
import 'audio_surah_list_page.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TranslationService _translationService = TranslationService.instance;
  final TafsirService _tafsirService = TafsirService.instance;
  final AudioService _audioService = AudioService.instance;

  List<TranslationEdition> _availableTranslations = [];
  List<TafsirEdition> _availableTafsirs = [];
  List<AudioRecitation> _availableRecitations = [];
  List<String> _downloadedTranslations = [];
  List<String> _downloadedTafsirs = [];
  final Map<int, List<String>> _downloadedAudioSurahs =
      {}; // recitationId -> [surahNumbers]

  bool _isLoadingTranslations = true;
  bool _isLoadingTafsirs = true;
  bool _isLoadingAudio = true;

  final Map<String, double> _downloadProgress = {};
  final Map<String, bool> _isDownloading = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    // Load metadata first, then fetch downloaded assets that depend on it.
    await Future.wait([
      _loadAvailableTranslations(),
      _loadAvailableTafsirs(),
    ]);

    await _loadAvailableRecitations();

    await Future.wait([
      _loadDownloadedEditions(),
      _loadDownloadedAudio(),
    ]);
  }

  Future<void> _loadAvailableTranslations() async {
    setState(() => _isLoadingTranslations = true);
    try {
      final translations =
          await _translationService.getAllTranslationEditions();
      setState(() {
        _availableTranslations = translations;
        _isLoadingTranslations = false;
      });
    } catch (e) {
      setState(() => _isLoadingTranslations = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text((AppLocalizations.of(context)
                          ?.translate('error_loading_translations') ??
                      'Error loading translations: {error}')
                  .replaceAll('{error}', '$e'))),
        );
      }
    }
  }

  Future<void> _loadAvailableTafsirs() async {
    setState(() => _isLoadingTafsirs = true);
    try {
      final tafsirs = await _tafsirService.getAvailableTafsirs();
      setState(() {
        _availableTafsirs = tafsirs;
        _isLoadingTafsirs = false;
      });
    } catch (e) {
      setState(() => _isLoadingTafsirs = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text((AppLocalizations.of(context)
                          ?.translate('error_loading_tafsirs') ??
                      'Error loading tafsirs: {error}')
                  .replaceAll('{error}', '$e'))),
        );
      }
    }
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
    } catch (e) {
      setState(() => _isLoadingAudio = false);
      if (mounted) {
        _showSnack(
            (AppLocalizations.of(context)?.translate('error_loading_audio') ??
                    'Error loading audio recitations: {error}')
                .replaceAll('{error}', '$e'));
      }
    }
  }

  Future<void> _loadDownloadedEditions() async {
    try {
      final translations =
          await _translationService.getDownloadedTranslations();
      final tafsirs = await _tafsirService.getDownloadedTafsirs();
      setState(() {
        _downloadedTranslations = translations;
        _downloadedTafsirs = tafsirs;
      });
    } catch (e) {
      print('Error loading downloaded editions: $e');
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
    } catch (e) {
      // non-fatal
    }
  }

  Future<bool> _checkWifiPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final wifiOnly = prefs.getBool('download_wifi_only') ?? false;

    final connectivity = await Connectivity().checkConnectivity();
    final hasConnection = connectivity.isNotEmpty &&
        connectivity.any((e) => e != ConnectivityResult.none);
    if (!hasConnection) {
      _showSnack(AppLocalizations.of(context)?.translate('no_internet') ??
          'No internet connection. Please connect and retry.');
      return false;
    }

    final onWifi = connectivity.contains(ConnectivityResult.wifi);
    final onMobile = connectivity.contains(ConnectivityResult.mobile);

    // If WiFi-only is enabled, block downloads when on mobile data without prompts
    if (wifiOnly && !onWifi && onMobile) {
      _showSnack(AppLocalizations.of(context)?.translate('wifi_only_warning') ??
          'WiFi-only enabled. Connect to WiFi to download.');
      return false;
    }

    // If WiFi-only is disabled, allow downloads without any warnings
    return true;
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _downloadTranslation(TranslationEdition edition) async {
    // Check WiFi preference first
    final canProceed = await _checkWifiPreference();
    if (!canProceed) return;

    // Initialize notifications so progress stays visible while the app is active
    await AppNotificationService.instance.initialize();
    await AppNotificationService.instance.requestPermissionsIfNeeded();

    setState(() {
      _isDownloading[edition.id.toString()] = true;
      _downloadProgress[edition.id.toString()] = 0.0;
    });

    // Use a stable notification id per item
    final notifId = edition.id.hashCode & 0x7fffffff;
    try {
      final success = await _translationService.downloadTranslation(
        edition,
        onProgress: (progress) {
          setState(() {
            _downloadProgress[edition.id.toString()] = progress;
          });
          // Show progress in notification regardless of mode
          AppNotificationService.instance
              .showProgress(notifId, 'Downloading ${edition.name}', progress);
        },
      );

      if (success) {
        await _loadDownloadedEditions();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${edition.name} downloaded successfully')),
          );
        }
        await AppNotificationService.instance
            .complete(notifId, 'Downloading ${edition.name}', success: true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Download failed. Please try again.')),
          );
        }
        await AppNotificationService.instance
            .complete(notifId, 'Downloading ${edition.name}', success: false);
      }
    } finally {
      setState(() {
        _isDownloading[edition.id.toString()] = false;
        _downloadProgress.remove(edition.id.toString());
      });
      if (mounted) {
        await AppNotificationService.instance.cancel(notifId);
      }
    }
  }

  Future<void> _downloadTafsir(TafsirEdition edition) async {
    // Check WiFi preference first
    final canProceed = await _checkWifiPreference();
    if (!canProceed) return;

    await AppNotificationService.instance.initialize();
    await AppNotificationService.instance.requestPermissionsIfNeeded();

    setState(() {
      _isDownloading[edition.id.toString()] = true;
      _downloadProgress[edition.id.toString()] = 0.0;
    });

    final notifId = edition.id.hashCode & 0x7fffffff;
    try {
      final success = await _tafsirService.downloadTafsir(
        edition,
        onProgress: (progress) {
          setState(() {
            _downloadProgress[edition.id.toString()] = progress;
          });
          AppNotificationService.instance
              .showProgress(notifId, 'Downloading ${edition.name}', progress);
        },
      );

      if (success) {
        await _loadDownloadedEditions();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${edition.name} downloaded successfully')),
          );
        }
        await AppNotificationService.instance
            .complete(notifId, 'Downloading ${edition.name}', success: true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Download failed. Please try again.')),
          );
        }
        await AppNotificationService.instance
            .complete(notifId, 'Downloading ${edition.name}', success: false);
      }
    } finally {
      setState(() {
        _isDownloading[edition.id.toString()] = false;
        _downloadProgress.remove(edition.id.toString());
      });
      if (mounted) {
        await AppNotificationService.instance.cancel(notifId);
      }
    }
  }

  Future<void> _deleteTranslation(String identifier, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)
                ?.translate('delete_translation_title') ??
            'Delete Translation'),
        content: Text((AppLocalizations.of(context)
                    ?.translate('delete_translation_confirm') ??
                'Are you sure you want to delete {name}?')
            .replaceAll('{name}', name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
                AppLocalizations.of(context)?.translate('cancel') ?? 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
                AppLocalizations.of(context)?.translate('delete_action') ??
                    'Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _translationService.deleteTranslation(identifier);
      if (success) {
        await _loadDownloadedEditions();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$name deleted')),
          );
        }
      }
    }
  }

  Future<void> _deleteTafsir(String identifier, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            AppLocalizations.of(context)?.translate('delete_tafsir_title') ??
                'Delete Tafsir'),
        content: Text(
            (AppLocalizations.of(context)?.translate('delete_tafsir_confirm') ??
                    'Are you sure you want to delete {name}?')
                .replaceAll('{name}', name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
                AppLocalizations.of(context)?.translate('cancel') ?? 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
                AppLocalizations.of(context)?.translate('delete_action') ??
                    'Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _tafsirService.deleteTafsir(identifier);
      if (success) {
        await _loadDownloadedEditions();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$name deleted')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = BrandColors.accent;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leadingWidth: 100,
        leading: TextButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: accent, size: 18),
          label: Text(
            'Settings',
            style: TextStyle(
                color: accent, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          style: TextButton.styleFrom(padding: const EdgeInsets.only(left: 8)),
        ),
        title: Text(
          'Downloads',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: accent),
            tooltip: 'Download Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DownloadSettingsPage(),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: accent,
          unselectedLabelColor: theme.textTheme.bodyMedium?.color,
          indicatorColor: accent,
          tabs: [
            Tab(
                text: AppLocalizations.of(context)
                        ?.translate('tab_translations') ??
                    'Translations'),
            Tab(
                text: AppLocalizations.of(context)?.translate('tab_tafsir') ??
                    'Tafsir'),
            Tab(
                text: AppLocalizations.of(context)?.translate('tab_audio') ??
                    'Audio'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTranslationsTab(),
          _buildTafsirsTab(),
          _buildAudioTab(),
        ],
      ),
    );
  }

  Widget _buildTranslationsTab() {
    if (_isLoadingTranslations) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_availableTranslations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(AppLocalizations.of(context)
                    ?.translate('unable_load_translations') ??
                'Unable to load translations'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAvailableTranslations,
              child: Text(
                  AppLocalizations.of(context)?.translate('retry') ?? 'Retry'),
            ),
          ],
        ),
      );
    }

    // Group by language
    final groupedByLanguage = <String, List<TranslationEdition>>{};
    for (final translation in _availableTranslations) {
      groupedByLanguage.putIfAbsent(translation.languageName, () => []);
      groupedByLanguage[translation.languageName]!.add(translation);
    }

    final sortedLanguages = groupedByLanguage.keys.toList()..sort();

    print('Loaded translation languages: $sortedLanguages'); // Debug log

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: sortedLanguages.length,
      itemBuilder: (context, index) {
        final langName = sortedLanguages[index];
        final langCode = LanguageUtils.getCodeForName(langName) ??
            TranslationApi.getLanguageCode(langName);
        final hasCode = langCode != null && langCode.isNotEmpty;

        final displayFlag =
            hasCode ? LanguageUtils.getLanguageFlag(langCode) : '🌐';
        final displayName =
            hasCode ? LanguageUtils.getLanguageName(langCode) : langName;

        final translations = groupedByLanguage[langName]!;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ExpansionTile(
            leading: Text(
              displayFlag,
              style: const TextStyle(fontSize: 24),
            ),
            title: Text(
              displayName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
                (AppLocalizations.of(context)?.translate('translation_count') ??
                        '{count} translation{s}')
                    .replaceAll('{count}', '${translations.length}')),
            children: translations.map((edition) {
              final isDownloaded =
                  _downloadedTranslations.contains(edition.id.toString());
              final isDownloading =
                  _isDownloading[edition.id.toString()] == true;
              final progress = _downloadProgress[edition.id.toString()];
              final percent =
                  ((_downloadProgress[edition.id.toString()] ?? 0) * 100)
                      .clamp(0, 100)
                      .toStringAsFixed(0);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(edition.name,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: isDownloading
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                LinearProgressIndicator(value: progress),
                                const SizedBox(height: 4),
                                Text('$percent%'),
                              ],
                            )
                          : Row(
                              children: [
                                _StatusChip(
                                  label: isDownloaded
                                      ? 'Downloaded'
                                      : 'Not downloaded',
                                  color: isDownloaded
                                      ? Colors.green.shade100
                                      : Colors.orange.shade100,
                                  textColor: isDownloaded
                                      ? Colors.green.shade900
                                      : Colors.orange.shade900,
                                ),
                              ],
                            ),
                      trailing: isDownloading
                          ? const SizedBox.shrink()
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isDownloaded)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => _deleteTranslation(
                                        edition.id.toString(), edition.name),
                                  )
                                else
                                  FilledButton.icon(
                                    onPressed: () =>
                                        _downloadTranslation(edition),
                                    icon: const Icon(Icons.download),
                                    label: const Text('Download'),
                                  ),
                              ],
                            ),
                    ),
                    const Divider(height: 1),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildTafsirsTab() {
    if (_isLoadingTafsirs) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_availableTafsirs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(AppLocalizations.of(context)
                    ?.translate('unable_load_tafsirs') ??
                'Unable to load tafsirs'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAvailableTafsirs,
              child: Text(
                  AppLocalizations.of(context)?.translate('retry') ?? 'Retry'),
            ),
          ],
        ),
      );
    }

    // Group by language
    final groupedByLanguage = <String, List<TafsirEdition>>{};
    for (final tafsir in _availableTafsirs) {
      groupedByLanguage.putIfAbsent(tafsir.languageName, () => []);
      groupedByLanguage[tafsir.languageName]!.add(tafsir);
    }

    final sortedLanguages = groupedByLanguage.keys.toList()..sort();

    print('Loaded tafsir languages: $sortedLanguages'); // Debug log

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: sortedLanguages.length,
      itemBuilder: (context, index) {
        final langName = sortedLanguages[index];
        final langCode = LanguageUtils.getCodeForName(langName) ??
            TranslationApi.getLanguageCode(langName);
        final hasCode = langCode != null && langCode.isNotEmpty;

        final displayFlag =
            hasCode ? LanguageUtils.getLanguageFlag(langCode) : '🌐';
        final displayName =
            hasCode ? LanguageUtils.getLanguageName(langCode) : langName;

        final tafsirs = groupedByLanguage[langName]!;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ExpansionTile(
            leading: Text(
              displayFlag,
              style: const TextStyle(fontSize: 24),
            ),
            title: Text(
              displayName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
                (AppLocalizations.of(context)?.translate('tafsir_count') ??
                        '{count} tafsir{s}')
                    .replaceAll('{count}', '${tafsirs.length}')),
            children: tafsirs.map((edition) {
              final isDownloaded =
                  _downloadedTafsirs.contains(edition.id.toString());
              final isDownloading =
                  _isDownloading[edition.id.toString()] == true;
              final progress = _downloadProgress[edition.id.toString()];
              final percent =
                  ((_downloadProgress[edition.id.toString()] ?? 0) * 100)
                      .clamp(0, 100)
                      .toStringAsFixed(0);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(edition.name,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: isDownloading
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                LinearProgressIndicator(value: progress),
                                const SizedBox(height: 4),
                                Text('$percent%'),
                              ],
                            )
                          : Row(
                              children: [
                                _StatusChip(
                                  label: isDownloaded
                                      ? 'Downloaded'
                                      : 'Not downloaded',
                                  color: isDownloaded
                                      ? Colors.green.shade100
                                      : Colors.orange.shade100,
                                  textColor: isDownloaded
                                      ? Colors.green.shade900
                                      : Colors.orange.shade900,
                                ),
                              ],
                            ),
                      trailing: isDownloading
                          ? const SizedBox.shrink()
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isDownloaded)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => _deleteTafsir(
                                        edition.id.toString(), edition.name),
                                  )
                                else
                                  FilledButton.icon(
                                    onPressed: () => _downloadTafsir(edition),
                                    icon: const Icon(Icons.download),
                                    label: const Text('Download'),
                                  ),
                              ],
                            ),
                    ),
                    const Divider(height: 1),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // Removed old per-surah picker in favor of dedicated page

  Widget _buildAudioTab() {
    if (_isLoadingAudio) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_availableRecitations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(AppLocalizations.of(context)?.translate('unable_load_audio') ??
                'Unable to load audio recitations'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAvailableRecitations,
              child: Text(
                  AppLocalizations.of(context)?.translate('retry') ?? 'Retry'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _availableRecitations.length,
      itemBuilder: (context, index) {
        final r = _availableRecitations[index];
        final keyPrefix = '${r.id}-';
        final isAnyDownloading = _isDownloading.entries
            .any((e) => e.key.startsWith(keyPrefix) && e.value == true);
        final downloadedSurahs = _downloadedAudioSurahs[r.id] ?? [];
        final latestProgress = _downloadProgress.entries
            .where((e) => e.key.startsWith(keyPrefix))
            .map((e) => e.value)
            .fold<double>(0.0, (a, b) => b);

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            title: Text(r.reciterName,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text((AppLocalizations.of(context)
                            ?.translate('downloaded_surahs_label') ??
                        'Downloaded surahs: {list}')
                    .replaceAll(
                        '{list}',
                        downloadedSurahs.isEmpty
                            ? 'None'
                            : downloadedSurahs.join(', '))),
                const SizedBox(height: 6),
                if (isAnyDownloading)
                  LinearProgressIndicator(value: latestProgress),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AudioSurahListPage(recitation: r),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    required this.textColor,
  });

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: textColor, fontSize: 12),
      ),
    );
  }
}
