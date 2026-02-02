import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quran_app/app/app.dart';
import 'package:quran_app/core/quran/qcf_quran.dart';
import 'package:quran_app/core/services/audio_player_service.dart';
import 'package:quran_app/features/bookmarks/bookmark_screen.dart';
import 'package:quran_app/features/bookmarks/state/bookmark_notes_notifier.dart';
import 'package:quran_app/features/downloads/downloads_screen.dart';
import 'package:quran_app/features/share/presentation/dialogs/share_preview_dialog.dart';
import 'package:quran_app/features/mushaf/screens/verse_details_screen.dart';
import 'package:quran_app/core/i18n/app_localizations.dart';
import 'package:quran_app/core/utils/localization_helper.dart';
import 'play_range_dialog.dart';
import 'share_options_sheet.dart';

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
  static const List<String> _bookmarkColors = [
    '#EF5350', // Red
    '#FFB300', // Yellow
    '#66BB6A', // Green
    '#42A5F5', // Blue
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
      child: FractionallySizedBox(
        heightFactor: 0.9,
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
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
                              await _saveMenuConfig(
                                  result.order, result.hidden);
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
                      Navigator.pop(context);
                      await bookmarkState.refresh();
                      await Navigator.push(
                          rootContext,
                          MaterialPageRoute(
                              builder: (_) => const BookmarkScreen()));
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
                Navigator.pop(context);
                _showPlayToDialog(rootContext, surah, verse);
              })),
            ]));
          addSpacer();
          break;

        case 'downloads':
          widgets
            ..add(_buildSectionLabel(
                AppLocalizations.of(context)?.translate('downloads_title') ??
                    'Downloads',
                context))
            ..add(const SizedBox(height: 8))
            ..add(_buildActionCard(context,
                width: double.infinity,
                icon: Icons.download_rounded,
                label: AppLocalizations.of(context)
                        ?.translate('downloads_title') ??
                    'Downloads',
                trailing: Icons.chevron_right, onTap: () {
              Navigator.pop(context);
              Navigator.push(rootContext,
                  MaterialPageRoute(builder: (_) => const DownloadsScreen()));
            }));
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
                      Navigator.pop(context);
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
      BuildContext context, BookmarkNotesNotifier state, int surah, int verse) {
    final chips = <Widget>[];
    final existingColor =
        state.bookmarkForVerse(surah, verse)?.colorHex.toLowerCase();
    for (var i = 0; i < _bookmarkColors.length; i++) {
      final hex = _bookmarkColors[i];
      final color = Color(_parseColor(hex));
      final isSelected = existingColor == hex.toLowerCase();
      chips.add(Padding(
        padding: const EdgeInsets.only(right: 10),
        child: InkWell(
          onTap: () {
            Navigator.pop(context);
            if (isSelected) {
              state.deleteBookmark(surah, verse);
            } else {
              state.saveBookmark(
                  surahId: surah,
                  ayahId: verse,
                  colorHex: hex,
                  category: _getCategoryName(hex));
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
          icon: Icons.note_add_outlined,
          label: AppLocalizations.of(context)?.translate('write_note') ??
              'Write note',
          trailing: Icons.chevron_right, onTap: () {
        Navigator.pop(context);
        unawaited(_openNoteSheet(rootContext, state, surah, verse));
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
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) =>
                VerseDetailsScreen(surahNumber: surah, ayahNumber: verse)));
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
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
  }

  String _getCategoryName(String hex) {
    if (hex.toUpperCase() == '#EF5350') return 'Red';
    if (hex.toUpperCase() == '#FFB300') return 'Yellow';
    if (hex.toUpperCase() == '#66BB6A') return 'Green';
    if (hex.toUpperCase() == '#42A5F5') return 'Blue';
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
        return AppLocalizations.of(context)?.translate('downloads_title') ??
            'Downloads';
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
