// A fling moves the paper; it does not build the thread again every frame.
//
// "Build cost is p50 20 ms but p95 1426 ms and max 1785 ms, a 71x spread; 252 of 817 frames build
// in over 500 ms ... the spikes recur with a median gap of 3 frames ... raster cost over the same
// frames is flat, so the spikes are the app's own build work." The cause was that each frame of
// the scroll clip re-entered the list at a new index and alignment: jumping to an index is not a
// scroll, it tears the active sliver down and builds another one at the new index.
//
// Milliseconds on a busy machine are not a measurement, so this counts rows built instead: a
// pixel scroll builds the rows that come into view and nothing else.
import 'dart:async';

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
  testWidgets('a fling builds the rows that come into view and no more', (tester) async {
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

    // twenty frames of a fling, the way the scene drives it
    ThreadRowStats.reset();
    const steps = 20;
    for (var i = 0; i < steps; i++) {
      CaptureBus.scrollBy!(-120);
      await tester.pump(const Duration(milliseconds: 16));
    }
    final built = ThreadRowStats.built;

    // Measured on this machine: 17 rows built over 20 frames, with six on the glass — under one
    // a frame, which is the rows coming into view and nothing else. The same twenty frames driven
    // by jumping to an index build 543. The budget sits between the two, nearer the true number.
    expect(built, lessThan(steps * 2),
        reason: 'the list was rebuilt rather than scrolled: $built rows built over $steps frames '
            'with $onScreen on the glass');
  });
}
