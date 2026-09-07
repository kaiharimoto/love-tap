// A date in the thread: a ticket stub.
//
// The plan stamped along the top, the title in the hand that wrote it, and the day and the place
// under a perforation. It is on the module's own paper — an index card, which is what `stocks`
// says — so the same event is the same piece of paper in Us, in Moments and here.
import 'package:flutter/material.dart';

import '../../material/hands.dart';
import '../../material/marks.dart';
import '../../material/palette.dart';
import '../../spine/spine.dart';
import '../../thread/note_body.dart';

Widget ticketStub(NoteContext c) {
  final p = c.event.payload;
  final when = p['when'] == null ? '' : whenLabel(p['when']);
  final place = (p['place'] as String?) ?? '';
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        children: [
          Stamped(
            dateVerb(p['action']).trim().isEmpty ? 'a date' : dateVerb(p['action']).trim(),
            size: 9,
            colour: Pen.margin,
          ),
          const Spacer(),
          if (when.isNotEmpty) Text(when, style: Hands.margin(size: 12)),
        ],
      ),
      const SizedBox(height: 4),
      Written('${p['title'] ?? ''}', by: c.event.author, size: 18),
      if (place.isNotEmpty) ...[
        const SizedBox(height: 2),
        Text(place, style: Hands.margin(size: 13)),
      ],
      const Padding(padding: EdgeInsets.only(top: 6), child: RuleLine(seed: 41, weight: 0.8)),
    ],
  );
}

/// What was done to a date, in the words a person would use about their own week.
String dateVerb(Object? action) => switch ('$action') {
  'planned' => 'planning',
  'said' => 'said of',
  'remembered' => 'remembering',
  'scheduled' => 'booked',
  'moved' => 'moved',
  'done' || 'been' => 'went to',
  'cancelled' => 'called off',
  _ => '',
};

/// The same date as one sentence, for search, a notification and the standing line.
String dateSentence(Event e) {
  final p = e.payload;
  final where = (p['place'] as String?)?.isNotEmpty == true ? ' at ${p['place']}' : '';
  final when = p['when'] == null ? '' : ' · ${whenLabel(p['when'])}';
  return '${dateVerb(p['action'])} ${p['title']}$where$when';
}
