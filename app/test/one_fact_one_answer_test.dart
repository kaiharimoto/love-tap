// The same fact, read off the same signal, by two surfaces that used to disagree by seven hours.
//
// `last_active` carries what the other phone reported at the moment it reported it: 0 means "up
// just now" *then*. The Pulse card read the value and wrote "LAST UP  just now"; the standing line
// read the event's timestamp and wrote "· 7 hours ago". Both were on the same screen, from the same
// signal, in all seventeen seeded reports — a coherence critic listed them.
//
// They are the same fact and the arithmetic is: what they said, plus how long ago they said it.
import 'package:desk/ambient/ambient.dart';
import 'package:desk/spine/event.dart';
import 'package:desk/spine/projections/state.dart';
import 'package:flutter_test/flutter_test.dart';

PersonState _state({required int reported, required int minutesAgo, int nowMs = 0}) {
  final at = nowMs - minutesAgo * 60000;
  return PersonState(Person.noor, {
    'mood': SignalValue(signal: 'mood', value: 'calm', at: at, declared: true),
    'last_active':
        SignalValue(signal: 'last_active', value: reported, at: at, declared: false),
  });
}

void main() {
  const now = 1788000000000;

  test('how long ago they were up counts from now, not from when they said it', () {
    // said "up just now", seven hours ago
    final stale = _state(reported: 0, minutesAgo: 420, nowMs: now);
    expect(stale.lastActiveMinutesAt(now), 420);
    // said "up twenty minutes ago", five minutes ago
    final fresh = _state(reported: 20, minutesAgo: 5, nowMs: now);
    expect(fresh.lastActiveMinutesAt(now), 25);
    // nothing said at all is not the same as zero
    final silent = PersonState(Person.noor, {
      'mood': SignalValue(signal: 'mood', value: 'calm', at: now, declared: true),
    });
    expect(silent.lastActiveMinutesAt(now), isNull);
  });

  test('and the standing line says the same thing the card says', () {
    final stale = _state(reported: 0, minutesAgo: 420, nowMs: now);
    final line = standingLine(Person.noor, stale, now);
    expect(line, contains('7 hours ago'));
    expect(line, isNot(contains('there now')));

    final here = _state(reported: 0, minutesAgo: 0, nowMs: now);
    expect(standingLine(Person.noor, here, now), contains('there now'));
    expect(here.lastActiveMinutesAt(now), 0);
  });

}
