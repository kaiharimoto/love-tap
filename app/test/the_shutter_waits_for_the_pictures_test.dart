// A still is taken of what the screen became, or the log says it was taken early.
//
// `window.__deskReady` is set from the second post-frame callback after the first frame: the
// material library is loaded, the spine is open, one frame is on the glass. It is a claim about
// painting, and `tools/capture/scene.js` was reading it as a claim about content.
// `evidence/logs/04_moments.json` timed one run at 4771 ms to ready and then 2305 and 2828 before
// the shutter, against a gallery whose blob reads had not landed — so the artifact shows one
// photograph and six tiles reading "still fetching the picture.", and three of cycle 3's critics
// scored it as a screen that never fills. It was a screen that had not filled *yet*, and from the
// outside the two are the same picture. That ambiguity is worth thirty points: it is the cap on
// the heaviest row on the rubric.
//
// A screenshot cannot tell them apart. A log can, if something writes down what the screen was
// still waiting for at the moment the shutter went. So:
//
//   - `BlobCache.outstanding` is what the screen is still waiting for;
//   - `report()` carries it into every scene log as `blobs_pending`;
//   - `scene.js` waits on it before each shot, on a budget, and records the wait either way.
//
// The budget is the other half, and it is the half that keeps this honest. Waiting forever would
// photograph a lie: twelve seconds of blank grid is itself the row's disqualifier, and a harness
// that waits it out is a harness that hides it. So the wait is bounded, the wait is written down,
// and a scene that outruns it is recorded as having outrun it.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:desk/capture/bus.dart';
import 'package:desk/capture/hooks.dart';
import 'package:desk/material/library.dart';
import 'package:desk/voice/strings.dart';
import 'package:desk/regions/chat/blob_widgets.dart';
import 'package:desk/scope.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/spine/store/store.dart';
import 'package:desk/transport/local/local_transport.dart';
import 'package:desk/transport/sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A store that answers when it is told to, so the test decides what is outstanding and when.
class _HeldStore implements SpineStore {
  final MemoryStore _inner = MemoryStore();
  final List<({String hash, Completer<StoredBlob?> done})> _held = [];

  int get held => _held.length;

  Future<void> seedBlob(String hash, Uint8List bytes) => _inner.putBlob(hash, 'image/png', bytes);

  Future<void> serveOne() async {
    if (_held.isEmpty) return;
    final next = _held.removeAt(0);
    next.done.complete(await _inner.getBlob(next.hash));
  }

  @override
  Future<StoredBlob?> getBlob(String hash) {
    final done = Completer<StoredBlob?>();
    _held.add((hash: hash, done: done));
    return done.future;
  }

  @override
  Future<List<Event>> loadAll() => _inner.loadAll();
  @override
  Future<void> upsertAll(Iterable<Event> events) => _inner.upsertAll(events);
  @override
  Future<String?> getMeta(String key) => _inner.getMeta(key);
  @override
  Future<void> setMeta(String key, String? value) => _inner.setMeta(key, value);
  @override
  Future<void> putBlob(String hash, String mime, Uint8List bytes) =>
      _inner.putBlob(hash, mime, bytes);
  @override
  Future<bool> hasBlob(String hash) => _inner.hasBlob(hash);
  @override
  Future<List<String>> blobHashes() => _inner.blobHashes();
  @override
  Future<void> wipe() => _inner.wipe();
  @override
  Future<void> close() => _inner.close();
}

final Uint8List _onePixelPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

