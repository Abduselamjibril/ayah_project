import 'dart:math';

import 'package:flutter/material.dart';
import 'package:quran_app/core/services/audio_player_service.dart';
import 'package:quran_app/core/services/audio_service.dart';
import 'package:quran_app/data/models/audio_model.dart';
import 'package:quran_app/features/downloads/audio_surah_list_page.dart';
import 'package:quran_app/app/app.dart';
import 'package:quran_app/core/i18n/app_localizations.dart';

Future<AudioRecitation?> ensureMushafReciterSelected(
  BuildContext context,
  AudioPlayerService audioPlayer, {
  AudioRecitation? selected,
  bool force = false,
}) async {
  if (!force && selected != null) return selected;

  await AudioService.instance.initialize();
  final recitations = await AudioService.instance.getAvailableRecitations();
  if (!context.mounted) return null;

  final chosen = await showReciterPickerSheet(context, recitations);

  if (chosen != null) {
    audioPlayer.setRecitationInfo(id: chosen.id, name: chosen.reciterName);
  }
  return chosen;
}

Future<AudioRecitation?> showReciterPickerSheet(
  BuildContext context,
  List<AudioRecitation> recitations,
) async {
  final result = await showModalBottomSheet<AudioRecitation>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final media = MediaQuery.of(ctx);
      final maxHeight = min(media.size.height * 0.9, 720.0);
      final theme = Theme.of(ctx);
      final cardColor = theme.colorScheme.surfaceVariant.withOpacity(0.9);
      final bgColor = theme.colorScheme.surface;
      return SafeArea(
        child: Center(
          child: Container(
            height: maxHeight,
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: StatefulBuilder(
              builder: (context, setState) {
                final searchController = TextEditingController();
                // Dispose controller when modal closes
                void closeModal([AudioRecitation? result]) {
                  searchController.dispose();
                  Navigator.of(context).pop(result);
                }

                final query = searchController.text.trim().toLowerCase();
                final filtered = recitations.where((r) {
                  final name = r.reciterName.toLowerCase();
                  final style = (r.style ?? '').toLowerCase();
                  return query.isEmpty ||
                      name.contains(query) ||
                      style.contains(query);
                }).toList();

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          TextButton(
                            onPressed: () {},
                            style: TextButton.styleFrom(
                              foregroundColor: BrandColors.accent,
                            ),
                            child: Text(
                              AppLocalizations.of(context)?.translate('edit') ??
                                  'Edit',
                            ),
                          ),
                          const Spacer(),
                          Text(
                            AppLocalizations.of(context)
                                    ?.translate('select_recitation') ??
                                'Select Recitation',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.close, size: 18),
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.8),
                              onPressed: () => closeModal(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color:
                                theme.colorScheme.onSurface.withOpacity(0.12),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search,
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.6)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: searchController,
                                decoration: InputDecoration(
                                  hintText: 'Search',
                                  hintStyle:
                                      theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.6),
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'All Recitations',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: maxHeight * 0.5,
                        child: ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: filtered.length,
                          shrinkWrap: true,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final r = filtered[index];
                            return InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => closeModal(r),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 14),
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.onSurface
                                            .withOpacity(0.08),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.volume_up_outlined,
                                        size: 20,
                                        color: theme.colorScheme.onSurface
                                            .withOpacity(0.7),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            r.reciterName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16,
                                            ),
                                          ),
                                          if (r.style != null &&
                                              r.style!.trim().isNotEmpty)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 2),
                                              child: Text(
                                                r.style!,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: theme
                                                      .colorScheme.onSurface
                                                      .withOpacity(0.7),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: BrandColors.accent),
                                      ),
                                      child: const Icon(
                                        Icons.info_outline,
                                        size: 18,
                                        color: BrandColors.accent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
    },
  );
  return result;
}

Future<void> navigateToMushafAudioDownloads(
  BuildContext context, {
  required int recitationId,
  required String reciterName,
}) async {
  if (!context.mounted) return;
  final recitation =
      AudioRecitation(id: recitationId, reciterName: reciterName);
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AudioSurahListPage(recitation: recitation),
    ),
  );
}
