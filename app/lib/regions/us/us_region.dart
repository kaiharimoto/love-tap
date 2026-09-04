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
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 96),
      children: [
        for (var i = 0; i < kModules.length; i++)
          _Section(
            module: kModules[i],
            ctx: ctx,
            row: i,
            rows: _rowsFor(kModules[i].id),
            onOpen: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                // opened on its own it gets the whole of itself: no limit, its own scroller
              builder: (_) => _Alone(module: kModules[i], ctx: ctx.whole()),
              ),
            ),
          ),
      ],
    );
  }

  /// How much of each module is on the desk before you have to move something, counted in rows
  /// rather than in points. It used to be a height, and a height cuts a row in half: a to-do read
  /// `get someone out to look at the` and then stopped at a hard horizontal edge. Rows end where
  /// the paper ends.
  ///
  /// The dates and the list are the two anyone reads standing up, so they get more of them.
  static int _rowsFor(String id) => switch (id) {
    'dates' => 2,
    'todos' => 3,
    'calendar' => 2,
    _ => 2,
  };
}

/// One module on the desk: its name stamped on an index card laid over the top of it, and as much
/// of it as fits under that.
class _Section extends StatelessWidget {
  const _Section({
    required this.module,
    required this.ctx,
    required this.row,
    required this.rows,
    required this.onOpen,
  });

  final Module module;
  final ModuleContext ctx;
  final int row;

  /// How many of the module's own rows are on the desk. Whole rows, so nothing is sliced.
  final int rows;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
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
                    module.glance(ctx.events),
                    style: Hands.margin(size: 12.5),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          module.build(context, ctx.only(rows)),
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
