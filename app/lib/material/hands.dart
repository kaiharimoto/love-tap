// The two hands and the stamped furniture face. Contextual alternates are on everywhere, so a
// repeated letter never shows the same outline twice; nothing in the app is set in a system font
// except where a real machine did the printing (the receipt).
import 'package:flutter/material.dart';

import '../spine/event.dart';
import 'palette.dart';

const List<FontFeature> _handFeatures = [FontFeature.enable('calt'), FontFeature.enable('liga')];

class Hands {
  /// Noor: fast, slanted ballpoint.
  static TextStyle noor({double size = 19, Color? colour, double height = 1.42}) => TextStyle(
        fontFamily: 'NoorHand',
        fontSize: size,
        height: height,
        color: colour ?? Pen.ballpoint,
        fontFeatures: _handFeatures,
      );

  /// Teo: upright, heavy pencil.
  static TextStyle teo({double size = 19, Color? colour, double height = 1.46}) => TextStyle(
        fontFamily: 'TeoHand',
        fontSize: size,
        height: height,
        color: colour ?? Pen.graphite,
        fontFeatures: _handFeatures,
      );

  /// Furniture: tabs, stamps, dates.
  static TextStyle stamp({double size = 12, Color? colour, double spacing = 1.6}) => TextStyle(
        fontFamily: 'DeskStamp',
        fontSize: size,
        letterSpacing: spacing,
        color: colour ?? Pen.stamp,
        fontFeatures: _handFeatures,
      );

  // `Hands.onDesk` used to live here, for anything written straight onto the wood: the margin
  // line beside the thread, the composer, the word `search`. It is gone, and so is the ink it
  // was written in. The reasoning is in material/palette.dart and in docs/COLOR.md section 6, and
  // it is arithmetic rather than preference — no ink of any colour clears the body floor on the
  // plate this app ships. Everything that used it now sits on a `Strip` (material/slip.dart) and
  // is written in [margin], which is pencil, because a strip of stock is pale and pencil is not.

  /// A margin note in pencil: system facts inside the thread, and every label that used to be
  /// written on the desk.
  static TextStyle margin({double size = 12.5}) => TextStyle(
        fontFamily: 'TeoHand',
        fontSize: size,
        color: Pen.margin,
        fontFeatures: _handFeatures,
      );

  static TextStyle of(Person p, {double size = 19, Color? colour}) =>
      p == Person.noor ? noor(size: size, colour: colour) : teo(size: size, colour: colour);
}

/// Text written by one of the two people, in their hand.
class Written extends StatelessWidget {
  const Written(this.text, {super.key, required this.by, this.size = 19, this.colour, this.align = TextAlign.start, this.maxLines});
  final String text;
  final Person by;
  final double size;
  final Color? colour;
  final TextAlign align;
  final int? maxLines;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Hands.of(by, size: size, colour: colour),
        textAlign: align,
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
      );
}

/// A stamped label: tabs, dates, the furniture of the desk.
class Stamped extends StatelessWidget {
  const Stamped(this.text, {super.key, this.size = 12, this.colour, this.spacing = 1.6});

  // `Stamped.onDesk` used to be here, for a heading stamped straight onto the wood in a chalky
  // tone. A heading is a word, and words do not go on the wood any more; the headings that used
  // it are wrapped in a `Strip` and stamped in ordinary stamp ink, which is what stamp ink is for.

  final String text;
  final double size;
  final Color? colour;
  final double spacing;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        // A stamp does not wrap. It was stamped in one go, and a tab reading "SETTING / S" down
        // the bottom of a real phone is the letters running out of room, not a design.
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.visible,
        textHeightBehavior: const TextHeightBehavior(
          applyHeightToFirstAscent: false,
          applyHeightToLastDescent: false,
        ),
        style: Hands.stamp(size: size, colour: colour, spacing: spacing),
      );
}
