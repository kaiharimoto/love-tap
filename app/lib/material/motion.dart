// Paper moves like paper: it lifts (its shadow grows), settles (its shadow shrinks), and curls at
// a corner before it turns. Durations are short and the overshoot is small — a note is light.
import 'dart:async';

import 'package:flutter/widgets.dart';

import '../capture/hooks.dart';

class Motion {
  static const lift = Duration(milliseconds: 180);
  static const settle = Duration(milliseconds: 260);
  static const turn = Duration(milliseconds: 320);
  static const land = Duration(milliseconds: 420);
  static const unfold = Duration(seconds: 4);

  /// A sheet dropping onto the desk: quick at first, then the air under it slows it.
  static const drop = Cubic(0.22, 0.9, 0.28, 1.0);

  /// A corner turning over: a little overshoot as the fibres spring.
  static const curl = Cubic(0.34, 1.12, 0.42, 1.0);

  /// A strip sliding off the desk when a note is sent.
  static const slide = Cubic(0.5, 0.0, 0.75, 0.2);
}

/// A cross-fade that happens on whichever clock is running.
///
/// Everything in this app that moves has had to learn the same lesson twice over: an
/// AnimationController runs on the wall clock, and under the capture harness a quarter of a second
/// of wall clock passes between one grabbed frame and the next. So a two-hundred-millisecond
/// transition is over before the second frame exists — the fold played and was never seen, the
/// corner turned and was never seen, and a region change and a partner's state card arrived whole
/// between two frames, which reads to a frame checker as a splice and to a person as a blink.
///
/// This is that lesson as one widget: when the app is being captured the fade follows
/// DrivenClock; otherwise it is an ordinary AnimatedSwitcher on the wall clock, because on a phone
/// the wall clock is the right one.
class Turning extends StatefulWidget {
  const Turning({
    super.key,
    required this.child,
    this.duration = Motion.turn,
    this.curve = Curves.easeOut,
    this.alignment = Alignment.topCenter,
  });

  /// Give this a key that changes when the thing being shown changes.
  final Widget child;
  final Duration duration;
  final Curve curve;
  final AlignmentGeometry alignment;

  @override
  State<Turning> createState() => _TurningState();
}

class _TurningState extends State<Turning> {
  Widget? _leaving;
  Duration? _from;
  double _t = 1.0;
  StreamSubscription<Duration>? _driven;

  @override
  void initState() {
    super.initState();
    if (DrivenClock.enabled) _driven = DrivenClock.ticks.listen(_advance);
  }

  @override
  void didUpdateWidget(Turning old) {
    super.didUpdateWidget(old);
    if (old.child.key != widget.child.key) {
      _leaving = old.child;
      _from = DrivenClock.enabled ? DrivenClock.now : null;
      _t = 0.0;
      if (!DrivenClock.enabled) _wallClock();
    }
  }

  void _advance(Duration now) {
    final from = _from;
    if (from == null || _t >= 1.0) return;
    final t = ((now - from).inMicroseconds / widget.duration.inMicroseconds).clamp(0.0, 1.0);
    setState(() {
      _t = t;
      if (t >= 1.0) _leaving = null;
    });
  }

  Future<void> _wallClock() async {
    final started = DateTime.now();
    while (mounted && _t < 1.0) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
      if (!mounted) return;
      final ms = DateTime.now().difference(started).inMilliseconds;
      setState(() {
        _t = (ms / widget.duration.inMilliseconds).clamp(0.0, 1.0);
        if (_t >= 1.0) _leaving = null;
      });
    }
  }

  @override
  void dispose() {
    _driven?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.curve.transform(_t.clamp(0.0, 1.0));
    final leaving = _leaving;
    if (leaving == null) return widget.child;
    return Stack(
      alignment: widget.alignment,
      children: [
        Opacity(opacity: 1.0 - t, child: leaving),
        Opacity(opacity: t, child: widget.child),
      ],
    );
  }
}

/// A number that runs from 0 to 1 once, on whichever clock is running.
///
/// This is the third time the same defect has been fixed in a different place, so it is a widget
/// now. TweenAnimationBuilder, AnimatedOpacity, AnimatedSize and every AnimationController run on
/// the framework's wall clock, and under capture the wall clock is not the app's clock: a quarter
/// of a second of it passes between two grabbed frames, so an implicit animation either has not
/// started or is already over, and never once appears in the recording. The unfolding clip ended
/// on a blank cream rectangle for exactly this reason — the note faded in over the last fold
/// frame, on the wall clock, in the gap between two screenshots.
///
/// [Settling] follows DrivenClock.ticks when it is enabled and a plain loop when it is not, and
/// hands the builder the eased value either way.
class Settling extends StatefulWidget {
  const Settling({
    super.key,
    required this.builder,
    this.duration = Motion.settle,
    this.curve = Curves.easeOut,
    this.child,
  });

  final Widget Function(BuildContext context, double t, Widget? child) builder;
  final Duration duration;
  final Curve curve;
  final Widget? child;

  @override
  State<Settling> createState() => _SettlingState();
}

class _SettlingState extends State<Settling> {
  double _t = 0.0;
  Duration? _from;
  StreamSubscription<Duration>? _driven;

  @override
  void initState() {
    super.initState();
    if (DrivenClock.enabled) {
      _from = DrivenClock.now;
      _driven = DrivenClock.ticks.listen(_advance);
    } else {
      _wallClock();
    }
  }

  void _advance(Duration now) {
    final from = _from;
    if (from == null || _t >= 1.0) return;
    final t = ((now - from).inMicroseconds / widget.duration.inMicroseconds).clamp(0.0, 1.0);
    if (mounted) setState(() => _t = t);
  }

  Future<void> _wallClock() async {
    final started = DateTime.now();
    while (mounted && _t < 1.0) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
      if (!mounted) return;
      final ms = DateTime.now().difference(started).inMilliseconds;
      setState(() => _t = (ms / widget.duration.inMilliseconds).clamp(0.0, 1.0));
    }
  }

  @override
  void dispose() {
    _driven?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, widget.curve.transform(_t.clamp(0.0, 1.0)), widget.child);
}
