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
import '../material/slip.dart';
import '../spine/spine.dart' show Person;
import '../material/palette.dart';
import '../material/objects.dart';
import 'builtins.dart';

/// One thing arriving: what it is, how hard it was thrown, and which way it came.
class Arrival {
  const Arrival({
    required this.feeling,
    required this.intensity,
    required this.mine,
    required this.from,
    required this.at,
  });
  final Feeling feeling;
  final double intensity;

  /// Something you sent lands too — you feel it leave — but it lands lighter and off to the side.
  final bool mine;

  /// Who sent it, and when it was sent — the two things the shelf writes under its copy of the
  /// same object and this one did not write at all.
  final Person from;
  final DateTime at;
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
  // And after the last segment the page does not stop dead.
  //
  // This returned zero the moment the pattern ended, so the substitute had an arrival and a
  // sustain and no release: an emotional critic tracked the board against each run's own rest
  // frame and found hold at dy -12 on frame 118 and dy 0 on frame 119, squeeze at -17 then 0,
  // soup at -13 then 0 — full deflection to rest in a single sixteen-millisecond frame, three
  // times out of three, with the whole frame then reading 0.000 grey levels of change for the
  // next thirty. A hand that has been pushed comes back over about a tenth of a second, and this
  // is the same fifty-millisecond fall the pattern's own gaps already use.
  return previous * math.exp(-(ms - at) / 48.0);
}

/// How far the page moves at full amplitude, in logical pixels. On the PWA the page is the only
/// body the pattern has, so it moves enough to be read as a thing being held out to you; on
/// Android the vibrator is doing the same work to your hand and the paper only agrees with it.
double get kPageLiftPx => kIsWeb ? 9.0 : 3.0;

/// Which way the desk is knocked, for a feeling, as a unit vector.
///
/// A buzz is a push and not a lift. The substitute moved the page on one axis only — an emotional
/// critic measured every frame of 07 and found the horizontal component *exactly* zero in all 421
/// of them — so what it read as was a page bouncing rather than a phone being knocked in the hand.
/// The direction is the feeling's own, so two feelings with the same envelope still do not move
/// the desk the same way: on a phone with no vibrator the motion is the whole of the body the
/// feeling has, and the row asks that it be identifiable.
///
/// Sideways is smaller than up, because the hand holding a phone gives more in the axis it is not
/// gripping across, and a page that slides as far as it lifts reads as a swipe.
Offset knockDirection(String feelingId) {
  final a = (feelingId.hashCode & 0xffff) / 0xffff * 2 * math.pi;
  // Both components turn with the angle, not just the sideways one. With the lift held at -1 the
  // direction was a function of cos alone, and cos is symmetric: forty-two pairs of feelings came
  // out moving the desk identically because their angles were mirror images.
  return Offset(math.cos(a) * 0.42, -(0.82 + 0.18 * math.sin(a)));
}

/// How far the desk is turned by the same knock, in radians. Under a quarter of a degree at full
/// amplitude: enough that a corner moves further than the middle, which is what makes it read as a
/// board being struck rather than a layer being animated.
double knockTilt(String feelingId) =>
    math.sin((feelingId.hashCode & 0xffff) / 0xffff * 2 * math.pi + 1.7) * 0.004;

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
        if (a == null)
          widget.child
        else
          Transform.rotate(
            angle: lift * knockTilt(a.feeling.id),
            child: Transform.translate(
              offset: knockDirection(a.feeling.id) * (lift * kPageLiftPx),
              child: widget.child,
            ),
          ),
        if (a != null) IgnorePointer(child: _Landing(arrival: a, t: _t, seed: _seed)),
        // The pattern annotated on the timeline, which artifact 07 is required to carry. Capture
        // builds only, along the top edge where the app draws only desk, and gone the moment the
        // pattern is. No words on it — see HapticLane.
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

    // Whose it is and when, written on the desk under it, in the hand and at the sizes the shelf
    // writes its copy of the same object in.
    //
    // This carried nothing. The same feeling was on the glass twice at once in 15 — 'tuesday soup
    // / 20:35 · noor' in the shelf, and lying across the state card above it with no name, no time
    // and no sender at all — which is one event drawn two incompatible ways, the thing the
    // coherence row exists to catch. It comes in as the object touches the desk and goes with it.
    final when = arrival.at.toLocal();
    final hh = when.hour.toString().padLeft(2, '0');
    final mm = when.minute.toString().padLeft(2, '0');
    final written = (h <= 0.001 ? 1.0 : 0.0) * fade;
    final box = s * scale;

    return Stack(
      children: [
        Positioned(
          left: x - box / 2,
          top: y - box / 2,
          width: box,
          height: box,
          child: Opacity(
            opacity: fade,
            child: Transform.rotate(
              angle: spin,
              child: Transform(
                alignment: Alignment.bottomCenter,
                transform: Matrix4.diagonal3Values(1.0 + squash * 0.6, 1.0 - squash, 1.0),
                child: FeelingObject(
                  feeling: arrival.feeling,
                  size: box,
                  intensity: arrival.intensity,
                  shadowScale: shadow,
                  lift: h,
                ),
              ),
            ),
          ),
        ),
        if (written > 0)
          Positioned(
            left: x - box * 0.6,
            top: y + box / 2 - 4,
            width: box * 1.2,
            child: Opacity(
              opacity: written,
              // On a slip, not on whatever it landed on.
              //
              // Written straight onto the ground it was the hand the *desk* is written in, which
              // is a pale warm grey: legible on wood and a ghost on paper. The landing lands
              // wherever the region has put its cards, so the name came out drawn through the
              // rituals card's own writing — measured on 07 frame 360, which is exactly as bad as
              // carrying no name at all. No one colour reads on both grounds, so the label brings
              // its own: a thing that arrives with who it is from written on it is a parcel, which
              // is what a feeling sent from one phone to another is.
              child: Slip(
                id: 'landing.${arrival.feeling.id}',
                row: 1,
                stock: 'receipt',
                width: box * 1.2,
                padding: const EdgeInsets.fromLTRB(6, 3, 6, 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(arrival.feeling.name,
                        style: Hands.margin(size: 10 * scale.clamp(0.6, 1.4)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center),
                    Text('$hh:$mm${arrival.mine ? '' : ' · ${arrival.from.name}'}',
                        style: Hands.margin(size: 8.5 * scale.clamp(0.6, 1.4)),
                        textAlign: TextAlign.center),
                  ],
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

/// The haptic pattern, drawn to scale with a playhead: the annotation the brief requires 07 to
/// carry on its timeline. It comes from the feeling's own segments — the list the vibrator is given
/// and the page is moved by — so what it shows is what was played.
///
/// It carries no words. The version that did printed the feeling's name, its length in
/// milliseconds and the channel it played on, and four critics read that, rightly, as a diagnostic
/// laid over the app; one of them counted it sitting on the composer's own words. An annotation on
/// a recording is a ruler laid beside the thing, not a caption written across it. So this is the
/// pattern and nothing else, along the top edge where the app draws only desk, and it goes the
/// moment the pattern does.
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
