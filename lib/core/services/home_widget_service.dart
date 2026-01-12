import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:workmanager/workmanager.dart';

import '../../features/bookmarks/data/repositories/bookmark_notes_repository.dart';

const _refreshTask = 'com.quran_app.widget.refresh';
const _lastSurahKey = 'last_surah';
const _lastAyahKey = 'last_ayah';

/// Keeps the Android/iOS home widget in sync with the local SQLite state.
class HomeWidgetService {
  HomeWidgetService._();

  static final HomeWidgetService instance = HomeWidgetService._();
  final BookmarkNotesRepository _repository = BookmarkNotesRepository();

  Future<void> initializeBackgroundSync() async {
    if (!Platform.isAndroid) return;
    try {
      await Workmanager().initialize(_callbackDispatcher, isInDebugMode: false);
      await Workmanager().registerPeriodicTask(
        'refresh-widget-task',
        _refreshTask,
        frequency: const Duration(hours: 6),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        constraints: Constraints(networkType: NetworkType.notRequired),
      );
    } catch (e, st) {
      debugPrint('HomeWidgetService background sync init failed: $e\n$st');
    }
  }

  Future<void> updateLastRead(
      {required int surahId, required int ayahId}) async {
    await HomeWidget.saveWidgetData<int>(_lastSurahKey, surahId);
    await HomeWidget.saveWidgetData<int>(_lastAyahKey, ayahId);
    await HomeWidget.updateWidget(
      name: 'LastReadWidgetProvider',
      iOSName: 'LastReadWidget',
    );
  }
}

@pragma('vm:entry-point')
void _callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    if (task != _refreshTask) return false;
    final repo = BookmarkNotesRepository();
    final pin = await repo.getKhatmahPin();
    if (pin == null) return true;
    await HomeWidget.saveWidgetData<int>(_lastSurahKey, pin.surahId);
    await HomeWidget.saveWidgetData<int>(_lastAyahKey, pin.ayahId);
    await HomeWidget.updateWidget(
      name: 'LastReadWidgetProvider',
      iOSName: 'LastReadWidget',
    );
    return true;
  });
}
