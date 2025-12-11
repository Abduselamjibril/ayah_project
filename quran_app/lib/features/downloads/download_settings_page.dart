// lib/features/downloads/download_settings_page.dart
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
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
  List<ConnectivityResult> _connections = const [ConnectivityResult.none];
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _initConnectivityListener();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _wifiOnly = prefs.getBool('download_wifi_only') ?? true;
      _backgroundDownload = prefs.getBool('download_background') ?? false;
      _isLoading = false;
    });
  }

  Future<void> _initConnectivityListener() async {
    final connectivity = Connectivity();
    final initial = await connectivity.checkConnectivity();
    if (mounted) {
      setState(() => _connections = initial);
    }

    _connectivitySub = connectivity.onConnectivityChanged.listen((status) {
      if (mounted) {
        setState(() => _connections = status);
      }
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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildConnectionStatusCard(),
          ),
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
              'Keep downloads running when you switch apps. On iOS the app must stay in foreground for reliability.',
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

  Widget _buildConnectionStatusCard() {
    final active = _choosePrimaryConnection(_connections);

    final color = switch (active) {
      ConnectivityResult.wifi => Colors.green,
      ConnectivityResult.mobile => Colors.orange,
      ConnectivityResult.ethernet => Colors.green,
      ConnectivityResult.vpn => Colors.blue,
      _ => Colors.red,
    };

    final label = switch (active) {
      ConnectivityResult.wifi => 'Connected to WiFi',
      ConnectivityResult.mobile => 'Using mobile data',
      ConnectivityResult.ethernet => 'Ethernet connection',
      ConnectivityResult.vpn => 'VPN connection',
      _ => 'Offline',
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Row(
        children: [
          Icon(Icons.podcasts, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                        TextStyle(color: color, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text(
                  'These settings are enforced before downloads start.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh connection',
            onPressed: () async {
              final status = await Connectivity().checkConnectivity();
              if (mounted) setState(() => _connections = status);
            },
          ),
        ],
      ),
    );
  }

  ConnectivityResult _choosePrimaryConnection(List<ConnectivityResult> list) {
    if (list.any((e) => e == ConnectivityResult.wifi))
      return ConnectivityResult.wifi;
    if (list.any((e) => e == ConnectivityResult.ethernet))
      return ConnectivityResult.ethernet;
    if (list.any((e) => e == ConnectivityResult.vpn))
      return ConnectivityResult.vpn;
    if (list.any((e) => e == ConnectivityResult.mobile))
      return ConnectivityResult.mobile;
    return ConnectivityResult.none;
  }
}
