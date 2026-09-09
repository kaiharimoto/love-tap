// The feeling corner: a folded corner at the bottom right of every region.
//
// One gesture from anywhere. Hold the corner and it curls up; the vocabulary fans out across the
// desk as objects, not as a grid of icons; drag onto one and let go, and it slides off the desk
// toward the other phone. How long you held it is how hard it arrives.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../capture/bus.dart';
import '../capture/hooks.dart';
import '../flags.dart';
import '../material/hands.dart';
import '../material/motion.dart';
import '../material/objects.dart';
import '../material/palette.dart';
import '../material/slip.dart';
import 'builtins.dart';
import 'registry.dart';

class FeelingCorner extends StatefulWidget {
  const FeelingCorner({super.key, required this.registry, required this.onSend, this.onPreview});

  final FeelingRegistry registry;

  /// Called with the feeling and the intensity the hold produced.
  final void Function(Feeling feeling, double intensity) onSend;

  /// Called while a feeling is under the thumb, so the sender can play it locally.
  final void Function(Feeling feeling, double intensity)? onPreview;

  @override
  State<FeelingCorner> createState() => _FeelingCornerState();
}

class _FeelingCornerState extends State<FeelingCorner> with SingleTickerProviderStateMixin {
  late final AnimationController _curl = AnimationController(
    vsync: this,
    duration: Motion.turn,
    reverseDuration: Motion.settle,
  );
  bool _open = false;
  DateTime? _heldSince;
  Feeling? _under;
  Family _family = Family.warmth;

  double get _intensity {
    final since = _heldSince;
    if (since == null) return 0.5;
    final ms = DateTime.now().difference(since).inMilliseconds;
    // 0.2 s -> 0.3, 2 s -> 1.0 (docs/FEELINGS.md)
    return (0.3 + (ms - 200) / 1800 * 0.7).clamp(0.25, 1.0);
  }

  void _openSender() {
    setState(() {
      _open = true;
      _heldSince = DateTime.now();
    });
    if (DrivenClock.enabled) {
      _curlFrom = DrivenClock.now;
      _curl.value = 0.0;
    } else {
      _curl.forward();
    }
  }

  /// The feeling under a finger, wherever on the screen it is.
  ///
  /// The tiles are drawn by the sheet and the drag is owned by the corner, so the corner cannot
  /// ask its own children what is under the thumb — it asks the view. Each tile carries itself as
  /// metadata, which is what a hit test returns along the way.
  Feeling? _feelingAt(Offset global) {
    final view = View.maybeOf(context);
    if (view == null) return null;
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(result, global, view.viewId);
    for (final entry in result.path) {
      final target = entry.target;
      if (target is RenderMetaData && target.metaData is Feeling) {
        return target.metaData as Feeling;
      }
    }
    return null;
  }

  void _close({Feeling? send}) {
    final intensity = _intensity;
    setState(() {
      _open = false;
      _under = null;
      _heldSince = null;
    });
    if (DrivenClock.enabled) {
      _curlFrom = DrivenClock.now;
      _curl.value = 1.0;
    } else {
      _curl.reverse();
    }
    if (send != null) widget.onSend(send, intensity);
  }

  StreamSubscription<Duration>? _driven;
  Duration? _curlFrom;

  @override
  void initState() {
    super.initState();
    if (Flags.capture) {
      CaptureBus.openCorner = (open) => open ? _openSender() : _close();
      CaptureBus.showFamily = (name) {
        final want = Family.values.firstWhere(
            (f) => f.label.toLowerCase() == name.toLowerCase() || f.name.toLowerCase() == name.toLowerCase(),
            orElse: () => _family);
        setState(() => _family = want);
        return widget.registry.all.where((f) => f.family == want).length;
      };
      // A corner turning up takes a quarter of a second, and under the capture harness a quarter
      // of a second of wall clock passes between the first two frames of a take — so the whole
      // turn happened before the second one was grabbed, and ninety-four of ninety-five frames
      // were identical. The clock the harness drives is the one the corner has to turn on.
      _driven = DrivenClock.ticks.listen(_onDriven);
    }
  }

  void _onDriven(Duration now) {
    final from = _curlFrom;
    if (from == null) return;
    final span = _open ? Motion.turn : Motion.settle;
    final t = ((now - from).inMicroseconds / span.inMicroseconds).clamp(0.0, 1.0);
    _curl.value = _open ? t : 1.0 - t;
    if (t >= 1.0) _curlFrom = null;
  }

  @override
  void dispose() {
    if (Flags.capture) {
      CaptureBus.openCorner = null;
      CaptureBus.showFamily = null;
    }
    _driven?.cancel();
    _curl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(animation: _curl, builder: (context, _) => _stack(context));
  }

