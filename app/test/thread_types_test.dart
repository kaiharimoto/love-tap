// The registry's promise, checked.
//
// docs/EVENT_TYPES.md and spine/types.dart both say that adding an event type is one entry in the
// registry and one renderer. That was not true for most of this build's life: the `renderer` field
// named a directory that did not exist, nothing read it, and the thread and the search results
// each kept their own copy of a per-type switch. A type added to one and forgotten in the other
// rendered correctly in the thread and as a bare registry id in search, and nothing failed.
//
// These are the cheapest guards against that coming back.
import 'package:desk/regions/chat/renderers.dart';
import 'package:desk/spine/event.dart';
import 'package:desk/spine/types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every event type names a renderer that exists', () {
    for (final spec in kEventTypes) {
      expect(kThreadRenderers.containsKey(spec.renderer), isTrue,
          reason: '${spec.id} names the renderer "${spec.renderer}", which is not in '
              'regions/chat/renderers.dart');
    }
  });

  test('every renderer is named by at least one event type', () {
    final named = {for (final s in kEventTypes) s.renderer};
    for (final id in kThreadRenderers.keys) {
      expect(named.contains(id), isTrue,
          reason: 'the renderer "$id" is not declared by any type, so nothing can reach it');
    }
  });

  test('every event type reads as a sentence away from the thread', () {
    // Search results, notification bodies and the standing line all come through summaryOf, so a
    // type that has not been given one shows its registry id to a person, which is the failure
    // this replaced.
    for (final spec in kEventTypes) {
      final payload = <String, dynamic>{
        for (final k in spec.required) k: _plausible(k),
      };
      final e = Event(
        id: '01J0', seq: 1, author: Person.noor, device: DeviceKind.android,
        ts: DateTime.utc(2026, 4, 22, 16, 30).millisecondsSinceEpoch,
        type: spec.id, payload: payload,
      );
      final line = summaryOf(e, me: Person.teo);
      expect(line.trim(), isNotEmpty, reason: '${spec.id} has no sentence');
      expect(line, isNot(equals(spec.id)),
          reason: '${spec.id} falls through to showing its own registry id');
      expect(line, isNot(contains('_')),
          reason: '${spec.id} shows a key rather than words: "$line"');
    }
  });

  test('the types that are never rows say so', () {
    for (final spec in kEventTypes) {
      if (spec.rowInThread) continue;
      expect(kThreadRenderers[spec.renderer], isNotNull);
    }
    // read markers in particular: they move a mark, they are not a line of their own
    final marker = kEventTypeById['read_marker']!;
    expect(marker.rowInThread, isFalse);
  });
}

Object _plausible(String key) => switch (key) {
      'text' => 'the folder is open',
      'caption' => 'the folder is open',
      'w' || 'h' => 1200,
      'duration_ms' => 52000,
      'intensity' => 0.8,
      'signal' => 'mood',
      'value' => 'tender',
      'feeling_id' => 'hold',
      'title' => 'the ferry',
      'name' => 'empty chair',
      'ritual' => 'text when home',
      'done' => false,
      'upto_seq' => 12,
      'at' => '2026-07-18T09:00:00+01:00',
      _ => 'x',
    };
