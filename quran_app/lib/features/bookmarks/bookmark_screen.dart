import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'state/bookmark_notes_notifier.dart';
import 'data/models/bookmark.dart';
import '../../core/quran/qcf_quran.dart';

class BookmarkScreen extends StatelessWidget {
  const BookmarkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<BookmarkNotesNotifier>(context, listen: true);
    if (!state.isInitialized && !state.isLoading) {
      // Kick off loading on first open
      // ignore: discarded_futures
      state.initialize();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookmarks'),
      ),
      body: state.isLoading && !state.isInitialized
          ? const Center(child: CircularProgressIndicator())
          : _BookmarkList(bookmarks: state.bookmarks),
    );
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
            'No bookmarks yet',
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
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Color(_parseColor(b.colorHex)).withOpacity(0.25),
            child: Text(
              b.ayahId.toString(),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          title: Text('$name • ${b.surahId}:${b.ayahId}'),
          subtitle: b.categoryName != null && b.categoryName!.isNotEmpty
              ? Text(b.categoryName!)
              : null,
        );
      },
    );
  }

  int _parseColor(String hex) {
    final normalized = hex.replaceAll('#', '');
    final value = int.tryParse(normalized, radix: 16) ?? 0xFFD54F;
    return 0xFF000000 | value;
  }
}
