// A feeling one of them made, in the thread: the object itself, its name in their hand, and whose
// it is. A feeling that somebody drew is not an announcement about the app; it is a new word in
// the language the two of them are writing, so it arrives as the thing and not as a notice.
import 'package:flutter/material.dart';

import 'builtins.dart';
import '../material/hands.dart';
import '../material/objects.dart';
import '../thread/note_body.dart';

Widget newFeelingCard(NoteContext c) {
  final p = c.event.payload;
  final f = c.registry.byId('${p['feeling_id']}');
  return Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      if (f != null) FeelingObject(feeling: f, size: 58, intensity: 0.7),
      if (f != null) const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Written('${p['name'] ?? f?.name ?? ''}', by: c.event.author, size: 18),
            Text(
              'a new one, ${c.event.author == c.me ? 'yours' : c.event.author.name}\'s · '
              '${p['family'] ?? f?.family.label ?? ''}',
              style: Hands.margin(size: 12),
            ),
          ],
        ),
      ),
    ],
  );
}
