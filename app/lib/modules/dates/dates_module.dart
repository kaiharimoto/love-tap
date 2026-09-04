// Dates: planning, scheduling, doing, rating, remembering. Every step is a date_event in the
// spine, so a date that was planned in May and rated in July is one thread of the same history.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../material/hands.dart';
import '../../material/palette.dart';
import '../../spine/spine.dart';
import '../module.dart';
import 'date_list.dart';

class DatesModule extends Module {
  const DatesModule();

  @override
  String get id => 'dates';

  @override
  String get label => 'dates';

  @override
  List<String> get eventTypes => const ['date_event'];

  @override
  Widget build(BuildContext context, ModuleContext ctx) => DateList(ctx: ctx);

  @override
  String glance(List<Event> events) {
    final dates = projectDates(events);
    final upcoming = dates.where((d) => d.when != null && d.state != 'done' && d.state != 'rated').toList()
      ..sort((a, b) => a.when!.compareTo(b.when!));
    if (upcoming.isNotEmpty) return 'next: ${upcoming.first.title}';
    final done = dates.where((d) => d.state == 'rated' || d.state == 'done').toList();
    if (done.isNotEmpty) return 'last: ${done.last.title}';
    return 'nothing planned';
  }
}

/// One date, folded up from its events.
class DateItem {
  DateItem(this.id);
  final String id;
  String title = '';
  String? place;
  String? note;
  DateTime? when;
  int? rating;
  String state = 'planned';
  Person? by;
  int lastTs = 0;
}

List<DateItem> projectDates(List<Event> events) {
  final byId = <String, DateItem>{};
  for (final e in events) {
    if (e.type != 'date_event') continue;
    // A projection is handed whatever is in the log, including whatever the other phone
    // sent, so it may not assume a payload is well formed: an event missing the key that
    // identifies it used to take down the whole module and with it the whole screen.
    final id = e.payload['date_id'] as String?;
    if (id == null) continue;
    final d = byId.putIfAbsent(id, () => DateItem(id));
    d.title = (e.payload['title'] as String?) ?? d.title;
    d.place = (e.payload['place'] as String?) ?? d.place;
    d.note = (e.payload['note'] as String?) ?? d.note;
    final when = e.payload['when'] as String?;
    if (when != null) d.when = DateTime.tryParse(when) ?? d.when;
    final rating = e.payload['rating'];
    if (rating is num) d.rating = rating.toInt();
    d.state = (e.payload['action'] as String?) ?? d.state;
    d.by = e.author;
    d.lastTs = e.ts;
  }
  final list = byId.values.toList()..sort((a, b) => a.lastTs.compareTo(b.lastTs));
  return list;
}

/// A rating drawn as pencil stars on a ticket stub, never as a number out of five.
class Stars extends StatelessWidget {
  const Stars({super.key, required this.rating});
  final int rating;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: CustomPaint(size: const Size(13, 13), painter: _StarPainter(filled: i <= rating)),
            ),
        ],
      );
}

class _StarPainter extends CustomPainter {
  _StarPainter({required this.filled});
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = filled ? Pen.graphite : Pen.margin.withValues(alpha: 0.4)
      ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final path = Path();
    final c = size.center(Offset.zero);
    for (var k = 0; k < 10; k++) {
      final r = k.isEven ? size.width * 0.48 : size.width * 0.2;
      final a = -math.pi / 2 + k * math.pi / 5;
      final o = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      k == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    path.close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.filled != filled;
}

/// A date's line in the thread and in Us.
String describeDate(DateItem d) {
  final bits = <String>[d.title];
  if (d.place != null) bits.add(d.place!);
  if (d.rating != null) bits.add('${d.rating}/5');
  if (d.note != null) bits.add(d.note!);
  return bits.join(' · ');
}

/// The hand a date's title is written in.
TextStyle dateStyle(Person by) => Hands.of(by, size: 19);
