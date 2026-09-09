// A fling while messages are arriving must still build only the rows that come into view.
//
// The number this exists to hold, from two shoots of the same scene against the same build. Shot
// on its own: 135 rows built over 300 driven frames, build cost p50 3 ms and p95 26. Shot in a run
// where the far phone was up and syncing, which is how the capture actually runs: **5028 rows over
// the same 300 frames**, p95 1562 ms, 269 frames over 400. Thirty-seven times the work, from the
// same fling, because the spine notifies on every round and ChatRegion reads the scope, so every
// visible row was torn down and built again for a message that changed nothing on the screen.
//
// A message arriving while you are scrolling should add a row. It should not rebuild the ones you
// are looking at.
import 'package:desk/capture/bus.dart';
import 'package:desk/material/library.dart';
import 'package:desk/regions/chat/chat_region.dart';
import 'package:desk/regions/chat/note.dart';
import 'package:desk/scope.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/spine/store/store.dart';
import 'package:desk/transport/local/local_transport.dart';
import 'package:desk/transport/sync.dart';
import 'package:desk/transport/transport.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a fling under a live sync builds no more rows than a quiet one', (tester) async {
    await MaterialLibrary.load();
    CaptureBus.wanted = true;
    addTearDown(() => CaptureBus.wanted = false);
    final spine = await Spine.open(
      SpineStore.memory(),
      const Identity(person: Person.teo, device: DeviceKind.pwa),
    );
    for (var i = 0; i < 400; i++) {
      await spine.append('message', {'text': 'a line of the year, number $i'},
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

    final onScreen = find.byType(Note).evaluate().length;
    expect(onScreen, greaterThan(2), reason: 'the thread is empty');

    const steps = 20;

    // twenty frames with nothing arriving
    ThreadRowStats.reset();
    for (var i = 0; i < steps; i++) {
      CaptureBus.scrollBy!(-120);
      await tester.pump(const Duration(milliseconds: 16));
    }
    final quiet = ThreadRowStats.built;

    // the same twenty frames, with a message landing on each one the way a live sync round does
    ThreadRowStats.reset();
    for (var i = 0; i < steps; i++) {
      CaptureBus.scrollBy!(-120);
      await spine.append('message', {'text': 'and one more while you are scrolling, $i'},
          at: DateTime.utc(2026, 9, 3, 19, 40).add(Duration(seconds: i)), hostAssign: true);
      await tester.pump(const Duration(milliseconds: 16));
    }
    final busy = ThreadRowStats.built;

    // ignore: avoid_print
    print('rows built over $steps frames with $onScreen on the glass: '
        'quiet $quiet, with a message on every frame $busy');
    expect(busy, lessThan(steps * 2),
        reason: 'a sync round rebuilt the thread: $busy rows built over $steps frames with '
            '$onScreen on the glass, against $quiet for the same fling with nothing arriving');
  });
}
