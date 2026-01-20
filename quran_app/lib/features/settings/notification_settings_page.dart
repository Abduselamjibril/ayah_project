import 'package:flutter/material.dart';
import 'package:quran_app/app/app.dart';
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
    final theme = Theme.of(context);
    final accent = BrandColors.accent;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leadingWidth: 100,
        leading: TextButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: accent, size: 18),
          label: Text(
            'Settings',
            style: TextStyle(color: accent, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          style: TextButton.styleFrom(padding: const EdgeInsets.only(left: 8)),
        ),
        title: Text(
          'Notification Settings',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
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
