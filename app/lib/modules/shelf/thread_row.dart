// Something passed between them — a book, a film, a record — in the thread, as the card off a
// shelf: what it is, and how far the other one has got.
import 'package:flutter/material.dart';

import '../../material/hands.dart';
import '../../material/palette.dart';
import '../../spine/spine.dart';
import '../../thread/note_body.dart';

Widget shelfCard(NoteContext c) {
  final p = c.event.payload;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Written('${p['title'] ?? ''}', by: c.event.author, size: 18),
      const SizedBox(height: 3),
      Stamped(
        switch ('${p['action']}') {
          'started' => 'started',
          'finished' => 'finished',
          _ => 'passed on',
        },
        size: 9,
        colour: Pen.margin,
      ),
    ],
  );
}

String shelfSentence(Event e, String who) => switch ('${e.payload['action']}') {
  'started' => '$who started ${e.payload['title']}',
  'finished' => '$who finished ${e.payload['title']}',
  _ => '$who passed on ${e.payload['title']}',
};
