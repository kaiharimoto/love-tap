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
    final tear = lib?.writableTears.isNotEmpty == true ? lib!.writableTears[3 % lib.writableTears.length] : null;
    final width = MediaQuery.sizeOf(context).width - 36;

    return ListView(
      // the tab strip sits over the foot of this list, so the sheet ends above it rather
      // than under it
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 108),
      children: [
        PaperPiece(
          stockId: stock,
          tearId: tear,
          liftMm: 1.1,
          tilt: -0.006,
          width: width,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          safe: tear == null || lib == null ? const [0.06, 0.07, 0.06, 0.07] : lib.safeOf(tear),
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
              const SizedBox(height: 14),
              for (final s in steps)
                _Line(step: s, state: state[s.id] ?? StepState.waiting),
              if (hostAddress != null) ...[
                const SizedBox(height: 14),
                const RuleLine(seed: 53),
                const SizedBox(height: 8),
                Text('the other phone is at', style: Hands.margin(size: 13)),
                Text(hostAddress!, style: Hands.stamp(size: 16, spacing: 0.6)),
              ],
              if (onShowWords != null) ...[
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: onShowWords,
                  child: Text('read the six words out', style: Hands.margin(size: 16)),
                ),
              ],
            ],
          ),
        ),
      ],
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
