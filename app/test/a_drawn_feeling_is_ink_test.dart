// A feeling somebody drew is ink on paper, not a vector.
//
// An emotional critic put the gap exactly: "the two authored feelings render as a drawn mark on a
// torn card — pigeon a fish-bone on pale blue, tuesday soup an orange arc on off-white — while all
// thirty-six built-ins are rendered objects". A mark somebody made is allowed to look like a mark.
// It is not allowed to look like a stroke of flat colour beside thirty-six photographs of things.
//
// The same measurement the handwriting is held to, on the same plates: erode the mark to its core
// and ask how much the ink varies inside its own strokes.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:desk/feelings/drawn.dart';
import 'package:desk/material/ink.dart';
import 'package:desk/material/library.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every dark pixel whose four neighbours are also dark: the critic's erosion.
List<int> _core(ui.Image image, ByteData bytes) {
  final w = image.width, h = image.height;
  int lum(int x, int y) {
    final i = (y * w + x) * 4;
    if (bytes.getUint8(i + 3) < 200) return 255;
    return ((bytes.getUint8(i) + bytes.getUint8(i + 1) + bytes.getUint8(i + 2)) / 3).round();
  }

  final out = <int>[];
  for (var y = 1; y < h - 1; y++) {
    for (var x = 1; x < w - 1; x++) {
      if (lum(x, y) > 140) continue;
      if (lum(x - 1, y) > 140 || lum(x + 1, y) > 140 || lum(x, y - 1) > 140 || lum(x, y + 1) > 140) {
        continue;
      }
      out.add(lum(x, y));
    }
  }
  return out;
}

void main() {
  setUpAll(() async {
    await MaterialLibrary.load();
    await InkPlates.load();
  });

  testWidgets('a drawn mark carries the pen\'s coverage', (tester) async {
    if (!InkPlates.ready) {
      markTestSkipped('no ink plates packed: run python3 tools/pack_assets.py');
      return;
    }
    // the busiest of them, so the erosion has enough core to measure
    final id = kDrawnFeelings.keys.firstWhere((k) => k.contains('thumbprint'),
        orElse: () => kDrawnFeelings.keys.first);
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      home: RepaintBoundary(
        key: key,
        child: ColoredBox(
          color: const Color(0xFFF1ECDF),
          child: Center(
            child: SizedBox(
              width: 220,
              height: 220,
              // Through the widget the app draws, not through a painter of this test's own.
              //
              // It used to call the recipe directly with a DrawingHand, and when the pen's
              // coverage moved off the individual strokes and onto the finished mark — because a
              // stroke drawn through the plate is drawn at the plate's own alpha, so every
              // junction inside a walked stroke doubled and the mark beaded — this test kept
              // measuring the path the app had stopped using, and read one distinct value.
              child: DrawnFeelingMark(
                  object: id, colour: const Color(0xFF2B2B2E), size: 220, seed: 7),
            ),
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
      core = _core(image, bytes);
    });
    expect(core.length, greaterThan(200), reason: '$id drew almost nothing');
    final distinct = core.toSet().length;
    final commonest = _commonest(core);
    final mean = core.reduce((a, b) => a + b) / core.length;
    var v = 0.0;
    for (final x in core) {
      v += (x - mean) * (x - mean);
    }
    final sd = v <= 0 ? 0.0 : _sqrt(v / core.length);
    // ignore: avoid_print
    print('$id: ${core.length} core px, $distinct distinct, sd ${sd.toStringAsFixed(2)}, '
        'commonest ${(commonest * 100).round()}%');
    // Measured both ways on this mark: through the plate it reads 97 distinct values with a
    // standard deviation of 21.2; drawn in flat colour with the same taper it reads 24 and 7.5.
    // The taper alone is why a value count is not enough on its own — a stroke that swells has
    // more than one value whatever it is drawn with. These sit between the two.
    expect(distinct, greaterThan(48),
        reason: '$id has only $distinct distinct ink values inside its strokes, which is what a '
            'tapered stroke of flat colour gives');
    expect(sd, greaterThan(13.0),
        reason: '$id: ink core varies by only ${sd.toStringAsFixed(2)} grey levels');
    expect(commonest, lessThan(0.10),
        reason: '$id: ${(commonest * 100).round()} per cent of its ink is one exact value');
  });
}

double _sqrt(double x) {
  var g = x;
  for (var i = 0; i < 40; i++) {
    g = 0.5 * (g + x / g);
  }
  return g;
}

double _commonest(List<int> values) {
  final counts = <int, int>{};
  for (final v in values) {
    counts[v] = (counts[v] ?? 0) + 1;
  }
  return counts.values.reduce((a, b) => a > b ? a : b) / values.length;
}
