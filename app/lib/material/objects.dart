// A feeling is an object on the desk: the render, over its own baked contact shadow, at the size
// the intensity asks for. Never an icon, never a glyph.
import 'package:flutter/material.dart';

import '../feelings/builtins.dart';
import '../feelings/drawn.dart';
import 'library.dart';
import 'light.dart';

class FeelingObject extends StatelessWidget {
  const FeelingObject({
    super.key,
    required this.feeling,
    this.size = 84,
    this.intensity = 0.7,
    this.tilt = 0.0,
    this.shadowScale = 1.0,
    this.lift = 0.0,
  });

  final Feeling feeling;
  final double size;

  /// 0..1: scales the object a little and the drop of its landing (docs/FEELINGS.md).
  final double intensity;
  final double tilt;

  /// While an object is still falling its shadow is smaller and lighter.
  final double shadowScale;

  /// How far the object itself is off the desk, in object-heights. The shadow does not move with
  /// it: that gap between a thing and its shadow is the only thing that says it is in the air.
  final double lift;

  @override
  Widget build(BuildContext context) {
    final dusk = Light.of(context) == LightCondition.dusk;
    final scale = 0.88 + 0.24 * intensity.clamp(0.0, 1.0);
    final id = feeling.object;

    // Some feelings are not things. A sun scribbled at the top of a page, a moon on the corner,
    // rain, a tongue stuck out — those are marks somebody made, and rendering them as objects
    // would give a thing with no thickness some. They are drawn, in the same hand as everything
    // else the app draws (feelings/drawn.dart).
    if (DrawnFeelingMark.has(id)) {
      return SizedBox(
        width: size,
        height: size,
        child: Transform.rotate(
          angle: tilt,
          child: Transform.scale(
            scale: scale,
            child: DrawnFeelingMark(
              object: id,
              colour: Color(int.parse(feeling.colour.substring(1), radix: 16) | 0xFF000000),
              size: size,
              seed: feeling.id.hashCode,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: Transform.rotate(
        angle: tilt,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: (0.75 * shadowScale).clamp(0.0, 1.0),
              child: Transform.scale(
                scale: scale * (0.86 + 0.14 * shadowScale),
                child: Image.asset(objectAsset('${id}_shadow${dusk ? '_dusk' : ''}'),
                    fit: BoxFit.contain, gaplessPlayback: true, errorBuilder: _none),
              ),
            ),
            Transform.translate(
              offset: Offset(lift * size * 0.16, -lift * size * 0.62),
              child: Transform.scale(
                scale: scale,
                child: Image.asset(objectAsset(id),
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (c, e, s) => _Fallback(feeling: feeling)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _none(BuildContext c, Object e, StackTrace? s) => const SizedBox.shrink();
}

/// Before the library is baked, a feeling still has to be a mark rather than a blank: a scribble
/// in its own colour, drawn by hand. Never a system glyph.
class _Fallback extends StatelessWidget {
  const _Fallback({required this.feeling});
  final Feeling feeling;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _ScribblePainter(feeling));
}

class _ScribblePainter extends CustomPainter {
  _ScribblePainter(this.feeling);
  final Feeling feeling;

  @override
  void paint(Canvas canvas, Size size) {
    final colour = Color(int.parse(feeling.colour.substring(1), radix: 16) | 0xFF000000);
    final paint = Paint()
      ..color = colour
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width * 0.045;
    final path = Path();
    final seed = feeling.id.codeUnits.fold<int>(7, (a, b) => (a * 31 + b) & 0xFFFF);
    final n = 3 + seed % 3;
    for (var i = 0; i <= n; i++) {
      final t = i / n;
      final x = size.width * (0.2 + 0.6 * t);
      final y = size.height * (0.32 + 0.36 * (((seed >> (i * 2)) & 3) / 3.0));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.quadraticBezierTo(x - size.width * 0.12, y + size.height * 0.1, x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ScribblePainter old) => old.feeling.id != feeling.id;
}
