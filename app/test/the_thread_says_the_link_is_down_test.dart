// When the other phone cannot be reached, the thread says so where the person is writing.
//
// A messenger critic read 08_state_propagating — the only artifact in the set about a message
// crossing a cut link — and found a note sitting at `going` for 47 frames with nothing anywhere on
// the glass saying why. The delivery mark says what happened to that one note; it does not say
// that the link is down, and a person watching one note fail cannot tell the difference between a
// phone that is out of range and a message that was refused.
//
// The sentence has been in the voice file since the link was written and was used nowhere.
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
import 'package:desk/voice/strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a thread whose link is down says so, and stops saying it when it comes back',
      (tester) async {
    // flutter_test replaces HttpClient with one that answers 400 to everything, so that a widget
    // test cannot reach the network by accident. This test is about two phones on a loopback and
    // has to actually reach one, so the override comes off for the length of it.
    final overrides = HttpOverrides.current;
    HttpOverrides.global = null;
    addTearDown(() => HttpOverrides.global = overrides);
    CaptureBus.wanted = true;
    addTearDown(() => CaptureBus.wanted = false);
    await MaterialLibrary.load();
    // Two real phones on a real loopback, paired. `offline` is a state a *paired* client reaches
    // by trying and failing; a client that was never paired is `connecting`, which is a different
    // fact and must not draw this line — 10_first_run is a phone that has not been paired yet.
    final port = (await tester.runAsync(() async {
      final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final p = s.port;
      await s.close();
      return p;
    }))!;
    final far = await Spine.open(
      SpineStore.memory(),
      const Identity(person: Person.noor, device: DeviceKind.android),
    );
    final farT = LocalTransport(
        role: TransportRole.host, spine: far, deviceId: 'android-test',
        binding: LocalBinding(port: port));
    await tester.runAsync(() => farT.start());
    addTearDown(() async {
      await farT.stop();
      await far.close();
    });

    final spine = await Spine.open(
      SpineStore.memory(),
      const Identity(person: Person.teo, device: DeviceKind.pwa),
    );
    await spine.append('message', {'text': 'the canal has gone all dimples'}, hostAssign: true);
    final transport = LocalTransport(
        role: TransportRole.client, spine: spine, deviceId: 'pwa-test',
        binding: LocalBinding(port: port));
    final scope = AppScope(
      spine: spine,
      transport: transport,
      sync: SyncEngine(spine: spine, transport: transport),
      clock: Clock(frozenAt: DateTime.utc(2026, 9, 3, 19, 40)),
    );
    addTearDown(scope.dispose);
    // started, the way main.dart starts it: a transport nobody started is `stopped`, which is not
    // a link that is down, it is a link that was never asked for
    await tester.runAsync(() async {
      await transport.start();
      final code = await farT.beginPairing();
      await transport.completePairing('http://127.0.0.1:$port', code.spoken);
      await scope.sync.once();
    });

    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(AppScope.provide(
      scope: scope,
      child: const MaterialApp(home: Scaffold(body: ChatRegion())),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(S.offlineQueued), findsNothing,
        reason: 'the thread says the link is down while it is up');

    // The link goes, and the app finds out the way it always does: by trying.
    transport.scriptedFaults.goOffline();
    for (var i = 0; i < 20 && scope.link.state != LinkState.offline; i++) {
      await tester.runAsync(() => scope.sync.once().catchError((Object _) => false));
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(scope.link.state, LinkState.offline,
        reason: 'the transport never noticed it could not reach the other phone');
    await tester.pump();

    expect(find.text(S.offlineQueued), findsOneWidget,
        reason: 'the other phone cannot be reached and nothing on the glass says so: a note sits '
            'at `going` and the person watching it has no way to tell a phone out of range from a '
            'message that was refused');

    // and it goes away again, rather than becoming furniture
    transport.scriptedFaults.goOnline();
    for (var i = 0; i < 20 && scope.link.state == LinkState.offline; i++) {
      await tester.runAsync(() => scope.sync.once().catchError((Object _) => false));
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.pump();
    expect(find.text(S.offlineQueued), findsNothing,
        reason: 'the link came back and the thread still says it is down');
  });
}
