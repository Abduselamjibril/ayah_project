import 'package:flutter/material.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../services/khatmah_service.dart';
import 'package:quran_app/features/mushaf/controller/mushaf_controller.dart';
import 'package:quran_app/features/mushaf/widgets/horizontal_mushaf_view.dart';

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
  late final MushafController _mushafController;
  final KhatmahService _khatmahService = KhatmahService();
  bool _overlayVisible = true;

  @override
  void initState() {
    super.initState();
    _mushafController = MushafController();
    // Initialize controller to the correct page
    // We delay the jump slightly to ensure the view is ready or just rely on the initialPage of the view if we could pass it.
    // However, MushafController doesn't accept initialPage in constructor, but HorizontalMushafView reads currentPage from it.
    // So we assume we can set it immediately.
    _mushafController.setPage(widget.initialPage);

    _mushafController.addListener(_onPageChanged);
  }

  @override
  void dispose() {
    _mushafController.removeListener(_onPageChanged);
    _mushafController.dispose();
    super.dispose();
  }

  void _onPageChanged() {
    final newPage = _mushafController.currentPage;
    // Only update progress if within range (though technically they can read outside)
    // For Khatmah, we track where they are.
    _khatmahService.updateKhatmahProgress(widget.khatmahId, newPage);
    setState(() {});
  }

  void _onOverlayVisibilityChanged(bool visible) {
    if (_overlayVisible == visible) return;
    setState(() {
      _overlayVisible = visible;
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = widget.endPage - widget.startPage + 1;
    final progress = _mushafController.currentPage - widget.startPage + 1;

    // Sanity check for progress display
    final displayProgress = progress.clamp(0, totalPages);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // We use the HorizontalMushafView directly.
          // Note: Vertical mode support could be added if requested, but for now we follow the "same thing" instruction which usually implies the main reading view.
          HorizontalMushafView(
            controller: _mushafController,
            onOverlayVisibilityChanged: _onOverlayVisibilityChanged,
          ),

          // Custom Top Bar for Khatmah tracking
          _buildTopAppBar(context, displayProgress, totalPages),

          // Custom Bottom Progress for Khatmah
          _buildProgressIndicator(displayProgress, totalPages, context),
        ],
      ),
    );
  }

  Widget _buildTopAppBar(BuildContext context, int progress, int totalPages) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: !_overlayVisible,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: _overlayVisible ? 1.0 : 0.0,
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
            child: SafeArea(
              bottom: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildCloseButton(context),
                  _buildProgressInfo(progress, totalPages, context),
                  const SizedBox(width: 48), // Balance layout
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCloseButton(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.close),
      onPressed: () => Navigator.pop(context),
      tooltip:
          AppLocalizations.of(context)?.translate('close_tooltip') ?? 'Close',
    );
  }

  Widget _buildProgressInfo(
      int progress, int totalPages, BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          AppLocalizations.of(context)?.translate('khatmah_session') ??
              'Khatmah Session',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          (AppLocalizations.of(context)?.translate('page_progress') ??
                  'Page {current} of {total}')
              .replaceAll('{current}', '$progress')
              .replaceAll('{total}', '$totalPages'),
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
      child: IgnorePointer(
        ignoring: !_overlayVisible,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: _overlayVisible ? 1.0 : 0.0,
          child: Container(
            height: 4,
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 0), // At the very bottom
            child: LinearProgressIndicator(
              value: (totalPages > 0)
                  ? (progress / totalPages).clamp(0.0, 1.0)
                  : 0,
              backgroundColor: Theme.of(context).dividerColor,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
              minHeight: 4,
            ),
          ),
        ),
      ),
    );
  }
}
