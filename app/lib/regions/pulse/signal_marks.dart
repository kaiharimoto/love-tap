// What their phone says about them, drawn in the margin of their sheet in pencil.
//
// docs/SIGNALS.md gives every signal a material rendering, and for the life of the build all of
// them were a table instead: BATTERY 72%, RINGER normal, SIGNAL wifi, AT HOME yes, in one hand at
// one weight. The emotional-transmission critic's word for that was a message in a different
// font. The passive signals are the ones a person never chose to say -- the phone noticed them --
// so they are the ones that belong in the margin as marks rather than on the sheet as words:
//
//   battery   a pencil, worn to a stub as it drains; under 15% a red ring round the stub
//   charging  a plug on a cord beside the pencil
//   ringer    vibrate is a squiggle; silent is the same squiggle struck through; normal is nothing
//   moving    walking is two footprints; riding is a pencil arrow
//   network   cellular is a radio mast, which says they are out; wifi is nothing
//   at_home   a house, when they are home
//
// "Nothing" is a real answer and most of the time it is the answer: a margin with a house and a
// long pencil in it says the day is ordinary. The declared signals -- the mood, where they are,
// what they need -- stay words on the sheet, because those are things a person said.
//
// Each mark is drawn with the same hand as a drawn feeling (feelings/drawn.dart): a pen with a
// wobble, pressing harder in the middle of a stroke. Seeded by the signal's own name, so a mark is
// the same mark on both phones.
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../feelings/drawn.dart';
import '../../material/assignment.dart';
import '../../material/palette.dart';
import '../../spine/projections/state.dart';

/// One signal's mark, and which signal it is -- the key a test reads it back by.
class SignalMark extends StatelessWidget {
  const SignalMark({super.key, required this.signal, required this.draw, this.width = 30});

  /// The SIGNALS.md id this mark renders.
  final String signal;
  final void Function(Canvas canvas, Size size, DrawingHand pencil) draw;
  final double width;

  static const double height = 30;

  @override
  Widget build(BuildContext context) => Semantics(
        label: signal,
        child: CustomPaint(
          size: Size(width, height),
          painter: _MarkPainter(draw, hashOf(signal)),
        ),
      );
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.draw, this.seed);
  final void Function(Canvas canvas, Size size, DrawingHand pencil) draw;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) =>
      draw(canvas, size, DrawingHand(canvas, Pen.graphite, 1.3, seed));

  @override
  bool shouldRepaint(_MarkPainter old) => true;
}

/// The marks [state] earns, in the order SIGNALS.md lists them. Empty is an ordinary day.
List<SignalMark> signalMarks(PersonState state) {
  final battery = state.battery;
  return [
    if (battery != null)
      SignalMark(
        signal: 'battery',
        width: 84,
        draw: (c, s, p) => _pencil(c, s, p, battery.clamp(0, 100) / 100),
      ),
    if (battery != null && state.charging)
      SignalMark(signal: 'charging', draw: _plug),
    if (state.ringer == 'vibrate') SignalMark(signal: 'ringer', draw: (c, s, p) => _squiggle(s, p)),
    if (state.ringer == 'silent')
      SignalMark(signal: 'ringer', draw: (c, s, p) {
        _squiggle(s, p);
        p.stroke([Offset(s.width * 0.12, s.height * 0.82), Offset(s.width * 0.88, s.height * 0.18)]);
      }),
    if (state.moving == 'walking') SignalMark(signal: 'moving', draw: _footprints),
    if (state.moving == 'riding') SignalMark(signal: 'moving', draw: _arrow),
    if (state.network == 'cellular') SignalMark(signal: 'network', draw: _mast),
    if (state.atHome == true) SignalMark(signal: 'at_home', draw: _house),
  ];
}

/// A pencil lying along the margin, as long as the battery is full: a hexagonal barrel, a
/// sharpened point, and the ferrule and rubber at the far end. At 5% it is a stub, and under 15%
/// a red pen has ringed it, which is the one colour in the margin and is there to be noticed.
void _pencil(Canvas c, Size s, DrawingHand p, double left) {
  final y0 = s.height * 0.36, y1 = s.height * 0.64;
  const point = 9.0;
  const rubber = 6.0;
  final barrel = math.max(3.0, (s.width - point - rubber - 4) * left);
  final x0 = 2.0, xTip = x0 + point, xEnd = xTip + barrel;
  // the sharpened cone, and its lead
  p.stroke([Offset(xTip, y0), Offset(x0, (y0 + y1) / 2), Offset(xTip, y1)], taper: 0.2);
  p.dot(Offset(x0 + 1.2, (y0 + y1) / 2), 1.1);
  // the barrel, with the one facet line a hexagonal pencil shows
  p.stroke([Offset(xTip, y0), Offset(xEnd, y0)]);
  p.stroke([Offset(xTip, y1), Offset(xEnd, y1)]);
  p.stroke([Offset(xTip, (y0 + y1) / 2), Offset(xEnd, (y0 + y1) / 2)], width: 0.5, wobble: 0.3);
  // ferrule and rubber
  p.stroke([Offset(xEnd, y0), Offset(xEnd, y1)]);
  p.stroke([Offset(xEnd + rubber, y0 + 1), Offset(xEnd + rubber, y1 - 1)]);
  p.stroke([Offset(xEnd, y0), Offset(xEnd + rubber, y0 + 1)]);
  p.stroke([Offset(xEnd, y1), Offset(xEnd + rubber, y1 - 1)]);
  if (left < 0.15) {
    final ring = DrawingHand(c, Pen.red, 1.2, 15);
    final centre = Offset((x0 + xEnd + rubber) / 2, (y0 + y1) / 2);
    final r = (xEnd + rubber - x0) / 2 + 5;
    ring.arc(centre, r, -0.4, math.pi * 2 - 0.1, steps: 32, wobble: 1.0);
  }
}

