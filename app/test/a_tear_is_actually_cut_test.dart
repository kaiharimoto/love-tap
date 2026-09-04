// A torn sheet is actually cut out, and the corners of its box are empty.
//
// This is the guard that was missing when it mattered most. The mask stopped being applied at all
// — a render object opened a layer, painted the child, and drew the mask over it with dstIn, and
// after PaintingContext.paintChild the context can be on a different canvas, so the saveLayer and
// the restore landed on two different ones. Every sheet in the app came out a hard rectangle, a
// whole capture ran that way, and the only reason it was caught was a person looking at a picture.
//
// So: render one piece over a known colour and read the pixels. A tear mask is empty at the
// extreme corners of its box — that is what being torn means — and full in the middle.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:desk/material/library.dart';
import 'package:desk/material/paper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _behind = Color(0xFF00FF00);   // nothing in the library is this, so it can only be showing through

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await MaterialLibrary.load();
  });

  testWidgets('the corners of a torn piece are the desk, not the paper', (tester) async {
    final lib = MaterialLibrary.instance;
    final tear = lib.writableTears.first;
    final stock = lib.stockVariants(lib.stocks.first).first;

    // Decode outside the fake-async zone: an image future never completes inside it, and a mask
    // that has not decoded leaves the sheet whole on purpose — which is exactly the state this
    // test would otherwise be asserting against.
    await tester.runAsync(() async {
      await MaskCache.load(tearAsset(tear));
      await MaskCache.load(tearAsset('${tear}_edge'));
    });

    // The boundary is the piece's own box and nothing else, so a corner of the image is a corner
    // of the piece. Wrapping the whole screen instead is how the first version of this test passed
    // with the mask switched off: the corners it read were the corners of the window.
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: RepaintBoundary(
          key: const ValueKey('shot'),
          child: SizedBox(
            width: 300,
            child: Stack(
              children: [
                const Positioned.fill(child: ColoredBox(color: _behind)),
                PaperPiece(
                  stockId: stock,
                  tearId: tear,
                  width: 300,
                  padding: EdgeInsets.zero,
                  safe: const [0, 0, 0, 0],
                  child: const SizedBox(height: 200),
                ),
              ],
            ),
          ),
        ),
      ),
    ));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }

    final boundary =
        tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
    // synchronous on purpose: toImage's future does not complete under flutter_tester's software
    // rendering, and a test that hangs for ten minutes is not a guard against anything
    final shot = boundary.toImageSync();
    late ByteData? data;
    await tester.runAsync(() async {
      data = await shot.toByteData(format: ui.ImageByteFormat.rawRgba);
    });
    final px = data!.buffer.asUint8List();
    final w = shot.width, h = shot.height;

    Color at(int x, int y) {
      final i = (y * w + x) * 4;
      return Color.fromARGB(px[i + 3], px[i], px[i + 1], px[i + 2]);
    }

    bool isBehind(Color c) => c.g > 0.7 && c.r < 0.35 && c.b < 0.35;

    // find the piece: the middle of the surface is where its writing would be
    final middle = at(w ~/ 2, h ~/ 2);
    expect(isBehind(middle), isFalse,
        reason: 'the middle of the piece is showing the background, so no paper was drawn at all');

    // and its four extreme corners are outside the tear
    final corners = <String, Color>{
      'top left': at(2, 2),
      'top right': at(w - 3, 2),
      'bottom left': at(2, h - 3),
      'bottom right': at(w - 3, h - 3),
    };
    for (final e in corners.entries) {
      expect(isBehind(e.value), isTrue,
          reason: 'the ${e.key} corner of the box is ${e.value}, not the desk: the tear mask is '
              'not being applied and the piece is a rectangle');
    }
  });
}
