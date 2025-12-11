// lib/features/downloads/downloads_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/translation_service.dart';
import '../../core/services/tafsir_service.dart';
import '../../data/models/translation_model.dart';
import '../../data/models/tafsir_model.dart';
import '../../data/sources/remote/translation_api.dart';
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

  List<TranslationEdition> _availableTranslations = [];
  List<TafsirEdition> _availableTafsirs = [];
  List<String> _downloadedTranslations = [];
  List<String> _downloadedTafsirs = [];
  List<String> _availableLanguages = [];
  String? _selectedLanguage;

  bool _isLoadingTranslations = true;
  bool _isLoadingTafsirs = true;
  bool _isLoadingLanguages = true;

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
    await _loadAvailableLanguages();
    await Future.wait([
      _loadAvailableTafsirs(),
      _loadDownloadedEditions(),
    ]);
  }

  Future<void> _loadAvailableLanguages() async {
    setState(() => _isLoadingLanguages = true);
    try {
      final languages = await _translationService.getAvailableLanguages();
      setState(() {
        _availableLanguages = languages;
        _isLoadingLanguages = false;
        // Default to English if available
        if (languages.contains('en')) {
          _selectedLanguage = 'en';
          _loadAvailableTranslations();
        } else if (languages.isNotEmpty) {
          _selectedLanguage = languages.first;
          _loadAvailableTranslations();
        }
      });
    } catch (e) {
      setState(() => _isLoadingLanguages = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading languages: $e')),
        );
      }
    }
  }

  Future<void> _loadAvailableTranslations() async {
    if (_selectedLanguage == null) return;

    setState(() => _isLoadingTranslations = true);
    try {
      final translations =
          await _translationService.getEditionsByLanguage(_selectedLanguage!);
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
            'Make sure you are connected to WiFi before proceeding.\\n\\n'
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

  Future<void> _downloadTranslation(TranslationEdition edition) async {
    // Check WiFi preference first
    final canProceed = await _checkWifiPreference();
    if (!canProceed) return;

    setState(() {
      _isDownloading[edition.identifier] = true;
      _downloadProgress[edition.identifier] = 0.0;
    });

    try {
      final success = await _translationService.downloadTranslation(
        edition,
        onProgress: (progress) {
          setState(() {
            _downloadProgress[edition.identifier] = progress;
          });
        },
      );

      if (success) {
        await _loadDownloadedEditions();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('${edition.englishName} downloaded successfully')),
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
        _isDownloading[edition.identifier] = false;
        _downloadProgress.remove(edition.identifier);
      });
    }
  }

  Future<void> _downloadTafsir(TafsirEdition edition) async {
    // Check WiFi preference first
    final canProceed = await _checkWifiPreference();
    if (!canProceed) return;

    setState(() {
      _isDownloading[edition.identifier] = true;
      _downloadProgress[edition.identifier] = 0.0;
    });

    try {
      final success = await _tafsirService.downloadTafsir(
        edition,
        onProgress: (progress) {
          setState(() {
            _downloadProgress[edition.identifier] = progress;
          });
        },
      );

      if (success) {
        await _loadDownloadedEditions();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('${edition.englishName} downloaded successfully')),
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
        _isDownloading[edition.identifier] = false;
        _downloadProgress.remove(edition.identifier);
      });
    }
  }

  Future<void> _deleteTranslation(String identifier, String name) async {
    // Check if it's a bundled edition
    if (_translationService.isBundledEdition(identifier)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete bundled translations')),
      );
      return;
    }

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
    // Check if it's a bundled edition
    if (_tafsirService.isBundledEdition(identifier)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete bundled tafsirs')),
      );
      return;
    }

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
    return Column(
      children: [
        // Language selector
        if (_isLoadingLanguages)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: CircularProgressIndicator(),
          )
        else if (_availableLanguages.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: DropdownButtonFormField<String>(
              value: _selectedLanguage,
              decoration: const InputDecoration(
                labelText: 'Select Language',
                border: OutlineInputBorder(),
              ),
              items: _availableLanguages.map((langCode) {
                return DropdownMenuItem(
                  value: langCode,
                  child: Text(TranslationApi.getLanguageName(langCode)),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  _selectedLanguage = newValue;
                  _loadAvailableTranslations();
                });
              },
            ),
          ),

        // Translations list
        Expanded(
          child: _buildTranslationsList(),
        ),
      ],
    );
  }

  Widget _buildTranslationsList() {
    if (_isLoadingTranslations) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_availableTranslations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No translations available for this language'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAvailableTranslations,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _availableTranslations.length,
      itemBuilder: (context, index) {
        final edition = _availableTranslations[index];
        final isDownloaded =
            _downloadedTranslations.contains(edition.identifier);
        final isDownloading = _isDownloading[edition.identifier] == true;
        final progress = _downloadProgress[edition.identifier];
        final isBundled =
            _translationService.isBundledEdition(edition.identifier);

        return ListTile(
          title: Text(edition.englishName),
          subtitle: isDownloading
              ? LinearProgressIndicator(value: progress)
              : Text(
                  isDownloaded
                      ? (isBundled ? '✓ Downloaded (Built-in)' : '✓ Downloaded')
                      : 'Tap to download',
                ),
          trailing: isDownloading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : isDownloaded
                  ? (isBundled
                      ? const Icon(Icons.star, color: Colors.amber)
                      : IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deleteTranslation(
                              edition.identifier, edition.englishName),
                        ))
                  : IconButton(
                      icon: const Icon(Icons.download),
                      onPressed: () => _downloadTranslation(edition),
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
      groupedByLanguage.putIfAbsent(tafsir.language, () => []);
      groupedByLanguage[tafsir.language]!.add(tafsir);
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
          children: tafsirs.map((edition) {
            final isDownloaded =
                _downloadedTafsirs.contains(edition.identifier);
            final isDownloading = _isDownloading[edition.identifier] == true;
            final progress = _downloadProgress[edition.identifier];
            final isBundled =
                _tafsirService.isBundledEdition(edition.identifier);

            return ListTile(
              title: Text(edition.englishName),
              subtitle: isDownloading
                  ? LinearProgressIndicator(value: progress)
                  : Text(
                      isDownloaded
                          ? (isBundled
                              ? '✓ Downloaded (Built-in)'
                              : '✓ Downloaded')
                          : 'Tap to download',
                    ),
              trailing: isDownloading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : isDownloaded
                      ? (isBundled
                          ? const Icon(Icons.star, color: Colors.amber)
                          : IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _deleteTafsir(
                                  edition.identifier, edition.englishName),
                            ))
                      : IconButton(
                          icon: const Icon(Icons.download),
                          onPressed: () => _downloadTafsir(edition),
                        ),
            );
          }).toList(),
        );
      },
    );
  }
}
