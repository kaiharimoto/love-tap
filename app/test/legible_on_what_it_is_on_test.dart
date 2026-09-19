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
// colours against declared colours, and every ground in this app is a render. This file is the
// cheap pass that runs in a second. It is not the measurement.
//
// There was a fourth thing wrong with it, found on 2026-09-18 and the reason the last test in
// this file exists. It read every ink as it is DECLARED, and a widget is free to paint a
// declared ink at less than full strength: `_Margin` in regions/chat/note.dart wrapped the
// thread's timestamps in `Opacity(0.78)`, and that number was known to one call site and to
// nothing else. So this file swept `Pen.margin` against ten stocks, found 5.91:1 at worst, and
// passed, while `tools/check/legibility.py` read the pixels the widget actually produced and
// failed nineteen timestamp runs -- one of them at 1.02:1 against a floor of 4.5. Declared
// colour against declared colour is a real check and it is not the same check as painted
// against painted. Every thinning factor now has a name in material/palette.dart, and the sweep
// below reads them.
//
// The third thing that was wrong with it is gone now, and it was the largest. It asked whether
// the on-desk inks cleared 4.5:1 against `DeskColour.day`, which is a flat colour the app almost
// never ships: the plate renders 0.120 OKLab L lighter than it. Against the plate itself
// `Pen.onWood` was 2.49:1, and in `02_chat.png` the composer placeholder measured 1.56:1. No
// value would have fixed it — the plank's grain reaches Y 0.1467 and 4.5:1 against that needs an
// ink at Y -0.006, a number that does not exist — so `docs/COLOR.md` section 6 forbids the case
// rather than tuning the pair, and `Pen.onWood` and `Hands.onDesk` are deleted. The three tests
// that asserted those pairs are gone with them; what replaces them is the ladder, below, which
// is the rule they were a special case of.
import 'dart:math' as math;

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

/// OKLab lightness, which is the axis `docs/COLOR.md`'s ladder is written on. Luminance is not
/// interchangeable with it: #F3E08A and #3A3A3C differ by far more perceived lightness than their
/// luminances suggest, and a ladder judged in luminance drifts dark without anyone noticing.
double _oklabL(Color c) {
  double lin(double v) => v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4) as double;
  final r = lin(c.r), g = lin(c.g), b = lin(c.b);
  final l = math.pow(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b, 1 / 3) as double;
  final m = math.pow(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b, 1 / 3) as double;
  final s = math.pow(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b, 1 / 3) as double;
  return 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s;
}

/// OKLab chroma: how colourful, as distinct from how light.
double _oklabChroma(Color c) {
  double lin(double v) => v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4) as double;
  final r = lin(c.r), g = lin(c.g), b = lin(c.b);
  final l = math.pow(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b, 1 / 3) as double;
  final m = math.pow(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b, 1 / 3) as double;
  final s = math.pow(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b, 1 / 3) as double;
  final a = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s;
  final bb = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s;
  return math.sqrt(a * a + bb * bb);
}

/// Nothing in this app is set at 24px, so nothing in this app gets the large-text floor.
const _body = 4.5;

/// The `ink` step of the ladder. Derived rather than chosen: the darkest ground a word can
/// legitimately land on is aged stock rendered at dusk, Y p50 0.5528, and the dusk body floor of
/// 5.0:1 against that puts the ink at Y <= 0.0706, which is OKLab L 0.413. Rounded down to give a
/// handwritten hairline a little room.
const _inkCeiling = 0.40;

/// The `mid` step: contact shadow, the underside of a turned corner, tape, a photograph's
/// midtones. Nothing that sits here carries a word.
const _midLow = 0.52;
const _midHigh = 0.64;

/// Where an ink stops being a grey and starts being a colour. `Pen.red` is 0.155 and every other
/// ink in the palette is under 0.051, so nothing sits near this line and it is not load-bearing
/// to a thousandth.
const _chromatic = 0.10;

