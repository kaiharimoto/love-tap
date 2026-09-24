// What the other person's phone noticed is drawn in pencil in the margin of their sheet, not
// tabulated on it.
//
// docs/SIGNALS.md gives every signal a material rendering. 01_pulse.png rendered all of them as
// one label-value table -- MOOD bright, BATTERY 72%, RINGER normal, SIGNAL wifi, AT HOME yes --
// which the cycle 3 emotional-transmission critic called a message in a different font, and
// `partner-state-is-a-label-and-value-table-and-signals-md-describes-something-else` filed. The six
// passive signals are marks now (regions/pulse/signal_marks.dart); the declared ones stay words,
// because a person said those.
//
// ANCHORED (WORKER_PROMPT 3d) to the signal ids the marks declare, through the widget tree, not to
// a pixel. The item's own measurement named a distinct asset per signal in the surfaces sidecar;
// a pencil mark is drawn, not a rendered asset, so there is no asset for the sidecar to carry and
// the id is carried on the widget instead. Re-break: put `_Fact('battery', ...)` back in the
// pulse's their-sheet and drop the battery mark, and the seeded case fails on both counts.
import 'package:desk/material/library.dart';
import 'package:desk/material/hands.dart';
import 'package:desk/regions/pulse/pulse_region.dart';
import 'package:desk/regions/pulse/signal_marks.dart';
import 'package:desk/scope.dart';
import 'package:desk/spine/projections/state.dart';
import 'package:desk/spine/seed_loader.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/transport/local/local_transport.dart';
import 'package:desk/transport/sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

PersonState _state(Map<String, Object> values) => PersonState(Person.noor, {
      for (final e in values.entries)
        e.key: SignalValue(signal: e.key, value: e.value, at: 0, declared: false),
    });

/// The six passive signals the margin carries, and the labels the table used to give them.
const _drawn = {
  'battery': 'battery',
  'charging': null,
  'ringer': 'ringer',
  'moving': 'moving',
  'network': 'signal',
  'at_home': 'at home',
};

void main() {
  test('every passive signal has a mark, and an ordinary day has almost none', () {
    final busy = signalMarks(_state({
      'battery': 9,
      'charging': true,
      'ringer': 'silent',
      'moving': 'riding',
      'network': 'cellular',
      'at_home': true,
    }));
    expect({for (final m in busy) m.signal}, _drawn.keys.toSet(),
        reason: 'each of the six passive signals in docs/SIGNALS.md draws its own mark');
    for (final (ringer, moving) in const [('vibrate', 'walking')]) {
      final ids = {for (final m in signalMarks(_state({'ringer': ringer, 'moving': moving}))) m.signal};
      expect(ids, {'ringer', 'moving'}, reason: '$ringer and $moving each have a mark too');
    }
    // "Nothing" is the answer SIGNALS.md gives for the ordinary values, and a margin that drew a
    // mark for them would be the table again in pictures.
    final ordinary = signalMarks(_state({
      'battery': 80,
      'charging': false,
      'ringer': 'normal',
      'moving': 'still',
      'network': 'wifi',
      'at_home': false,
    }));
    expect([for (final m in ordinary) m.signal], ['battery']);
  });

  testWidgets('the seeded pulse draws their phone and tabulates none of it', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    try {
      await MaterialLibrary.load();
    } catch (_) {
      return; // no packed library in this bundle; every_screen_builds_test says so loudly
    }
    late AppScope scope;
    await tester.runAsync(() async {
      final spine = await Spine.open(
        SpineStore.memory(),
        const Identity(person: Person.teo, device: DeviceKind.pwa),
      );
      await SeedLoader(rootBundle).load(spine);
      final transport = LocalTransport(role: TransportRole.client, spine: spine, deviceId: 'test');
      scope = AppScope(
        spine: spine,
        transport: transport,
        sync: SyncEngine(spine: spine, transport: transport),
        clock: Clock(frozenAt: DateTime.utc(2026, 9, 3, 19, 40)),
      );
    });
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(AppScope.provide(
      scope: scope,
      child: const MaterialApp(home: Scaffold(body: PulseRegion())),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);

    final partner = scope.partnerState;
    // The population: which of the six the seeded partner actually has. The capture this item was
    // filed against showed battery, ringer, signal and at home, so fewer than that means the
    // screen is not the one the item is about.
    final present = [
      for (final s in _drawn.keys)
        if (partner[s] != null) s,
    ];
    expect(present.length, greaterThanOrEqualTo(4),
        reason: 'the seeded partner has only $present of the six passive signals');

    final marks = {
      for (final m in tester.widgetList<SignalMark>(find.byType(SignalMark))) m.signal,
    };
    // a subset rather than equal: where `place` and `at home` disagree the sheet keeps only the
    // newer of the two, so the house can be withheld -- which the seed does, at 19:40
    expect({for (final m in signalMarks(partner)) m.signal}.containsAll(marks), isTrue,
        reason: 'the sheet drew $marks, which its partner state does not earn');
    expect(marks, contains('battery'), reason: 'their battery is on the seed and is not drawn');

    final stamped = {
      for (final w in tester.widgetList<Stamped>(find.byType(Stamped))) w.text.toLowerCase(),
    };
    final tabulated = [
      for (final label in _drawn.values)
        if (label != null && stamped.contains(label)) label,
    ];
    expect(tabulated, isEmpty,
        reason: 'these passive signals are still a label and a value on their sheet: $tabulated');
  });
}
