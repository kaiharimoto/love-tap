// What the two hands actually put on the glass when a letter comes round again.
//
// `one-variant-per-glyph-and-zero-pressure-variance` says the variants are "not thin, absent and
// measured": five 'e' glyphs on one line of `crops/02_chat_300_hand.png` at ink areas 457, 448,
// 459, 450, 457, a best-aligned mean absolute difference of 3.07/255 between the 'e' of "The" and
// the 'e' of "open" against a control of 42.41, and every ink pixel one flat colour. Its gate,
// `evidence/logs/fonts.json`, reads 775 glyphs and 360 variants per hand with no findings,
// "because it checks the font FILE and not the render". The item's account of the CAUSE is "the
// hands carry the variants; nothing asks for them."
//
// FIRING 42 MEASURED THE CAUSE AND IT IS NOT THAT. Something does ask, and the ask is honoured:
//
//   * `_handFeatures` in material/hands.dart has carried `FontFeature.enable('calt')` all along,
//     and it is a no-op either way -- HarfBuzz turns `calt` on by itself for horizontal text, and
//     deleting the enable changes not one of the numbers below.
//   * The shipped `app/assets/fonts/NoorHand.ttf` carries GSUB with `calt`, `rand` and `ss01-05`,
//     reachable from both DFLT and latn, and `calt` points at a type-6 chain-context lookup with
//     eight subtables -- the cycle tools/handwriting/build.py writes.
//   * Shaped through HarfBuzz, "eeeeeeee" comes out as glyph ids 690, 225, 380, 535, 690, 380,
//     535, 690: FOUR DISTINCT OUTLINES, not one. The substitution happens.
//
// So the variants are not absent. They are APPLIED AND TOO SIMILAR TO SEE, and that is a
// different item with a different site. Measured here on the Dart VM at the sizes
// `02_chat.text.json` says the app draws -- 51, 39 and 34.5 device pixels, which is what its `px`
// means -- over eight 'e's in a row:
//
//   NoorHand @51px   pairwise MAD  min 2.44  median  9.82  max 12.76
//   TeoHand  @51px   pairwise MAD  min 0.00  median  6.81  max 10.24
//   NoorHand @39px   pairwise MAD  min 0.00  median 10.61  max 11.43
//
// against a control that is the floor of the method: THE SAME glyph, the same variant, drawn half
// a pixel further along, reads 4.99. Two different outlines are therefore about five luminance
// levels apart once the rasteriser's own phase is taken off, where the item asks for fifteen. And
// the cycle has a period -- 690 comes back at the fifth and eighth letter -- so a long enough
// line brings the identical outline back and reads 0.00, which is where the critic's 3.07 came
// from. The work is in the variants' SHAPES, in tools/handwriting/build.py's alt planning and
// jitter, not in asking for them.
//
// AND THE SECOND HALF OF THE ITEM CANNOT BE MET ON THIS PATH AT ALL. "An ink-luminance
// interquartile range >= 8 within a single glyph" is asking a filled TrueType outline to vary in
// TONE. Measured here, the interior ink -- every pixel all four of whose neighbours are also ink,
// so the antialiased rim is excluded -- has an IQR of 0 at every size in both hands, and it
// always will: a glyph is one fill colour by construction. Pressure in a font is carried by the
// WIDTH of the stroke. The item needs re-expressing against the outline, or against a drawn hand
// like the one `material/marks.dart` already uses for tallies.
//
// What this file asserts is only what it can hold. It does NOT assert a floor on the pairwise
// difference: that number was tried as a guard and it does not discriminate -- disabling `calt`
// outright leaves the medians at 6.46-10.82, because what it is mostly measuring is subpixel
// phase. It prints the numbers, asserts the glyph boxes it measured them over, and holds the one
// clause that is stable and load-bearing: the interior of a glyph is one tone.
import 'dart:ui' as ui;

import 'package:desk/material/hands.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _load(String family, String path) async {
  final loader = FontLoader(family);
  loader.addFont(rootBundle.load(path));
  await loader.load();
}

