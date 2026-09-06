// A feeling arriving, as a thing arriving rather than a row appearing.
//
// The difference between a feeling and a message in another colour is weight. A message appears.
// A thing that has been thrown to you falls, hits the desk, gives, comes up again, and is still
// for a moment before it is finally still — and while it does that its shadow is doing the
// opposite, spreading out and going pale as the thing rises and drawing in hard underneath it as
// it lands. That is not decoration on top of an arrival; it *is* the arrival, and without it the
// object may as well be a sticker.
//
// Everything here is a pure function of how long ago the thing was let go. Nothing is tweened by
// the framework, which is what lets the capture harness step the whole landing one frame at a
// time and get the same landing every run, and what lets a test assert that the object is where
// ballistics says it should be.
//
// The second half of this file is the sensation the page carries. Android vibrates the pattern
// in docs/FEELINGS.md; iOS Safari has no vibration at all, so the same pattern moves the paper
// under your thumb instead: the whole surface lifts on every `on` and settles on every `off`.
// Same numbers, different body — not a fallback, and not silence.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../capture/hooks.dart';
import '../flags.dart';
import '../material/hands.dart';
import '../material/objects.dart';
import '../material/palette.dart';
import 'builtins.dart';

/// One thing arriving: what it is, how hard it was thrown, and which way it came.
class Arrival {
  const Arrival({required this.feeling, required this.intensity, required this.mine});
  final Feeling feeling;
  final double intensity;

  /// Something you sent lands too — you feel it leave — but it lands lighter and off to the side.
  final bool mine;
}

/// The ballistics. Distances are in object-heights, time in seconds, and the numbers are the
/// numbers: nothing here is an easing curve chosen because it looked nice.
class Fall {
  /// Desk-scale gravity. Not 9.81: the object is a few centimetres across and the desk is the
  /// whole world, so the fall is scaled to read at the size the thing is drawn.
  static const g = 26.0;

  /// How much of the impact comes back. Paper and cloth keep very little; a stone keeps more.
  static const restitution = 0.30;

  static double startHeight(double intensity) => 0.42 + 0.55 * intensity.clamp(0.0, 1.0);

  /// Height above the desk at [t] seconds, in object-heights. Zero once it has finished.
  static double heightAt(double t, double intensity) {
    if (t <= 0) return startHeight(intensity);
    final h0 = startHeight(intensity);
    final tc = math.sqrt(2 * h0 / g);
    if (t < tc) return h0 - 0.5 * g * t * t;
    var v = g * tc;
    var left = t - tc;
    for (var i = 0; i < 5; i++) {
      v *= restitution;
      final flight = 2 * v / g;
      if (flight < 0.012) return 0.0;
      if (left < flight) return v * left - 0.5 * g * left * left;
      left -= flight;
    }
    return 0.0;
  }

  /// The times, in seconds, at which it touches down. Used for the squash and for the sound.
  static List<double> contacts(double intensity, {int most = 5}) {
    final h0 = startHeight(intensity);
    var t = math.sqrt(2 * h0 / g);
    final out = <double>[t];
    var v = g * t;
    for (var i = 0; i < most; i++) {
      v *= restitution;
      final flight = 2 * v / g;
      if (flight < 0.012) break;
      t += flight;
      out.add(t);
    }
    return out;
  }

  static double get totalSeconds {
    final c = contacts(1.0);
    return c.last + 0.55;
  }

  /// How long the thing lies where it landed: until it has stopped bouncing and the pattern has
  /// finished playing through the paper, whichever is later.
  /// How long the thing lies on the desk before it is put away: as long as the feeling lasts —
  /// until it has stopped bouncing and the pattern has finished, and not a moment longer. It
  /// used to hold for half a second after both, and in that window nothing on the screen moved
  /// at all: the object still, the paper settled, the pattern over. Three frames of the landing
  /// clip were the frame before them.
  static double restSeconds(Feeling feeling, double intensity) =>
      math.max(contacts(intensity).last, feeling.hapticLengthMs / 1000.0);

