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
    setState(() => _currentPage = newPage);
    _khatmahService.updateKhatmahProgress(widget.khatmahId, newPage);
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = widget.endPage - widget.startPage + 1;
    final progress = _currentPage - widget.startPage + 1;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _buildReadingView(totalPages, progress, context),
    );
  }

  Widget _buildReadingView(int totalPages, int progress, BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          _buildQuranPageView(totalPages, context),
          _buildTopAppBar(context, progress, totalPages),
          _buildProgressIndicator(progress, totalPages, context),
        ],
      ),
    );
  }

  Widget _buildQuranPageView(int totalPages, BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: PageView.builder(
        controller: _pageController,
        reverse: false,
        itemCount: totalPages,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          final pageNumber = widget.startPage + index;
          return QuranPageContent(
            pageNumber: pageNumber,
            fontSize: null,
            textColor: Theme.of(context).colorScheme.onSurface,
            sp: 1.0,
            h: 1.0,
            scrollMode: ScrollMode.horizontal,
            onLongPress: null,
            onLongPressUp: null,
            onLongPressCancel: null,
            onLongPressStart: null,
          );
        },
      ),
    );
  }

  Widget _buildTopAppBar(BuildContext context, int progress, int totalPages) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildCloseButton(context),
            _buildProgressInfo(progress, totalPages, context),
            const SizedBox(width: 48), // Balance layout
          ],
        ),
      ),
    );
  }

  Widget _buildCloseButton(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.close),
      onPressed: () => Navigator.pop(context),
      tooltip: 'Close',
    );
  }

  Widget _buildProgressInfo(
      int progress, int totalPages, BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Khatmah Session',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          'Page $progress of $totalPages',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator(
    int progress,
    int totalPages,
    BuildContext context,
  ) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 4,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progress / totalPages,
            backgroundColor: Theme.of(context).dividerColor,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).primaryColor,
            ),
            minHeight: 4,
          ),
        ),
      ),
    );
  }
}
