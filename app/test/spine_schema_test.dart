// The registry and docs/EVENT_TYPES.md must list the same types, and there must be at least fourteen.
import 'dart:io';

import 'package:desk/spine/types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('registry matches docs/EVENT_TYPES.md', () {
    final doc = File('../docs/EVENT_TYPES.md').readAsStringSync();
    final documented = RegExp(r'^\| \d+ \| `([a-z_]+)` \|', multiLine: true)
        .allMatches(doc)
        .map((m) => m.group(1)!)
        .toList();
    final registered = kEventTypes.map((t) => t.id).toList();
    expect(documented, registered);
    expect(registered.length, greaterThanOrEqualTo(14));
    expect(registered.toSet().length, registered.length);
  });

  test('every required type from the brief is present', () {
    const required = [
      'message', 'photo', 'video', 'voice_note', 'reaction', 'message_edit', 'message_delete', 'read_marker',
      'feeling', 'state_declared', 'state_passive', 'date_event', 'todo_event', 'milestone', 'ritual_kept',
      'ping', 'feeling_authored',
    ];
    for (final t in required) {
      expect(kEventTypeById.containsKey(t), isTrue, reason: t);
    }
  });

  test('read markers and reactions are never rows in the thread', () {
    expect(kEventTypeById['read_marker']!.rowInThread, isFalse);
    expect(kEventTypeById['reaction']!.rowInThread, isFalse);
  });

  test('payload validation', () {
    expect(specOf('message').validate({'text': 'hi'}), isNull);
    expect(specOf('message').validate({}), isNotNull);
    expect(specOf('message').validate({'text': 'hi', 'bogus': 1}), isNotNull);
    expect(specOf('feeling').validate({'feeling_id': 'squeeze', 'intensity': 0.5}), isNull);
  });
}
