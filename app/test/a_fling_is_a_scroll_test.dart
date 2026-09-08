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
    final began = CaptureBus.scrollWhere!()[0];
    var asked = 0.0;
    for (var i = 0; i < steps; i++) {
      // The pixels move on the frame they are asked for, not on whichever later frame a ticker
      // happens to run on. A millisecond-long animation per nudge is what put frames identical
      // to the one before them into the scroll clip: the animation's ticker is stepped by the
      // browser's frame timestamp, and two frames the driven clock pumped could carry the same
      // one. What comes back here is the pixels the thread actually travelled.
      final moved = CaptureBus.scrollBy!(-120);
      expect(moved, closeTo(-120, 0.01),
          reason: 'frame $i asked for 120 pixels and the thread moved ${moved.abs()}');
      asked += moved;
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(CaptureBus.scrollWhere!()[0], closeTo(began + asked, 0.01),
        reason: 'the thread is not where the frames it drew say it should be');
    final built = ThreadRowStats.built;

    // Measured on this machine: 17 rows built over 20 frames, with six on the glass — under one
    // a frame, which is the rows coming into view and nothing else. The same twenty frames driven
    // by jumping to an index build 543. The budget sits between the two, nearer the true number.
    expect(built, lessThan(steps * 2),
        reason: 'the list was rebuilt rather than scrolled: $built rows built over $steps frames '
            'with $onScreen on the glass');
  });
}
