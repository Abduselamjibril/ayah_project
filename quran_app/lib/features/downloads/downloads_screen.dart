// lib/features/downloads/downloads_screen.dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/background_download_service.dart';
import '../../core/services/translation_service.dart';
import '../../core/services/tafsir_service.dart';
import '../../data/models/translation_model.dart';
import '../../data/models/tafsir_model.dart';
import '../../core/utils/language_utils.dart';
import '../../data/sources/remote/translation_api.dart';
import 'download_settings_page.dart';

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

  List<TranslationEdition> _availableTranslations = [];
  List<TafsirEdition> _availableTafsirs = [];
  List<String> _downloadedTranslations = [];
  List<String> _downloadedTafsirs = [];

  bool _isLoadingTranslations = true;
  bool _isLoadingTafsirs = true;

  final Map<String, double> _downloadProgress = {};
  final Map<String, bool> _isDownloading = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadAvailableTranslations(),
      _loadAvailableTafsirs(),
      _loadDownloadedEditions(),
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
          SnackBar(content: Text('Error loading translations: $e')),
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
          SnackBar(content: Text('Error loading tafsirs: $e')),
        );
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

  Future<bool> _checkWifiPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final wifiOnly = prefs.getBool('download_wifi_only') ?? false;

    final connectivity = await Connectivity().checkConnectivity();
    final hasConnection = connectivity.isNotEmpty &&
        connectivity.any((e) => e != ConnectivityResult.none);
    if (!hasConnection) {
      _showSnack('No internet connection. Please connect and retry.');
      return false;
    }

    final onWifi = connectivity.contains(ConnectivityResult.wifi);
    final onMobile = connectivity.contains(ConnectivityResult.mobile);

    // If WiFi-only is enabled, block downloads when on mobile data without prompts
    if (wifiOnly && !onWifi && onMobile) {
      _showSnack('WiFi-only enabled. Connect to WiFi to download.');
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

    // Always initialize notifications so both foreground and background paths surface progress
    await AppNotificationService.instance.initialize();
    await AppNotificationService.instance.requestPermissionsIfNeeded();

    setState(() {
      _isDownloading[edition.id.toString()] = true;
      _downloadProgress[edition.id.toString()] = 0.0;
    });

    // Use a stable notification id per item
    final notifId = edition.id.hashCode & 0x7fffffff;
    try {
      final useBackground =
          await BackgroundDownloadService.instance.isBackgroundEnabled();
      final bgUrl =
          useBackground ? _translationService.getDownloadUrl(edition) : null;
      final effectiveBackground = useBackground && bgUrl != null;
      if (effectiveBackground) {
        await BackgroundDownloadService.instance.initialize();
        BackgroundDownloadService.registerCallback();
        await BackgroundDownloadService.instance
            .enqueue(url: bgUrl, fileName: '${edition.id}.json');
      }
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
      final useBackground =
          await BackgroundDownloadService.instance.isBackgroundEnabled();
      final bgUrl =
          useBackground ? _tafsirService.getDownloadUrl(edition) : null;
      final effectiveBackground = useBackground && bgUrl != null;
      if (effectiveBackground) {
        await BackgroundDownloadService.instance.initialize();
        BackgroundDownloadService.registerCallback();
        await BackgroundDownloadService.instance
            .enqueue(url: bgUrl, fileName: '${edition.id}.json');
      }
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
        title: const Text('Delete Translation'),
        content: Text('Are you sure you want to delete $name?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
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
        title: const Text('Delete Tafsir'),
        content: Text('Are you sure you want to delete $name?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
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
          tabs: const [
            Tab(text: 'Translations'),
            Tab(text: 'Tafsir'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTranslationsTab(),
          _buildTafsirsTab(),
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
            const Text('Unable to load translations'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAvailableTranslations,
              child: const Text('Retry'),
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

        return ExpansionTile(
          leading: Text(
            displayFlag,
            style: const TextStyle(fontSize: 24),
          ),
          title: Text(
            displayName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
              '${translations.length} translation${translations.length > 1 ? 's' : ''}'),
          children: translations.map((edition) {
            final isDownloaded =
                _downloadedTranslations.contains(edition.id.toString());
            final isDownloading = _isDownloading[edition.id.toString()] == true;
            final progress = _downloadProgress[edition.id.toString()];
            const isSelected = false; // selection managed in TafsirScreen only
            final percent =
                ((_downloadProgress[edition.id.toString()] ?? 0) * 100)
                    .clamp(0, 100)
                    .toStringAsFixed(0);

            return ListTile(
              title: Text(edition.name),
              subtitle: isDownloading
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LinearProgressIndicator(value: progress),
                        const SizedBox(height: 4),
                        Text('$percent%'),
                      ],
                    )
                  : Text(isDownloaded ? 'Downloaded' : 'Not downloaded'),
              onTap: null,
              trailing: isDownloading
                  ? const SizedBox.shrink()
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isDownloaded)
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _deleteTranslation(
                                edition.id.toString(), edition.name),
                          )
                        else
                          IconButton(
                            icon: const Icon(Icons.download),
                            onPressed: () => _downloadTranslation(edition),
                          ),
                      ],
                    ),
            );
          }).toList(),
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
            const Text('Unable to load tafsirs'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAvailableTafsirs,
              child: const Text('Retry'),
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

        return ExpansionTile(
          leading: Text(
            displayFlag,
            style: const TextStyle(fontSize: 24),
          ),
          title: Text(
            displayName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle:
              Text('${tafsirs.length} tafsir${tafsirs.length > 1 ? 's' : ''}'),
          children: tafsirs.map((edition) {
            final isDownloaded =
                _downloadedTafsirs.contains(edition.id.toString());
            final isDownloading = _isDownloading[edition.id.toString()] == true;
            final progress = _downloadProgress[edition.id.toString()];
            const isSelected = false; // selection managed in TafsirScreen only
            final percent =
                ((_downloadProgress[edition.id.toString()] ?? 0) * 100)
                    .clamp(0, 100)
                    .toStringAsFixed(0);

            return ListTile(
              title: Text(edition.name),
              subtitle: isDownloading
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LinearProgressIndicator(value: progress),
                        const SizedBox(height: 4),
                        Text('$percent%'),
                      ],
                    )
                  : Text(isDownloaded ? 'Downloaded' : 'Not downloaded'),
              onTap: null,
              trailing: isDownloading
                  ? const SizedBox.shrink()
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isDownloaded)
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _deleteTafsir(
                                edition.id.toString(), edition.name),
                          )
                        else
                          IconButton(
                            icon: const Icon(Icons.download),
                            onPressed: () => _downloadTafsir(edition),
                          ),
                      ],
                    ),
            );
          }).toList(),
        );
      },
    );
  }
}
