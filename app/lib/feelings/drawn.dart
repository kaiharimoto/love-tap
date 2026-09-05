// The feelings you draw rather than fold.
//
// Most of the vocabulary is a thing: a paper crane, a stone, a candle, a cinema ticket. Those are
// modelled and rendered under the one light rig like everything else. But some of what one person
// hands another is not an object at all — it is a mark made in the margin of whatever was to hand.
// A sun scribbled at the top of a page. A moon on the corner. Rain. A tongue stuck out.
//
// Drawing those in Blender would be a mistake in both directions: it would take a thing that has
// no thickness and give it some, and it would put a rendered object where a hand should be. So
// they are drawn here, in the same hand that draws every other mark in the app — a pen with a
// wobble, pressing harder in the middle of a stroke than at either end.
//
// What is not drawn here any more: a sun with rays, a crescent moon, a tongue-out face, rain and a
// firework. Drawn by hand they were still the standard emoji set — a critic seeing the vocabulary
// for the first time named them as such — and those feelings are things now (blender/objects/).
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// A feeling drawn as a mark. Null for the ones that are objects.
typedef DrawnFeeling = void Function(Canvas canvas, Size size, DrawingHand hand);

/// A hand holding a pen. The same pressure and wobble as material/marks.dart, kept separate so a
/// feeling can be drawn without the app's chrome and the emotional layer depending on each other.
class DrawingHand {
  DrawingHand(this.canvas, this.colour, this.weight, int seed) : _rng = math.Random(seed);
  final Canvas canvas;
  final Color colour;
  final double weight;
  final math.Random _rng;

  double _wobble(double amount) => (_rng.nextDouble() - 0.5) * amount;

  void stroke(List<Offset> points, {double wobble = 0.7, double taper = 0.4, double width = 1.0}) {
    if (points.length < 2) return;
    final pts = [for (final p in points) p + Offset(_wobble(wobble), _wobble(wobble))];
    final n = pts.length - 1;
    for (var i = 0; i < n; i++) {
      final t = n == 1 ? 0.5 : i / (n - 1);
      final swell = 1 - taper * (2 * t - 1).abs();
      canvas.drawLine(
        pts[i],
        pts[i + 1],
        Paint()
          ..color = colour.withValues(alpha: colour.a * (0.7 + 0.3 * swell))
          ..strokeWidth = weight * width * (0.7 + 0.6 * swell)
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void arc(Offset centre, double r, double from, double to, {int steps = 28, double wobble = 0.6}) {
    stroke([
      for (var i = 0; i <= steps; i++)
        Offset(centre.dx + r * math.cos(from + (to - from) * i / steps),
            centre.dy + r * math.sin(from + (to - from) * i / steps)),
    ], wobble: wobble);
  }

  void dot(Offset at, double r) => canvas.drawCircle(at, r, Paint()..color = colour);
}

const double _tau = math.pi * 2;

/// Every feeling whose object is a mark rather than a thing.
final Map<String, DrawnFeeling> kDrawnFeelings = {
  'obj_thumbprint': (c, s, h) {
    // a thumb pressed on the page: arcs that do not quite close
    for (var i = 0; i < 6; i++) {
      final r = s.width * (0.09 + i * 0.055);
      h.arc(s.center(Offset.zero), r, -0.6 - i * 0.12, _tau * 0.78 - i * 0.1, wobble: 0.9);
    }
  },
  'obj_chair': (c, s, h) {
    final w = s.width, ht = s.height;
    h.stroke([Offset(w * 0.32, ht * 0.22), Offset(w * 0.32, ht * 0.60)]);          // back
    h.stroke([Offset(w * 0.32, ht * 0.60), Offset(w * 0.72, ht * 0.56)]);          // seat
    h.stroke([Offset(w * 0.36, ht * 0.60), Offset(w * 0.34, ht * 0.84)]);          // legs
    h.stroke([Offset(w * 0.69, ht * 0.57), Offset(w * 0.72, ht * 0.82)]);
    h.stroke([Offset(w * 0.30, ht * 0.26), Offset(w * 0.44, ht * 0.24)]);          // top rail
  },
  'obj_window': (c, s, h) {
    final w = s.width, ht = s.height;
    h.stroke([Offset(w * 0.24, ht * 0.22), Offset(w * 0.76, ht * 0.20),
              Offset(w * 0.78, ht * 0.78), Offset(w * 0.26, ht * 0.80), Offset(w * 0.24, ht * 0.22)]);
    h.stroke([Offset(w * 0.51, ht * 0.21), Offset(w * 0.52, ht * 0.79)]);
    h.stroke([Offset(w * 0.25, ht * 0.50), Offset(w * 0.77, ht * 0.49)]);
  },
  'obj_user_pigeon': (c, s, h) {
    // the pigeon: the feather it left on top of the cupboard, in pencil — a curved shaft with the
    // barbs coming off it, longer in the middle, and the downy bit at the quill
    final w = s.width, ht = s.height;
    final shaft = <Offset>[];
    for (var i = 0; i <= 24; i++) {
      final t = i / 24;
      shaft.add(Offset(w * (0.22 + 0.58 * t), ht * (0.78 - 0.56 * t + 0.10 * math.sin(t * math.pi))));
    }
    h.stroke(shaft, wobble: 0.5, taper: 0.5, width: 1.3);
    for (var i = 3; i < 22; i += 2) {
      final t = i / 24;
      final at = shaft[i];
      final len = w * (0.06 + 0.13 * math.sin(t * math.pi));
      final side = i.isEven ? 1.0 : -1.0;
      h.stroke([at, at + Offset(-len * 0.55, side * len * 0.9 - len * 0.3)], taper: 0.7, width: 0.8);
    }
    for (var i = 0; i < 5; i++) {
      final at = shaft[1] + Offset(w * 0.01 * i, ht * 0.01 * i);
      h.stroke([at, at + Offset(-w * 0.05, ht * (0.03 + 0.02 * i))], taper: 0.8, width: 0.6);
    }
  },
  'obj_scribble': (c, s, h) {
    final pts = <Offset>[];
    for (var i = 0; i <= 90; i++) {
      final t = i / 90;
      pts.add(Offset(s.width * (0.16 + 0.68 * t),
          s.height * (0.5 + 0.30 * math.sin(t * _tau * 2.6) * (1 - 0.4 * t))));
    }
    h.stroke(pts, wobble: 1.1, taper: 0.25, width: 1.2);
  },
};

/// Draws one, if it is one of these.
class DrawnFeelingMark extends StatelessWidget {
  const DrawnFeelingMark({super.key, required this.object, required this.colour, this.size = 84, this.seed = 0});

  final String object;
  final Color colour;
  final double size;
  final int seed;

  static bool has(String object) => kDrawnFeelings.containsKey(object);

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: _DrawnPainter(kDrawnFeelings[object]!, colour, size, seed),
      );
}

class _DrawnPainter extends CustomPainter {
  _DrawnPainter(this.draw, this.colour, this.size, this.seed);
  final DrawnFeeling draw;
  final Color colour;
  final double size;
  final int seed;

  @override
  void paint(Canvas canvas, Size s) =>
      draw(canvas, s, DrawingHand(canvas, colour, math.max(1.0, s.width / 44), seed + 7));

  @override
  bool shouldRepaint(_DrawnPainter old) => old.colour != colour || old.seed != seed;
}
