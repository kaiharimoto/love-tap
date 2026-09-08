// A piece of paper that is still being decoded is not a flat rectangle.
//
// 07's clip carried one frame of a note arriving before its mask had come out of the cache: a pale
// grey slab with square corners and no shadow, +11.6 grey levels of the whole screen, which is the
// light jump the frame check failed the clip on and the shape the anti-goal names. The piece keeps
// its room and paints nothing until its paper is there.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:desk/material/library.dart';
import 'package:desk/material/paper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _desk = Color(0xFF62503C);

Future<double> _middle(WidgetTester tester, GlobalKey key) async {
  late double lum;
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final rgba = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
    final w = image.width, h = image.height;
    final i = ((h ~/ 2) * w + w ~/ 2) * 4;
    lum = (rgba[i] + rgba[i + 1] + rgba[i + 2]) / 3.0;
    image.dispose();
  });
  return lum;
}

void main() {
  testWidgets('a torn sheet shows the desk until its mask is out of the cache', (tester) async {
    await MaterialLibrary.load();
    final lib = MaterialLibrary.instance;
    // one this run has not drawn yet, so its mask is genuinely not in the cache
    final tear = lib.writableTears.last;
    expect(MaskCache.peek(tearAsset(tear)), isNull, reason: 'the mask was already warm');

    final key = GlobalKey();
    tester.view.physicalSize = const Size(600, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: ColoredBox(
        color: _desk,
        child: Center(
          child: RepaintBoundary(
            key: key,
            child: SizedBox(
              width: 300,
              height: 200,
              child: PaperPiece(
                stockId: 'graph_01',
                tearId: tear,
                liftMm: 0.9,
                child: const SizedBox(height: 120),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();

    const deskLum = (0x62 + 0x50 + 0x3C) / 3.0;
    final loading = await _middle(tester, key);
    expect(loading, lessThan(deskLum + 12),
        reason: 'a sheet whose mask is still decoding painted itself anyway: the middle of the '
            'piece reads ${loading.toStringAsFixed(1)} against a desk of $deskLum, which is the '
            'flat rectangle of stock colour that ships in a clip as a light jump');

    // and when the mask lands, the sheet is there
    for (var i = 0; i < 40 && MaskCache.peek(tearAsset(tear)) == null; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
      await tester.pump();
    }
    await tester.pump();
    final landed = await _middle(tester, key);
    expect(landed, greaterThan(180),
        reason: 'the mask arrived and the sheet did not: the middle of the piece is still '
            '${landed.toStringAsFixed(1)}');
  });
}
