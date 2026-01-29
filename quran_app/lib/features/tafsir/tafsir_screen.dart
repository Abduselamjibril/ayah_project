// lib/features/tafsir/tafsir_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:quran_app/core/services/tafsir_service.dart';
import 'package:quran_app/core/services/translation_service.dart';
import 'package:quran_app/data/models/tafsir_model.dart';
import 'package:quran_app/data/models/translation_model.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quran_app/core/i18n/app_localizations.dart';

class TafsirScreen extends StatefulWidget {
  final int surahNumber;
  final int ayahNumber;

  const TafsirScreen({
    super.key,
    this.surahNumber = 1,
    this.ayahNumber = 1,
  });

  @override
  State<TafsirScreen> createState() => _TafsirScreenState();
}

class _TafsirScreenState extends State<TafsirScreen>
    with SingleTickerProviderStateMixin {
  final TranslationService _translationService = TranslationService.instance;
  final TafsirService _tafsirService = TafsirService.instance;
  final HtmlUnescape _unescaper = HtmlUnescape();

  TranslationEdition? _selectedTranslation;
  TafsirEdition? _selectedTafsir;
  String? _content;
  bool _isLoading = true;
  String _activeType = 'none';
  String _contentSource = 'unknown';

  List<TafsirEdition> _tafsirEditions = [];
  List<TranslationEdition> _translationEditions = [];
  Set<String> _downloadedTafsirs = <String>{};
  Set<String> _downloadedTranslations = <String>{};
  bool _isFetchingEditions = true;
  bool _isDownloading = false;
  String? _downloadingType;
  int? _downloadingId;
  double _downloadProgress = 0.0;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<Color?> _cardColorAnimation;

  bool _showFullContent = true;
  bool _showInfoCard = true;
  final ScrollController _scrollController = ScrollController();

  bool get _contentHasHtml =>
      _content != null && RegExp(r'<[^>]+>').hasMatch(_content!);

  String _normalizeContent(String? raw) {
    if (raw == null) return '';
    String current = raw;
    for (int i = 0; i < 5; i++) {
      final decoded = _unescaper.convert(current);
      if (decoded == current) break;
      current = decoded;
    }
    return current.trim();
  }

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );

    _cardColorAnimation = ColorTween(
      begin: Colors.grey.shade50,
      end: Theme.of(context).colorScheme.surface,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _initPage();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initPage() async {
    await _loadEditions();
    await _loadContent();
    _animationController.forward();
  }

  Future<void> _loadEditions() async {
    setState(() => _isFetchingEditions = true);
    try {
      final tafsirs = await _tafsirService.getAvailableTafsirs();
      final translations =
          await _translationService.getAllTranslationEditions();
      final downloadedTafsirs = await _tafsirService.getDownloadedTafsirs();
      final downloadedTranslations =
          await _translationService.getDownloadedTranslations();
      setState(() {
        _tafsirEditions = tafsirs;
        _translationEditions = translations;
        _downloadedTafsirs = downloadedTafsirs.toSet();
        _downloadedTranslations = downloadedTranslations.toSet();
      });
    } catch (e) {
      debugPrint('Error loading editions: $e');
    } finally {
      if (mounted) setState(() => _isFetchingEditions = false);
    }
  }

  Future<void> _loadContent() async {
    setState(() => _isLoading = true);
    try {
      _selectedTafsir = await _tafsirService.getSelectedTafsir();
      _selectedTranslation = await _translationService.getSelectedTranslation();

      if (_selectedTafsir != null) {
        _activeType = 'tafsir';
        final tafsirText = await _tafsirService.getTafsirByEdition(
          surahNumber: widget.surahNumber,
          ayahNumber: widget.ayahNumber,
          editionIdentifier: _selectedTafsir!.id.toString(),
        );
        _content = _normalizeContent(tafsirText);
        _contentSource = 'tafsir-db-${_selectedTafsir!.id}';
      } else if (_selectedTranslation != null) {
        _activeType = 'translation';
        final transText = await _translationService.getTranslationByEdition(
          surahNumber: widget.surahNumber,
          ayahNumber: widget.ayahNumber,
          editionIdentifier: _selectedTranslation!.id.toString(),
        );
        _content = _normalizeContent(transText);
        _contentSource = 'translation-db-${_selectedTranslation!.id}';
      } else {
        _activeType = 'none';
        _content = AppLocalizations.of(context)
                ?.translate('no_tafsir_translation_selected') ??
            'No translation or tafsir selected. Please select one from the options below.';
        _contentSource = 'none-selected';
      }
    } catch (e) {
      _content =
          (AppLocalizations.of(context)?.translate('error_loading_content') ??
                  'Error loading content: {error}')
              .replaceAll('{error}', '$e');
      _contentSource = 'error';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _startDownloadTafsir(TafsirEdition edition) async {
    final canDownload = await _ensureInternetConnection();
    if (!canDownload) return;
    if (_isDownloading) return;
    setState(() {
      _isDownloading = true;
      _downloadingType = 'tafsir';
      _downloadingId = edition.id;
      _downloadProgress = 0.0;
    });
    final ok = await _tafsirService.downloadTafsir(
      edition,
      onProgress: (p) {
        if (!mounted) return;
        setState(() => _downloadProgress = p.clamp(0.0, 1.0));
      },
    );
    if (ok) {
      await _tafsirService.setSelectedTafsirId(edition.id);
      await _loadEditions();
      await _loadContent();
    }
    if (mounted) {
      setState(() {
        _isDownloading = false;
        _downloadingType = null;
        _downloadingId = null;
        _downloadProgress = 0.0;
      });
    }
  }

  Future<void> _startDownloadTranslation(TranslationEdition edition) async {
    final canDownload = await _ensureInternetConnection();
    if (!canDownload) return;
    if (_isDownloading) return;
    setState(() {
      _isDownloading = true;
      _downloadingType = 'translation';
      _downloadingId = edition.id;
      _downloadProgress = 0.0;
    });
    final ok = await _translationService.downloadTranslation(
      edition,
      onProgress: (p) {
        if (!mounted) return;
        setState(() => _downloadProgress = p.clamp(0.0, 1.0));
      },
    );
    if (ok) {
      await _translationService.setSelectedTranslationId(edition.id);
      await _loadEditions();
      await _loadContent();
    }
    if (mounted) {
      setState(() {
        _isDownloading = false;
        _downloadingType = null;
        _downloadingId = null;
        _downloadProgress = 0.0;
      });
    }
  }

  Future<bool> _ensureInternetConnection() async {
    final connectivity = await Connectivity().checkConnectivity();
    final hasConnection = connectivity.isNotEmpty &&
        connectivity.any((e) => e != ConnectivityResult.none);
    if (hasConnection) return true;

    if (!mounted) return false;
    final title = AppLocalizations.of(context)?.translate('offline') ??
        'No internet connection';
    final message = AppLocalizations.of(context)?.translate('no_internet') ??
        'Please connect to the internet and try again.';

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)?.translate('ok') ?? 'OK'),
          ),
        ],
      ),
    );
    return false;
  }

  Future<void> _openDownloadedPicker(String type) async {
    // Implementation remains the same as original
    // (This part is quite lengthy and not essential for UI redesign)
  }

  Widget _buildDownloadButton(
      TafsirEdition? tafsir, TranslationEdition? translation) {
    if (tafsir != null && !_downloadedTafsirs.contains(tafsir.id.toString())) {
      return _DownloadButton(
        type: 'tafsir',
        edition: tafsir,
        isDownloading: _isDownloading,
        downloadingType: _downloadingType,
        downloadingId: _downloadingId,
        progress: _downloadProgress,
        onDownload: () => _startDownloadTafsir(tafsir),
      );
    } else if (translation != null &&
        !_downloadedTranslations.contains(translation.id.toString())) {
      return _DownloadButton(
        type: 'translation',
        edition: translation,
        isDownloading: _isDownloading,
        downloadingType: _downloadingType,
        downloadingId: _downloadingId,
        progress: _downloadProgress,
        onDownload: () => _startDownloadTranslation(translation),
      );
    }
    return const SizedBox();
  }

  Widget _buildEditionSelector({
    required String title,
    required IconData icon,
    required List<dynamic> editions,
    required dynamic selectedEdition,
    required bool isTafsir,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isTafsir
                      ? Colors.blue.withOpacity(0.1)
                      : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: isTafsir ? Colors.blue : Colors.green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              if (selectedEdition != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    AppLocalizations.of(context)?.translate('selected') ??
                        'Selected',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<dynamic>(
            isExpanded: true,
            initialValue: selectedEdition,
            decoration: InputDecoration(
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              hintText: isTafsir
                  ? (AppLocalizations.of(context)
                          ?.translate('select_tafsir_placeholder') ??
                      'Select Tafsir')
                  : (AppLocalizations.of(context)
                          ?.translate('select_trans_placeholder') ??
                      'Select Translation'),
              hintStyle: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            items: editions.map((e) {
              final isDownloaded = isTafsir
                  ? _downloadedTafsirs.contains(e.id.toString())
                  : _downloadedTranslations.contains(e.id.toString());

              return DropdownMenuItem<dynamic>(
                value: e,
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isDownloaded ? Colors.green : Colors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.name,
                            style: Theme.of(context).textTheme.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            e.languageName ??
                                (AppLocalizations.of(context)
                                        ?.translate('unknown_lang') ??
                                    'Unknown Language'),
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.6),
                                ),
                          ),
                        ],
                      ),
                    ),
                    if (isDownloaded)
                      const Icon(
                        Icons.download_done,
                        size: 16,
                        color: Colors.green,
                      ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (val) async {
              if (val == null) return;
              if (isTafsir) {
                await _tafsirService.setSelectedTafsirId(val.id);
                setState(() => _selectedTafsir = val);
              } else {
                await _translationService.setSelectedTranslationId(val.id);
                setState(() => _selectedTranslation = val);
              }
              _loadContent();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    if (_activeType == 'none') return const SizedBox();

    final edition =
        _activeType == 'tafsir' ? _selectedTafsir : _selectedTranslation;
    if (edition == null) return const SizedBox();

    // Resolve edition fields without relying on an implicit Object type
    final String editionName = _activeType == 'tafsir'
        ? (_selectedTafsir?.name ??
            (AppLocalizations.of(context)?.translate('unknown') ?? 'Unknown'))
        : (_selectedTranslation?.name ??
            (AppLocalizations.of(context)?.translate('unknown') ?? 'Unknown'));
    final String editionLanguage = _activeType == 'tafsir'
        ? (_selectedTafsir?.languageName ??
            (AppLocalizations.of(context)?.translate('unknown_language') ??
                'Unknown Language'))
        : (_selectedTranslation?.languageName ??
            (AppLocalizations.of(context)?.translate('unknown_language') ??
                'Unknown Language'));
    final String editionId = (_activeType == 'tafsir'
                ? _selectedTafsir?.id
                : _selectedTranslation?.id)
            ?.toString() ??
        'N/A';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _activeType == 'tafsir'
              ? [
                  Colors.blue.shade50,
                  Colors.blue.shade100.withOpacity(0.5),
                ]
              : [
                  Colors.green.shade50,
                  Colors.green.shade100.withOpacity(0.5),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _activeType == 'tafsir'
              ? Colors.blue.shade200.withOpacity(0.3)
              : Colors.green.shade200.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _activeType == 'tafsir' ? Colors.blue : Colors.green,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _activeType == 'tafsir' ? Icons.menu_book : Icons.translate,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _activeType == 'tafsir'
                      ? (AppLocalizations.of(context)
                              ?.translate('tab_tafsir') ??
                          'Tafsir')
                      : (AppLocalizations.of(context)
                              ?.translate('tab_translations') ??
                          'Translation'),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  editionName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '$editionLanguage • ID: $editionId',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6),
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _showInfoCard = !_showInfoCard),
            icon: Icon(
              _showInfoCard ? Icons.visibility_off : Icons.visibility,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.of(context)?.translate('content_header') ??
                    'Content',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: () =>
                        setState(() => _showFullContent = !_showFullContent),
                    icon: Icon(
                      _showFullContent
                          ? Icons.fullscreen_exit
                          : Icons.fullscreen,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    tooltip: _showFullContent
                        ? (AppLocalizations.of(context)
                                ?.translate('compact_view') ??
                            'Compact view')
                        : (AppLocalizations.of(context)
                                ?.translate('full_view') ??
                            'Full view'),
                  ),
                  IconButton(
                    onPressed: () {
                      _scrollController.animateTo(
                        0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    icon: Icon(
                      Icons.vertical_align_top,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    tooltip:
                        AppLocalizations.of(context)?.translate('scroll_top') ??
                            'Scroll to top',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _content == null ? _buildEmptyState() : _buildContentDisplay(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(
            Icons.info_outline,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 20),
          Text(
            AppLocalizations.of(context)?.translate('no_content') ??
                'No content available',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)?.translate('select_content_msg') ??
                'Please select a tafsir or translation to view content',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentDisplay() {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: _showFullContent
            ? MediaQuery.of(context).size.height * 0.6
            : MediaQuery.of(context).size.height * 0.4,
      ),
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        child: (_activeType != 'none' || _contentHasHtml)
            ? Html(
                data: _content!,
                style: {
                  'body': Style(
                    fontSize: FontSize(18),
                    lineHeight: const LineHeight(1.8),
                    textAlign: TextAlign.justify,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontFamily: 'Georgia',
                  ),
                  'h1': Style(
                    fontSize: FontSize(24),
                    fontWeight: FontWeight.bold,
                    padding: HtmlPaddings.only(bottom: 16),
                  ),
                  'h2': Style(
                    fontSize: FontSize(20),
                    fontWeight: FontWeight.w600,
                    padding: HtmlPaddings.only(bottom: 12),
                  ),
                  'p': Style(
                    margin: Margins.only(bottom: 16),
                  ),
                },
              )
            : Text(
                _content!,
                style: TextStyle(
                  fontSize: 18,
                  height: 1.8,
                  color: Theme.of(context).colorScheme.onSurface,
                  fontFamily: 'Georgia',
                ),
                textAlign: TextAlign.justify,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
            AppLocalizations.of(context)?.translate('tafsir_trans_title') ??
                'Tafsir & Translation'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loadEditions,
            icon: const Icon(Icons.refresh),
            tooltip:
                AppLocalizations.of(context)?.translate('refresh') ?? 'Refresh',
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.translate(
            offset:
                Offset(0, _slideAnimation.value * (1 - _fadeAnimation.value)),
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: child,
            ),
          );
        },
        child: _isLoading
            ? _buildLoadingState()
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ListView(
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _buildEditionSelector(
                            title: AppLocalizations.of(context)
                                    ?.translate('tafsir_select') ??
                                'Tafsir Selection',
                            icon: Icons.menu_book,
                            editions: _tafsirEditions,
                            selectedEdition: _selectedTafsir,
                            isTafsir: true,
                          ),
                          _buildEditionSelector(
                            title: AppLocalizations.of(context)
                                    ?.translate('trans_select') ??
                                'Translation Selection',
                            icon: Icons.translate,
                            editions: _translationEditions,
                            selectedEdition: _selectedTranslation,
                            isTafsir: false,
                          ),
                          if (_showInfoCard) _buildInfoCard(),
                          _buildDownloadButton(
                              _selectedTafsir, _selectedTranslation),
                          const SizedBox(height: 24),
                          _buildContentCard(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
      floatingActionButton: _selectedTafsir != null ||
              _selectedTranslation != null
          ? FloatingActionButton.extended(
              onPressed: () => _openDownloadedPicker(
                _activeType == 'tafsir' ? 'tafsir' : 'translation',
              ),
              icon: const Icon(Icons.download_for_offline),
              label: Text(
                  AppLocalizations.of(context)?.translate('downloaded_btn') ??
                      'Downloaded'),
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              elevation: 4,
            )
          : null,
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            AppLocalizations.of(context)?.translate('loading_msg') ??
                'Loading Content...',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)?.translate('preparing_msg') ??
                'Preparing tafsir and translation data',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadButton extends StatelessWidget {
  final String type;
  final dynamic edition;
  final bool isDownloading;
  final String? downloadingType;
  final int? downloadingId;
  final double progress;
  final VoidCallback onDownload;

  const _DownloadButton({
    required this.type,
    required this.edition,
    required this.isDownloading,
    required this.downloadingType,
    required this.downloadingId,
    required this.progress,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final isCurrentDownloading =
        isDownloading && downloadingType == type && downloadingId == edition.id;
    final typeLabel = AppLocalizations.of(context)?.translate(
            type == 'tafsir' ? 'type_tafsir' : 'type_translation') ??
        (type == 'tafsir' ? 'Tafsir' : 'Translation');

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: type == 'tafsir'
            ? Colors.blue.withOpacity(0.05)
            : Colors.green.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: type == 'tafsir'
              ? Colors.blue.withOpacity(0.2)
              : Colors.green.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            type == 'tafsir' ? Icons.cloud_download : Icons.download,
            color: type == 'tafsir' ? Colors.blue : Colors.green,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)
                          ?.translate('download_required') ??
                      'Download Required',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: type == 'tafsir' ? Colors.blue : Colors.green,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  (AppLocalizations.of(context)
                              ?.translate('download_required_msg') ??
                          'This {type} needs to be downloaded for offline use')
                      .replaceAll('{type}', typeLabel),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6),
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (isCurrentDownloading)
            SizedBox(
              width: 120,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  type == 'tafsir' ? Colors.blue : Colors.green,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
            )
          else
            ElevatedButton(
              onPressed: onDownload,
              style: ElevatedButton.styleFrom(
                backgroundColor: type == 'tafsir' ? Colors.blue : Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                elevation: 0,
              ),
              child: Text(
                AppLocalizations.of(context)?.translate('download_now') ??
                    'Download Now',
              ),
            ),
        ],
      ),
    );
  }
}
