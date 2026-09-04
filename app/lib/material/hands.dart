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

  /// A margin note in pencil: system facts inside the thread.
  static TextStyle margin({double size = 12.5}) => TextStyle(
        fontFamily: 'TeoHand',
        fontSize: size,
        color: Pen.margin,
        fontFeatures: _handFeatures,
      );

  static TextStyle of(Person p, {double size = 19, Color? colour}) =>
      p == Person.noor ? noor(size: size, colour: colour) : teo(size: size, colour: colour);

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
        style: Hands.of(by, size: size, colour: colour),
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
        style: Hands.stamp(
          size: size,
          colour: colour ?? (onDesk ? Pen.onWood : null),
          spacing: spacing,
        ),
      );
}
