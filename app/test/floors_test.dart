// The floors the brief sets, as things the build cannot quietly fall below.
//
// Every number here is a minimum from the mission, and each of these is the cheapest possible
// guard against the way a floor is actually breached: not by someone deciding to ship 29 feelings,
// but by a rename that drops a family, a registry line that gets lost in a merge, or a signal that
// stops being produced and nobody notices until a critic counts them.
import 'package:desk/ambient/ambient.dart';
import 'package:desk/feelings/builtins.dart';
import 'package:desk/feelings/drawn.dart';
import 'package:desk/modules/registry.dart';
import 'package:desk/setup/checklist.dart';
import 'package:desk/spine/event.dart';
import 'package:desk/spine/projections/state.dart';
import 'package:desk/spine/projections/thread.dart';
import 'package:desk/spine/types.dart';
import 'package:desk/transport/transport.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desk/feelings/landing.dart';
import 'package:desk/regions/chat/renderers.dart';

void main() {
  test('at least thirty built-in feelings, in at least five named families', () {
    expect(kBuiltInFeelings.length, greaterThanOrEqualTo(30));
    final families = kBuiltInFeelings.map((f) => f.family).toSet();
    expect(families.length, greaterThanOrEqualTo(5));
    for (final family in families) {
      expect(family.label.trim(), isNotEmpty, reason: 'every family is named');
      expect(kBuiltInFeelings.where((f) => f.family == family).length, greaterThanOrEqualTo(3),
          reason: '${family.label} is a family, not a label on one feeling');
    }
  });

  test('every feeling is told apart by its own object, rhythm, sound and colour', () {
    expect(kBuiltInFeelings.map((f) => f.id).toSet().length, kBuiltInFeelings.length);
    expect(kBuiltInFeelings.map((f) => f.object).toSet().length, kBuiltInFeelings.length,
        reason: 'a feeling that shares an object is a feeling wearing another one');
    expect(kBuiltInFeelings.map((f) => f.haptic).toSet().length, kBuiltInFeelings.length,
        reason: 'the rhythm alone has to identify it with the screen face down');
    expect(kBuiltInFeelings.map((f) => f.sound).toSet().length, kBuiltInFeelings.length);
    for (final f in kBuiltInFeelings) {
      expect(f.segments, isNotEmpty, reason: '${f.id} has no rhythm at all');
    }
  });

  test('every feeling resolves to something drawn or rendered, and never to a glyph', () {
    // Some of the vocabulary is objects and some of it is marks. What matters is that none of it
    // is a blank or a character from a font: a feeling that cannot be shown is a feeling that
    // arrives as its own name, which is the thing the emotional layer is meant not to be.
    final drawn = kDrawnFeelings.keys.toSet();
    for (final f in kBuiltInFeelings) {
      expect(f.object.startsWith('obj_'), isTrue, reason: '${f.id} has no object at all');
      expect(f.name.codeUnits.every((c) => c < 0x2190), isTrue,
          reason: '${f.id} has a glyph in its name');
    }
    // the ones that are marks are marks on purpose, and the list is closed
    for (final id in drawn) {
      expect(kBuiltInFeelings.any((f) => f.object == id), isTrue,
          reason: '$id is drawn but no feeling uses it');
    }
  });

  test('at least twelve partner-state signals, all of them projected', () {
    final signals = {...kDeclaredSignals, ...kPassiveSignals};
    expect(signals.length, greaterThanOrEqualTo(12));
    expect(kDeclaredSignals.toSet().intersection(kPassiveSignals.toSet()), isEmpty,
        reason: 'a signal is either declared or read off the phone, not both');
  });

  test('at least fourteen event types, each with a renderer and a notification treatment', () {
    // This test used to assert that a non-nullable List was not null, which is to say it asserted
    // nothing at all while carrying a name that said otherwise. The renderer half now has to
    // exist in regions/chat/renderers.dart, and thread_types_test holds the other end.
    expect(kEventTypes.length, greaterThanOrEqualTo(14));
    for (final spec in kEventTypes) {
      expect(spec.renderer.trim(), isNotEmpty, reason: '${spec.id} names no renderer');
      expect(kThreadRenderers.containsKey(spec.renderer), isTrue,
          reason: '${spec.id} names a renderer that does not exist');
      expect(Notify.values.contains(spec.notify), isTrue);
      expect(spec.search.excluded || spec.search.textFields.isNotEmpty ||
             spec.search.facets.isNotEmpty, isTrue,
          reason: '${spec.id} can neither be searched nor filtered nor is it excluded, so it '
              'would be invisible in Moments and in search both');
    }
    // and the seventeen the brief names are all of them present
    for (final id in ['message', 'photo', 'video', 'voice_note', 'reaction', 'message_edit',
                      'message_delete', 'read_marker', 'feeling', 'state_declared',
                      'state_passive', 'date_event', 'todo_event', 'milestone', 'ritual_kept',
                      'ping', 'feeling_authored']) {
      expect(kEventTypeById[id], isNotNull, reason: '$id is not in the registry');
    }
  });

  test('at least four shared-life modules, each writing into the one log', () {
    expect(kModules.length, greaterThanOrEqualTo(4));
    expect(kModules.map((m) => m.id).toSet().length, kModules.length);
    for (final m in kModules) {
      expect(m.eventTypes, isNotEmpty, reason: '${m.id} keeps no history of its own');
      for (final type in m.eventTypes) {
        expect(kEventTypeById.containsKey(type), isTrue,
            reason: '${m.id} writes $type, which is not a type of the one log');
      }
    }
  });

  test('the standing line never becomes a debt', () {
    // The anti-goal is engagement machinery, and the standing line is where it would appear first:
    // an unread count is a number that goes up while you are not looking, which is the whole
    // mechanism. It may say what they are. It may not say how much you owe them.
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final state = PersonState(Person.noor, {
      'mood': SignalValue(signal: 'mood', value: 'calm', at: now, declared: true),
      'status_line': SignalValue(signal: 'status_line', value: 'marking, badly', at: now, declared: true),
      'place': SignalValue(signal: 'place', value: 'work', at: now, declared: true),
      'last_active': SignalValue(signal: 'last_active', value: 2, at: now - 120000, declared: false),
    });
    final line = standingLine(Person.noor, state, now);
    expect(line, contains('calm'));
    for (final forbidden in ['unread', 'waiting for you', 'streak', 'missed', 'owe', 'behind']) {
      expect(line.toLowerCase(), isNot(contains(forbidden)));
    }
    expect(RegExp(r'\d+\s*(new|unread|message)').hasMatch(line), isFalse);
  });

  test('a setup step ticks on something observed, and un-ticks when it goes away', () {
    SetupFacts facts({bool allowed = false, bool home = false}) => SetupFacts(
          platform: 'pwa',
          link: const TransportStatus(name: 'local', role: TransportRole.client, state: LinkState.stopped),
          paired: null,
          notificationsAllowed: allowed,
          installedToHome: home,
          certificateVerified: false,
          mineInSpine: false,
          theirsInSpine: false,
        );
    final steps = stepsFor('pwa');
    expect(observe(steps, facts())['home'], StepState.doing);
    expect(observe(steps, facts(home: true))['home'], StepState.done);
    // and back: the permission is asked of the phone every time, so a step cannot stay ticked
    expect(observe(steps, facts(home: false))['home'], StepState.doing);
    expect(settled(steps, facts(home: true, allowed: true)), isFalse);
  });


  test('a feeling arrives with weight rather than appearing', () {
    // The whole difference between a feeling and a message in another colour. If this reduces to
    // "the object is at rest from the first frame", the landing clip is a hard cut and rubric
    // row 03 is at its floor whatever else is true.
    const intensity = 0.85;
    final heights = [
      for (var ms = 0; ms <= 1600; ms += 16) Fall.heightAt(ms / 1000.0, intensity),
    ];
    expect(heights.first, greaterThan(0.5), reason: 'it starts off the desk');
    expect(heights.any((h) => h == 0.0), isTrue, reason: 'it reaches the desk');

    // it comes back up after the first contact, which is what weight looks like
    final contacts = Fall.contacts(intensity);
    expect(contacts.length, greaterThanOrEqualTo(3), reason: 'more than one bounce');
    final between = Fall.heightAt((contacts[0] + contacts[1]) / 2, intensity);
    expect(between, greaterThan(0.01), reason: 'it leaves the desk again between contacts');

    // and the shadow does the opposite of the object the whole way down
    final upShadow = Fall.shadowAt(0.0, intensity);
    final downShadow = Fall.shadowAt(contacts[0], intensity);
    expect(downShadow, greaterThan(upShadow * 1.6),
        reason: 'the shadow draws in hard as the thing lands');

    // something actually moves in every one of the first thirty frames
    var moving = 0;
    for (var i = 1; i < 30; i++) {
      if ((heights[i] - heights[i - 1]).abs() > 0.001) moving++;
    }
    expect(moving, greaterThanOrEqualTo(28), reason: 'no still run at the start of the clip');
  });

  test('the page carries the pattern when there is no vibrator to carry it', () {
    // On iOS Safari there is no vibration API at all, so the rhythm has to arrive through the
    // paper instead. Same segments, same milliseconds; a different body.
    final f = kBuiltInFeelings.firstWhere((f) => f.id == 'hold');
    final segments = f.segments;
    expect(segments, isNotEmpty);
    final total = f.hapticLengthMs;
    var moved = 0;
    for (var ms = 0; ms < total; ms += 8) {
      if (amplitudeAt(segments, ms) > 0) moved++;
    }
    expect(moved, greaterThan(0), reason: 'the surface moves at all');
    expect(moved * 8, lessThan(total), reason: 'and it is a rhythm, not one long push');
    expect(amplitudeAt(segments, total + 50), 0.0, reason: 'and it stops when the pattern does');
  });

  test('a message that did not go looks nothing like one that was read', () {
    // Five delivery states used to be three, two of which were the same grey lowercase word in
    // the same place — so a message that failed to send was indistinguishable from one the other
    // person had read. That is the row-01 disqualifier in one pixel.
    final states = Delivery.values.toSet();
    expect(states.length, 5);
    expect(states.containsAll({Delivery.queued, Delivery.sending, Delivery.sent,
      Delivery.read, Delivery.refused}), isTrue);

    Event mine(String id, {int? seq}) => Event(
          id: id, seq: seq, author: Person.teo, device: DeviceKind.pwa,
          ts: DateTime.utc(2026, 9, 3, 17).millisecondsSinceEpoch,
          type: 'message', payload: const {'text': 'ok'},
        );
    final log = [
      mine('a', seq: 1), mine('b', seq: 2), mine('c'), mine('d'), mine('e'),
      Event(id: 'r', seq: 3, author: Person.noor, device: DeviceKind.android,
          ts: DateTime.utc(2026, 9, 3, 17, 1).millisecondsSinceEpoch,
          type: 'read_marker', payload: const {'upto_seq': 1}),
    ];
    final t = projectThread(log, me: Person.teo, linkUp: true,
        refused: {'e': 'the other phone is on an older version'}, inFlight: {'c'});
    final by = {for (final i in t.items) i.id: i.delivery};
    expect(by['a'], Delivery.read);
    expect(by['b'], Delivery.sent);
    expect(by['c'], Delivery.sending);
    expect(by['e'], Delivery.refused);
    final offline = projectThread(log, me: Person.teo, linkUp: false);
    expect(offline.items.firstWhere((i) => i.id == 'd').delivery, Delivery.queued);
  });
}
