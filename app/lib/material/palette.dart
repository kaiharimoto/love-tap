// Colours from stationery, not from a UI palette (DIRECTION.md). Nothing here emits light: no
// glow, no saturated brand colour, no gradient that is not the shading of a fold.
//
// docs/COLOR.md is the colour law and wins on any number here. In particular every achromatic ink
// in this file sits at OKLab L <= 0.40, which is the `ink` step of its ladder, derived from the
// darkest ground a word can legitimately land on.
//
// THAT DERIVATION NAMED A STOCK THAT IS NOT IN THE LIBRARY, and this header repeated it for four
// cycles. It read "aged stock rendered at dusk, Y p50 0.5528, which at the dusk body floor of
// 5.0:1 puts the ink at L <= 0.413". There is no `aged` render in assets/paper in any light --
// `Paper.aged` below is a flat swatch the app declares and never draws, which is exactly how the
// name survived -- and 0.5528 is `index_02_dusk`, a middling written stock. Eleven dusk stocks
// ship darker than it.
//
// The darkest ground a word can actually land on is `sticky_pink_02_dusk` at Y p50 0.4506, and a
// sticky has always been a ground for a word here: legible_on_what_it_is_on_test.dart has swept
// every ink against `Paper.stickyPink` since it was written. The same dusk floor of 5.0:1 against
// 0.4506 puts the ink at Y <= 0.0501, which is OKLab L 0.368. `tools/check/dusk_ground.py`
// measures it from the renders rather than quoting it, and the test reads what it wrote.
//
// AND THAT WAS STILL THE WRONG STATISTIC, WHICH IS THE THIRD TIME THIS DERIVATION HAS BEEN TAKEN
// AGAINST SOMETHING A WORD DOES NOT LAND ON. A p50 is the median pixel of a sheet. A word does not
// land on the median pixel of a sheet: every written stock in this library is PRINTED, and the
// line a word is written on is darker than the paper either side of it. Measured at firing 47 by
// `printed_rules` in the same tool, over the 21 ruled dusk renders, the horizontal rulings sit at
// Y 0.3963 (`spiral_04_dusk`) to 0.4414, every one of them below the premise. The dusk body floor
// of 5.0:1 against 0.3963 puts the ink at Y <= 0.0393, which is OKLab L 0.3375.
//
// The first derivation was taken against a stock that does not exist, the second against a stock
// that does and a statistic that misses the line. The measurement is not "which sheet is darkest"
// but "what is the darkest thing a line of writing is written ON", and it is now read that way.
//
// A SECOND NUMBER CAME OUT OF THE SAME MEASUREMENT AND NO INK ANSWERS IT. Legal, lined and spiral
// carry a red vertical margin rule, which at dusk measures Y 0.2235 (`spiral_03_dusk`) -- half the
// premise. 5.0:1 across it would need an ink at Y <= 0.0047, which is very nearly black and is not
// a stationery colour. A word laid ACROSS the margin rule cannot be rescued by any ink in this
// ladder; it is a placement defect, it is filed as its own queue item, and the ink below is
// derived against the horizontal ruling with that case excluded and named rather than averaged in.
//
// `Pen.onWood` used to live here, for the few headings written straight onto the desk. It is gone
// rather than retuned. It measured 4.94:1 against the flat colour the desk declares and 2.49:1
// against the plate the app actually ships, and no value would have rescued it: the plank's grain
// reaches Y 0.1467, and 4.5:1 against that needs an ink at Y -0.006, which does not exist. Words
// go on paper now (material/slip.dart, `Strip`).
import 'package:flutter/painting.dart';

class Pen {
  /// Noor: ballpoint blue-black.
  static const ballpoint = Color(0xFF1F2A44);

  /// Teo: graphite.
  ///
  /// Moved with the ceiling at firing 47 rather than chosen again. At #3A3A3C it read 5.411:1 on
  /// the darkest SHEET the ink ladder used to be derived from and 4.824:1 on the darkest printed
  /// RULING it is derived from now -- below the dusk body floor of 5.0, which the sweep in
  /// `legible_on_what_it_is_on_test.dart` found the moment the ground was corrected. It is the
  /// same miss `Pen.stamp` made and it was hidden by the same statistic.
  ///
  /// #323234 is not the lightest value that clears, because graphite is not furniture: it is a
  /// person's pencil and it carries their words. What is held instead is its RELATIONSHIP to the
  /// stamped face, which the palette already had and which the correction would otherwise have
  /// flattened -- graphite sat OKLab 0.0192 below `stamp`, and at #323234 under a `stamp` of
  /// #373739 it sits 0.0197 below. It reads 5.438:1 on `spiral_04_dusk`'s ruling.
  static const graphite = Color(0xFF323234);

