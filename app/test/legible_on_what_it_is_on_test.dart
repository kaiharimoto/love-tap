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
//
// Two things were wrong with the first version of this file, and both of them let a real failure
// through while the test stayed green.
//
// The first was the threshold. It asked the on-desk pairs for three to one, which is WCAG's
// large-text floor — and large text means 24px regular. `Hands.onDesk` is set at 13 and
// `Hands.stamp` at 12. At that size the floor is four and a half, and asking for three was
// granting an exemption nothing had earned.
//
// The second was the coverage. It checked three inks against one ground, `Paper.lined`, which is
// the palest stock in the library and therefore the easiest. `Pen.margin` was darkened
// specifically to clear 4.5 against it and clears nothing else: it is 4.05 on aged, 4.03 on the
// underside of a turned corner, 4.01 on a yellow sticky note and 3.33 on a pink one. The comment
// on the constant says "against the palest stock" and means it. Nine stocks, six inks and two
// light conditions is fifty-six pairs, and a test that reads three of them is a sample, not a
// guard.
//
// What it still cannot see, and what `tools/check/legibility.py` exists for: these are declared
// colours against declared colours, and every ground in this app is a render. The composer's
// placeholder is `Pen.onWood` at 4.94:1 against `DeskColour.day` — and 1.56:1 against the actual
// waxed oak in `02_chat.png`, because the plank has grain in it and the grain runs through the
// letters. This file is the cheap pass that runs in a second. It is not the measurement.
import 'dart:math' as math;

import 'package:desk/material/desk.dart';
import 'package:desk/material/hands.dart';
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

/// Nothing in this app is set at 24px, so nothing in this app gets the large-text floor.
const _body = 4.5;

const _desk = DeskColour.day;
const _paper = Color(0xFFF1ECDF); // the palest stock, the hardest ground for a pale ink

const _inks = <String, Color>{
  'ballpoint': Pen.ballpoint,
  'graphite': Pen.graphite,
  'biro': Pen.biro,
  'red': Pen.red,
  'stamp': Pen.stamp,
  'margin': Pen.margin,
};

const _stocks = <String, Color>{
  'lined': Paper.lined,
  'aged': Paper.aged,
  'graph': Paper.graph,
  'legal': Paper.legal,
  'index': Paper.index,
  'looseleaf': Paper.looseleaf,
  'spiral': Paper.spiral,
  'stickyYellow': Paper.stickyYellow,
  'stickyPink': Paper.stickyPink,
  'underside': Paper.underside,
};

/// The pairs that are below the floor today, with what they measure.
///
/// This is a ratchet and not an exemption list. The suite has to stay green so the rest of the
/// build can keep moving, and the failures have to stay visible so they get fixed, and those two
/// are only compatible if the list can shrink and cannot grow. So: a pair that is not on this list
/// and is below the floor fails. A pair on this list that has got worse fails. A pair on this list
/// that has been fixed also fails, because the entry is now a lie and the next person to read it
/// would believe it.
///
/// Every one of these is `Pen.margin` except the last. Pencil is the ink that does not have the
/// headroom, and every stock that is not the palest is where it runs out.
const _knownBelowFloor = <String, double>{
  'margin on stickyPink': 3.33,
  'margin on stickyYellow': 4.01,
  'margin on underside': 4.03,
  'margin on aged': 4.05,
  'red on stickyPink': 4.17,
  'margin on legal': 4.22,
  'margin on spiral': 4.42,
  'margin on graph': 4.47,
};

void main() {
  test('nothing written on the desk is written in an ink for paper', () {
    // Set at 12 and 13, so the floor is the body floor. The earlier version of this asked for
    // 3:1 here, which is the floor for text at 24px, and there is no text at 24px in this app.
    final onDesk = <String, Color>{
      'the hand for the desk': Hands.onDesk().color!,
      'a stamped label on the desk': Pen.onWood,
    };
    for (final e in onDesk.entries) {
      final r = contrast(e.value, _desk);
      expect(r, greaterThanOrEqualTo(_body),
          reason: '${e.key} is ${r.toStringAsFixed(2)}:1 on the desk, and it is set at 13px');
    }
  });

  test('the desk at dusk is still a ground, and the ink on it still has to clear the floor', () {
    // The whole library is re-rendered at dusk and not one declared constant moves, so this pair
    // was never checked in either condition until it was checked in both.
    for (final ground in {'day': DeskColour.day, 'dusk': DeskColour.dusk}.entries) {
      final r = contrast(Pen.onWood, ground.value);
      expect(r, greaterThanOrEqualTo(_body),
          reason: 'the desk hand is ${r.toStringAsFixed(2)}:1 on the desk at ${ground.key}');
    }
  });

  test('the pencil the margin is written in is for paper, and stays off the desk', () {
    // It is a good ink on paper and a bad one on wood. This holds both halves of that, so the
    // day nobody remembers why Hands.onDesk exists, the test says.
    final onPaper = contrast(Pen.margin, _paper);
    final onWood = contrast(Pen.margin, _desk);
    expect(onPaper, greaterThanOrEqualTo(_body),
        reason: 'the margin pencil is ${onPaper.toStringAsFixed(2)}:1 on paper');
    expect(onWood, lessThan(3.0),
        reason: 'the margin pencil now reads on wood too, so Hands.onDesk may be unnecessary — '
            'check the desk has not been lightened into something else');
  });

  test('both hands are legible on the paper they are written on', () {
    for (final e in {'noor': Pen.ballpoint, 'teo': Pen.graphite, 'a red pen': Pen.red}.entries) {
      final r = contrast(e.value, _paper);
      expect(r, greaterThanOrEqualTo(_body),
          reason: '${e.key} is ${r.toStringAsFixed(2)}:1 on the palest stock');
    }
  });

  test('every ink on every stock, and the list of what is not right yet only shrinks', () {
    final below = <String, double>{};
    for (final ink in _inks.entries) {
      for (final stock in _stocks.entries) {
        final r = contrast(ink.value, stock.value);
        if (r < _body) below['${ink.key} on ${stock.key}'] = r;
      }
    }

    final unexpected = below.keys.where((k) => !_knownBelowFloor.containsKey(k)).toList()..sort();
    expect(unexpected, isEmpty,
        reason: 'these pairs are below $_body:1 and are not written down: '
            '${unexpected.map((k) => '$k at ${below[k]!.toStringAsFixed(2)}:1').join(', ')}');

    for (final e in _knownBelowFloor.entries) {
      final now = below[e.key];
      expect(now, isNotNull,
          reason: '${e.key} clears $_body:1 now — take it out of _knownBelowFloor, because '
              'leaving it there tells the next reader a true thing about a fixed pair');
      expect(now, greaterThanOrEqualTo(e.value - 0.01),
          reason: '${e.key} was ${e.value}:1 and is now ${now!.toStringAsFixed(2)}:1, '
              'which is the wrong direction');
    }
  });
}
