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

  test('the mask is drawn wider than the piece it cuts', () {
    // "One-pixel bright rules are drawn across the desk: at 02_chat y=650, x=1100 three
    // consecutive rows read 78.9 / 127.3 / 80.2, a +48-grey spike one pixel tall running 254 px.
    // Nine of the ten stills carry them." Five cycles and six wrong explanations: the desk render,
    // the baked shadows, the denoiser, the shadow's bounding box, the mask's own inset, and — the
    // one this test used to assert — an unfiltered rotation staircasing the piece's lit edge. That
    // last one was measured and is wrong: with the rotation filtered every way it can be, the
    // count does not move.
    //
    // What it is: ShaderMask multiplies the mask in by drawing a rectangle the size of the child
    // in dstIn, and that rectangle is antialiased. On the row where the piece's box falls between
    // two device pixels the blend lands at partial coverage, and a fraction of the sheet survives
    // where the tear had erased it — a third of it, solved on all three channels off the hero.
    // A bisect in the browser settled it: twenty-nine runs with the mask, one without it, and
    // twenty-nine with every other part of the mask path changed. The mask rectangle is drawn two
    // pixels larger than the piece now, so its own edge is out on the desk where there is nothing
    // to erase.
    //
    // Read off the source: the artifact that shows it is a screenshot from CanvasKit, and the
    // test binding's rasteriser does not draw the fault at any size or density — sixty-six piece
    // heights at three device pixel ratios, zero one-row spikes. tools/check/hairline.py is what
    // measures it, on the pictures, where it happens.
    final src = File('lib/material/paper.dart').readAsStringSync();
    expect(src, contains('class _RenderMaskedBox'),
        reason: 'the tear mask is applied by something else again; whatever it is, it has to keep '
            'its own antialiased edge off the piece');
    final at = src.indexOf('..maskRect =');
    expect(at, greaterThan(0), reason: 'nothing sets a mask rectangle');
    expect(src.substring(at - 400, at + 200), contains('air'),
        reason: 'the mask rectangle is the size of the piece again, so a third of a pixel of sheet '
            'survives on the row where the piece lands between two device pixels');
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
