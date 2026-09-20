// A voice note and a dial are pen strokes, not bars.
//
// `a-barcode-of-vertical-bars-is-painted-across-the-paper-on-four-artifacts` was filed on two
// widgets that drew with `Canvas.drawRect`: the waveform in `regions/chat/blob_widgets.dart`, in
// `Theme.of(context).colorScheme.onSurface` — the last Material scheme colour in an app that has
// none anywhere else — and `_Dial` in `material/desk.dart`, four flat `Container`s under a
// docstring that said "drawn as tally strokes rather than as a progress bar". The dial is on the
// partner strip at the top of every screen, which is why one defect was measured on six artifacts:
// 58 mean-crossings and a 70.8 L range across 47% of the width of `02_chat`, 68 crossings on
// `13_messenger_states`, 21 on the dusk object shelf.
//
// The item names two clauses. Every bar begins and ends at exactly the same y, and every bar
// interior is perfectly constant — `(195,195,195,...)` against a 240 ground. Both are read here
// off the pixels of the widget rather than off a capture, because a capture is OBSERVE's and this
// has to gate a commit.
//
// **The re-break is kept standing rather than done once and described.** `_BarPainter` below is
// the old code, verbatim in behaviour, and the last two tests assert that it FAILS both clauses.
// If a future change makes [Tally] draw bars again, those two go green and say so.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:desk/material/marks.dart';
import 'package:desk/material/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _behind = Color(0xFF00FF00); // no ink and no paper is this, so anything else is a mark

/// What `_WavePainter` and `_Dial` did: hard-edged rectangles, all on one y, one flat colour.
class _BarPainter extends CustomPainter {
  _BarPainter(this.heights, this.colour);
  final List<double> heights;
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final n = heights.length;
    final w = size.width / n;
    final paint = Paint()..color = colour;
    for (var i = 0; i < n; i++) {
      final h = heights[i].clamp(0.05, 1.0) * size.height;
      canvas.drawRect(
          Rect.fromLTWH(i * w + w * 0.2, (size.height - h) / 2, w * 0.6, h), paint);
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) => false;
}

/// One reading of a painted mark: where its ink starts down each column, and how many distinct
/// colours the ink has in it.
class _Reading {
  _Reading(this.tops, this.inkColours, this.inkedColumns);

  /// The first inked row in each inked column.
  final List<int> tops;

  /// Every distinct ARGB the ink took, background excluded.
  final Set<int> inkColours;

  final int inkedColumns;

  /// How many different rows the marks start on. A row of bars sharing a y reads 1 or 2.
  int get distinctTops => tops.toSet().length;
}

Future<_Reading> _read(WidgetTester tester, Widget mark) async {
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: RepaintBoundary(
        key: const ValueKey('shot'),
        child: SizedBox(
          width: 160,
          height: 28,
          child: Stack(children: [
            const Positioned.fill(child: ColoredBox(color: _behind)),
            Positioned.fill(child: mark),
          ]),
        ),
      ),
    ),
  ));
  await tester.pump();

  final boundary =
      tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
  // synchronous on purpose: toImage's future does not complete under flutter_tester's software
  // rendering — see a_tear_is_actually_cut_test.dart, which learned it the slow way
  final shot = boundary.toImageSync();
  late ByteData? data;
  await tester.runAsync(() async {
    data = await shot.toByteData(format: ui.ImageByteFormat.rawRgba);
  });
  final px = data!.buffer.asUint8List();
  final w = shot.width, h = shot.height;

  int argb(int x, int y) {
    final i = (y * w + x) * 4;
    return (px[i + 3] << 24) | (px[i] << 16) | (px[i + 1] << 8) | px[i + 2];
  }

  // the background is flat green; anything whose green dominates that strongly is not a mark
  bool isInk(int x, int y) {
    final i = (y * w + x) * 4;
    return !(px[i + 1] > 178 && px[i] < 90 && px[i + 2] < 90);
  }

  final tops = <int>[];
  final colours = <int>{};
  var inked = 0;
  for (var x = 0; x < w; x++) {
    var top = -1;
    for (var y = 0; y < h; y++) {
      if (!isInk(x, y)) continue;
      if (top < 0) top = y;
      colours.add(argb(x, y));
    }
    if (top >= 0) {
      tops.add(top);
      inked++;
    }
  }
  return _Reading(tops, colours, inked);
}

