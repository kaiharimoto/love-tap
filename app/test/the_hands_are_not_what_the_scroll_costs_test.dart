// WHAT THIS TEST CANNOT SEE, written at the top because it matters more than what it can.
//
// `flutter test` runs the engine with `--use-test-fonts --disable-asset-fonts`. Every paragraph
// laid out in here is laid out in Ahem, which has no contextual alternates and no ligatures, so
// the 0.074 ms below is the cost of shaping a note *in a font with nothing to shape*. It was read
// as ruling the hand fonts out of the scroll's cost and it does not rule anything out.
//
// What the twelfth capture measured, in the browser, against the real faces: a fling frame that
// builds nothing costs 4 ms and a fling frame that builds two and a half rows costs 688 — about
// 276 ms a row. The row count itself fell from 5,028 over three hundred frames to 167 when
// Note.build stopped subscribing to the scope, so the rows are no longer being rebuilt for
// nothing; what one costs to build the first time is a separate question and this file has never
// been able to answer it. `Flags.plainFonts` and a second capture of the same fling can.
//
// The claim this file was written to make, which stands only for a font with nothing to shape:
//
// The scroll's build spikes were attributed to the tear mask being baked per note; a counter
// disproved it (twelve masks across a fling through 8,075 rows). The next hypothesis, named so it
// could be killed as cleanly, was that the hand fonts carry contextual alternates and every new
// note shapes a paragraph through them on the build thread. This is that test, and it kills it:
// a note's worth of handwriting shapes in a twentieth of a millisecond, and turning the features
// off saves about half of that. A row was costing sixty milliseconds in the browser. The fonts
// are three orders of magnitude away from being the answer.
//
// It stays as a test rather than a note in a report because it is also a regression guard: if
// shaping a line of a hand ever costs a millisecond, the thread will feel it.
import 'dart:ui' as ui;

import 'package:desk/material/hands.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _msPerParagraph(TextStyle style, List<String> lines) {
  final sw = Stopwatch()..start();
  for (final s in lines) {
    final b = ui.ParagraphBuilder(ui.ParagraphStyle(
      fontFamily: style.fontFamily,
      fontSize: style.fontSize,
    ))
      ..pushStyle(ui.TextStyle(
        fontFamily: style.fontFamily,
        fontSize: style.fontSize,
        fontFeatures: style.fontFeatures,
      ))
      ..addText(s);
    final p = b.build()..layout(const ui.ParagraphConstraints(width: 280));
    p.dispose();
  }
  sw.stop();
  return sw.elapsedMicroseconds / 1000.0 / lines.length;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a note of handwriting shapes in well under a millisecond, features and all', () {
    final lines = List.generate(200, (i) =>
        'it is raining here too and i keep thinking about the thing you said on tuesday $i');
    final hand = Hands.noor(size: 18);
    final withFeatures = _msPerParagraph(hand, lines);
    final without = _msPerParagraph(hand.copyWith(fontFeatures: const <ui.FontFeature>[]), lines);
    // ignore: avoid_print
    print('one note of handwriting: ${withFeatures.toStringAsFixed(3)} ms with calt and liga, '
        '${without.toStringAsFixed(3)} ms with them off');
    expect(withFeatures, lessThan(1.0),
        reason: 'shaping a note of handwriting costs $withFeatures ms, which the thread will feel');
    expect(withFeatures - without, lessThan(1.0),
        reason: 'the contextual alternates cost ${withFeatures - without} ms a note');
  });
}
