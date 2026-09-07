// A video in the thread is a video, and a picture already in hand is drawn on this frame.
//
// Two messenger findings, both measured on the artifacts by a critic:
//
//   - "although two reports count a video event, no artifact shows a video row rendered — the
//     video row is clipped to a blank 50-logical-pixel sliver of paper at y 2645-2790 with no
//     poster, play control, duration, timestamp or marker". Fourteen of the seeded year's videos
//     have no poster frame at all, and the row asked the store for a hash it does not hold and
//     then sat on the sentence about fetching for ever.
//   - "the photo is fully rendered from frame 64 to frame 92 and on exactly three isolated frames
//     it vanishes ... and the row reads 'still fetching the picture.'". A FutureBuilder handed a
//     future that has already finished still builds once with no data, and a fling rebuilds a row
//     every time it comes back into view.
import 'dart:typed_data';

import 'package:desk/material/library.dart';
import 'package:desk/material/marks.dart';
import 'package:desk/regions/chat/blob_widgets.dart';
import 'package:desk/regions/chat/chat_region.dart';
import 'package:desk/scope.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/spine/store/store.dart';
import 'package:desk/transport/local/local_transport.dart';
import 'package:desk/transport/sync.dart';
import 'package:desk/voice/strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A one-pixel PNG, so the store holds something a decoder will take.
final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

Future<AppScope> _aScope() async {
  final spine = await Spine.open(
    SpineStore.memory(),
    const Identity(person: Person.teo, device: DeviceKind.pwa),
  );
  final transport = LocalTransport(role: TransportRole.client, spine: spine, deviceId: 'test');
  return AppScope(
    spine: spine,
    transport: transport,
    sync: SyncEngine(spine: spine, transport: transport),
    clock: Clock(frozenAt: DateTime.utc(2026, 8, 30, 9, 14)),
  );
}

Future<void> _draw(WidgetTester tester, AppScope scope, Widget screen) async {
  tester.view.physicalSize = const Size(1440, 3120);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(AppScope.provide(
    scope: scope,
    child: MaterialApp(home: Scaffold(body: screen)),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await MaterialLibrary.load();
  });

  testWidgets('a video with no frame off it still says what it is and how long it runs',
      (tester) async {
    final scope = await _aScope();
    addTearDown(scope.dispose);
    await scope.spine.append('video', {
      'blob': 'the-film',
      'poster_blob': '',
      'duration_ms': 62000,
      'w': 1920,
      'h': 1080,
      'caption': 'the canal at the turn',
    }, hostAssign: true);

    await _draw(tester, scope, const ChatRegion());

    expect(find.byType(Mark), findsWidgets, reason: 'no mark to press: the row is a blank sliver');
    expect(find.text('62s'), findsOneWidget, reason: 'the row does not say how long it runs');
    expect(find.text(S.fetching), findsNothing,
        reason: 'a video with no poster frame asked the store for a hash it does not hold');
    expect(find.text('the canal at the turn'), findsOneWidget);
  });

  testWidgets('a picture already in hand is handed to the frame that draws it', (tester) async {
    // The frame itself cannot be caught here: flutter_test drains the microtask queue before it
    // builds, so the `then` on an already-finished future has always run by the time the widget
    // is built and the gap never opens in a test. On a phone drawing sixty frames a second it
    // does, and a critic measured it on three frames of a three-hundred-frame fling. So what is
    // asserted is the mechanism that closes it: what has come is kept, and the row is handed it
    // as the data it starts from rather than being told to wait for it again.
    final scope = await _aScope();
    addTearDown(scope.dispose);
    final held = await scope.spine.putBlob(_png, 'image/png');
    BlobCache.forget(held);

    await _draw(
      tester,
      scope,
      SizedBox(width: 200, height: 200, child: BlobImage(hash: held)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget, reason: 'the picture never arrived');
    expect(BlobCache.peek(held), isNotNull, reason: 'what came was not kept');

    // and now the row is built from nothing, the way a fling builds one that comes back into view
    await tester.pumpWidget(AppScope.provide(
      scope: scope,
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 200,
            child: BlobImage(key: const ValueKey('again'), hash: held),
          ),
        ),
      ),
    ));
    await tester.pump();
    final builder = tester.widget<FutureBuilder<StoredBlob?>>(
      find.byType(FutureBuilder<StoredBlob?>),
    );
    expect(builder.initialData, isNotNull,
        reason: 'the row was built with nothing in hand, so its first frame is the sentence about '
            'fetching a picture that is already here');
    expect(find.text(S.fetching), findsNothing);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('a picture the store does not hold is a blank print, not a promise', (tester) async {
    final scope = await _aScope();
    addTearDown(scope.dispose);
    BlobCache.forget('never-had-it');
    await _draw(
      tester,
      scope,
      const SizedBox(width: 200, height: 200, child: BlobImage(hash: 'never-had-it')),
    );
    await tester.pumpAndSettle();
    expect(find.text(S.fetching), findsNothing,
        reason: 'the store has answered and does not have it: it is not still coming');
  });
}
