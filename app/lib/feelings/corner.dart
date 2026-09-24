// The feeling corner: a folded corner at the bottom right of every region.
//
// One gesture from anywhere. Hold the corner and it curls up; the vocabulary fans out across the
// desk as objects, not as a grid of icons; drag onto one and let go, and it slides off the desk
// toward the other phone. How long you held it is how hard it arrives.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../capture/bus.dart';
import '../capture/hooks.dart';
import '../flags.dart';
import '../material/assignment.dart';
import '../material/hands.dart';
import '../material/library.dart';
import '../material/motion.dart';
import '../material/objects.dart';
import '../material/palette.dart';
import '../material/paper.dart';
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
    if (Flags.capture) CaptureBus.openCorner = null;
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
            child: Opacity(
              opacity: _curl.value.clamp(0.0, 1.0),
              child: _Fan(
                registry: widget.registry,
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
              ),
            ),
          ),
        Positioned(
          right: 0,
          bottom: 0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _open ? () => _close() : _openSender,
            onLongPressStart: (_) => _openSender(),
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
    final curl = 0.35 + 0.65 * t;
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

/// The vocabulary, laid out on a sheet of paper by family. Objects, never a grid of icons.
///
/// **A sheet, not a scrim, and every family with its objects on it.** Until firing 59 this was a
/// gradient of 18% to 84% black over the page, with the six family names on tabs and only the
/// selected family's objects under them. The cycle 3 emotional_transmission critic found it
/// blocking twice in 07_feeling_landing: the partner card -- `room smells right again`, MOOD,
/// HERE, PLACE -- read through it, and five of the six families were empty torn tabs with a
/// name on them. A tinted overlay is also the one thing DIRECTION.md's `nothing is drawn as
/// alpha` rules out. So the vocabulary is written on an opaque sheet laid over the page, and
/// each family is a row: its tab, and beside it every object in it, so every feeling is one tap
/// from the moment the corner turns up.
class _Fan extends StatelessWidget {
  const _Fan({
    required this.registry,
    required this.onHover,
    required this.onPick,
    required this.onDismiss,
    required this.under,
    required this.intensity,
  });

  final FeelingRegistry registry;
  final ValueChanged<Feeling?> onHover;
  final ValueChanged<Feeling> onPick;
  final VoidCallback onDismiss;
  final Feeling? under;
  final double intensity;

  /// The tabs lane row of a family's tab: past the three moments uses for its views, because the
  /// corner comes up over moments too.
  static int _tabRow(Family f) => 7 + f.index;

  /// The width of a family's tab, so the objects of every family start at one line.
  static const double _tabWidth = 76;

  @override
  Widget build(BuildContext context) {
    final lib = MaterialLibrary.loaded ? MaterialLibrary.instance : null;
    final variants = lib?.stockVariants('looseleaf') ?? const <String>[];
    final stock = variants.isEmpty ? (lib?.stockVariants('lined').firstOrNull ?? '') : variants.first;
    // Chosen for its shape rather than by a row: see sheetTearFor. Nothing on the sheet may share
    // it -- the family tabs and the scrap under every object on it.
    final tear = sheetTearFor(lib, avoid: [
      for (final f in Family.values) tearAt(lib, lane: TearLanes.tabs, row: _tabRow(f)) ?? '',
      for (final f in registry.active) scrapFor(lib, f.id) ?? '',
    ]);
    final safe = tear == null || lib == null ? const [0.05, 0.06, 0.05, 0.06] : lib.safeOf(tear);
    const padding = EdgeInsets.fromLTRB(10, 12, 10, 12);
    return GestureDetector(
      onTap: onDismiss,
      child: LayoutBuilder(builder: (context, c) {
        // The piece fills what it is given and lays its writing out at the top of its safe area,
        // so the writing is given the whole inside height and sits at the bottom of it, where the
        // thumb that turned the corner up still is.
        final inside = (c.maxHeight * (1 - safe[1] - safe[3]) - padding.vertical).clamp(0.0, c.maxHeight);
        final across = c.maxWidth * (1 - safe[0] - safe[2]) - padding.horizontal - _tabWidth;
        final item = _itemFor(across, inside - _cornerRoom);
        return PaperPiece(
          id: 'feelings.sheet',
          stockId: stock,
          tearId: tear,
          liftMm: 1.6,
          tilt: 0.004,
          padding: padding,
          safe: safe,
          child: SizedBox(
            height: inside,
            child: SingleChildScrollView(
              reverse: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final f in Family.values) _familyRow(f, item),
                  // the corner itself, which is still under the thumb
                  const SizedBox(height: _cornerRoom),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  /// Room left under the rows for the turned corner, which is still under the thumb.
  static const double _cornerRoom = 40;

  /// The largest width an object and its name can take so that every family fits the sheet at
  /// once, [across] wide beside the tabs and [tall] high. The vocabulary is one tap away only if
  /// it is all on the sheet, and the sheet is a 360x780 phone as often as a 480x1040 one: sized
  /// once for the bigger, the first version of this had Warmth, Ache and Shelter scrolled off the
  /// top of the smaller in 07_feeling_landing.
  double _itemFor(double across, double tall) {
    for (var w = 56.0; w > 34; w -= 2) {
      final perLine = (across / w).floor();
      if (perLine < 1) continue;
      var height = 0.0;
      for (final f in Family.values) {
        final lines = (registry.family(f).length / perLine).ceil().clamp(1, 99);
        height += lines * _rowHeight(w) + 6;
      }
      if (height <= tall) return w;
    }
    return 34;
  }

  /// How tall one line of objects [w] wide is: the object, its name, and the gap under them.
  static double _rowHeight(double w) => (w - 6) + _nameSize(w) * 1.35 + 4;
  static double _nameSize(double w) => (w / 4.6).clamp(9.5, 11.5);

  Widget _familyRow(Family f, double w) {
    final members = registry.family(f);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: _tabWidth,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Slip(
                id: 'family_${f.name}',
                // A row each in the tabs lane, past the three moments uses for its views: the
                // corner comes up over moments too. These all took the overlay row once, which
                // is the sheet's now.
                row: _tabRow(f),
                lane: TearLanes.tabs,
                stock: 'index',
                hug: true,
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                child: Stamped(f.label, size: 9.5, colour: Pen.stamp),
              ),
            ),
          ),
          Expanded(
            child: Wrap(
              children: [
                for (var i = 0; i < members.length; i++)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (_) => onHover(members[i]),
                    onTap: () => onPick(members[i]),
                    child: SizedBox(
                      width: w,
                      height: _rowHeight(w),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: w - 6,
                            height: w - 6,
                            child: OverflowBox(
                              maxWidth: w + 6,
                              maxHeight: w + 6,
                              child: FeelingObject(
                                feeling: members[i],
                                size: under?.id == members[i].id ? w + 4 : w - 6,
                                intensity: under?.id == members[i].id ? intensity : 0.6,
                                tilt: math.sin(i * 1.7) * 0.09,
                              ),
                            ),
                          ),
                          Text(
                            members[i].name,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Hands.margin(size: _nameSize(w)),
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
    );
  }
}
