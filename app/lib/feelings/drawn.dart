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
import '../material/ink.dart';

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

  /// A hand's line between two points it meant to join.
  ///
  /// It drifts; it does not jitter. The wobble used to be one random offset applied to each point
  /// the shape names, so `obj_window` — six strokes of two points each — came out as six dead
  /// straight bars of uniform width, and at three hundred per cent on the chat hero it read as
  /// vector art laid on the paper rather than as something somebody drew. A stroke is walked at
  /// about a pen's width a step now, with two slow terms across its length: the line leaves where
  /// it was aimed and comes back, the way a line drawn without a ruler does.
  List<Offset> _walk(List<Offset> points, double wobble) {
    final step = math.max(2.0, weight * 2.2);
    final out = <Offset>[];
    // one drift per stroke, so a line bows rather than shivering
    final k1 = 0.6 + _rng.nextDouble() * 1.9;
    final k2 = 2.1 + _rng.nextDouble() * 3.4;
    final p1 = _rng.nextDouble() * _tau;
    final p2 = _rng.nextDouble() * _tau;
    // How far the line leaves its aim, as a fraction of the *mark*: a person drawing a square
    // freehand wanders a couple of per cent of it whatever size they draw it, and the first two
    // attempts at this were tied to the pen instead — 0.13 per cent of the mark at one size and
    // 3.2 per cent at another, so the same window was a ruler on one screen and a scrawl on the
    // next. The hand's weight is the mark's width over forty-four, so this recovers the width.
    final amp = wobble * (weight * 44.0) * 0.021;
    var walked = 0.0;
    final total = () {
      var d = 0.0;
      for (var i = 0; i < points.length - 1; i++) {
        d += (points[i + 1] - points[i]).distance;
      }
      return d;
    }();
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i], b = points[i + 1];
      final len = (b - a).distance;
      if (len < 1e-6) continue;
      final n = math.max(1, (len / step).ceil());
      final normal = Offset(-(b.dy - a.dy) / len, (b.dx - a.dx) / len);
      for (var j = 0; j < n; j++) {
        final t = j / n;
        final at = Offset.lerp(a, b, t)!;
        final u = total <= 0 ? 0.0 : (walked + len * t) / total;
        // ends are pinned: a person hits the corner they were aiming for
        final ease = math.sin(u * math.pi);
        final off = amp * ease *
            (math.sin(u * _tau * k1 + p1) * 0.65 + math.sin(u * _tau * k2 + p2) * 0.35);
        out.add(at + normal * off);
      }
      walked += len;
    }
    out.add(points.last);
    return out;
  }

  void stroke(List<Offset> points, {double wobble = 0.7, double taper = 0.4, double width = 1.0}) {
    if (points.length < 2) return;
    final pts = _walk(points, wobble);
    final n = pts.length - 1;
    for (var i = 0; i < n; i++) {
      final t = n == 1 ? 0.5 : i / (n - 1);
      final swell = 1 - taper * (2 * t - 1).abs();
      final w = weight * width * (0.62 + 0.76 * swell);
      // Opaque, and the pressure is in the width and in the plate.
      //
      // Each segment used to be laid down at 0.7 to 1.0 alpha, which was survivable while a stroke
      // was two points and became a string of beads the moment a stroke was walked: every junction
      // between two segments is two round caps over each other, and 0.7 over 0.7 is 0.91. On the
      // chat hero the drawn window came out as a dotted line. A ballpoint does not vary its
      // opacity — it varies its width, it skips, and its ink has a texture, which is what the
      // plate is for. The mark's own weight is applied once, by the layer this is drawn into.
      final tone = colour.withValues(alpha: 1.0);
      // The pen's own coverage, the same plate the handwriting is drawn through. These marks were
      // flat colour while every built-in object beside them was a photograph of a thing, and an
      // emotional critic said so: "a drawn mark on a torn card, while all thirty-six built-ins are
      // rendered objects". A mark somebody made is allowed to look like a mark. It is not allowed
      // to look like a vector.
      // Solid. The pen's coverage goes over the whole mark once, in _DrawnPainter — see inkMask.
      canvas.drawLine(
          pts[i],
          pts[i + 1],
          Paint()
            ..color = tone
            ..strokeWidth = w
            ..strokeCap = StrokeCap.round);
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
  void paint(Canvas canvas, Size s) {
    // The whole mark into one layer, and composited once.
    //
    // Ink does not get darker where a line crosses another line, and it does not get darker
    // between one segment of a stroke and the next — but every segment here is drawn under the
    // pen's own coverage at less than full alpha, so both were happening: the crossings of
    // `obj_window` came out visibly darker than its bars, which is what six translucent
    // rectangles laid over each other looks like and is not what a pen does.
    canvas.saveLayer(
        Offset.zero & s, Paint()..color = const Color(0xFF000000).withValues(alpha: colour.a));
    draw(canvas, s, DrawingHand(canvas, colour.withValues(alpha: 1.0),
        math.max(1.0, s.width / 44), seed + 7));
    // The pen's own coverage, punched into the finished mark rather than carried by every stroke
    // that makes it. A stroke drawn through the plate is drawn at the plate's alpha — 0.81 on
    // average — so every junction inside a walked stroke was 0.81 over 0.81, and the drawn window
    // on the chat hero came out beaded like a dotted line. Once, over the lot.
    final mask = inkMask('ballpoint');
    if (mask != null) canvas.drawRect(Offset.zero & s, mask);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DrawnPainter old) => old.colour != colour || old.seed != seed;
}
