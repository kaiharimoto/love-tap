// A contact shadow's spill is a physical width, so a strip and a sheet get the same one.
//
// THE DEFECT THIS IS THE RULER FOR. `_bakedShadow` drew the shadow render `Positioned.fill` with
// `BoxFit.fill` inside a `Transform.scale(shadowFrame)`, which made the spill a tenth of the PIECE
// on each side. A margin strip 111 device pixels tall got 11 px of spill and a note 974 px tall got
// 97, for a shadow that is one millimetre wide either way, so the render's falloff was averaged
// away on the strips and blown up on the notes. Firing 42 measured it over 87 pieces on six
// artifacts, by each piece's own declared rect: at more than 6:1 of aspect distortion the visible
// contact band had a median width of 0 px at a depth of 0.2 L, at 2-6:1 it was 6 px at 5.9 L, and
// at 2:1 or less it was 9.5 px at 6.2 L. The spill was proportional to the paper instead of to the
// lift, which is not what a contact shadow is.
//
// WHAT IS MEASURED HERE, and why it is not measured the way firing 42 measured the BEFORE. Two
// pieces are drawn from the SAME tear mask at two very different aspect distortions, and two things
// are read:
//
//   (a) the SPILL each piece declares to `CaptureHooks.paperSurfaces()` -- how far its contact
//       shadow reaches outside it, in device pixels. This is the clause that says the shadow's
//       size follows the lift and not the sheet: the two must be equal although one piece is six
//       times the other's aspect and six times its height. Under the old code this number was
//       `shadowFrame` times the piece, so the same two pieces would declare about 10.5 px and
//       63.6 px.
//   (b) a floor, so (a) cannot be satisfied by both being zero: the shadow each piece actually
//       composes carries at least 6 device pixels of falloff at a depth of at least 5 L, measured
//       outward from its own outline.
//   (c) the paired population (WORKER_PROMPT 3d, corollary 2): both pieces are still on the screen
//       and still declaring all three of their layers, so neither clause can be met by a piece
//       leaving it.
//
// FIRING 42 READ THE BAND ABOVE EACH PIECE'S DECLARED RECT, AND THAT WINDOW CANNOT BE REUSED HERE.
// Firing 45 tried it first and measured why: a packed mask's alpha does not reach the top of its
// own box. Over the 28 masks whose top edge is a straight cut rather than a tear, the fraction of
// the top row above half alpha is 0.0 on every one of them, and the row means climb 0, 0, 0, 1, 1,
// 2 -- so the paper's outline sits somewhere inside the box on every mask in the library, a median
// of 8.73 mm in on a torn side. A window placed above the box therefore reads the wander of the
// tear rather than the width of the shadow, and it reads zero for any piece whose edge happens not
// to come near the top. That is WORKER_PROMPT 3d's first failure exactly -- a ruler measuring the
// thing standing next to the defect -- so it is written down here rather than used.
//
// So (b) is read off the composed shadow itself, where there is no paper texture and no tear
// wander to confuse it: the alpha of `ContactShadowPainter`'s own composition, which is the core
// under the paper and then the falloff outward, so the outline is where the alpha crosses half and
// the spill is what lies beyond it.
//
// TO RE-BREAK IT: put `Positioned.fill` with `BoxFit.fill` back on the shadow -- the diff is in
// `PaperPiece._contactShadow` -- and the piece declares no contact surface at all, so (c) fails
// first and (a) never gets to be asked.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:desk/capture/hooks.dart';
import 'package:desk/material/library.dart';
import 'package:desk/material/light.dart';
import 'package:desk/material/paper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const double _dpr = 3.0;

/// A piece's declared rect and how far its tear mask is stretched away from its own aspect.
class _Declared {
  _Declared(this.rect, this.distortion, this.spill);
  final List<int> rect;
  final double distortion;
  final double spill;
}

_Declared _declaredFor(String piece) {
  final mine = CaptureHooks.paperSurfaces().where((s) => s['piece'] == piece).toList();
  final mask = mine.firstWhere((s) => s['fit'] == 'mask',
      orElse: () => throw StateError('$piece declared no mask: $mine'));
  final shadow = mine.firstWhere((s) => s['fit'] == 'contact',
      orElse: () => throw StateError('$piece declared no contact shadow: $mine'));
  final src = (mask['src'] as List).cast<num>();
  final drawn = (mask['drawn'] as List).cast<num>();
  // (drawn_w/src_w) / (drawn_h/src_h), the number firing 41 and firing 42 grouped by
  final ratio = (drawn[0] / src[0]) / (drawn[1] / src[1]);
  return _Declared((shadow['rect'] as List).cast<int>(), ratio < 1 ? 1 / ratio : ratio,
      (shadow['spill'] as num).toDouble());
}

