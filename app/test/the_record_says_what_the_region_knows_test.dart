// The capture record must carry everything the region recorded, not a hand-copied list of it.
//
// `_viewOf` named thirteen keys of the chat report one at a time. Two that the build already
// wrote — `replies_on_the_glass`, which exists because a messenger critic capped the whole row on
// there being no delivered reply in any of the seventeen records, and `clipped_at_an_edge`, which
// exists because a record counted a read mark on a row that was 125 device pixels of blank paper
// with its ink above the top edge — were dropped on the way out. A record that knows less than the
// build does is worse than no record, because it is a record that can be believed.
import 'package:desk/capture/bus.dart';
import 'package:desk/capture/hooks.dart';
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

void main() {
  testWidgets('every key the chat region records reaches the artifact record', (tester) async {
    await MaterialLibrary.load();
    CaptureBus.wanted = true;
    addTearDown(() => CaptureBus.wanted = false);
    final spine = await Spine.open(
      SpineStore.memory(),
      const Identity(person: Person.teo, device: DeviceKind.pwa),
    );
    for (var i = 0; i < 12; i++) {
      await spine.append('message', {'text': 'a line, number $i'},
          at: DateTime.utc(2026, 1, 1).add(Duration(minutes: i * 37)), hostAssign: true);
    }
    final transport = LocalTransport(role: TransportRole.client, spine: spine, deviceId: 'test');
    final scope = AppScope(
      spine: spine,
      transport: transport,
      sync: SyncEngine(spine: spine, transport: transport),
      clock: Clock(frozenAt: DateTime.utc(2026, 9, 3, 19, 40)),
    );
    addTearDown(scope.dispose);
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(AppScope.provide(
      scope: scope,
      child: const MaterialApp(home: Scaffold(body: ChatRegion())),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // the shell is what normally sets this; the region is mounted on its own here
    CaptureBus.regionIndex = 1;
    addTearDown(() => CaptureBus.regionIndex = -1);
    final recorded = CaptureBus.chatReport!();
    final view = CaptureHooks(scope).report()['view'] as Map<String, dynamic>;
    final missing = recorded.keys.where((k) => !view.containsKey(k)).toList();
    expect(missing, isEmpty,
        reason: 'the region recorded ${recorded.keys.length} things and the record carries '
            '${view.length}; these were dropped: $missing');
    // and the two the last cycle added are among them
    expect(view.containsKey('replies_on_the_glass'), isTrue);
    expect(view.containsKey('clipped_at_an_edge'), isTrue);
  });
}
