import 'package:flutter/material.dart';
import '../../core/services/verse_of_the_day_service.dart';

class DailyVerseSettingsPage extends StatefulWidget {
  const DailyVerseSettingsPage({super.key});

  @override
  State<DailyVerseSettingsPage> createState() => _DailyVerseSettingsPageState();
}

class _DailyVerseSettingsPageState extends State<DailyVerseSettingsPage> {
  final _service = VerseOfTheDayService.instance;
  late bool _enabled;
  late TimeOfDay _time;

  @override
  void initState() {
    super.initState();
    _enabled = _service.enabled;
    _time = _service.notificationTime;
  }

  Future<void> _toggleEnabled(bool value) async {
    await _service.setEnabled(value);
    setState(() {
      _enabled = value;
    });
  }

  Future<void> _pickTime() async {
    final newTime = await showTimePicker(
      context: context,
      initialTime: _time,
    );

    if (newTime != null) {
      await _service.setNotificationTime(newTime);
      setState(() {
        _time = newTime;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Inspiration'),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Enable Daily Verse'),
            subtitle:
                const Text('Receive a random verse notification every day'),
            value: _enabled,
            onChanged: _toggleEnabled,
          ),
          ListTile(
            title: const Text('Notification Time'),
            subtitle: Text(_time.format(context)),
            trailing: const Icon(Icons.access_time_rounded),
            enabled: _enabled,
            onTap: _enabled ? _pickTime : null,
          ),
        ],
      ),
    );
  }
}
