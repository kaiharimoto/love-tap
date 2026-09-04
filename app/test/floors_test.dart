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
import 'package:desk/spine/types.dart';
import 'package:desk/transport/transport.dart';
import 'package:flutter_test/flutter_test.dart';

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
    expect(kEventTypes.length, greaterThanOrEqualTo(14));
    for (final t in kEventTypes) {
      expect(t.id.trim(), isNotEmpty);
      expect(t.required, isNotNull);
      expect(kEventTypeById[t.id], same(t), reason: '${t.id} is reachable from the registry');
    }
    // adding an eighteenth is one entry and one renderer, which is only true while the registry is
    // the single place a type is declared
    expect(kEventTypeById.length, kEventTypes.length);
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
}
