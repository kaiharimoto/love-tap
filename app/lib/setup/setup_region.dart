// The first screen either phone shows: a list in pencil, with the steps that are done ticked off.
//
// This is not an onboarding flow. It is the piece of paper you would actually write if you were
// setting two phones up on a table: the things that have to happen, in the order they happen, with
// a tick beside the ones that already have. Nothing here congratulates anyone.
import 'package:flutter/widgets.dart';

import '../material/hands.dart';
import '../material/library.dart';
import '../material/marks.dart';
import '../material/paper.dart';
import '../material/palette.dart';
import 'checklist.dart';

class SetupSheet extends StatelessWidget {
  const SetupSheet({
    super.key,
    required this.platform,
    required this.facts,
    this.hostAddress,
    this.onShowWords,
  });

  final String platform;
  final SetupFacts facts;

  /// The address the other phone is serving its certificate and its six words from.
  final String? hostAddress;
  final VoidCallback? onShowWords;

  @override
  Widget build(BuildContext context) {
    final steps = stepsFor(platform);
    final state = observe(steps, facts);
    final lib = MaterialLibrary.loaded ? MaterialLibrary.instance : null;
    final stock = lib?.stockVariants('looseleaf').firstOrNull ?? lib?.stockVariants('lined').firstOrNull ?? '';
    final width = MediaQuery.sizeOf(context).width - 36;

    return ListView(
      // the tab strip sits over the foot of this list, so the sheets end above it rather
      // than under it
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 108),
      children: [
        // A sheet per step, not one sheet the height of the list.
        //
        // It was one PaperPiece with the whole checklist on it, about two and a half thousand
        // points tall, and its stock never drew: at three device pixels to the point the covered
        // image is past what the canvas will hold, so it fell back to the colour underneath and
        // fifty-one per cent of the screen was one exact grey — the flat fill this whole visual
        // language is defined against, on the first screen anybody sees. Several sheets is also
        // what a list of things to do actually looks like on a desk.
        _Sheet(
          id: 'setup.head',
          row: 0,
          width: width,
          stock: stock,
          lib: lib,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                platform == 'android' ? 'this phone' : 'this one, the iphone',
                style: Hands.teo(size: 22),
              ),
              const SizedBox(height: 4),
              Text('two phones, one wire between them, nobody else on it.', style: Hands.margin(size: 14)),
            ],
          ),
        ),
        for (final (i, st) in steps.indexed)
          _Sheet(
            id: 'setup.${st.id}',
            row: i + 1,
            width: width,
            stock: stock,
            lib: lib,
            child: _Line(step: st, state: state[st.id] ?? StepState.waiting),
          ),
        if (hostAddress != null)
          _Sheet(
            id: 'setup.where',
            row: steps.length + 1,
            width: width,
            stock: stock,
            lib: lib,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('the other phone is at', style: Hands.margin(size: 13)),
                Text(hostAddress!, style: Hands.stamp(size: 16, spacing: 0.6)),
              ],
            ),
          ),
        if (onShowWords != null)
          _Sheet(
            id: 'setup.words',
            row: steps.length + 2,
            width: width,
            stock: stock,
            lib: lib,
            onTap: onShowWords,
            child: Text('read the six words out', style: Hands.margin(size: 16)),
          ),
      ],
    );
  }
}

/// One sheet of the setup list: the same paper, a different tear each time, lying at its own
/// angle the way a few sheets left on a desk do.
class _Sheet extends StatelessWidget {
  const _Sheet({
    required this.id,
    required this.row,
    required this.width,
    required this.stock,
    required this.lib,
    required this.child,
    this.onTap,
  });

  final String id;
  final int row;
  final double width;
  final String stock;
  final MaterialLibrary? lib;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final masks = lib?.writableTears ?? const <String>[];
    final tear = masks.isEmpty ? null : masks[(row * 5 + 3) % masks.length];
    final piece = PaperPiece(
      stockId: stock,
      tearId: tear,
      liftMm: 0.7 + (row % 4) * 0.2,
      tilt: ((row.isEven ? 1 : -1) * (4 + row % 3)) / 900.0,
      width: width,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 15),
      safe: tear == null || lib == null ? const [0.06, 0.07, 0.06, 0.07] : lib!.safeOf(tear),
      stockAlignment: Alignment(((row * 37) % 100) / 50.0 - 1, ((row * 61) % 100) / 50.0 - 1),
      stockScale: 1.12,
      child: child,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: onTap == null ? piece : GestureDetector(onTap: onTap, child: piece),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.step, required this.state});
  final SetupStep step;
  final StepState state;

  @override
  Widget build(BuildContext context) {
    final done = state == StepState.done;
    final doing = state == StepState.doing;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 26,
            child: done
                ? Padding(padding: const EdgeInsets.only(top: 2), child: Mark.tick(size: 17, seed: step.id.length * 7))
                : const SizedBox.shrink(),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: Hands.teo(size: 18).copyWith(
                    color: done ? Pen.margin : Pen.graphite,
                    decoration: done ? TextDecoration.lineThrough : null,
                    decorationColor: Pen.margin,
                    decorationThickness: 1.4,
                  ),
                ),
                if (!done)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(step.detail, style: Hands.margin(size: 14)),
                  ),
                if (doing)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(step.observedBy, style: Hands.margin(size: 12.5).copyWith(color: Pen.margin)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
