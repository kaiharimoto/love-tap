// The app said "you's phone is nearly out", and nothing in the build could see it.
//
// `summaryOf` set `who` to the literal string 'you' when the event was the reader's own, and
// `_stateSentence` dropped that straight into templates written for a third-person subject. Ten
// sentences came out ungrammatical on the reader's own rows:
//
//     you's phone is nearly out      you's phone is on silent      you's signal is wifi
//     you was up an hour ago         it is nine where you is       you is tender
//     you is charging                you needs a little            you has a lot left
//     you has read up to here
//
// The queue item named five of them; the other five are the same mistake in `need`, `energy`,
// `charging`, the `is` signals and the read marker, and they were found by rendering every signal
// rather than by reading the five.
//
// **Why the string lint cannot catch this, which is the part worth keeping.**
// `tools/lint/strings.py` walks Dart literals that reach a display call and holds them against
// `docs/VOICE.md`. Every fragment above passes: `"$who's phone is on $words"` is a good sentence
// for every value `who` can take but one. The defect is created by composition, at runtime, and
// `docs/VOICE.md` is enforced over the string table while the string table is not every displayed
// string. So the enforcement has to be here, over the rendered output, with a real event going
// through the real renderer.
//
// This test renders EVERY signal in both persons. A list of five forbidden strings would have
// passed on a sixth.
import 'package:desk/regions/chat/renderers.dart';
import 'package:desk/spine/projections/state.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/voice/subject.dart';
import 'package:flutter_test/flutter_test.dart';

/// A value each signal will accept, in the shape `docs/SIGNALS.md` gives it.
Object _valueFor(String signal) => switch (signal) {
      'mood' => 'tender',
      'status_line' => 'at the desk until six',
      'availability' => 'heads down',
      'need' => 1,
      'energy' => 3,
      'place' => 'the canal',
      'battery' => 'low',
      'charging' => true,
      'last_active' => 'an hour ago',
      'local_hour' => 'nine',
      'ringer' => 'silent',
      'moving' => 'walking',
      'network' => 'wifi',
      'at_home' => true,
      _ => 'something',
    };

Event _state(String type, String signal, Person author) => Event(
      id: '01J0',
      seq: 1,
      author: author,
      device: author == Person.noor ? DeviceKind.android : DeviceKind.pwa,
      ts: DateTime.utc(2026, 4, 22, 16, 30).millisecondsSinceEpoch,
      type: type,
      payload: {'signal': signal, 'value': _valueFor(signal)},
    );

/// The shapes a second-person subject cannot take. Held as patterns rather than as the ten
/// strings, because the ten strings are the symptom.
final _malformed = <String, RegExp>{
  "a possessive on \"you\"": RegExp(r"\byou's\b"),
  'a third-person verb on "you"': RegExp(r'\byou (is|was|has|needs|does|goes|wants|says)\b'),
  'a second-person verb on a name': RegExp(r'\b(noor|teo) (are|were|have)\b'),
};

void main() {
  test('every signal reads as English about the person holding the phone', () {
    // Both state types, every signal, both ways round: the reader's own row and the other
    // person's. 2 x 14 x 2 = 56 sentences, and the item was filed on five.
    final seen = <String>[];
    for (final type in ['state_declared', 'state_passive']) {
      for (final signal in [...kDeclaredSignals, ...kPassiveSignals]) {
        for (final author in [Person.noor, Person.teo]) {
          final line = summaryOf(_state(type, signal, author), me: Person.teo);
          seen.add(line);
          for (final entry in _malformed.entries) {
            expect(entry.value.hasMatch(line), isFalse,
                reason: '$type/$signal about '
                    '${author == Person.teo ? 'the reader' : 'the other person'} reads '
                    '"$line", which is ${entry.key}');
          }
          expect(line.trim(), isNotEmpty, reason: '$type/$signal says nothing');
        }
      }
    }
    expect(seen.length, 56, reason: 'the signal lists changed shape under this test');
  });

  test('the reader is spoken to and the other person is spoken about', () {
    // Not only "no bad grammar": the two persons must actually differ, or a build that dropped
    // the first person entirely and said "teo" to Teo would pass everything above.
    String mine(String signal) =>
        summaryOf(_state('state_passive', signal, Person.teo), me: Person.teo);
    String theirs(String signal) =>
        summaryOf(_state('state_passive', signal, Person.noor), me: Person.teo);

    expect(mine('battery'), 'your phone is nearly out');
    expect(theirs('battery'), "noor's phone is nearly out");
    expect(mine('ringer'), 'your phone is on silent');
    expect(mine('network'), 'your signal is wifi');
    expect(mine('last_active'), 'you were up an hour ago');
    expect(mine('local_hour'), 'it is nine where you are');
    expect(mine('charging'), 'you are charging');
    expect(theirs('charging'), 'noor is charging');
    expect(mine('moving'), 'you are walking');

    expect(summaryOf(_state('state_declared', 'mood', Person.teo), me: Person.teo),
        'you are tender');
    expect(summaryOf(_state('state_declared', 'need', Person.teo), me: Person.teo),
        'you need a little');
    expect(summaryOf(_state('state_declared', 'energy', Person.teo), me: Person.teo),
        'you have a lot left');
    expect(summaryOf(_state('state_declared', 'need', Person.noor), me: Person.teo),
        'noor needs a little');
    expect(summaryOf(_state('state_declared', 'energy', Person.noor), me: Person.teo),
        'noor has a lot left');
  });

  test('a read marker is the eleventh, and it is not a state row', () {
    // Found by the same sweep and in a different switch: `read_marker` is a message-side type, so
    // a test that walked only the signals would have left it saying "you has read up to here".
    Event mark(Person author) => Event(
          id: '01J0', seq: 1, author: author, device: DeviceKind.pwa,
          ts: DateTime.utc(2026, 4, 22, 16, 30).millisecondsSinceEpoch,
          type: 'read_marker', payload: {'upto_seq': 3},
        );
    expect(summaryOf(mark(Person.teo), me: Person.teo), 'you have read up to here');
    expect(summaryOf(mark(Person.noor), me: Person.teo), 'noor has read up to here');
  });

  test('with nobody reading, every sentence is about a named person', () {
    // `summaryOf` is also called with no `me` — a notification composed before the app knows who
    // is looking. There is no second person in that case and there must be no "you" in the output
    // either, or the sentence is about nobody.
    for (final signal in [...kDeclaredSignals, ...kPassiveSignals]) {
      final line = summaryOf(_state('state_passive', signal, Person.noor));
      expect(line.contains('you'), isFalse,
          reason: 'with no reader, $signal still says "you": "$line"');
    }
  });

  test('the subject carries the grammar, so a new sentence cannot get it wrong quietly', () {
    // The type itself, because the next sentence about a person will be written by somebody who
    // has not read this file. Asking the subject is the only way to write it; there is no way to
    // interpolate a person that produces "you's".
    const you = Subject.you();
    const noor = Subject.named('noor');
    expect(you.possessive, 'your');
    expect(noor.possessive, "noor's");
    expect('$you', 'you');
    expect(you.be, 'are');
    expect(noor.be, 'is');
    expect(you.were, 'were');
    expect(noor.were, 'was');
    expect(you.have, 'have');
    expect(noor.have, 'has');
    expect(you.does('need'), 'need');
    expect(noor.does('need'), 'needs');
    expect(noor.does('miss'), 'misses');
  });
}
