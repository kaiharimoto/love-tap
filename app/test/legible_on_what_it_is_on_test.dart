// Every ink is legible on the surface it is written on.
//
// This regressed silently and it regressed because something else got better. Pencil grey is
// #6D6D70 and the desk is dark waxed oak: one and a half to one, which is not a contrast ratio,
// it is a rumour. It was survivable while the desk was a flat fill — the eye forgave it — and it
// stopped being survivable the moment the desk had grain in it, because now there is figure
// running through the letters. The margin line beside the thread, the composer, the word `search`:
// all of it went from hard to read to not worth trying.
//
// So the pairs are written down and the arithmetic is done, rather than looked at.
import 'dart:math' as math;

import 'package:desk/material/hands.dart';
import 'package:desk/material/desk.dart';
import 'package:desk/material/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG relative luminance, and the ratio between two of them.
double _lum(Color c) {
  double channel(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4) as double;
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double contrast(Color a, Color b) {
  final la = _lum(a), lb = _lum(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// The two grounds anything in this app is ever written on.
const _desk = DeskColour.day;
const _paper = Color(0xFFF1ECDF);   // the palest stock, the hardest ground for a pale ink

void main() {
  test('nothing written on the desk is written in an ink for paper', () {
    // 3:1 is the large-text floor, and everything written straight on the desk is either a
    // margin line, a heading or a control — none of it is body text, and all of it has to be
    // readable across the grain.
    final onDesk = <String, Color>{
      'the hand for the desk': Hands.onDesk().color!,
      'a stamped label on the desk': Pen.onWood,
    };
    for (final e in onDesk.entries) {
      final r = contrast(e.value, _desk);
      expect(r, greaterThanOrEqualTo(3.0),
          reason: '${e.key} is ${r.toStringAsFixed(2)}:1 on the desk');
    }
  });

  test('the pencil the margin is written in is for paper, and stays off the desk', () {
    // It is a good ink on paper and a bad one on wood. This holds both halves of that, so the
    // day nobody remembers why Hands.onDesk exists, the test says.
    final onPaper = contrast(Pen.margin, _paper);
    final onWood = contrast(Pen.margin, _desk);
    expect(onPaper, greaterThanOrEqualTo(4.5),
        reason: 'the margin pencil is ${onPaper.toStringAsFixed(2)}:1 on paper');
    expect(onWood, lessThan(3.0),
        reason: 'the margin pencil now reads on wood too, so Hands.onDesk may be unnecessary — '
            'check the desk has not been lightened into something else');
  });

  test('both hands are legible on the paper they are written on', () {
    for (final e in {'noor': Pen.ballpoint, 'teo': Pen.graphite, 'a red pen': Pen.red}.entries) {
      final r = contrast(e.value, _paper);
      expect(r, greaterThanOrEqualTo(4.5),
          reason: '${e.key} is ${r.toStringAsFixed(2)}:1 on the palest stock');
    }
  });
}
