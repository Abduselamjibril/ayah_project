import 'package:flutter/material.dart';
import '../khatmah/services/khatmah_service.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  final KhatmahService _service = KhatmahService();
  bool _enabled = false;
  TimeOfDay _time = const TimeOfDay(hour: 20, minute: 0);
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await _service.getNotificationSettings();
    if (mounted) {
      setState(() {
        _enabled = settings['enabled'];
        _time = TimeOfDay(hour: settings['hour'], minute: settings['minute']);
        _isLoading = false;
      });
    }
  }

  Future<void> _updateSettings(bool enabled, TimeOfDay time) async {
    setState(() {
      _enabled = enabled;
      _time = time;
    });
    await _service.setNotificationSettings(enabled, time);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                SwitchListTile(
                  title: const Text('Daily Khatmah Reminder'),
                  subtitle: const Text(
                      'Receive a daily notification to read your Khatmah'),
                  value: _enabled,
                  onChanged: (value) => _updateSettings(value, _time),
                ),
                ListTile(
                  title: const Text('Reminder Time'),
                  subtitle: Text(_time.format(context)),
                  enabled: _enabled,
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final TimeOfDay? picked = await showTimePicker(
                      context: context,
                      initialTime: _time,
                    );
                    if (picked != null && picked != _time) {
                      _updateSettings(_enabled, picked);
                    }
                  },
                ),
              ],
            ),
    );
  }
}