// There is deliberately no desk here. No ink of any colour is legible on the plank -- the
// arithmetic in no_word_is_written_on_the_desk_test.dart puts the required ink at Y = -0.006
// -- so there is no ink/desk pair to declare, and that invariant is structural rather than a
// contrast sum. Do not add one back: the sibling test is what enforces it.
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

/// Every factor by which this app paints a declared ink at less than full strength.
///
/// One entry today, and it is a 1.0, which is the point: a thinning that lives in a widget is
/// invisible to this file, and a thinning that lives here is not. An `Opacity` of 1.0 costs
/// nothing at paint time -- RenderOpacity paints its child directly rather than building a layer
/// -- so a widget keeping the wrapper and taking its factor from here is not carrying a cost for
/// the sake of the test.
///
/// Add the name here first and read it from the widget; do not write a factor into a widget.
const _thinnings = <String, double>{
  'margin': Pen.marginThinning,
};

/// What `Opacity` does to a colour: the ink mixed toward what is behind it, in sRGB component
/// space, which is where Flutter composites -- the same mix `Color.lerp` does, so the widget and
/// the test cannot disagree about it. A linear-light mix is a different and more generous number
/// and is not what the screen shows.
Color _thinned(Color ink, double alpha, Color ground) => Color.lerp(ground, ink, alpha)!;

/// The pairs that are below the floor today, with what they measure.
///
/// This is a ratchet and not an exemption list. The suite has to stay green so the rest of the
/// build can keep moving, and the failures have to stay visible so they get fixed, and those two
/// are only compatible if the list can shrink and cannot grow. So: a pair that is not on this list
/// and is below the floor fails. A pair on this list that has got worse fails. A pair on this list
/// that has been fixed also fails, because the entry is now a lie and the next person to read it
/// would believe it.
///
/// Seven of the eight entries that used to be here were `Pen.margin`, which was #6B6B6E: OKLab
/// L 0.529, sitting in the `mid` band, which is where shadows live. It was a shadow that had been
/// asked to spell. At L 0.3949 it clears every stock in the library, worst 5.91:1 on the pink
/// sticky, so all seven are gone from this list because they are gone from the build.
///
/// What is left is a red pen on a pink sticky note, which is a real pair and a genuinely hard
/// one: red on pink is two hues at the same lightness, and the fix is a stock or an ink rather
/// than a nudge.
const _knownBelowFloor = <String, double>{
  'red on stickyPink': 4.17,
};

