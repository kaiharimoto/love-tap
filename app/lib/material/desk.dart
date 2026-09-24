// The desk the whole app sits on, and the strip of the partner's paper that sits at the top of
// every region. The desk is a render (assets/shell/desk*.webp) when the library has been baked;
// until then it is the flat colour the render was made against, never a gradient.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../spine/projections/state.dart';
import '../spine/spine.dart';
import '../voice/strings.dart';
import 'assignment.dart';
import 'hands.dart';
import 'library.dart';
import 'light.dart';
import 'marks.dart';
import 'objects.dart';
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
    // The desk hides whatever was painted before it, and says so. `ColoredBox` is the first thing
    // in the stack, it is expanded to the whole of this box, and both desk colours carry a full
    // alpha, so there is no condition under which something behind shows through -- not even when
    // the library has not been baked and the render above is absent. See [OpaqueSurface] for what
    // the declaration does with that.
    return OpaqueSurface(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: dusk ? DeskColour.dusk : DeskColour.day),
          if (surface)
            Image.asset(shellAsset(dusk ? 'desk_dusk' : 'desk'),
                fit: BoxFit.cover, repeat: ImageRepeat.repeatY,
                frameBuilder: paintWhenItArrives, errorBuilder: PaperPiece.none),
          child,
        ],
      ),
    );
  }
}

/// A surface that covers whatever was painted before it, stated by the widget that knows.
///
/// It draws nothing and costs nothing; it exists so that the capture declaration can tell the
/// difference between a paragraph that is on the glass and one that is behind a desk.
///
/// The declaration needed this because the framework will not answer it. `CaptureHooks.textRuns`
/// declares only what is painted, and asks `paintsChild` -- the framework's own answer -- which
/// covers a zero opacity, an `Offstage`, a scrolled-away list child, and, asked directly, a
/// `RenderIndexedStack`. What it does not cover is a route stacked over another route: the
/// `Navigator`'s overlay lays its offstage entries out and simply does not paint them, and its
/// render object does not override `paintsChild` to say so. `SearchPage` has been pushed with
/// `opaque: true` since it was written and the chat behind it was declared anyway, which is the
/// proof that this is not something a route flag can fix from the outside.
///
/// So `14_media_viewer.png` declared 25 runs where the screen holds three: one torn note, one
/// stamped button, and 22 lines of the chat underneath a photograph. `legibility.py` looked
/// inside those rects, found photograph and wood grain, and reported them as writing at 1.01:1 --
/// six of the 84 runs below floor on firing 12's capture were texture inside a declaration of
/// something invisible, and firing 13 lost a guess to one of them.
class OpaqueSurface extends SingleChildRenderObjectWidget {
  const OpaqueSurface({super.key, required Widget super.child});

  @override
  RenderOpaqueSurface createRenderObject(BuildContext context) => RenderOpaqueSurface();
}

/// The render object [OpaqueSurface] exists to put in the tree. It is a plain proxy: it changes
/// no layout, paints nothing of its own, and is only ever looked for by type.
class RenderOpaqueSurface extends RenderProxyBox {}

/// The partner's state, on a torn strip of the paper their mood picks, in their hand, at the top
/// of every region. docs/SIGNALS.md says what each signal does to it.
class PartnerStrip extends StatelessWidget {
  const PartnerStrip({
    super.key,
    required this.partner,
    required this.state,
    required this.nowMs,
    this.lastHeard,
    this.onTap,
  });

  final Person partner;
  final PersonState state;
  final int nowMs;

