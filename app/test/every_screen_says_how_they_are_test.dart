// Partner state is legible on every screen, not only on Pulse.
//
// A coherence critic drove three state changes through 08_state_propagating and found that two of
// them never reached the standing ribbon: `state mood restless` showed on the Pulse card and as a
// thread row and nowhere else, and `state availability heads_down` moved nothing visible at all.
// Only `state place out` moved the ribbon. So on Moments and on Settings a reader got three of the
// five signals — and the two missing ones are the two that decide whether to write to somebody.
import 'package:desk/material/desk.dart';
import 'package:desk/material/light.dart';
import 'package:desk/material/library.dart';
import 'package:desk/scope.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/spine/store/store.dart';
import 'package:desk/transport/local/local_transport.dart';
import 'package:desk/transport/sync.dart';
import 'package:desk/transport/transport.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<AppScope> _scopeSaying(Map<String, Object> signals) async {
  final spine = await Spine.open(
    SpineStore.memory(),
    const Identity(person: Person.teo, device: DeviceKind.pwa),
  );
  // written on the other phone and accepted here, which is the only way a partner's state ever
  // gets into this log
  final far = await Spine.open(
    SpineStore.memory(),
    const Identity(person: Person.noor, device: DeviceKind.android),
  );
  var at = DateTime.utc(2026, 9, 3, 19, 0);
  for (final e in signals.entries) {
    at = at.add(const Duration(minutes: 1));
    await far.append('state_declared', {'signal': e.key, 'value': e.value},
        at: at, hostAssign: true);
  }
  await spine.accept(far.ordered);
  final transport = LocalTransport(role: TransportRole.client, spine: spine, deviceId: 'test');
  return AppScope(
    spine: spine,
    transport: transport,
    sync: SyncEngine(spine: spine, transport: transport),
    clock: Clock(frozenAt: DateTime.utc(2026, 9, 3, 19, 40)),
  );
}

void main() {
  setUpAll(() async => MaterialLibrary.load());

  Future<String> ribbonWords(WidgetTester tester, AppScope scope) async {
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(AppScope.provide(
      scope: scope,
      child: MaterialApp(
        home: Scaffold(
          body: PartnerStrip(
            partner: scope.partner,
            state: scope.partnerState,
            nowMs: scope.clock.now().millisecondsSinceEpoch,
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return tester
        .widgetList<Text>(find.byType(Text))
        .map((w) => w.data ?? '')
        .join(' | ')
        .toLowerCase();
  }

  testWidgets('the ribbon says where they are, how they are, and whether to write', (tester) async {
    final scope = await _scopeSaying({
      'place': 'out',
      'mood': 'restless',
      'availability': 'heads_down',
      'need': 3,
      'energy': 2,
    });
    addTearDown(scope.dispose);
    final words = await ribbonWords(tester, scope);
    expect(words, contains('out'), reason: 'the place is missing: "$words"');
    expect(words, contains('restless'), reason: 'the mood is missing: "$words"');
    expect(words, contains('heads down'),
        reason: 'nothing says they are heads down: "$words"');
  });

  testWidgets('and never says the same signal twice', (tester) async {
    // the standing line already carries the mood, so the stamp must not repeat it
    final scope = await _scopeSaying({
      'status_line': 'restless and out for a walk',
      'mood': 'restless',
      'place': 'out',
    });
    addTearDown(scope.dispose);
    final words = await ribbonWords(tester, scope);
    expect('restless'.allMatches(words).length, 1,
        reason: 'the ribbon says restless twice: "$words"');
  });
}
