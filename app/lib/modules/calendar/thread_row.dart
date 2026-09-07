// A day that matters, in the thread: stamped, with its date, the way a card is kept.
import 'package:flutter/material.dart';

import '../../material/hands.dart';
import '../../spine/spine.dart';
import '../../thread/note_body.dart';

Widget stampedCard(NoteContext c) {
  final p = c.event.payload;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Stamped('${p['title'] ?? ''}', size: 11.5),
      const SizedBox(height: 5),
      Text(
        dayLabel(p['date']).isEmpty ? whenLabel(p['date']) : dayLabel(p['date']),
        style: Hands.margin(size: 13),
      ),
    ],
  );
}

String milestoneSentence(Event e) => '${e.payload['title']} · ${whenLabel(e.payload['date'])}';