  /// How long it takes to be put away into the recent row once it has rested.
  static const putAwaySeconds = 0.5;

  /// How much the thing is compressed at [t]: one over the first few hundredths of a second
  /// after each contact, biggest at the first.
  static double squashAt(double t, double intensity) {
    var s = 0.0;
    var strength = 1.0;
    for (final c in contacts(intensity)) {
      final since = t - c;
      if (since >= 0 && since < 0.075) {
        s = math.max(s, strength * math.sin(since / 0.075 * math.pi));
      }
      strength *= restitution + 0.25;
    }
    return s * (0.05 + 0.05 * intensity);
  }

  /// It was thrown, so it is turning, and it stops turning by rubbing on the desk.
  static double spinAt(double t, double intensity, double seed) {
    final a0 = (0.10 + 0.22 * intensity) * (seed < 0.5 ? -1 : 1);
    return a0 * math.exp(-t / 0.42) * math.cos(2 * math.pi * t / 0.33 + seed * 3.1);
  }

  /// The shadow: wide and pale when the thing is up, tight and dark when it is down. This is the
  /// whole reason a landing reads as a landing rather than as a slide.
  static double shadowAt(double t, double intensity) {
    final h = heightAt(t, intensity);
    return 1.0 / (1.0 + h * 2.1);
  }
}

/// The amplitude the page is moving at, [0..1], at [ms] into a feeling's pattern.
double amplitudeAt(List<HapticSegment> segments, int ms) {
  var at = 0;
  for (final s in segments) {
    if (ms < at + s.ms) return s.amp / 255.0;
    at += s.ms;
  }
  return 0.0;
}

/// How far off the desk the page is at [ms] into the pattern, 0..1: the sheet under your thumb
/// lifts when the pattern is on and comes back down when it is off, the way a motor's buzz starts
/// and stops, rather than following the amplitude as a step. The lift comes up over about twenty
/// milliseconds and falls away over about fifty, and while a segment is on the paper trembles a
/// little on top of the lift — a page held off a table by a running motor does not sit still.
double pageLiftAt(List<HapticSegment> segments, int ms) {
  var at = 0;
  var previous = 0.0;
  for (final s in segments) {
    final amp = s.amp / 255.0;
    if (ms < at + s.ms) {
      final into = (ms - at).toDouble();
      if (s.on) {
        final rise = 1.0 - math.exp(-into / 18.0);
        final tremor = 0.12 * math.sin(2 * math.pi * 18.0 * ms / 1000.0);
        return (amp * rise * (1.0 + tremor)).clamp(0.0, 1.0);
      }
      return previous * math.exp(-into / 48.0);
    }
    at += s.ms;
    previous = s.on ? amp : previous * math.exp(-s.ms / 48.0);
  }
  return 0.0;
}

/// How far the page moves at full amplitude, in logical pixels. On the PWA the page is the only
/// body the pattern has, so it moves enough to be read as a thing being held out to you; on
/// Android the vibrator is doing the same work to your hand and the paper only agrees with it.
double get kPageLiftPx => kIsWeb ? 9.0 : 3.0;

/// Wraps the shell. Moves everything under it on the feeling's own rhythm, and draws the thing
/// that is arriving on top of it.
class LandingStage extends StatefulWidget {
  const LandingStage({super.key, required this.arrivals, required this.child});

  final Stream<Arrival> arrivals;
  final Widget child;

  @override
  State<LandingStage> createState() => _LandingStageState();
}

class _LandingStageState extends State<LandingStage> with SingleTickerProviderStateMixin {
  Arrival? _arrival;
  double _t = 0.0;
  double _seed = 0.0;
  Ticker? _ticker;
  StreamSubscription<Arrival>? _sub;
  StreamSubscription<Duration>? _driven;
  Duration _startedAt = Duration.zero;

