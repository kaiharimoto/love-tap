// Paper moves like paper: it lifts (its shadow grows), settles (its shadow shrinks), and curls at
// a corner before it turns. Durations are short and the overshoot is small — a note is light.
import 'package:flutter/animation.dart';

class Motion {
  static const lift = Duration(milliseconds: 180);
  static const settle = Duration(milliseconds: 260);
  static const turn = Duration(milliseconds: 320);
  static const land = Duration(milliseconds: 420);
  static const unfold = Duration(seconds: 4);

  /// A sheet dropping onto the desk: quick at first, then the air under it slows it.
  static const drop = Cubic(0.22, 0.9, 0.28, 1.0);

  /// A corner turning over: a little overshoot as the fibres spring.
  static const curl = Cubic(0.34, 1.12, 0.42, 1.0);

  /// A strip sliding off the desk when a note is sent.
  static const slide = Cubic(0.5, 0.0, 0.75, 0.2);
}
