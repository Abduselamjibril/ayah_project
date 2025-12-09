// lib/features/downloads/download_settings_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DownloadSettingsPage extends StatefulWidget {
  const DownloadSettingsPage({super.key});

  @override
  State<DownloadSettingsPage> createState() => _DownloadSettingsPageState();
}

class _DownloadSettingsPageState extends State<DownloadSettingsPage> {
  bool _wifiOnly = true;
  bool _backgroundDownload = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _wifiOnly = prefs.getBool('download_wifi_only') ?? true;
      _backgroundDownload = prefs.getBool('download_background') ?? false;
      _isLoading = false;
    });
  }

  Future<void> _saveWifiOnly(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('download_wifi_only', value);
    setState(() => _wifiOnly = value);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Downloads will only use WiFi'
                : 'Downloads can use mobile data',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _saveBackgroundDownload(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('download_background', value);
    setState(() => _backgroundDownload = value);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Background downloads enabled'
                : 'Background downloads disabled',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Download Settings'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Download Settings'),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Network Preferences',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('WiFi Only'),
            subtitle: const Text(
              'Download translations and tafsir only when connected to WiFi',
            ),
            value: _wifiOnly,
            onChanged: _saveWifiOnly,
            secondary: const Icon(Icons.wifi),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Background Downloads',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('Allow Background Downloads'),
            subtitle: const Text(
              'Continue downloading when app is in background',
            ),
            value: _backgroundDownload,
            onChanged: _saveBackgroundDownload,
            secondary: const Icon(Icons.cloud_download),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'About Downloads',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 12),
                _buildInfoCard(
                  icon: Icons.info_outline,
                  title: 'Download Size',
                  description:
                      'Each translation/tafsir contains all 114 surahs. Size varies from 1-5 MB depending on the edition.',
                ),
                const SizedBox(height: 12),
                _buildInfoCard(
                  icon: Icons.storage,
                  title: 'Storage',
                  description:
                      'Downloaded content is stored locally on your device for offline access.',
                ),
                const SizedBox(height: 12),
                _buildInfoCard(
                  icon: Icons.sync,
                  title: 'Updates',
                  description:
                      'Downloaded editions do not auto-update. Delete and re-download to get latest version.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