  @override
  void initState() {
    super.initState();
    _sub = widget.arrivals.listen(_begin);
    if (DrivenClock.enabled) {
      // Under capture the landing is a function of the clock the harness is turning, so one
      // frame of the clip is one step of the clock and the same run gives the same frames.
      _driven = DrivenClock.ticks.listen((now) {
        if (_arrival == null) return;
        setState(() => _t = (now - _startedAt).inMicroseconds / 1e6);
        _stopIfDone();
      });
    } else {
      _ticker = createTicker((elapsed) {
        if (_arrival == null) return;
        setState(() => _t = (elapsed - _startedAt).inMicroseconds / 1e6);
        _stopIfDone();
      });
    }
  }

  void _begin(Arrival a) {
    setState(() {
      _arrival = a;
      _t = 0.0;
      _seed = ((a.feeling.id.hashCode & 0xffff) / 0xffff);
      _startedAt = DrivenClock.enabled ? DrivenClock.now : Duration.zero;
    });
    if (!DrivenClock.enabled) {
      _ticker!.stop();
      _ticker!.start();
    }
  }

  void _stopIfDone() {
    final a = _arrival;
    if (a == null) return;
    final over = Fall.restSeconds(a.feeling, a.intensity) + Fall.putAwaySeconds + 0.05;
    if (_t >= over) {
      _ticker?.stop();
      setState(() => _arrival = null);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _driven?.cancel();
    _ticker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = _arrival;
    // The page rhythm: the surface lifts while the pattern is on and settles while it is off, on
    // the pattern's own timings. On Android the vibrator is doing this to your hand at the same
    // time and with the same numbers; on a phone with no vibrator this is the only body the
    // feeling has, so there it moves three times as far.
    var lift = 0.0;
    var ms = 0;
    if (a != null) {
      ms = (_t * 1000).round();
      lift = pageLiftAt(a.feeling.segments, ms) * (0.55 + 0.45 * a.intensity);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        Transform.translate(offset: Offset(0, -lift * kPageLiftPx), child: widget.child),
        if (a != null) IgnorePointer(child: _Landing(arrival: a, t: _t, seed: _seed)),
        // the haptic pattern annotated on the clip, generated from the same segments that are
        // moving the page and the motor: capture builds only, while a feeling is arriving
        // The lane is an annotation on the recording, so it goes where nothing of the app is:
        // along the very top of the frame, above the partner's strip. It sat across the bottom,
        // over the composer, where 'here · 2000ms · page' and 'write something' were printed on
        // top of each other — the one control you send a message with, unreadable. And it goes
        // when the pattern does, not when the object has finished being put away.
        if (a != null && Flags.capture && ms <= a.feeling.hapticLengthMs)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: IgnorePointer(child: HapticLane(feeling: a.feeling, intensity: a.intensity, ms: ms)),
          ),
      ],
    );
  }
}

/// The haptic pattern, drawn to scale along the bottom of the frame with a playhead: the
/// annotation the evidence clips carry. It is drawn from the feeling's own segments — the list the
/// vibrator is given and the page is moved by — so what it shows is what was played.
class HapticLane extends StatelessWidget {
  const HapticLane({super.key, required this.feeling, required this.intensity, required this.ms});
  final Feeling feeling;
  final double intensity;
  final int ms;

  static const double height = 30;

