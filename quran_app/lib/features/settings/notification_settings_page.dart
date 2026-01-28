import 'package:flutter/material.dart';
import 'package:quran_app/app/app.dart';
import 'package:quran_app/core/i18n/app_localizations.dart';
import '../khatmah/services/khatmah_service.dart';
import 'package:quran_app/core/ui/responsive.dart';
import 'package:quran_app/core/services/notification_service.dart';
import '../../core/services/verse_of_the_day_service.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  final KhatmahService _khatmahService = KhatmahService();
  final VerseOfTheDayService _votdService = VerseOfTheDayService.instance;

  // Khatmah Settings
  bool _khatmahEnabled = false;
  TimeOfDay _khatmahTime = const TimeOfDay(hour: 20, minute: 0);

  // Verse of the Day Settings
  bool _votdEnabled = true;
  TimeOfDay _votdTime = const TimeOfDay(hour: 8, minute: 0);

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final khatmahSettings = await _khatmahService.getNotificationSettings();

    if (mounted) {
      setState(() {
        _khatmahEnabled = khatmahSettings['enabled'];
        _khatmahTime = TimeOfDay(
            hour: khatmahSettings['hour'], minute: khatmahSettings['minute']);

        _votdEnabled = _votdService.enabled;
        _votdTime = _votdService.notificationTime;

        _isLoading = false;
      });
    }
  }

  Future<bool> _ensureExactAlarms() async {
    final canExact =
        await AppNotificationService.instance.canScheduleExactAlarms();
    if (canExact) return true;

    if (!mounted) return false;

    // Show dialog (Android only)
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
              'To send reminders at exact times, this app needs permission to schedule exact alarms. '
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
              'Notifications are disabled for this app. Please enable them in settings to receive reminders.',
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

  Future<void> _updateKhatmahSettings(bool enabled, TimeOfDay time) async {
    if (enabled) {
      // 1. Check Notification Permission
      final notifGranted = await _checkNotificationPermission();
      if (!notifGranted) {
        if (mounted) {
          setState(() => _khatmahEnabled = false);
        }
        return;
      }

      // 2. Check Exact Alarm Permission (Android)
      final exactGranted = await _ensureExactAlarms();
      if (!exactGranted) {
        if (mounted) {
          setState(() => _khatmahEnabled = false);
        }
        return;
      }
    }

    setState(() {
      _khatmahEnabled = enabled;
      _khatmahTime = time;
    });
    await _khatmahService.setNotificationSettings(enabled, time);
  }

  Future<void> _updateVotdSettings(bool enabled, TimeOfDay time) async {
    if (enabled) {
      // 1. Check Notification Permission
      final notifGranted = await _checkNotificationPermission();
      if (!notifGranted) {
        if (mounted) {
          setState(() => _votdEnabled = false);
        }
        return;
      }

      // 2. Check Exact Alarm Permission (Android)
      final exactGranted = await _ensureExactAlarms();
      if (!exactGranted) {
        if (mounted) {
          setState(() => _votdEnabled = false);
        }
        return;
      }
    }

    setState(() {
      _votdEnabled = enabled;
      _votdTime = time;
    });
    await _votdService.setEnabled(enabled);
    await _votdService.setNotificationTime(time);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = BrandColors.accent;
    final leadingWidth =
        ResponsiveLayout.scaled(context, 170, min: 140, max: 210);
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
          label: ConstrainedBox(
            constraints: BoxConstraints(minWidth: 60, maxWidth: 120),
            child: Text(
              AppLocalizations.of(context)?.translate('settings_title') ??
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
          ),
          style: TextButton.styleFrom(
              padding: EdgeInsets.only(
                  left: ResponsiveLayout.scaled(context, 8, min: 6, max: 12))),
        ),
        title: Text(
          AppLocalizations.of(context)
                  ?.translate('notification_settings_title') ??
              'Notification Settings',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700, fontSize: titleFontSize),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.all(listPadding),
              children: [
                _buildSectionHeader(
                  theme,
                  AppLocalizations.of(context)
                          ?.translate('khatmah_reminder_section') ??
                      'Khatmah Reminder',
                ),
                SwitchListTile(
                  title: Text(
                    AppLocalizations.of(context)
                            ?.translate('daily_khatmah_reminder') ??
                        'Daily Khatmah Reminder',
                  ),
                  subtitle: Text(
                    AppLocalizations.of(context)
                            ?.translate('daily_khatmah_reminder_subtitle') ??
                        'Receive a daily notification to read your Khatmah',
                  ),
                  value: _khatmahEnabled,
                  onChanged: (value) =>
                      _updateKhatmahSettings(value, _khatmahTime),
                  activeColor: theme.primaryColor,
                ),
                ListTile(
                  title: Text(
                    AppLocalizations.of(context)?.translate('reminder_time') ??
                        'Reminder Time',
                  ),
                  subtitle: Text(_khatmahTime.format(context)),
                  enabled: _khatmahEnabled,
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final TimeOfDay? picked = await showTimePicker(
                      context: context,
                      initialTime: _khatmahTime,
                    );
                    if (picked != null && picked != _khatmahTime) {
                      _updateKhatmahSettings(_khatmahEnabled, picked);
                    }
                  },
                ),
                const Divider(),
                _buildSectionHeader(
                  theme,
                  AppLocalizations.of(context)
                          ?.translate('verse_of_the_day_section') ??
                      'Verse of the Day',
                ),
                SwitchListTile(
                  title: Text(
                    AppLocalizations.of(context)
                            ?.translate('daily_verse_notification') ??
                        'Daily Verse Notification',
                  ),
                  subtitle: Text(
                    AppLocalizations.of(context)
                            ?.translate('daily_verse_notification_subtitle') ??
                        'Receive a random verse every day',
                  ),
                  value: _votdEnabled,
                  onChanged: (value) => _updateVotdSettings(value, _votdTime),
                  activeColor: theme.primaryColor,
                ),
                ListTile(
                  title: Text(
                    AppLocalizations.of(context)
                            ?.translate('notification_time') ??
                        'Notification Time',
                  ),
                  subtitle: Text(_votdTime.format(context)),
                  enabled: _votdEnabled,
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final TimeOfDay? picked = await showTimePicker(
                      context: context,
                      initialTime: _votdTime,
                    );
                    if (picked != null && picked != _votdTime) {
                      _updateVotdSettings(_votdEnabled, picked);
                    }
                  },
                ),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.primaryColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
