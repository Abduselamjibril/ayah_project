import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quran_app/app/app.dart';
import 'package:quran_app/core/ui/snackbar_utils.dart';
import 'package:quran_app/core/quran/qcf_quran.dart';
import 'package:quran_app/core/services/audio_player_service.dart';
import 'package:quran_app/core/services/translation_service.dart';
import 'package:quran_app/data/models/translation_model.dart';
import 'package:quran_app/features/bookmarks/bookmark_screen.dart';
import 'package:quran_app/features/bookmarks/state/bookmark_notes_notifier.dart';
import 'package:quran_app/features/highlights/state/highlight_notifier.dart';
import 'package:quran_app/features/highlights/data/models/highlight.dart';
import 'package:quran_app/features/share/presentation/dialogs/share_preview_dialog.dart';
import 'package:quran_app/features/mushaf/screens/verse_details_screen.dart';
import 'package:quran_app/core/i18n/app_localizations.dart';
import 'package:quran_app/core/utils/localization_helper.dart';
import 'play_range_dialog.dart';
import 'share_options_sheet.dart';

class _TranslationItem {
  final TranslationEdition edition;
  final bool isDownloaded;

  const _TranslationItem({
    required this.edition,
    required this.isDownloaded,
  });
}

class _MenuEditResult {
  _MenuEditResult({required this.order, required this.hidden});
  final List<String> order;
  final List<String> hidden;
}

class VerseOptionsSheet extends StatefulWidget {
  final int surah;
  final int verse;
  final VoidCallback? onDismiss;

  const VerseOptionsSheet({
    super.key,
    required this.surah,
    required this.verse,
    this.onDismiss,
  });

  @override
  State<VerseOptionsSheet> createState() => _VerseOptionsSheetState();
}

class _VerseOptionsSheetState extends State<VerseOptionsSheet> {
  final TranslationService _translationService = TranslationService.instance;
  TranslationEdition? _selectedTranslation;
  String? _translationText;
  bool _translationExpanded = false;
  bool _translationLoading = false;
  final Map<String, double> _translationDownloadProgress = {};
  final Set<String> _translationDownloading = {};
  StateSetter? _translationSheetSetState;
  static const String _translationDownloadPrefix =
      'translation_download_progress_';
  static const List<String> _bookmarkColors = [
    '#EF5350', // Red
    '#FFB300', // Yellow
    '#FFA726', // Orange
    '#66BB6A', // Green
    '#42A5F5', // Blue
    '#AB47BC', // Purple
  ];

  static const List<String> _defaultSectionOrder = [
    'bookmarks',
    'recitation',
    'downloads',
    'sharing',
    'highlight',
  ];

  List<String> _sectionOrder = List.from(_defaultSectionOrder);
  List<String> _hiddenSections = [];
  static const _sectionOrderKey = 'verse_menu_order';
  static const _hiddenSectionKey = 'verse_menu_hidden';

  @override
  void initState() {
    super.initState();
    _loadSectionOrder();
    _loadPersistedTranslationProgress();
    _loadSelectedTranslation();
  }

  Future<void> _loadPersistedTranslationProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (!key.startsWith(_translationDownloadPrefix)) continue;
      final id = key.substring(_translationDownloadPrefix.length);
      final value = prefs.getDouble(key);
      if (value != null) {
        _translationDownloading.add(id);
        _translationDownloadProgress[id] = value.clamp(0.0, 1.0);
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadSelectedTranslation() async {
    if (mounted) {
      setState(() {
        _translationLoading = true;
      });
    }
    final selectedId = await _translationService.getSelectedTranslationId();
    TranslationEdition? edition;
    String? text;

    if (selectedId == null) {
      final allEditions =
          await _translationService.getAllTranslationEditions();
      final downloaded = await _translationService.getDownloadedTranslations();
      final englishDownloaded = allEditions
          .where((e) =>
              e.languageName.toLowerCase() == 'english' &&
              downloaded.contains(e.id.toString()))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));

      if (englishDownloaded.isNotEmpty) {
        edition = englishDownloaded.first;
        await _translationService.setSelectedTranslationId(edition.id);
      }
    }

