import 'package:flutter/material.dart';
import 'package:quran_app/core/services/translation_service.dart';
import 'package:quran_app/core/services/tafsir_service.dart';
import 'package:quran_app/core/quran/data/suwar.dart';
import 'package:quran_app/core/quran/data/quran_text.dart';
import 'package:quran_app/features/downloads/downloads_screen.dart';

class VerseDetailsScreen extends StatefulWidget {
  final int surahNumber;
  final int ayahNumber;

  const VerseDetailsScreen({
    super.key,
    required this.surahNumber,
    required this.ayahNumber,
  });

  @override
  State<VerseDetailsScreen> createState() => _VerseDetailsScreenState();
}

class _VerseDetailsScreenState extends State<VerseDetailsScreen>
    with SingleTickerProviderStateMixin {
  final TranslationService _translationService = TranslationService.instance;
  final TafsirService _tafsirService = TafsirService.instance;

  List<Map<String, dynamic>> _allTranslations = [];
  List<Map<String, dynamic>> _allTafsirs = [];
  String? _selectedTranslationId;
  String? _selectedTafsirId;
  bool _isLoading = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideUpAnimation;
  late Animation<Color?> _backgroundColorAnimation;

  final PageController _pageController = PageController();
  final int _currentPage = 0;
  bool _showArabicOnly = false;
  bool _isExpanded = true;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _slideUpAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    // `_backgroundColorAnimation` depends on the widget tree's inherited
    // widgets (Theme). Initialize it in `didChangeDependencies` where
    // `context` is safe to use.

    _loadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Initialize background color animation here since it requires Theme
    _backgroundColorAnimation = ColorTween(
      begin: Colors.grey.shade50,
      end: Theme.of(context).colorScheme.surface,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final [translations, tafsirs] = await Future.wait([
        _translationService.getAllTranslations(
          surahNumber: widget.surahNumber,
          ayahNumber: widget.ayahNumber,
        ),
        _tafsirService.getAllTafsirs(
          surahNumber: widget.surahNumber,
          ayahNumber: widget.ayahNumber,
        ),
      ]);

      // Load persisted selections and validate against current lists
      final savedTranslationInt =
          await _translationService.getSelectedTranslationId();
      final savedTafsirInt = await _tafsirService.getSelectedTafsirId();

      String? savedTranslationId = savedTranslationInt?.toString();
      String? savedTafsirId = savedTafsirInt?.toString();

      final hasSavedTranslation = savedTranslationId != null &&
          translations
              .any((t) => t['edition_identifier'] == savedTranslationId);
      final hasSavedTafsir = savedTafsirId != null &&
          tafsirs.any((t) => t['edition_identifier'] == savedTafsirId);

      setState(() {
        _allTranslations = translations;
        _allTafsirs = tafsirs;

        _selectedTranslationId = hasSavedTranslation
            ? savedTranslationId
            : (translations.isNotEmpty
                ? translations.first['edition_identifier']
                : null);
        _selectedTafsirId = hasSavedTafsir
            ? savedTafsirId
            : (tafsirs.isNotEmpty ? tafsirs.first['edition_identifier'] : null);

        _isLoading = false;
      });

      _animationController.forward();
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error loading data: $e');
    }
  }

  String _getArabicText() {
    try {
      final verse = quranText.firstWhere(
        (v) =>
            v['surah_number'] == widget.surahNumber &&
            v['verse_number'] == widget.ayahNumber,
        orElse: () => {'content': ''},
      );
      return verse['content'] as String? ?? '';
    } catch (e) {
      return '';
    }
  }

  String _getSurahName() {
    try {
      final surahData = surah.firstWhere(
        (s) => s['id'] == widget.surahNumber,
        orElse: () => {'name': 'Unknown'},
      );
      return surahData['name'] as String? ?? 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }

  Widget _buildArabicVerseCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).primaryColor.withOpacity(0.1),
            Theme.of(context).primaryColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -20,
            right: -20,
            child: Opacity(
              opacity: 0.1,
              child: Icon(
                Icons.book,
                size: 120,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Verse ${widget.ayahNumber}',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => setState(
                              () => _showArabicOnly = !_showArabicOnly),
                          icon: Icon(
                            _showArabicOnly
                                ? Icons.unfold_less
                                : Icons.unfold_more,
                            color: Theme.of(context).primaryColor,
                          ),
                          tooltip: _showArabicOnly ? 'Show less' : 'Show more',
                        ),
                        IconButton(
                          onPressed: () {
                            // Share functionality
                          },
                          icon: Icon(
                            Icons.share,
                            color: Theme.of(context).primaryColor,
                          ),
                          tooltip: 'Share verse',
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  _getArabicText(),
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontSize: _showArabicOnly ? 32 : 28,
                    height: 2.0,
                    fontFamily: 'Amiri',
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                if (!_showArabicOnly) ...[
                  const SizedBox(height: 16),
                  Divider(
                    color: Theme.of(context).dividerColor.withOpacity(0.3),
                    height: 1,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.import_contacts,
                        size: 16,
                        color: Theme.of(context).primaryColor.withOpacity(0.6),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _getSurahName(),
                        style: TextStyle(
                          fontSize: 14,
                          color:
                              Theme.of(context).primaryColor.withOpacity(0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.library_books,
                        size: 16,
                        color: Theme.of(context).primaryColor.withOpacity(0.6),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Surah ${widget.surahNumber}',
                        style: TextStyle(
                          fontSize: 14,
                          color:
                              Theme.of(context).primaryColor.withOpacity(0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Map<String, dynamic>> items,
    required String? selectedId,
    required Function(String?) onSelected,
    required Widget contentBuilder,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                      ),
                    ),
                    if (items.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${items.length} available',
                          style: TextStyle(
                            fontSize: 12,
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (items.isNotEmpty)
                  _buildEnhancedDropdown(
                    items: items,
                    selectedId: selectedId,
                    onSelected: onSelected,
                    color: color,
                  ),
              ],
            ),
          ),
          if (selectedId != null || items.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              // Constrain the content height relative to screen size so the
              // section becomes scrollable on small devices instead of
              // overflowing.
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height,
                ),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: contentBuilder,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEnhancedDropdown({
    required List<Map<String, dynamic>> items,
    required String? selectedId,
    required Function(String?) onSelected,
    required Color color,
  }) {
    final dropdownItems = items.map((item) {
      final editionId = item['edition_identifier'] as String?;
      final language = (item['language'] as String? ?? '').trim();
      final displayName =
          (item['translator'] ?? item['scholar'] ?? 'Unknown').toString();
      final label = [
        if (language.isNotEmpty) language,
        displayName,
      ].join(' — ');

      final isSelected = editionId == selectedId;

      return DropdownMenuItem<String>(
        value: editionId,
        child: SizedBox(
          height: 48,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor.withOpacity(0.1),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isSelected ? color : Colors.grey.shade400,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isSelected
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.8),
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSelected)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Icon(
                            Icons.check_circle,
                            size: 16,
                            color: color,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();

    final screenHeight = MediaQuery.of(context).size.height;
    final useModal = screenHeight < 680;

    if (useModal) {
      return InkWell(
        onTap: () async {
          final chosen = await showModalBottomSheet<String>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            builder: (ctx) {
              return DraggableScrollableSheet(
                initialChildSize: 0.5,
                minChildSize: 0.3,
                maxChildSize: 0.9,
                expand: false,
                builder: (c, scrollController) {
                  return ListView.builder(
                    controller: scrollController,
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final editionId = item['edition_identifier'] as String?;
                      final language =
                          (item['language'] as String? ?? '').trim();
                      final displayName =
                          (item['translator'] ?? item['scholar'] ?? 'Unknown')
                              .toString();
                      final label = [
                        if (language.isNotEmpty) language,
                        displayName
                      ].join(' — ');
                      final isSelected = editionId == selectedId;

                      return ListTile(
                        title: Text(label,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: item['language'] != null
                            ? Text(item['language'].toString())
                            : null,
                        trailing: isSelected
                            ? Icon(Icons.check_circle, color: color)
                            : null,
                        onTap: () => Navigator.of(context).pop(editionId),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                      );
                    },
                  );
                },
              );
            },
          );

          if (chosen != null) onSelected(chosen);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: Theme.of(context).dividerColor.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  selectedId != null
                      ? (items.firstWhere(
                                  (i) => i['edition_identifier'] == selectedId,
                                  orElse: () => {})['translator'] ??
                              items.firstWhere(
                                  (i) => i['edition_identifier'] == selectedId,
                                  orElse: () => {})['scholar'] ??
                              'Selected')
                          .toString()
                      : 'Select ${items.isNotEmpty && items.first.containsKey('translator') ? 'translation' : 'tafsir'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.onSurface),
                ),
              ),
              Icon(Icons.arrow_drop_up_rounded, color: color),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.2),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: selectedId,
          icon: Icon(
            Icons.arrow_drop_down_rounded,
            color: color,
          ),
          dropdownColor: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          menuMaxHeight: (() {
            final screenHeight = MediaQuery.of(context).size.height;
            final topPadding = MediaQuery.of(context).padding.top;
            final available = screenHeight - topPadding - kToolbarHeight - 120;
            final safeHeight = available.clamp(240.0, 520.0);
            return safeHeight;
          })(),
          hint: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Select ${items.isNotEmpty && items.first.containsKey('translator') ? 'translation' : 'tafsir'}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ),
          items: dropdownItems,
          onChanged: onSelected,
          selectedItemBuilder: (context) {
            return items.map((item) {
              final displayName =
                  (item['translator'] ?? item['scholar'] ?? '').toString();
              return Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  displayName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList();
          },
        ),
      ),
    );
  }

  Widget _buildContentDisplay({
    required Map<String, dynamic> item,
    required bool isArabic,
  }) {
    final text = item['text'] as String? ?? 'No content available';
    final author = item['translator'] ?? item['scholar'] ?? 'Unknown';
    final language = item['language'] as String? ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).dividerColor.withOpacity(0.1),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person,
                  size: 14,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      author.toString(),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (language.isNotEmpty)
                      Text(
                        language,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.5),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _isExpanded = !_isExpanded),
                icon: Icon(
                  _isExpanded ? Icons.unfold_less : Icons.unfold_more,
                  size: 20,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
                tooltip: _isExpanded ? 'Collapse' : 'Expand',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 300),
          crossFadeState: _isExpanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: Text(
            text,
            style: TextStyle(
              fontSize: 16,
              height: 1.8,
              fontFamily: isArabic ? 'Amiri' : null,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
            textAlign: TextAlign.justify,
          ),
          secondChild: Container(
            height: 100,
            alignment: Alignment.center,
            child: Text(
              'Content collapsed. Tap to expand.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (_isExpanded)
          Row(
            children: [
              const Spacer(),
              TextButton.icon(
                onPressed: () {},
                icon: Icon(
                  Icons.copy,
                  size: 14,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
                label: Text(
                  'Copy',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildEmptyState(String type) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              type == 'translation' ? Icons.translate : Icons.menu_book,
              size: 40,
              color: Theme.of(context).primaryColor.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No ${type}s available',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Download ${type}s to view content for this verse',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DownloadsScreen(),
                ),
              ).then((_) => _loadData());
            },
            icon: const Icon(Icons.download),
            label: Text('Download ${type}s'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Container(
          color: _backgroundColorAnimation.value,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Transform.translate(
                  offset: Offset(0, _slideUpAnimation.value),
                  child: Opacity(
                    opacity: _fadeAnimation.value,
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        );
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).primaryColor,
                  ),
                ),
                Icon(
                  Icons.book,
                  size: 40,
                  color: Theme.of(context).primaryColor.withOpacity(0.7),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading Verse Details',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Surah ${widget.surahNumber}, Verse ${widget.ayahNumber}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 200,
            child: LinearProgressIndicator(
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
              minHeight: 2,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenTitle =
        '${_getSurahName()} ${widget.surahNumber}:${widget.ayahNumber}';

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            collapsedHeight: 60,
            floating: true,
            pinned: true,
            backgroundColor: Theme.of(context).colorScheme.surface,
            elevation: 0,
            title: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _isLoading ? 0 : 1,
              child: Text(
                screenTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            centerTitle: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).primaryColor.withOpacity(0.1),
                      Theme.of(context).primaryColor.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                ),
                child: Center(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: _isLoading ? 0 : 1,
                    child: Text(
                      'Verse ${widget.ayahNumber}',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).primaryColor.withOpacity(0.8),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
              ),
            ],
          ),
          if (_isLoading)
            SliverFillRemaining(
              child: _buildLoadingState(),
            )
          else
            SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 16),
                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _slideUpAnimation.value),
                      child: Opacity(
                        opacity: _fadeAnimation.value,
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    children: [
                      _buildArabicVerseCard(),
                      const SizedBox(height: 8),
                      _buildContentSection(
                        title: 'Translation',
                        icon: Icons.translate,
                        color: Colors.green,
                        items: _allTranslations,
                        selectedId: _selectedTranslationId,
                        onSelected: (id) async {
                          setState(() => _selectedTranslationId = id);
                          if (id != null) {
                            final intId = int.tryParse(id);
                            if (intId != null) {
                              await _translationService
                                  .setSelectedTranslationId(intId);
                            }
                          }
                        },
                        contentBuilder: _selectedTranslationId != null &&
                                _allTranslations.isNotEmpty
                            ? _buildContentDisplay(
                                item: _allTranslations.firstWhere(
                                  (t) =>
                                      t['edition_identifier'] ==
                                      _selectedTranslationId,
                                  orElse: () => {},
                                ),
                                isArabic: false,
                              )
                            : _buildEmptyState('translation'),
                      ),
                      _buildContentSection(
                        title: 'Tafsir (Interpretation)',
                        icon: Icons.menu_book,
                        color: Colors.blue,
                        items: _allTafsirs,
                        selectedId: _selectedTafsirId,
                        onSelected: (id) async {
                          setState(() => _selectedTafsirId = id);
                          if (id != null) {
                            final intId = int.tryParse(id);
                            if (intId != null) {
                              await _tafsirService.setSelectedTafsirId(intId);
                            }
                          }
                        },
                        contentBuilder:
                            _selectedTafsirId != null && _allTafsirs.isNotEmpty
                                ? _buildContentDisplay(
                                    item: _allTafsirs.firstWhere(
                                      (t) =>
                                          t['edition_identifier'] ==
                                          _selectedTafsirId,
                                      orElse: () => {},
                                    ),
                                    isArabic: (_allTafsirs.firstWhere(
                                      (t) =>
                                          t['edition_identifier'] ==
                                          _selectedTafsirId,
                                      orElse: () => {'language': ''},
                                    )['language'] as String)
                                        .toLowerCase()
                                        .contains('arabic'),
                                  )
                                : _buildEmptyState('tafsir'),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ]),
            ),
        ],
      ),
      // floatingActionButton:
      //     _allTranslations.isNotEmpty || _allTafsirs.isNotEmpty
      //         ? FloatingActionButton.extended(
      //             onPressed: () {
      //               _pageController.animateToPage(
      //                 (_currentPage + 1) % 3,
      //                 duration: const Duration(milliseconds: 500),
      //                 curve: Curves.easeInOut,
      //               );
      //             },
      //             icon: const Icon(Icons.swap_horiz),
      //             label: const Text('Switch View'),
      //             backgroundColor: Theme.of(context).primaryColor,
      //             foregroundColor: Colors.white,
      //           )
      //         : null,
    );
  }
}
