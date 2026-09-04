// The marks a hand makes when a word will not do.
//
// There is no icon set here and there never will be: everything below is a pen or pencil stroke
// with the pressure and the wobble of a hand, drawn at the size it is used at. Where a word fits
// (find, send, keep, leave it) the word is used instead, in the margin hand.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'palette.dart';

/// A hand-drawn mark. [seed] moves the wobble so two marks on one screen are not twins.
class Mark extends StatelessWidget {
  const Mark._(this._draw, {required this.size, required this.colour, required this.weight, required this.seed});

  final void Function(Canvas canvas, Size size, _Hand hand) _draw;
  final double size;
  final Color colour;
  final double weight;
  final int seed;

  /// A paperclip: one continuous wire, bent back on itself twice.
  factory Mark.clip({double size = 22, Color colour = Pen.graphite, int seed = 3}) =>
      Mark._(_clip, size: size, colour: colour, weight: 1.35, seed: seed);

  /// Three pencil ticks standing in a row: the shape a voice note takes in the thread, so the
  /// thing that records looks like the thing it makes. [level] swells them while recording.
  factory Mark.ticks({double size = 22, Color colour = Pen.graphite, double level = 0, int seed = 7}) =>
      Mark._((c, s, h) => _ticks(c, s, h, level), size: size, colour: colour, weight: 1.5, seed: seed);

  /// A loop with a tail, the way anyone circles a word they are looking for.
  factory Mark.loop({double size = 22, Color colour = Pen.ballpoint, int seed = 11}) =>
      Mark._(_loop, size: size, colour: colour, weight: 1.25, seed: seed);

  /// A cross: struck through, the way a line is crossed out rather than dismissed.
  factory Mark.cross({double size = 18, Color colour = Pen.margin, int seed = 5}) =>
      Mark._(_cross, size: size, colour: colour, weight: 1.2, seed: seed);

  /// A tick: two strokes, the second longer than the first, the way anyone strikes a list.
  factory Mark.tick({double size = 18, Color colour = Pen.graphite, int seed = 19}) =>
      Mark._(_tick, size: size, colour: colour, weight: 1.5, seed: seed);

  /// An arrow bent back on itself: the reply mark drawn in a margin.
  factory Mark.turnback({double size = 20, Color colour = Pen.margin, int seed = 13}) =>
      Mark._(_turnback, size: size, colour: colour, weight: 1.2, seed: seed);

  /// A triangle, drawn in three strokes that overshoot at the corners the way a pencil does.
  /// It is what anyone draws beside a recording they want to hear, and the reason it is drawn
  /// rather than set is that a glyph out of an icon font on a sheet of paper is a sticker.
  factory Mark.play({double size = 20, Color colour = Pen.graphite, int seed = 23}) =>
      Mark._(_play, size: size, colour: colour, weight: 1.4, seed: seed);

  /// Two bars, pressed the way a pencil is when a hand stops: harder in the middle of the stroke.
  factory Mark.hold({double size = 20, Color colour = Pen.graphite, int seed = 29}) =>
      Mark._(_hold, size: size, colour: colour, weight: 1.6, seed: seed);

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _MarkPainter(_draw, colour, weight, seed));
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.draw, this.colour, this.weight, this.seed);
  final void Function(Canvas, Size, _Hand) draw;
  final Color colour;
  final double weight;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) => draw(canvas, size, _Hand(canvas, colour, weight, seed));

  @override
  bool shouldRepaint(_MarkPainter old) => old.colour != colour || old.weight != weight || old.seed != seed;
}

/// A hand holding a pen: it never draws a mathematically straight line, and it presses harder in
/// the middle of a stroke than at either end.
class _Hand {
  _Hand(this.canvas, this.colour, this.weight, int seed) : _rng = math.Random(seed);
  final Canvas canvas;
  final Color colour;
  final double weight;
  final math.Random _rng;

  double _wobble(double amount) => (_rng.nextDouble() - 0.5) * amount;

