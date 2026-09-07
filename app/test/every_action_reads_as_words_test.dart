// Every action a module can write reads as words, wherever the sentence turns up.
//
// docs/EVENT_TYPES.md declares each module type's action vocabulary in the row that defines the
// type — `action (added/assigned/done/reopened/removed)` — and that is the list a projection folds
// and a seeded year contains. Nothing was holding the app's own words to it, and they had drifted
// all the way: the list module's sentence knew `ticked`/`unticked`/`dropped`, which the module has
// never written, so ninety-five `done` events and forty-three `reopened` ones in the seeded year
// read as their own text with a space in front of it — in search hits, in notification bodies and
// in the standing line on the lock screen. The thread row had the same three wrong words, so a
// finished job drew an empty pencil box captioned "put down" while Us showed it ticked and struck
// through: one event, two surfaces, opposite meanings.
//
// So the doc row is the vocabulary, and this reads it.
import 'dart:io';

import 'package:desk/spine/spine.dart';
import 'package:desk/thread/renderers.dart';
import 'package:flutter_test/flutter_test.dart';

/// `| 13 | `todo_event` | `todo_id`, `action` (added/assigned/done/…), … |` → todo_event: [...]
Map<String, List<String>> _declaredActions() {
  final doc = File('../docs/EVENT_TYPES.md').readAsStringSync();
  final out = <String, List<String>>{};
  final row = RegExp(r'\|\s*\d+\s*\|\s*`([a-z_]+)`\s*\|(.*)');
  for (final line in doc.split('\n')) {
    final m = row.firstMatch(line);
    if (m == null) continue;
    final actions = RegExp(r'`action`\s*\(([a-z/]+)\)').firstMatch(m.group(2)!);
    if (actions == null) continue;
    out[m.group(1)!] = actions.group(1)!.split('/');
  }
  return out;
}

void main() {
  test('every declared action reads as words away from the thread', () {
    final declared = _declaredActions();
    expect(declared.keys, containsAll(<String>['date_event', 'todo_event', 'passed_on']),
        reason: 'the doc rows that declare an action vocabulary were not found');

    final wrong = <String>[];
    declared.forEach((type, actions) {
      final spec = kEventTypeById[type]!;
      for (final action in actions) {
        final payload = <String, dynamic>{
          for (final k in spec.required) k: _value(k),
          'action': action,
        };
        final e = Event(
          id: '01J0',
          seq: 1,
          author: Person.noor,
          device: DeviceKind.android,
          ts: DateTime.utc(2026, 4, 22, 16, 30).millisecondsSinceEpoch,
          type: type,
          payload: payload,
        );
        final line = summaryOf(e, me: Person.teo);
        // and the same event with an action nobody has ever written, to see what the fall-through
        // says. A declared action that reads exactly like an undeclared one is not handled: this
        // is how `ticked`/`unticked`/`dropped` sat in the list module's table for five cycles
        // while the module wrote `done`/`reopened`/`removed`, and every sentence still came out
        // as words, just not the right ones.
        final unknown = summaryOf(
          Event(
            id: '01J0',
            seq: 1,
            author: Person.noor,
            device: DeviceKind.android,
            ts: e.ts,
            type: type,
            payload: {...payload, 'action': 'nothing anybody writes'},
          ),
          me: Person.teo,
        );
        final body = (payload['text'] ?? payload['title']) as String;
        if (line == unknown) {
          wrong.add('$type/$action: reads the same as an action nobody writes — "$line"');
        }
        if (line.trim() != line) wrong.add('$type/$action: "$line" has space around it');
        if (line.contains('  ')) wrong.add('$type/$action: "$line" has a gap in it');
        if (line.trim() == body) {
          wrong.add('$type/$action: "$line" says nothing about what happened');
        }
        if (!line.contains(body)) wrong.add('$type/$action: "$line" has lost the thing itself');
        if (line.contains('_')) wrong.add('$type/$action: "$line" shows a key');
      }
    });
    expect(wrong, isEmpty, reason: 'an action the docs declare and a module writes:\n${wrong.join('\n')}');
  });
}

Object _value(String key) => switch (key) {
      'date' || 'kept_at' || 'when' || 'fires_at' => '2026-04-23T16:00:00Z',
      'yearly' => true,
      'kind' => 'book',
      'action' => 'added',
      _ => 'the canal',
    };
