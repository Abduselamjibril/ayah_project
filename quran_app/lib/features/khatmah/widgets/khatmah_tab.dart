import 'package:flutter/material.dart';
import 'package:quran_app/core/i18n/app_localizations.dart';
import '../models/khatmah.dart';
import '../services/khatmah_service.dart';
import '../../mushaf/controller/mushaf_controller.dart';
import '../screens/khatmah_reading_screen.dart';
import 'package:quran_app/app/app.dart';

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
    // RULE 1: Using your complete UI structure from HEAD.
    final theme = Theme.of(context);
    final background = theme.scaffoldBackgroundColor;
    final onBackground = theme.colorScheme.onSurface;
    final accent = BrandColors.accent;

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
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Khatmah',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: onBackground,
                      ),
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: onBackground.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        Icons.arrow_forward_ios,
                        size: 18,
                        color: BrandColors.accent,
                      ),
                      onPressed: () {
                        Navigator.of(context).maybePop();
                      },
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: bodyContent),
          ],
        ),
      ),
      floatingActionButton: floatingActionButton,
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
            "Choose a period to complete the Quran, and continue your Khatmah during Ramadan and throughout the year.",
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
            child: const Text('Start New Khatmah'),
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
    final progress = k.lastReadPage / 604;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _confirmDelete(k.id),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 8),
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
                  style: const TextStyle(color: Colors.grey),
                ),
                Text(
                  'Page ${k.lastReadPage} / 604',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)?.translate('todays_goal') ??
                          'Today\'s Goal',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
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
                  onPressed: () async {
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
                  },
                  icon: const Icon(Icons.menu_book),
                  label: Text(
                    AppLocalizations.of(context)?.translate('read_now') ??
                        'Read Now',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BrandColors.accent,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
