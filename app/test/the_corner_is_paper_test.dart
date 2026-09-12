// The corner you pull to reach the whole emotional layer is a corner of a sheet of paper.
//
// It was a flat beige triangle with a gradient over it, on every screen and in every clip. An
// anti-goal critic measured it: 0.26 grey levels of high-frequency texture across its interior,
// eroded eight pixels in from every boundary, against 1.162 for the paper tab a hundred pixels
// away in the same frame and 4.099 for the desk — and, decisively, byte-identical between
// 01_pulse.png and crops/dusk_pulse.png over 4,316 interior pixels while the desk beside it moved
// by 25.7. A surface that does not answer the light in the room is not a surface in the room. "A
// beige rounded rectangle with a drop shadow" is the fourth anti-goal's own first example, and
// this was a beige shape standing in for a folded paper corner.
//
// So the two things it was missing, measured here rather than in a capture: it has the tooth of
// the sheet it is a corner of, and it is a different picture in the two lights the app has.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:desk/feelings/corner.dart';
import 'package:desk/material/library.dart';
import 'package:desk/material/light.dart';
import 'package:desk/material/paper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Luminance at every pixel of the grab.
List<double> _luma(Uint8List rgba) => [
      for (var i = 0; i < rgba.length; i += 4)
        0.299 * rgba[i] + 0.587 * rgba[i + 1] + 0.114 * rgba[i + 2],
    ];

/// The critic's own measure: luma minus a blur of itself, over the triangle's interior only.
///
/// A three-by-three box blur rather than a Gaussian — the claim is about whether there is any
/// structure at all at a pixel or two, and at 0.26 against 1.16 the shape of the kernel is not
/// what decides it.
double _tooth(List<double> l, int w, int h, bool Function(int, int) inside) {
  final v = <double>[];
  for (var y = 1; y < h - 1; y++) {
    for (var x = 1; x < w - 1; x++) {
      if (!inside(x, y)) continue;
      var sum = 0.0;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          sum += l[(y + dy) * w + x + dx];
        }
      }
      v.add(l[y * w + x] - sum / 9.0);
    }
  }
  if (v.length < 100) return 0;
  final mean = v.reduce((a, b) => a + b) / v.length;
  final s = v.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b) / v.length;
  return math.sqrt(s);
}

const _size = 74.0;

class _Grab {
  _Grab(this.luma, this.w, this.h);
  final List<double> luma;
  final int w;
  final int h;
}

Future<_Grab> _corner(WidgetTester tester, LightCondition light,
    {String stock = 'looseleaf_01'}) async {
  final key = GlobalKey();
  tester.view.physicalSize = const Size(_size * 3, _size * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Light(
      condition: light,
      child: RepaintBoundary(
        key: key,
        child: SizedBox(
          width: _size,
          height: _size,
          // At rest, which is how it stands in nine of the ten stills.
          child: TurnedCorner(curl: 0.0, stock: stock),
        ),
      ),
    ),
  ));
  // the sheet has to have decoded: the corner draws the flat colour until it has, which is the
  // thing this is about
  final want = paperAsset(light == LightCondition.dusk ? '${stock}_dusk' : stock);
  for (var i = 0; i < 40 && StockCache.peek(want) == null; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
    await tester.pump();
  }
  await tester.pump();
  late _Grab grab;
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    // at the density the phone draws it at, not at one pixel to the point
    final image = await boundary.toImage(pixelRatio: 3.0);
    final px = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
    grab = _Grab(_luma(px), image.width, image.height);
    image.dispose();
  });
  return grab;
}

void main() {
  // One test, three grabs. Two of these as separate `testWidgets` hung the runner: each passes
  // alone and together they do not come back, and what they share is a decoded sheet in a static
  // pool and a view whose size is reset between them. The two claims are about the same corner
  // anyway.
  testWidgets('the turned corner is paper, and it is lit by whichever light the desk is in',
      (tester) async {
    await MaterialLibrary.load();
    final day = await _corner(tester, LightCondition.day);
    final dusk = await _corner(tester, LightCondition.dusk);
    // The same corner with no sheet behind it: exactly what this drew for eleven cycles — the flat
    // colour and the gradient — so the measurement is against the thing it replaced rather than
    // against a number somebody chose.
    final flat = await _corner(tester, LightCondition.day, stock: 'no_such_stock');
    final w = day.w, h = day.h;
    expect(dusk.w, w);
    expect(flat.w, w);

    // the triangle at rest, eroded well in from all three of its sides
    bool inside(int x, int y) {
      final cx = x - w * 0.5, cy = y - h * 0.5;
      return x < w - 10 && y < h - 10 && cx + cy > w * 0.5 + 14;
    }

    final tooth = _tooth(day.luma, w, h, inside);
    final nothing = _tooth(flat.luma, flat.w, flat.h, inside);
    expect(tooth, greaterThan(nothing * 3),
        reason: 'the corner reads $tooth grey levels of texture against $nothing for the same '
            'corner with no sheet behind it: it is still a flat shape standing in for paper, '
            'which is the fourth anti-goal\'s own first example');

    var moved = 0.0;
    var n = 0;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (!inside(x, y)) continue;
        moved += (day.luma[y * w + x] - dusk.luma[y * w + x]).abs();
        n += 1;
      }
    }
    final apart = n == 0 ? 0.0 : moved / n;
    expect(apart, greaterThan(2.0),
        reason: 'day and dusk draw the same corner to within $apart grey levels: it is a shape '
            'over the scene rather than a surface in it');
  });
}
