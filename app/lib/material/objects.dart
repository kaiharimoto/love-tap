// A feeling is an object on the desk: the render, over its own baked contact shadow, at the size
// the intensity asks for. Never an icon, never a glyph.
import 'package:flutter/material.dart';

import '../feelings/builtins.dart';
import '../feelings/drawn.dart';
import 'library.dart';
import 'paper.dart';
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
    this.onPaper = true,
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

  /// Whether a feeling that is a *drawn* mark should be given a scrap of paper to be drawn on.
  ///
  /// True when the mark is standing on the desk beside the rendered objects — six feelings in a
  /// row on the pulse read as four ink drawings floating on bare wood with no shadow between
  /// them and two rendered objects with contact shadows under them, which is two worlds in one
  /// picture. Ink has to be on something.
  ///
  /// False when the mark is already on a piece of paper: a reaction stuck to a note is drawn on
  /// that note, and a second scrap under it would be a sticker.
  final bool onPaper;

  @override
  Widget build(BuildContext context) {
    final dusk = Light.of(context) == LightCondition.dusk;
    final id = feeling.object;
    // `size` is the size of the object, not of the square it was rendered into. A candle fills 27
    // per cent of its frame and a paper crane 85, so before this the same number asked for a
    // candle 29 points tall and a crane 82 — and the small ones read as a smudge beside their own
    // name. tools/pack_assets.py measures each one's ink at pack time.
    final ink = MaterialLibrary.loaded ? MaterialLibrary.instance.inkScaleOf(id) : 1.0;
    // The box is the room the thing needs; how hard it was thrown scales what is drawn inside it.
    // Putting intensity in the box made a landing re-lay-out everything under it — 15 caught it as
    // two light jumps a frame apart, and the frames show the whole of Settings shifting while a
    // feeling arrived. A thing does not take up more room because it was sent harder.
    final box = size * ink;
    final scale = 0.88 + 0.24 * intensity.clamp(0.0, 1.0);

    // Some feelings are not things. A sun scribbled at the top of a page, a moon on the corner,
    // rain, a tongue stuck out — those are marks somebody made, and rendering them as objects
    // would give a thing with no thickness some. They are drawn, in the same hand as everything
    // else the app draws (feelings/drawn.dart).
    if (DrawnFeelingMark.has(id)) {
      final mark = Transform.scale(
        scale: scale,
        child: DrawnFeelingMark(
          object: id,
          colour: Color(int.parse(feeling.colour.substring(1), radix: 16) | 0xFF000000),
          size: size * (onPaper ? 0.72 : 1.0),
          seed: feeling.id.hashCode,
        ),
      );
      if (!onPaper) {
        // the same rule as the rendered objects below: the box is what the drawing needs
        return SizedBox(
          width: box,
          height: box,
          child: Transform.rotate(angle: tilt, child: mark),
        );
      }
      // a scrap, torn off something, with the mark on it — and the scrap's own contact shadow out
      // of the same render as every other piece of paper on the desk
      final lib = MaterialLibrary.loaded ? MaterialLibrary.instance : null;
      final scraps = lib?.scrapTears ?? const <String>[];
      final tear = scraps.isEmpty ? null : scraps[feeling.id.hashCode.abs() % scraps.length];
      return SizedBox(
        width: size,
        height: size,
        child: PaperPiece(
          stockId: lib == null ? 'plain_01' : _scrapStock(lib, feeling.id),
          tearId: tear,
          liftMm: 0.5,
          tilt: tilt,
          width: size,
          padding: EdgeInsets.zero,
          safe: lib == null ? const [0.1, 0.1, 0.1, 0.1] : lib.safeOf(tear ?? ''),
          stockAlignment: Alignment(
            ((feeling.id.hashCode % 100) / 50.0) - 1.0,
            (((feeling.id.hashCode >> 7) % 100) / 50.0) - 1.0,
          ),
          stockScale: 2.4,
          child: Center(child: mark),
        ),
      );
    }

    // The box is the room the drawing actually needs, not the size of the thing drawn in it.
    //
    // For three cycles this was a `size`-wide box with the image scaled up to `size * scale`
    // inside it, and `scale` carries the ink correction — a candle that fills a quarter of its
    // render was drawn nearly three times the width of its own box. Anything that clips its
    // children then cuts the object off, and the paper a feeling arrives on clips: in the thread
    // the candle came out as a grey semicircle with its shadow lying beside it on the wood.
    //
    // A widget that draws outside its box is the bug, so the box grew. `boxFor` is the same
    // arithmetic, public, for a caller that has to reserve the room in a row or a grid. Half the
    // correction went at the source in the same change — tools/pack_assets.py now packs each
    // object and its shadows cropped to the box they share, so the frame is the thing rather than
    // the thing adrift in a square of nothing.
    return SizedBox(
      width: box,
      height: box,
      child: Transform.rotate(
        angle: tilt,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // The shadow in its own frame, which is wider than the object's and off to one side:
            // it falls down and to the right in daylight and the other way off the desk lamp at
            // dusk. Drawn through an OverflowBox so it may reach past the box the object needs —
            // a shadow running off the edge of a sheet is what a shadow does; the thing casting
            // it being cut off at the same edge is what this whole arrangement exists to stop.
            _Shadow(
              id: '${id}_shadow${dusk ? '_dusk' : ''}',
              box: box,
              opacity: (0.75 * shadowScale).clamp(0.0, 1.0),
              scale: scale * (0.86 + 0.14 * shadowScale),
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

  /// The room a [FeelingObject] takes for this feeling at this size — larger than `size` for an
  /// object that sits small in its own render. A row or a grid that has to reserve space asks
  /// here rather than assuming `size`, which is what left the candle cut in half.
  static double boxFor(Feeling feeling, double size) {
    final ink = MaterialLibrary.loaded ? MaterialLibrary.instance.inkScaleOf(feeling.object) : 1.0;
    return size * ink;
  }

  /// The `size` to ask for so the whole drawing fits in [room]. For a fixed row: the object reads
  /// a little smaller rather than being cut off at the edge of the paper.
  static double sizeToFit(Feeling feeling, double room) {
    final ink = MaterialLibrary.loaded ? MaterialLibrary.instance.inkScaleOf(feeling.object) : 1.0;
    return room / ink;
  }

  /// Which stock a scrap is torn from. Scraps come off whatever was to hand, so they are not all
  /// the same paper, but they are all paper the app has actually baked.
  static String _scrapStock(MaterialLibrary lib, String id) {
    final names = lib.stocks;
    if (names.isEmpty) return 'plain_01';
    final variants = lib.stockVariants(names[id.hashCode.abs() % names.length]);
    if (variants.isEmpty) return 'plain_01';
    return variants[(id.hashCode.abs() >> 5) % variants.length];
  }
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


Widget _none(BuildContext c, Object e, StackTrace? s) => const SizedBox.shrink();

/// A baked contact shadow, drawn in the frame it was packed in.
class _Shadow extends StatelessWidget {
  const _Shadow({required this.id, required this.box, required this.opacity, required this.scale});

  final String id;

  /// The object's own box. The shadow's frame is a multiple of it.
  final double box;
  final double opacity;

  /// How firmly the thing is resting: a shadow shrinks a little as something lifts off the desk.
  final double scale;

  @override
  Widget build(BuildContext context) {
    final f = MaterialLibrary.loaded ? MaterialLibrary.instance.objectShadow[id] : null;
    final k = f == null ? 1.0 : f[0];
    final dx = f == null ? 0.0 : f[1];
    final dy = f == null ? 0.0 : f[2];
    return OverflowBox(
      maxWidth: box * k,
      maxHeight: box * k,
      child: Transform.translate(
        offset: Offset(dx * box, dy * box),
        child: Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: Image.asset(objectAsset(id),
                fit: BoxFit.contain, gaplessPlayback: true, errorBuilder: _none),
          ),
        ),
      ),
    );
  }
}