  /// Draw through [points] as a wobbling stroke whose width swells in the middle.
  void stroke(List<Offset> points, {double wobble = 0.6, bool close = false, double taper = 0.45}) {
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
          ..color = colour.withValues(alpha: colour.a * (0.72 + 0.28 * swell))
          ..strokeWidth = weight * (0.7 + 0.6 * swell)
          ..strokeCap = StrokeCap.round,
      );
    }
    if (close) {
      canvas.drawLine(
        pts.last,
        pts.first,
        Paint()
          ..color = colour
          ..strokeWidth = weight * 0.8
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  /// A stroke sampled off a path, so a curve is drawn rather than approximated by hand.
  void along(Path path, {int steps = 40, double wobble = 0.6, double taper = 0.45}) {
    final metrics = path.computeMetrics().toList();
    for (final m in metrics) {
      final pts = <Offset>[];
      for (var i = 0; i <= steps; i++) {
        final tan = m.getTangentForOffset(m.length * i / steps);
        if (tan != null) pts.add(tan.position);
      }
      stroke(pts, wobble: wobble, taper: taper);
    }
  }
}

void _clip(Canvas canvas, Size size, _Hand hand) {
  final w = size.width, h = size.height;
  final path = Path()
    ..moveTo(w * 0.34, h * 0.14)
    ..lineTo(w * 0.34, h * 0.74)
    ..arcToPoint(Offset(w * 0.62, h * 0.74), radius: ui.Radius.circular(w * 0.15))
    ..lineTo(w * 0.62, h * 0.26)
    ..arcToPoint(Offset(w * 0.46, h * 0.26), radius: ui.Radius.circular(w * 0.09), clockwise: false)
    ..lineTo(w * 0.46, h * 0.80);
  hand.along(path, steps: 56, wobble: 0.45);
}

void _ticks(Canvas canvas, Size size, _Hand hand, double level) {
  final w = size.width, h = size.height;
  const heights = [0.42, 0.74, 0.30];
  for (var i = 0; i < 3; i++) {
    final x = w * (0.30 + i * 0.20);
    final grow = 1 + level * (0.35 + i * 0.12);
    final half = h * heights[i] * 0.5 * grow.clamp(1.0, 1.6);
    hand.stroke([Offset(x, h * 0.5 - half), Offset(x, h * 0.5 + half)], wobble: 0.35, taper: 0.2);
  }
}

void _loop(Canvas canvas, Size size, _Hand hand) {
  final w = size.width, h = size.height;
  final pts = <Offset>[];
  for (var i = 0; i <= 44; i++) {
    final a = -math.pi * 0.65 + i / 44 * math.pi * 2.05;
    pts.add(Offset(w * 0.44 + w * 0.30 * math.cos(a), h * 0.44 + h * 0.30 * math.sin(a)));
  }
  hand.stroke(pts, wobble: 0.5, taper: 0.3);
  hand.stroke([Offset(w * 0.66, h * 0.68), Offset(w * 0.92, h * 0.94)], wobble: 0.4);
}

void _cross(Canvas canvas, Size size, _Hand hand) {
  final w = size.width, h = size.height;
  hand.stroke([Offset(w * 0.22, h * 0.24), Offset(w * 0.78, h * 0.78)], wobble: 0.5);
  hand.stroke([Offset(w * 0.78, h * 0.22), Offset(w * 0.22, h * 0.80)], wobble: 0.5);
}

void _tick(Canvas canvas, Size size, _Hand hand) {
  final w = size.width, h = size.height;
  hand.stroke([Offset(w * 0.16, h * 0.52), Offset(w * 0.40, h * 0.80)], wobble: 0.4, taper: 0.3);
  hand.stroke([Offset(w * 0.40, h * 0.80), Offset(w * 0.88, h * 0.18)], wobble: 0.5, taper: 0.4);
}

void _turnback(Canvas canvas, Size size, _Hand hand) {
  final w = size.width, h = size.height;
  final path = Path()
    ..moveTo(w * 0.86, h * 0.24)
    ..cubicTo(w * 0.86, h * 0.72, w * 0.52, h * 0.74, w * 0.20, h * 0.72);
  hand.along(path, steps: 36, wobble: 0.4);
  hand.stroke([Offset(w * 0.36, h * 0.54), Offset(w * 0.18, h * 0.72), Offset(w * 0.38, h * 0.88)], wobble: 0.4);
}

void _play(Canvas canvas, Size size, _Hand hand) {
  final w = size.width, h = size.height;
  // Each side is its own stroke and each one runs a little past the corner, because a hand
  // lifting off a corner leaves the overshoot behind. A closed path would not have them.
  final a = Offset(w * 0.28, h * 0.16);
  final b = Offset(w * 0.84, h * 0.50);
  final c = Offset(w * 0.28, h * 0.84);
  hand.stroke([a, Offset(w * 0.86, h * 0.52)], wobble: 0.45, taper: 0.35);
  hand.stroke([b, Offset(w * 0.26, h * 0.86)], wobble: 0.45, taper: 0.35);
  hand.stroke([c, Offset(w * 0.29, h * 0.13)], wobble: 0.5, taper: 0.3);
}

void _hold(Canvas canvas, Size size, _Hand hand) {
  final w = size.width, h = size.height;
  hand.stroke([Offset(w * 0.36, h * 0.18), Offset(w * 0.34, h * 0.82)], wobble: 0.4, taper: 0.25);
  hand.stroke([Offset(w * 0.64, h * 0.17), Offset(w * 0.66, h * 0.83)], wobble: 0.4, taper: 0.25);
}

/// A line ruled by hand: what a composer sits on, and what separates two things on a page.
class RuleLine extends StatelessWidget {
  const RuleLine({super.key, this.colour = Pen.margin, this.weight = 1.0, this.seed = 17, this.height = 3});
  final Color colour;
  final double weight;
  final int seed;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _RulePainter(colour, weight, seed)),
      );
}

class _RulePainter extends CustomPainter {
  _RulePainter(this.colour, this.weight, this.seed);
  final Color colour;
  final double weight;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final hand = _Hand(canvas, colour, weight, seed);
    final y = size.height * 0.5;
    final steps = math.max(6, size.width ~/ 18);
    hand.stroke([for (var i = 0; i <= steps; i++) Offset(size.width * i / steps, y)], wobble: 0.7, taper: 0.25);
  }

  @override
  bool shouldRepaint(_RulePainter old) => old.colour != colour || old.seed != seed;
}
