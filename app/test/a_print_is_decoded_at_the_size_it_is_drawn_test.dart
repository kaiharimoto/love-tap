// A print in the gallery is decoded at the size of the print, not at the size of the photograph.
//
// `BlobImage` has carried this paragraph since it was written:
//
//   > A print in the Moments gallery is about a third of the screen wide and the photograph behind
//   > it is a full-size one, so decoding it at its own resolution puts nine times the pixels it can
//   > ever show into the image cache, per tile, across a year of them. cacheWidth decodes at the
//   > size being drawn. It is only passed when a width is actually known: with no width there is
//   > nothing to decode against and a guess would be worse than the original.
//
// `cacheWidth` was passed only when `BlobImage.width` was non-null, and **no call site in the app
// ever passed one**. The gallery the paragraph is about puts its `BlobImage` inside an
// `AspectRatio` and gives it no width; so does the print in the thread. So the sentence was true
// of a parameter nobody used, the guard was the whole of the behaviour, and every photograph in
// this app has been decoded at full size for the life of the build — in the one region whose
// capture came back as tiles reading "still fetching the picture."
//
// The width was never unknown. It is in the widget's own constraints, which is where a picture
// inside an `AspectRatio` has always been told exactly how wide it will be drawn.
//
// The number this file asserts is the decoded pixel width of what is on screen, read off the
// `RawImage` the framework is painting. It is the defect itself rather than a proxy for it: a
// duration would measure this machine, and a count of `cacheWidth` call sites would pass on a
// build that computed the wrong one.
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:desk/material/desk.dart';
import 'package:desk/material/library.dart';
import 'package:desk/regions/chat/blob_widgets.dart';
import 'package:desk/regions/moments/moments_region.dart';
import 'package:desk/scope.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/transport/local/local_transport.dart';
import 'package:desk/transport/sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The size a seeded photograph is, in pixels. Large on purpose: the whole question is whether
/// what reaches the image cache is this or the size of the tile.
const _photoW = 1200;
const _photoH = 1600;

/// A real encoded photograph, at [_photoW] by [_photoH].
///
/// Drawn rather than checked in: a file in the repository would be one more asset with a
/// generator to name, and what the test needs is only that the bytes decode at a known size.
Future<Uint8List> _aPhotograph() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  // Not a flat fill — a flat fill is a thing a codec can store in almost no bytes, and a tiny
  // file would let a slow read look fast for the wrong reason.
  for (var y = 0; y < _photoH; y += 8) {
    canvas.drawRect(
      Rect.fromLTWH(0, y.toDouble(), _photoW.toDouble(), 8),
      Paint()..color = Color.fromARGB(255, (y * 7) % 256, (y * 13) % 256, (y * 29) % 256),
    );
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(_photoW, _photoH);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}

List<Event> _prints({int count = 24}) => [
      for (var i = 0; i < count; i++)
        Event(
          id: 'P${i.toString().padLeft(6, '0')}',
          seq: i + 1,
          author: i % 2 == 0 ? Person.noor : Person.teo,
          device: i % 2 == 0 ? DeviceKind.android : DeviceKind.pwa,
          ts: DateTime.utc(2025, 9, 1).millisecondsSinceEpoch + i * 1800000,
          type: 'photo',
          payload: {'blob': 'hash$i', 'w': _photoW, 'h': _photoH},
          blobs: ['hash$i'],
        ),
    ];

Future<AppScope> _scopeWith(List<Event> events, Uint8List photo) async {
  final store = SpineStore.memory();
  for (final e in events) {
    await store.putBlob(e.payload['blob'] as String, 'image/png', photo);
  }
  final spine = await Spine.open(
    store, const Identity(person: Person.teo, device: DeviceKind.pwa));
  await spine.importSeed(events);
  final transport = LocalTransport(role: TransportRole.client, spine: spine, deviceId: 'test');
  return AppScope(
    spine: spine,
    transport: transport,
    sync: SyncEngine(spine: spine, transport: transport),
    clock: Clock(frozenAt: DateTime.utc(2026, 8, 30, 9, 14)),
  );
}

/// Every decoded photograph currently on screen, by its decoded pixel width.
///
/// The paper stocks and the bits are `Image.asset` and are decoded too; they are told apart by
/// size, because only the seeded photograph is [_photoW] by [_photoH] in its source and only it
/// carries that aspect ratio exactly.
List<int> _decodedPhotoWidths(WidgetTester tester) {
  final out = <int>[];
  for (final raw in tester.widgetList<RawImage>(find.byType(RawImage))) {
    final img = raw.image;
    if (img == null) continue;
    // the seeded photograph's shape, whatever it was decoded down to
    if ((img.width * _photoH - img.height * _photoW).abs() > img.width) continue;
    out.add(img.width);
  }
  return out;
}

