// The other phone changes its mood while Pulse is showing.
//
// The state-propagation clip hung the page at exactly this moment, twice, with the browser's
// process spinning and no frame drawn for minutes. This pumps the same moment through the
// widgets on the test runner: if a loop lives in the Dart, it lives here too, and the runner's
// timeout names it.
import 'package:desk/material/desk.dart';
import 'package:desk/material/library.dart';
import 'package:desk/regions/pulse/pulse_region.dart';
import 'package:desk/scope.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/transport/local/local_transport.dart';
import 'package:desk/transport/sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<AppScope> _aScope() async {
  final spine = await Spine.open(
    SpineStore.memory(),
    const Identity(person: Person.teo, device: DeviceKind.pwa),
  );
  final transport = LocalTransport(role: TransportRole.client, spine: spine, deviceId: 'test');
  return AppScope(
    spine: spine,
    transport: transport,
    sync: SyncEngine(spine: spine, transport: transport),
    clock: Clock(frozenAt: DateTime.utc(2026, 9, 3, 19, 40)),
  );
}

final _ulids = UlidFactory();

Event _theirs(String type, Map<String, dynamic> payload, int seq) => Event(
      id: _ulids.next(DateTime.utc(2026, 9, 3, 19, 39, seq)),
      seq: seq,
      author: Person.noor,
      device: DeviceKind.android,
      ts: DateTime.utc(2026, 9, 3, 19, 39).millisecondsSinceEpoch + seq,
      type: type,
      payload: payload,
    );

void main() {
  late AppScope scope;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await MaterialLibrary.load();
  });
  setUp(() async => scope = await _aScope());
  tearDown(() => scope.dispose());

  Future<void> draw(WidgetTester tester, Widget w) async {
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(AppScope.provide(scope: scope, child: MaterialApp(home: Scaffold(body: w))));
    await tester.pump();
  }

  testWidgets('a mood arriving while Pulse is showing does not hang the page', (tester) async {
    await draw(tester, const PulseRegion());
    await scope.spine.applyFromHost([_theirs('state_declared', {'signal': 'mood', 'value': 'restless'}, 1)]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    await scope.spine.applyFromHost([_theirs('feeling', {'feeling_id': 'hold', 'intensity': 0.92}, 2)]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the strip takes the new mood', (tester) async {
    await draw(tester, PartnerStrip(partner: scope.partner, state: scope.partnerState, nowMs: 0));
    await scope.spine.applyFromHost([_theirs('state_declared', {'signal': 'mood', 'value': 'restless'}, 1)]);
    await draw(tester, PartnerStrip(partner: scope.partner, state: scope.partnerState, nowMs: 0));
    expect(tester.takeException(), isNull);
  });
}