void main() {
  testWidgets('what the screen is still waiting for is a number the harness can read',
      (tester) async {
    if (!MaterialLibrary.loaded) await MaterialLibrary.load();
    CaptureBus.wanted = true;
    addTearDown(() => CaptureBus.wanted = false);
    BlobCache.reset();
    addTearDown(BlobCache.reset);

    final store = _HeldStore();
    const hashes = ['a', 'b', 'c', 'd', 'e', 'f'];
    for (final h in hashes) {
      await store.seedBlob(h, _onePixelPng);
    }
    final spine = await Spine.open(
      store, const Identity(person: Person.teo, device: DeviceKind.pwa));
    final transport = LocalTransport(role: TransportRole.client, spine: spine, deviceId: 'test');
    final scope = AppScope(
      spine: spine,
      transport: transport,
      sync: SyncEngine(spine: spine, transport: transport),
      clock: Clock(frozenAt: DateTime.utc(2026, 8, 30, 9, 14)),
    );
    addTearDown(scope.dispose);
    final hooks = CaptureHooks(scope);

    expect(BlobCache.outstanding, 0, reason: 'nothing has been asked for yet');
    expect(hooks.report()['blobs_pending'], 0);

    // Six pictures asked for, none answered: this is the moment the shutter was going in the
    // capture that produced 04_moments.
    for (final h in hashes) {
      unawaited(BlobCache.get(spine, h));
    }
    await tester.pump();
    expect(BlobCache.outstanding, hashes.length,
        reason: 'six reads are outstanding and the cache says ${BlobCache.outstanding}');
    expect(hooks.report()['blobs_pending'], hashes.length,
        reason: 'the scene log has to carry the number, or the still is unreadable afterwards');

    // The store answers them one at a time, the way one IndexedDB lane does.
    for (var i = 0; i < hashes.length; i++) {
      await store.serveOne();
      await tester.pump();
    }
    await tester.pump();
    expect(BlobCache.outstanding, 0,
        reason: 'every read came back and the cache still reports '
            '${BlobCache.outstanding} outstanding, so the harness would wait out its whole budget '
            'on a screen that had finished');
    expect(hooks.report()['blobs_pending'], 0);
  });

  test('every shot in the harness waits for the pictures before the shutter', () {
    // The source, because the behaviour is in a Node script this suite cannot run. What it
    // catches is the thing that will actually happen: somebody adds a `shot` case, or moves the
    // screenshot above the wait, and the evidence goes back to being ambiguous with nothing
    // failing. `04_moments` was photographed early for three cycles and every gate read green.
    final src = File('../tools/capture/scene.js').readAsStringSync();

    expect(src.contains('__deskBlobsPending'), isTrue,
        reason: 'the harness never asks the app what it is still waiting for');
    expect(src.contains('blob_waits'), isTrue,
        reason: 'the wait is not written into the scene log, so a still taken early cannot be '
            'told from a still of a screen that does not fill — which is the whole defect');

    // Every screenshot the harness takes is preceded by the wait. Checked by position rather than
    // by the presence of the call, because a wait that runs after the shutter is no wait at all.
    final shutters = <int>[];
    for (final m in RegExp(r'page\.screenshot\(').allMatches(src)) {
      shutters.add(m.start);
    }
    expect(shutters, isNotEmpty, reason: 'the harness takes no screenshots at all');
    final waits = RegExp(r'await settleBlobs\(').allMatches(src).map((m) => m.start).toList();
    expect(waits, isNotEmpty, reason: 'no shot waits for the pictures');

    // The still shots are the seventeen artifacts. A clip's frames are stepped off the driven
    // clock and are a different question, so only the `shot` case is required to wait here; what
    // must never happen is a `shot` case with no wait above it in the same block.
    final shotCase = src.indexOf("case 'shot': {");
    expect(shotCase, isNot(-1), reason: "the harness has no 'shot' step any more");
    final shotEnd = src.indexOf("case 'frames'", shotCase);
    final shotBlock = src.substring(shotCase, shotEnd < 0 ? src.length : shotEnd);
    final waitAt = shotBlock.indexOf('await settleBlobs(');
    final shutterAt = shotBlock.indexOf('page.screenshot(');
    expect(waitAt, isNot(-1), reason: 'the shot step does not wait for the pictures');
    expect(waitAt, lessThan(shutterAt),
        reason: 'the harness waits for the pictures after it has taken the photograph');
  });

  _theSecondNumber();

  test('the wait is bounded, because a slow screen is a fact and not a thing to wait out', () {
    // Twelve seconds of blank grid is the heaviest row's own disqualifier — a reason to open
    // Instagram. A harness that waits until the grid fills, however long that takes, photographs
    // a screen no person would ever see and reports the row as passing. So the budget exists, it
    // has a number, and running out of it is recorded.
    final src = File('../tools/capture/scene.js').readAsStringSync();
    expect(src.contains('blobsBudgetMs'), isTrue, reason: 'the wait has no budget');
    expect(RegExp(r'blobs_budget_ms').hasMatch(src), isTrue,
        reason: 'a scene cannot set its own budget, so a scene with no pictures in it pays the '
            'same wait as the gallery');
    expect(src.contains('pending_at_shot'), isTrue,
        reason: 'running out of the budget is not written down, so it is indistinguishable from '
            'a screen that filled');
  });
}

