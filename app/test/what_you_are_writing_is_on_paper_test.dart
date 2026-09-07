// Everything you are writing is written on paper.
//
// The composer stack — the draft, the line saying what is being answered, what else can go in the
// envelope, and the note that they are writing too — was drawn straight onto the wood. Measured on
// 13_messenger_states.png with the WCAG ratio between the 3rd and 97th luminance percentiles, that
// band reads 1.76 to 2.22 to 1 across its whole height, while the placeholder telling you to write
// something reads 4.44:1. The text you type was half as legible as the prompt.
//
// The palette test next door does the arithmetic on the inks. This does the other half: that the
// ground under them is paper and not the desk.
import 'package:desk/material/library.dart';
import 'package:desk/material/slip.dart';
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
  setUpAll(() async {
    await MaterialLibrary.load();
  });

  testWidgets('the composer and everything above it sits on one sheet', (tester) async {
    final spine = await Spine.open(
      SpineStore.memory(),
      const Identity(person: Person.teo, device: DeviceKind.pwa),
    );
    await spine.append('message', {'text': 'the pigeon is still on the cupboard'},
        hostAssign: true);
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
    await tester.pump(const Duration(milliseconds: 300));

    final pad = find.byWidgetPredicate((w) => w is Slip && w.id == 'chat.writing');
    expect(pad, findsOneWidget, reason: 'the writing pad is the sheet the composer is written on');

    // the draft itself
    final field = find.byType(TextField);
    expect(field, findsWidgets);
    expect(find.ancestor(of: field.first, matching: pad), findsOneWidget,
        reason: 'the draft is written on the desk rather than on paper');

    // and the word that sends it
    final send = find.text(S.send);
    expect(send, findsOneWidget);
    expect(find.ancestor(of: send, matching: pad), findsOneWidget,
        reason: 'send is written on the desk rather than on paper');

    // the pad is the last thing in the region, so nothing of the composer is outside it
    final padBottom = tester.getBottomLeft(pad).dy;
    final regionBottom = tester.getBottomLeft(find.byType(ChatRegion)).dy;
    expect(padBottom, lessThanOrEqualTo(regionBottom + 1));
  });
}
