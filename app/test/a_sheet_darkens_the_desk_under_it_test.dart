// The desk just under a sheet is darker than the desk a little further away.
//
// This is the one material claim that had no test and cost the most to find out about. The check
// that guards it runs only on a capture — tools/check/holes.py, which walks down every column,
// finds where a run of paper ends and compares a band four to fourteen pixels below it with a band
// forty-five to sixty-five below — and the first capture to run it failed eight of the ten stills:
// 3.6 grey levels in the chat hero, 0.05 in search, −0.17 in the pulse, −1.64 in Moments, against a
// floor of 6 taken from a capture where it worked.
//
// The cause was that a baked shadow is stretched to its piece, and a piece's shape is decided when
// its writing is laid out, so the width of its penumbra in millimetres was whatever the layout
// happened to make it — and the renders have almost none to stretch, because in them the sheet
// lies nearly flat and its shadow is genuinely underneath it.
//
// So the measurement runs here, on a piece drawn over the real wood, and it does not need a
// two-hour capture to answer.
//
// It is the stricter version of the check's: the bands are the same four to fourteen and
// forty-five to sixty-five, but taken from the last pixel that reads as paper rather than from the
// end of the tear's fringe. holes.py has to walk off the fringe first, because a torn edge in this
// build is about a centimetre of loose strands at phone scale and on a large sheet the whole
// window lands among them; a test picks its own sizes and does not need the allowance.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:desk/material/desk.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:desk/material/library.dart';
import 'package:desk/material/paper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The check's own bands, in device pixels.
const _near = (4, 14);
const _far = (45, 65);

Future<double> _darkerBy(WidgetTester tester, {String? tearId, required double height}) async {
  const width = 300.0;
  const surround = 130.0;
  tester.view.physicalSize = const Size(1440, 3120);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    // The boundary is *outside* the desk, or what comes back is the piece over nothing: an empty
    // pixel reads as luma 0 and the band further down the wood comes out darker than the shadow.
    home: Center(
      child: RepaintBoundary(
        key: const ValueKey('under.the.glass'),
        child: SizedBox(
          width: width + surround * 2,
          height: height + surround * 2,
          child: Desk(
            child: Center(
              child: PaperPiece(
                stockId: 'lined_01',
                tearId: tearId,
                safe: const [0.1, 0.12, 0.06, 0.12],
                padding: EdgeInsets.zero,
                child: SizedBox(width: width, height: height),
              ),
            ),
          ),
        ),
      ),
    ),
  ));
  // The wood, the stock and the tear all have to have arrived: a piece keeps its room and paints
  // nothing while its paper is still decoding, and a desk with no render on it is 62.7 grey levels
  // of flat colour rather than the 87 the stills measure.
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 700)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 40));

  // Both the grab and the read-back go through the real event loop: a toByteData awaited outside
  // runAsync never completes, because the test's own clock is the only thing turning.
  late Uint8List px;
  late int w;
  late int h;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('under.the.glass')));
    final shot = await boundary.toImage(pixelRatio: 3.0);
    final data = await shot.toByteData(format: ui.ImageByteFormat.rawRgba);
    px = data!.buffer.asUint8List();
    w = shot.width;
    h = shot.height;
    shot.dispose();
  });
  double lumaAt(int x, int y) {
    final i = (y * w + x) * 4;
    return (px[i] + px[i + 1] + px[i + 2]) / 3.0;
  }

  // holes.py's own walk: down each column, find where a run of paper ends, and compare the band
  // just below it with a band further down, keeping only the pairs where both are on the wood.
  final near = <double>[], far = <double>[];
  for (var x = 30; x < w - 30; x += 3) {
    var inPaper = false;
    var start = 0;
    for (var y = 0; y < h - 1; y++) {
      final i = (y * w + x) * 4;
      final isPaper = (px[i] + px[i + 1] + px[i + 2]) / 3.0 > 150.0 &&
          (px[i] - px[i + 2]) < 60;
      if (isPaper && !inPaper) {
        inPaper = true;
        start = y;
      } else if (!isPaper && inPaper) {
        inPaper = false;
        if (y - start > 40 && y + _far.$2 < h) {
          final a = <double>[for (var d = _near.$1; d < _near.$2; d++) lumaAt(x, y + d)];
          final b = <double>[for (var d = _far.$1; d < _far.$2; d++) lumaAt(x, y + d)];
          if (a.reduce((p, q) => p > q ? p : q) < 150 &&
              b.reduce((p, q) => p > q ? p : q) < 150) {
            near.addAll(a);
            far.addAll(b);
          }
        }
      }
    }
  }
  expect(near, isNotEmpty, reason: 'no paper edge with wood under it was found in the picture');
  double mean(List<double> v) => v.reduce((a, b) => a + b) / v.length;
  return mean(far) - mean(near);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await MaterialLibrary.load();
  });

  testWidgets('a torn sheet darkens the desk under its edge', (tester) async {
    final got = await _darkerBy(tester, tearId: 'tear_004', height: 420);
    expect(got, greaterThanOrEqualTo(6.0),
        reason: 'the desk four to fourteen pixels under a torn sheet is only '
            '${got.toStringAsFixed(2)} grey levels darker than forty-five to sixty-five below it');
  });

  testWidgets('and so does a cut one', (tester) async {
    final got = await _darkerBy(tester, height: 420);
    expect(got, greaterThanOrEqualTo(6.0),
        reason: 'a cut card casts ${got.toStringAsFixed(2)} grey levels');
  });

  testWidgets('a small piece casts as much as a large one, because a lift is a lift',
      (tester) async {
    // The fault the stretch produced: the penumbra was a fraction of the piece, so a chip's
    // shadow was a fifth of a note's for the same paper at the same height off the same desk.
    final big = await _darkerBy(tester, tearId: 'tear_004', height: 560);
    final small = await _darkerBy(tester, tearId: 'tear_004', height: 90);
    expect(small, greaterThanOrEqualTo(6.0), reason: 'a small piece casts $small');
    expect((small - big).abs(), lessThan(4.0),
        reason: 'the same paper at the same lift casts $small on a small piece and $big on a '
            'large one, so the shadow is a fraction of the piece rather than of the lift');
  });
}
