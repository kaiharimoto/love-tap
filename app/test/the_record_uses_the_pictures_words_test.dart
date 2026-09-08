// The record of a picture uses the picture's own words.
//
// "The glass draws 'read ✓✓' twice, 'it would not go ✗' in red, and 'going ⦀'. The report's
// states_on_the_glass is {read: 3, sent: 1, refused: 1}: it records a row as 'sent' when no
// 'sent ✓' appears anywhere in the frame, and it never records 'sending', which is the state
// whose word is 'going'." A record written in the enum's names and a picture drawn in the app's
// words cannot be checked against each other, which is the whole point of writing the record.
import 'dart:io';

import 'package:desk/capture/bus.dart';
import 'package:desk/material/library.dart';
import 'package:desk/regions/chat/chat_region.dart';
import 'package:desk/regions/chat/note.dart';
import 'package:desk/scope.dart';
import 'package:desk/spine/projections/thread.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/spine/store/store.dart';
import 'package:desk/transport/local/local_transport.dart';
import 'package:desk/transport/sync.dart';
import 'package:desk/transport/transport.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('what the report says a row said is what the row says', (tester) async {
    await MaterialLibrary.load();
    CaptureBus.wanted = true;
    addTearDown(() => CaptureBus.wanted = false);
    final spine = await Spine.open(
      SpineStore.memory(),
      const Identity(person: Person.teo, device: DeviceKind.pwa),
    );
    for (var i = 0; i < 4; i++) {
      await spine.append('message', {'text': 'one of mine, number $i'},
          at: DateTime.utc(2026, 5, 1).add(Duration(minutes: i * 11)), hostAssign: true);
    }
    // one taken back: it draws no delivery mark, because a delivery state is about writing on its
    // way and there is none
    final gone = spine.all.last;
    await spine.append('message_delete', {'target': gone.id}, hostAssign: true);
    final transport = LocalTransport(role: TransportRole.client, spine: spine, deviceId: 't');
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

    final report = CaptureBus.chatReport!();
    final states = (report['states_on_the_glass'] as Map).cast<String, dynamic>();
    expect(states, isNotEmpty, reason: 'nothing on the glass carried a delivery state');
    for (final said in states.keys) {
      expect(find.text(said), findsWidgets,
          reason: 'the record says a row on the glass said "$said" and no row does');
    }
    // and the row that was taken back is not counted: it draws no mark
    final delivery = (report['delivery'] as Map).cast<String, dynamic>();
    expect(delivery.containsKey(gone.id), isFalse,
        reason: 'a row taken back has no delivery mark and the record counted one');
    // the words are the app's, not the enum's
    expect(deliverySays(Delivery.sending), 'going');
    expect(deliverySays(Delivery.refused), 'it would not go');
  });

  // The widget test above can only reach the states a spine of its own reaches — `sent`, whose
  // word happens to be its own name. What keeps the other four honest is that there is one table:
  // the mark that draws a state and the record that reports it read the same function, so they
  // cannot drift again. Read off the source, because that is where the drift would be.
  test('the delivery mark says what deliverySays says', () {
    final src = File('lib/regions/chat/note.dart').readAsStringSync();
    final at = src.indexOf('class _DeliveryMark');
    expect(at, greaterThan(0));
    final body = src.substring(src.indexOf('return switch (delivery)', at));
    final arms = RegExp(r'Delivery\.\w+ =>').allMatches(body).length;
    expect(arms, Delivery.values.length, reason: 'a delivery state with no mark of its own');
    for (final m in RegExp(r'_said\(\s*([A-Za-z.]+)').allMatches(body)) {
      expect(m.group(1), 'deliverySays',
          reason: 'the mark draws ${m.group(1)} and the record reports deliverySays: two tables '
              'for one thing is how the record came to say `sent` for a row that says `going`');
    }
  });
}
