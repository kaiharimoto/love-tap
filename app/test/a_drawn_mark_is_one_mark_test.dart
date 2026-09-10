// Where one line crosses another, ink does not get darker.
//
// A drawn feeling is painted stroke by stroke through the pen's own coverage plate, and every one
// of those strokes was composited at less than full alpha — so a crossing carried two of them and
// came out darker than either, and so did the overlap between one segment of a stroke and the
// next. At three hundred per cent on the chat hero, `obj_window` read as six translucent
// rectangles laid over each other rather than as a window somebody drew: dead straight bars of
// uniform width with visibly darker joints.
//
// The whole mark goes into one layer now and is composited once. This rasterises it and reads the
// pixels: the darkest place in the mark must not be darker than the darkest place on a single
// bar of it.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:desk/feelings/drawn.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<ui.Image> drawnAt(WidgetTester tester, String object, {double size = 200}) async {
    final key = GlobalKey();
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: RepaintBoundary(
          key: key,
          child: ColoredBox(
            color: const Color(0xFFFFFFFF),
            child: DrawnFeelingMark(
                object: object, colour: const Color(0xB3202024), size: size, seed: 3),
          ),
        ),
      ),
    ));
    await tester.pump();
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    // Through runAsync: toImage is real engine work and the test binding's fake clock never
    // completes it otherwise — the future simply never returns.
    return (await tester.runAsync(() => boundary.toImage(pixelRatio: 1.0)))!;
  }

  Future<List<int>> lumaOf(WidgetTester tester, ui.Image image) async {
    final data =
        await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba));
    final b = data!.buffer.asUint8List();
    return [
      for (var i = 0; i < b.length; i += 4) ((b[i] + b[i + 1] + b[i + 2]) / 3).round(),
    ];
  }

  testWidgets('a crossing is not darker than the lines that cross', (tester) async {
    for (final object in ['obj_window', 'obj_scribble', 'obj_chair']) {
      if (!DrawnFeelingMark.has(object)) continue;
      final image = await drawnAt(tester, object);
      final lum = await lumaOf(tester, image);
      final inked = lum.where((v) => v < 250).toList()..sort();
      expect(inked.length, greaterThan(200), reason: '$object drew almost nothing');
      // The darkest pixel anywhere against the darkest tenth of the ink. Two strokes composited
      // over each other used to put the first well below the second; one layer cannot.
      final darkest = inked.first;
      final tenth = inked[inked.length ~/ 10];
      expect(darkest, greaterThanOrEqualTo(tenth - 6),
          reason: '$object has a place ${tenth - darkest} levels darker than its own ink, which '
              'is two strokes composited over each other rather than one mark');
    }
  });

  testWidgets('and a hand-drawn line is not a ruled one', (tester) async {
    // The straight bars of a window, walked. A line a person draws leaves where it was aimed and
    // comes back; a line this file used to draw was two points with one offset on each of them.
    final image = await drawnAt(tester, 'obj_window', size: 300);
    final lum = await lumaOf(tester, image);
    const w = 300;
    // the topmost ink row of every column inside the window's own span, which traces the top bar
    final top = <int>[];
    for (var x = (w * 0.30).round(); x < (w * 0.70).round(); x++) {
      for (var y = 0; y < w; y++) {
        if (lum[y * w + x] < 200) { top.add(y); break; }
      }
    }
    expect(top.length, greaterThan(50), reason: 'no top bar found to measure');
    // Against the straight line through it, not against its own mean: this bar is drawn on a
    // slope — the window's top runs from 0.22 to 0.20 of the height — and the slope on its own
    // puts several pixels of spread into a profile with no wobble in it at all, which is how a
    // ruled version of this bar passed a test named for not being ruled.
    final n = top.length;
    final sx = (n - 1) * n / 2.0;
    var sxx = 0.0, sy = 0.0, sxy = 0.0;
    for (var i = 0; i < n; i++) {
      sxx += i * i.toDouble();
      sy += top[i];
      sxy += i * top[i].toDouble();
    }
    final slope = (n * sxy - sx * sy) / (n * sxx - sx * sx);
    final intercept = (sy - slope * sx) / n;
    var ss = 0.0;
    for (var i = 0; i < n; i++) {
      final r = top[i] - (intercept + slope * i);
      ss += r * r;
    }
    final rms = math.sqrt(ss / n);
    // Measured both ways with this same code: ruled, the top of this bar reads 0.31 px about its
    // own line; walked, 0.55. The floor sits between them. It is not a large separation and it is
    // not meant to be — the bar is seven pixels wide with its caps overlapping, so tracing its top
    // edge smooths the wander down to about a tenth of what the pen was given. What this catches
    // is a return to the ruler, which is the thing that was actually wrong.
    expect(rms, greaterThan(0.45),
        reason: 'the top of the window is straight to $rms px about its own line over $n '
            'columns, against 0.31 for a ruled one: this is a ruler and not a hand');
  });
}