/// The pairwise best-aligned differences between the inked groups of [text], and the interquartile
/// range of the interior ink of the first one.
Future<({List<double> mads, int coreIqr, int groups})> _render(TextStyle style, String text) async {
  final tp = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)
    ..layout();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(Rect.fromLTWH(0, 0, tp.width + 20, tp.height + 20),
      Paint()..color = const Color(0xFFFFFFFF));
  tp.paint(canvas, const Offset(10, 10));
  final image = await recorder.endRecording().toImage((tp.width + 20).ceil(), (tp.height + 20).ceil());
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final px = data!.buffer.asUint8List();
  final w = image.width, h = image.height;
  int lum(int x, int y) => px[(y * w + x) * 4];
  bool ink(int x, int y) => x >= 0 && x < w && y >= 0 && y < h && lum(x, y) < 200;

  // the glyphs, as columns of ink separated by columns of none
  final boxes = <List<int>>[];
  int? start;
  for (var x = 0; x <= w; x++) {
    var any = false;
    for (var y = 0; y < h && x < w; y++) {
      if (ink(x, y)) { any = true; break; }
    }
    if (any && start == null) start = x;
    if (!any && start != null) { boxes.add([start, x - 1]); start = null; }
  }

  final mads = <double>[];
  for (var i = 0; i + 1 < boxes.length; i++) {
    for (var j = i + 1; j < boxes.length; j++) {
      final a = boxes[i], b = boxes[j];
      if (a[1] - a[0] < 3 || b[1] - b[0] < 3) continue;
      var best = double.infinity;
      for (var dx = -3; dx <= 3; dx++) {
        for (var dy = -3; dy <= 3; dy++) {
          var sum = 0.0;
          var n = 0;
          for (var y = 0; y < h; y++) {
            for (var x = 0; x <= a[1] - a[0]; x++) {
              final bx = b[0] + x + dx, by = y + dy;
              if (bx < 0 || bx >= w || by < 0 || by >= h) continue;
              sum += (lum(a[0] + x, y) - lum(bx, by)).abs();
              n++;
            }
          }
          if (n > 0 && sum / n < best) best = sum / n;
        }
      }
      if (best.isFinite) mads.add(best);
    }
  }
  final core = <int>[];
  if (boxes.isNotEmpty) {
    for (var y = 0; y < h; y++) {
      for (var x = boxes.first[0]; x <= boxes.first[1]; x++) {
        if (ink(x, y) && ink(x - 1, y) && ink(x + 1, y) && ink(x, y - 1) && ink(x, y + 1)) {
          core.add(lum(x, y));
        }
      }
    }
  }
  core.sort();
  mads.sort();
  final iqr = core.isEmpty ? -1 : core[3 * core.length ~/ 4] - core[core.length ~/ 4];
  return (mads: mads, coreIqr: iqr, groups: boxes.length);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _load('NoorHand', 'assets/fonts/NoorHand.ttf');
    await _load('TeoHand', 'assets/fonts/TeoHand.ttf');
  });

  // **`eeeeeeee` IS A CONTROL STRING FOR THE RASTERISER AND IS NOT A MEASUREMENT OF THIS APP**,
  // and firing 48 put that sentence here because the number it produces has been quoted as one
  // for two cycles. Eight instances against five variants: by pigeonhole two of them MUST share an
  // outline, so `min` is 0.00 before a single line of the generator is touched, and a firing that
  // tunes the hands until this string comes clean is tuning against a requirement the brief does
  // not make. The item's clause is anchored to the runs `02_chat.text.json` declares, where the
  // longest same-letter repeat is FIVE against five variants -- exactly reachable.
  //
  // What that clause needs is glyph IDS, which is shaping rather than rasterising, and it is in
  // `tools/check/hands.py`: 19 of the 53 repeated letters inside a declared run take an outline
  // twice, and one pair -- the two `o`s of `room` in the Chat hero -- is the identical outline
  // printed twice IN A ROW. The ruler is earned against `--no-calt`, which reads 27 of 53 and
  // eight such pairs, so it discriminates the defect from the repair in the right order.
  //
  // What stays here is what only a rasteriser can answer: how far apart two DIFFERENT outlines
  // actually look, against the floor of the method.
  test('a letter that comes round again is not the same outline stamped twice', () async {
    for (final size in <double>[51, 39, 34.5]) {
      for (final entry in {
        'NoorHand': Hands.noor(size: size, colour: const Color(0xFF000000)),
        'TeoHand': Hands.teo(size: size, colour: const Color(0xFF000000)),
      }.entries) {
        final r = await _render(entry.value, 'eeeeeeee');
        expect(r.groups, greaterThanOrEqualTo(8),
            reason: '${entry.key} at ${size}px drew ${r.groups} separated glyphs for eight '
                'letters, so the measurement below is about the wrong boxes');
        final median = r.mads[r.mads.length ~/ 2];
        // ignore: avoid_print
        print('${entry.key} @${size}px eight e (a RASTERISER control, not the app): MAD min '
            '${r.mads.first.toStringAsFixed(2)} median ${median.toStringAsFixed(2)} max '
            '${r.mads.last.toStringAsFixed(2)}; interior ink IQR ${r.coreIqr}. The min is 0.00 by '
            'pigeonhole and says nothing; the MEDIAN is how far two different outlines are, '
            'against the item\'s floor of 15 and this method\'s own floor of 4.99.');
        // and no floor asserted, on purpose: see the head of this file. It is printed so a
        // successor tuning HAUSDORFF_MIN can watch the median move, and it is not a gate.
      }
    }
  });

  test('and the tone inside a glyph is one value, which is what a filled outline is', () async {
    // Not a defect to fix in the app, and written down so the item that asks for an ink-luminance
    // interquartile range of 8 is not attempted against this path. A TrueType glyph is a filled
    // contour: the interior is one colour, and pressure lives in the width of the stroke.
    final r = await _render(Hands.noor(size: 51, colour: const Color(0xFF000000)), 'eeeeeeee');
    expect(r.coreIqr, 0,
        reason: 'the interior ink of a filled outline now varies in tone, which would mean the '
            'hands are no longer being drawn as a plain fill — re-read '
            'one-variant-per-glyph-and-zero-pressure-variance, whose second clause assumes they '
            'are');
  });
}
