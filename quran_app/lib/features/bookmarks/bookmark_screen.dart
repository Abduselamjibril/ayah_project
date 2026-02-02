import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quran_app/core/i18n/app_localizations.dart';
import 'package:quran_app/core/utils/localization_helper.dart';

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

  static const List<Map<String, String>> _colorCategories = [
    {'name': 'Red', 'hex': '#EF5350'},
    {'name': 'Yellow', 'hex': '#FFB300'},
    {'name': 'Green', 'hex': '#66BB6A'},
    {'name': 'Blue', 'hex': '#42A5F5'},
  ];

  @override
  Widget build(BuildContext context) {
    // We use watch to rebuild when bookmarks or the quickBookmarkColor changes
    final state = Provider.of<BookmarkNotesNotifier>(context, listen: true);

    if (!state.isInitialized && !state.isLoading) {
      state.initialize();
    }

    // Filtered list based on category selection (the cards at the top)
    final filteredBookmarks = _selectedColor == null
        ? state.bookmarks
        : state.bookmarks
            .where((b) => _isSameColor(b.colorHex, _selectedColor!))
            .toList();

    return Scaffold(
      backgroundColor: Colors.black, // Pure black like iOS dark mode
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: SizedBox(
          width: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Centered Title
              Center(
                child: Text(
                  AppLocalizations.of(context)?.translate('bookmarks_title') ??
                      'Bookmarks',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
              // Far left back icon
              Positioned(
                left: 0,
                child: IconButton(
                  icon: const Icon(Icons.chevron_left,
                      color: Color(0xFF4CAF50), size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              // Far right close icon
              Positioned(
                right: 0,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: CircleAvatar(
                    radius: 15,
                    backgroundColor: Colors.white10,
                    child: const Icon(Icons.close,
                        size: 18, color: Colors.white60),
                  ),
                ),
              ),
            ],
          ),
        ),
        toolbarHeight: 56,
      ),
      body: state.isLoading && !state.isInitialized
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Permanent Color Category Cards
                  _buildGroupedContainer(
                    children: _colorCategories.map((cat) {
                      // Find the latest bookmark in this specific color category
                      final latest = state.bookmarks.firstWhere(
                        (b) => _isSameColor(b.colorHex, cat['hex']!),
                        orElse: () => Bookmark(
                          surahId: 0,
                          ayahId: 0,
                          colorHex: cat['hex']!,
                          createdAt: DateTime.now(),
                          updatedAt: DateTime.now(),
                        ),
                      );

                      return _buildCategoryTile(
                        context,
                        cat['name']!,
                        cat['hex']!,
                        latest,
                        state, // Pass state to check global quick color
                        onTap: () {
                          setState(() {
                            // This filters the list below
                            _selectedColor = (_selectedColor == cat['hex'])
                                ? null
                                : cat['hex'];
                          });
                        },
                        isSelected: _selectedColor == cat['hex'],
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 32),

                  // 2. List of Bookmarks Header
                  if (filteredBookmarks.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                      child: Text(
                        _selectedColor == null
                            ? "All Bookmarks"
                            : "Filtered Bookmarks",
                        style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                            fontWeight: FontWeight.bold),
                      ),
                    ),

                  // 3. The List of Bookmarks
                  _buildGroupedContainer(
                    children: filteredBookmarks.map((b) {
                      return _buildBookmarkEntryTile(context, b);
                    }).toList(),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildGroupedContainer({required List<Widget> children}) {
    if (children.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E), // iOS Secondary Fill
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: List.generate(children.length, (index) {
          return Column(
            children: [
              children[index],
              if (index != children.length - 1)
                const Divider(height: 1, indent: 56, color: Color(0xFF38383A)),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildCategoryTile(BuildContext context, String name, String hex,
      Bookmark latest, BookmarkNotesNotifier state,
      {required VoidCallback onTap, required bool isSelected}) {
    final bool hasData = latest.surahId != 0;
    final color = Color(_parseColor(hex));

    // Check if THIS specific tile's color is the one set as the global Quick Bookmark
    final isQuickBookmarkColor =
        _isSameColor(state.quickBookmarkColor ?? '#EF5350', hex);

    return ListTile(
      onTap: onTap,
      dense: true,
      tileColor: isSelected ? Colors.white.withOpacity(0.05) : null,
      leading: GestureDetector(
        onTap: () {
          // UPDATE: Save this color as the global quick choice
          state.setQuickBookmarkColor(hex);
        },
        child: Icon(
          isQuickBookmarkColor ? Icons.bookmark : Icons.bookmark_outline,
          color: color,
          size: 28,
        ),
      ),
      title: Text(
        name,
        style: const TextStyle(
            color: Colors.white, fontSize: 17, fontWeight: FontWeight.w400),
      ),
      subtitle: hasData
          ? Text(
              '${_formatTime(latest.updatedAt)}  ${getBilingualSurahName(context, latest.surahId)}: ${latest.ayahId}',
              style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
            )
          : const Text('No items',
              style: TextStyle(color: Color(0xFF48484A), fontSize: 14)),
      trailing: isSelected
          ? const Icon(Icons.check, color: Color(0xFF4CAF50), size: 20)
          : null,
    );
  }

  Widget _buildBookmarkEntryTile(BuildContext context, Bookmark b) {
    final name = getBilingualSurahName(context, b.surahId);
    final color = Color(_parseColor(b.colorHex));

    return Dismissible(
      key: ValueKey('entry_${b.surahId}_${b.ayahId}_${b.updatedAt}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) =>
          Provider.of<BookmarkNotesNotifier>(context, listen: false)
              .deleteBookmark(b.surahId, b.ayahId),
      child: ListTile(
        onTap: () {
          // Action for navigating to verse could be added here
        },
        leading: Icon(Icons.bookmark, color: color, size: 24),
        title: Text('$name: ${b.ayahId}',
            style: const TextStyle(color: Colors.white, fontSize: 16)),
        subtitle: Text(_formatTime(b.updatedAt),
            style: const TextStyle(color: Colors.grey, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: Color(0xFF38383A)),
      ),
    );
  }

  bool _isSameColor(String hex1, String hex2) {
    return hex1.replaceAll('#', '').toUpperCase() ==
        hex2.replaceAll('#', '').toUpperCase();
  }

  String _formatTime(DateTime? date) {
    if (date == null) return '';
    final hour =
        date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = (date.hour >= 18 || date.hour < 5) ? 'at night' : 'at day';
    return '$hour:$minute $period';
  }

  int _parseColor(String hex) {
    final normalized = hex.replaceAll('#', '');
    return int.tryParse('FF$normalized', radix: 16) ?? 0xFF8E8E93;
  }
}
