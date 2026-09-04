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
import 'dart:io';

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

const _pushes = [
  'await ViewerPage.open(',
  'await SearchPage.open(',
  'await Navigator.of(context).push',
  'await Navigator.push',
];

void main() {
  _everyHandleRuns();
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
      try {
        await e.value();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
      } catch (err) {
        fail('${e.key} threw: $err');
      }
      expect(tester.takeException(), isNull, reason: '${e.key} left an exception behind');
    }
  });
}
