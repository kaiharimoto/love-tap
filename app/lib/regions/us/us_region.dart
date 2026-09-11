// Us: the couple's shared life, all of it on one desk, all of it writing into the same spine.
// The sections come from modules/registry.dart, so a fifth module appears here without this file
// changing.
import 'package:flutter/material.dart';

import '../../material/desk.dart';
import '../../material/hands.dart';
import '../../material/marks.dart';
import '../../material/slip.dart';
import '../../modules/module.dart';
import '../../modules/registry.dart';
import '../../scope.dart';

class UsRegion extends StatefulWidget {
  const UsRegion({super.key});

  @override
  State<UsRegion> createState() => _UsRegionState();
}

class _UsRegionState extends State<UsRegion> {
  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final events = scope.spine.all;
    final ctx = ModuleContext(
      events: events,
      me: scope.me,
      partner: scope.partner,
      now: scope.clock.now().toLocal(),
      emit: scope.emit,
    );
    // Four things on one desk, all of them open. The brief asks for the four modules present and
    // populated at once, and that is also just what the surface should be: you do not tab between
    // the dates and the list when they are both on the table in front of you. Tapping a heading
    // pushes that one open on its own, for when you are actually working in it.
    return LayoutBuilder(builder: (context, constraints) {
      final rooms = shareOfTheDesk(constraints.maxHeight);
      return ListView(
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 96),
        children: [
          for (var i = 0; i < kModules.length; i++)
            _Section(
              module: kModules[i],
              ctx: ctx.inRoom(rooms[i], kModules[i].rowHeight),
              row: i,
              onOpen: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  // opened on its own it gets the whole of itself: no limit, its own scroller
                builder: (_) => _Alone(module: kModules[i], ctx: ctx.whole()),
                ),
              ),
            ),
        ],
      );
    });
  }

}

/// The stamped heading on each section: one fixed height, so the desk knows what its own chrome
/// costs before it shares out what is left.
const double kUsHeading = 72;

/// The gap under each section.
const double kUsSectionGap = 10;

/// How much of the desk each module gets, in points, given the height of the slot Us is drawn in.
///
/// Us used to budget in rows: two for the dates, two for the list, one each for the rest. A row is
/// not a unit the shell can price — with the seeded year's own events the dates cost 576.7 pt and
/// the list 254.0 pt of the ~896 pt the shell leaves, so the calendar heading landed at 928 pt and
/// the rituals and the shelf never reached the glass, while 03_us.report.json listed all five with
/// their event counts. The guard that was supposed to catch it measured five one-field synthetic
/// events in a bare Scaffold against the whole screen, and certified a layout 380 pt shorter than
/// the one that was photographed.
///
/// So: take the chrome off the top, give every module one row of itself, and share what is left.
/// The dates and the list are the two anyone reads standing up, so they ask for the larger shares
/// — each module says what it wants ([Module.share]) rather than being named in a table here.
/// [Module.rowHeight] only decides fairness — [FitRows] enforces the budget by laying the rows
/// out, so a module whose declared row height has drifted takes a wrong share of the desk rather
/// than falling off the bottom of it.
List<double> shareOfTheDesk(double slot) {
  final chrome = kModules.length * (kUsHeading + kUsSectionGap) + 4 + 8;
  final minima = [for (final m in kModules) m.rowHeight];
  final room = slot.isFinite ? slot - chrome : double.infinity;
  if (!room.isFinite) return minima;
  var extra = room - minima.fold<double>(0, (a, b) => a + b);
  if (extra <= 0) return minima;
  final w = [for (final m in kModules) m.share];
  final total = w.fold<double>(0, (a, b) => a + b);
  return [for (var i = 0; i < kModules.length; i++) minima[i] + extra * w[i] / total];
}

/// One module on the desk: its name stamped on an index card laid over the top of it, and as much
/// of it as fits under that.
class _Section extends StatelessWidget {
  const _Section({
    required this.module,
    required this.ctx,
    required this.row,
    required this.onOpen,
  });

  final Module module;
  final ModuleContext ctx;
  final int row;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: kUsSectionGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // one fixed height, so the desk can subtract its own chrome before it shares out the rest
          SizedBox(
            height: kUsHeading,
            child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 2),
            child: Slip(
              id: 'us.${module.id}',
              row: row,
              stock: 'index',
              torn: false,
              width: 236,
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 7),
              onTap: onOpen,
              // The label and the glance used to share one line on a card two hundred points
              // wide, and there was never room: three of the four cards read `next: the …`,
              // `us in 65 d…`. A card is a card — the name is stamped on it and what it would
              // tell you is written under the stamp, on the next line, where it fits.
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Stamped(module.label, size: 11),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    module.glance(ctx.events, ctx.now),
                    style: Hands.margin(size: 12.5),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          ),
          module.build(context, ctx),
        ],
      ),
    );
  }
}

/// One module, pushed open on its own.
class _Alone extends StatelessWidget {
  const _Alone({required this.module, required this.ctx});
  final Module module;
  final ModuleContext ctx;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: DeskColour.day,
    body: Desk(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(),
                child: Row(
                  children: [
                    Mark.turnback(size: 18),
                    const SizedBox(width: 8),
                    Stamped(module.label, size: 12),
                  ],
                ),
              ),
            ),
            Expanded(child: module.build(context, ctx)),
          ],
        ),
      ),
    ),
  );
}
