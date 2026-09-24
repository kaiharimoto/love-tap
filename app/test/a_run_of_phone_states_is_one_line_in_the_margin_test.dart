// A run of phone states between two things said is one line in the margin.
//
// 02_chat, the hero, showed eight full-width strips of "noor's phone is on normal", "noor went
// out", "you got in" and not one written message. The fold is a view (state_runs.dart): every
// state row stays in the projection -- search, the read marker and every scene's anchor index it
// -- and a run is drawn once, on its newest row, as one sentence naming what changed.
//
// Re-break by making StateRuns fold nothing (every row closes its own run of one) and the first
// case fails on the eight rows drawn between the two messages.
import 'package:desk/regions/chat/state_runs.dart';
import 'package:desk/spine/event.dart';
import 'package:desk/spine/projections/thread.dart';
import 'package:flutter_test/flutter_test.dart';

var _seq = 0;
Event _e(Person by, String type, Map<String, dynamic> payload) {
  _seq++;
  return Event(
    id: 'row$_seq',
    seq: _seq,
    author: by,
    device: by == Person.noor ? DeviceKind.android : DeviceKind.pwa,
    // an hour apart, so the projection's once-an-hour filter on a phone's reports keeps them all
    ts: DateTime.utc(2026, 9, 3, 8).add(Duration(hours: _seq)).millisecondsSinceEpoch,
    type: type,
    payload: payload,
  );
}

Event _state(Person by, String signal, Object value, {bool passive = false}) =>
    _e(by, passive ? 'state_passive' : 'state_declared', {'signal': signal, 'value': value});

void main() {
  test('eight states between two messages are one row, and all eight stay in the thread', () {
    _seq = 0;
    final items = projectThread([
      _e(Person.teo, 'message', {'text': 'on the train'}),
      _state(Person.noor, 'ringer', 'silent', passive: true),
      _state(Person.noor, 'at_home', false, passive: true),
      _state(Person.noor, 'mood', 'restless'),
      _state(Person.noor, 'ringer', 'normal', passive: true),
      _state(Person.teo, 'at_home', true, passive: true),
      _state(Person.noor, 'need', 3),
      _state(Person.noor, 'place', 'travelling'),
      _state(Person.teo, 'energy', 1),
      _e(Person.noor, 'message', {'text': 'call me when you land'}),
    ]).items;
    // the population: nothing is folded out of the projection
    expect(
      items.length,
      10,
      reason:
          'the projection dropped state rows, so the fold has nothing '
          'to fold and this test would pass for the wrong reason',
    );
    expect(items.where(isStateRow).length, 8);

    final runs = StateRuns(items);
    final drawn = [
      for (var i = 0; i < items.length; i++)
        if (!runs.folded.contains(i)) i,
    ];
    final between = drawn.where((i) => isStateRow(items[i])).toList();
    expect(between, [8], reason: 'the eight states between the messages drew as rows $between');
    expect(runs.closing(8), hasLength(8));
    expect(runs.closing(0), isNull);

    final said = runSentence(runs.closing(8)!, me: Person.teo);
    // ignore: avoid_print
    print(said);
    // what is true now, once each: the ringer went silent and back, and says `normal` only
    expect(said, contains('normal'));
    expect(said, isNot(contains('silent')));
    for (final what in ['went out', 'restless', 'a lot', 'travelling', 'you got in', 'a little']) {
      expect(said, contains(what), reason: 'the folded line does not say "$what": $said');
    }
    // and the name is said once per turn of speaker, not once per change
    expect('noor'.allMatches(said).length, lessThanOrEqualTo(2), reason: said);
    expect(said, isNot(contains('· ·')), reason: 'a part of the line came out empty: $said');
  });

  test('a single state between two messages is its own row, said as before', () {
    _seq = 0;
    final items = projectThread([
      _e(Person.teo, 'message', {'text': 'home?'}),
      _state(Person.noor, 'at_home', true, passive: true),
      _e(Person.noor, 'message', {'text': 'yes'}),
    ]).items;
    final runs = StateRuns(items);
    expect(runs.folded, isEmpty);
    expect(runSentence(runs.closing(1)!, me: Person.teo), 'noor got in');
  });

  test('two runs a message apart stay two rows', () {
    _seq = 0;
    final items = projectThread([
      _state(Person.noor, 'mood', 'calm'),
      _state(Person.noor, 'energy', 2),
      _e(Person.noor, 'message', {'text': 'ok'}),
      _state(Person.noor, 'mood', 'low'),
      _state(Person.noor, 'energy', 0),
    ]).items;
    final runs = StateRuns(items);
    expect(runs.folded, {0, 3});
    expect(runs.closing(1), hasLength(2));
    expect(runs.closing(4), hasLength(2));
  });
}
