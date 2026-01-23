import 'package:flutter/material.dart';
import 'package:quran_app/app/app.dart';
import '../khatmah/services/khatmah_service.dart';
import 'package:quran_app/core/ui/responsive.dart';
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

  Future<void> _updateKhatmahSettings(bool enabled, TimeOfDay time) async {
    setState(() {
      _khatmahEnabled = enabled;
      _khatmahTime = time;
    });
    await _khatmahService.setNotificationSettings(enabled, time);
  }

  Future<void> _updateVotdSettings(bool enabled, TimeOfDay time) async {
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
        ResponsiveLayout.scaled(context, 120, min: 96, max: 140);
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
                _buildSectionHeader(theme, 'Khatmah Reminder'),
                SwitchListTile(
                  title: const Text('Daily Khatmah Reminder'),
                  subtitle: const Text(
                      'Receive a daily notification to read your Khatmah'),
                  value: _khatmahEnabled,
                  onChanged: (value) =>
                      _updateKhatmahSettings(value, _khatmahTime),
                  activeColor: theme.primaryColor,
                ),
                ListTile(
                  title: const Text('Reminder Time'),
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
                _buildSectionHeader(theme, 'Verse of the Day'),
                SwitchListTile(
                  title: const Text('Daily Verse Notification'),
                  subtitle: const Text('Receive a random verse every day'),
                  value: _votdEnabled,
                  onChanged: (value) => _updateVotdSettings(value, _votdTime),
                  activeColor: theme.primaryColor,
                ),
                ListTile(
                  title: const Text('Notification Time'),
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
