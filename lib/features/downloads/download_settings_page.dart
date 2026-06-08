// lib/features/downloads/download_settings_page.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/services/storage_service.dart';
import '../../core/ui/responsive.dart';
import '../../core/ui/snackbar_utils.dart';
import 'package:quran_app/features/settings/widgets/settings_app_bar.dart';
import 'storage_management_page.dart';

class DownloadSettingsPage extends StatefulWidget {
  const DownloadSettingsPage({super.key});

  @override
  State<DownloadSettingsPage> createState() => _DownloadSettingsPageState();
}

class _DownloadSettingsPageState extends State<DownloadSettingsPage> {
  bool _wifiOnly = true;
  bool _backgroundDownload = false;
  bool _isLoading = true;
  bool _usageLoading = true;
  bool _clearingCache = false;
  bool _clearingData = false;
  StorageUsage? _usage;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadUsage();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _wifiOnly = prefs.getBool('download_wifi_only') ?? false;
      _backgroundDownload = prefs.getBool('download_background') ?? true;
      _isLoading = false;
    });
  }

  Future<void> _saveWifiOnly(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('download_wifi_only', value);
    setState(() => _wifiOnly = value);
  }

  Future<void> _saveBackgroundDownload(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('download_background', value);
    setState(() => _backgroundDownload = value);
  }

  Future<void> _loadUsage() async {
    setState(() => _usageLoading = true);
    final usage = await StorageService.instance.getUsage();
    if (!mounted) return;
    setState(() {
      _usage = usage;
      _usageLoading = false;
    });
  }

  Future<void> _confirmClearCache() async {
    if (_clearingCache) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            AppLocalizations.of(context)?.translate('clear_cache_title') ??
                'Clear Cache?'),
        content: Text(AppLocalizations.of(context)
                ?.translate('clear_cache_confirm') ??
            'This will remove temporary files. Downloaded content will stay.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
                AppLocalizations.of(context)?.translate('cancel') ?? 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
                AppLocalizations.of(context)?.translate('clear_cache') ??
                    'Clear Cache'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    setState(() => _clearingCache = true);
    try {
      await StorageService.instance.clearCache();
      await _loadUsage();
      if (!mounted) return;
      showAppSnack(
        context,
        AppLocalizations.of(context)?.translate('cache_cleared') ??
            'Cache cleared',
        type: AppSnackType.success,
      );
    } catch (_) {
      if (!mounted) return;
      showAppSnack(
        context,
        AppLocalizations.of(context)?.translate('cache_clear_failed') ??
            'Unable to clear cache',
        type: AppSnackType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _clearingCache = false);
      }
    }
  }

  Future<void> _confirmClearData() async {
    if (_clearingData) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            AppLocalizations.of(context)?.translate('clear_data_title') ??
                'Clear Data?'),
        content: Text(
            AppLocalizations.of(context)?.translate('clear_data_confirm') ??
                'This will remove downloaded translations, tafsir, and audio.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
                AppLocalizations.of(context)?.translate('cancel') ?? 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context)?.translate('clear_data') ??
                'Clear Data'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    setState(() => _clearingData = true);
    try {
      await StorageService.instance.clearDownloadedData();
      await _loadUsage();
      if (!mounted) return;
      showAppSnack(
        context,
        AppLocalizations.of(context)?.translate('data_cleared') ??
            'Downloaded data cleared',
        type: AppSnackType.success,
      );
    } catch (_) {
      if (!mounted) return;
      showAppSnack(
        context,
        AppLocalizations.of(context)?.translate('data_clear_failed') ??
            'Unable to clear data',
        type: AppSnackType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _clearingData = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final cardBg = isLight
        ? theme.scaffoldBackgroundColor
        : theme.cardColor.withOpacity(0.5);
    final listPadding = ResponsiveLayout.scaled(context, 16, min: 12, max: 20);

    return Scaffold(
      backgroundColor:
          isLight ? theme.colorScheme.surface : theme.scaffoldBackgroundColor,
      appBar: SettingsAppBar(
        title: AppLocalizations.of(context)?.translate('storage_title') ??
            'Storage',
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.all(listPadding),
              children: [
                // --- Network Preferences ---
                _buildSectionHeader(
                  theme,
                  AppLocalizations.of(context)
                          ?.translate('network_preferences') ??
                      'Network Preferences',
                ),
                Card(
                  color: cardBg,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SwitchListTile(
                    title: Text(
                      AppLocalizations.of(context)?.translate('wifi_only') ??
                          'WiFi Only',
                    ),
                    subtitle: Text(
                      AppLocalizations.of(context)
                              ?.translate('wifi_only_subtitle') ??
                          'Download translations and tafsir only when connected to WiFi',
                    ),
                    value: _wifiOnly,
                    onChanged: _saveWifiOnly,
                    activeColor: theme.primaryColor,
                    secondary: const Icon(Icons.wifi),
                  ),
                ),

                // --- Background Downloads ---
                _buildSectionHeader(
                  theme,
                  AppLocalizations.of(context)
                          ?.translate('background_downloads_header') ??
                      'Background Downloads',
                ),
                Card(
                  color: cardBg,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SwitchListTile(
                    title: Text(
                      AppLocalizations.of(context)
                              ?.translate('allow_background_downloads') ??
                          'Allow Background Downloads',
                    ),
                    subtitle: Text(
                      AppLocalizations.of(context)
                              ?.translate('background_downloads_subtitle') ??
                          'Keep downloads running when you switch apps. On iOS the app must stay in foreground for reliability.',
                    ),
                    value: _backgroundDownload,
                    onChanged: _saveBackgroundDownload,
                    activeColor: theme.primaryColor,
                    secondary: const Icon(Icons.cloud_download),
                  ),
                ),

                // --- Storage Info ---
                _buildSectionHeader(
                  theme,
                  AppLocalizations.of(context)
                          ?.translate('storage_usage_title') ??
                      'Storage Usage',
                ),
                Card(
                  color: cardBg,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _usageLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _buildStorageUsage(theme),
                  ),
                ),

                // --- Manage Downloads ---
                _buildSectionHeader(
                  theme,
                  AppLocalizations.of(context)?.translate('about_downloads') ??
                      'About Downloads',
                ),
                Card(
                  color: cardBg,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    onTap: () {
                      if (!mounted) return;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const StorageManagementPage(),
                        ),
                      );
                    },
                    leading: Icon(
                      Icons.storage,
                      color: theme.colorScheme.primary,
                      size: ResponsiveLayout.scaled(context, 24,
                          min: 20, max: 28),
                    ),
                    title: Text(
                      AppLocalizations.of(context)
                              ?.translate('manage_storage_title') ??
                          'Manage Storage',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      AppLocalizations.of(context)
                              ?.translate('storage_subtitle') ??
                          'View downloaded items by category, sizes, and bulk delete.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                      size: ResponsiveLayout.scaled(context, 18,
                          min: 16, max: 22),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildSectionHeader(ThemeData theme, String title) {
    final isLight = theme.brightness == Brightness.light;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          color: isLight ? Colors.black : theme.primaryColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStorageUsage(ThemeData theme) {
    final usage = _usage ?? const StorageUsage(cacheBytes: 0, dataBytes: 0);
    final totalBytes = usage.totalBytes;
    final cacheColor = theme.colorScheme.primary;
    final dataColor = theme.colorScheme.secondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              AppLocalizations.of(context)?.translate('total_label') ?? 'Total',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              StorageService.formatBytes(totalBytes),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildUsagePie(theme, usage, cacheColor, dataColor),
        const SizedBox(height: 12),
        _buildUsageLegendItem(
          theme,
          color: cacheColor,
          label:
              AppLocalizations.of(context)?.translate('cache_label') ?? 'Cache',
          value: StorageService.formatBytes(usage.cacheBytes),
        ),
        const SizedBox(height: 6),
        _buildUsageLegendItem(
          theme,
          color: dataColor,
          label:
              AppLocalizations.of(context)?.translate('data_label') ?? 'Data',
          value: StorageService.formatBytes(usage.dataBytes),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _clearingCache ? null : _confirmClearCache,
                icon: _clearingCache
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.primary,
                        ),
                      )
                    : const Icon(Icons.delete_sweep_outlined),
                label: Text(
                  AppLocalizations.of(context)?.translate('clear_cache') ??
                      'Clear Cache',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _clearingData ? null : _confirmClearData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                ),
                icon: _clearingData
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onError,
                        ),
                      )
                    : const Icon(Icons.delete_forever_outlined),
                label: Text(
                  AppLocalizations.of(context)?.translate('clear_data') ??
                      'Clear Data',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUsagePie(
    ThemeData theme,
    StorageUsage usage,
    Color cacheColor,
    Color dataColor,
  ) {
    final cacheMb = _bytesToMb(usage.cacheBytes);
    final dataMb = _bytesToMb(usage.dataBytes);
    final totalMb = cacheMb + dataMb;

    return Center(
      child: SizedBox(
        width: 120,
        height: 120,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size(120, 120),
              painter: _UsagePiePainter(
                cacheMb: cacheMb,
                dataMb: dataMb,
                cacheColor: cacheColor,
                dataColor: dataColor,
                baseColor: theme.dividerColor.withOpacity(0.2),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  totalMb == 0 ? '0 MB' : '${totalMb.toStringAsFixed(1)} MB',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  AppLocalizations.of(context)?.translate('total_label') ??
                      'Total',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  double _bytesToMb(int bytes) {
    if (bytes <= 0) return 0.0;
    return bytes / (1024 * 1024);
  }

  Widget _buildUsageLegendItem(
    ThemeData theme, {
    required Color color,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _UsagePiePainter extends CustomPainter {
  _UsagePiePainter({
    required this.cacheMb,
    required this.dataMb,
    required this.cacheColor,
    required this.dataColor,
    required this.baseColor,
  });

  final double cacheMb;
  final double dataMb;
  final Color cacheColor;
  final Color dataColor;
  final Color baseColor;

  @override
  void paint(Canvas canvas, Size size) {
    final total = cacheMb + dataMb;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final stroke = radius * 0.35;

    final basePaint = Paint()
      ..color = baseColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    canvas.drawCircle(center, radius - stroke / 2, basePaint);

    if (total <= 0) return;

    final cacheSweep = (cacheMb / total) * 6.283185307179586;
    final dataSweep = (dataMb / total) * 6.283185307179586;
    final startAngle = -1.5707963267948966;

    final cachePaint = Paint()
      ..color = cacheColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    final dataPaint = Paint()
      ..color = dataColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    final rect = Rect.fromCircle(center: center, radius: radius - stroke / 2);
    canvas.drawArc(rect, startAngle, cacheSweep, false, cachePaint);
    canvas.drawArc(rect, startAngle + cacheSweep, dataSweep, false, dataPaint);
  }

  @override
  bool shouldRepaint(covariant _UsagePiePainter oldDelegate) {
    return cacheMb != oldDelegate.cacheMb ||
        dataMb != oldDelegate.dataMb ||
        cacheColor != oldDelegate.cacheColor ||
        dataColor != oldDelegate.dataColor ||
        baseColor != oldDelegate.baseColor;
  }
}
