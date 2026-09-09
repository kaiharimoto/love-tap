// A stroke does not arrive evenly, and until now it did.
//
// The material critic eroded every letter on the hero to its core and found three grey values
// before antialiasing, with two thirds of the pixels sharing one of them. That is the signature of
// a font drawn in a flat colour, and it is what separates writing from printing.
//
// So the two pens have coverage plates (tools/ink_plate.py) tiled under the letters and multiplied
// into their alpha. This renders a line in each hand, erodes it the way the critic did, and asks
// how much the ink varies inside its own strokes.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:desk/material/hands.dart';
import 'package:desk/material/ink.dart';
import 'package:desk/material/library.dart';
import 'package:desk/spine/event.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// The grey values of ink that is not on an edge: every dark pixel whose four neighbours are also
/// dark, which is the critic's erosion.
List<int> inkCore(ui.Image image, ByteData bytes) {
  final w = image.width, h = image.height;
  int lum(int x, int y) {
    final i = (y * w + x) * 4;
    final a = bytes.getUint8(i + 3);
    if (a < 200) return 255;
    return ((bytes.getUint8(i) + bytes.getUint8(i + 1) + bytes.getUint8(i + 2)) / 3).round();
  }

  final core = <int>[];
  for (var y = 1; y < h - 1; y++) {
    for (var x = 1; x < w - 1; x++) {
      final v = lum(x, y);
      if (v > 140) continue;
      if (lum(x - 1, y) > 140 || lum(x + 1, y) > 140 || lum(x, y - 1) > 140 || lum(x, y + 1) > 140) {
        continue;
      }
      core.add(v);
    }
  }
  return core;
}

void main() {
  setUpAll(() async {
    await MaterialLibrary.load();
    await InkPlates.load();
  });

  testWidgets('ink inside a stroke is not one value', (tester) async {
    if (!InkPlates.ready) {
      markTestSkipped('no ink plates packed: run python3 tools/pack_assets.py');
      return;
    }
    for (final who in [Person.noor, Person.teo]) {
      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        home: RepaintBoundary(
          key: key,
          child: ColoredBox(
            color: const Color(0xFFF1ECDF),
            child: Padding(
              padding: const EdgeInsets.all(8),
              // Short, because this is rasterised. The plate goes into the glyphs' own paint as a
              // repeated image shader, and this binding rasterises in software: a long line at 34
              // point through `toImage` at three times scale took the suite from ninety seconds to
              // over eight minutes, and the suite is what a capture waits on now. Four hundred ink
              // pixels is what the assertion needs and this gives thousands.
              child: Written('the boiler is sulking', by: who, size: 34),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      late List<int> core;
      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        core = inkCore(image, bytes);
      });
      expect(core.length, greaterThan(400), reason: 'nothing was written for ${who.name}');
      final mean = core.reduce((a, b) => a + b) / core.length;
      final variance =
          core.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / core.length;
      final sd = variance <= 0 ? 0.0 : _sqrt(variance);
      final distinct = core.toSet().length;
      final commonest = _commonestShare(core);
      // A flat colour gives three values and two thirds of the pixels on one of them. Real
      // coverage spreads across a range; these floors are well under what the plates produce and
      // well over what a flat fill can reach.
      expect(distinct, greaterThan(12),
          reason: '${who.name}: only $distinct distinct ink values inside the strokes');
      expect(sd, greaterThan(3.0),
          reason: '${who.name}: ink core varies by only ${sd.toStringAsFixed(2)} grey levels');
      expect(commonest, lessThan(0.5),
          reason: '${who.name}: ${(commonest * 100).round()}% of the ink is one exact value');
    }
  });
}

double _sqrt(double v) {
  var x = v;
  for (var i = 0; i < 40; i++) {
    x = 0.5 * (x + v / x);
  }
  return x;
}

double _commonestShare(List<int> values) {
  final counts = <int, int>{};
  for (final v in values) {
    counts[v] = (counts[v] ?? 0) + 1;
  }
  final most = counts.values.reduce((a, b) => a > b ? a : b);
  return most / values.length;
}
