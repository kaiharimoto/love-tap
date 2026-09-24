// The partner strip fits a phone 360 points wide, with everything on it still on it.
//
// Its second row -- where they are, the need and energy dials, the battery pencil -- was laid out
// for 480 wide. At 360x780, the frame of 06, 07, 08, 11 and 15 and a common Android width, it
// overflowed by 39 px with the real hands (firing 59), and in the 07 re-capture the pencil was cut
// off at the strip's edge.
//
// With the real hands, not the test font: the overflow is a matter of glyph widths. And with the
// seeded year's partner state, which is what those five scenes draw.
//
// The pencil moved up to the status line, which ellipsizes, and the clover and its room scale
// with the width, so at 480 nothing changed (a_pressed_clover_is_on_the_strip_test still reads
// 0.01091 of the still).
//
// Re-break: put the pencil back at the end of the second row, and 360 overflows again (by 19 px
// with the smaller clover's room; by 39 with the old one).
import 'package:desk/material/desk.dart';
import 'package:desk/material/hands.dart';
import 'package:desk/material/library.dart';
import 'package:desk/scope.dart';
import 'package:desk/spine/seed_loader.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/transport/local/local_transport.dart';
import 'package:desk/transport/sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';

void main() {
  String? absent;
  late AppScope scope;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final f in <(String, String)>[
      ('NoorHand', 'assets/fonts/NoorHand.ttf'),
      ('TeoHand', 'assets/fonts/TeoHand.ttf'),
      ('DeskStamp', 'assets/fonts/TeoHand.ttf'),
    ]) {
      await (FontLoader(f.$1)..addFont(rootBundle.load(f.$2))).load();
    }
    try {
      await MaterialLibrary.load();
      await rootBundle.loadString('assets/seed/index.json');
    } catch (_) {
      absent = 'this bundle was packed without the year (tools/pack_assets.py --seed=year)';
      return;
    }
    final spine = await Spine.open(
        SpineStore.memory(), const Identity(person: Person.teo, device: DeviceKind.pwa));
    await SeedLoader(rootBundle).load(spine);
    final t = LocalTransport(role: TransportRole.client, spine: spine, deviceId: 'test');
    scope = AppScope(
      spine: spine,
      transport: t,
      sync: SyncEngine(spine: spine, transport: t),
      clock: Clock(frozenAt: DateTime.utc(2026, 9, 3, 19, 40)),
    );
  });

  for (final width in const [360.0, 480.0]) {
    testWidgets('at ${width.round()} wide nothing overflows and nothing is left off',
        (tester) async {
      if (absent != null) return markTestSkipped(absent!);
      tester.view.physicalSize = Size(width, 780) * 3.0;
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      final state = scope.partnerState;
      expect(state.place, isNotNull, reason: 'the scenario needs a place on the strip');
      expect(state.battery, isNotNull, reason: 'and a pencil');
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(children: [
            PartnerStrip(
              partner: scope.partner,
              state: state,
              nowMs: scope.clock.now().millisecondsSinceEpoch,
              lastHeard: scope.partnerLastHeard,
            ),
            const Spacer(),
          ]),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'the strip overflows at ${width.round()} wide');

      // POPULATION, by widget: where they are, both dials and the pencil are all still drawn,
      // and all inside the strip.
      final strip = tester.getRect(find.byType(PartnerStrip));
      final parts = {
        'place': find.byWidgetPredicate((w) => w is Stamped && w.text == state.place),
        'need': find.byWidgetPredicate((w) => w is Stamped && w.text == 'need'),
        'energy': find.byWidgetPredicate((w) => w is Stamped && w.text == 'energy'),
        'pencil': find.byWidgetPredicate((w) => w.runtimeType.toString() == '_Pencil'),
      };
      for (final p in parts.entries) {
        expect(p.value, findsOneWidget, reason: '${p.key} is not on the strip');
        final r = tester.getRect(p.value);
        expect(r.right <= strip.right && r.left >= strip.left, isTrue,
            reason: '${p.key} at $r is outside the strip at $strip');
      }
    });
  }
}
