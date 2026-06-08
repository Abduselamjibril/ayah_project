import 'package:flutter/material.dart';
import 'package:quran_app/core/i18n/app_localizations.dart';
import '../models/khatmah.dart';
import '../services/khatmah_service.dart';
import '../../mushaf/controller/mushaf_controller.dart';
import '../screens/khatmah_reading_screen.dart';
import 'package:quran_app/app/app.dart';
import 'package:quran_app/core/ui/snackbar_utils.dart';

class KhatmahTab extends StatefulWidget {
  final MushafController controller;

  const KhatmahTab({super.key, required this.controller});

  @override
  State<KhatmahTab> createState() => _KhatmahTabState();
}

class _KhatmahTabState extends State<KhatmahTab> {
  final KhatmahService _service = KhatmahService();
  List<Khatmah> _khatmahs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadKhatmahs();
    _service.init();
  }

  @override
  void dispose() {
    // RULE 2: Accepted company's logic/architectural note.
    // The listener for page changes is now handled within KhatmahReadingScreen
    // or triggered on return from it, so no listener here.
    super.dispose();
  }

  Future<void> _loadKhatmahs() async {
    final khatmahs = await _service.getAllKhatmahs();
    if (mounted) {
      setState(() {
        _khatmahs = khatmahs;
        _isLoading = false;
      });
    }
  }

  Future<void> _addKhatmah(int days) async {
    await _service.addKhatmah(days);
    _loadKhatmahs();
  }

  Future<void> _deleteKhatmah(String id) async {
    await _service.deleteKhatmah(id);
    _loadKhatmahs();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final background =
        isLight ? theme.colorScheme.surface : theme.scaffoldBackgroundColor;
    final cardBackground =
        isLight ? theme.scaffoldBackgroundColor : theme.cardColor;
    final accent = BrandColors.accent;

    // Use a slightly larger top padding to match the visual spacing in the screenshot
    final double topPadding = 28.0;

    Widget bodyContent;
    Widget? floatingActionButton;

    if (_isLoading) {
      bodyContent = const Center(child: CircularProgressIndicator());
    } else if (_khatmahs.isEmpty) {
      bodyContent = _buildStartScreen();
    } else {
      bodyContent = ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _khatmahs.length,
        itemBuilder: (context, index) {
          return _buildKhatmahCard(_khatmahs[index]);
        },
      );
      floatingActionButton = FloatingActionButton.extended(
        onPressed: _showDurationOptions,
        label: Text(
          AppLocalizations.of(context)?.translate('new_plan') ?? 'New Plan',
          style: const TextStyle(color: Colors.white),
        ),
        icon: const Icon(Icons.add, color: Colors.white),
        backgroundColor: accent,
        foregroundColor: Colors.white,
      );
    }

    return Scaffold(
      backgroundColor: background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            elevation: 0,
            color: Colors.transparent,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                  top: topPadding, left: 24, right: 24, bottom: 18),
              color: background,
              alignment: Alignment.centerLeft,
              child: Text(
                AppLocalizations.of(context)?.translate('khatmah') ?? 'Khatmah',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                  fontSize: 40,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              bottom: false,
              child: bodyContent,
            ),
          ),
          Material(
            elevation: 2,
            shadowColor: Colors.black.withOpacity(0.08),
            child: Container(
              width: double.infinity,
              height: 0,
              color: background,
            ),
          ),
        ],
      ),
      floatingActionButton: floatingActionButton == null
          ? null
          : Material(
              elevation: 2,
              shadowColor: Colors.black.withOpacity(0.08),
              type: MaterialType.transparency,
              child: floatingActionButton,
            ),
    );
  }

  Widget _buildStartScreen() {
    // RULE 1: Using your custom start screen UI from HEAD.
    final theme = Theme.of(context);
    final onBackground = theme.colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context)!.translate('khatmah_description'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              color: onBackground.withOpacity(0.82),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 36),
          ElevatedButton(
            onPressed: _showDurationOptions,
            style: ElevatedButton.styleFrom(
              backgroundColor: BrandColors.accent,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              foregroundColor: Colors.white,
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: Text(
              AppLocalizations.of(context)?.translate('start_new_khatmah') ??
                  'Start New Khatmah',
            ),
          ),
        ],
      ),
    );
  }

  void _showDurationOptions() {
    // RULE 1: Using your custom modal bottom sheet UI from HEAD.
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppLocalizations.of(context)?.translate('select_duration') ??
                    'Select a duration to complete the Quran',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),
              _buildOptionButton(
                AppLocalizations.of(context)?.translate('duration_1_month') ??
                    '1 Month (29 Days)',
                29,
              ),
              const SizedBox(height: 12),
              _buildOptionButton(
                AppLocalizations.of(context)?.translate('duration_15_days') ??
                    '15 Days',
                15,
              ),
              const SizedBox(height: 12),
              _buildOptionButton(
                AppLocalizations.of(context)?.translate('duration_10_days') ??
                    '10 Days',
                10,
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(context); // Close bottom sheet
                  _showCustomDaysDialog();
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: Text(
                  AppLocalizations.of(context)?.translate('custom_duration') ??
                      'Custom Duration',
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOptionButton(String text, int days) {
    // RULE 1: Using your styled button from HEAD.
    return ElevatedButton(
      onPressed: () {
        Navigator.pop(context); // Close the bottom sheet first
        _addKhatmah(days);
      },
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        backgroundColor: BrandColors.accent,
        foregroundColor: Colors.white,
      ),
      child: Text(text),
    );
  }

  Widget _buildKhatmahCard(Khatmah k) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final cardBackground =
        isLight ? theme.scaffoldBackgroundColor : theme.cardColor;
    final progress = k.lastReadPage / 604;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      elevation: 2,
      color: cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  (AppLocalizations.of(context)?.translate('day_progress') ??
                          'Day {current} of {total}')
                      .replaceAll('{current}', '${k.currentDay}')
                      .replaceAll('{total}', '${k.durationDays}'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.redAccent, size: 20),
                  onPressed: () => _confirmDelete(k.id),
                  splashRadius: 20,
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor:
                  Theme.of(context).colorScheme.onSurface.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation<Color>(BrandColors.accent),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  (AppLocalizations.of(
                            context,
                          )?.translate('percent_completed') ??
                          '{percent}% Completed')
                      .replaceAll(
                    '{percent}',
                    (progress * 100).toStringAsFixed(1),
                  ),
                  style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.6)),
                ),
                Text(
                  'Page ${k.lastReadPage} / 604',
                  style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withOpacity(0.6)),
                ),
              ],
            ),
            const Divider(height: 24, thickness: 0.5),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Today's goal + small read button on the right
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)
                                  ?.translate('todays_goal') ??
                              'Today\'s Goal',
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${k.startPageForToday} - ${k.targetPageForToday}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _startReading(k),
                      icon: const Icon(Icons.menu_book, color: Colors.white),
                      label: Text(
                        AppLocalizations.of(context)?.translate('read_now') ??
                            'Read Now',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BrandColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        minimumSize: const Size(120, 44),
                        elevation: 2,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),
                // Centered prominent action: mark as complete
                ElevatedButton.icon(
                  onPressed: () async {
                    final updated =
                        k.copyWith(isCompleted: true, lastReadPage: 604);
                    await _service.saveKhatmah(updated);
                    _loadKhatmahs();
                    showAppSnack(
                      context,
                      AppLocalizations.of(context)
                              ?.translate('khatmah_marked_complete') ??
                          'Khatmah marked as complete',
                      type: AppSnackType.success,
                    );
                  },
                  icon: const Icon(Icons.check_circle, color: Colors.white),
                  label: Text(
                    AppLocalizations.of(context)?.translate('mark_complete') ??
                        'Mark as Complete',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BrandColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    minimumSize: const Size(double.infinity, 50),
                    elevation: 2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _startReading(Khatmah k) async {
    int startPage = 1;
    int endPage = k.targetPageForToday;
    int initialPage = k.lastReadPage > 0 ? k.lastReadPage : 1;

    if (initialPage > endPage) {
      endPage = initialPage + k.pagesPerDay;
    }

    if (endPage > 604) endPage = 604;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => KhatmahReadingScreen(
          khatmahId: k.id,
          startPage: startPage,
          endPage: endPage,
          initialPage: initialPage,
        ),
      ),
    );

    _loadKhatmahs();
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppLocalizations.of(context)?.translate('delete_khatmah_title') ??
              'Delete Khatmah?',
        ),
        content: Text(
          AppLocalizations.of(context)?.translate('delete_khatmah_content') ??
              'This will delete this plan and its progress.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppLocalizations.of(context)?.translate('cancel') ?? 'Cancel',
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteKhatmah(id);
            },
            child: Text(
              AppLocalizations.of(context)?.translate('delete_action') ??
                  'Delete',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showCustomDaysDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppLocalizations.of(context)?.translate('new_khatmah_plan') ??
              'New Khatmah Plan',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppLocalizations.of(context)?.translate('enter_duration') ??
                  'Enter duration in days:',
            ),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'e.g. 30'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppLocalizations.of(context)?.translate('cancel') ?? 'Cancel',
            ),
          ),
          TextButton(
            onPressed: () {
              final days = int.tryParse(controller.text);
              if (days != null && days > 0) {
                Navigator.pop(context);
                _addKhatmah(days);
              }
            },
            child: Text(
              AppLocalizations.of(context)?.translate('create_action') ??
                  'Create',
            ),
          ),
        ],
      ),
    );
  }
}
