// A message the other phone would not take says what it said about it.
//
// The far side refuses with a reason in its own words — "this phone is on an older version and
// cannot read that" — and the spine has kept it since refusals were added. The row said `it would
// not go`, offered `send it again`, and never said why: a messenger critic found the reason in the
// scene script and in the transport log and nowhere on the glass. A refusal a person cannot act on
// is a dead end however many ways out you draw beside it.
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

void main() {
  testWidgets('the row carries the words the other phone refused in', (tester) async {
    await MaterialLibrary.load();
    CaptureBus.wanted = true;
    addTearDown(() => CaptureBus.wanted = false);
    final spine = await Spine.open(
      SpineStore.memory(),
      const Identity(person: Person.teo, device: DeviceKind.pwa),
    );
    for (var i = 0; i < 4; i++) {
      await spine.append('message', {'text': 'a line, number $i'},
          at: DateTime.utc(2026, 9, 3, 19, i), hostAssign: true);
    }
    // one that never got a seq, and a refusal for it in the other phone's own words
    final stuck = await spine.append('message', {'text': 'the second one, then'},
        at: DateTime.utc(2026, 9, 3, 19, 30));
    const why = 'this phone is on an older version and cannot read that';
    spine.markRefused(stuck.id, why);

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

    final words = tester
        .widgetList<Text>(find.byType(Text))
        .map((w) => w.data ?? '')
        .join(' | ');
    expect(words, contains('it would not go'), reason: 'the state is missing: "$words"');
    expect(words, contains(why), reason: 'the reason is missing: "$words"');
    expect(words, contains('send it again'), reason: 'the way out is missing: "$words"');

    // and the record says it too, so a reader of the log sees what a reader of the picture sees
    final report = CaptureBus.chatReport!();
    expect((report['refusals_on_the_glass'] as Map).values, contains(why));
  });
}
