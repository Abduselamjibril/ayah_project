import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quran_app/core/i18n/app_localizations.dart';

import 'state/bookmark_notes_notifier.dart';
import 'data/models/bookmark.dart';
import '../../core/quran/qcf_quran.dart';

class BookmarkScreen extends StatefulWidget {
  const BookmarkScreen({super.key});

  @override
  State<BookmarkScreen> createState() => _BookmarkScreenState();
}

class _BookmarkScreenState extends State<BookmarkScreen> {
  String? _selectedColor;

  static const List<String> _filterColors = [
    '#EF5350', // Red
    '#FFB300', // Yellow
    '#66BB6A', // Green
    '#42A5F5', // Blue
  ];

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<BookmarkNotesNotifier>(context, listen: true);
    if (!state.isInitialized && !state.isLoading) {
      // Kick off loading on first open
      // ignore: discarded_futures
      state.initialize();
    }

    final allBookmarks = state.bookmarks;
    final displayedBookmarks = _selectedColor == null
        ? allBookmarks
        : allBookmarks.where((b) {
            // Compare normalized hex
            final bColor = b.colorHex.replaceAll('#', '').toUpperCase();
            final fColor = _selectedColor!.replaceAll('#', '').toUpperCase();
            // Also handle if stored color has extra FF transparency or similar if needed,
            // but usually they match if we stick to the palette.
            // Let's do a contains check or exact match ignoring #
            return bColor.contains(fColor) || fColor.contains(bColor);
          }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)?.translate('bookmarks_title') ??
              'Bookmarks',
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: _filterColors.map((hex) {
                final isSelected = _selectedColor == hex;
                final color = Color(_parseColor(hex));
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text(''),
                    selected: isSelected,
                    showCheckmark: false,
                    backgroundColor: color.withOpacity(0.2),
                    selectedColor: color,
                    shape: CircleBorder(
                      side: BorderSide(
                        color: isSelected ? Colors.transparent : color,
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.all(4),
                    onSelected: (selected) {
                      setState(() {
                        _selectedColor = selected ? hex : null;
                      });
                    },
                    avatar: isSelected
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
      body: state.isLoading && !state.isInitialized
          ? const Center(child: CircularProgressIndicator())
          : _BookmarkList(bookmarks: displayedBookmarks),
    );
  }

  int _parseColor(String hex) {
    try {
      final normalized = hex.replaceAll('#', '');
      if (normalized.isEmpty) return 0xFFD54F;
      final value = int.tryParse(normalized, radix: 16) ?? 0xFFD54F;
      return 0xFF000000 | value;
    } catch (_) {
      return 0xFFD54F;
    }
  }
}

class _BookmarkList extends StatelessWidget {
  final List<Bookmark> bookmarks;
  const _BookmarkList({required this.bookmarks});

  @override
  Widget build(BuildContext context) {
    if (bookmarks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No bookmarks found',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: bookmarks.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final b = bookmarks[index];
        final name = getSurahName(b.surahId);
        final colorInt = _parseColor(b.colorHex);

        return Dismissible(
          key: ValueKey('${b.surahId}:${b.ayahId}'),
          direction: DismissDirection.horizontal,
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          secondaryBackground: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (direction) {
            Provider.of<BookmarkNotesNotifier>(context, listen: false)
                .deleteBookmark(b.surahId, b.ayahId);
          },
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Color(colorInt).withOpacity(0.25),
              child: Text(
                b.ayahId.toString(),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(colorInt).withOpacity(1.0),
                ),
              ),
            ),
            title: Text('$name • ${b.surahId}:${b.ayahId}'),
            subtitle: b.categoryName != null && b.categoryName!.isNotEmpty
                ? Text(b.categoryName!)
                : null,
            onTap: () {
              // Navigate to verse
              // Assuming we have a way to navigate back to main mushaf or standard nav
              // For now, we didn't implement tap-to-navigate in the prompt, but it's good UX.
              // Let's leave it as is per instructions to just fix delete/filter.
            },
          ),
        );
      },
    );
  }

  int _parseColor(String hex) {
    try {
      final normalized = hex.replaceAll('#', '');
      if (normalized.isEmpty) return 0xFFD54F;
      final value = int.tryParse(normalized, radix: 16) ?? 0xFFD54F;
      return 0xFF000000 | value;
    } catch (_) {
      return 0xFFD54F;
    }
  }
}
