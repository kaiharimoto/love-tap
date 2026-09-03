// The desk the whole app sits on, and the strip of the partner's paper that sits at the top of
// every region. The desk is a render (assets/shell/desk*.webp) when the library has been baked;
// until then it is the flat colour the render was made against, never a gradient.
import 'package:flutter/material.dart';

import '../spine/projections/state.dart';
import '../spine/spine.dart';
import 'assignment.dart';
import 'hands.dart';
import 'library.dart';
import 'light.dart';
import 'palette.dart';
import 'paper.dart';

class Desk extends StatelessWidget {
  const Desk({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dusk = Light.of(context) == LightCondition.dusk;
    final lib = MaterialLibrary.loaded ? MaterialLibrary.instance : null;
    final surface = lib?.shell.any((e) => e.id == (dusk ? 'desk_dusk' : 'desk')) ?? false;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: dusk ? DeskColour.dusk : DeskColour.day),
        if (surface)
          Image.asset(shellAsset(dusk ? 'desk_dusk' : 'desk'),
              fit: BoxFit.cover, repeat: ImageRepeat.repeatY, errorBuilder: PaperPiece.none),
        child,
      ],
    );
  }
}

/// The partner's state, on a torn strip of the paper their mood picks, in their hand, at the top
/// of every region. docs/SIGNALS.md says what each signal does to it.
class PartnerStrip extends StatelessWidget {
  const PartnerStrip({super.key, required this.partner, required this.state, required this.nowMs, this.onTap});

  final Person partner;
  final PersonState state;
  final int nowMs;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final lib = MaterialLibrary.loaded ? MaterialLibrary.instance : null;
    final stock = stockForMood(state.mood);
    final variants = lib?.stockVariants(stock) ?? const <String>[];
    final id = variants.isEmpty ? '' : variants[(partner.index + (state.mood?.length ?? 0)) % variants.length];
    final tears = lib?.writableTears ?? const <String>[];
    // a strip torn across the page: the strip kinds sit early in the pool
    final tear = tears.isEmpty ? null : tears[(state.mood?.hashCode.abs() ?? 3) % tears.length];
    final asleep = state.availability == 'asleep';
    final headsDown = state.availability == 'heads_down';
    final ink = partner == Person.noor ? Pen.ballpoint : Pen.graphite;
    // pen pressure follows their energy: faint pencil at 0, hard biro at 4
    final energy = state.energy;
    final weight = 0.55 + 0.15 * energy;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 2),
        child: SizedBox(
          height: 86,
          child: Opacity(
            opacity: asleep ? 0.55 : 1.0,
            child: PaperPiece(
              stockId: id,
              tearId: tear,
              liftMm: 0.5 + 0.4 * state.need,
              tilt: -0.006,
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
              safe: tear == null || lib == null ? const [0.06, 0.07, 0.06, 0.07] : lib.safeOf(tear),
              stockScale: 1.2,
              stockAlignment: Alignment.topCenter,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          state.statusLine ?? _fallbackLine(state, asleep, headsDown),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Hands.of(partner, size: 17, colour: ink.withValues(alpha: weight)),
                        ),
                        const SizedBox(height: 2),
                        Row(children: [
                          if (state.place != null) Stamped(state.place!, size: 10),
                          if (state.place != null) const SizedBox(width: 8),
                          _Dial(label: 'need', value: state.need),
                          const SizedBox(width: 10),
                          _Dial(label: 'energy', value: state.energy),
                          const SizedBox(width: 10),
                          if (state.battery != null) _Pencil(charge: state.battery! / 100.0, charging: state.charging),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _fallbackLine(PersonState s, bool asleep, bool headsDown) {
    if (asleep) return 'asleep';
    if (headsDown) return 'heads down';
    return s.mood ?? '';
  }
}

/// A need or energy dial: a corner of the strip folded over, drawn as tally strokes rather than
/// as a progress bar. Never a coloured dot.
class _Dial extends StatelessWidget {
  const _Dial({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Stamped(label, size: 9, colour: Pen.margin),
          const SizedBox(width: 3),
          for (var i = 0; i < 4; i++)
            Container(
              width: 2.2,
              height: i < value ? 11 : 5,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              color: Pen.margin.withValues(alpha: i < value ? 0.85 : 0.3),
            ),
        ],
      );
}

/// The battery as a pencil worn down to a stub.
class _Pencil extends StatelessWidget {
  const _Pencil({required this.charge, required this.charging});
  final double charge;
  final bool charging;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 30,
        height: 10,
        child: CustomPaint(painter: _PencilPainter(charge.clamp(0.0, 1.0), charging)),
      );
}

class _PencilPainter extends CustomPainter {
  _PencilPainter(this.charge, this.charging);
  final double charge;
  final bool charging;

  @override
  void paint(Canvas canvas, Size size) {
    final body = Paint()..color = Pen.margin.withValues(alpha: 0.8);
    final w = size.width * (0.25 + 0.75 * charge);
    canvas.drawRect(Rect.fromLTWH(0, size.height * 0.25, w - 5, size.height * 0.5), body);
    final tip = Path()
      ..moveTo(w - 5, size.height * 0.25)
      ..lineTo(w, size.height * 0.5)
      ..lineTo(w - 5, size.height * 0.75)
      ..close();
    canvas.drawPath(tip, Paint()..color = Pen.graphite);
    if (charge < 0.15) {
      canvas.drawCircle(Offset(w - 2, size.height * 0.5), 5,
          Paint()..color = Pen.red..style = PaintingStyle.stroke..strokeWidth = 1.2);
    }
    if (charging) {
      canvas.drawLine(Offset(0, size.height * 0.5), Offset(-4, size.height * 0.5),
          Paint()..color = Pen.margin..strokeWidth = 1.2);
    }
  }

  @override
  bool shouldRepaint(_PencilPainter old) => old.charge != charge || old.charging != charging;
}

/// The desk colour, kept out of `Desk` so both can be const.
class DeskColour {
  static const day = Color(0xFF4C3E32);
  static const dusk = Color(0xFF2A241F);
}
