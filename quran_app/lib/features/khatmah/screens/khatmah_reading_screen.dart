import 'package:flutter/material.dart';
import 'package:quran_app/core/quran/widgets/quran_pageview.dart';
import '../services/khatmah_service.dart';

class KhatmahReadingScreen extends StatefulWidget {
  final String khatmahId;
  final int startPage;
  final int endPage;
  final int initialPage;

  const KhatmahReadingScreen({
    super.key,
    required this.khatmahId,
    required this.startPage,
    required this.endPage,
    required this.initialPage,
  });

  @override
  State<KhatmahReadingScreen> createState() => _KhatmahReadingScreenState();
}

class _KhatmahReadingScreenState extends State<KhatmahReadingScreen> {
  late PageController _pageController;
  late int _currentPage;
  final KhatmahService _khatmahService = KhatmahService();

  @override
  void initState() {
    super.initState();
    // Calculate initial index based on startPage
    // If initialPage is 11 and startPage is 11, index is 0.
    final initialIndex = widget.initialPage - widget.startPage;
    _pageController = PageController(initialPage: initialIndex);
    _currentPage = widget.initialPage;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    final newPage = widget.startPage + index;
    setState(() {
      _currentPage = newPage;
    });
    _khatmahService.updateKhatmahProgress(widget.khatmahId, newPage);
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = widget.endPage - widget.startPage + 1;
    final progress = _currentPage - widget.startPage + 1;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Quran Page View
            Directionality(
              textDirection: TextDirection.rtl,
              child: PageView.builder(
                controller: _pageController,
                reverse: false, // right-to-left
                itemCount: totalPages,
                onPageChanged: _onPageChanged,
                itemBuilder: (context, index) {
                  final pageNumber = widget.startPage + index;
                  return QuranPageContent(
                    pageNumber: pageNumber,
                    fontSize: null, // Use default
                    textColor: Theme.of(context).colorScheme.onSurface,
                    sp: 1.0,
                    h: 1.0,
                    scrollMode: ScrollMode.horizontal,
                    onLongPress: null,
                    onLongPressUp: null,
                    onLongPressCancel: null,
                    onLongPressDown: null,
                  );
                },
              ),
            ),

            // Top Bar (Overlay)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color:
                    Theme.of(context).scaffoldBackgroundColor.withOpacity(0.9),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Column(
                      children: [
                        Text(
                          'Khatmah Session',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          'Page $progress of $totalPages',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(width: 48), // Balance close button
                  ],
                ),
              ),
            ),

            // Bottom Progress Bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                value: progress / totalPages,
                backgroundColor: Colors.grey.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
