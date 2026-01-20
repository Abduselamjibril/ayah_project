// lib/features/downloads/storage_management_page.dart
import 'package:flutter/material.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/services/translation_service.dart';

import '../../core/services/tafsir_service.dart';
import '../../core/services/audio_service.dart';

class StorageManagementPage extends StatefulWidget {
  const StorageManagementPage({super.key});

  @override
  State<StorageManagementPage> createState() => _StorageManagementPageState();
}

class _StorageManagementPageState extends State<StorageManagementPage> {
  final TranslationService _translationService = TranslationService.instance;
  final TafsirService _tafsirService = TafsirService.instance;
  final AudioService _audioService = AudioService.instance;

  List<String> _downloadedTranslations = [];
  List<String> _downloadedTafsirs = [];
  List<String> _downloadedRecitations = [];
  Map<String, String> _translationNames = {};
  Map<String, String> _tafsirNames = {};
  Map<String, String> _recitationNames = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final translations = await _translationService.getDownloadedTranslations();
    final tafsirs = await _tafsirService.getDownloadedTafsirs();
    await _audioService.initialize();
    final recitationIds = await _audioService.getDownloadedRecitationIds();
    final recitations = await _audioService.getAvailableRecitations();

    // Fetch metadata to map ids to names
    final allTranslationEditions =
        await _translationService.getAllTranslationEditions();
    final allTafsirEditions = await _tafsirService.getAvailableTafsirs();

    final translationNames = <String, String>{
      for (final e in allTranslationEditions) e.id.toString(): e.name
    };
    final tafsirNames = <String, String>{
      for (final e in allTafsirEditions) e.id.toString(): e.name
    };
    final recitationNames = <String, String>{
      for (final r in recitations) r.id.toString(): r.reciterName
    };

    setState(() {
      _downloadedTranslations = translations;
      _downloadedTafsirs = tafsirs;
      _downloadedRecitations = recitationIds.map((e) => e.toString()).toList();
      _translationNames = translationNames;
      _tafsirNames = tafsirNames;
      _recitationNames = recitationNames;
      _loading = false;
    });
  }

  Future<void> _bulkDeleteTranslations() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)
                ?.translate('delete_all_translations_title') ??
            'Delete All Translations'),
        content: Text(AppLocalizations.of(context)
                ?.translate('delete_all_translations_confirm') ??
            'Are you sure you want to delete all downloaded translations?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppLocalizations.of(context)?.translate('cancel') ??
                  'Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                  AppLocalizations.of(context)?.translate('delete_action') ??
                      'Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    for (final id in List.of(_downloadedTranslations)) {
      await _translationService.deleteTranslation(id);
    }
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(AppLocalizations.of(context)
                  ?.translate('all_translations_deleted') ??
              'All translations deleted')),
    );
  }

  Future<void> _bulkDeleteTafsirs() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)
                ?.translate('delete_all_tafsir_title') ??
            'Delete All Tafsir'),
        content: Text(AppLocalizations.of(context)
                ?.translate('delete_all_tafsir_confirm') ??
            'Are you sure you want to delete all downloaded tafsir?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppLocalizations.of(context)?.translate('cancel') ??
                  'Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                  AppLocalizations.of(context)?.translate('delete_action') ??
                      'Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    for (final id in List.of(_downloadedTafsirs)) {
      await _tafsirService.deleteTafsir(id);
    }
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              AppLocalizations.of(context)?.translate('all_tafsir_deleted') ??
                  'All tafsir deleted')),
    );
  }

  Future<void> _bulkDeleteAudios() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            AppLocalizations.of(context)?.translate('delete_all_audio_title') ??
                'Delete All Audio'),
        content: Text(AppLocalizations.of(context)
                ?.translate('delete_all_audio_confirm') ??
            'Are you sure you want to delete all downloaded audio recitations?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppLocalizations.of(context)?.translate('cancel') ??
                  'Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                  AppLocalizations.of(context)?.translate('delete_action') ??
                      'Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    for (final id in List.of(_downloadedRecitations)) {
      await _audioService.deleteRecitation(int.parse(id));
    }
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              AppLocalizations.of(context)?.translate('all_audio_deleted') ??
                  'All audio deleted')),
    );
  }

  // Placeholder size getters. Implement real size calculation in services if available.
  Future<String> _getTranslationSize(String id) async {
    // TODO: Return actual size on disk per translation id
    return '—';
  }

  Future<String> _getTafsirSize(String id) async {
    // TODO: Return actual size on disk per tafsir id
    return '—';
  }

  Future<String> _getAudioSize(String id) async {
    final bytes = await _audioService.getRecitationSizeBytes(int.parse(id));
    return _formatBytes(bytes);
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    double value = bytes.toDouble();
    int unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    return '${value.toStringAsFixed(value >= 10 || value == value.floorToDouble() ? 0 : 1)} ${units[unitIndex]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.translate('storage_title') ??
            'Storage'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _buildCategory(
                  title: AppLocalizations.of(context)
                          ?.translate('tab_translations') ??
                      'Translations',
                  items: _downloadedTranslations,
                  nameForId: (id) => _translationNames[id] ?? 'ID: $id',
                  onBulkDelete: _bulkDeleteTranslations,
                  itemSizeGetter: _getTranslationSize,
                  onDeleteItem: (id) async {
                    await _translationService.deleteTranslation(id);
                    await _load();
                  },
                ),
                _buildCategory(
                  title:
                      AppLocalizations.of(context)?.translate('tab_tafsir') ??
                          'Tafsir',
                  items: _downloadedTafsirs,
                  nameForId: (id) => _tafsirNames[id] ?? 'ID: $id',
                  onBulkDelete: _bulkDeleteTafsirs,
                  itemSizeGetter: _getTafsirSize,
                  onDeleteItem: (id) async {
                    await _tafsirService.deleteTafsir(id);
                    await _load();
                  },
                ),
                _buildCategory(
                  title: AppLocalizations.of(context)?.translate('tab_audio') ??
                      'Audio',
                  items: _downloadedRecitations,
                  nameForId: (id) => _recitationNames[id] ?? 'Recitation $id',
                  onBulkDelete: _bulkDeleteAudios,
                  itemSizeGetter: _getAudioSize,
                  onDeleteItem: (id) async {
                    await _audioService.deleteRecitation(int.parse(id));
                    await _load();
                  },
                ),
              ],
            ),
    );
  }

  Widget _buildCategory({
    required String title,
    required List<String> items,
    required String Function(String id) nameForId,
    required VoidCallback onBulkDelete,
    required Future<String> Function(String id) itemSizeGetter,
    required Future<void> Function(String id) onDeleteItem,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (items.isNotEmpty)
                TextButton.icon(
                  onPressed: onBulkDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: Text(
                      AppLocalizations.of(context)?.translate('delete_all') ??
                          'Delete All'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Text(
                AppLocalizations.of(context)
                        ?.translate('no_downloads_category') ??
                    'No downloads in this category',
                style: const TextStyle(color: Colors.grey))
          else
            Card(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final id = items[index];
                  final displayName = nameForId(id);
                  return FutureBuilder<String>(
                    future: itemSizeGetter(id),
                    builder: (context, snapshot) {
                      final size = snapshot.data ?? '…';
                      return ListTile(
                        title: Text(displayName),
                        subtitle: Text((AppLocalizations.of(context)
                                    ?.translate('size_label') ??
                                'Size: {size}')
                            .replaceAll('{size}', size)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => onDeleteItem(id),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
