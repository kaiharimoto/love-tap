// The two hands and the stamped furniture face. Contextual alternates are on everywhere, so a
// repeated letter never shows the same outline twice; nothing in the app is set in a system font
// except where a real machine did the printing (the receipt).
import 'package:flutter/material.dart';

import '../flags.dart';
import '../spine/event.dart';
import 'ink.dart';
import 'palette.dart';

// Off only under Flags.plainFonts, which exists to measure what they cost and is never set in a
// build anybody uses. See the flag.
const List<FontFeature> _allFeatures = [FontFeature.enable('calt'), FontFeature.enable('liga')];
final List<FontFeature> _handFeatures = Flags.plainFonts ? const [] : _allFeatures;

class Hands {
  /// Noor: fast, slanted ballpoint.
  static TextStyle noor({double size = 19, Color? colour, double height = 1.42, bool inked = false}) {
    final c = colour ?? Pen.ballpoint;
    final paint = inked ? inkPaint('ballpoint', c) : null;
    return TextStyle(
      fontFamily: 'NoorHand',
      fontSize: size,
      height: height,
      // A TextStyle carries a colour or a paint, never both. The paint is the same colour with
      // the pen's coverage in its shader, so the letters are the colour they were.
      color: paint == null ? c : null,
      foreground: paint,
      fontFeatures: _handFeatures,
    );
  }

  /// Teo: upright, heavy pencil.
  static TextStyle teo({double size = 19, Color? colour, double height = 1.46, bool inked = false}) {
    final c = colour ?? Pen.graphite;
    final paint = inked ? inkPaint('graphite', c) : null;
    return TextStyle(
      fontFamily: 'TeoHand',
      fontSize: size,
      height: height,
      color: paint == null ? c : null,
      foreground: paint,
      fontFeatures: _handFeatures,
    );
  }

  /// Furniture: tabs, stamps, dates.
  static TextStyle stamp({double size = 12, Color? colour, double spacing = 1.6}) => TextStyle(
        fontFamily: 'DeskStamp',
        fontSize: size,
        letterSpacing: spacing,
        color: colour ?? Pen.stamp,
        fontFeatures: _handFeatures,
      );

  /// The same hand, in the ink that is legible on wood.
  ///
  /// Pencil grey is #6D6D70 and the desk is a dark waxed oak: one and a half to one, which is not
  /// a contrast ratio, it is a rumour. It was survivable while the desk was a flat fill and it
  /// stopped being survivable the moment the desk had grain in it. Anything written straight onto
  /// the desk — the margin line beside the thread, the composer, the word `search` — uses this.
  /// Anything written on paper uses [margin], because paper is pale and pencil is not.
  static TextStyle onDesk({double size = 13, Color? colour}) => TextStyle(
        fontFamily: 'TeoHand',
        fontSize: size,
        color: colour ?? Pen.onWood,
        fontFeatures: _handFeatures,
      );

  /// A margin note in pencil: system facts inside the thread.
  static TextStyle margin({double size = 12.5}) => TextStyle(
        fontFamily: 'TeoHand',
        fontSize: size,
        color: Pen.margin,
        fontFeatures: _handFeatures,
      );

  static TextStyle of(Person p, {double size = 19, Color? colour, bool inked = false}) =>
      p == Person.noor
          ? noor(size: size, colour: colour, inked: inked)
          : teo(size: size, colour: colour, inked: inked);

  /// The second pen a person reaches for (Noor: red; Teo: a hard biro).
  static TextStyle second(Person p, {double size = 19}) =>
      of(p, size: size, colour: p == Person.noor ? Pen.red : Pen.biro);
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
        // The plate goes in as the paint the glyphs are drawn with rather than as a ShaderMask
        // over them. Same ink; no compositing layer — and a piece of paper whose subtree needs a
        // layer of its own cannot have its tear drawn straight into the canvas, so every note in
        // the thread was baking its mask into an image on the build thread.
        style: Hands.of(by, size: size, colour: colour, inked: true),
        textAlign: align,
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
      );
}

/// A stamped label: tabs, dates, the furniture of the desk.
class Stamped extends StatelessWidget {
  const Stamped(this.text, {super.key, this.size = 12, this.colour, this.spacing = 1.6})
      : onDesk = false;

  /// A heading stamped straight onto the desk rather than onto a piece of paper. The stamp ink is
  /// dark because it is meant for paper; on the desk it disappears, so this is the same stamp in
  /// the chalky tone the desk takes.
  const Stamped.onDesk(this.text, {super.key, this.size = 12, this.spacing = 1.6})
      : colour = null,
        onDesk = true;

  final String text;
  final double size;
  final Color? colour;
  final double spacing;
  final bool onDesk;

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
        style: Hands.stamp(
          size: size,
          colour: colour ?? (onDesk ? Pen.onWood : null),
          spacing: spacing,
        ),
      );
}