// ---------------------------------------------------------------------------------------------
// Firing 40. The wait above is real and it is not enough, because the number it waits on is not
// the number it is believed to be.
//
// `BlobCache.outstanding` counts READS: blobs the store has been asked for and has not answered.
// A read coming back is bytes arriving in Dart. Bytes arriving is not a picture — `Image.memory`
// still has to decode them, off the framework's clock, and until it does the `RawImage` is laid
// out at its full size with `image == null` and paints nothing at all.
//
// The shutter fits in that gap and went through it. `evidence/logs/04_moments.json` from firing
// 39 records `waited_ms 6969, pending_at_shot 0` and `blobs_pending 0`, and three of the
// gallery's twelve on-screen tiles are blank index card in `evidence/04_moments.png`: the
// paper's own red rule and blue lines run straight through the box the photograph goes in
// (correlation 0.91 between the row profile inside the box and the row profile of the slip's
// margin beside it, against -0.80 on a tile that has its photograph).
//
// And the proof that those three were a decode away rather than missing is in the harness's own
// ordering: `scene.js` writes the surfaces sidecar AFTER `page.screenshot`, and
// `04_moments.surfaces.json` declares a decoded 375x500 image in every one of the three boxes
// the PNG shows as empty paper. The artifact and the sidecar disagree about one frame. Between
// the two calls, the pictures arrived.
//
// So the queue item this was filed under — "a blob read that resolves to nothing and fails
// silently" — names the wrong cause. Nothing resolved to nothing: a read that comes back empty
// draws `S.pictureNotHere` in words, and there is no such run anywhere in
// `04_moments.text.json`. The read succeeded, the decode had not finished, and no number in the
// app could tell the difference.
void _theSecondNumber() {
  testWidgets('the reads landing is not the pictures arriving, and only one of them is on the glass',
      (tester) async {
    if (!MaterialLibrary.loaded) await MaterialLibrary.load();
    CaptureBus.wanted = true;
    addTearDown(() => CaptureBus.wanted = false);
    BlobCache.reset();
    addTearDown(BlobCache.reset);
    imageCache.clear();
    imageCache.clearLiveImages();

    final store = _HeldStore();
    await store.seedBlob('one', _onePixelPng);
    final spine = await Spine.open(
      store, const Identity(person: Person.teo, device: DeviceKind.pwa));
    final transport = LocalTransport(role: TransportRole.client, spine: spine, deviceId: 'test');
    final scope = AppScope(
      spine: spine,
      transport: transport,
      sync: SyncEngine(spine: spine, transport: transport),
      clock: Clock(frozenAt: DateTime.utc(2026, 8, 30, 9, 14)),
    );
    addTearDown(scope.dispose);
    final hooks = CaptureHooks(scope);

    // One picture, in a box the size a gallery tile's picture is. Nothing else in the tree draws
    // an image, so every number below is about this one.
    await tester.pumpWidget(AppScope.provide(
      scope: scope,
      child: const MaterialApp(
        home: Scaffold(
          body: Center(child: SizedBox(width: 140, height: 187, child: BlobImage(hash: 'one'))),
        ),
      ),
    ));
    await tester.pump();

    expect(BlobCache.outstanding, 1, reason: 'the tile has asked for its picture');
    expect(CaptureHooks.picturesPending(), 0,
        reason: 'while the read is outstanding there is no image box on screen at all — the '
            'widget is drawing a sentence — so this number is about the second step only');

    // The store answers. This is the moment `__deskBlobsPending` goes to zero and the harness
    // stops waiting.
    await store.serveOne();
    await tester.pump();
    await tester.pump();

    expect(BlobCache.outstanding, 0,
        reason: 'the read has landed, which is all the old signal ever knew');
    expect(hooks.report()['blobs_pending'], 0,
        reason: 'and the scene log says the screen is ready, which is what firing 39 believed');

    // THE DISCRIMINATOR. The bytes are in Dart and the picture is not on the glass: the box is
    // laid out at 140x187 with nothing in it, which on a print is the slip's own paper showing
    // through, which is the three blank tiles on 04_moments.
    expect(CaptureHooks.picturesPending(), 1,
        reason: 'the bytes arrived and the decode has not, and nothing in the app said so — this '
            'is the one frame the shutter went through on 04_moments');
    expect(hooks.report()['pictures_pending'], 1,
        reason: 'the scene log has to carry it, or the still is unreadable afterwards in exactly '
            'the way blobs_pending was unreadable');

    // And it clears, so the harness is not waiting out its budget on every scene forever after.
    // A decode happens off the framework's clock, so real time has to be allowed to pass.
    for (var i = 0; i < 40 && CaptureHooks.picturesPending() != 0; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    }
    expect(tester.takeException(), isNull);
    expect(CaptureHooks.picturesPending(), 0,
        reason: 'the picture is on the glass and the number has not come back down, so every '
            'shot after this one would pay the whole budget');
    expect(hooks.report()['pictures_pending'], 0);
  });

  testWidgets('a picture this phone does not have says so in words and does not hold the shutter',
      (tester) async {
    // The other half, and the reason this number is safe to block the shutter on. A blob that
    // resolves to nothing is a fact, not a wait: `BlobImage` draws `S.pictureNotHere`, which is a
    // paragraph and not an image box. If a missing picture counted here, every scene with one in
    // it would spend its entire budget and then be reported as shot early — the harness would
    // have swapped one silent lie for a loud wrong one.
    if (!MaterialLibrary.loaded) await MaterialLibrary.load();
    BlobCache.reset();
    addTearDown(BlobCache.reset);
    imageCache.clear();
    imageCache.clearLiveImages();

    final store = _HeldStore();
    // nothing seeded under this hash, so the read comes back null
    final spine = await Spine.open(
      store, const Identity(person: Person.teo, device: DeviceKind.pwa));
    final transport = LocalTransport(role: TransportRole.client, spine: spine, deviceId: 'test');
    final scope = AppScope(
      spine: spine,
      transport: transport,
      sync: SyncEngine(spine: spine, transport: transport),
      clock: Clock(frozenAt: DateTime.utc(2026, 8, 30, 9, 14)),
    );
    addTearDown(scope.dispose);

    await tester.pumpWidget(AppScope.provide(
      scope: scope,
      child: const MaterialApp(
        home: Scaffold(
          body: Center(child: SizedBox(width: 140, height: 187, child: BlobImage(hash: 'gone'))),
        ),
      ),
    ));
    await tester.pump();
    await store.serveOne();
    await tester.pump();
    await tester.pump();

    expect(BlobCache.outstanding, 0);
    expect(find.text(S.pictureNotHere), findsOneWidget,
        reason: 'a picture this phone does not have is said out loud, which is the behaviour '
            'this number is allowed to rely on');
    expect(CaptureHooks.picturesPending(), 0,
        reason: 'a missing picture is not a picture on its way, and counting it here would make '
            'every scene containing one pay the whole blob budget');
  });

  test('the shutter waits for the pictures and not only for the reads', () {
    // The source again, for the same reason the test above it reads the source: the behaviour is
    // in a Node script this suite cannot run, and what it catches is somebody adding a `shot`
    // path that asks only the old question. Reading the reads alone is not a smaller version of
    // this wait — it is the wait that let three blank tiles through with `pending_at_shot 0`
    // written in the log beside them.
    final src = File('../tools/capture/scene.js').readAsStringSync();
    expect(src.contains('__deskPicturesPending'), isTrue,
        reason: 'the harness never asks the app whether the pictures are on the glass, only '
            'whether the reads came back');
    expect(src.contains('undrawn_at_shot'), isTrue,
        reason: 'an empty picture box at the shutter is not written into the scene log, so a '
            'still taken one decode early is indistinguishable from a still of a screen with no '
            'photographs in it — which is exactly the reading three critics made of 04_moments');

    final shotCase = src.indexOf("case 'shot': {");
    final shotEnd = src.indexOf("case 'frames'", shotCase);
    final shotBlock = src.substring(shotCase, shotEnd < 0 ? src.length : shotEnd);
    expect(shotBlock.indexOf('await settleBlobs('), lessThan(shotBlock.indexOf('page.screenshot(')),
        reason: 'the wait is after the shutter');

    // And the wait actually goes on both. A poll that breaks on the reads alone has the handle in
    // the file and none of the behaviour.
    final settle = src.substring(src.indexOf('async function settleBlobs('));
    final body = settle.substring(0, settle.indexOf('\n  }\n'));
    expect(RegExp(r'pending === 0 && undrawn === 0').hasMatch(body), isTrue,
        reason: 'the poll stops when the reads have landed, whatever the pictures are doing');
  });
}
