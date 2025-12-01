import 'package:flutter/material.dart';
import '../models/khatmah.dart';
import '../services/khatmah_service.dart';
import '../../mushaf/controller/mushaf_controller.dart';
import '../screens/khatmah_reading_screen.dart';

class KhatmahTab extends StatefulWidget {
  final MushafController controller;

  const KhatmahTab({super.key, required this.controller});

  @override
  State<KhatmahTab> createState() => _KhatmahTabState();
}

class _KhatmahTabState extends State<KhatmahTab> {
  final KhatmahService _service = KhatmahService();
  Khatmah? _currentKhatmah;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadKhatmah();
    _service.init();

    // Listen to controller to update progress when user reads
    widget.controller.addListener(_onPageChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onPageChanged);
    super.dispose();
  }

  void _onPageChanged() {
    // Update progress when page changes
    // We might want to debounce this or only update if it's a significant change
    // For now, just update.
    if (_currentKhatmah != null) {
      _service.updateProgress(widget.controller.currentPage);
      // Reload local state to reflect changes if needed, but updateProgress is async
      // Maybe just update local state?
      // _currentKhatmah = _currentKhatmah!.copyWith(lastReadPage: widget.controller.currentPage);
      // setState(() {});
      // Actually, let's just reload periodically or when tab is opened?
      // Updating service is enough for persistence.
    }
  }

  Future<void> _loadKhatmah() async {
    final khatmah = await _service.getCurrentKhatmah();
    if (mounted) {
      setState(() {
        _currentKhatmah = khatmah;
        _isLoading = false;
      });
    }
  }

  Future<void> _startNewKhatmah(int days) async {
    await _service.startKhatmah(days);
    _loadKhatmah();
  }

  Future<void> _deleteKhatmah() async {
    await _service.deleteKhatmah();
    _loadKhatmah();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_currentKhatmah == null) {
      return _buildStartScreen();
    }

    return _buildProgressScreen();
  }

  Widget _buildStartScreen() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book,
              size: 64, color: Theme.of(context).primaryColor.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text(
            'Start a New Khatmah',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select a duration to complete the Quran',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 32),
          _buildOptionButton('1 Month (29 Days)', 29),
          const SizedBox(height: 12),
          _buildOptionButton('15 Days', 15),
          const SizedBox(height: 12),
          _buildOptionButton('10 Days', 10),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _showCustomDaysDialog,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text('Custom Duration'),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionButton(String text, int days) {
    return ElevatedButton(
      onPressed: () => _startNewKhatmah(days),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      child: Text(text),
    );
  }

  Widget _buildProgressScreen() {
    final k = _currentKhatmah!;
    final progress = k.lastReadPage / 604;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    'Day ${k.currentDay} of ${k.durationDays}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).primaryColor),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(progress * 100).toStringAsFixed(1)}% Completed',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Page ${k.lastReadPage} / 604',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Today\'s Goal',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Card(
            color: Theme.of(context).primaryColor.withOpacity(0.05),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                  color: Theme.of(context).primaryColor.withOpacity(0.2)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Target Pages',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(
                            '${k.startPageForToday} - ${k.targetPageForToday}',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Amount',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(
                            '${k.pagesPerDay} pages',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () async {
                      // Calculate start and end pages
                      // Start at the last read page (to resume) or 1 if just starting
                      // If lastReadPage is 0, start at 1.
                      // If lastReadPage is 10, start at 10 (resume reading page 10).
                      // Wait, if lastReadPage means "completed", then start at lastReadPage + 1.
                      // But user said: "if he close it in page 11 ... open at page 11".
                      // This implies lastReadPage tracks the CURRENT page.
                      int startPage = k.lastReadPage > 0 ? k.lastReadPage : 1;

                      // Target for today (accumulated)
                      int endPage = k.targetPageForToday;

                      // If user is ahead (start > end), give them the next batch
                      if (startPage > endPage) {
                        endPage = startPage + k.pagesPerDay;
                      }

                      // Clamp to 604
                      if (endPage > 604) endPage = 604;
                      if (startPage > 604) startPage = 604;

                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => KhatmahReadingScreen(
                            startPage: startPage,
                            endPage: endPage,
                            initialPage: startPage,
                          ),
                        ),
                      );

                      // Reload progress when returning
                      _loadKhatmah();
                    },
                    icon: const Icon(Icons.menu_book),
                    label: const Text('Read Now'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 45),
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Khatmah?'),
                  content:
                      const Text('This will delete your current progress.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _deleteKhatmah();
                      },
                      child: const Text('Delete',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            label: const Text('Delete Khatmah',
                style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
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
        title: const Text('Custom Duration'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Enter number of days',
            hintText: 'e.g. 20',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final days = int.tryParse(controller.text);
              if (days != null && days > 0) {
                Navigator.pop(context);
                _startNewKhatmah(days);
              }
            },
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }
}
