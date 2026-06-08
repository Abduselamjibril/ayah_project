import 'package:flutter/material.dart';
import 'package:quran_app/app/app.dart';
import 'package:quran_app/core/i18n/app_localizations.dart';
import '../../core/services/verse_of_the_day_service.dart';
import 'package:quran_app/core/services/notification_service.dart';
import 'package:quran_app/core/ui/responsive.dart';
import 'package:quran_app/features/settings/widgets/settings_app_bar.dart';

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

    if (!mounted) return false;

    // Show dialog explaining why we need this permission (Android only)
    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppLocalizations.of(context)
                  ?.translate('permission_required_title') ??
              'Permission Required',
        ),
        content: Text(
          AppLocalizations.of(context)
                  ?.translate('exact_alarm_permission_msg') ??
              'To send notifications at exact times, this app needs permission to schedule exact alarms. '
                  'You will be redirected to system settings to grant this permission.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              AppLocalizations.of(context)?.translate('cancel') ?? 'Cancel',
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              AppLocalizations.of(context)?.translate('open_settings') ??
                  'Open Settings',
            ),
          ),
        ],
      ),
    );

    if (shouldOpen == true) {
      await AppNotificationService.instance.openExactAlarmSettings();
      // Wait a bit and check again
      await Future.delayed(const Duration(seconds: 1));
      final after =
          await AppNotificationService.instance.canScheduleExactAlarms();
      return after;
    }

    return false;
  }

  Future<bool> _checkNotificationPermission() async {
    final service = AppNotificationService.instance;

    // 1. Initial Check
    bool enabled = await service.areNotificationsEnabled();
    if (enabled) return true;

    // 2. Request if not enabled
    enabled = await service.requestPermissionsIfNeeded();
    if (enabled) return true;

    // 3. If still denied, show manual settings dialog
    if (!mounted) return false;

    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppLocalizations.of(context)
                  ?.translate('notifications_disabled_title') ??
              'Notifications Disabled',
        ),
        content: Text(
          AppLocalizations.of(context)
                  ?.translate('notifications_disabled_msg') ??
              'Notifications are disabled for this app. Please enable them in settings to receive receiving verses.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              AppLocalizations.of(context)?.translate('cancel') ?? 'Cancel',
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              AppLocalizations.of(context)?.translate('open_settings') ??
                  'Open Settings',
            ),
          ),
        ],
      ),
    );

    if (shouldOpen == true) {
      await service.openAppNotificationSettings();
      // Wait a bit and check again
      await Future.delayed(const Duration(seconds: 1));
      return await service.areNotificationsEnabled();
    }

    return false;
  }

  Future<void> _toggleEnabled(bool value) async {
    if (value) {
      // 1. Check Notification Permission
      final notifGranted = await _checkNotificationPermission();
      if (!notifGranted) {
        if (mounted) {
          setState(() => _enabled = false);
        }
        return;
      }

      // 2. Check Exact Alarm Permission
      final exactGranted = await _ensureExactAlarms();
      if (!exactGranted) {
        if (mounted) {
          setState(() => _enabled = false);
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
    final isLight = theme.brightness == Brightness.light;
    final accent = BrandColors.accent;
    final listPadding = ResponsiveLayout.scaled(context, 16, min: 12, max: 20);
    final cardBg = isLight
        ? theme.scaffoldBackgroundColor
        : theme.cardColor.withOpacity(0.5);
    return Scaffold(
      backgroundColor:
          isLight ? theme.colorScheme.surface : theme.scaffoldBackgroundColor,
      appBar: SettingsAppBar(
        title: AppLocalizations.of(context)
                ?.translate('daily_inspiration_title') ??
            'Daily Inspiration',
      ),
      body: ListView(
        padding: EdgeInsets.all(listPadding),
        children: [
          Card(
            color: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(
                    AppLocalizations.of(context)
                            ?.translate('enable_daily_verse') ??
                        'Enable Daily Verse',
                  ),
                  subtitle: Text(
                    AppLocalizations.of(context)
                            ?.translate('daily_verse_notification_subtitle') ??
                        'Receive a random verse notification every day',
                  ),
                  value: _enabled,
                  onChanged: _toggleEnabled,
                  activeColor: theme.primaryColor,
                ),
                Divider(
                  height: 0,
                  thickness: 0.7,
                  indent: 16,
                  endIndent: 16,
                  color: theme.dividerColor.withOpacity(0.25),
                ),
                ListTile(
                  title: Text(
                    AppLocalizations.of(context)
                            ?.translate('notification_time') ??
                        'Notification Time',
                  ),
                  subtitle: Text(_time.format(context)),
                  trailing: const Icon(Icons.access_time_rounded),
                  enabled: _enabled,
                  onTap: _enabled ? _pickTime : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
