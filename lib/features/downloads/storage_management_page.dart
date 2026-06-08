// lib/features/downloads/storage_management_page.dart
import 'package:flutter/material.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/services/translation_service.dart';
import '../../core/services/tafsir_service.dart';
import '../../core/services/audio_service.dart';
import '../../core/ui/snackbar_utils.dart';
import '../../core/ui/responsive.dart';
import '../settings/widgets/settings_app_bar.dart';

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

    if (mounted) {
      setState(() {
        _downloadedTranslations = translations;
        _downloadedTafsirs = tafsirs;
        _downloadedRecitations =
            recitationIds.map((e) => e.toString()).toList();
        _translationNames = translationNames;
        _tafsirNames = tafsirNames;
        _recitationNames = recitationNames;
        _loading = false;
      });
    }
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
    showAppSnack(
      context,
      AppLocalizations.of(context)?.translate('all_translations_deleted') ??
          'All translations deleted',
      type: AppSnackType.success,
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
    showAppSnack(
      context,
      AppLocalizations.of(context)?.translate('all_tafsir_deleted') ??
          'All tafsir deleted',
      type: AppSnackType.success,
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
    showAppSnack(
      context,
      AppLocalizations.of(context)?.translate('all_audio_deleted') ??
          'All audio deleted',
      type: AppSnackType.success,
    );
  }

  Future<String> _getTranslationSize(String id) async {
    final bytes = await _translationService.getTranslationSizeBytes(id);
    return _formatBytes(bytes);
  }

  Future<String> _getTafsirSize(String id) async {
    final bytes = await _tafsirService.getTafsirSizeBytes(id);
    return _formatBytes(bytes);
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
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    // Use matching colors to DownloadSettingsPage
    final cardBg = isLight
        ? theme.scaffoldBackgroundColor
        : theme.cardColor.withOpacity(0.5);

    return Scaffold(
      backgroundColor:
          isLight ? theme.colorScheme.surface : theme.scaffoldBackgroundColor,
      appBar: SettingsAppBar(
        title: AppLocalizations.of(context)?.translate('storage_title') ??
            'Storage',
        leadingLabel:
            AppLocalizations.of(context)?.translate('storage_title') ??
                'Storage', // Back button says "Storage"
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_downloadedTranslations.isEmpty &&
                  _downloadedTafsirs.isEmpty &&
                  _downloadedRecitations.isEmpty)
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.folder_open_rounded,
                        size: 80,
                        color: theme.colorScheme.onSurface.withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context)
                                ?.translate('no_downloads_yet') ??
                            'Nothing downloaded yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: EdgeInsets.all(
                      ResponsiveLayout.scaled(context, 16, min: 12, max: 20)),
                  children: [
                    _buildCategorySection(
                      context: context,
                      theme: theme,
                      cardBg: cardBg,
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
                    _buildCategorySection(
                      context: context,
                      theme: theme,
                      cardBg: cardBg,
                      title: AppLocalizations.of(context)
                              ?.translate('tab_tafsir') ??
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
                    _buildCategorySection(
                      context: context,
                      theme: theme,
                      cardBg: cardBg,
                      title: AppLocalizations.of(context)
                              ?.translate('tab_audio') ??
                          'Audio',
                      items: _downloadedRecitations,
                      nameForId: (id) =>
                          _recitationNames[id] ?? 'Recitation $id',
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

  Widget _buildCategorySection({
    required BuildContext context,
    required ThemeData theme,
    required Color cardBg,
    required String title,
    required List<String> items,
    required String Function(String id) nameForId,
    required VoidCallback onBulkDelete,
    required Future<String> Function(String id) itemSizeGetter,
    required Future<void> Function(String id) onDeleteItem,
  }) {
    final isLight = theme.brightness == Brightness.light;

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: isLight ? Colors.black : theme.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (items.isNotEmpty)
                GestureDetector(
                  onTap: onBulkDelete,
                  child: Text(
                    AppLocalizations.of(context)?.translate('delete_all') ??
                        'Delete All',
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Rounded Card for List
        Card(
          color: cardBg,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              thickness: 0.5,
              indent: 16,
              endIndent: 16,
              color: theme.dividerColor.withOpacity(0.3),
            ),
            itemBuilder: (context, index) {
              final id = items[index];
              final displayName = nameForId(id);
              final isLast = index == items.length - 1;

              return FutureBuilder<String>(
                future: itemSizeGetter(id),
                builder: (context, snapshot) {
                  final size = snapshot.data ?? '…';
                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    dense: true,
                    title: Text(
                      displayName,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      (AppLocalizations.of(context)?.translate('size_label') ??
                              'Size: {size}')
                          .replaceAll('{size}', size),
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.delete_outline,
                          size: 20,
                          color: theme.colorScheme.onSurface.withOpacity(0.5)),
                      onPressed: () => onDeleteItem(id),
                    ),
                    shape: isLast
                        ? const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                                bottom: Radius.circular(16)))
                        : null,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
