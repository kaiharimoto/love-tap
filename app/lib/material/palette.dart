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
  static const margin = Color(0xFF6D6D70);
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
}

/// The pen a person writes with, by their id in seed/people.json.
Color inkFor(String person) => person == 'noor' ? Pen.ballpoint : Pen.graphite;

Color secondInkFor(String person) => person == 'noor' ? Pen.red : Pen.biro;