    edition ??= await _translationService.getSelectedTranslation();
    if (edition != null) {
      final cached = _translationService.getCachedTranslation(
        surahNumber: widget.surah,
        ayahNumber: widget.verse,
        editionIdentifier: edition.id.toString(),
      );
      if (cached != null && mounted) {
        setState(() {
          _selectedTranslation = edition;
          _translationText = cached;
        });
      }
      text = await _translationService.getTranslationByEdition(
        surahNumber: widget.surah,
        ayahNumber: widget.verse,
        editionIdentifier: edition.id.toString(),
      );
    }

    if (mounted) {
      setState(() {
        _selectedTranslation = edition;
        _translationText = text;
        _translationExpanded = false;
        _translationLoading = false;
      });
    }
  }

  Future<void> _setSelectedTranslation(TranslationEdition? edition) async {
    if (edition == null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('selected_translation_id');
      if (mounted) {
        setState(() {
          _selectedTranslation = null;
          _translationText = null;
          _translationExpanded = false;
          _translationLoading = false;
        });
      }
      return;
    }

    await _translationService.setSelectedTranslationId(edition.id);
    if (mounted) {
      setState(() {
        _translationLoading = true;
      });
    }
    final text = await _translationService.getTranslationByEdition(
      surahNumber: widget.surah,
      ayahNumber: widget.verse,
      editionIdentifier: edition.id.toString(),
    );
    if (mounted) {
      setState(() {
        _selectedTranslation = edition;
        _translationText = text;
        _translationExpanded = false;
        _translationLoading = false;
      });
    }
  }

  Future<void> _loadSectionOrder() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _sectionOrder = prefs.getStringList(_sectionOrderKey) ??
            List.from(_defaultSectionOrder);
        _hiddenSections = prefs.getStringList(_hiddenSectionKey) ?? [];
      });
    }
  }

  Future<void> _saveMenuConfig(List<String> order, List<String> hidden) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_sectionOrderKey, order);
    await prefs.setStringList(_hiddenSectionKey, hidden);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    // Listen to the bookmark state globally
    final bookmarkState = context.watch<BookmarkNotesNotifier>();

    final surahTitle =
        '${getBilingualSurahName(context, widget.surah)}: ${widget.verse}';

    final orderedSections = _buildOrderedSections(
      context,
      bookmarkState,
      widget.surah,
      widget.verse,
      context,
    );

    return SafeArea(
      top: false,
      bottom: false,
      child: FractionallySizedBox(
        heightFactor: 0.9,
        alignment: Alignment.bottomCenter,
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      TextButton(
                        onPressed: () async {
                          final result = await _openMenuEditor(context);
                          if (result != null && mounted) {
                            setState(() {
                              _sectionOrder = result.order;
                              _hiddenSections = result.hidden;
                            });
                            await _saveMenuConfig(result.order, result.hidden);
                          }
                        },
                        child: Text(
                          AppLocalizations.of(context)?.translate('edit') ??
                              'Edit',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: BrandColors.accent),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(surahTitle,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 18)),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...orderedSections,
                  const SizedBox(height: 12),
                  Text(
                    AppLocalizations.of(context)?.translate('actions') ??
                        'Actions',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  _buildQuickActions(context, bookmarkState, context,
                      widget.surah, widget.verse),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text, BuildContext context) {
    return Text(text,
        style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.9)));
  }

  List<Widget> _buildOrderedSections(
      BuildContext context,
      BookmarkNotesNotifier bookmarkState,
      int surah,
      int verse,
      BuildContext rootContext) {
    final widgets = <Widget>[];
    final visibleSections =
        _sectionOrder.where((s) => !_hiddenSections.contains(s));

    // Get the dynamic color from our global state
    final activeQuickColor = bookmarkState.quickBookmarkColor ?? '#EF5350';
    final activeColorName = _getCategoryName(activeQuickColor);

    void addSpacer() => widgets.add(const SizedBox(height: 18));

    for (final sectionKey in visibleSections) {
      switch (sectionKey) {
        case 'bookmarks':
          widgets
            ..add(_buildSectionLabel(
                AppLocalizations.of(context)?.translate('bookmarks_title') ??
                    'Bookmarks',
                context))
            ..add(const SizedBox(height: 8))
            ..add(Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    context,
                    width: double.infinity,
                    icon: Icons.bookmark_border,
                    // Dynamic color from the Bookmark Screen selection
                    iconColor: Color(_parseColor(activeQuickColor)),
                    // Dynamic label based on the active color
                    label: activeColorName,
                    onTap: () {
                      Navigator.pop(context);
                      unawaited(() async {
                        await bookmarkState.saveBookmark(
                          surahId: surah,
                          ayahId: verse,
                          colorHex: activeQuickColor,
                          category: activeColorName,
                        );
                        if (!mounted) return;
                        _showSnack(AppLocalizations.of(context)
                                ?.translate('verse_bookmarked') ??
                            'Verse bookmarked');
                      }());
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionCard(
                    context,
                    width: double.infinity,
                    icon: Icons.list_alt,
                    label: 'All',
                    trailing: Icons.chevron_right,
                    onTap: () async {
                      await bookmarkState.refresh();
                      await showModalBottomSheet(
                        context: rootContext,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const BookmarkScreen(),
                      );
                    },
                  ),
                ),
              ],
            ));
          addSpacer();
          break;

        case 'recitation':
          widgets
            ..add(_buildSectionLabel(
                AppLocalizations.of(context)?.translate('recitation') ??
                    'Recitation',
                context))
            ..add(const SizedBox(height: 8))
            ..add(Row(children: [
              Expanded(
                  child: _buildActionCard(context,
                      width: double.infinity,
                      icon: Icons.play_arrow,
                      label: AppLocalizations.of(context)?.translate('play') ??
                          'Play', onTap: () {
                Navigator.pop(context);
                AudioPlayerService.instance
                    .playSurahSequenceWithDownload(rootContext, surah, verse);
              })),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildActionCard(context,
                      width: double.infinity,
                      icon: Icons.playlist_play,
                      label:
                          AppLocalizations.of(context)?.translate('play_to') ??
                              'Play to...', onTap: () {
                _showPlayToDialog(rootContext, surah, verse);
              })),
            ]));
          addSpacer();
          break;

        case 'downloads':
          widgets
            ..add(_buildSectionLabel(
                AppLocalizations.of(context)?.translate('translation') ??
                    'Translation',
                context))
            ..add(const SizedBox(height: 8))
            ..add(_buildTranslationCard(context))
            ..add(const SizedBox(height: 10))
            ..add(_buildActionCard(
              context,
              width: double.infinity,
                icon: Icons.local_library_outlined,
                label: AppLocalizations.of(context)?.translate('tab_tafsir') ??
                  'Tafsir',
              trailing: Icons.chevron_right,
              onTap: () {
                Navigator.pop(context);
                _viewTafsir(rootContext, surah, verse);
              },
            ));
          addSpacer();
          break;

        case 'sharing':
          widgets
            ..add(_buildSectionLabel(
                AppLocalizations.of(context)?.translate('sharing') ?? 'Sharing',
                context))
            ..add(const SizedBox(height: 8))
            ..add(Row(
              children: [
                SizedBox(
                  width: 64,
                  child: _buildShareIconCard(context,
                      icon: Icons.file_copy_outlined, onTap: () {
                    Navigator.pop(context);
                    _copyVerseText(surah, verse);
                  }),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 64,
                  child: _buildShareIconCard(context, icon: Icons.save_alt,
                      onTap: () {
                    Navigator.pop(context);
                    _shareVerseCardPreview(surah, verse);
                  }),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildShareMainCard(
                    context,
                    icon: Icons.ios_share,
                    label: AppLocalizations.of(context)?.translate('share') ??
                        'Share',
                    onTap: () {
                      _openShareSheet(rootContext, surah, verse);
                    },
                  ),
                ),
              ],
            ));
          addSpacer();
          break;

        case 'highlight':
          widgets
            ..add(_buildSectionLabel(
                AppLocalizations.of(context)?.translate('highlight') ??
                    'Highlight',
                context))
            ..add(const SizedBox(height: 10))
            ..add(_buildHighlightRow(context, bookmarkState, surah, verse));
          addSpacer();
          break;
      }
    }
    if (widgets.isNotEmpty && widgets.last is SizedBox) widgets.removeLast();
    return widgets;
  }

  Widget _buildActionCard(BuildContext context,
      {required double width,
      required IconData icon,
      required String label,
      required VoidCallback onTap,
      IconData? trailing,
      bool enabled = true,
      Color? iconColor}) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final cardBg = isLight
        ? theme.scaffoldBackgroundColor
        : theme.colorScheme.onSurface.withOpacity(enabled ? 0.08 : 0.04);
    final borderColor = isLight
        ? theme.colorScheme.surface
        : theme.colorScheme.onSurface.withOpacity(0.08);
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Row(
            children: [
              Icon(icon,
                  color: enabled
                      ? (iconColor ?? BrandColors.accent)
                      : theme.colorScheme.onSurface.withOpacity(0.4)),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(label,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: enabled
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurface.withOpacity(0.4),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis)),
              if (trailing != null)
                Icon(trailing,
                    size: 18,
                    color: theme.colorScheme.onSurface.withOpacity(0.7)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTranslationCard(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final cardBg = isLight
        ? theme.scaffoldBackgroundColor
        : theme.colorScheme.onSurface.withOpacity(0.08);
    final borderColor = isLight
        ? theme.colorScheme.surface
        : theme.colorScheme.onSurface.withOpacity(0.08);
    final accent = BrandColors.accent;

    final translationText = _translationText?.trim();
    final hasTranslation =
        translationText != null && translationText.isNotEmpty;
    final isLoading = _translationLoading;
    final translatorName = _selectedTranslation?.name;
    return SizedBox(
      width: double.infinity,
      child: InkWell(
        onTap: () => _openTranslationPicker(context),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            if (!hasTranslation && isLoading)
              Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)
                              ?.translate('loading') ??
                          'Loading translation...',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ),
                ],
              )
            else if (!hasTranslation)
              Row(
                children: [
                  Icon(Icons.menu_book_outlined, color: accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)
                              ?.translate('select_translation') ??
                          'Select Translation...',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ),
                ],
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final textStyle = theme.textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                    color: theme.colorScheme.onSurface,
                  );
                  final isOverflowing = _isTextOverflowing(
                    translationText,
                    textStyle ?? const TextStyle(),
                    constraints.maxWidth,
                  );
                  final maxLines = _translationExpanded ? null : 3;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        translationText,
                        maxLines: maxLines,
                        overflow: _translationExpanded
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                        style: textStyle,
                      ),
                      if (isOverflowing || _translationExpanded)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _translationExpanded = !_translationExpanded;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              _translationExpanded
                                  ? (AppLocalizations.of(context)
                                          ?.translate('show_less') ??
                                      'Show less')
                                  : (AppLocalizations.of(context)
                                          ?.translate('continue_reading') ??
                                      'Continue reading'),
                              style: TextStyle(
                                color: accent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            if (translatorName != null && translatorName.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                translatorName,
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            ],
          ),
        ),
      ),
    );
  }

  bool _isTextOverflowing(String text, TextStyle style, double maxWidth) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 3,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    return painter.didExceedMaxLines;
  }

  Future<void> _openTranslationPicker(BuildContext context) async {
    final translations = await _translationService.getAllTranslationEditions();
    final downloaded = await _translationService.getDownloadedTranslations();
    final selectedId = await _translationService.getSelectedTranslationId();

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            _translationSheetSetState = setSheetState;
            final theme = Theme.of(context);
            final isLight = theme.brightness == Brightness.light;
            final cardBg = isLight
                ? theme.scaffoldBackgroundColor
                : theme.colorScheme.onSurface.withOpacity(0.08);

            final grouped = <String, List<_TranslationItem>>{};
            for (final t in translations) {
              grouped.putIfAbsent(t.languageName, () => []);
              grouped[t.languageName]!.add(
                _TranslationItem(
                  edition: t,
                  isDownloaded: downloaded.contains(t.id.toString()),
                ),
              );
            }

            const preferred = ['english', 'arabic', 'amharic'];
            final preferredLangs = <String>[];
            for (final p in preferred) {
              final match = grouped.keys.firstWhere(
                (k) => k.toLowerCase() == p,
                orElse: () => '',
              );
              if (match.isNotEmpty) preferredLangs.add(match);
            }

            final otherLangs = grouped.keys
                .where((l) => !preferred.contains(l.toLowerCase()))
                .toList()
              ..sort((a, b) {
                final aHas = grouped[a]!.any((e) => e.isDownloaded);
                final bHas = grouped[b]!.any((e) => e.isDownloaded);
                if (aHas != bHas) return aHas ? -1 : 1;
                return a.compareTo(b);
              });

            final orderedLangs = [...preferredLangs, ...otherLangs];

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
                                AppLocalizations.of(context)
                                        ?.translate('select_translation') ??
                                    'Select Translation',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        children: [
                          _buildTranslationPickerItem(
                            context: sheetContext,
                            title: AppLocalizations.of(context)
                                    ?.translate('none_selected') ??
                                'None',
                            subtitle: null,
                            cardBg: cardBg,
                            isSelected: selectedId == null,
                            trailing: selectedId == null
                                ? Icon(Icons.check, color: BrandColors.accent)
                                : null,
                            onTap: () async {
                              await _setSelectedTranslation(null);
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          for (final lang in orderedLangs) ...[
                            Text(
                              lang,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ..._buildLanguageItems(
                              context: sheetContext,
                              items: grouped[lang]!,
                              cardBg: cardBg,
                              selectedId: selectedId?.toString(),
                            ),
                            const SizedBox(height: 16),
                          ],
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
    );
    _translationSheetSetState = null;
  }

  Future<void> _downloadTranslationFromPicker(
    TranslationEdition edition,
    BuildContext sheetContext,
  ) async {
    final id = edition.id.toString();
    if (_translationDownloading.contains(id)) return;

    setState(() {
      _translationDownloading.add(id);
      _translationDownloadProgress[id] = 0.0;
    });
    _translationSheetSetState?.call(() {});
    final prefsFuture = SharedPreferences.getInstance();
    (await prefsFuture)
        .setDouble('${_translationDownloadPrefix}$id', 0.0);

    _showSnack(
      (AppLocalizations.of(context)?.translate('downloading_item') ??
              'Downloading {name}')
          .replaceAll('{name}', edition.name),
    );
    bool ok = false;
    try {
      ok = await _translationService.downloadTranslation(
        edition,
        onProgress: (progress) {
          if (!mounted) return;
          prefsFuture.then((prefs) {
            prefs.setDouble('${_translationDownloadPrefix}$id',
                progress.clamp(0.0, 1.0));
          });
          setState(() {
            _translationDownloadProgress[id] =
                progress.clamp(0.0, 1.0);
          });
          _translationSheetSetState?.call(() {});
        },
      );

      if (ok) {
        await _setSelectedTranslation(edition);
        if (sheetContext.mounted) {
          Navigator.pop(sheetContext);
        }
      } else {
        _showSnack(
          AppLocalizations.of(context)
                  ?.translate('download_failed_try_again') ??
              'Download failed. Please try again.',
        );
      }
    } finally {
      (await prefsFuture).remove('${_translationDownloadPrefix}$id');
      if (mounted) {
        setState(() {
          _translationDownloading.remove(id);
          _translationDownloadProgress.remove(id);
        });
      }
      _translationSheetSetState?.call(() {});
    }
  }

  List<Widget> _buildLanguageItems({
    required BuildContext context,
    required List<_TranslationItem> items,
    required Color cardBg,
    required String? selectedId,
  }) {
    final sorted = List<_TranslationItem>.from(items)
      ..sort((a, b) {
        if (a.isDownloaded != b.isDownloaded) {
          return a.isDownloaded ? -1 : 1;
        }
        return a.edition.name.compareTo(b.edition.name);
      });

    return [
      _buildTranslationGroupCard(
        context: context,
        items: sorted,
        cardBg: cardBg,
        selectedId: selectedId,
      ),
    ];
  }

  Widget _buildTranslationGroupCard({
    required BuildContext context,
    required List<_TranslationItem> items,
    required Color cardBg,
    required String? selectedId,
  }) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.dividerColor.withOpacity(0.15),
          ),
        ),
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              _buildTranslationRow(
                context: context,
                item: items[i],
                selectedId: selectedId,
              ),
              if (i != items.length - 1)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: theme.dividerColor.withOpacity(0.15),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTranslationRow({
    required BuildContext context,
    required _TranslationItem item,
    required String? selectedId,
  }) {
    final theme = Theme.of(context);
    final edition = item.edition;
    final id = edition.id.toString();
    final isSelected = selectedId == id;
    final isDownloading = _translationDownloading.contains(id);
    final progress = _translationDownloadProgress[id] ?? 0.0;
    final trailing = item.isDownloaded
        ? (isSelected ? Icon(Icons.check, color: BrandColors.accent) : null)
        : (isDownloading
            ? _buildDownloadProgressIndicator(progress)
            : IconButton(
                icon: Icon(Icons.download_for_offline,
                    color: BrandColors.accent),
                onPressed: () => _downloadTranslationFromPicker(edition, context),
              ));

    return InkWell(
      onTap: item.isDownloaded
          ? () async {
              await _setSelectedTranslation(edition);
              if (context.mounted) {
                Navigator.pop(context);
              }
            }
          : (isDownloading
              ? null
              : () => _downloadTranslationFromPicker(edition, context)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
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
                    edition.languageName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadProgressIndicator(double progress) {
    final percent = (progress * 100).round();
    return SizedBox(
      width: 32,
      height: 32,
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
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildTranslationPickerItem({
    required BuildContext context,
    required String title,
    required String? subtitle,
    required Color cardBg,
    required bool isSelected,
    required Widget? trailing,
    required VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? BrandColors.accent.withOpacity(0.4)
                  : theme.dividerColor.withOpacity(0.15),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShareIconCard(BuildContext context,
      {required IconData icon,
      required VoidCallback onTap,
      bool enabled = true}) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final cardBg = isLight
        ? theme.scaffoldBackgroundColor
        : theme.colorScheme.onSurface.withOpacity(enabled ? 0.08 : 0.04);
    final borderColor = isLight
        ? theme.colorScheme.surface
        : theme.colorScheme.onSurface.withOpacity(0.08);
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Center(
          child: Icon(icon,
              size: 26,
              color: enabled
                  ? BrandColors.accent
                  : theme.colorScheme.onSurface.withOpacity(0.4)),
        ),
      ),
    );
  }

  Widget _buildShareMainCard(BuildContext context,
      {required IconData icon,
      required String label,
      required VoidCallback onTap,
      bool enabled = true}) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final cardBg = isLight
        ? theme.scaffoldBackgroundColor
        : theme.colorScheme.onSurface.withOpacity(enabled ? 0.08 : 0.04);
    final borderColor = isLight
        ? theme.colorScheme.surface
        : theme.colorScheme.onSurface.withOpacity(0.08);
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, size: 26, color: BrandColors.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: BrandColors.accent),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            const Icon(Icons.chevron_right,
                size: 20, color: BrandColors.accent),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightRow(
      BuildContext context, BookmarkNotesNotifier _, int surah, int verse) {
    final highlightState = context.watch<HighlightNotifier>();
    final chips = <Widget>[];
    final existingHighlight = highlightState.getHighlight(surah, verse);
    final existingColor = existingHighlight?.colorHex.toLowerCase();
    for (var i = 0; i < _bookmarkColors.length; i++) {
      final hex = _bookmarkColors[i];
      final color = Color(_parseColor(hex));
      final isSelected = existingColor == hex.toLowerCase();
      chips.add(Padding(
        padding: const EdgeInsets.only(right: 10),
        child: InkWell(
          onTap: () async {
            Navigator.pop(context);
            if (isSelected) {
              await highlightState.removeHighlight(surah, verse);
              _showSnack(AppLocalizations.of(context)
                      ?.translate('highlight_removed') ??
                  'Highlight removed');
            } else {
              await highlightState.addHighlight(
                Highlight(
                  surahId: surah,
                  ayahId: verse,
                  colorHex: hex,
                  createdAt: DateTime.now(),
                ),
              );
              _showSnack(
                  AppLocalizations.of(context)?.translate('highlight_added') ??
                      'Verse highlighted');
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? color.withOpacity(0.3)
                    : color.withOpacity(0.18),
                border: Border.all(color: color, width: 2)),
            child:
                isSelected ? Icon(Icons.check, size: 20, color: color) : null,
          ),
        ),
      ));
    }
    return Row(children: chips);
  }

  Widget _buildQuickActions(BuildContext context, BookmarkNotesNotifier state,
      BuildContext rootContext, int surah, int verse) {
    return Column(children: [
      _buildActionCard(context,
          width: double.infinity,
          icon: Icons.push_pin_outlined,
          label: AppLocalizations.of(context)?.translate('pin_khatmah') ??
              'Pin here (Khatmah)', onTap: () {
        Navigator.pop(context);
        _pinKhatmah(state, surah, verse);
      }),
      const SizedBox(height: 10),
      _buildActionCard(context,
          width: double.infinity,
          icon: Icons.flag_outlined,
          label: AppLocalizations.of(context)?.translate('set_last_read') ??
              'Set as last read', onTap: () {
        Navigator.pop(context);
        unawaited(_toggleLastReadAt(state, surah, verse));
      }),
      const SizedBox(height: 10),
      _buildActionCard(context,
          width: double.infinity,
          icon: Icons.menu_book_outlined,
          label: AppLocalizations.of(context)?.translate('view_tafsir') ??
              'View Tafsir',
          trailing: Icons.chevron_right, onTap: () {
        Navigator.pop(context);
        _viewTafsir(rootContext, surah, verse);
      }),
    ]);
  }

  Future<void> _pinKhatmah(
      BookmarkNotesNotifier state, int surah, int verse) async {
    await state.setKhatmahPin(
        surahId: surah,
        ayahId: verse,
        colorHex: '#FFB300',
        category: 'Khatmah');
    if (!mounted) return;
    _showSnack(AppLocalizations.of(context)?.translate('pinned_for_khatmah') ??
        'Pinned for Khatmah');
  }

  Future<void> _toggleLastReadAt(
      BookmarkNotesNotifier state, int surah, int verse) async {
    int? page;
    try {
      page = getPageNumber(surah, verse);
    } catch (_) {}
    final pin = state.khatmahPin;
    bool isSameLastRead = pin != null &&
        pin.surahId == surah &&
        pin.ayahId == verse &&
        (pin.categoryName == 'Last read' || pin.categoryName == null);
    if (isSameLastRead) {
      await state.clearKhatmahPin();
      if (!mounted) return;
      _showSnack(page != null
          ? 'Removed last read for page $page'
          : 'Removed last read');
      return;
    }
    await state.setKhatmahPin(
        surahId: surah,
        ayahId: verse,
        colorHex: '#4DB6AC',
        category: 'Last read');
    if (!mounted) return;
    final name = getBilingualSurahName(context, surah);
    _showSnack('Page ${page ?? ""} • $name:$verse set as last read');
  }

  Future<_MenuEditResult?> _openMenuEditor(BuildContext context) async {
    final order = List<String>.from(_sectionOrder);
    final hidden = List<String>.from(_hiddenSections);
    return showModalBottomSheet<_MenuEditResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isLight = theme.brightness == Brightness.light;
        return FractionallySizedBox(
          heightFactor: 0.8,
          alignment: Alignment.bottomCenter,
          child: Container(
            decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(24)),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx)),
                    const Spacer(),
                    Text(
                        AppLocalizations.of(context)
                                ?.translate('edit_verse_menu') ??
                            'Edit Verse Menu',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 18)),
                    const Spacer(),
                    TextButton(
                        onPressed: () => Navigator.pop(
                            ctx,
                            _MenuEditResult(
                                order: List.from(order),
                                hidden: List.from(hidden))),
                        child: Text(
                            AppLocalizations.of(context)?.translate('done') ??
                                'Done')),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: StatefulBuilder(
                    builder: (context, setSheetState) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              AppLocalizations.of(context)
                                      ?.translate('display_order') ??
                                  'Display Order',
                              style: theme.textTheme.labelMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 10),
                          Expanded(
                            child: ReorderableListView.builder(
                              itemCount: order.length,
                              buildDefaultDragHandles: false,
                              itemBuilder: (context, index) {
                                final item = order[index];
                                return Card(
                                  key: ValueKey(item),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  color: isLight
                                      ? theme.scaffoldBackgroundColor
                                      : theme.colorScheme.onSurface
                                          .withOpacity(0.05),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                  child: ListTile(
                                    title: Text(_labelForSection(item),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700)),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                            icon: const Icon(
                                                Icons.remove_circle_outline,
                                                color: Colors.redAccent),
                                            onPressed: () {
                                              setSheetState(() {
                                                order.removeAt(index);
                                                if (!hidden.contains(item))
                                                  hidden.add(item);
                                              });
                                            }),
                                        ReorderableDragStartListener(
                                            index: index,
                                            child:
                                                const Icon(Icons.drag_handle)),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              onReorder: (oldIndex, newIndex) {
                                setSheetState(() {
                                  if (newIndex > oldIndex) newIndex -= 1;
                                  final item = order.removeAt(oldIndex);
                                  order.insert(newIndex, item);
                                });
                              },
                            ),
                          ),
                          if (hidden.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                                AppLocalizations.of(context)
                                        ?.translate('hidden') ??
                                    'Hidden',
                                style: theme.textTheme.labelMedium
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              for (final item in hidden)
                                InputChip(
                                    label: Text(_labelForSection(item)),
                                    avatar: const Icon(Icons.add),
                                    onPressed: () {
                                      setSheetState(() {
                                        hidden.remove(item);
                                        order.add(item);
                                      });
                                    }),
                            ]),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openNoteSheet(BuildContext context, BookmarkNotesNotifier state,
      int surah, int verse) async {
    final existing = state.noteForVerse(surah, verse);
    final controller = TextEditingController(text: existing?.content ?? '');
    String? lastSavedText = existing?.content;
    bool saving = false;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> handleSave() async {
              if (saving) return;
              setModalState(() => saving = true);
              try {
                final text = controller.text.trim();
                if (text.isEmpty) {
                  if (existing != null)
                    await state.deleteNoteForVerse(surah, verse);
                  lastSavedText = '';
                } else {
                  await state.upsertNote(
                      surahId: surah, ayahId: verse, content: text);
                  lastSavedText = text;
                }
                if (context.mounted) Navigator.pop(context, true);
              } catch (_) {
                if (context.mounted) _showSnack('Failed to save note');
              } finally {
                setModalState(() => saving = false);
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Note for $surah:$verse',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(
                      controller: controller,
                      maxLines: 6,
                      decoration: const InputDecoration(
                          hintText: 'Write your reflection here',
                          border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (existing != null)
                        TextButton.icon(
                          onPressed: saving
                              ? null
                              : () async {
                                  setModalState(() => saving = true);
                                  await state.deleteNoteForVerse(surah, verse);
                                  if (context.mounted)
                                    Navigator.pop(context, true);
                                },
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Delete'),
                        ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: saving ? null : handleSave,
                        icon: saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.save),
                        label: Text(saving ? 'Saving...' : 'Save'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (saved == true && mounted) {
      _showSnack((lastSavedText == null || lastSavedText!.isEmpty)
          ? 'Note removed for $surah:$verse'
          : 'Note saved for $surah:$verse');
    }
  }

  Future<void> _openShareSheet(
      BuildContext context, int surah, int verse) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => ShareOptionsSheet(surah: surah, verse: verse),
    );
  }

  Future<void> _shareVerseCardPreview(int surah, int verse) async {
    await showSharePreviewDialog(
        context: context, surahNumber: surah, ayahNumber: verse);
  }

  void _viewTafsir(BuildContext context, int surah, int verse) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => VerseDetailsScreen(
        surahNumber: surah,
        ayahNumber: verse,
      ),
    );
  }

  Future<void> _showPlayToDialog(
      BuildContext context, int startSurah, int startVerse) async {
    await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) =>
            PlayRangeDialog(startSurah: startSurah, startVerse: startVerse));
  }

  void _copyVerseText(int surah, int verse) {
    Clipboard.setData(
        ClipboardData(text: getVerseQCF(surah, verse, verseEndSymbol: true)));
    _showSnack('Copied Surah $surah:$verse');
  }

  void _showSnack(String message) {
    if (!mounted) return;
    showAppSnack(context, message, type: AppSnackType.info);
  }

  String _getCategoryName(String hex) {
    if (hex.toUpperCase() == '#EF5350') return 'Red';
    if (hex.toUpperCase() == '#FFB300') return 'Yellow';
    if (hex.toUpperCase() == '#FFA726') return 'Orange';
    if (hex.toUpperCase() == '#66BB6A') return 'Green';
    if (hex.toUpperCase() == '#42A5F5') return 'Blue';
    if (hex.toUpperCase() == '#AB47BC') return 'Purple';
    return 'Bookmark';
  }

  String _labelForSection(String key) {
    switch (key) {
      case 'bookmarks':
        return AppLocalizations.of(context)?.translate('bookmarks_title') ??
            'Bookmarks';
      case 'recitation':
        return AppLocalizations.of(context)?.translate('recitation') ??
            'Recitation';
      case 'downloads':
        return AppLocalizations.of(context)?.translate('translation') ??
            'Translation';
      case 'sharing':
        return AppLocalizations.of(context)?.translate('sharing') ?? 'Sharing';
      case 'highlight':
        return AppLocalizations.of(context)?.translate('highlight') ??
            'Highlight';
      default:
        return key;
    }
  }

  int _parseColor(String value) {
    try {
      final normalized = value.replaceAll('#', '').padLeft(6, '0');
      return int.parse('FF$normalized', radix: 16);
    } catch (_) {
      return int.parse('FFFFC107', radix: 16);
    }
  }
}
