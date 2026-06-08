// lib/features/downloads/downloads_tafsir_screen.dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quran_app/app/app.dart';
import '../../core/i18n/app_localizations.dart';
import 'package:quran_app/features/settings/widgets/settings_app_bar.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/tafsir_service.dart';
import '../../data/models/tafsir_model.dart';
import '../../core/utils/language_utils.dart';
import '../../data/sources/remote/translation_api.dart';
import '../../core/ui/snackbar_utils.dart';

class DownloadsTafsirScreen extends StatefulWidget {
  const DownloadsTafsirScreen({super.key});

  @override
  State<DownloadsTafsirScreen> createState() => _DownloadsTafsirScreenState();
}

class _DownloadsTafsirScreenState extends State<DownloadsTafsirScreen> {
  final TafsirService _tafsirService = TafsirService.instance;
  final Map<String, bool> _tafsirExpanded = {};
  final Map<String, double> _downloadProgress = {};
  final Map<String, bool> _isDownloading = {};
  bool _downloadedSectionExpanded = true;

  List<TafsirEdition> _availableTafsirs = [];
  List<String> _downloadedTafsirs = [];
  bool _isLoadingTafsirs = true;

  @override
  void initState() {
    super.initState();
    _loadAvailableTafsirs();
    _loadDownloadedEditions();
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
        showAppSnack(
          context,
          (AppLocalizations.of(context)?.translate('error_loading_tafsirs') ??
                  'Error loading tafsirs: {error}')
              .replaceAll('{error}', '$e'),
          type: AppSnackType.error,
        );
      }
    }
  }

  Future<void> _loadDownloadedEditions() async {
    try {
      final tafsirs = await _tafsirService.getDownloadedTafsirs();
      setState(() {
        _downloadedTafsirs = tafsirs;
      });
    } catch (_) {
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
      await _showNoInternetDialog();
      return false;
    }

    final onWifi = connectivity.contains(ConnectivityResult.wifi);
    final onMobile = connectivity.contains(ConnectivityResult.mobile);

    if (wifiOnly && !onWifi && onMobile) {
      _showSnack(
        AppLocalizations.of(context)?.translate('wifi_only_warning') ??
            'WiFi-only enabled. Connect to WiFi to download.',
        type: AppSnackType.info,
      );
      return false;
    }

    return true;
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

  void _showSnack(String message, {AppSnackType type = AppSnackType.info}) {
    if (!mounted) return;
    showAppSnack(context, message, type: type);
  }

  Future<void> _downloadTafsir(TafsirEdition edition) async {
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
        },
      );

      if (success) {
        await _loadDownloadedEditions();
        if (mounted) {
          showAppSnack(
            context,
            (AppLocalizations.of(context)?.translate('download_success') ??
                    '{name} downloaded successfully')
                .replaceAll('{name}', edition.name),
            type: AppSnackType.success,
          );
        }
        await AppNotificationService.instance.complete(
          notifId,
          (AppLocalizations.of(context)?.translate('downloading_item') ??
                  'Downloading {name}')
              .replaceAll('{name}', edition.name),
          success: true,
        );
      } else {
        if (mounted) {
          showAppSnack(
            context,
            AppLocalizations.of(context)
                    ?.translate('download_failed_try_again') ??
                'Download failed. Please try again.',
            type: AppSnackType.error,
          );
        }
        await AppNotificationService.instance.complete(
          notifId,
          (AppLocalizations.of(context)?.translate('downloading_item') ??
                  'Downloading {name}')
              .replaceAll('{name}', edition.name),
          success: false,
        );
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
          showAppSnack(
            context,
            (AppLocalizations.of(context)?.translate('delete_success') ??
                    '{name} deleted')
                .replaceAll('{name}', name),
            type: AppSnackType.success,
          );
        }
      }
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
        title: AppLocalizations.of(context)?.translate('tab_tafsir') ??
            'Tafsir',
        leadingLabel: AppLocalizations.of(context)?.translate('storage_title') ??
            'Storage',
      ),
      body: _isLoadingTafsirs
          ? const Center(child: CircularProgressIndicator())
          : _availableTafsirs.isEmpty
              ? Center(
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
                            AppLocalizations.of(context)?.translate('retry') ??
                                'Retry'),
                      ),
                    ],
                  ),
                )
              : _buildTafsirsList(cardBackground),
    );
  }

  Widget _buildTafsirsList(Color cardBackground) {
    final theme = Theme.of(context);
    final dividerColor = theme.dividerColor.withOpacity(0.15);

    final downloadedEditions = _availableTafsirs
        .where((e) => _downloadedTafsirs.contains(e.id.toString()))
        .toList();
    final availableEditions = _availableTafsirs
        .where((e) => !_downloadedTafsirs.contains(e.id.toString()))
        .toList();

    Map<String, List<TafsirEdition>> groupByLanguage(
        List<TafsirEdition> items) {
      final grouped = <String, List<TafsirEdition>>{};
      for (final t in items) {
        grouped.putIfAbsent(t.languageName, () => []);
        grouped[t.languageName]!.add(t);
      }
      return grouped;
    }

    Widget buildLanguageGroup(String langName, List<TafsirEdition> editions) {
      final langCode = LanguageUtils.getCodeForName(langName) ??
          TranslationApi.getLanguageCode(langName);
      final hasCode = langCode != null && langCode.isNotEmpty;
      final displayName =
          hasCode ? LanguageUtils.getLanguageName(langCode) : langName;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            displayName,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          _buildTafsirGroupCard(
            cardBackground: cardBackground,
            dividerColor: dividerColor,
            children: editions
                .map((edition) => _buildTafsirRow(edition: edition))
                .toList(),
          ),
        ],
      );
    }

    final downloadedByLang = groupByLanguage(downloadedEditions);
    final availableByLang = groupByLanguage(availableEditions);
    final downloadedLangs = downloadedByLang.keys.toList()..sort();
    final availableLangs = availableByLang.keys.toList()..sort();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (downloadedEditions.isNotEmpty) ...[
          _buildSectionHeader(
            title: AppLocalizations.of(context)?.translate('downloaded') ??
                'Downloaded',
            expanded: _downloadedSectionExpanded,
            onTap: () {
              setState(() {
                _downloadedSectionExpanded = !_downloadedSectionExpanded;
              });
            },
          ),
          AnimatedCrossFade(
            firstChild: Column(
              children: [
                for (final lang in downloadedLangs) ...[
                  buildLanguageGroup(lang, downloadedByLang[lang]!),
                  const SizedBox(height: 16),
                ],
              ],
            ),
            secondChild: const SizedBox.shrink(),
            crossFadeState: _downloadedSectionExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 200),
          ),
          const SizedBox(height: 8),
        ],
        Text(
          AppLocalizations.of(context)?.translate('available') ?? 'Available',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 8),
        for (final lang in availableLangs) ...[
          buildLanguageGroup(lang, availableByLang[lang]!),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required bool expanded,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const Spacer(),
            AnimatedRotation(
              turns: expanded ? 0.0 : 0.5,
              duration: const Duration(milliseconds: 200),
              child: const Icon(Icons.expand_more),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTafsirGroupCard({
    required Color cardBackground,
    required Color dividerColor,
    required List<Widget> children,
  }) {
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
            for (var i = 0; i < children.length; i++) ...[
              children[i],
              if (i != children.length - 1)
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

  Widget _buildTafsirRow({required TafsirEdition edition}) {
    final theme = Theme.of(context);
    final id = edition.id.toString();
    final isDownloaded = _downloadedTafsirs.contains(id);
    final isDownloading = _isDownloading[id] == true;
    final progress = _downloadProgress[id] ?? 0.0;
    final percent = (progress * 100).round();

    return InkWell(
      onTap: isDownloaded ? null : () => _downloadTafsir(edition),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    edition.name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    edition.authorName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            if (isDownloading)
              SizedBox(
                width: 60,
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 2.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('$percent%', style: theme.textTheme.bodySmall),
                  ],
                ),
              )
            else if (isDownloaded)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                tooltip: AppLocalizations.of(context)?.translate('delete_action') ??
                    'Delete',
                onPressed: () => _deleteTafsir(edition.id.toString(), edition.name),
              )
            else
              IconButton(
                icon: Icon(Icons.download_for_offline,
                    color: BrandColors.accent),
                tooltip: AppLocalizations.of(context)?.translate('download') ??
                    'Download',
                onPressed: () => _downloadTafsir(edition),
              ),
          ],
        ),
      ),
    );
  }
}
