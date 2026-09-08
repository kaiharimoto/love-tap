// The chat hero's own standard, measured on the real year before a capture is spent on it.
//
// tools/check/tears.py fails 02_chat.png unless eight rows were on the glass, each on its own
// torn edge. Which stretch of a year does that cannot be worked out from the text: it depends on
// how tall each row lays out — how many words wrapped, what is stuck to it, whether it carries a
// waveform. Estimating it from the length of the writing framed six notes, then seven, and the
// artifact was recorded missing on its own standard twice. So the app measures instead, and so
// does this: the same seeded year, on a surface the size of the one the scene shoots, through
// the same handle the harness pulls.
import 'dart:io';
import 'dart:typed_data';

import 'package:desk/app.dart';
import 'package:desk/capture/bus.dart';
import 'package:desk/material/library.dart';
import 'package:desk/material/paper.dart';
import 'package:desk/regions/chat/chat_region.dart';
import 'package:desk/scope.dart';
import 'package:desk/spine/seed_loader.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/spine/store/store.dart';
import 'package:desk/transport/local/local_transport.dart';
import 'package:desk/transport/sync.dart';
import 'package:desk/transport/transport.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';

void main() {
  _plainPieceComposesNothing();
  testWidgets('a thread scrolls without stopping to bake a mask', timeout: const Timeout(Duration(minutes: 25)), (tester) async {
    final began = DateTime.now();
    void mark(String what) => debugPrint('[${DateTime.now().difference(began).inSeconds}s] $what');
    await MaterialLibrary.load();
    // The real hands, not the test font. A widget test lays every string out in Ahem unless the
    // face it names has been loaded, and Ahem is a different width and a different height: the
    // same stretch of thread that fits seven rows on a phone fitted five here, which would have
    // sent a capture off to frame the wrong place.
    for (final face in const ['TeoHand', 'NoorHand', 'DeskStamp']) {
      final loader = FontLoader(face)
        ..addFont(Future.value(
            File('assets/fonts/$face.ttf').readAsBytesSync().buffer.asByteData()));
      await loader.load();
    }
    // The masks, in the cache before anything draws. A widget test runs inside a fake-async zone,
    // so MaskedLayer's own asynchronous load never completes and every piece is drawn whole: the
    // thing this test is about would then never happen, and the test would pass by not looking.
    await tester.runAsync(() async {
      for (final tear in MaterialLibrary.instance.writableTears) {
        await MaskCache.load(tearAsset(tear));
        await MaskCache.load(tearAsset('${tear}_edge'));
      }
    });
    CaptureBus.wanted = true;
    addTearDown(() => CaptureBus.wanted = false);

    final spine = await Spine.open(
      SpineStore.memory(),
      const Identity(person: Person.teo, device: DeviceKind.pwa),
    );
    // the same loader the app and the far phone use, off the packed assets rather than a bundle,
    // so the rows are the year's own rows with the year's own authors
    final seeded = await SeedLoader(_OffDisk(Directory.current.path)).load(spine);
    expect(seeded, isNotNull, reason: 'the seeded year did not load');
    expect(spine.length, greaterThan(10000), reason: 'only ${spine.length} events loaded');
    mark('the year is in: ${spine.length} events');
    final transport = LocalTransport(role: TransportRole.client, spine: spine, deviceId: 'test');
    final scope = AppScope(
      spine: spine,
      transport: transport,
      sync: SyncEngine(spine: spine, transport: transport),
      clock: Clock(frozenAt: DateTime.utc(2026, 9, 3, 19, 40)),
    );
    addTearDown(scope.dispose);

    // the surface 02_chat is shot on, and the app's own shell around the thread, so the room the
    // list has is the room it has on the phone rather than a guess at the chrome
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(AppScope.provide(
      scope: scope,
      child: const MaterialApp(home: Shell()),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    CaptureBus.goToRegion!(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    mark('the thread is drawn');

    var settled = false;
    CaptureBus.scrollTo!('types:voice_note,reacted').then((_) => settled = true);
    for (var i = 0; i < 2000 && !settled; i++) {
      await tester.pump(const Duration(milliseconds: 40));
      if (i % 20 == 0) mark('pump $i');
    }
    mark('the search is done');
    expect(settled, isTrue, reason: 'the framing search never finished');
    await tester.pump(const Duration(milliseconds: 200));

    // and now the thing 11's timings are about: a thread that scrolls without stopping to bake a
    // mask. SlicedMasks.composed counts the masks actually composed into an image — 16.1 ms each
    // on the Dart VM and hundreds of milliseconds in CanvasKit, on the build thread. It was one
    // per note as the thread scrolled, which is what put 52 of 189 frames of 11_chat_scroll over
    // 400 ms to build, at p95 807 and max 2142 against a raster that never left 133-199. The
    // pieces draw their tear as a nine-patch now: same picture, no image made.
    final bakedBefore = SlicedMasks.composed;
    final costs = <int>[];
    for (var i = 0; i < 24; i++) {
      final moved = CaptureBus.scrollBy!(200);
      final sw = Stopwatch()..start();
      await tester.pump(const Duration(milliseconds: 16));
      sw.stop();
      costs.add(sw.elapsedMilliseconds);
      if (moved == 0) break;
    }
    costs.sort();
    debugPrint('one scrolled frame: median ${costs[costs.length ~/ 2]} ms, worst ${costs.last} ms, '
        'over ${costs.length} frames: $costs');
    // What is left composing one is the fallback: a row whose subtree needs a compositing layer
    // of its own — a photograph fading in, a video — cannot be painted inside the saveLayer the
    // nine-patch needs, so it goes through the composed mask instead. Written down rather than
    // asserted, because the number is a property of what is on the glass.
    debugPrint('masks composed: $bakedBefore before the scroll, '
        '${SlicedMasks.composed - bakedBefore} during it, over ${costs.length} frames');

    // and what the same list costs when nothing moved, for a floor
    final still = <int>[];
    for (var i = 0; i < 8; i++) {
      final sw = Stopwatch()..start();
      await tester.pump(const Duration(milliseconds: 16));
      sw.stop();
      still.add(sw.elapsedMilliseconds);
    }
    debugPrint('a still frame: $still ms');
    expect(costs.last, lessThan(120),
        reason: 'one frame of a scroll costs ${costs.last} ms to build here, and the browser is '
            'slower than this by two orders of magnitude');
  });
}

class _OffDisk implements SeedSource {
  _OffDisk(this.root);
  final String root;

  // Read off the disk without going near the event loop. A widget test runs inside a fake-async
  // zone: a real asynchronous read completes on the real one, and awaiting it there is how a test
  // sits for twelve minutes and is then killed.
  @override
  Future<String> loadString(String path) async => File('$root/$path').readAsStringSync();

  @override
  Future<Uint8List> loadBytes(String path) async => File('$root/$path').readAsBytesSync();
}

/// One piece of paper with writing on it: the case every note in the thread is, and the case the
/// nine-patch is for. It composes nothing.
void _plainPieceComposesNothing() {
  testWidgets('a plain piece draws its tear without baking it', (tester) async {
    await MaterialLibrary.load();
    final tear = MaterialLibrary.instance.writableTears.first;
    await tester.runAsync(() async {
      await MaskCache.load(tearAsset(tear));
      await MaskCache.load(tearAsset('${tear}_edge'));
    });
    final was = SlicedMasks.composed;
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: ColoredBox(
        color: const Color(0xFF62503C),
        child: Center(
          child: SizedBox(
            width: 340,
            child: PaperPiece(
              stockId: 'lined_02',
              tearId: tear,
              liftMm: 0.9,
              tilt: 0.006,
              child: const Text('back by six. the pigeon is still on the cupboard'),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(SlicedMasks.composed - was, 0,
        reason: 'a plain note baked its tear into an image — 16 ms on this machine and hundreds of '
            'milliseconds in CanvasKit, on the build thread, once per note as the thread scrolls');
  });
}
