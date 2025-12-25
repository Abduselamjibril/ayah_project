import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'audio_player_service.dart';

/// Manages audio playback notification with play/pause/stop actions.
class AudioNotificationService {
  AudioNotificationService._();
  static final AudioNotificationService instance = AudioNotificationService._();

  static const int _notificationId = 2001;
  static const String _channelId = 'quran_audio';
  static const String _channelName = 'Quran Audio';
  static const String _actionPlay = 'audio_play';
  static const String _actionPause = 'audio_pause';
  static const String _actionStop = 'audio_stop';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings =
        InitializationSettings(android: androidInit, iOS: iosInit);
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleAction,
    );
    _initialized = true;
  }

  Future<void> showNowPlaying({
    required String title,
    required String reciterName,
    required bool isPlaying,
  }) async {
    if (!_initialized) await init();
    final actions = <AndroidNotificationAction>[
      if (isPlaying)
        const AndroidNotificationAction(_actionPause, 'Pause')
      else
        const AndroidNotificationAction(_actionPlay, 'Play'),
      const AndroidNotificationAction(
        _actionStop,
        'Stop',
        showsUserInterface: false,
        cancelNotification: true,
      ),
    ];

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Audio playback controls',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      showWhen: false,
      onlyAlertOnce: true,
      category: AndroidNotificationCategory.service,
      actions: actions,
    );

    const iosDetails = DarwinNotificationDetails(
      interruptionLevel: InterruptionLevel.active,
      presentSound: false,
    );

    final notificationDetails =
        NotificationDetails(android: androidDetails, iOS: iosDetails);
    await _plugin.show(
        _notificationId, title, reciterName, notificationDetails);
  }

  /// Show download progress in the notification area (Android only).
  Future<void> showDownloadProgress({
    required String title,
    required String reciterName,
    required double progress, // 0.0 - 1.0
  }) async {
    if (!_initialized) await init();
    final intPct = (progress.clamp(0.0, 1.0) * 100).round();

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Audio download progress',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      onlyAlertOnce: true,
      showWhen: false,
      category: AndroidNotificationCategory.progress,
      // progress support
      showProgress: true,
      maxProgress: 100,
      progress: intPct,
      indeterminate: false,
    );

    const iosDetails = DarwinNotificationDetails(
      interruptionLevel: InterruptionLevel.passive,
      presentSound: false,
    );

    final notificationDetails =
        NotificationDetails(android: androidDetails, iOS: iosDetails);
    await _plugin.show(
        _notificationId, title, '$reciterName • $intPct%', notificationDetails);
  }

  Future<void> cancel() async {
    if (!_initialized) return;
    await _plugin.cancel(_notificationId);
  }

  // Handle notification button taps.
  void _handleAction(NotificationResponse response) {
    final actionId = response.actionId;
    if (actionId == _actionPause) {
      AudioPlayerService.instance.pause();
      showNowPlaying(
        title: AudioPlayerService.instance.currentLabel.value,
        reciterName: AudioPlayerService.instance.recitationName,
        isPlaying: false,
      );
    } else if (actionId == _actionPlay) {
      AudioPlayerService.instance.resume();
      showNowPlaying(
        title: AudioPlayerService.instance.currentLabel.value,
        reciterName: AudioPlayerService.instance.recitationName,
        isPlaying: true,
      );
    } else if (actionId == _actionStop) {
      AudioPlayerService.instance.stop();
      cancel();
    }
  }
}
