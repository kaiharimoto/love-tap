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
  'obj_margin_sun': (c, s, h) {
    final centre = s.center(Offset.zero);
    h.arc(centre, s.width * 0.20, 0, _tau, steps: 36);
    for (var i = 0; i < 9; i++) {
      final a = _tau * i / 9 + 0.2;
      h.stroke([
        Offset(centre.dx + s.width * 0.27 * math.cos(a), centre.dy + s.width * 0.27 * math.sin(a)),
        Offset(centre.dx + s.width * 0.42 * math.cos(a), centre.dy + s.width * 0.42 * math.sin(a)),
      ]);
    }
  },
  'obj_corner_moon': (c, s, h) {
    final centre = s.center(Offset.zero);
    h.arc(centre, s.width * 0.30, -_tau * 0.20, _tau * 0.30, steps: 34);
    h.arc(centre + Offset(s.width * 0.14, 0), s.width * 0.28, -_tau * 0.17, _tau * 0.27, steps: 30);
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
  'obj_tongue_face': (c, s, h) {
    final w = s.width, ht = s.height;
    h.dot(Offset(w * 0.38, ht * 0.40), s.width * 0.035);
    h.dot(Offset(w * 0.62, ht * 0.39), s.width * 0.035);
    h.arc(Offset(w * 0.50, ht * 0.52), w * 0.18, 0.35, math.pi - 0.35, steps: 22);
    h.stroke([Offset(w * 0.50, ht * 0.66), Offset(w * 0.52, ht * 0.78), Offset(w * 0.44, ht * 0.80)],
        width: 1.4);
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
  'obj_rain': (c, s, h) {
    for (var i = 0; i < 7; i++) {
      final x = s.width * (0.18 + (i % 4) * 0.21);
      final y = s.height * (0.20 + (i ~/ 4) * 0.30 + (i % 3) * 0.06);
      h.stroke([Offset(x, y), Offset(x - s.width * 0.05, y + s.height * 0.22)], taper: 0.6);
    }
  },
  'obj_firework': (c, s, h) {
    final centre = s.center(Offset.zero);
    for (var i = 0; i < 12; i++) {
      final a = _tau * i / 12 + 0.13;
      final r = s.width * (0.16 + (i.isEven ? 0.28 : 0.20));
      h.stroke([centre, Offset(centre.dx + r * math.cos(a), centre.dy + r * math.sin(a))], taper: 0.7);
      h.dot(Offset(centre.dx + r * 1.14 * math.cos(a), centre.dy + r * 1.14 * math.sin(a)),
          s.width * 0.018);
    }
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
