// Colours from stationery, not from a UI palette (DIRECTION.md). Nothing here emits light: no
// glow, no saturated brand colour, no gradient that is not the shading of a fold.
//
// docs/COLOR.md is the colour law and wins on any number here. In particular every ink in this
// file sits at OKLab L <= 0.40, which is the `ink` step of its ladder, derived from the darkest
// ground a word can legitimately land on: aged stock rendered at dusk, Y p50 0.5528, which at the
// dusk body floor of 5.0:1 puts the ink at L <= 0.413.
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
  static const graphite = Color(0xFF3A3A3C);

  /// A cheap biro pressed hard.
  static const biro = Color(0xFF141A2E);

  /// Red pen, for logistics and corrections.
  static const red = Color(0xFFA8322B);

  /// The stamped furniture face. Inside the `ink` step of docs/COLOR.md's ladder at OKLab
  /// L 0.3949, where it was 0.410 and just outside it.
  static const stamp = Color(0xFF464648);

  /// Pencil, for the margin of a page.
  ///
  /// It was #6B6B6E, which is OKLab L 0.529, and that is not an ink that is slightly too pale —
  /// it sits in the `mid` band, which is where contact shadows live. It was a shadow that had
  /// been asked to spell, and it was below 4.5:1 on six of the ten stocks it can land on: 3.33 on
  /// a pink sticky, 4.01 on a yellow one, 4.03 on the underside of a turned corner, 4.05 on aged,
  /// 4.22 on legal, 4.47 on graph. Its own comment said it had been tuned "against the palest
  /// stock", and that is the wrong end of the range to tune against: ink is tuned against the
  /// darkest ground it can land on. At L 0.3949 it now clears every stock, worst 5.91:1 on the
  /// pink sticky, which also clears the dusk floor of 5.0.
  static const margin = Color(0xFF464648);

  /// How far a margin note is thinned toward the paper behind it.
  ///
  /// It is a named constant rather than a number inside a widget because thinning an ink changes
  /// which pair the legibility test is checking, and for four cycles nothing connected the two.
  /// `_Margin` in `regions/chat/note.dart` wrapped the thread's timestamps in `Opacity(0.78)`.
  /// `legible_on_what_it_is_on_test.dart` read [margin] at full strength, found 5.91:1 on the
  /// darkest stock, and passed. `tools/check/legibility.py` read the pixels and failed nineteen
  /// timestamps, six of them among the worst twelve runs in the capture -- `Wed 22 Apr / 16:44`
  /// at 1.02:1, and a row of them at 4.44, 4.45 and 4.48 against a floor of 4.5, which is the
  /// shape of an ink that is fractionally too pale rather than one on the wrong ground.
  ///
  /// The arithmetic, composited the way `Opacity` composites, over the ten stocks in the library:
  /// at full strength [margin] runs 5.91:1 (pink sticky) to 8.36:1 (index) and clears the 4.5
  /// body floor everywhere. At 0.78 it runs 3.74:1 to 4.68:1 and six of the ten are below floor
  /// -- pink sticky 3.74, stickyYellow 4.22, underside 4.23, aged 4.24, legal 4.36, spiral 4.49.
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
  static const highlighterYellow = Color(0x73F4EA6A); // 45%
  static const highlighterPink = Color(0x66F2A8C0); // 40%
  static const correctionFluid = Color(0xFFF7F5EE);
  static const tapeAmber = Color(0x8CD9B46B); // 55%
  static const stickyYellow = Color(0xFFF3E08A);
  static const stickyPink = Color(0xFFF2C1C1);
  static const stickyBlue = Color(0xFFBCD8E8);
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
