import 'package:desk/capture/bus.dart';
import 'package:desk/material/library.dart';
import 'package:desk/regions/chat/chat_region.dart';
import 'package:desk/scope.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/spine/store/store.dart';
import 'package:desk/transport/local/local_transport.dart';
import 'package:desk/transport/sync.dart';
import 'package:desk/transport/transport.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<Event>> _fromNoor(Future<void> Function(Spine) write) async {
  final far = await Spine.open(
    SpineStore.memory(), const Identity(person: Person.noor, device: DeviceKind.android));
  await write(far);
  return far.ordered;
}

void main() {
  testWidgets('two arrivals, two unfolds', (tester) async {
    await MaterialLibrary.load();
    CaptureBus.wanted = true;
    addTearDown(() => CaptureBus.wanted = false);
    final spine = await Spine.open(
      SpineStore.memory(), const Identity(person: Person.teo, device: DeviceKind.pwa));
    await spine.append('message', {'text': 'mine, before'}, hostAssign: true);
    final transport = LocalTransport(role: TransportRole.client, spine: spine, deviceId: 't');
    final scope = AppScope(
      spine: spine, transport: transport,
      sync: SyncEngine(spine: spine, transport: transport),
      clock: Clock(frozenAt: DateTime.utc(2026, 9, 3, 19, 40)));
    addTearDown(scope.dispose);
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(AppScope.provide(
      scope: scope, child: const MaterialApp(home: Scaffold(body: ChatRegion()))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    for (var round = 0; round < 2; round++) {
      await spine.applyFromHost(await _fromNoor((far) async {
        await far.append('message', {'text': 'from noor $round'}, hostAssign: true);
      }));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      CaptureBus.unfoldAll!();
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      expect(tester.takeException(), isNull, reason: 'round $round threw');
    }
  });
}
