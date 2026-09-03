// The one light. Every shadow in the app comes from a render made under this rig
// (blender/rig/common.py); nothing here invents a second direction. What lives here is only what
// the app needs to place those renders and to move paper consistently.
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Daylight from a window up and to the left, azimuth 315°, elevation 50° (DIRECTION.md).
/// In image space that puts the light in the top-left, so contact shadows fall down and to the
/// right by this unit vector.
const Offset kShadowDirection = Offset(0.34, 0.42);

/// How far a shadow shifts per millimetre of lift, in logical pixels at 1 mm ≈ 3.8 dp.
const double kShadowPerMm = 3.8;

enum LightCondition {
  /// Soft indirect daylight: the app's normal appearance.
  day,

  /// The dusk rig: a low cool sky and a warm desk lamp on the right. Not a dim overlay: the
  /// stocks, objects and shadows are separate renders under that condition.
  dusk,
}

class Light extends InheritedWidget {
  const Light({super.key, required this.condition, required super.child});

  final LightCondition condition;

  static LightCondition of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<Light>()?.condition ?? LightCondition.day;

  /// The asset suffix for the current condition ('' or '_dusk').
  static String suffixOf(BuildContext context) => of(context) == LightCondition.dusk ? '_dusk' : '';

  @override
  bool updateShouldNotify(Light old) => old.condition != condition;
}

/// A lift in millimetres becomes an offset for a piece's shadow.
Offset shadowOffsetFor(double liftMm) => kShadowDirection * (liftMm * kShadowPerMm);

/// How dark a contact shadow reads: close paper is a sharp dark line, lifted paper is softer.
double shadowOpacityFor(double liftMm) => (0.62 - 0.06 * liftMm).clamp(0.22, 0.7);

/// The angle in radians the light comes from, for anything that has to reason about it.
double get lightAngle => math.atan2(kShadowDirection.dy, kShadowDirection.dx);
