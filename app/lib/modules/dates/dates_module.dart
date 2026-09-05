// Dates: planning, scheduling, doing, saying what it was, remembering. Every step is a date_event in the
// spine, so a date that was planned in May and written up in July is one thread of the same history.

import 'package:flutter/material.dart';

import '../../material/hands.dart';
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
    final upcoming = dates.where((d) => d.when != null && d.state != 'done' && d.state != 'said').toList()
      ..sort((a, b) => a.when!.compareTo(b.when!));
    if (upcoming.isNotEmpty) return 'next: ${upcoming.first.title}';
    final done = dates.where((d) => d.state == 'said' || d.state == 'done').toList();
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
  /// What they said about it afterwards, in words.
  ///
  /// Never a score. It was five pencil stars out of five on a ticket stub, and a review
  /// widget attached to an evening you spent with someone quantifies the relationship,
  /// which is the thing the first anti-goal exists to forbid. The seeded year's twenty-five
  /// ratings were rewritten into the sentences a person would actually say.
  String? verdict;
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
    final verdict = e.payload['verdict'];
    if (verdict is String && verdict.isNotEmpty) d.verdict = verdict;
    d.state = (e.payload['action'] as String?) ?? d.state;
    d.by = e.author;
    d.lastTs = e.ts;
  }
  final list = byId.values.toList()..sort((a, b) => a.lastTs.compareTo(b.lastTs));
  return list;
}

/// A date's line in the thread and in Us.
String describeDate(DateItem d) {
  final bits = <String>[d.title];
  if (d.place != null) bits.add(d.place!);
  if (d.verdict != null) bits.add(d.verdict!);
  if (d.note != null) bits.add(d.note!);
  return bits.join(' · ');
}

/// The hand a date's title is written in.
TextStyle dateStyle(Person by) => Hands.of(by, size: 19);