  @override
  Widget build(BuildContext context) {
    final total = feeling.hapticLengthMs;
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _LanePainter(feeling.segments, total, ms, intensity)),
          ),
          Positioned(
            left: 8,
            top: 1,
            child: Text(
              '${feeling.name} · ${total}ms · ${kIsWeb ? 'page' : 'vibration'}',
              style: Hands.onDesk(size: 9),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanePainter extends CustomPainter {
  _LanePainter(this.segments, this.total, this.ms, this.intensity);
  final List<HapticSegment> segments;
  final int total;
  final int ms;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0) return;
    const inset = 8.0;
    final w = size.width - 2 * inset;
    final base = size.height - 4;
    final scale = 0.55 + 0.45 * intensity.clamp(0.0, 1.0);
    // the baseline: pencil on the desk
    canvas.drawLine(Offset(inset, base), Offset(inset + w, base),
        Paint()..color = Pen.onWood.withValues(alpha: 0.7)..strokeWidth = 1.0);
    var at = 0;
    final bar = Paint()..color = Pen.onWood.withValues(alpha: 0.85);
    for (final s in segments) {
      final x0 = inset + w * at / total;
      final x1 = inset + w * (at + s.ms) / total;
      if (s.on) {
        final h = (size.height - 12) * (s.amp / 255.0) * scale;
        canvas.drawRect(Rect.fromLTRB(x0 + 0.5, base - h, math.max(x0 + 1.5, x1 - 0.5), base), bar);
      }
      at += s.ms;
    }
    // the playhead, in red pen, where the pattern is now
    final px = inset + w * (ms.clamp(0, total) / total);
    canvas.drawLine(Offset(px, 2), Offset(px, base + 3), Paint()..color = Pen.red..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(_LanePainter old) => old.ms != ms || old.segments != segments;
}

class _Landing extends StatelessWidget {
  const _Landing({required this.arrival, required this.t, required this.seed});
  final Arrival arrival;
  final double t;
  final double seed;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final s = 132.0 + 58.0 * arrival.intensity.clamp(0.0, 1.0);
    final h = Fall.heightAt(t, arrival.intensity);
    final squash = Fall.squashAt(t, arrival.intensity);
    final spin = Fall.spinAt(t, arrival.intensity, seed);
    final shadow = Fall.shadowAt(t, arrival.intensity);

    // where on the desk it lands: never dead centre, and never the same place twice
    final x0 = size.width * (arrival.mine ? 0.66 : 0.34) + (seed - 0.5) * size.width * 0.14;
    final y0 = size.height * 0.52 + (seed - 0.5) * size.height * 0.10;

    // It lies where it landed while the pattern plays — that is the feeling being felt, the
    // paper under it lifting to the rhythm — and then it is put away: it goes up the desk to
    // where the recent row keeps it, getting smaller as it goes, and the row's copy lands at the
    // moment this one is gone. It used to sit at full size for the whole pattern and then fade
    // where it lay, which read as the thing vanishing.
    final over = Fall.restSeconds(arrival.feeling, arrival.intensity);
    final put = ((t - over) / Fall.putAwaySeconds).clamp(0.0, 1.0);
    final ease = Curves.easeInOut.transform(put);
    final x = x0 + (size.width * 0.5 - x0) * ease * 0.6;
    final y = y0 + (size.height * 0.34 - y0) * ease;
    final scale = 1.0 - 0.62 * ease;
    final fade = put < 0.7 ? 1.0 : (1.0 - (put - 0.7) / 0.3).clamp(0.0, 1.0);

    return Stack(
      children: [
        Positioned(
          left: x - s * scale / 2,
          top: y - s * scale / 2,
          width: s * scale,
          height: s * scale,
          child: Opacity(
            opacity: fade,
            child: Transform.rotate(
              angle: spin,
              child: Transform(
                alignment: Alignment.bottomCenter,
                transform: Matrix4.diagonal3Values(1.0 + squash * 0.6, 1.0 - squash, 1.0),
                child: FeelingObject(
                  feeling: arrival.feeling,
                  size: s * scale,
                  intensity: arrival.intensity,
                  shadowScale: shadow,
                  lift: h,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Only used to keep the capture harness honest: what the stage would be showing at [ms].
Map<String, double> landingAt(int ms, double intensity) {
  final t = ms / 1000.0;
  return {
    'height': Fall.heightAt(t, intensity),
    'squash': Fall.squashAt(t, intensity),
    'shadow': Fall.shadowAt(t, intensity),
  };
}

bool get landingIsDriven => Flags.capture;