  Widget _stack(BuildContext context) {
    return Stack(
      children: [
        // The palette comes and goes with the corner rather than instead of it. Taken out in one
        // frame it was a jump in the light — a fifth of the brightness of the whole screen gone
        // between two frames, which is what a cut looks like — and in the app it was a page that
        // blinked. _curl is the corner's own turn, so the two are the same movement.
        if (_open || _curl.value > 0.01)
          Positioned.fill(
            key: const ValueKey('the.vocabulary'),
            // The sheet is pulled out from under the corner, not faded up. Paper does not fade:
            // while this was an Opacity the thread underneath read straight through the
            // vocabulary — the ink of the notes below colliding with the names of the feelings —
            // which is the translucent drawer the material language is written against. The
            // scrim still fades, because a scrim is light and not a thing.
            child: FractionalTranslation(
              translation: Offset(0, (1.0 - _curl.value.clamp(0.0, 1.0)) * 0.92),
              child: _Fan(
                registry: widget.registry,
                family: _family,
                onFamily: (f) => setState(() => _family = f),
                onHover: (f) {
                  if (f != _under) {
                    setState(() => _under = f);
                    if (f != null) widget.onPreview?.call(f, _intensity);
                  }
                },
                onPick: (f) => _close(send: f),
                onDismiss: () => _close(),
                under: _under,
                intensity: _intensity,
                scrim: _curl.value.clamp(0.0, 1.0),
              ),
            ),
          ),
        // Keyed, both of them. A Stack's children are matched by position when they have no
        // keys, and the sheet appears *before* the corner in the list — so opening it moved the
        // corner from the first child to the second, Flutter tore its element down and built a
        // new one, and the gesture recogniser holding the press went with it. The corner opened
        // and then heard nothing more from the thumb that opened it, which is exactly the drag
        // this is for.
        Positioned(
          key: const ValueKey('the.corner'),
          right: 0,
          bottom: 0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _open ? () => _close() : _openSender,
            // One gesture, from any region: press the corner, the sheet comes up under your
            // thumb, drag onto a feeling and let go. It was three taps — the corner, a family,
            // the tile — and the row asks for a feeling reachable in one gesture from anywhere.
            // The hold is already the intensity, so the thing that decides how hard it lands is
            // the same movement that chooses it. Tapping still works for anyone who would rather.
            onLongPressStart: (_) => _openSender(),
            onLongPressMoveUpdate: (d) {
              if (!_open) return;
              final f = _feelingAt(d.globalPosition);
              if (f?.id != _under?.id) {
                setState(() => _under = f);
                if (f != null) widget.onPreview?.call(f, _intensity);
              }
            },
            onLongPressEnd: (d) {
              if (!_open) return;
              final f = _feelingAt(d.globalPosition);
              if (f != null) _close(send: f);
            },
            child: AnimatedBuilder(
              animation: _curl,
              builder: (context, _) =>
                  CustomPaint(size: const Size(74, 74), painter: _CornerPainter(_curl.value)),
            ),
          ),
        ),
      ],
    );
  }
}

/// The corner of the desk's top sheet, turned up. Drawn rather than rendered because it follows
/// the finger; the fold sequence in assets/folds/corner_curl is used for the resting state.
class _CornerPainter extends CustomPainter {
  _CornerPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    // At rest the turned-up corner was 35 per cent of its box — twenty-six logical pixels of
    // triangle, which an emotional critic measured at 3.5 grey levels of contrast against the
    // sheet it lies on and could not find at all over the viewer's dark ground (93.3 inside its
    // own footprint against 96.0 just outside). It is the one gesture the whole emotional layer
    // is reached by; it has to be visible on both grounds.
    final curl = 0.5 + 0.5 * t;
    final w = size.width * curl;
    final h = size.height * curl;
    // The two sides of one sheet: the back of the paper, which is where the light is not, and the
    // face of it where the corner has turned over far enough to show again.
    final under = Paint()..color = Paper.underside;
    final face = Paint()..color = Paper.forStock('looseleaf');
    final shade = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomRight,
        end: Alignment.topLeft,
        colors: [Colors.black.withValues(alpha: 0.16), Colors.black.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(size.width - w, size.height - h, w, h));
    final path = Path()
      ..moveTo(size.width, size.height)
      ..lineTo(size.width - w, size.height)
      ..lineTo(size.width, size.height - h)
      ..close();
    canvas.drawPath(path, under);
    canvas.drawPath(path, shade);
    // The crease, and a lit edge just inside it. The dark line alone disappears against anything
    // dark — a photograph open in the viewer, the desk at dusk — and the pale one alone disappears
    // against paper. Together the fold has an edge on any ground, which is what a real fold has:
    // one side of it is in the light.
    canvas.drawLine(
      Offset(size.width - w, size.height),
      Offset(size.width, size.height - h),
      Paint()
        ..color = Pen.margin.withValues(alpha: 0.35)
        ..strokeWidth = 1.0,
    );
    canvas.drawLine(
      Offset(size.width - w + 1.4, size.height),
      Offset(size.width, size.height - h + 1.4),
      Paint()
        ..color = const Color(0xFFF6F1E6).withValues(alpha: 0.55)
        ..strokeWidth = 1.2,
    );
    if (t > 0.05) {
      final lift = Path()
        ..moveTo(size.width - w, size.height)
        ..quadraticBezierTo(size.width - w * 0.5, size.height - h * 0.5 - 8 * t, size.width, size.height - h)
        ..lineTo(size.width, size.height)
        ..close();
      canvas.drawPath(lift, face);
    }
  }

  @override
  bool shouldRepaint(_CornerPainter old) => old.t != t;
}