/// The falloff a piece's own composed contact shadow carries, measured outward from its outline.
///
/// The composition is the shadow and nothing else: the core is what lies under the paper and
/// everything beyond it is spill, so the outline is where the alpha crosses half and no paper
/// texture or torn edge can be mistaken for either. Returned in device pixels and in L, the units
/// firing 42 reported the BEFORE in.
Future<({int band, double depth})> _falloffOf(
    WidgetTester tester, String tearId, Size box, double dpr) async {
  final mask = MaskCache.peek(tearAsset(tearId));
  expect(mask, isNotNull, reason: 'the mask for $tearId never decoded, so there is no outline');
  final p = ContactShadowPainter(
    tearId: tearId,
    mask: mask!,
    condition: LightCondition.day,
    opacity: 1.0,
    dpr: dpr,
  );
  final spill = ContactShadowPainter.spill;
  final w = ((box.width + 2 * spill) * dpr).round();
  final h = ((box.height + 2 * spill) * dpr).round();

  Future<ByteData> shotOf(void Function(Canvas) draw) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(dpr);
    draw(canvas);
    late final ui.Image img;
    await tester.runAsync(() async => img = recorder.endRecording().toImageSync(w, h));
    return (await tester.runAsync(
        () => img.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
  }

  final shadow = await shotOf((canvas) {
    canvas.translate(spill, spill);
    p.paint(canvas, box);
  });
  // THE SAME OUTLINE, AT THE SAME PLACE, WITH NOTHING LAID AROUND IT. A mask's alpha does not step
  // from nothing to paper: it ramps, and the ramp is stretched or squashed with the piece, so a
  // strip six times shorter than a sheet carries a sixth of the mask's own soft margin. Measured
  // against the alpha crossing alone, that margin reads as falloff and the two pieces came out 14
  // px and 19 px for a shadow that is the same width on both. Subtracting the bare outline's own
  // margin, column by column, leaves what the composer actually laid down -- and the residue is
  // the mask's, which is `the-tears-are-overlays-painted-on-whole-paper`'s business and not this
  // item's.
  final bare = await shotOf((canvas) {
    final outline = SlicedMasks.at(tearAsset(tearId), mask, box, dpr);
    canvas.drawImageRect(
      outline,
      Rect.fromLTWH(0, 0, outline.width.toDouble(), outline.height.toDouble()),
      Rect.fromLTWH(spill, spill, box.width, box.height),
      Paint()..filterQuality = FilterQuality.medium,
    );
  });

  int alphaAt(ByteData px, int x, int y) => px.getUint8((y * w + x) * 4 + 3);

  /// How many rows above the alpha crossing carry ink, at one column, and how dark they get.
  (int, double) marginAt(ByteData px, int col) {
    var outline = -1;
    for (var y = 0; y < h; y++) {
      if (alphaAt(px, col, y) >= 128) {
        outline = y;
        break;
      }
    }
    if (outline <= 0) return (-1, 0.0);
    var band = 0;
    var depth = 0.0;
    for (var y = outline - 1; y >= 0; y--) {
      final a = alphaAt(px, col, y).toDouble();
      if (a < 2.0) break;
      band++;
      depth = math.max(depth, a);
    }
    return (band, depth);
  }

  // WORKER_PROMPT 3d, corollary 1: one column is a sampling accident. The window is tiled across
  // the piece at a fixed stride and the median is reported, with the number of columns that
  // carried an outline at all beside it -- a single placement down the middle read 14 px on one
  // of these two pieces and 18 px on the other, and the difference was where the column fell
  // rather than anything about the shadow.
  final bands = <int>[];
  final depths = <double>[];
  for (var col = 2; col < w - 2; col += math.max(1, w ~/ 32)) {
    final lit = marginAt(shadow, col);
    final plain = marginAt(bare, col);
    if (lit.$1 < 0 || plain.$1 < 0) continue;
    bands.add(math.max(0, lit.$1 - plain.$1));
    depths.add(lit.$2);
  }
  expect(bands, isNotEmpty,
      reason: 'the composed shadow for $tearId has no core anywhere, so nothing was laid down');
  bands.sort();
  depths.sort();
  return (band: bands[bands.length ~/ 2], depth: depths[depths.length ~/ 2]);
}

Widget _twoPieces({required double stripChild, required double sheetChild}) => MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFFF2F0EC),
        // the desk colour lives INSIDE the boundary: a `Scaffold`'s own background paints behind
        // its body, so a boundary wrapping only the body rasterises to a transparent frame and
        // every darkness reading off it is taken against nothing
        body: RepaintBoundary(
          key: const ValueKey('frame'),
          child: Container(
            color: const Color(0xFFF2F0EC),
            child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // the distorted one: the same mask pulled wide and flat, which is the chat
                // margin's shape and the one firing 42 found carrying no contact shadow at all
                SizedBox(
                  width: 300,
                  child: PaperPiece(
                    id: 'the_strip',
                    stockId: 'lined_01',
                    tearId: 'tear_001',
                    child: SizedBox(height: stripChild),
                  ),
                ),
                const SizedBox(height: 90),
                // and the undistorted one, drawn near the aspect the mask was rendered at
                SizedBox(
                  width: 300,
                  child: PaperPiece(
                    id: 'the_sheet',
                    stockId: 'lined_01',
                    tearId: 'tear_001',
                    child: SizedBox(height: sheetChild),
                  ),
                ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await MaterialLibrary.load();
  });

  testWidgets('the contact band above a strip is the band above a sheet', (tester) async {
    tester.view.devicePixelRatio = _dpr;
    tester.view.physicalSize = const Size(1200, 2400);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_twoPieces(stripChild: 8, sheetChild: 130));
    // the masks and the stocks decode off the real bundle; inside the fake-async zone their
    // futures never complete and a piece whose mask never arrived has no outline to be lit round
    for (var i = 0; i < 24; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    }
    expect(tester.takeException(), isNull);

    final strip = _declaredFor('the_strip');
    final sheet = _declaredFor('the_sheet');

    // (c) the denominator, asserted before anything is read off the pixels: both pieces are on the
    // screen, both declare a contact shadow, and they are the two groups this is about.
    expect(strip.distortion, greaterThan(6.0),
        reason: 'the distorted piece is meant to be in firing 42\'s >6:1 group, and it declares '
            '${strip.distortion.toStringAsFixed(2)}:1');
    expect(sheet.distortion, lessThan(2.0),
        reason: 'the undistorted piece is meant to be in the <=2:1 group, and it declares '
            '${sheet.distortion.toStringAsFixed(2)}:1');
    expect(strip.spill, closeTo(sheet.spill, 0.001),
        reason: 'the declared spill is a physical width, so it does not know how big the piece is. '
            'Under the old code it was shadowFrame times the piece, which for these two would be '
            'about ${(strip.rect[3] * 0.125).toStringAsFixed(1)} px against '
            '${(sheet.rect[3] * 0.125).toStringAsFixed(1)} px');

    // (b) a floor, so (a) cannot be satisfied by both shadows being nothing. Read off each
    // piece's OWN composition, at the box it was declared at.
    final stripBox = Size(strip.rect[2] / _dpr, strip.rect[3] / _dpr);
    final sheetBox = Size(sheet.rect[2] / _dpr, sheet.rect[3] / _dpr);
    final a = await _falloffOf(tester, 'tear_001', stripBox, _dpr);
    final b = await _falloffOf(tester, 'tear_001', sheetBox, _dpr);
    final say = 'strip ${strip.distortion.toStringAsFixed(2)}:1 '
        '${strip.rect[2]}x${strip.rect[3]} spill ${strip.spill} falloff ${a.band} px '
        'at ${a.depth.toStringAsFixed(1)} L; '
        'sheet ${sheet.distortion.toStringAsFixed(2)}:1 '
        '${sheet.rect[2]}x${sheet.rect[3]} spill ${sheet.spill} falloff ${b.band} px '
        'at ${b.depth.toStringAsFixed(1)} L';
    printOnFailure(say);
    // ignore: avoid_print
    print(say);

    expect(a.band, greaterThanOrEqualTo(6),
        reason: 'the distorted piece composes no falloff: $say');
    expect(b.band, greaterThanOrEqualTo(6),
        reason: 'the undistorted piece composes no falloff: $say');
    expect(a.depth, greaterThanOrEqualTo(5.0), reason: say);
    expect(b.depth, greaterThanOrEqualTo(5.0), reason: say);

    // (a) the clause the item is about: the spill stops being a function of the paper. The
    // declared widths are equal exactly, and the composed falloffs are within a fifth of each
    // other although one piece is six times the other's height.
    expect(a.band, greaterThanOrEqualTo((b.band * 0.8).floor()),
        reason: 'the falloff still follows the shape of the sheet rather than the lift: $say');
    expect(b.band, greaterThanOrEqualTo((a.band * 0.8).floor()), reason: say);
  });
}