// a waveform of the shape a real one is: uneven, and never two neighbours the same
const _wave = [0.42, 0.88, 0.31, 0.67, 0.95, 0.24, 0.55, 0.78, 0.36, 0.61, 0.83, 0.29];

void main() {
  testWidgets('the strokes of a voice do not all begin on one row', (tester) async {
    final r = await _read(
        tester,
        const Tally(heights: _wave, struck: 5));
    // A pen inks far fewer columns than a bar does, and that is part of the point: the item
    // measured the barcode at 670 px, 47% of the frame's width. Twelve strokes at pen weight ink
    // 21 of these 160 columns, about 13%. So this is a sanity floor — did anything paint at all —
    // and not a coverage floor.
    expect(r.inkedColumns, greaterThanOrEqualTo(_wave.length),
        reason: 'only ${r.inkedColumns} columns were inked for ${_wave.length} strokes, so the '
            'rest of this test proves nothing');
    // twelve strokes of twelve different heights, each wobbling: a great many distinct tops
    expect(r.distinctTops, greaterThan(12),
        reason: 'the marks start on ${r.distinctTops} distinct rows across ${r.inkedColumns} '
            'inked columns, which is a row of bars sharing a y, not a row of strokes');
  });

  testWidgets('no stroke has an interior of one constant value', (tester) async {
    final r = await _read(tester, const Tally(heights: _wave, struck: 5));
    // a hand swells and thins along a stroke, so the ink is many values; drawRect gives one
    // per paint, which for played-and-rest was exactly two
    expect(r.inkColours.length, greaterThan(20),
        reason: 'the ink took only ${r.inkColours.length} distinct values, which is a flat fill '
            'and not a pen');
  });

  testWidgets('a dial is the same marks at dial size', (tester) async {
    final r = await _read(
        tester,
        const Tally(
          heights: [1.0, 1.0, 0.45, 0.45],
          struck: 2,
          colour: Pen.margin,
          lightColour: Pen.margin,
          weight: 1.4,
          seed: 31,
        ));
    expect(r.inkedColumns, greaterThan(6),
        reason: 'the dial painted almost nothing');
    expect(r.distinctTops, greaterThan(2),
        reason: 'four strokes at two heights should still not share two exact rows: '
            '${r.distinctTops} distinct tops');
    expect(r.inkColours.length, greaterThan(6),
        reason: 'the dial ink took only ${r.inkColours.length} values');
  });

  // ---- the re-break, kept standing ------------------------------------------------------------

  testWidgets('RE-BREAK: the old bars share one row, and that is what was wrong', (tester) async {
    final r = await _read(tester, CustomPaint(painter: _BarPainter(_wave, Pen.graphite)));
    expect(r.inkedColumns, greaterThan(40));
    // every rect is centred on the box, so tops take one value per distinct height and no more
    expect(r.distinctTops, lessThanOrEqualTo(_wave.toSet().length),
        reason: 'the bars produced ${r.distinctTops} distinct tops, which is more than one per '
            'height — _BarPainter is no longer the old code and this re-break is not re-breaking '
            'anything');
  });

  testWidgets('RE-BREAK: the old bar interiors are one exact value', (tester) async {
    final r = await _read(tester, CustomPaint(painter: _BarPainter(_wave, Pen.graphite)));
    // one fill colour, plus whatever the edges antialias to
    expect(r.inkColours.length, lessThan(20),
        reason: 'the bars took ${r.inkColours.length} distinct values, so they are no longer flat '
            'and this re-break is not re-breaking anything');
  });
}
