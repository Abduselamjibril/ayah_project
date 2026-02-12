import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:quran_app/core/services/tafsir_service.dart';
import 'package:quran_app/core/quran/data/suwar.dart';
import 'package:quran_app/core/quran/qcf_quran.dart';
import 'package:quran_app/features/downloads/downloads_screen.dart';
import 'package:quran_app/core/i18n/app_localizations.dart';
import 'package:quran_app/core/utils/localization_helper.dart';
import 'package:quran_app/features/mushaf/widgets/share_options_sheet.dart';
import 'package:quran_app/app/app.dart';
import 'package:quran_app/features/share/services/share_service.dart';
import 'package:quran_app/features/mushaf/widgets/verse_options_sheet.dart';
import 'package:quran_app/data/models/tafsir_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final TafsirService _tafsirService = TafsirService.instance;

  List<Map<String, dynamic>> _allTafsirs = [];
  List<TafsirEdition> _availableTafsirs = [];
  List<String> _downloadedTafsirIds = [];
  List<String> _addedTafsirOrder = [];
  final Map<String, GlobalKey> _tafsirCardKeys = {};
  final Map<String, double> _tafsirDownloadProgress = {};
  final Set<String> _tafsirDownloading = {};
  StateSetter? _librarySheetSetState;
  bool _isLoading = true;
  int _currentSurah = 0;
  int _currentVerse = 0;

  static const String _textFontFamilyKey = 'tafsir_text_font_family';
  static const String _textFontLabelKey = 'tafsir_text_font_label';
  static const String _textSizeIndexKey = 'tafsir_text_size_index';
  static const String _tafsirLibraryKey = 'tafsir_library_order';

  static const int _textSizeDefaultIndex = 3;
  static const List<double> _arabicTextSizes = [20, 21, 22, 24, 26, 28, 30];
  static const List<double> _tafsirTextSizes = [11, 12, 13, 14, 15, 16, 17];

  String _selectedFontLabel = 'Default';
  String _selectedFontFamily = 'Amiri';
  int _textSizeIndex = _textSizeDefaultIndex;

  static const List<_FontOption> _fontOptions = [
    _FontOption(label: 'Default', family: 'Amiri'),
    _FontOption(label: 'Default Rounded', family: 'Arial Rounded MT Bold'),
    _FontOption(label: 'النسخ', family: 'Amiri'),
    _FontOption(label: 'كتاب', family: 'Times New Roman'),
    _FontOption(label: 'New York', family: 'Georgia'),
  ];

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideUpAnimation;
  late Animation<Color?> _backgroundColorAnimation;


  @override
  void initState() {
    super.initState();

    _currentSurah = widget.surahNumber;
    _currentVerse = widget.ayahNumber;

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
    _loadTextSettings();
    _loadLibraryData().then((_) {
      if (mounted) _maybeOpenAddBooks();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
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
      final tafsirs = await _tafsirService.getAllTafsirs(
        surahNumber: _currentSurah,
        ayahNumber: _currentVerse,
      );

      setState(() {
        _allTafsirs = tafsirs;
        _isLoading = false;
      });

      _animationController.forward(from: 0);
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error loading data: $e');
    }
  }

  Future<void> _maybeOpenAddBooks() async {
    if (_addedTafsirOrder.isNotEmpty) return;
    await _ensureLibraryData();
    if (!mounted) return;
    _openAddBooksSheet();
  }

  Future<void> _loadLibraryData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedOrder = prefs.getStringList(_tafsirLibraryKey) ?? [];

    final available = await _tafsirService.getAvailableTafsirs();
    final downloaded = await _tafsirService.getDownloadedTafsirs();

    setState(() {
      _availableTafsirs = available;
      _downloadedTafsirIds = downloaded;
      _addedTafsirOrder = savedOrder;
    });
  }

  Future<void> _loadTextSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIndex = prefs.getInt(_textSizeIndexKey) ?? 1;
    final savedLabel = prefs.getString(_textFontLabelKey);
    final savedFamily = prefs.getString(_textFontFamilyKey);
    final fallback = _fontOptions.first;

    final match = savedLabel == null
        ? null
        : _fontOptions.where((o) => o.label == savedLabel).toList();
    final resolved = match != null && match.isNotEmpty ? match.first : fallback;

    setState(() {
      _textSizeIndex = savedIndex.clamp(0, _arabicTextSizes.length - 1);
      _selectedFontLabel = savedLabel ?? resolved.label;
      _selectedFontFamily = savedFamily ?? resolved.family;
    });
  }

  Future<void> _saveTextSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_textFontLabelKey, _selectedFontLabel);
    await prefs.setString(_textFontFamilyKey, _selectedFontFamily);
    await prefs.setInt(_textSizeIndexKey, _textSizeIndex);
  }

  double get _arabicFontSize {
    return _arabicTextSizes[_textSizeIndex];
  }

  double get _tafsirFontSize {
    return _tafsirTextSizes[_textSizeIndex];
  }

  void _decreaseTextSize() {
    if (_textSizeIndex == 0) return;
    setState(() => _textSizeIndex -= 1);
    _saveTextSettings();
  }

  void _increaseTextSize() {
    if (_textSizeIndex >= _arabicTextSizes.length - 1) return;
    setState(() => _textSizeIndex += 1);
    _saveTextSettings();
  }

  Future<void> _saveAddedTafsirs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_tafsirLibraryKey, _addedTafsirOrder);
  }

  String _getArabicText() {
    try {
      return getVerse(
        _currentSurah,
        _currentVerse,
        verseEndSymbol: true,
      );
    } catch (e) {
      return '';
    }
  }

  String _getSurahName() {
    return getBilingualSurahName(context, _currentSurah);
  }

  String _formatLabel(String value, String fallback) {
    final raw = value.isEmpty ? fallback : value;
    final normalized = raw.replaceAll('_', ' ').trim();
    if (normalized.isEmpty) return fallback;
    return normalized
        .split(RegExp(r'\s+'))
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1);
        })
        .join(' ');
  }

  int _getAyahCount(int surahId) {
    if (surahId < 1 || surahId > surah.length) return 0;
    final data = surah[surahId - 1] as Map<String, dynamic>;
    return (data['aya'] as num?)?.toInt() ?? 0;
  }

  TafsirEdition? _findEditionById(String id) {
    final parsed = int.tryParse(id);
    if (parsed == null) return null;
    try {
      return _availableTafsirs.firstWhere((e) => e.id == parsed);
    } catch (_) {
      return null;
    }
  }

  String _getEditionLabel(String id) {
    final edition = _findEditionById(id);
    if (edition == null) return id;
    return edition.name;
  }

  String _getEditionSubtitle(String id) {
    final edition = _findEditionById(id);
    if (edition == null) return '';
    if (edition.languageName.isEmpty && edition.authorName.isEmpty) return '';
    final parts = <String>[];
    if (edition.languageName.isNotEmpty) parts.add(edition.languageName);
    if (edition.authorName.isNotEmpty) parts.add(edition.authorName);
    return parts.join(' • ');
  }

  List<Map<String, dynamic>> _getOrderedTafsirsForDisplay() {
    if (_addedTafsirOrder.isEmpty) return [];
    final mapById = <String, Map<String, dynamic>>{};
    for (final item in _allTafsirs) {
      final id = item['edition_identifier']?.toString();
      if (id != null) mapById[id] = item;
    }
    final ordered = <Map<String, dynamic>>[];
    for (final id in _addedTafsirOrder) {
      final item = mapById[id];
      if (item != null) ordered.add(item);
    }
    if (ordered.isNotEmpty) return ordered;
    return _allTafsirs;
  }

  void _goToVerse({required bool next}) {
    var surahId = _currentSurah;
    var verseId = _currentVerse;

    if (next) {
      final ayahCount = _getAyahCount(surahId);
      if (verseId < ayahCount) {
        verseId += 1;
      } else if (surahId < surah.length) {
        surahId += 1;
        verseId = 1;
      } else {
        return;
      }
    } else {
      if (verseId > 1) {
        verseId -= 1;
      } else if (surahId > 1) {
        surahId -= 1;
        verseId = _getAyahCount(surahId);
      } else {
        return;
      }
    }

    setState(() {
      _currentSurah = surahId;
      _currentVerse = verseId;
    });

    _loadData();
  }

  Future<void> _openVersePicker() async {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final cardBg = isLight
        ? theme.scaffoldBackgroundColor
        : theme.colorScheme.onSurface.withOpacity(0.08);

    int tempSurah = _currentSurah;
    int tempVerse = _currentVerse;

    final surahController = FixedExtentScrollController(
      initialItem: (_currentSurah - 1).clamp(0, surah.length - 1),
    );
    final verseController = FixedExtentScrollController(
      initialItem: (_currentVerse - 1).clamp(0, _getAyahCount(_currentSurah) - 1),
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final maxVerse = _getAyahCount(tempSurah).clamp(1, 300);
            if (tempVerse > maxVerse) tempVerse = maxVerse;

            return FractionallySizedBox(
              heightFactor: 0.45,
              alignment: Alignment.bottomCenter,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Text(
                      'Select Verse',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: CupertinoPicker(
                                scrollController: surahController,
                                itemExtent: 40,
                                onSelectedItemChanged: (index) {
                                  setSheetState(() {
                                    tempSurah = index + 1;
                                    final newMax = _getAyahCount(tempSurah).clamp(1, 300);
                                    if (tempVerse > newMax) {
                                      tempVerse = newMax;
                                      verseController.jumpToItem(newMax - 1);
                                    }
                                  });
                                },
                                children: List.generate(surah.length, (index) {
                                  final surahId = index + 1;
                                  final name = getBilingualSurahName(context, surahId);
                                  return Center(
                                    child: Text(
                                      name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                            Expanded(
                              child: CupertinoPicker(
                                scrollController: verseController,
                                itemExtent: 40,
                                onSelectedItemChanged: (index) {
                                  setSheetState(() {
                                    tempVerse = index + 1;
                                  });
                                },
                                children: List.generate(maxVerse, (index) {
                                  return Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: TextButton(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          setState(() {
                            _currentSurah = tempSurah;
                            _currentVerse = tempVerse;
                          });
                          _loadData();
                        },
                        child: Text(
                          'Done',
                          style: TextStyle(
                            color: BrandColors.accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildArabicVerseCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        children: [
          Text(
            _getArabicText(),
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontSize: _arabicFontSize,
              height: 1.9,
              fontFamily: _selectedFontFamily,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTafsirCard(Map<String, dynamic> item) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final accent = BrandColors.accent;
    final editionId = item['edition_identifier']?.toString();
    final cardKey = editionId == null
      ? null
      : _tafsirCardKeys.putIfAbsent(editionId, () => GlobalKey());
    final title = (item['scholar'] ?? item['translator'] ?? 'Unknown')
        .toString()
        .toUpperCase();
    final language = (item['language'] ?? '').toString();
    final text = (item['text'] ?? '').toString();
    final cardBg = isLight
        ? theme.scaffoldBackgroundColor
        : theme.colorScheme.onSurface.withOpacity(0.08);

    return Container(
      key: cardKey,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFamily: _selectedFontFamily,
                    fontSize: _tafsirFontSize,
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ),
              Builder(
                builder: (iconContext) {
                  return IconButton(
                    onPressed: () => _showShareMenu(iconContext),
                    icon: const Icon(Icons.more_horiz),
                    color: accent,
                  );
                },
              ),
            ],
          ),
          if (language.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              language,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.45),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            text,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.5,
              fontFamily: _selectedFontFamily,
              fontSize: _tafsirFontSize,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openTextSettingsSheet() async {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final cardBg = isLight
        ? theme.scaffoldBackgroundColor
        : theme.colorScheme.onSurface.withOpacity(0.08);
    final dividerColor = theme.dividerColor.withOpacity(0.12);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.55,
          alignment: Alignment.bottomCenter,
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.dividerColor.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const SizedBox(width: 32),
                      const Expanded(
                        child: Center(
                          child: Text(
                            'Text Settings',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close),
                        color: BrandColors.accent,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: [
                      _buildSettingsRow(
                        label: 'Font',
                        value: _selectedFontLabel,
                        cardBg: cardBg,
                        dividerColor: dividerColor,
                        onTap: _openFontSettingsSheet,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Text Size',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: dividerColor),
                        ),
                        child: Row(
                          children: [
                            _buildTextSizeOption(
                              label: 'A',
                              size: 16,
                              selected: _textSizeIndex < _textSizeDefaultIndex,
                              onTap: _decreaseTextSize,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Center(
                                child: InkWell(
                                  onTap: () {
                                    setState(
                                        () => _textSizeIndex = _textSizeDefaultIndex);
                                    _saveTextSettings();
                                  },
                                  borderRadius: BorderRadius.circular(18),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 6),
                                    child: Text(
                                      'Default',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildTextSizeOption(
                              label: 'A',
                              size: 22,
                              selected: _textSizeIndex > _textSizeDefaultIndex,
                              onTap: _increaseTextSize,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettingsRow({
    required String label,
    required String value,
    required Color cardBg,
    required Color dividerColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: dividerColor),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openFontSettingsSheet() async {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final cardBg = isLight
        ? theme.scaffoldBackgroundColor
        : theme.colorScheme.onSurface.withOpacity(0.08);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return FractionallySizedBox(
              heightFactor: 0.65,
              alignment: Alignment.bottomCenter,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.dividerColor.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: const Icon(Icons.arrow_back_ios_new),
                            color: BrandColors.accent,
                          ),
                          const Expanded(
                            child: Center(
                              child: Text(
                                'Font',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: const Icon(Icons.close),
                            color: BrandColors.accent,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemBuilder: (context, index) {
                          final option = _fontOptions[index];
                          final selected = option.label == _selectedFontLabel;
                          return InkWell(
                            onTap: () {
                              setState(() {
                                _selectedFontLabel = option.label;
                                _selectedFontFamily = option.family;
                              });
                              setSheetState(() {});
                              _saveTextSettings();
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      option.label,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontFamily: option.family,
                                      ),
                                    ),
                                  ),
                                  if (selected)
                                    Icon(
                                      Icons.check,
                                      color: BrandColors.accent,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemCount: _fontOptions.length,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTextSizeOption({
    required String label,
    required double size,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? BrandColors.accent.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: size,
            color: selected
                ? BrandColors.accent
                : theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ),
    );
  }

  Future<void> _showShareMenu(BuildContext iconContext) async {
    final renderBox = iconContext.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final overlay = Overlay.of(iconContext).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    final accent = BrandColors.accent;

    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        renderBox.localToGlobal(Offset.zero, ancestor: overlay),
        renderBox.localToGlobal(renderBox.size.bottomRight(Offset.zero),
            ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    final selected = await showMenu<String>(
      context: context,
      position: position,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        PopupMenuItem<String>(
          value: 'image',
          child: Row(
            children: [
              Icon(Icons.image_outlined, color: accent, size: 18),
              const SizedBox(width: 10),
              Text(
                AppLocalizations.of(context)?.translate('share_image') ??
                    'Share Image',
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'text',
          child: Row(
            children: [
              Icon(Icons.text_snippet_outlined, color: accent, size: 18),
              const SizedBox(width: 10),
              Text(
                AppLocalizations.of(context)?.translate('share_text') ??
                    'Share Text',
              ),
            ],
          ),
        ),
      ],
    );

    if (selected == 'image') {
      try {
        final shareTheme = ShareService.resolveShareCardTheme(context);
        await ShareService.instance.shareVerseImage(
          surahNumber: _currentSurah,
          ayahNumber: _currentVerse,
          background: shareTheme.background,
          isDark: shareTheme.isDark,
          frameAsset: shareTheme.frameAsset,
          showSurahName: false,
          showPageNumber: true,
          showBadge: true,
          size: 1080,
          pixelRatio: 2.5,
        );
      } catch (e) {
        debugPrint('Share image failed: $e');
      }
    } else if (selected == 'text') {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (shareContext) => ShareOptionsSheet(
          surah: _currentSurah,
          verse: _currentVerse,
        ),
      );
    }
  }

  List<PopupMenuEntry<String>> _buildLibraryMenuItems() {
    final accent = BrandColors.accent;
    final dividerColor = Colors.black.withOpacity(0.12);
    final items = <PopupMenuEntry<String>>[];

    if (_addedTafsirOrder.isNotEmpty) {
      for (var i = 0; i < _addedTafsirOrder.length; i++) {
        final id = _addedTafsirOrder[i];
        items.add(
          PopupMenuItem<String>(
            value: 'book:$id',
            child: Row(
              children: [
                Icon(Icons.menu_book_outlined, color: accent, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(_getEditionLabel(id))),
              ],
            ),
          ),
        );

        if (i != _addedTafsirOrder.length - 1) {
          items.add(
            PopupMenuItem<String>(
              enabled: false,
              height: 8,
              child: Divider(height: 1, thickness: 1, color: dividerColor),
            ),
          );
        }
      }

      items.add(
        PopupMenuItem<String>(
          enabled: false,
          height: 14,
          child: Divider(height: 2, thickness: 2, color: dividerColor),
        ),
      );
    }

    items.add(
      PopupMenuItem<String>(
        value: 'add_books',
        child: Row(
          children: [
            const Icon(Icons.add, color: Colors.green, size: 18),
            const SizedBox(width: 10),
            Text(
              _formatLabel(
                AppLocalizations.of(context)?.translate('add_books') ?? '',
                'Add Books',
              ),
            ),
          ],
        ),
      ),
    );

    return items;
  }

  Future<void> _showLibraryMenuAtPosition(RelativeRect position) async {
    final selected = await showMenu<String>(
      context: context,
      position: position,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: _buildLibraryMenuItems(),
    );

    if (selected == 'add_books') {
      _openAddBooksSheet();
    } else if (selected != null && selected.startsWith('book:')) {
      final id = selected.replaceFirst('book:', '');
      final key = _tafsirCardKeys[id];
      final cardContext = key?.currentContext;
      if (cardContext != null) {
        await Scrollable.ensureVisible(
          cardContext,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    }
  }

  Future<void> _openLibraryMenu(BuildContext iconContext) async {
    if (_addedTafsirOrder.isEmpty) {
      await _ensureLibraryData();
      _openAddBooksSheet();
      return;
    }
    final renderBox = iconContext.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final overlay = Overlay.of(iconContext).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    final rect = Rect.fromPoints(
      renderBox.localToGlobal(Offset.zero, ancestor: overlay),
      renderBox.localToGlobal(
        renderBox.size.bottomRight(Offset.zero),
        ancestor: overlay,
      ),
    );
    final top = rect.top - 6;
    final position = RelativeRect.fromLTRB(
      rect.left,
      top < 0 ? 0 : top,
      overlay.size.width - rect.right,
      overlay.size.height - rect.top,
    );

    await _showLibraryMenuAtPosition(position);
  }

  Future<void> _ensureLibraryData() async {
    if (_availableTafsirs.isNotEmpty) return;
    await _loadLibraryData();
  }

  void _openLibraryMenuFromTopRight() {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    final right = 16.0;
    final top = 56.0;
    final position = RelativeRect.fromLTRB(
      overlay.size.width - right,
      top,
      right,
      overlay.size.height - top,
    );
    _showLibraryMenuAtPosition(position);
  }

  void _openAddBooksSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            _librarySheetSetState = setSheetState;
            final theme = Theme.of(context);
            final isLight = theme.brightness == Brightness.light;
            final cardBg = isLight
                ? theme.scaffoldBackgroundColor
                : theme.colorScheme.onSurface.withOpacity(0.08);
            final dividerColor = theme.dividerColor.withOpacity(0.15);

            if (_availableTafsirs.isEmpty) {
              return FractionallySizedBox(
                heightFactor: 0.9,
                alignment: Alignment.bottomCenter,
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
              );
            }

            final addedIds = _addedTafsirOrder
                .where((id) => _downloadedTafsirIds.contains(id))
                .toList();
            final downloadedNotAdded = _downloadedTafsirIds
                .where((id) => !_addedTafsirOrder.contains(id))
                .toList();
            final availableNotDownloaded = _availableTafsirs
                .where((e) => !_downloadedTafsirIds.contains(e.id.toString()))
                .toList();

            final downloadedByLang = <String, List<TafsirEdition>>{};
            for (final id in downloadedNotAdded) {
              final edition = _findEditionById(id);
              if (edition == null) continue;
              downloadedByLang.putIfAbsent(edition.languageName, () => []);
              downloadedByLang[edition.languageName]!.add(edition);
            }

            final availableByLang = <String, List<TafsirEdition>>{};
            for (final edition in availableNotDownloaded) {
              availableByLang.putIfAbsent(edition.languageName, () => []);
              availableByLang[edition.languageName]!.add(edition);
            }

            List<String> sortedKeys(Map<String, List<TafsirEdition>> map) {
              final keys = map.keys.toList()..sort();
              return keys;
            }

            return FractionallySizedBox(
              heightFactor: 0.9,
              alignment: Alignment.bottomCenter,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.dividerColor.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          const SizedBox(width: 32),
                          Expanded(
                            child: Center(
                              child: Text(
                                _formatLabel(
                                  AppLocalizations.of(context)
                                          ?.translate('add_books') ??
                                      '',
                                  'Add Books',
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: const Icon(Icons.arrow_back_ios_new),
                            color: BrandColors.accent,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        children: [
                          AnimatedSize(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              switchInCurve: Curves.easeOut,
                              switchOutCurve: Curves.easeIn,
                              transitionBuilder: (child, animation) =>
                                  SizeTransition(sizeFactor: animation, child: child),
                              child: addedIds.isEmpty
                                  ? const SizedBox.shrink()
                                  : Column(
                                      key: const ValueKey('added_section'),
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildLibrarySectionTitle(
                                          _formatLabel(
                                            AppLocalizations.of(context)
                                                    ?.translate('added') ??
                                                '',
                                            'Added',
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        _buildAddedListCard(
                                          ids: addedIds,
                                          cardBg: cardBg,
                                          dividerColor: dividerColor,
                                        ),
                                        const SizedBox(height: 16),
                                      ],
                                    ),
                            ),
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              switchInCurve: Curves.easeOut,
                              switchOutCurve: Curves.easeIn,
                              transitionBuilder: (child, animation) =>
                                  SizeTransition(sizeFactor: animation, child: child),
                              child: downloadedNotAdded.isEmpty
                                  ? const SizedBox.shrink()
                                  : Column(
                                      key: const ValueKey('downloaded_section'),
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildLibrarySectionTitle(
                                          _formatLabel(
                                            AppLocalizations.of(context)
                                                    ?.translate('downloaded') ??
                                                '',
                                            'Downloaded',
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        for (final lang in sortedKeys(downloadedByLang)) ...[
                                          Text(
                                            lang,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: theme.colorScheme.onSurface,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          _buildLibraryGroupCard(
                                            cardBg: cardBg,
                                            dividerColor: dividerColor,
                                            children: downloadedByLang[lang]!
                                                .map((edition) => _buildTafsirAddRow(
                                                      edition: edition,
                                                      added: false,
                                                      onTap: () => _addTafsir(edition.id.toString()),
                                                    ))
                                                .toList(),
                                          ),
                                          const SizedBox(height: 16),
                                        ],
                                      ],
                                    ),
                            ),
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              switchInCurve: Curves.easeOut,
                              switchOutCurve: Curves.easeIn,
                              transitionBuilder: (child, animation) =>
                                  SizeTransition(sizeFactor: animation, child: child),
                              child: availableNotDownloaded.isEmpty
                                  ? const SizedBox.shrink()
                                  : Column(
                                      key: const ValueKey('available_section'),
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildLibrarySectionTitle(
                                          _formatLabel(
                                            AppLocalizations.of(context)
                                                    ?.translate('available') ??
                                                '',
                                            'Available',
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        for (final lang in sortedKeys(availableByLang)) ...[
                                          Text(
                                            lang,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: theme.colorScheme.onSurface,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          _buildLibraryGroupCard(
                                            cardBg: cardBg,
                                            dividerColor: dividerColor,
                                            children: availableByLang[lang]!
                                                .map((edition) => _buildTafsirDownloadRow(
                                                      edition: edition,
                                                    ))
                                                .toList(),
                                          ),
                                          const SizedBox(height: 16),
                                        ],
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() => _librarySheetSetState = null);
  }

  Widget _buildLibrarySectionTitle(String text) {
    return Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 13,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
      ),
    );
  }

  Widget _buildLibraryGroupCard({
    required Color cardBg,
    required Color dividerColor,
    required List<Widget> children,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: dividerColor),
        ),
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              children[i],
              if (i != children.length - 1)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Divider(height: 1, thickness: 1, color: dividerColor),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTafsirAddRow({
    required TafsirEdition edition,
    required bool added,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            _buildCircleIcon(
              icon: added ? Icons.remove : Icons.add,
              color: added ? Colors.redAccent : Colors.green,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    edition.name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    edition.authorName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTafsirDownloadRow({required TafsirEdition edition}) {
    final theme = Theme.of(context);
    final id = edition.id.toString();
    final isDownloading = _tafsirDownloading.contains(id);
    final progress = _tafsirDownloadProgress[id] ?? 0.0;

    return InkWell(
      onTap: isDownloading ? null : () => _downloadTafsirEdition(edition),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            if (isDownloading)
              _buildProgressIndicator(progress)
            else
              _buildCircleIcon(
                icon: Icons.download_for_offline,
                color: BrandColors.accent,
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    edition.name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    edition.authorName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleIcon({required IconData icon, required Color color}) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
      child: Icon(icon, size: 16, color: color),
    );
  }

  Widget _buildProgressIndicator(double progress) {
    final percent = (progress * 100).round();
    return SizedBox(
      width: 28,
      height: 28,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 2.5,
            color: BrandColors.accent,
            backgroundColor: Colors.black.withOpacity(0.08),
          ),
          Text(
            '$percent%',
            style: const TextStyle(fontSize: 7, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildAddedListCard({
    required List<String> ids,
    required Color cardBg,
    required Color dividerColor,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: dividerColor),
        ),
        child: ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: ids.length,
          onReorder: (oldIndex, newIndex) {
            _reorderAddedTafsirs(oldIndex, newIndex);
          },
          itemBuilder: (context, index) {
            final id = ids[index];
            return Container(
              key: ValueKey('added_$id'),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                border: index == ids.length - 1
                    ? null
                    : Border(
                        bottom: BorderSide(color: dividerColor, width: 1),
                      ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _removeTafsir(id),
                    child: _buildCircleIcon(
                      icon: Icons.remove,
                      color: Colors.redAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getEditionLabel(id),
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        if (_getEditionSubtitle(id).isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            _getEditionSubtitle(id),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.6),
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  ReorderableDragStartListener(
                    index: index,
                    child: Icon(
                      Icons.drag_handle,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _reorderAddedTafsirs(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    setState(() {
      final item = _addedTafsirOrder.removeAt(oldIndex);
      _addedTafsirOrder.insert(newIndex, item);
    });
    _librarySheetSetState?.call(() {});
    _saveAddedTafsirs();
  }

  void _addTafsir(String id) {
    if (_addedTafsirOrder.contains(id)) return;
    setState(() {
      _addedTafsirOrder.add(id);
    });
    _librarySheetSetState?.call(() {});
    _saveAddedTafsirs();
  }

  void _removeTafsir(String id) {
    setState(() {
      _addedTafsirOrder.remove(id);
    });
    _librarySheetSetState?.call(() {});
    _saveAddedTafsirs();
  }

  Future<void> _downloadTafsirEdition(TafsirEdition edition) async {
    final id = edition.id.toString();
    if (_tafsirDownloading.contains(id)) return;

    setState(() {
      _tafsirDownloading.add(id);
      _tafsirDownloadProgress[id] = 0.0;
    });
    _librarySheetSetState?.call(() {});

    bool ok = false;
    try {
      ok = await _tafsirService.downloadTafsir(
        edition,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _tafsirDownloadProgress[id] = progress.clamp(0.0, 1.0);
          });
          _librarySheetSetState?.call(() {});
        },
      );

      if (ok) {
        setState(() {
          if (!_downloadedTafsirIds.contains(id)) {
            _downloadedTafsirIds.add(id);
          }
        });
      }
    } finally {
      setState(() {
        _tafsirDownloading.remove(id);
        _tafsirDownloadProgress.remove(id);
      });
      _librarySheetSetState?.call(() {});
    }
  }

  Widget _buildSheetHeader(String title) {
    final accent = BrandColors.accent;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _backToVerseOptions,
                icon: const Icon(Icons.arrow_back_ios_new),
                color: accent,
              ),
              Expanded(
                child: Center(
                  child: Text(
                    'Tafsir',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                color: accent,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 12, bottom: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _backToVerseOptions() {
    Navigator.pop(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => VerseOptionsSheet(
        surah: _currentSurah,
        verse: _currentVerse,
      ),
    );
  }

  Widget _buildSheetHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(context).dividerColor.withOpacity(0.5),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  Widget _buildBottomBar(String title) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final accent = BrandColors.accent;
    final barBg = isLight
        ? theme.scaffoldBackgroundColor
        : theme.colorScheme.onSurface.withOpacity(0.08);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: barBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor.withOpacity(0.12)),
        ),
        child: Row(
          children: [
            Builder(
              builder: (iconContext) {
                return IconButton(
                  onPressed: () => _openLibraryMenu(iconContext),
                  icon: const Icon(Icons.library_books_outlined),
                  color: accent,
                );
              },
            ),
            const SizedBox(width: 6),
            IconButton(
              onPressed: () => _goToVerse(next: true),
              icon: const Icon(Icons.chevron_left_rounded),
              color: accent,
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  onTap: _openVersePicker,
                  borderRadius: BorderRadius.circular(12),
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: () => _goToVerse(next: false),
              icon: const Icon(Icons.chevron_right_rounded),
              color: accent,
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: _openTextSettingsSheet,
              borderRadius: BorderRadius.circular(17),
              child: Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withOpacity(0.06),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  'Aa',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
            (AppLocalizations.of(context)?.translate('no_types_available') ??
                    'No {type}s available')
                .replaceAll('{type}', type),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            (AppLocalizations.of(context)
                        ?.translate('download_types_to_view') ??
                    'Download {type}s to view content for this verse')
                .replaceAll('{type}', type),
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
            label: Text(
              (AppLocalizations.of(context)?.translate('download_types') ??
                      'Download {type}s')
                  .replaceAll('{type}', type),
            ),
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
    return Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(BrandColors.accent),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenTitle =
        '${_getSurahName()} ${_currentSurah}:${_currentVerse}';

    return SafeArea(
      top: false,
      bottom: false,
      child: FractionallySizedBox(
        heightFactor: 0.9,
        alignment: Alignment.bottomCenter,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              _buildSheetHandle(),
              _buildSheetHeader(screenTitle),
              Expanded(
                child: _addedTafsirOrder.isEmpty
                    ? const SizedBox.shrink()
                    : _isLoading
                        ? _buildLoadingState()
                        : SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            child: Column(
                              children: [
                                _buildArabicVerseCard(),
                                const SizedBox(height: 16),
                                for (final item
                                    in _getOrderedTafsirsForDisplay())
                                  _buildTafsirCard(item),
                              ],
                            ),
                          ),
              ),
              _buildBottomBar(screenTitle),
            ],
          ),
        ),
      ),
    );
  }
}

class _FontOption {
  final String label;
  final String family;
  const _FontOption({required this.label, required this.family});
}
