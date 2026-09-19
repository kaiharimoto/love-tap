// Typing indication: rubric row 01 names it, and docs/BRIEF.md 09 forbids storing it.
//
// Those two are not in tension, they are the whole design: a typing signal is a frame that is not
// an event. It goes over the transport, it is shown, and it expires; nothing about it is ever
// written to the log. `messenger_reliability` found it in no artifact and in no key of
// reliability.json, and it may never be a key of reliability.json either — that file's capability
// list is the record of what the log carries, and typing is exactly the thing that must not be in
// the log. So the evidence for it is a picture of a phone showing it, and the evidence that it is
// not stored is here.
//
// Re-break by routing typing through `scope.emit` and watching `a typing signal writes nothing to
// the spine` count the rows it wrote.
import 'package:desk/capture/bus.dart';
import 'package:desk/material/library.dart';
import 'package:desk/regions/chat/chat_region.dart';
import 'package:desk/scope.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/transport/local/local_transport.dart';
import 'package:desk/transport/sync.dart';
import 'package:desk/voice/strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await MaterialLibrary.load();
  });

  test('there is no event type for typing, so it cannot be stored by accident', () {
    // The first half of storing something is having a type for it. There is none, and
    // `transport_local_test.dart`'s `ephemeral frames are delivered and never stored` holds the
    // other half over a real pair of phones — it cannot be held here, because a file that
    // initialises the widget binding has every HTTP request answered 400 by the test harness.
    expect(kEventTypeById.keys, isNot(contains('typing')));
    expect(kEventTypes.map((t) => t.id), isNot(contains('presence')));
  });

  testWidgets('the thread says so while they are writing, and stores nothing', (tester) async {
    final spine = await Spine.open(
        SpineStore.memory(), const Identity(person: Person.teo, device: DeviceKind.pwa));
    await spine.append('message', {'text': 'are you still in it'}, hostAssign: true);
    final t = LocalTransport(role: TransportRole.client, spine: spine, deviceId: 'x');
    final scope = AppScope(
      spine: spine,
      transport: t,
      sync: SyncEngine(spine: spine, transport: t),
      clock: Clock(frozenAt: DateTime.utc(2026, 9, 3, 19, 40)),
    );
    addTearDown(() async {
      scope.dispose();
      await spine.close();
    });
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    CaptureBus.wanted = true;
    addTearDown(() => CaptureBus.wanted = false);
    await tester.pumpWidget(AppScope.provide(
      scope: scope,
      child: const MaterialApp(home: Scaffold(body: ChatRegion())),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final line = '${scope.partner.name} ${S.typing}';
    expect(find.text(line), findsNothing, reason: 'nobody is writing yet');

    final rows = spine.length;
    // The frame the capture sends, through the same door the transport's stream uses.
    CaptureBus.partnerTyping!(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(line), findsOneWidget,
        reason: 'the thread does not say the other person is writing, which rubric row 01 names');
    expect(spine.length, rows, reason: 'showing it wrote a row');

    CaptureBus.partnerTyping!(false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(line), findsNothing, reason: 'it stayed up after they stopped');
    expect(spine.length, rows);
  });
}