  /// A cheap biro pressed hard.
  static const biro = Color(0xFF141A2E);

  /// Red pen, for logistics and corrections.
  static const red = Color(0xFFA8322B);

  /// The stamped furniture face. Inside the `ink` step of docs/COLOR.md's ladder at OKLab
  /// L 0.3375 -- it was 0.410 and outside it, then 0.3949 and inside a ceiling derived from a
  /// stock that does not exist, then 0.3684 and inside one derived from the darkest stock's
  /// MEDIAN PIXEL, and is now inside one derived from the darkest line a word is written on.
  ///
  /// The three readings, all on committed renders, all by `tools/check/dusk_ground.py`:
  ///
  ///   #464648  4.490:1 on `sticky_pink_02_dusk` p50 --  4.003:1 on the darkest printed rule
  ///   #3F3F41  5.009:1 on the same p50            --  4.466:1 on the darkest printed rule
  ///   #373739  5.663:1 on the same p50            --  5.049:1 on the darkest printed rule
  ///
  /// The dusk floor is 5.0, so the second row is the one that was passing a test and failing the
  /// screen: 24 of 54 runs below floor in `crops/dusk_pulse.png` at firing 39, and 17 of those 24
  /// sit on a horizontal ruling reading 0.395-0.448 -- which is the printed rule, not the paper.
  ///
  /// The dusk margin is 0.049, still thin on purpose: this is the LIGHTEST ink that clears the
  /// floor -- #38383A reads 4.97 and misses it -- and stamp and margin are furniture and want to
  /// recede. It is arithmetic on committed renders rather than a sampled reading, so it does not
  /// drift; a re-render that darkens a ruling turns it red, which is the test doing its job.
  ///
  /// What it does NOT buy, stated so nobody spends a firing expecting it: the six runs that cross
  /// the red margin rule stay below floor, because 3.094:1 is what this ink reads there and no
  /// ink in the ladder reads 5.0 across a ground at Y 0.2235.
  static const stamp = Color(0xFF373739);

  /// Pencil, for the margin of a page.
  ///
  /// It was #6B6B6E, which is OKLab L 0.529, and that is not an ink that is slightly too pale —
  /// it sits in the `mid` band, which is where contact shadows live. It was a shadow that had
  /// been asked to spell, and it was below 4.5:1 on six of the ten stocks it can land on: 3.33 on
  /// a pink sticky, 4.01 on a yellow one, 4.03 on the underside of a turned corner, 4.05 on aged,
  /// 4.22 on legal, 4.47 on graph. Its own comment said it had been tuned "against the palest
  /// stock", and that is the wrong end of the range to tune against: ink is tuned against the
  /// darkest ground it can land on -- which is the mistake this constant made twice. The first
  /// time it was tuned against the palest stock. The second time it was tuned against a ceiling
  /// derived from `index_02_dusk` under the name "aged", and cleared 5.0 against that and 4.490
  /// against the sticky that is really darkest. The third time it was tuned against that sticky's
  /// MEDIAN PIXEL, which is lighter than the ruling on any written stock in the library, and read
  /// 4.466:1 on the darkest of them. At L 0.3375 it clears the ruling too: 5.049:1 on
  /// `spiral_04_dusk`'s rule at dusk, and 5.663:1 on the pink sticky render it was last derived
  /// against. On the flat `Paper.stickyPink` swatch the day sweep reads 7.45:1, where it was 6.59.
  static const margin = Color(0xFF373739);

