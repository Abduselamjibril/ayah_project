// lib/features/downloads/downloads_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/translation_service.dart';
import '../../core/services/tafsir_service.dart';
import '../../core/utils/language_utils.dart';
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

  List<Map<String, dynamic>> _availableTranslations = [];
  List<Map<String, dynamic>> _availableTafsirs = [];
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
      final translations = await _translationService.getAvailableTranslations();
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
    final wifiOnly = prefs.getBool('download_wifi_only') ?? true;

    if (wifiOnly && mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('WiFi Only Mode'),
          content: const Text(
            'Your settings require WiFi for downloads. '
            'Make sure you are connected to WiFi before proceeding.\n\n'
            'Continue anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      return proceed ?? false;
    }
    return true;
  }

  Future<void> _downloadTranslation(String identifier, String name) async {
    // Check WiFi preference first
    final canProceed = await _checkWifiPreference();
    if (!canProceed) return;

    setState(() {
      _isDownloading[identifier] = true;
      _downloadProgress[identifier] = 0.0;
    });

    try {
      final success = await _translationService.downloadTranslation(
        identifier,
        onProgress: (current, total) {
          setState(() {
            _downloadProgress[identifier] = current / total;
          });
        },
      );

      if (success) {
        await _loadDownloadedEditions();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$name downloaded successfully')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Download failed. Please try again.')),
          );
        }
      }
    } finally {
      setState(() {
        _isDownloading[identifier] = false;
        _downloadProgress.remove(identifier);
      });
    }
  }

  Future<void> _downloadTafsir(String identifier, String name) async {
    // Check WiFi preference first
    final canProceed = await _checkWifiPreference();
    if (!canProceed) return;

    setState(() {
      _isDownloading[identifier] = true;
      _downloadProgress[identifier] = 0.0;
    });

    try {
      final success = await _tafsirService.downloadTafsir(
        identifier,
        onProgress: (current, total) {
          setState(() {
            _downloadProgress[identifier] = current / total;
          });
        },
      );

      if (success) {
        await _loadDownloadedEditions();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$name downloaded successfully')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Download failed. Please try again.')),
          );
        }
      }
    } finally {
      setState(() {
        _isDownloading[identifier] = false;
        _downloadProgress.remove(identifier);
      });
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
    final groupedByLanguage = <String, List<Map<String, dynamic>>>{};
    for (final translation in _availableTranslations) {
      final langCode = translation['language'] as String? ?? 'unknown';
      groupedByLanguage.putIfAbsent(langCode, () => []);
      groupedByLanguage[langCode]!.add(translation);
    }

    return ListView.builder(
      itemCount: groupedByLanguage.length,
      itemBuilder: (context, index) {
        final langCode = groupedByLanguage.keys.elementAt(index);
        final translations = groupedByLanguage[langCode]!;

        // Use language utils to get display name with flag
        final displayName = LanguageUtils.getDisplayName(langCode);

        return ExpansionTile(
          leading: Text(
            LanguageUtils.getLanguageFlag(langCode),
            style: const TextStyle(fontSize: 24),
          ),
          title: Text(
            LanguageUtils.getLanguageName(langCode),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
              '${translations.length} translation${translations.length > 1 ? 's' : ''}'),
          children: translations.map((translation) {
            final identifier = translation['identifier'] as String;
            final name = translation['englishName'] as String? ??
                translation['name'] as String;
            final isDownloaded = _downloadedTranslations.contains(identifier);
            final isDownloading = _isDownloading[identifier] == true;
            final progress = _downloadProgress[identifier];

            return ListTile(
              title: Text(name),
              subtitle: isDownloading
                  ? LinearProgressIndicator(value: progress)
                  : Text(isDownloaded ? '✓ Downloaded' : 'Tap to download'),
              trailing: isDownloading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : isDownloaded
                      ? IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deleteTranslation(identifier, name),
                        )
                      : IconButton(
                          icon: const Icon(Icons.download),
                          onPressed: () =>
                              _downloadTranslation(identifier, name),
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
    final groupedByLanguage = <String, List<Map<String, dynamic>>>{};
    for (final tafsir in _availableTafsirs) {
      final langCode = tafsir['language'] as String? ?? 'unknown';
      groupedByLanguage.putIfAbsent(langCode, () => []);
      groupedByLanguage[langCode]!.add(tafsir);
    }

    return ListView.builder(
      itemCount: groupedByLanguage.length,
      itemBuilder: (context, index) {
        final langCode = groupedByLanguage.keys.elementAt(index);
        final tafsirs = groupedByLanguage[langCode]!;

        return ExpansionTile(
          leading: Text(
            LanguageUtils.getLanguageFlag(langCode),
            style: const TextStyle(fontSize: 24),
          ),
          title: Text(
            LanguageUtils.getLanguageName(langCode),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle:
              Text('${tafsirs.length} tafsir${tafsirs.length > 1 ? 's' : ''}'),
          children: tafsirs.map((tafsir) {
            final identifier = tafsir['identifier'] as String;
            final name =
                tafsir['englishName'] as String? ?? tafsir['name'] as String;
            final isDownloaded = _downloadedTafsirs.contains(identifier);
            final isDownloading = _isDownloading[identifier] == true;
            final progress = _downloadProgress[identifier];

            return ListTile(
              title: Text(name),
              subtitle: isDownloading
                  ? LinearProgressIndicator(value: progress)
                  : Text(isDownloaded ? '✓ Downloaded' : 'Tap to download'),
              trailing: isDownloading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : isDownloaded
                      ? IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deleteTafsir(identifier, name),
                        )
                      : IconButton(
                          icon: const Icon(Icons.download),
                          onPressed: () => _downloadTafsir(identifier, name),
                        ),
            );
          }).toList(),
        );
      },
    );
  }
}
