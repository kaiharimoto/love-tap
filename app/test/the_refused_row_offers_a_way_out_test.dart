// The third half of the dead end: what the row shows.
//
// `13_messenger_states.png` carried a permanently failed outbound message with a clear and
// well-worded failure marker — `it would not go` — and no retry, resend or try-again affordance
// anywhere on or beside it. A message that cannot be resent is a reason to open the other app,
// which is rubric row 01's own disqualifier wording.
//
// Re-break it by taking the `try again` out of `_Refused` in note.dart, or by wiring its tap to
// anything that does not clear the refusal, and both tests here fail.
import 'package:desk/material/library.dart';
import 'package:desk/regions/chat/chat_region.dart';
import 'package:desk/scope.dart';
import 'package:desk/spine/projections/thread.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/transport/local/local_transport.dart';
import 'package:desk/transport/sync.dart';
import 'package:desk/transport/transport.dart';
import 'package:desk/voice/strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppScope scope;
  late Spine spine;
  late Event refusedOne;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await MaterialLibrary.load();
    spine = await Spine.open(
        SpineStore.memory(), const Identity(person: Person.teo, device: DeviceKind.pwa));
    // One of theirs above it, so the refused row is not the only paper on the desk.
    await spine.append('message', {'text': 'is the roster up yet'}, hostAssign: true);
    refusedOne = await spine.append('message', {'text': 'sending you the roster'});
    spine.markRefused(refusedOne.id, S.refusedUnreadable);
    final transport =
        LocalTransport(role: TransportRole.client, spine: spine, deviceId: 'pwa-t');
    scope = AppScope(
      spine: spine,
      transport: transport,
      sync: SyncEngine(spine: spine, transport: transport),
      clock: Clock(frozenAt: DateTime.utc(2026, 9, 18, 13, 46)),
    );
    addTearDown(() async {
      scope.dispose();
      await spine.close();
    });
  });

  Future<void> draw(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(AppScope.provide(
      scope: scope,
      child: const MaterialApp(home: Scaffold(body: ChatRegion())),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  }

  testWidgets('a refused row says what happened, why, and what to press', (tester) async {
    await draw(tester);
    expect(scope.thread.byId[refusedOne.id]!.delivery, Delivery.refused);
    expect(find.text(S.refused), findsOneWidget);
    expect(find.text(S.refusedUnreadable), findsOneWidget,
        reason: 'the reason was on the row in the spine and stopped there');
    expect(find.text(S.tryAgain), findsOneWidget,
        reason: 'the one delivery state a person can act on offered nothing to act with');
  });

  testWidgets('pressing it puts the message back in the outbox', (tester) async {
    await draw(tester);
    expect(spine.outbox, isEmpty);

    await tester.tap(find.text(S.tryAgain));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(spine.refused, isEmpty, reason: 'the refusal survived the press');
    expect(spine.outbox.map((e) => e.id), contains(refusedOne.id),
        reason: 'the message is not back where the sync engine will pick it up');
    expect(scope.thread.byId[refusedOne.id]!.delivery, isNot(Delivery.refused));
    expect(find.text(S.tryAgain), findsNothing,
        reason: 'the row still offers a retry for something that is no longer refused');
  });
}
