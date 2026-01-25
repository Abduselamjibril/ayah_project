import 'package:flutter/material.dart';
import 'package:quran_app/app/app.dart';
import '../../core/services/verse_of_the_day_service.dart';
import 'package:quran_app/core/services/notification_service.dart';
import 'package:quran_app/core/ui/responsive.dart';

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

  Future<bool> _ensureExactAlarms() async {
    final canExact =
        await AppNotificationService.instance.canScheduleExactAlarms();
    if (canExact) return true;

    await AppNotificationService.instance.openExactAlarmSettings();
    final after =
        await AppNotificationService.instance.canScheduleExactAlarms();
    return after;
  }

  Future<void> _toggleEnabled(bool value) async {
    if (value) {
      final ok = await _ensureExactAlarms();
      if (!ok) {
        if (mounted) {
          setState(() {
            _enabled = false;
          });
        }
        return;
      }
    }
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
    final theme = Theme.of(context);
    final accent = BrandColors.accent;
    final leadingWidth =
        ResponsiveLayout.scaled(context, 132, min: 110, max: 150);
    final backIconSize = ResponsiveLayout.scaled(context, 18, min: 16, max: 22);
    final backFontSize = ResponsiveLayout.scaled(context, 15, min: 13, max: 17);
    final titleFontSize =
        ResponsiveLayout.scaled(context, 18, min: 16, max: 20);
    final listPadding = ResponsiveLayout.scaled(context, 16, min: 12, max: 20);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leadingWidth: leadingWidth,
        leading: TextButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: accent, size: backIconSize),
          label: Text(
            'Settings',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: TextStyle(
              color: accent,
              fontSize: backFontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: TextButton.styleFrom(
              padding: EdgeInsets.only(
                  left: ResponsiveLayout.scaled(context, 8, min: 6, max: 12))),
        ),
        title: Text(
          'Daily Inspiration',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700, fontSize: titleFontSize),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.all(listPadding),
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