/// The vocabulary fanned across the desk, by family. Objects, never a grid of icons.
class _Fan extends StatelessWidget {
  const _Fan({
    required this.registry,
    required this.family,
    required this.onFamily,
    required this.onHover,
    required this.onPick,
    required this.onDismiss,
    required this.under,
    required this.intensity,
    required this.scrim,
  });

  final FeelingRegistry registry;
  final Family family;
  final ValueChanged<Family> onFamily;
  final ValueChanged<Feeling?> onHover;
  final ValueChanged<Feeling> onPick;
  final VoidCallback onDismiss;
  final Feeling? under;
  final double intensity;

  /// How far out the sheet is, 0 to 1. The scrim comes up with it; the sheet itself does not
  /// fade, it moves.
  final double scrim;

  @override
  Widget build(BuildContext context) {
    final members = registry.family(family);
    final width = MediaQuery.sizeOf(context).width;
    return GestureDetector(
      onTap: onDismiss,
      child: DecoratedBox(
        // A light scrim, even from top to bottom, so the page underneath is dimmed but still where
        // you were. It used to be a wash that went to eighty-four per cent at the bottom with the
        // vocabulary printed straight on it: the names sat over whatever the region had drawn
        // there, at under two to one against the wood, and half the tiles came out on one side of
        // the wash and half on the other. The vocabulary is on paper now — a sheet pulled up from
        // under the corner — and paper is opaque.
        decoration: BoxDecoration(color: Color(0x46120D08).withValues(alpha: 0.27 * scrim)),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(5, 0, 5, 66),
                child: Slip(
                  id: 'the.vocabulary.sheet',
                  row: 3,
                  stock: 'looseleaf',
                  width: width - 10,
                  padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // every family, on its own card, all of them on the sheet at once: the strip
                      // this replaced scrolled sideways with nothing to say so, and two of the
                      // six were off the edge of every frame anyone took
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 2,
                        runSpacing: 2,
                        children: [
                          for (final f in Family.values)
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => onFamily(f),
                              child: Padding(
                                padding: const EdgeInsets.all(3),
                                // as wide as its word: a slip given no width takes all the
                                // width a Wrap offers, and six of them stacked into six bars
                                // the height of the sheet with no room under them for a tile
                                child: IntrinsicWidth(
                                  child: Slip(
                                    id: 'family_${f.name}',
                                    stock: 'index',
                                    torn: false,
                                    // room for the stamp's letter-spacing, which the intrinsic
                                    // width undercounts: SHELTER came out as SHELTE
                                    padding: const EdgeInsets.fromLTRB(11, 5, 16, 5),
                                    child: Stamped(
                                      f.label,
                                      size: f == family ? 12 : 10.5,
                                      colour: f == family ? Pen.stamp : Pen.margin,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Turning to another family draws it across, the way a hand moves a sheet
                      // rather than swapping it. It also means the clip of somebody going through
                      // the vocabulary has motion in it: a family that changed on one frame and
                      // then sat there gave the frame check nineteen identical grabs in a row, and
                      // the vocabulary was in the evidence for a fifth of a second.
                      Settling(
                        key: ValueKey('fan.${family.name}'),
                        duration: Motion.turn,
                        curve: Curves.easeOutCubic,
                        builder: (_, t, child) => ClipRect(
                          child: FractionalTranslation(
                            translation: Offset(0.10 * (1 - t), 0),
                            child: Opacity(opacity: (0.35 + 0.65 * t).clamp(0.0, 1.0), child: child),
                          ),
                        ),
                        child: Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          for (var i = 0; i < members.length; i++)
                            MetaData(
                              // what this tile is, so a thumb dragged out of the corner and over
                              // it can be told what it is on without the corner knowing anything
                              // about how the sheet lays itself out
                              metaData: members[i],
                              behavior: HitTestBehavior.opaque,
                              child: GestureDetector(
                              // the whole tile takes the tap. A detector that defers to its
                              // child only hears a tap the child claims, and an object drawn
                              // with a painter claims nothing: a drawn feeling could only be
                              // picked by tapping its name
                              behavior: HitTestBehavior.opaque,
                              onTapDown: (_) => onHover(members[i]),
                              onTap: () => onPick(members[i]),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(4, 4, 4, 2),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    FeelingObject(
                                      feeling: members[i],
                                      size: under?.id == members[i].id ? 92 : 76,
                                      intensity: under?.id == members[i].id ? intensity : 0.6,
                                      tilt: math.sin(i * 1.7) * 0.09,
                                    ),
                                    SizedBox(
                                      width: 96,
                                      // the whole name, on paper, in pencil: 'thinking of y…' is
                                      // not a feeling anyone can choose
                                      child: Text(
                                        members[i].name,
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        style: Hands.margin(size: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            ),
                        ],
                      ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