  /// When their phone was last heard from, while the link is down; null while it is up. Given,
  /// the strip says how old its news is. See `AppScope.partnerLastHeard`.
  final int? lastHeard;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final lib = MaterialLibrary.loaded ? MaterialLibrary.instance : null;
    final stock = stockForMood(state.mood);
    final variants = lib?.stockVariants(stock) ?? const <String>[];
    final id = variants.isEmpty ? '' : variants[(partner.index + (state.mood?.length ?? 0)) % variants.length];
    // The partner strip is one strip per person, so it is a two-row lane and the row is who it
    // is. It keyed off `hashOf(state.mood)` into the whole pool, which is the mechanism
    // `tearAt`'s docstring rules out -- a hash cannot promise distinctness -- and it also made
    // the strip change its torn edge when the partner's mood changed, which is a piece of paper
    // becoming a different piece of paper because somebody felt differently.
    // `4 + partner.index` stood here, and `chrome` had a span of 4: `(4 + i) % 4 == i % 4`, so
    // the `+ 4` that was meant to hold this clear of the pulse's their-sheet was annihilated by
    // the modulus and the two drew the same mask on every screen the strip is on. It is the one
    // piece of chrome that is above every region, so it has a row of its own and no arithmetic.
    final tear = tearAt(lib, lane: TearLanes.chrome, row: ChromeRows.partner);
    final asleep = state.availability == 'asleep';
    final headsDown = state.availability == 'heads_down';
    final ink = partner == Person.noor ? Pen.ballpoint : Pen.graphite;
    // Pen pressure follows their energy, and it stays -- a hand that presses lightly is still a
    // hand you can read. It just varies between 0.80 and 1.00 rather than between 0.55 and 1.00,
    // because alpha counts as contrast: at energy 0 the old range put ballpoint on lined stock at
    // about 3.3:1 and graphite lower still, and docs/COLOR.md section 6 requires any ink carrying
    // a word to composite at alpha >= 0.80.
    final energy = state.energy;
    final weight = 0.80 + 0.05 * energy;
    // The clover and the room left for it scale with the screen's width. At 480 they are what
    // `a_pressed_clover_is_on_the_strip_test` measures; at 360, the width of 06, 07, 08, 11 and 15
    // and a common Android phone, a clover of the same size is 1% of a screen 56% as large, and
    // its room was a quarter of a strip whose second row overflowed by 39 px.
    final narrow = narrowing(MediaQuery.sizeOf(context).width);

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 2),
        child: SizedBox(
          height: 86,
          // Asleep used to fade this whole strip to 0.55, sentence and all. docs/COLOR.md section 8:
          // nothing that carries a word may be dimmed, and the status line is the part you still
          // need to read. Asleep is said by the stock `stockForMood` picks and by the pen's own
          // weight above, which is where it belonged, so there is no Opacity here at all now.
          child: Stack(
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: [
            PaperPiece(
              stockId: id,
              tearId: tear,
              liftMm: 0.5 + 0.4 * state.need,
              tilt: -0.006,
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
              safe: tear == null || lib == null ? const [0.06, 0.07, 0.06, 0.07] : lib.safeOf(tear),
              stockScale: 1.2,
              stockAlignment: Alignment.topCenter,
              // the status line runs the width of the strip, and the strip's stock is whichever
              // the mood picks -- legal, lined and spiral all carry a red rule at about 23%
              besideTheMargin: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // The age goes on this line and not with the dials, which fill theirs:
                        // the status line is what it is the age OF, and it ellipsizes to make room.
                        Row(children: [
                          Flexible(
                            child: Text(
                              state.statusLine ?? _fallbackLine(state, asleep, headsDown),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Hands.of(partner, size: 17, colour: ink.withValues(alpha: weight)),
                            ),
                          ),
                          if (lastHeard != null) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(S.lastHeard(nowMs, lastHeard!),
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.ellipsis,
                                  style: Hands.margin(size: 12)),
                            ),
                          ],
                          // The pencil is a fact about their phone, like when it was last heard
                          // from, so it goes on this line, which ellipsizes to make room for it.
                          // The line below is fixed widths end to end and had none to give.
                          if (state.battery != null) ...[
                            const SizedBox(width: 8),
                            _Pencil(charge: state.battery! / 100.0, charging: state.charging),
                          ],
                        ]),
                        const SizedBox(height: 2),
                        Row(children: [
                          if (state.place != null) Stamped(state.place!, size: 10),
                          if (state.place != null) const SizedBox(width: 8),
                          _Dial(label: 'need', value: state.need),
                          const SizedBox(width: 10),
                          _Dial(label: 'energy', value: state.energy),
                        ]),
                      ],
                    ),
                  ),
                  // the clover's room: the status line ellipsizes before it rather than under it
                  SizedBox(width: _cloverRoom * narrow),
                ],
              ),
            ),
            // Lying across the strip's right end and off it onto the desk, pressed flat. The strip
            // is at the top of every region, so this is the one coloured thing on every screen
            // that has it -- docs/COLOR.md §7 items 5 and 6. See [PressedClover].
            Positioned(right: -16, top: -10, child: PressedClover(size: cloverSize * narrow)),
            ],
          ),
          ),
        ),
    );
  }

  /// The pressed clover's ink, in logical pixels: enough for 1% of a 480x1040 screen at 3x to be
  /// family D over the 0.09 chroma floor. `test/a_pressed_clover_is_on_the_strip_test.dart`.
  static const double cloverSize = 112;

  /// How much the clover and its room shrink on a screen [width] logical pixels wide: 1 at 480
  /// and above, 0.75 at 360, never under 0.7.
  static double narrowing(double width) => (width / 480).clamp(0.7, 1.0).toDouble();

  /// How much of the strip's right end the status line leaves to the clover.
  static const double _cloverRoom = 80;

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
          // Tally strokes, which is what this widget's docstring has always said it was. It was
          // four flat `Container`s: hard-edged vertical bars sharing a y to the pixel, interiors
          // perfectly constant, one ink at two opacities. This strip is at the top of every
          // screen, so that barcode was on all of them.
          SizedBox(
            width: 17,
            height: 11,
            child: Tally(
              heights: [for (var i = 0; i < 4; i++) i < value ? 1.0 : 0.45],
              struck: value,
              colour: Pen.margin,
              lightColour: Pen.margin,
              weight: 1.4,
              // the two dials sit side by side, so they must not be the same hand twice
              seed: label == 'need' ? 31 : 37,
            ),
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