void main() {
  test('every ink sits in the ink step of the ladder', () {
    // docs/COLOR.md section 2, as amended on 2026-09-16 by the measurement this test took.
    //
    // The ceiling binds by what the ink is for. An achromatic ink carries body text and sits at
    // L <= 0.40. A chromatic one may sit above that and below the mid band, because forcing red
    // to 0.40 takes it to #7C2520 and its chroma from 0.1553 to 0.1215 — and section 5 anchors
    // the whole figure chroma ceiling on red's 0.1553, so the rule as first written would have
    // destroyed the number the next rule depends on. What it may not do is skip the contrast
    // floors, and the every-ink-by-every-stock sweep below is where that is checked.
    for (final e in _inks.entries) {
      final l = _oklabL(e.value);
      final c = _oklabChroma(e.value);
      if (c >= _chromatic) {
        expect(l, lessThan(_midLow),
            reason: '${e.key} is chromatic (chroma ${c.toStringAsFixed(3)}) and at OKLab L '
                '${l.toStringAsFixed(3)}, which is in or above the mid band. A chromatic ink has '
                'room above the ink ceiling and none inside the band where shadows live.');
      } else {
        expect(l, lessThanOrEqualTo(_inkCeiling),
            reason: '${e.key} is achromatic (chroma ${c.toStringAsFixed(3)}) and at OKLab L '
                '${l.toStringAsFixed(3)}, above the ink ceiling of $_inkCeiling. An ink darker '
                'than every ground it can land on is the only kind that carries body text here.');
      }
    }
  });

  test('nothing in the mid band carries a word', () {
    // The mid band is contact shadow, tape and the underside of a turned corner. `Pen.margin`
    // used to sit in it at L 0.529 and that single fact explains seven of the eight pairs that
    // used to be in _knownBelowFloor.
    for (final e in _inks.entries) {
      final l = _oklabL(e.value);
      expect(l > _midLow && l < _midHigh, isFalse,
          reason: '${e.key} is at OKLab L ${l.toStringAsFixed(3)}, inside the mid band '
              '($_midLow..$_midHigh), which is where shadows live. An ink there is a shadow that '
              'has been asked to spell.');
    }
  });

  test('a surface clears the surface it rests on', () {
    // 0.18 L, docs/COLOR.md section 2. Paper on the day desk is 0.44 and passes with room; this
    // is here so that a desk lightened toward its paper, or a stock darkened toward its desk,
    // fails in a test rather than in a capture.
    final deskL = _oklabL(DeskColour.day);
    for (final e in _stocks.entries) {
      final gap = _oklabL(e.value) - deskL;
      expect(gap, greaterThanOrEqualTo(0.18),
          reason: '${e.key} is only ${gap.toStringAsFixed(3)} L above the day desk, and a sheet '
              'that does not clear what it lies on has no edge without a shadow to give it one');
    }
  });

  test('the desk is within reach of the flat colour that stands in for it', () {
    // The rule that caught the root cause, docs/COLOR.md section 2: a rendered ground may not sit
    // more than 0.05 L from the flat colour declared as its fallback. This half of it is the only
    // half a Dart test can see -- that the two declared desk colours are where the ladder says
    // the ground steps are. The other half, whether the plate agrees with them, is
    // tools/check/palette.py's job against assets/shell.
    expect((_oklabL(DeskColour.day) - 0.40).abs(), lessThanOrEqualTo(0.03),
        reason: 'the day desk is at OKLab L ${_oklabL(DeskColour.day).toStringAsFixed(3)}, and '
            'the ground_day step is 0.40 +/- 0.03');
    expect((_oklabL(DeskColour.dusk) - 0.26).abs(), lessThanOrEqualTo(0.03),
        reason: 'the dusk desk is at OKLab L ${_oklabL(DeskColour.dusk).toStringAsFixed(3)}, and '
            'the ground_dusk step is 0.26 +/- 0.03');
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

  test('an ink thinned by a widget still clears the floor on the stock it is thinned against', () {
    // The guard the nineteen failing timestamps did not have. Put `Pen.marginThinning` back to
    // 0.78 and this fails on six of the ten stocks -- pink sticky 3.74:1, stickyYellow 4.22,
    // underside 4.23, aged 4.24, legal 4.36, spiral 4.49 -- while all six tests above stay
    // green, because the ink they read is still #464648 at full strength and the thinning never
    // reached it. That is the whole of the blind spot, demonstrated rather than argued.
    //
    // The pair is checked against the stock rather than against the desk on purpose: `Opacity`
    // composites against whatever is behind the text, and what is behind a margin note is the
    // note's own paper. A word thinned against the desk is a different and worse case, and
    // docs/COLOR.md section 6 forbids it outright rather than tuning it.
    final below = <String, double>{};
    for (final t in _thinnings.entries) {
      final ink = _inks[t.key];
      expect(ink, isNotNull,
          reason: '_thinnings names "${t.key}", which is not an ink in _inks. A thinning factor '
              'with no ink to apply it to is a factor nothing is checking.');
      expect(t.value, inInclusiveRange(0.0, 1.0));
      for (final stock in _stocks.entries) {
        final r = contrast(_thinned(ink!, t.value, stock.value), stock.value);
        if (r < _body) below['${t.key} at ${t.value} on ${stock.key}'] = r;
      }
    }

    expect(below, isEmpty,
        reason: 'these inks are below $_body:1 once the widget has thinned them, however well '
            'they read at full strength: '
            '${below.entries.map((e) => '${e.key} at ${e.value.toStringAsFixed(2)}:1').join(', ')}');
  });
}
