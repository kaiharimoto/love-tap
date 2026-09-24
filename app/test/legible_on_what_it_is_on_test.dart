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
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:desk/material/desk.dart';
import 'package:desk/material/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'no_word_is_written_in_a_faded_ink_test.dart' show kMinInkAlpha;

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

/// The `ink` step of the ladder. Derived rather than chosen -- and derived, until firing 38, from
/// a stock that is not in the library.
///
/// The derivation used to read: "the darkest ground a word can legitimately land on is aged stock
/// rendered at dusk, Y p50 0.5528, and the dusk body floor of 5.0:1 against that puts the ink at
/// Y <= 0.0706, which is OKLab L 0.413." There is no `aged` render in `assets/paper` in any light
/// -- `Paper.aged` is a flat swatch the app declares and never draws, which is how the name
/// survived four cycles -- and 0.5528 is `index_02_dusk`, a middling written stock, not the
/// darkest anything. Eleven dusk stocks ship darker than it.
///
/// The darkest ground a word can actually land on is `sticky_pink_02_dusk` at Y p50 0.4506, and
/// the app has always treated a sticky as a ground for a word: the sweep below has read every ink
/// against `Paper.stickyPink` since it was written. The same body floor of 5.0:1 against 0.4506
/// puts the ink at Y <= 0.0501, which is OKLab L 0.368.
///
/// AND A p50 IS STILL THE WRONG STATISTIC, which firing 47 measured and this file now reads. A
/// word does not land on a sheet's median pixel; on every written stock in this library it lands
/// on a PRINTED RULE, which is darker than the paper either side of it. The 21 ruled dusk renders
/// carry rulings at Y 0.3963 to 0.4414 -- every one below the premise -- and the same floor of
/// 5.0:1 against the darkest of them puts the ink at Y <= 0.0393, OKLab L 0.3375. The dusk test at
/// the end of this file reads that number out of `evidence/dusk_ground.json` rather than either
/// p50, and `tools/check/dusk_ground_selftest.py` is where the ruler that produces it earns its
/// place against 21 day/dusk pairs.
///
/// The ceiling stays at 0.40 because that is what the ladder declares and this file does not get
/// to move it; what the re-derivation binds is the CONTRAST, and that is checked against the
/// measured library in the dusk test at the end of this file rather than inferred from a swatch.
const _inkCeiling = 0.40;

/// The dusk body floor, from docs/COLOR.md §6. A word at dusk is read in less light and asks for
/// more separation than the 4.5 a day screen asks for.
const _duskBody = 5.0;

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
/// asked to spell. At L 0.3375 it clears every stock in the library, worst 7.45:1 on the pink
/// sticky, so all seven are gone from this list because they are gone from the build.
///
/// What is left is a red pen on a pink sticky note, which is a real pair and a genuinely hard
/// one: red on pink is two hues at the same lightness, and the fix is a stock or an ink rather
/// than a nudge.
///
/// Firing 62 took that last one out by the only route that cost no colour: red is a MARKING ink
/// ([_markingInks]) and writes no word, which `red is a marking ink and writes no word` below holds.
const _knownBelowFloor = <String, double>{};

/// Inks that mark and never spell: the cross on a refused note, the turn-back beside `try again`,
/// the ring round a pencil worn to a stub. **Red, and only red.** It is the one chromatic ink, and
/// docs/COLOR.md §2's amendment exempts it from the achromatic lightness ceiling because forcing it
/// down to L 0.40 takes its chroma from 0.1553 to 0.1215 and §5 anchors the figure chroma ceiling
/// on that 0.1553. The exemption was from the ceiling, never from the floors -- and red on the
/// darkest dusk ruling is 2.8:1, on the pink sticky by day 4.17:1. Of the three routes the item
/// priced (darken red and re-derive §5; lighten the darkest stock, which does not close it alone;
/// deny red the words) the third is the one that costs no colour. A marking ink is walked by every
/// sweep below and counted in its population, and its pairs are not held to a body floor, because
/// it carries no body.
const _markingInks = {'red'};

