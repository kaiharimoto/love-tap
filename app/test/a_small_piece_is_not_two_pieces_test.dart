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

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:desk/feelings/builtins.dart';
import 'package:desk/feelings/drawn.dart';
import 'package:desk/material/hands.dart';
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
    // A torn edge wanders: a step of a few pixels is the tear. What says two pictures have been
    // butted together is the middle standing out from the rest of the same edge — so it is
    // compared with the rest of the same edge, measured the same way.
    //
    // It used to be an absolute eight pixels, and eight was the old library's roughness rather
    // than a fact about seams. With the tear generator's amplitude floor raised, this edge reads
    // p50 2, p90 8, p95 9 and a worst of 19 somewhere that is not the middle: a nine-pixel step
    // in the middle of it is the tear, and the fault this test exists for was twenty-one pixels
    // at the exact mid-width of a 04_moments tile against an edge that was nothing like that
    // rough. Comparing the middle's five-column window with every other five-column window is the
    // comparison that means what the test says it means.
    final windows = <int>[];
    for (var c = 1; c + 4 < edge.length; c++) {
      var worstHere = 0;
      for (var x = c; x < c + 5; x++) {
        final a = edge[x - 1], b = edge[x];
        if (a != null && b != null) worstHere = math.max(worstHere, (b - a).abs());
      }
      windows.add(worstHere);
    }
    windows.sort();
    final ordinary = windows[(windows.length * 49) ~/ 50];
    expect(middle, lessThanOrEqualTo(math.max(ordinary, 6)),
        reason: 'a $middle-pixel step at the exact mid-width, against $ordinary for the roughest '
            'five columns of the other ninety-eight per cent of the same edge, is a seam');
    // and however rough the tear, a butted pair of corners is a step no tear makes
    expect(middle, lessThan(16),
        reason: 'a $middle-pixel step at the exact mid-width is two pictures meeting: the one this '
            'was written for measured twenty-one');
  });

  testWidgets('a chip is mostly paper, not mostly fringe', (tester) async {
    // A material critic measured the WRITTEN chip in 12_search holding six rows of solid paper
    // where it had held forty-nine, in a piece of about the same total extent: almost all of it
    // had become fringe. The cause is `SlicedMasks.fitFor`'s room to stretch in. It was a fifth —
    // the borders could take four fifths of the piece — which is nothing on a sheet and is the
    // whole of a chip, and it only began to bite when the band came to be measured per mask
    // rather than assumed at four tenths, because a smaller band means less shrinking and so
    // bigger fibres against a small piece.
    final (img, bytes) = await render(
      tester,
      86,
      34,
      const Align(
        alignment: Alignment.topCenter,
        child: Slip(
          id: 'c0ffee112233',
          row: 1,
          stock: 'index',
          width: 86,
          padding: EdgeInsets.fromLTRB(7, 5, 7, 6),
          child: SizedBox(height: 20, width: 72),
        ),
      ),
    );
    var solid = 0;
    for (var y = 0; y < img.height; y++) {
      var on = 0;
      for (var x = 0; x < img.width; x++) {
        if (bytes[(y * img.width + x) * 4 + 3] > 250) on++;
      }
      if (on >= img.width * 0.9) solid++;
    }
    expect(solid, greaterThanOrEqualTo(img.height ~/ 3),
        reason: 'only $solid of the chip\'s ${img.height} rows are nine tenths solid paper: the '
            'rest is the tear, and there is nowhere on it to write. At four fifths of room to '
            'stretch in, which is what this was, the answer is zero');
  });

  testWidgets('a chip\'s tear does not eat its word', (tester) async {
    // The systemic one. A coherence critic measured the filter chips in 12_search: the paper behind
    // 'DATES THAT MATTER' fell from 35,753 px to 19,149 against the previous capture, behind
    // 'PHOTOGRAPHS' from 29,643 to 15,160, while the words did not shrink — and the tops of ten
    // chips ended up outside their own sheets. The same defect ate the leading 't' of a ritual row
    // in the hero and cut a voice note's 'Thu 26 Mar 08:23 read' horizontally.
    //
    // A letter that misses its paper is not drawn on the desk — the mask erases it — so it cannot
    // be found by looking for ink outside the sheet. It is found by drawing the same chip twice,
    // once torn and once cut, and counting how much of the word survives.
    Future<int> inkOf({required bool torn}) async {
      final (img, bytes) = await render(
        tester,
        150,
        44,
        Align(
          alignment: Alignment.topCenter,
          child: Slip(
            id: 'a1b2c3d4e5f6',
            row: 2,
            stock: 'index',
            torn: torn,
            width: 150,
            padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
            child: const Stamped('photographs', size: 12),
          ),
        ),
      );
      var ink = 0;
      for (var y = 0; y < img.height; y++) {
        for (var x = 0; x < img.width; x++) {
          final i = (y * img.width + x) * 4;
          // the letters: dark, and on opaque paper rather than in the shadow beside it
          if (bytes[i + 3] > 200 && (bytes[i] + bytes[i + 1] + bytes[i + 2]) / 3.0 < 110) ink++;
        }
      }
      return ink;
    }

    final cut = await inkOf(torn: false);
    final torn = await inkOf(torn: true);
    expect(cut, greaterThan(200), reason: 'the chip drew no word at all');
    // Five per cent, from the bracket: at four fifths of room to stretch in the tear takes 6.5
    // per cent of this word, at a half it takes 3.4, and at a third it takes under 3 and puts a
    // line of shadow beside the paper darker than ink. A torn edge is allowed to soften the edge
    // of a word block; it is not allowed to take a letter.
    expect(torn / cut, greaterThan(0.95),
        reason: 'the tear ate ${((1 - torn / cut) * 100).toStringAsFixed(1)} per cent of the '
            'word — $torn pixels of ink on the torn chip against $cut on the same chip cut');
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

  testWidgets('a wide sheet keeps its fibres instead of having them stretched out', (tester) async {
    // A nine-patch pulls its top band across the whole width of the piece, so on a sheet four
    // times the width of that band the fibres come out at a quarter of their frequency and a
    // high-pass over 31 columns stops seeing them. A material critic traced every paper/wood
    // boundary in the stills: median rms 0.71 px, thirteen of twenty-two under one pixel, against
    // the masks' own 2.417 measured the same way. The four smoothest edges in 02_chat were its
    // four widest pieces.
    // A mask that actually tears its top edge, named rather than drawn from the pool.
    //
    // This rendered a Slip and let the assignment choose, and the assignment handed it tear_023,
    // whose kind is `cut`: it tears its right edge and guillotines the other three. The test then
    // measured a guillotined top edge and called it a straight tear — the same mistake
    // tools/check/torn.py made for four cycles. What this test is about is a *wide torn* edge
    // being pulled across a piece four times the width of its band, so it names a mask that has
    // one.
    final meta = jsonDecode(
            File('${Directory.current.parent.path}/assets/tears/tears.json').readAsStringSync())
        as Map<String, dynamic>;
    final masks = (meta['masks'] as List).cast<Map<String, dynamic>>();
    final writable = MaterialLibrary.instance.writableTears.toSet();
    final tornTop = masks.firstWhere((m) {
      final e = {...(m['torn_edges'] as List).cast<String>()};
      if (e.contains('d')) e.addAll(['t', 'b']);
      return e.contains('t') && writable.contains(m['id']);
    });
    final tearId = tornTop['id'] as String;
    final (img, bytes) = await render(
      tester,
      470,
      200,
      ColoredBox(
        color: const Color(0xFF4C3E32),
        child: Center(
          child: SizedBox(
            width: 452,
            child: PaperPiece(
              stockId: MaterialLibrary.instance.stockVariants('lined').first,
              tearId: tearId,
              child: const SizedBox(height: 120, width: 420),
            ),
          ),
        ),
      ),
    );
    const fromTop = true;
    // On luma against the desk, not on alpha: the baked contact shadow is nearly opaque where it
    // meets the paper, so the first row with alpha above the threshold is the shadow's boundary
    // and not the sheet's. This is the measurement tools/check/deckle.py makes on the stills.
    final ys = <double>[];
    for (var x = 0; x < img.width; x++) {
      for (var k = 0; k < img.height; k++) {
        final y = fromTop ? k : img.height - 1 - k;
        final i = (y * img.width + x) * 4;
        final lum = 0.2126 * bytes[i] + 0.7152 * bytes[i + 1] + 0.0722 * bytes[i + 2];
        if (lum > 150) {
          ys.add(y.toDouble());
          break;
        }
      }
    }
    expect(ys.length, greaterThan(600), reason: 'the sheet did not draw');

    // the same high-pass the check uses: the edge with everything slower than 31 columns removed
    const window = 31;
    var sum = 0.0;
    var n = 0;
    for (var i = window ~/ 2; i < ys.length - window ~/ 2; i++) {
      var mean = 0.0;
      for (var k = -window ~/ 2; k <= window ~/ 2; k++) {
        mean += ys[i + k];
      }
      mean /= window;
      final d = ys[i] - mean;
      sum += d * d;
      n += 1;
    }
    final rms = n == 0 ? 0.0 : math.sqrt(sum / n);
    // One, because that is what this fix is actually worth on this piece and nothing more.
    // Measured on this exact sheet: 0.61 px rms with the old flat four-tenths band and a stretched
    // centre slice, 1.16 with the band measured per mask and the edge bands repeated. The bottom
    // edge of the same sheet goes 4.50 to 4.82 and its middle third against its outer thirds goes
    // from eight times smoother to three and a half. tools/check/deckle.py measures all of that on
    // the stills, and derives its own floor from the masks; this holds the one number a widget
    // test can hold without a capture.
    expect(rms, greaterThan(1.0),
        reason: 'the ${fromTop ? 'top' : 'bottom'} edge of a full-width sheet, torn by $tearId, '
            'measures $rms px rms: it is a straight line with a blur on it, not a tear');
  });

  test('a piece smaller than the render shrinks the tear rather than butting it', () async {
    final mask = await MaskCache.load(tearAsset('tear_001'));
    // The band the app actually slices this mask by, measured at pack time. It used to ask with
    // no band at all, which falls back to a flat four tenths a side — a number nothing has drawn
    // since the band came to be measured per mask, and one that makes a full sheet shrink as soon
    // as the room to stretch in is anything under four sevenths.
    final band = SlicedMasks.bandOf(tearAsset('tear_001'));
    // A Moments tile: 450 x 258 device pixels against a 1024-wide render.
    final small = SlicedMasks.fitFor(mask, const Size(450, 258), band);
    expect(small, lessThan(1.0), reason: 'the borders cannot fit and nothing shrank');
    // Both borders, and the middle left over to stretch, which is what stops the corners butting.
    expect((band[0] + band[2]) * mask.width * small, lessThanOrEqualTo(450 * 0.51));
    expect((band[1] + band[3]) * mask.height * small, lessThanOrEqualTo(258 * 0.51));

    // A full sheet is bigger than the render and keeps its fibres at the size they were rendered.
    expect(SlicedMasks.fitFor(mask, const Size(1440, 2000), band), 1.0);
  });

  test('and an ordinary chat note, which never fitted on its short axis either', () async {
    final mask = await MaskCache.load(tearAsset('tear_001'));
    final band = SlicedMasks.bandOf(tearAsset('tear_001'));
    // 340 logical points across at three device pixels to the point, about 120 tall.
    final k = SlicedMasks.fitFor(mask, const Size(1020, 360), band);
    expect(k, lessThan(1.0));
    expect((band[1] + band[3]) * mask.height * k, lessThanOrEqualTo(360 * 0.51));
  });
}
