// Rituals: a quiet record of the things they actually do.
//
// The brief is exact about this one, and so is the app: no streak, no count, no best run, no reset,
// no broken state, and nothing that can be failed. What is kept is a tally in the margin — the
// marks a person makes beside a habit — and the marks simply stop when a week goes by without one.
// Nothing nags: the only thing that ever arrives on the other phone is what one of them wrote.
import 'package:flutter/material.dart';

import '../../material/hands.dart';
import '../../material/palette.dart';
import '../../material/slip.dart';
import '../../spine/spine.dart';
import '../module.dart';

class RitualsModule extends Module {
  const RitualsModule();

  @override
  String get id => 'rituals';

  @override
  String get label => 'rituals';

  @override
  List<String> get eventTypes => const ['ritual_kept'];

  @override
  Widget build(BuildContext context, ModuleContext ctx) => RitualList(ctx: ctx);

  @override
  String glance(List<Event> events) {
    final r = projectRituals(events);
    if (r.isEmpty) return 'nothing kept yet';
    final recent = r.where((x) => x.marks.isNotEmpty).toList()
      ..sort((a, b) => b.marks.last.compareTo(a.marks.last));
    return recent.isEmpty ? 'nothing kept yet' : 'last: ${recent.first.title}';
  }
}

class Ritual {
  Ritual(this.id);
  final String id;
  String title = '';
  Person? by;

  /// When it was kept, in order. Never counted aloud.
  final List<DateTime> marks = [];
  final List<String> notes = [];
}

List<Ritual> projectRituals(List<Event> events) {
  final byId = <String, Ritual>{};
  for (final e in events) {
    if (e.type != 'ritual_kept') continue;
    // A projection is handed whatever is in the log, including whatever the other phone
    // sent, so it may not assume a payload is well formed: an event missing the key that
    // identifies it used to take down the whole module and with it the whole screen.
    final id = e.payload['ritual_id'] as String?;
    if (id == null) continue;
    final r = byId.putIfAbsent(id, () => Ritual(id));
    r.title = (e.payload['title'] as String?) ?? r.title;
    r.by = e.author;
    final kept = e.payload['kept_at'] as String?;
    r.marks.add(DateTime.tryParse(kept ?? '') ?? DateTime.fromMillisecondsSinceEpoch(e.ts));
    final note = e.payload['note'] as String?;
    if (note != null) r.notes.add(note);
  }
  return byId.values.toList();
}

class RitualList extends StatelessWidget {
  const RitualList({super.key, required this.ctx});
  final ModuleContext ctx;

  @override
  Widget build(BuildContext context) {
    final rituals = projectRituals(ctx.events);
    if (rituals.isEmpty) {
      return Center(child: Text('nothing kept yet.', style: Hands.margin(size: 15)));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 90),
      children: [
        for (final (i, r) in rituals.indexed) _Ritual(r: r, ctx: ctx, row: i),
      ],
    );
  }
}

class _Ritual extends StatelessWidget {
  const _Ritual({required this.r, required this.ctx, required this.row});
  final Ritual r;
  final ModuleContext ctx;
  final int row;

  @override
  Widget build(BuildContext context) {
    // the marks of the last eight weeks, as they were made: a mark, or nothing
    final weeks = <DateTime, int>{};
    for (final m in r.marks) {
      final monday = DateTime(m.year, m.month, m.day).subtract(Duration(days: m.weekday - 1));
      weeks[monday] = (weeks[monday] ?? 0) + 1;
    }
    final thisMonday = DateTime(ctx.now.year, ctx.now.month, ctx.now.day)
        .subtract(Duration(days: ctx.now.weekday - 1));
    final lastEight = [for (var i = 7; i >= 0; i--) thisMonday.subtract(Duration(days: 7 * i))];
    return GestureDetector(
      onTap: () => ctx.emit('ritual_kept', {
        'ritual_id': r.id,
        'title': r.title,
        'kept_at': ctx.now.toIso8601String(),
      }),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 5, 18, 5),
        child: Slip(
          id: r.id,
          row: row,
          stock: 'graph',
          width: MediaQuery.sizeOf(context).width - 30,
          padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(r.title, style: Hands.of(r.by ?? ctx.me, size: 19)),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final w in lastEight)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: _Tally(
                        marks: weeks[w] ?? 0,
                        ink: (r.by ?? ctx.me) == Person.noor ? Pen.ballpoint : Pen.graphite,
                      ),
                    ),
                ],
              ),
              if (r.notes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(r.notes.last, style: Hands.margin(size: 14)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tally marks for one week: one stroke per time it was kept, and nothing at all when it was not.
/// There is no zero, no gap marker and no colour for a week that passed without it.
class _Tally extends StatelessWidget {
  const _Tally({required this.marks, required this.ink});
  final int marks;
  final Color ink;

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: 22, height: 22, child: CustomPaint(painter: _TallyPainter(marks, ink)));
}

class _TallyPainter extends CustomPainter {
  _TallyPainter(this.marks, this.ink);
  final int marks;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    if (marks <= 0) return;
    final p = Paint()
      ..color = ink.withValues(alpha: 0.85)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < marks.clamp(0, 4); i++) {
      final x = 3.0 + i * 4.5;
      canvas.drawLine(Offset(x, size.height * 0.15), Offset(x + 1.5, size.height * 0.85), p);
    }
    if (marks >= 5) {
      canvas.drawLine(Offset(1, size.height * 0.8), Offset(size.width - 2, size.height * 0.2), p);
    }
  }

  @override
  bool shouldRepaint(_TallyPainter old) => old.marks != marks || old.ink != ink;
}
