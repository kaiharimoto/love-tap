// The feeling corner: a folded corner at the bottom right of every region.
//
// One gesture from anywhere. Hold the corner and it curls up; the vocabulary fans out across the
// desk as objects, not as a grid of icons; drag onto one and let go, and it slides off the desk
// toward the other phone. How long you held it is how hard it arrives.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../capture/bus.dart';
import '../flags.dart';
import '../material/hands.dart';
import '../material/motion.dart';
import '../material/objects.dart';
import '../material/palette.dart';
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
  late final AnimationController _curl =
      AnimationController(vsync: this, duration: Motion.turn, reverseDuration: Motion.settle);
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
    _curl.forward();
  }

  void _close({Feeling? send}) {
    final intensity = _intensity;
    setState(() {
      _open = false;
      _under = null;
      _heldSince = null;
    });
    _curl.reverse();
    if (send != null) widget.onSend(send, intensity);
  }

  @override
  void initState() {
    super.initState();
    if (Flags.capture) CaptureBus.openCorner = (open) => open ? _openSender() : _close();
  }

  @override
  void dispose() {
    if (Flags.capture) CaptureBus.openCorner = null;
    _curl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (_open) Positioned.fill(child: _Fan(
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
        )),
        Positioned(
          right: 0,
          bottom: 0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _open ? () => _close() : _openSender,
            onLongPressStart: (_) => _openSender(),
            child: AnimatedBuilder(
              animation: _curl,
              builder: (context, _) => CustomPaint(
                size: const Size(74, 74),
                painter: _CornerPainter(_curl.value),
              ),
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
    final curl = 0.35 + 0.65 * t;
    final w = size.width * curl;
    final h = size.height * curl;
    final under = Paint()..color = const Color(0xFFE7E0CE);
    final face = Paint()..color = const Color(0xFFF1ECDF);
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
    // the crease
    canvas.drawLine(
      Offset(size.width - w, size.height),
      Offset(size.width, size.height - h),
      Paint()
        ..color = Pen.margin.withValues(alpha: 0.35)
        ..strokeWidth = 1.0,
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
  });

  final FeelingRegistry registry;
  final Family family;
  final ValueChanged<Family> onFamily;
  final ValueChanged<Feeling?> onHover;
  final ValueChanged<Feeling> onPick;
  final VoidCallback onDismiss;
  final Feeling? under;
  final double intensity;

  @override
  Widget build(BuildContext context) {
    final members = registry.family(family);
    return GestureDetector(
      onTap: onDismiss,
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.18),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final f in Family.values)
                        Padding(
                          padding: const EdgeInsets.all(4),
                          child: GestureDetector(
                            onTap: () => onFamily(f),
                            child: Opacity(
                              opacity: f == family ? 1.0 : 0.6,
                              child: Stamped(f.label, size: f == family ? 13 : 11),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(8, 6, 8, 84),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    for (var i = 0; i < members.length; i++)
                      GestureDetector(
                        onTapDown: (_) => onHover(members[i]),
                        onTap: () => onPick(members[i]),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FeelingObject(
                                feeling: members[i],
                                size: under?.id == members[i].id ? 96 : 78,
                                intensity: under?.id == members[i].id ? intensity : 0.6,
                                tilt: math.sin(i * 1.7) * 0.09,
                              ),
                              SizedBox(
                                width: 92,
                                child: Text(
                                  members[i].name,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Hands.margin(size: 12),
                                ),
                              ),
                            ],
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
    );
  }
}
