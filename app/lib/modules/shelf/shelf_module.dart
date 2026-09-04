// The shelf: what they have handed each other, and how far the other one got.
//
// A couple passes things between them constantly — a book left on the arm of a chair, a film one
// of them will not stop mentioning, a record put on twice in a week — and nothing anywhere keeps
// track of it. It is not a to-do (nothing is owed), not a date (it is not a plan), not a milestone
// (it has no day), and not a ritual (it happens once). It is its own thing, so it is its own
// module.
//
// What it holds is one question: has the other one got to it yet, and what did they say when they
// did. That is the whole shape of it, and it is why a row is a card with two hands on it — one
// person passed it on, and the other one wrote back underneath.
import 'package:flutter/material.dart';

import '../../material/hands.dart';
import '../../material/palette.dart';
import '../../material/slip.dart';
import '../../spine/spine.dart';
import '../module.dart';

class ShelfModule extends Module {
  const ShelfModule();

  @override
  String get id => 'shelf';

  @override
  String get label => 'the shelf';

  @override
  List<String> get eventTypes => const ['passed_on'];

  @override
  Widget build(BuildContext context, ModuleContext ctx) => ShelfList(ctx: ctx);

  @override
  String glance(List<Event> events) {
    final things = projectShelf(events);
    if (things.isEmpty) return 'nothing passed on yet';
    final waiting = things.where((t) => t.state == 'passed').toList();
    if (waiting.isEmpty) return 'last: ${things.last.title}';
    return 'waiting on you: ${waiting.last.title}';
  }
}

/// One thing on the shelf, folded up from every event about it.
class Thing {
  Thing(this.id);
  final String id;
  String title = '';
  String kind = 'book';

  /// passed → started → finished. Nothing is ever overdue and nothing is ever failed: a thing
  /// left at `passed` for a year is a thing they have not got to.
  String state = 'passed';
  Person? from;
  Person? by;
  String? note;
  int lastTs = 0;
}

List<Thing> projectShelf(List<Event> events) {
  final byId = <String, Thing>{};
  for (final e in events) {
    if (e.type != 'passed_on') continue;
    final id = e.payload['item_id'] as String?;
    if (id == null) continue;
    final t = byId.putIfAbsent(id, () => Thing(id));
    t.title = (e.payload['title'] as String?) ?? t.title;
    t.kind = (e.payload['kind'] as String?) ?? t.kind;
    final action = e.payload['action'] as String?;
    if (action == 'passed') {
      t.from = e.author;
    } else if (action != null) {
      t.state = action;
      t.by = e.author;
    }
    final note = e.payload['note'] as String?;
    if (note != null && note.isNotEmpty) t.note = note;
    t.lastTs = e.ts;
  }
  final all = byId.values.toList()..sort((a, b) => a.lastTs.compareTo(b.lastTs));
  return all;
}

class ShelfList extends StatelessWidget {
  const ShelfList({super.key, required this.ctx});
  final ModuleContext ctx;

  @override
  Widget build(BuildContext context) {
    final things = projectShelf(ctx.events).reversed.toList();
    if (things.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(14),
        child: Text('nothing passed between you yet.', style: Hands.margin(size: 15)),
      );
    }
    final rows = [
      for (final (i, t) in ctx.few(things).indexed) _Thing(thing: t, ctx: ctx, row: i),
    ];
    if (ctx.onTheDesk) {
      return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows);
    }
    return ListView(padding: const EdgeInsets.fromLTRB(4, 8, 4, 90), children: rows);
  }
}

class _Thing extends StatelessWidget {
  const _Thing({required this.thing, required this.ctx, required this.row});
  final Thing thing;
  final ModuleContext ctx;
  final int row;

  /// What the next tap does. There is no button anywhere: the card says where the thing has got
  /// to, and touching it moves it on one step, which is the only thing anybody ever wants to do.
  String? get _next => switch (thing.state) {
        'passed' => 'started',
        'started' => 'finished',
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final mine = thing.from != ctx.me;
    final where = switch (thing.state) {
      'passed' => mine ? 'not started' : 'they have not started it',
      'started' => mine ? 'part way in' : 'they are part way in',
      _ => mine ? 'finished' : 'they finished it',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 5, 18, 5),
      child: Slip(
        id: thing.id,
        row: row,
        stock: 'index',
        width: MediaQuery.sizeOf(context).width - 30,
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
        onTap: _next == null
            ? null
            : () => ctx.emit('passed_on', {
                  'item_id': thing.id,
                  'title': thing.title,
                  'kind': thing.kind,
                  'action': _next!,
                }),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(thing.title,
                      style: Hands.of(thing.from ?? ctx.me, size: 19), maxLines: 2),
                ),
                const SizedBox(width: 10),
                Stamped(thing.kind, size: 10),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              thing.from == null ? where : '${thing.from!.name} passed it on · $where',
              style: Hands.margin(size: 13),
            ),
            if (thing.note != null)
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Text(thing.note!,
                    style: Hands.of(thing.by ?? ctx.partner, size: 15, colour: Pen.margin)),
              ),
          ],
        ),
      ),
    );
  }
}
