// A piece of paper that is still waiting for its tear becomes a cut sheet, not a hole.
//
// The one message the far phone wrote while the link was down is delivered on reconnect in
// 08_state_propagating, and a messenger critic measured what it drew: the thread opened 72 logical
// pixels for it and painted bare desk there for the last 46 frames of the clip — max luma 184 over
// the whole band, zero pixels above 190, against 4.7 per cent above 150 on the text line 50 pixels
// above it. A message-shaped hole in a conversation, in the only artifact in the set about a
// message crossing a cut link.
//
// The mechanism is in paper.dart and it was deliberate: a piece keeps its room and paints nothing
// until its mask is out of the cache, because a sheet that appears as a square-cornered slab and
// tears a frame later is a light jump, and 07's clip failed the frame check on one of those. What
// it had no answer for was the mask that does not come in the next frame, or the one after, or at
// all.
//
// So the wait has a deadline. Before it, nothing is drawn — a_sheet_waits_for_its_paper holds that
// half. After it, the piece is a sheet that was cut rather than torn: a wandering edge, a nicked
// corner, its own contact shadow, which is what this app already draws for every card that never
// had a tear. Paper that is cut is still paper. A hole is not.
import 'dart:ui' as ui;

import 'package:desk/material/library.dart';
import 'package:desk/material/paper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _desk = Color(0xFF62503C);
const _deskLum = (0x62 + 0x50 + 0x3C) / 3.0;

/// The mean luminance of the middle of the piece's box — where paper is paper and no torn edge,
/// no shadow and no writing reaches.
Future<double> _middle(WidgetTester tester, GlobalKey key) async {
  late double lum;
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final rgba = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
    final w = image.width, h = image.height;
    var total = 0.0;
    var n = 0;
    for (var y = h ~/ 3; y < h - h ~/ 3; y++) {
      for (var x = w ~/ 3; x < w - w ~/ 3; x++) {
        final i = (y * w + x) * 4;
        total += (rgba[i] + rgba[i + 1] + rgba[i + 2]) / 3.0;
        n += 1;
      }
    }
    lum = total / n;
    image.dispose();
  });
  return lum;
}

Widget _piece(GlobalKey key, String tear) => MaterialApp(
      home: RepaintBoundary(
        key: key,
        child: ColoredBox(
          color: _desk,
          child: Center(
            child: SizedBox(
              width: 300,
              height: 200,
              // The height a message row took in the clip this is about, at the width a note is
              // drawn at: the shape of the hole.
              child: PaperPiece(
                stockId: 'lined_02',
                tearId: tear,
                liftMm: 0.9,
                child: const SizedBox(height: 72),
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('a piece whose tear never arrives is a cut sheet, not a hole in the thread',
      (tester) async {
    await MaterialLibrary.load();
    final tear = MaterialLibrary.instance.writableTears.last;
    // Genuinely cold: the claim is about a mask that is not in the cache and does not come.
    expect(MaskCache.peek(tearAsset(tear)), isNull, reason: 'the mask was already warm');

    final key = GlobalKey();
    tester.view.physicalSize = const Size(600, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_piece(key, tear));

    // A quarter of a second, with no real event loop turning, so the bundle read cannot have
    // landed: exactly the case the clip caught, where the mask did not come for 736 ms of driven
    // app time. Nothing is measured before this — reading the glass turns the event loop, the
    // decode lands, and the case under test stops being the case. The frame the piece is mounted
    // on, where nothing of it is drawn, is a_sheet_waits_for_its_paper's half of the rule.
    await tester.pump(const Duration(milliseconds: 250));

    // it says what it settled for, rather than leaving it to be measured off a frame
    expect(PaperPiece.tearsThatHaveNotArrived[tearAsset(tear)], 'cut',
        reason: 'a piece whose tear did not arrive did not settle for a cut sheet, so the capture '
            'has no way to tell a hole in a thread from a sheet that came up cut');

    final settled = await _middle(tester, key);
    expect(settled, greaterThan(150),
        reason: 'a piece whose tear did not arrive is still a hole in the thread: the middle of '
            'its box reads ${settled.toStringAsFixed(1)} against a desk of $_deskLum, where a '
            'sheet of paper reads over 150');
  });
}
