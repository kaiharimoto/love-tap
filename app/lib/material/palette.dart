// Colours from stationery, not from a UI palette (DIRECTION.md). Nothing here emits light: no
// glow, no saturated brand colour, no gradient that is not the shading of a fold.
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

  /// The stamped furniture face.
  static const stamp = Color(0xFF4A4A4C);

  /// A pencil margin note.
  /// Pencil, for the margin of a page. Two levels darker than it was, which is what it takes to
  /// clear four and a half to one against the palest stock at the size a margin note is set —
  /// 4.37 was close enough to look fine and not close enough to be right.
  static const margin = Color(0xFF6B6B6E);

  /// Stamp ink is made for paper, and on the desk it disappears. This is the same stamp in the
  /// chalky tone wood takes, for the few headings that sit straight on the wood.
  static const onWood = Color(0xFFBFB2A0);
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
