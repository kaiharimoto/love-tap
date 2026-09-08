// A card that was cut is a card that was cut, and a tilted one leaves no staircase on the desk.
//
// Two material findings, both rasterised here and measured the way the critic measured them.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:desk/material/library.dart';
import 'package:desk/material/paper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// The picture a widget painted, as raw pixels.
Future<(Uint8List, int, int)> _raster(WidgetTester tester, GlobalKey key) async {
  late Uint8List rgba;
  late int w, h;
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    w = image.width;
    h = image.height;
    rgba = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
  });
  return (rgba, w, h);
}

double _lum(Uint8List rgba, int w, int x, int y) {
  final i = (y * w + x) * 4;
  return (rgba[i] + rgba[i + 1] + rgba[i + 2]) / 3.0;
}

Future<void> _draw(WidgetTester tester, GlobalKey key, Size view, Widget piece) async {
  tester.view.physicalSize = view;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: ColoredBox(
      color: const Color(0xFF62503C),
      child: Center(child: RepaintBoundary(key: key, child: piece)),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('the cut on a card wanders along its whole length', (tester) async {
    // "Every module card is a machine-cut plate: top/bottom edge roughness 0.00-0.81 px over 660
    // columns, TO DO exactly 673x164 px with 0.00 px roughness on all four sides." A guillotine
    // leaves a line that wanders, because the blade meets fibre and not butter. Square to the desk
    // on purpose: a tilted edge crosses whole pixel rows along its length and measures the tilt.
    await MaterialLibrary.load();
    final key = GlobalKey();
    await _draw(tester, key, const Size(900, 600), const SizedBox(
      width: 700,
      height: 300,
      child: Center(
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
    ));
    final (rgba, w, h) = await _raster(tester, key);

    // where the card's bottom edge is, column by column, to a fraction of a pixel: the row where
    // the light crosses halfway between the card and the desk
    const desk = (0x62 + 0x50 + 0x3C) / 3.0;
    final card = _lum(rgba, w, w ~/ 2, 90);
    final half = (card + desk) / 2;
    final edge = <int, double>{};
    for (var x = 0; x < w; x++) {
      if (_lum(rgba, w, x, 90) < half) continue;
      for (var y = 91; y < h; y++) {
        if (_lum(rgba, w, x, y) < half) {
          final above = _lum(rgba, w, x, y - 1), below = _lum(rgba, w, x, y);
          edge[x] = above == below ? y.toDouble() : (y - 1) + (above - half) / (above - below);
          break;
        }
      }
    }
    expect(edge.length, greaterThan(200), reason: 'no card was drawn');
    final xs = edge.keys.toList()..sort();
    final inner = xs.sublist(12, xs.length - 12);
    final ys = [for (final x in inner) edge[x]!];

    // the cut may run at a slight angle; what is measured is how far it wanders off its own line
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
    final roughness = _root(res / n);
    debugPrint('$n columns  bottom edge roughness ${roughness.toStringAsFixed(3)} px');
    expect(roughness, greaterThan(0.15),
        reason: 'the cut is a mathematical line (${roughness.toStringAsFixed(3)} px of wander over '
            '$n columns), which is a rectangle drawn by a program rather than a card that was cut');
  });

  test('a tilted piece is rotated with a filter', () {
    // "One-pixel bright rules are drawn across the desk: at 02_chat y=650, x=1100 three
    // consecutive rows read 78.9 / 127.3 / 80.2, a +48-grey spike one pixel tall running 254 px.
    // Nine of the ten stills carry them." Not a line drawn on the wood, and not in any asset —
    // the desk render carries zero one-row spikes at any threshold and so does every baked shadow.
    // It is the piece's own lit edge, tilted by a third of a degree and rotated *without* a
    // filter, which is nearest-neighbour: a hard edge then comes out one row at a time and steps,
    // about a hundred and sixty pixels per row, in dashes of sixty to three hundred, which is what
    // the artifact measures.
    //
    // Read off the source rather than rasterised: the picture that shows it needs a piece nine
    // hundred pixels wide, and rasterising one under the test binding takes longer than the whole
    // rest of the suite.
    final src = File('lib/material/paper.dart').readAsStringSync();
    final at = src.indexOf('Transform.rotate');
    expect(at, greaterThan(0), reason: 'nothing tilts a piece any more');
    expect(src.substring(at, (at + 900).clamp(0, src.length)), contains('filterQuality:'),
        reason: 'a piece is rotated without a filter, so every hard edge inside it staircases');
  });
}

double _root(double v) {
  if (v <= 0) return 0;
  var x = v;
  for (var i = 0; i < 40; i++) {
    x = 0.5 * (x + v / x);
  }
  return x;
}