/// Pumps until the blob reads and the decodes have all landed, or gives up.
///
/// `pumpAndSettle` is not enough on its own: a decode happens off the framework's clock, so the
/// tree can be settled with nothing decoded yet. Real time has to be allowed to pass, which is
/// what `runAsync` is for.
Future<void> _settleDecodes(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    if (_decodedPhotoWidths(tester).isNotEmpty && i > 8) return;
  }
}

void main() {
  testWidgets('a print in the gallery is decoded at the width of the print', (tester) async {
    if (!MaterialLibrary.loaded) await MaterialLibrary.load();
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    BlobCache.reset();
    addTearDown(BlobCache.reset);
    // A decoded image is cached by bytes and target size across the whole process, so a full-size
    // decode left by another test would be handed back here and read as this test's own.
    imageCache.clear();
    imageCache.clearLiveImages();

    late final Uint8List photo;
    await tester.runAsync(() async => photo = await _aPhotograph());

    final events = _prints();
    final scope = await _scopeWith(events, photo);
    addTearDown(scope.dispose);

    await tester.pumpWidget(AppScope.provide(
      scope: scope,
      child: const MaterialApp(home: Scaffold(body: Desk(child: MomentsRegion()))),
    ));
    await _settleDecodes(tester);
    expect(tester.takeException(), isNull);

    final widths = _decodedPhotoWidths(tester);
    expect(widths, isNotEmpty,
        reason: 'no photograph was decoded at all, so this test measured nothing');

    // The screen is 480 logical px wide, the gallery is three columns inside a 16px margin with a
    // 7px gap, and a print insets its picture by 5px on each side:
    //   tile   = (480 - 16 - 7 * 2) / 3 = 150
    //   picture= 150 - 5 * 2            = 140 logical px
    //   drawn  = 140 * 3                = 420 device px
    // A little over that is a rounding or a layout the arithmetic above did not anticipate. Nine
    // times over it is the whole photograph.
    const drawn = 420;
    final worst = widths.reduce((a, b) => a > b ? a : b);
    // ignore: avoid_print
    print('gallery: ${widths.length} prints decoded, widest $worst px against $drawn drawn');
    expect(worst, lessThanOrEqualTo((drawn * 1.25).round()),
        reason: 'a print ${drawn}px wide on screen was decoded at ${worst}px, which is '
            '${(worst / drawn).toStringAsFixed(1)} times the pixels it can show in each direction '
            'and ${((worst / drawn) * (worst / drawn)).toStringAsFixed(0)} times the bytes. With '
            '${widths.length} of them on one screen that is what the grid is spending its first '
            'seconds on, and why the capture caught tiles with no thumbnail in them.');
  });

  testWidgets('the photograph somebody opened is decoded whole, because it zooms', (tester) async {
    // The other half of the rule, and the reason this is not simply "decode small everywhere".
    // ViewerPage wraps the picture in an InteractiveViewer at maxScale 6: a photograph decoded to
    // the width of the screen is the right number of pixels until somebody pinches it, and then
    // it is a blur that no amount of filtering puts back. The viewer asks for the whole thing.
    if (!MaterialLibrary.loaded) await MaterialLibrary.load();
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    BlobCache.reset();
    addTearDown(BlobCache.reset);
    imageCache.clear();
    imageCache.clearLiveImages();

    late final Uint8List photo;
    await tester.runAsync(() async => photo = await _aPhotograph());

    final events = _prints(count: 1);
    final scope = await _scopeWith(events, photo);
    addTearDown(scope.dispose);

    await tester.pumpWidget(AppScope.provide(
      scope: scope,
      child: const MaterialApp(
        home: Scaffold(
          body: Center(child: BlobImage(hash: 'hash0', fit: BoxFit.contain, urgent: true, full: true)),
        ),
      ),
    ));
    await _settleDecodes(tester);
    expect(tester.takeException(), isNull);

    final widths = _decodedPhotoWidths(tester);
    expect(widths, isNotEmpty, reason: 'the viewer decoded no photograph at all');
    expect(widths.first, _photoW,
        reason: 'the viewer decoded the photograph at ${widths.first}px instead of its own '
            '${_photoW}px, so pinching it to six times will show the interpolation rather than '
            'the picture');
  });
}
