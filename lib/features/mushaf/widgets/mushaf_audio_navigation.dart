import 'dart:math';

import 'package:flutter/material.dart';
import 'package:quran_app/core/services/audio_player_service.dart';
import 'package:quran_app/core/services/audio_service.dart';
import 'package:quran_app/data/models/audio_model.dart';
import 'package:quran_app/features/downloads/audio_surah_list_page.dart';

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

  final chosen = await showModalBottomSheet<AudioRecitation>(
    context: context,
    builder: (context) {
      final maxHeight = min(MediaQuery.of(context).size.height * 0.7, 520.0);
      return SafeArea(
        child: SizedBox(
          height: maxHeight,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              const Padding(
                padding: EdgeInsets.all(12.0),
                child: Text('Choose Reciter',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: recitations.length,
                  itemBuilder: (context, index) {
                    final r = recitations[index];
                    return ListTile(
                      title: Text(r.reciterName),
                      subtitle: r.style != null ? Text(r.style!) : null,
                      onTap: () => Navigator.pop(context, r),
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

  if (chosen != null) {
    audioPlayer.setRecitationInfo(id: chosen.id, name: chosen.reciterName);
  }
  return chosen;
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
