// lib/features/downloads/storage_management_page.dart
import 'package:flutter/material.dart';
import '../../core/services/translation_service.dart';
import '../../core/services/tafsir_service.dart';

class StorageManagementPage extends StatefulWidget {
  const StorageManagementPage({super.key});

  @override
  State<StorageManagementPage> createState() => _StorageManagementPageState();
}

class _StorageManagementPageState extends State<StorageManagementPage> {
  final TranslationService _translationService = TranslationService.instance;
  final TafsirService _tafsirService = TafsirService.instance;

  List<String> _downloadedTranslations = [];
  List<String> _downloadedTafsirs = [];
  Map<String, String> _translationNames = {};
  Map<String, String> _tafsirNames = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final translations = await _translationService.getDownloadedTranslations();
    final tafsirs = await _tafsirService.getDownloadedTafsirs();

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

    setState(() {
      _downloadedTranslations = translations;
      _downloadedTafsirs = tafsirs;
      _translationNames = translationNames;
      _tafsirNames = tafsirNames;
      _loading = false;
    });
  }

  Future<void> _bulkDeleteTranslations() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Translations'),
        content: const Text(
            'Are you sure you want to delete all downloaded translations?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
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
      const SnackBar(content: Text('All translations deleted')),
    );
  }

  Future<void> _bulkDeleteTafsirs() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Tafsir'),
        content: const Text(
            'Are you sure you want to delete all downloaded tafsir?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
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
      const SnackBar(content: Text('All tafsir deleted')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Storage'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _buildCategory(
                  title: 'Translations',
                  items: _downloadedTranslations,
                  onBulkDelete: _bulkDeleteTranslations,
                  itemSizeGetter: _getTranslationSize,
                  onDeleteItem: (id) async {
                    await _translationService.deleteTranslation(id);
                    await _load();
                  },
                ),
                _buildCategory(
                  title: 'Tafsir',
                  items: _downloadedTafsirs,
                  onBulkDelete: _bulkDeleteTafsirs,
                  itemSizeGetter: _getTafsirSize,
                  onDeleteItem: (id) async {
                    await _tafsirService.deleteTafsir(id);
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
                  label: const Text('Delete All'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const Text('No downloads in this category',
                style: TextStyle(color: Colors.grey))
          else
            Card(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final id = items[index];
                  final displayName = title == 'Translations'
                      ? (_translationNames[id] ?? 'ID: $id')
                      : (_tafsirNames[id] ?? 'ID: $id');
                  return FutureBuilder<String>(
                    future: itemSizeGetter(id),
                    builder: (context, snapshot) {
                      final size = snapshot.data ?? '…';
                      return ListTile(
                        title: Text(displayName),
                        subtitle: Text('Size: $size'),
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
