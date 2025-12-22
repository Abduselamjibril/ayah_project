// lib/features/downloads/download_settings_page.dart
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
      // Defaults: WiFi-only OFF, Background downloads ON
      _wifiOnly = prefs.getBool('download_wifi_only') ?? false;
      _backgroundDownload = prefs.getBool('download_background') ?? true;
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
    // No warnings/snackbars per requirements
  }

  Future<void> _saveBackgroundDownload(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('download_background', value);
    setState(() => _backgroundDownload = value);
    // Full background service with notifications to be implemented separately
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
                GestureDetector(
                  onTap: () async {
                    // Navigate to storage management page
                    if (!mounted) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const StorageManagementPage(),
                      ),
                    );
                  },
                  child: _buildInfoCard(
                    icon: Icons.storage,
                    title: 'Storage',
                    description:
                        'View downloaded items by category, sizes, and bulk delete.',
                  ),
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
      ConnectivityResult.ethernet => Colors.green,
      ConnectivityResult.vpn => Colors.blue,
      ConnectivityResult.mobile => Colors.orange,
      _ => Colors.red,
    };

    final label = switch (active) {
      ConnectivityResult.wifi => 'Connected to WiFi',
      ConnectivityResult.ethernet => 'Ethernet connection',
      ConnectivityResult.vpn => 'VPN connection',
      ConnectivityResult.mobile => 'Mobile data',
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
          Icon(Icons.wifi_tethering, color: color),
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
                  'Network preference is applied before downloads.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  ConnectivityResult _choosePrimaryConnection(List<ConnectivityResult> list) {
    if (list.any((e) => e == ConnectivityResult.wifi)) {
      return ConnectivityResult.wifi;
    }
    if (list.any((e) => e == ConnectivityResult.ethernet)) {
      return ConnectivityResult.ethernet;
    }
    if (list.any((e) => e == ConnectivityResult.vpn)) {
      return ConnectivityResult.vpn;
    }
    if (list.any((e) => e == ConnectivityResult.mobile)) {
      return ConnectivityResult.mobile;
    }
    return ConnectivityResult.none;
  }
}
