// A card that was cut is a card that was cut, not a rectangle drawn by a program.
//
// "Every module card is a machine-cut plate on a uniform blurred drop shadow: top/bottom edge
// roughness 0.00-0.81 px over 660 columns, TO DO exactly 673x164 px with 0.00 px roughness on all
// four sides, and its shadow is a constant band (mean 74.14 grey at 2 px below the edge rising
// monotonically to 93.75 at 26 px, with a column-to-column spread of 8.18 grey that is SMALLER
// than the bare wood's own 14.93)."
//
// Rasterised here and measured the way the critic measured it.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:desk/material/library.dart';
import 'package:desk/material/paper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the contact shadow under a cut card is not a constant band', (tester) async {
    await MaterialLibrary.load();
    tester.view.physicalSize = const Size(900, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      home: ColoredBox(
        color: const Color(0xFF62503C),
        child: Center(
          child: RepaintBoundary(
            key: key,
            child: const SizedBox(
              width: 700,
              height: 300,
              child: Center(
                // square to the desk on purpose: paper never is, and a tilted edge crosses
                // whole pixel rows along its length, which measures the tilt and not the shadow
                child: SizedBox(
                  width: 560,
                  height: 150,
                  child: PaperPiece(
                    stockId: 'index_01',
                    liftMm: 0.9,
                    tilt: 0,
                    seed: 12345,
                    windowed: true,
                    child: SizedBox(height: 90),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    late Uint8List rgba;
    late int w, h;
    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      w = image.width;
      h = image.height;
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      rgba = data!.buffer.asUint8List();
    });
    double lum(int x, int y) {
      final i = (y * w + x) * 4;
      return (rgba[i] + rgba[i + 1] + rgba[i + 2]) / 3.0;
    }

    // Where the card's bottom edge is, column by column, to a fraction of a pixel: the row where
    // the light crosses halfway between the card and the desk. A whole-pixel edge would quantise
    // exactly the thing being measured.
    const desk = (0x62 + 0x50 + 0x3C) / 3.0;
    final card = lum(w ~/ 2, 90);
    final half = (card + desk) / 2;
    final edge = <int, double>{};
    for (var x = 0; x < w; x++) {
      if (lum(x, 90) < half) continue;
      for (var y = 91; y < h; y++) {
        if (lum(x, y) < half) {
          final above = lum(x, y - 1), below = lum(x, y);
          edge[x] = above == below ? y.toDouble() : (y - 1) + (above - half) / (above - below);
          break;
        }
      }
    }
    expect(edge.length, greaterThan(200), reason: 'no card was drawn');
    final xs = edge.keys.toList()..sort();
    final inner = xs.sublist(12, xs.length - 12);
    final ys = [for (final x in inner) edge[x]!];
    // the cut may run at a slight angle; what is being measured is how far it wanders off its own
    // line, not the line
    final n = ys.length;
    final mx = inner.reduce((a, b) => a + b) / n;
    final my = ys.reduce((a, b) => a + b) / n;
    var sxy = 0.0, sxx = 0.0;
    for (var i = 0; i < n; i++) {
      sxy += (inner[i] - mx) * (ys[i] - my);
      sxx += (inner[i] - mx) * (inner[i] - mx);
    }
    final slope = sxx == 0 ? 0.0 : sxy / sxx;
    var res = 0.0;
    for (var i = 0; i < n; i++) {
      final d = ys[i] - (my + slope * (inner[i] - mx));
      res += d * d;
    }
    final roughness = math_sqrt(res / n);
    debugPrint('$n columns  bottom edge roughness ${roughness.toStringAsFixed(3)} px');
    expect(roughness, greaterThan(0.15),
        reason: 'the cut is a mathematical line (${roughness.toStringAsFixed(3)} px of wander over '
            '$n columns), which is a rectangle drawn by a program rather than a card that was cut');
  });
}

double math_sqrt(double v) {
  var x = v;
  for (var i = 0; i < 40; i++) {
    x = 0.5 * (x + v / x);
  }
  return x;
}