void main() {
  _theDarkestGroundThatShips();
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

  test('red is a marking ink and writes no word', () {
    // What lets the sweeps pass over [_markingInks]: nothing in lib/ sets a word in one. A red
    // TextStyle is how `refused` and `try again` were written on the refused row, the one row in
    // the app whose whole job is to be read when something has gone wrong -- at 4.38:1 on the
    // legal stock 13_messenger_states drew it on. Re-break by putting
    // `.copyWith(color: Pen.red)` back on either and this names the line.
    final wordish = RegExp(r'TextStyle|copyWith\(\s*color|style:|Text\(|Written\(|Stamped\(|Hands\.');
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      for (final (i, line) in f.readAsLinesSync().indexed) {
        final code = line.trimLeft();
        if (code.startsWith('//')) continue;
        if (code.contains('Pen.red') && wordish.hasMatch(code)) offenders.add('${f.path}:${i + 1}: $code');
      }
    }
    expect(offenders, isEmpty,
        reason: 'a word is set in a marking ink, which the legibility sweeps do not hold to a body '
            'floor:\n${offenders.join('\n')}');
    expect(_markingInks, {'red'}, reason: 'a marking ink is a claim this test has to check');
  });

  test('every ink on every stock, and the list of what is not right yet only shrinks', () {
    final below = <String, double>{};
    var walked = 0;
    for (final ink in _inks.entries) {
      for (final stock in _stocks.entries) {
        walked++;
        if (_markingInks.contains(ink.key)) continue;
        final r = contrast(ink.value, stock.value);
        if (r < _body) below['${ink.key} on ${stock.key}'] = r;
      }
    }
    expect(walked, _inks.length * _stocks.length);
    expect(walked, greaterThanOrEqualTo(60), reason: 'an ink or a stock left the sweep');

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
    // green, because the ink they read is still the declared ink at full strength and the thinning never
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

// ---------------------------------------------------------------------------------------------
// And the dusk half, read from the stocks that ship rather than from a swatch.
//
// Everything above this line is a declared colour against a declared colour, and every ground in
// this app is a render. That is said at the top of the file and it is the reason `Paper.aged`
// could be the premise of the whole ink ladder while no `aged` render existed: a flat swatch is
// not a stock, and nothing was comparing the two.
//
// `tools/check/dusk_ground.py` measures every render in `assets/paper` and writes
// `evidence/dusk_ground.json`. This reads that file, takes the darkest ground it found, and asks
// the achromatic inks for the dusk body floor against it -- which is the law's own derivation,
// applied to the library the law is about.
//
// WHICH GROUND, AND WHY IT CHANGED AT FIRING 47. It used to read `darkest_dusk.p50`: the median
// pixel of the darkest sheet. That is not a ground a word lands on. It lands on the printed rule,
// and this now reads `written_ground.y` -- the darkest horizontal ruling over every ruled dusk
// render. The p50 is still in the report and still asserted below, because an ink that clears the
// rule and misses the sheet would mean the ruling is no longer the binding ground and this file
// should be read again.
//
// ACHROMATIC ONLY, and that is the law as written rather than an exemption invented here. §2
// binds an achromatic ink to L <= 0.40 because it carries body text; a chromatic one is allowed
// above that, because forcing `Pen.red` to 0.40 takes its chroma from 0.1553 to 0.1215 and §5
// anchors the figure chroma ceiling on that 0.1553. Red therefore goes in a ratchet with its
// measured number, the way `_knownBelowFloor` already holds `red on stickyPink`, rather than
// being silently excluded.
//
// Re-break: put `Pen.stamp` and `Pen.margin` back to #3F3F41 and this fails at 4.466:1 against
// `spiral_04_dusk`'s ruling, naming the stock. Back to #464648 and it fails at 4.003:1.

/// Chromatic inks below the dusk floor on the darkest ground, written down with what they measure
/// AND with the luminance of the ink that measured it. It may only shrink, like its day-lit
/// sibling above.
///
/// THE RATIO IS NOT THE RATCHET, AND FIRING 47 IS WHY. This used to hold `red: 3.17` alone and
/// assert that the ratio could not fall. A ratio is (ground + 0.05) / (ink + 0.05), so it falls
/// when the GROUND gets darker just as readily as when the ink gets lighter -- and moving the
/// derivation from the darkest sheet (Y 0.4506) to the darkest printed rule (Y 0.3963) took red
/// from 3.17:1 to 2.83:1 without touching a single colour. That is a harder ground, not a worse
/// ink, and a ratchet that cannot tell the two apart fails on the first honest correction and
/// then gets loosened, which is how a ratchet stops meaning anything.
///
/// So the thing held still is the INK, whose luminance this file does control: `y` may not rise.
/// The ratio is kept beside it and checked against the ground of the day, so the entry cannot go
/// stale and be believed -- if the ground moves, the recorded ratio has to be re-measured and the
/// commit that does it says which ground it was taken against.
class _KnownBelowFloor {
  const _KnownBelowFloor(this.ratio, this.y, this.against);

  /// What it measured, on the ground named in [against].
  final double ratio;

  /// The ink's own relative luminance when that was measured. This is the ratchet.
  final double y;

  /// The ground the ratio was taken against, so a moved ground is visible rather than absorbed.
  final String against;
}

const _knownBelowFloorAtDusk = <String, _KnownBelowFloor>{
  // `red` was here at 2.83:1 against spiral_04_dusk's ruling at Y 0.3963, Y 0.1086. Firing 62
  // made red a marking ink (_markingInks), which writes no word, so it left the list by leaving
  // the body, not by the ratio moving.
};

/// The (ink, alpha) pairs below the dusk body floor when composited at the faintest alpha
/// docs/COLOR.md §6 permits, on the darkest printed ruling, with what each reads. Measured at
/// firing 62 against spiral_04_dusk's ruling at Y 0.3963. It may only shrink.
const _knownBelowFloorAtMinAlpha = <String, double>{
  'ballpoint at 0.80': 4.177,
  'graphite at 0.80': 3.773,
  'stamp at 0.80': 3.542,
  'margin at 0.80': 3.542,
  // red is a marking ink and writes no word (_markingInks); it read 2.828 and 2.395 here
};

/// Read once, so a missing or malformed report fails loudly rather than skipping the test.
Map<String, dynamic> _duskGround() {
  // The test runs with `app/` as its working directory.
  final f = File('../evidence/dusk_ground.json');
  if (!f.existsSync()) {
    fail('evidence/dusk_ground.json is missing. Run `python3 tools/check/dusk_ground.py --out '
        'evidence/dusk_ground.json`. A check that skips itself when its measurement is absent is '
        'the same failure as a floor that gates nothing.');
  }
  return jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
}

void _theDarkestGroundThatShips() {
  test('every achromatic ink clears the dusk floor on the darkest line a word is written on', () {
    final report = _duskGround();
    final written = report['written_ground'] as Map<String, dynamic>?;
    if (written == null) {
      fail('evidence/dusk_ground.json has no `written_ground`. Regenerate it with '
          '`python3 tools/check/dusk_ground.py --out evidence/dusk_ground.json`; a report from '
          'before firing 47 reads the darkest SHEET and not the darkest RULE, and the ink is no '
          'longer derived from the sheet.');
    }
    final stock = written['stock'] as String;
    final groundY = (written['y'] as num).toDouble();
    final sheet = report['darkest_dusk'] as Map<String, dynamic>;
    final sheetY = (sheet['p50'] as num).toDouble();

    // The measurement is of the library, so say how much of it was read. A floor met because the
    // sweep shrank is the failure WORKER_PROMPT §3d's population clause exists for.
    final counted = report['counted'] as Map<String, dynamic>;
    expect((counted['dusk'] as num).toInt(), greaterThanOrEqualTo(27),
        reason: 'the dusk library had 27 renders when this was written and has '
            '${counted['dusk']}. A darkest-ground floor is only as good as the set it is the '
            'darkest of, so this may not fall.');
    // The same clause for the rules themselves: the binding number is the darkest of 21, and a
    // ruling that stops being FOUND would lift the ground without lightening a single pixel.
    expect((written['counted'] as num).toInt(), greaterThanOrEqualTo(21),
        reason: '21 ruled dusk renders carried a printed ruling when this was written and '
            '${written['counted']} do now. The ink ceiling is the darkest of that set, so a '
            'ruling the tool stops finding is a floor that rises for free.');
    // And the rule has to still be the darker of the two. If a re-render ever takes a SHEET below
    // its own ruling, the derivation above is against the wrong one of them again.
    expect(groundY, lessThan(sheetY),
        reason: 'the darkest printed rule ($groundY on $stock) is no longer darker than the '
            'darkest sheet ($sheetY on ${sheet['stock']}), so the ink is being derived against '
            'the lighter of the two. Read docs/COLOR.md §2 again before touching this.');

    var walked = 0;
    final below = <String, double>{};
    for (final e in _inks.entries) {
      // (ink, darkest dusk ground) -- one pair per ink, counted so the assertion cannot be met
      // by an ink leaving the sweep.
      walked++;
      final r = (groundY + 0.05) / (_lum(e.value) + 0.05);
      if (_markingInks.contains(e.key)) continue;
      if (_oklabChroma(e.value) >= _chromatic) {
        final known = _knownBelowFloorAtDusk[e.key];
        expect(known, isNotNull,
            reason: '${e.key} is chromatic and is not written down in _knownBelowFloorAtDusk');
        // The ratchet: the INK may not get lighter. A ground that gets darker is allowed to take
        // the ratio down with it, because that is the ground telling the truth.
        expect(_lum(e.value), lessThanOrEqualTo(known!.y + 0.0005),
            reason: '${e.key} was Y ${known.y} when it was written down and is now '
                '${_lum(e.value).toStringAsFixed(4)}. A chromatic ink in this list may only get '
                'darker; it is already below the floor.');
        // And the entry may not go stale: what it says it measures has to be what it measures on
        // today's ground, or the number beside it is decoration.
        expect(r, closeTo(known.ratio, 0.02),
            reason: '${e.key} is written down as ${known.ratio}:1 against ${known.against} and '
                'reads ${r.toStringAsFixed(2)}:1 on $stock at Y $groundY. Re-measure the entry '
                'and say in the commit which ground moved.');
        continue;
      }
      if (r < _duskBody) below['${e.key} on $stock'] = r;
    }

    expect(walked, _inks.length,
        reason: 'the sweep read $walked of ${_inks.length} inks');
    expect(below, isEmpty,
        reason: 'these achromatic inks are below $_duskBody:1 on $stock, whose printed ruling at '
            'Y $groundY is the darkest ground a word can land on in this build: '
            '${below.entries.map((e) => '${e.key} at ${e.value.toStringAsFixed(3)}:1').join(', ')}'
            '. docs/COLOR.md §2 derives the ink ceiling from exactly this stock, so an ink that '
            'misses here is an ink the law does not actually permit.');
  });

  // **docs/COLOR.md §6 lets a word's ink composite at alpha 0.80 and §2 derives every ink to clear
  // the dusk floor at FULL strength, and the two were never multiplied together.** This is the
  // same sweep at the minimum alpha the law permits (`kMinInkAlpha`, which
  // `no_word_is_written_in_a_faded_ink_test` enforces), composited the way Flutter composites an
  // ordinary surface -- in sRGB, per channel, over the grey of the darkest printed rule. Firing
  // 47 checked the compositing space against a run on the glass: `week one` in crops/dusk_pulse
  // is ballpoint at 0.851 and its measured ink core, Y 0.0481, is on the sRGB side (0.0536)
  // rather than the linear one (0.031).
  //
  // It is a ratchet and not a floor, because what closes it is a rule about WHERE a thinned ink
  // may be used, which is a design decision. Raising kMinInkAlpha to 1.0 would close it by
  // forbidding every thinned ink; deriving the inks at 0.80 takes `stamp` below Y 0, which is no
  // ink. So the pairs below the floor are written down with what they read, a new one fails, and
  // one that clears has to be taken out. Re-break by sweeping at alpha 1.0 instead: every entry
  // below then clears and the test names each one as stale.
  test('every ink at the faintest alpha the law permits, on the darkest line a word is written on',
      () {
    final report = _duskGround();
    final written = report['written_ground'] as Map<String, dynamic>;
    final stock = written['stock'] as String;
    final groundY = (written['y'] as num).toDouble();
    // the grey whose luminance is the ground's, in sRGB, which is where the blend happens
    final g = groundY <= 0.0031308 ? groundY * 12.92 : 1.055 * math.pow(groundY, 1 / 2.4) - 0.055;
    final ground = Color.from(alpha: 1, red: g, green: g, blue: g);
    const alpha = kMinInkAlpha / 255;

    var walked = 0;
    final below = <String, double>{};
    for (final e in _inks.entries) {
      for (final a in const [1.0, alpha]) {
        walked++;
        if (_markingInks.contains(e.key)) continue;
        final c = e.value;
        final over = Color.from(
          alpha: 1,
          red: a * c.r + (1 - a) * ground.r,
          green: a * c.g + (1 - a) * ground.g,
          blue: a * c.b + (1 - a) * ground.b,
        );
        final r = contrast(over, ground);
        if (r < _duskBody) below['${e.key} at ${a.toStringAsFixed(2)}'] = r;
      }
    }
    // the population clause: every ink at both strengths, so the list cannot shrink by an ink
    // leaving the sweep
    expect(walked, 2 * _inks.length, reason: 'the sweep walked $walked (ink, alpha) pairs');
    expect(_inks.length, greaterThanOrEqualTo(6), reason: 'an ink left the table');

    final unexpected = below.keys.where((k) => !_knownBelowFloorAtMinAlpha.containsKey(k)).toList()
      ..sort();
    expect(unexpected, isEmpty,
        reason: 'these (ink, alpha) pairs are below $_duskBody:1 on $stock at Y $groundY and are '
            'not written down: ${unexpected.map((k) => '$k ${below[k]!.toStringAsFixed(3)}:1').join(', ')}');
    for (final e in _knownBelowFloorAtMinAlpha.entries) {
      final r = below[e.key];
      expect(r, isNotNull,
          reason: '${e.key} clears $_duskBody:1 on $stock now -- take it out of '
              '_knownBelowFloorAtMinAlpha, because the list may only shrink');
      expect(r!, closeTo(e.value, 0.02),
          reason: '${e.key} is written down at ${e.value}:1 and reads ${r.toStringAsFixed(3)}:1 '
              'on $stock at Y $groundY. Re-measure it and say in the commit which ground moved.');
    }
  });

  test('the law quotes a stock that is on disk', () {
    // The other half of what firing 36 found, kept as a test so the sentence cannot drift back.
    // §2 named a render that does not exist; if one is ever added under that name this test says
    // so rather than continuing to assert a correction that is no longer needed.
    final premise = _duskGround()['law_premise'] as Map<String, dynamic>;
    expect(premise['no_such_render'], isTrue,
        reason: 'an `aged` render now exists in assets/paper. docs/COLOR.md §2 and '
            'material/palette.dart were corrected on the basis that it did not, and both should '
            'be read again against it.');
    expect((premise['darker_stocks_shipping'] as List).isNotEmpty, isTrue,
        reason: 'nothing ships darker than §2\'s premise any more, which would mean the premise '
            'has become the darkest ground after all and this file can stop correcting it');
  });
}
