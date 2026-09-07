// A shared-life module.
//
// A module owns nothing: it writes its events into the single spine and reads them back as a
// projection, so its history is the couple's history and cannot drift. Adding one is a directory
// under modules/ and one line in registry.dart — the existing modules are not touched.
import 'package:flutter/widgets.dart';

import '../spine/spine.dart';
import 'fit_rows.dart';

abstract class Module {
  const Module();

  /// Stable id, used for the tab and for nothing else.
  String get id;

  /// The stamped label on its tab in Us.
  String get label;

  /// The event types this module writes. They must already be in the spine registry
  /// (docs/EVENT_TYPES.md); a module may share a type with another.
  List<String> get eventTypes;

  /// The module's surface inside Us.
  Widget build(BuildContext context, ModuleContext ctx);

  /// A short line for the Us overview: what this module would tell you at a glance.
  String glance(List<Event> events);

  /// What one whole row of this module costs on the shared desk, in logical points.
  ///
  /// Us budgets the desk in points, not in rows: it subtracts one row of every module from the
  /// space it has and shares out what is left, so every module is on the glass with something
  /// under its heading. The number only has to be close — [FitRows] enforces the real budget by
  /// laying the rows out — but if it is badly wrong one module takes more of the desk than it
  /// should, so it is measured, not guessed.
  double get rowHeight;
}

/// What a module is given: the log, who is holding the phone, the clock, and the one way to write.
class ModuleContext {
  const ModuleContext({
    required this.events,
    required this.me,
    required this.partner,
    required this.now,
    required this.emit,
    this.limit,
    this.room,
  });

  /// Every event in the spine, in order. A module filters for its own.
  final List<Event> events;
  final Person me;
  final Person partner;
  final DateTime now;

  /// The only way anything is written.
  final Future<Event> Function(String type, Map<String, dynamic> payload) emit;

  /// The points of desk this module has been given, when it is one of five on the Us desk. Null
  /// when the module has been pushed open on its own. A module hands its rows to [fit], which
  /// keeps the ones that fit whole.
  final double? room;

  /// How many rows there is room for, when a module is one of four on the Us desk. Null when the
  /// module has been pushed open on its own and can run to whatever length it is.
  ///
  /// This exists because the alternative did not work: Us gave each module a fixed-height window
  /// onto its own scroller, and a window cuts wherever it lands — a to-do read `get someone out to
  /// look at the` and then stopped at a hard horizontal edge, which is a rendering fault, not a
  /// stack of paper. A module that is handed a limit lays out that many whole rows and ends.
  final int? limit;

  /// The first [limit] of something, or all of it when there is no limit.
  List<T> few<T>(List<T> xs) => limit == null ? xs : xs.take(limit!).toList();

  /// True when the module is a section on the shared desk rather than open on its own: it should
  /// lay itself out at its natural height and not scroll, because Us is the scroller.
  bool get onTheDesk => limit != null;

  List<Event> ofTypes(List<String> types) => events.where((e) => types.contains(e.type)).toList();

  /// The same context, with room for [rows] of whatever the module lists.
  ModuleContext only(int rows) => ModuleContext(
        events: events, me: me, partner: partner, now: now, emit: emit, limit: rows,
      );

  /// The same context, given [points] of desk. The limit is a coarse cap on how many rows are
  /// built at all — the exact cut is made by [fit], which can see what a row costs.
  ModuleContext inRoom(double points, double rowHeight) => ModuleContext(
        events: events, me: me, partner: partner, now: now, emit: emit,
        limit: (points / rowHeight).ceil() + 2, room: points,
      );

  /// A module's rows on the shared desk: as many whole rows as its share of the desk pays for.
  /// Outside the desk this is a plain column and every row is kept.
  Widget fit(List<Widget> rows) => room == null
      ? Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: rows)
      : FitRows(maxHeight: room!, children: rows);

  /// The same context with no limit at all: the module opened on its own.
  ModuleContext whole() => ModuleContext(
        events: events, me: me, partner: partner, now: now, emit: emit,
      );
}
