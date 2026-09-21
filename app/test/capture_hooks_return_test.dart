// A capture handle returns when the thing has happened, not when somebody closes it.
//
// Two of the seventeen artifacts were accused of proving nothing: the media viewer frame was a
// picture of the thread, and search never opened. Both handles opened a route with Navigator.push
// and awaited it — and a push does not complete until the page is popped. So the harness asked for
// search, waited for somebody to close it, ran out of time with no shot taken, and what shipped
// was whatever had been captured before.
//
// Nothing here can see a Navigator, so this reads the source: a handle registered on CaptureBus
// may not await a push.
import 'dart:async';
import 'dart:io';

import 'package:desk/capture/bus.dart';
import 'package:desk/material/library.dart';
import 'package:desk/regions/chat/chat_region.dart';
import 'package:desk/scope.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/transport/local/local_transport.dart';
import 'package:desk/transport/sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _pushes = [
  'await ViewerPage.open(',
  'await SearchPage.open(',
  'await Navigator.of(context).push',
  'await Navigator.push',
];

void main() {
  _everyHandleRuns();
  _anAnchorThatIsNotThereIsRefused();
  test('no capture handle waits for a page to be closed', () {
    final offenders = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final f in files) {
      final src = f.readAsStringSync();
      var at = src.indexOf('CaptureBus.');
      while (at >= 0) {
        final end = src.indexOf('\n    };', at);
        if (end < 0) break;
        final body = src.substring(at, end);
        for (final push in _pushes) {
          if (body.contains(push)) {
            final line = '\n'.allMatches(src.substring(0, at)).length + 1;
            offenders.add('${f.path}:$line  $push');
          }
        }
        at = src.indexOf('CaptureBus.', at + 1);
      }
    }
    expect(offenders, isEmpty,
        reason: 'a capture handle that awaits a route waits for the page to be popped, and the '
            'harness waits with it until the scene times out:\n${offenders.join('\n')}');
  });
}

// ---------------------------------------------------------------------------------------------
// And every handle actually runs.
//
// Reading the source catches a handle that waits for the wrong thing. It does not catch a handle
// that throws — and one did: __deskStage built a read marker with the id `stage_read_marker`,
// which is not a ULID, and the store refused the row. The scene reported
// `threw: Dart exception thrown from converted Future`, 13_messenger_states was recorded missing,
// and the only reason it was noticed at all is that capture.sh writes down what failed.
//
// So the app is built and every handle the scenes use is called, against a real spine, and asked
// to come back with `ok`.
void _everyHandleRuns() {
  testWidgets('every capture handle the scenes use comes back ok', (tester) async {
    CaptureBus.wanted = true;
    addTearDown(() => CaptureBus.wanted = false);
    await MaterialLibrary.load();
    final spine = await Spine.open(
      SpineStore.memory(),
      const Identity(person: Person.teo, device: DeviceKind.pwa),
    );
    for (final text in ['the canal has gone all dimples', 'one hour then stop']) {
      await spine.append('message', {'text': text}, hostAssign: true);
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
    await tester.pump(const Duration(milliseconds: 300));

    // the ones the scenes call that do not need a route or a second device
    final handles = <String, Future<void> Function()>{
      'stageStates': () async => CaptureBus.stageStates!(),
      'scrollTo end': () async => CaptureBus.scrollTo!('end'),
      'unfoldAll': () async => CaptureBus.unfoldAll!(),
    };
    for (final e in handles.entries) {
      // Started, then pumped, then awaited. Every one of these ends in a delay — the handles wait
      // for the app to settle before they answer — and inside a widget test a delay only elapses
      // when the test advances the clock. Awaiting first is a deadlock: the future is waiting for
      // a pump that is waiting for the future.
      final running = e.value();
      var settled = false;
      unawaited(running.then((_) => settled = true, onError: (Object _) => settled = true));
      for (var i = 0; i < 12 && !settled; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      try {
        await running;
      } catch (err) {
        fail('${e.key} threw: $err');
      }
      expect(tester.takeException(), isNull, reason: '${e.key} left an exception behind');
    }
  });
}

// ---------------------------------------------------------------------------------------------
// And a handle that cannot do what it was asked says so.
//
// `__deskScrollTo` used to return quietly when it could not resolve its anchor, and that silence
// cost firing 37 a 45-minute capture. The scene named a seeded event id; the id was a different
// string in the PWA than in the test that chose it, because `UlidFactory.next` peeled its 48-bit
// timestamp with 32-bit operations and a web `int` is a double. `indexWhere` returned -1, the
// handle returned, the list never moved, and the shutter photographed the thread where it stood:
// six notes where the artifact's floor is eight. The log, the report and the manifest were all
// clean, so what came back looked exactly like a real photograph of a short thread.
//
// The id is repaired. This is the other half — the half that would have named it in seconds.
// `hook()` in tools/capture/scene.js refuses any step whose handle throws and books the anchor in
// the reason, so a throw here is the difference between an artifact that is refused with a
// sentence and one that is quietly wrong.
void _anAnchorThatIsNotThereIsRefused() {
  testWidgets('an anchor that is in neither the thread nor the unit interval is refused', (tester) async {
    CaptureBus.wanted = true;
    addTearDown(() => CaptureBus.wanted = false);
    await MaterialLibrary.load();
    final spine = await Spine.open(
      SpineStore.memory(),
      const Identity(person: Person.teo, device: DeviceKind.pwa),
    );
    for (final text in ['the canal has gone all dimples', 'one hour then stop']) {
      await spine.append('message', {'text': text}, hostAssign: true);
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
    await tester.pump(const Duration(milliseconds: 300));

    /// Run a handle the way the test above does — started, pumped, then awaited — and hand back
    /// whatever it ended with. Awaiting first deadlocks: the future waits for a pump that is
    /// waiting for the future.
    Future<Object?> outcome(Future<void> Function() run) async {
      final running = run();
      Object? error;
      var settled = false;
      unawaited(running.then((_) => settled = true, onError: (Object e) {
        error = e;
        settled = true;
      }));
      for (var i = 0; i < 40 && !settled; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      // Awaited, not merely pumped at. Reading `error` while the future is still in flight is how
      // a test that is watching for a throw reports `null` and calls the throw missing.
      try {
        await running;
      } catch (e) {
        error = e;
      }
      return error;
    }

    // A ULID-shaped id that is simply not in this thread — which is precisely what a seeded id
    // from the other rig was.
    final absent = await outcome(() => CaptureBus.scrollTo!('01KPV0SDX06FA58CJ9JXH23W7R'));
    expect(absent, isA<StateError>(),
        reason: 'an anchor naming no note in the thread has to be refused, not returned from: '
            'returning is how a capture of six notes passes for a capture of twelve');
    expect('$absent', contains('01KPV0SDX06FA58CJ9JXH23W7R'),
        reason: 'and the anchor has to be in the reason, because that is what scene.js books');

    // Not a number either, so it cannot be read as a fraction of the way through.
    final nonsense = await outcome(() => CaptureBus.scrollTo!('nowhere-at-all'));
    expect(nonsense, isA<StateError>());

    // And the shapes that do resolve still resolve, so this has not simply broken scrolling.
    expect(await outcome(() => CaptureBus.scrollTo!('end')), isNull);
    expect(await outcome(() => CaptureBus.scrollTo!('0.5')), isNull);
    final first = scope.thread.items.first.id;
    expect(await outcome(() => CaptureBus.scrollTo!(first)), isNull,
        reason: 'an id that IS in the thread must still land');
  });
}
