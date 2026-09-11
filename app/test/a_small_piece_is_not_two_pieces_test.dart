// A small card is one torn card, not two half-cards butted together.
//
// `drawImageNine` draws the four corners at their *source* pixel size. Every tear mask is 1024
// pixels on its long side and four tenths of it is the torn border, so a nine-patch wants a
// 410-pixel corner at each end — and a Moments tile is 450 device pixels wide altogether. Skia
// squeezes the two corners until they meet, and because the left corner's inner edge and the
// right corner's inner edge are different columns of the render, what lands is a dead-straight
// butt seam at the piece's exact mid-width with a step in it. A material critic measured one: a
// 21-pixel step at x=1190, the middle of a 04_moments voice-note tile.
//
// The short axis of an ordinary chat note never fitted either — 360 device pixels tall against a
// 462-pixel border — so this was on every note in the thread as a horizontal seam at mid-height.
@TestOn('vm')
library;

import 'dart:ui' as ui;

import 'package:desk/feelings/builtins.dart';
import 'package:desk/feelings/drawn.dart';
import 'package:desk/material/library.dart';
import 'package:desk/material/objects.dart';
import 'package:desk/material/paper.dart';
import 'package:desk/material/slip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// The first row of each column where the piece is solid, or null where the column is empty.
List<int?> topEdge(ui.Image img, List<int> rgba) {
  final out = <int?>[];
  for (var x = 0; x < img.width; x++) {
    int? found;
    for (var y = 0; y < img.height; y++) {
      if (rgba[(y * img.width + x) * 4 + 3] > 200) {
        found = y;
        break;
      }
    }
    out.add(found);
  }
  return out;
}

/// How far the edge moves from one column to the next, everywhere it is defined.
List<int> steps(List<int?> edge) {
  final out = <int>[];
  for (var i = 1; i < edge.length; i++) {
    final a = edge[i - 1], b = edge[i];
    if (a != null && b != null) out.add((b - a).abs());
  }
  return out;
}

void main() {
  setUpAll(() async => MaterialLibrary.load());

  /// One piece, rendered at the capture's own density, as raw pixels.
  Future<(ui.Image, List<int>)> render(
      WidgetTester tester, double w, double h, Widget piece) async {
    const dpr = 3.0;
    tester.view.physicalSize = const Size(480 * dpr, 1040 * dpr);
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0x00000000),
        body: Center(
          child: RepaintBoundary(key: key, child: SizedBox(width: w, height: h, child: piece)),
        ),
      ),
    ));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    late ui.Image img;
    late List<int> bytes;
    await tester.runAsync(() async {
      img = await boundary.toImage(pixelRatio: dpr);
      final d = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      bytes = d!.buffer.asUint8List();
    });
    return (img, bytes);
  }

  testWidgets('a Moments tile has no seam down its middle', (tester) async {
    final (img, bytes) = await render(
      tester,
      150,
      86,
      const Align(
        alignment: Alignment.topCenter,
        child: Slip(
          id: 'e1f0a2b3c4d5',
          row: 3,
          stock: 'receipt',
          width: 150,
          padding: EdgeInsets.fromLTRB(8, 8, 8, 9),
          child: SizedBox(height: 36, width: 134),
        ),
      ),
    );
    final edge = topEdge(img, bytes);
    final defined = edge.where((e) => e != null).length;
    expect(defined, greaterThan(img.width ~/ 2), reason: 'the piece did not draw');

    final all = steps(edge)..sort();
    final worst = all.last;
    final mid = img.width ~/ 2;
    // the step at the exact middle, which is where a butted pair of corners meets
    var middle = 0;
    for (var x = mid - 2; x <= mid + 2; x++) {
      final a = edge[x - 1], b = edge[x];
      if (a != null && b != null) middle = middle > (b - a).abs() ? middle : (b - a).abs();
    }
    // A torn edge wanders: a step of a few pixels is the tear. A step at the middle that is the
    // largest on the whole edge, and several times the rest, is two pictures meeting.
    expect(middle, lessThanOrEqualTo(worst),
        reason: 'the middle of the piece is its roughest column');
    expect(middle, lessThan(8), reason: 'a $middle-pixel step at the exact mid-width is a seam');
  });

  testWidgets('a feeling lands on a torn scrap, not on a card', (tester) async {
    // The landing scrap is about 190 points square, which is 570 device pixels against a
    // 1024-pixel render — one of the smallest pieces in the app, and squarely inside what the
    // nine-patch could not hold. A coherence critic read what came out as "an unlabelled,
    // straight-edged card with a drop shadow" in three clips.
    final feeling = kBuiltInFeelings.firstWhere((f) => DrawnFeelingMark.has(f.object));
    final (img, bytes) = await render(
      tester,
      190,
      190,
      Center(child: FeelingObject(feeling: feeling, size: 190, intensity: 0.85)),
    );
    final edge = topEdge(img, bytes);
    final rough = steps(edge).where((s) => s > 0).length;
    expect(rough, greaterThan(12),
        reason: 'the top of the scrap is a straight line: $rough columns of it move at all');
    final mid = img.width ~/ 2;
    var middle = 0;
    for (var x = mid - 2; x <= mid + 2; x++) {
      final a = edge[x - 1], b = edge[x];
      if (a != null && b != null) middle = middle > (b - a).abs() ? middle : (b - a).abs();
    }
    expect(middle, lessThan(12), reason: 'a $middle-pixel step at the exact mid-width is a seam');
  });

  test('a piece smaller than the render shrinks the tear rather than butting it', () async {
    final mask = await MaskCache.load(tearAsset('tear_001'));
    // A Moments tile: 450 x 258 device pixels against a 1024-wide render.
    final small = SlicedMasks.fitFor(mask, const Size(450, 258));
    expect(small, lessThan(1.0), reason: 'the borders cannot fit and nothing shrank');
    // Both borders and a fifth of the piece to stretch, which is what stops the corners butting.
    expect(2 * SlicedMasks.edge * mask.width * small, lessThanOrEqualTo(450 * 0.81));
    expect(2 * SlicedMasks.edge * mask.height * small, lessThanOrEqualTo(258 * 0.81));

    // A full sheet is bigger than the render and keeps its fibres at the size they were rendered.
    expect(SlicedMasks.fitFor(mask, const Size(1440, 2000)), 1.0);
  });

  test('and an ordinary chat note, which never fitted on its short axis either', () async {
    final mask = await MaskCache.load(tearAsset('tear_001'));
    // 340 logical points across at three device pixels to the point, about 120 tall.
    expect(SlicedMasks.fitFor(mask, const Size(1020, 360)), lessThan(1.0));
    expect(2 * SlicedMasks.edge * mask.height * SlicedMasks.fitFor(mask, const Size(1020, 360)),
        lessThanOrEqualTo(360 * 0.81));
  });
}