/// A plug with two pins and its cord trailing off in a loop.
void _plug(Canvas c, Size s, DrawingHand p) {
  final x = s.width * 0.52, top = s.height * 0.22, bottom = s.height * 0.52;
  p.stroke([Offset(x - 6, top + 4), Offset(x + 6, top + 4), Offset(x + 6, bottom), Offset(x - 6, bottom), Offset(x - 6, top + 4)],
      taper: 0.1);
  p.stroke([Offset(x - 3, top + 4), Offset(x - 3, top - 2)]);
  p.stroke([Offset(x + 3, top + 4), Offset(x + 3, top - 2)]);
  p.stroke([
    Offset(x, bottom),
    Offset(x + 1, bottom + 4),
    Offset(x - 5, bottom + 8),
    Offset(x - 11, bottom + 7),
    Offset(x - 12, bottom + 3),
  ]);
}

/// The zigzag a phone on a table draws when it buzzes.
void _squiggle(Size s, DrawingHand p) {
  final mid = s.height / 2;
  p.stroke([
    for (var i = 0; i <= 7; i++) Offset(s.width * (0.12 + 0.76 * i / 7), mid + (i.isEven ? -5.0 : 5.0)),
  ], taper: 0.3);
}

/// Two footprints, one ahead of the other.
void _footprints(Canvas c, Size s, DrawingHand p) {
  for (final (dx, dy) in const [(0.3, 0.62), (0.66, 0.36)]) {
    final at = Offset(s.width * dx, s.height * dy);
    p.arc(at, 4.2, 0, math.pi * 2, steps: 14, wobble: 0.4);
    p.dot(at + const Offset(-2.2, -6.5), 1.1);
    p.dot(at + const Offset(1.8, -6.8), 1.1);
  }
}

/// An arrow off to the right: they are on their way somewhere.
void _arrow(Canvas c, Size s, DrawingHand p) {
  final y = s.height / 2;
  p.stroke([Offset(s.width * 0.1, y + 2), Offset(s.width * 0.5, y - 1), Offset(s.width * 0.86, y)]);
  p.stroke([Offset(s.width * 0.68, y - 7), Offset(s.width * 0.88, y), Offset(s.width * 0.68, y + 7)], taper: 0.2);
}

/// A radio mast with its waves: they are out, on the phone network.
void _mast(Canvas c, Size s, DrawingHand p) {
  final x = s.width / 2, top = s.height * 0.3, bottom = s.height * 0.9;
  p.stroke([Offset(x - 6, bottom), Offset(x, top), Offset(x + 6, bottom)], taper: 0.2);
  p.stroke([Offset(x - 3.5, s.height * 0.62), Offset(x + 3.5, s.height * 0.62)], width: 0.7);
  p.dot(Offset(x, top), 1.4);
  p.arc(Offset(x, top), 5, -math.pi * 0.85, -math.pi * 0.15, steps: 8, wobble: 0.3);
  p.arc(Offset(x, top), 9, -math.pi * 0.82, -math.pi * 0.18, steps: 10, wobble: 0.3);
}

/// A house: a box, a roof, a door. Drawn when their phone is home.
void _house(Canvas c, Size s, DrawingHand p) {
  final l = s.width * 0.2, r = s.width * 0.8, eave = s.height * 0.45, floor = s.height * 0.88;
  p.stroke([Offset(l - 3, eave + 1), Offset(s.width / 2, s.height * 0.1), Offset(r + 3, eave - 1)], taper: 0.2);
  p.stroke([Offset(l, eave), Offset(l, floor), Offset(r, floor), Offset(r, eave)], taper: 0.15);
  final d = s.width * 0.5;
  p.stroke([Offset(d - 3, floor), Offset(d - 3, floor - 8), Offset(d + 3, floor - 8), Offset(d + 3, floor)], width: 0.8);
}
