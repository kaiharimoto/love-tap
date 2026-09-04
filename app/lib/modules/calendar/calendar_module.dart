// The dates that matter: anniversaries and firsts, stamped on cards, counting down.
import 'package:flutter/material.dart';

import '../../material/hands.dart';
import '../../material/palette.dart';
import '../../material/slip.dart';
import '../../spine/spine.dart';
import '../module.dart';

class CalendarModule extends Module {
  const CalendarModule();

  @override
  String get id => 'calendar';

  @override
  String get label => 'dates that matter';

  @override
  List<String> get eventTypes => const ['milestone'];

  @override
  Widget build(BuildContext context, ModuleContext ctx) => MilestoneList(ctx: ctx);

  @override
  String glance(List<Event> events) {
    final now = DateTime.now();
    final next = projectMilestones(events)
        .map((m) => (m, m.nextOccurrence(now)))
        .where((p) => p.$2 != null)
        .toList()
      ..sort((a, b) => a.$2!.compareTo(b.$2!));
    if (next.isEmpty) return 'nothing marked';
    final days = next.first.$2!.difference(now).inDays;
    return '${next.first.$1.title} in $days days';
  }
}

class Milestone {
  Milestone(this.id);
  final String id;
  String title = '';
  String kind = 'custom';
  DateTime? date;
  bool yearly = false;
  Person? by;

  DateTime? nextOccurrence(DateTime from) {
    final d = date;
    if (d == null) return null;
    if (!yearly) return d.isAfter(from) ? d : null;
    var next = DateTime(from.year, d.month, d.day);
    if (next.isBefore(from)) next = DateTime(from.year + 1, d.month, d.day);
    return next;
  }

  int yearsAt(DateTime when) => date == null ? 0 : when.year - date!.year;
}

List<Milestone> projectMilestones(List<Event> events) {
  final byId = <String, Milestone>{};
  for (final e in events) {
    if (e.type != 'milestone') continue;
    final id = e.payload['milestone_id'] as String;
    final m = byId.putIfAbsent(id, () => Milestone(id));
    m.title = (e.payload['title'] as String?) ?? m.title;
    m.kind = (e.payload['kind'] as String?) ?? m.kind;
    m.yearly = e.payload['yearly'] == true;
    final d = e.payload['date'] as String?;
    if (d != null) m.date = DateTime.tryParse(d) ?? m.date;
    m.by = e.author;
  }
  return byId.values.toList();
}

class MilestoneList extends StatelessWidget {
  const MilestoneList({super.key, required this.ctx});
  final ModuleContext ctx;

  @override
  Widget build(BuildContext context) {
    final all = projectMilestones(ctx.events);
    final withNext = all.map((m) => (m, m.nextOccurrence(ctx.now))).toList()
      ..sort((a, b) {
        if (a.$2 == null) return 1;
        if (b.$2 == null) return -1;
        return a.$2!.compareTo(b.$2!);
      });
    if (all.isEmpty) {
      return Center(child: Text('no dates that matter yet. add the first.', style: Hands.margin(size: 15)));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 90),
      children: [
        for (final (i, (m, next)) in withNext.indexed) _Card(m: m, next: next, now: ctx.now, row: i),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.m, required this.next, required this.now, this.row = 0});
  final Milestone m;
  final DateTime? next;
  final DateTime now;
  final int row;

  @override
  Widget build(BuildContext context) {
    final days = next?.difference(now).inDays;
    // A day that matters was written on a card and kept, not torn off anything.
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 5, 16, 5),
      child: Slip(
        id: m.id,
        row: row,
        torn: false,
        stock: 'index',
        width: MediaQuery.sizeOf(context).width - 28,
        padding: const EdgeInsets.fromLTRB(15, 12, 15, 13),
        child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(m.title, style: Hands.of(m.by ?? Person.noor, size: 19)),
                const SizedBox(height: 3),
                Row(children: [
                  Stamped(m.kind, size: 9, colour: Pen.margin),
                  const SizedBox(width: 8),
                  if (m.date != null)
                    Text('${m.date!.day}/${m.date!.month}/${m.date!.year}', style: Hands.margin(size: 13)),
                ]),
              ],
            ),
          ),
          if (days != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$days', style: Hands.stamp(size: 22, colour: Pen.stamp, spacing: 0)),
                Stamped(days == 1 ? 'day' : 'days', size: 9, colour: Pen.margin),
                if (m.yearly && next != null)
                  Text('${m.yearsAt(next!)} years', style: Hands.margin(size: 11)),
              ],
            ),
        ],
        ),
      ),
    );
  }
}
