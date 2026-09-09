// The one delivery state a person could not get out of.
//
// A host refuses an event — a phone on an older version, a kind it has never heard of — and the
// row stays in the outbox marked `it would not go`, out of the wire, where its author can see it.
// That is right, and it was the whole of it: the note's menu offered reply, react, edit and
// delete, and none of those sends it. The other phone may have been on an older version an hour
// ago and not now.
import 'package:desk/material/library.dart';
import 'package:desk/regions/chat/chat_region.dart';
import 'package:desk/scope.dart';
import 'package:desk/spine/projections/thread.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/transport/local/local_transport.dart';
import 'package:desk/transport/sync.dart';
import 'package:desk/voice/strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppScope scope;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await MaterialLibrary.load();
  });
  setUp(() async {
    final spine = await Spine.open(
      SpineStore.memory(),
      const Identity(person: Person.teo, device: DeviceKind.pwa),
    );
    final transport = LocalTransport(role: TransportRole.client, spine: spine, deviceId: 'test');
    scope = AppScope(
      spine: spine,
      transport: transport,
      sync: SyncEngine(spine: spine, transport: transport),
      clock: Clock(frozenAt: DateTime.utc(2026, 9, 3, 19, 40)),
    );
  });
  tearDown(() => scope.dispose());

  testWidgets('a refused note can be sent again', (tester) async {
    final e = await scope.spine.append('message', {'text': 'the roster'});
    scope.spine.markRefused(e.id, 'this phone is on an older version and cannot read that');
    expect(scope.spine.pushable.any((p) => p.id == e.id), isFalse,
        reason: 'a refused event goes back over the wire for ever');
    expect(projectThread(scope.spine.all, refused: scope.spine.refused).byId[e.id]!.delivery,
        Delivery.refused);

    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(AppScope.provide(
      scope: scope,
      child: const MaterialApp(home: Scaffold(body: ChatRegion())),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.longPress(find.text('the roster'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(S.sendAgain), findsOneWidget,
        reason: 'the only thing to be done about a row that did not go is not on the menu: '
            'it offers ${S.reply}, ${S.react}, ${S.edit} and ${S.delete}, and none of those sends it');

    await tester.tap(find.text(S.sendAgain));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(scope.spine.refused, isEmpty, reason: 'the mark stayed on the row');
    expect(scope.spine.pushable.any((p) => p.id == e.id), isTrue,
        reason: 'the event is still out of the outbox after its author asked for it again');
  });
}