  /// How far a margin note is thinned toward the paper behind it.
  ///
  /// It is a named constant rather than a number inside a widget because thinning an ink changes
  /// which pair the legibility test is checking, and for four cycles nothing connected the two.
  /// `_Margin` in `regions/chat/note.dart` wrapped the thread's timestamps in `Opacity(0.78)`.
  /// `legible_on_what_it_is_on_test.dart` read [margin] at full strength, found 5.91:1 on the
  /// darkest stock, and passed. `tools/check/legibility.py` read the pixels and failed sixteen
  /// timestamps -- the queue item and firing 12's journal both say nineteen; counted from the
  /// committed evidence/legibility.json with two independent patterns it is sixteen, of which the
  /// thirteen at px 36 are this widget -- with six of them among the worst twelve runs in the
  /// capture. `Wed 22 Apr / 16:44`
  /// at 1.02:1, and a row of them at 4.44, 4.45 and 4.48 against a floor of 4.5, which is the
  /// shape of an ink that is fractionally too pale rather than one on the wrong ground.
  ///
  /// The arithmetic, composited the way `Opacity` composites, over the ten stocks in the library:
  /// at full strength [margin] runs 6.59:1 (pink sticky) to 9.33:1 (index) and clears the 4.5
  /// body floor everywhere. The 0.78 figures below were taken when it was #464648 and are kept as
  /// they were measured, because they are what the defect read: 3.74:1 to 4.68:1, with six of the
  /// ten below floor -- pink sticky 3.74, stickyYellow 4.22, underside 4.23, aged 4.24, legal
  /// 4.36, spiral 4.49. Darkening the ink lifts them; it does not make thinning a word safe.
  /// [margin] was derived to sit exactly at the ink ceiling of the ladder and therefore has no
  /// headroom at all to spend on being faint: the whole of its margin over the floor is the thing
  /// being thinned away.
  ///
  /// A smaller thinning was considered and is not what is written here, because the flat stocks
  /// are a stand-in and the real grounds are renders. The four stocks that survive 0.78 survive
  /// it by 0.02 to 0.18, and the runs the capture measured at 4.44, 4.45 and 4.48 are ones this
  /// same arithmetic calls 4.54 on lined. Whatever a render takes off comes out of a gap that is
  /// not there. Anything that thins an ink takes its factor from here, so the sweep in
  /// `legible_on_what_it_is_on_test.dart` can see it.
  static const marginThinning = 1.0;
}

class Accent {
  /// Multiplied, never on top: DIRECTION.md's accent line, and [highlighterBlend] is how. 70%, not
  /// the 45% it was, because docs/COLOR.md §5 prices the composite rather than the swatch: over
  /// the seven stocks a note or a search hit can be torn from ([stockFor]), multiplied at 45% the
  /// worst lands at chroma 0.0889 (graph_01 at dusk), under the 0.09 an accent is counted at; at
  /// 70% the worst is 0.1105 at hue 93°, inside family A, with 94% of its pixels over the line.
  /// And multiply only darkens, so the ink under it darkens with the paper instead of being
  /// veiled: painted on top at 45%, a highlighted note's ballpoint went from about 13:1 to 3.4:1.
  static const highlighterYellow = Color(0xB3F4EA6A); // 70%
  static const highlighterPink = Color(0x66F2A8C0); // 40%
  static const correctionFluid = Color(0xFFF7F5EE);
  static const tapeAmber = Color(0x8CD9B46B); // 55%
  static const stickyYellow = Color(0xFFF3E08A);
  static const stickyPink = Color(0xFFF2C1C1);
  static const stickyBlue = Color(0xFFBCD8E8);

  /// How a highlighter reaches the page. A dye, not a coat of paint.
  static const highlighterBlend = BlendMode.multiply;
}

/// A warm shadow, never neutral grey. (The desk's own colours live in material/desk.dart, with
/// the widget that paints it.)
class Shadow {
  static const warm = Color(0xFF3B3128);
}

/// The paper whites, for the rare surface with no render behind it (a loading sheet).
class Paper {
  static const lined = Color(0xFFF1ECDF);
  static const aged = Color(0xFFECE0C2);
  static const graph = Color(0xFFE9ECEC);
  static const legal = Color(0xFFF3E6A8);
  static const index = Color(0xFFF6F1E6);
  static const looseleaf = Color(0xFFF2EDE2);
  static const spiral = Color(0xFFEFEADC);
  static const stickyYellow = Color(0xFFF3E08A);
  static const stickyPink = Color(0xFFF2C1C1);

  /// The back of a sheet: the same paper with the light off it, for a corner turned over.
  static const underside = Color(0xFFE7E0CE);

  /// The colour a stock is, before its render arrives — or if it never does.
  ///
  /// A piece of paper with no paper on it is not a lesser version of a piece of paper. The setup
  /// screen came out as a page of dark text on bare wood at about one-to-one contrast, which is
  /// worse than any wrong colour would have been. Whatever else happens, a PaperPiece is the
  /// colour of the stock it is made of.
  static Color forStock(String stockId) {
    final family = stockId.split('_').first;
    return switch (family) {
      'lined' => lined,
      'graph' => graph,
      'legal' => legal,
      'index' => index,
      'looseleaf' => looseleaf,
      'spiral' => spiral,
      'sticky' => stockId.contains('pink') ? stickyPink : stickyYellow,
      _ => lined,
    };
  }
}

/// The pen a person writes with, by their id in seed/people.json.
Color inkFor(String person) => person == 'noor' ? Pen.ballpoint : Pen.graphite;

Color secondInkFor(String person) => person == 'noor' ? Pen.red : Pen.biro;
