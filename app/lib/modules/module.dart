// A shared-life module.
//
// A module owns nothing: it writes its events into the single spine and reads them back as a
// projection, so its history is the couple's history and cannot drift.
//
// What a module actually costs, counted rather than claimed. This file used to say "a directory
// under modules/ and one line in registry.dart", and a coherence critic counted the fifth module's
// own diff and found five shared files. Three of them are gone: the module declares its own paper
// (`stocks`, below), its own share of the desk (`rowHeight`), and Search builds its facets from
// the registry. Two are left, and one of them is deliberate:
//
//   - `app/lib/spine/types.dart`. A module's event types go in the spine's own registry, because
//     the spine validates every payload against one list before it writes it and before it takes
//     one off the wire. A module inventing its own schema is exactly what a single spine forbids,
//     so this one is not a cost to remove. What it means in practice: a new module writes its
//     types there and in docs/EVENT_TYPES.md, which is the same act.
// That is now the whole cost. The other shared file was `regions/chat/renderers.dart`, which drew
// every module's rows in the thread and wrote every module's sentence for search and the lock
// screen — two per-type switches in a region that has nothing to do with any module. A module
// brings both itself now (`bodies` and `sentence` below), the table is assembled from `kModules`
// the way the facets and the stocks already were, and `module_costs_test` counts what is left: no
// file outside a module's own directory may name that module's event types, except the spine
// registry.
import 'package:flutter/widgets.dart';

import '../spine/spine.dart';
import '../thread/note_body.dart';
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

  /// The paper each of this module's event types is written on, by type id.
  ///
  /// A module brings its own paper. The assignment used to be a switch in material/assignment.dart
  /// that every module had to be added to by hand, which is one of the shared files a fifth module
  /// cost; the switch reads this now.
  Map<String, String> get stocks => const {};

  /// How this module's events are drawn in the thread, by the renderer id the spine registry
  /// names for each type.
  ///
  /// A module's events are not a separate feed: they are written into the one spine and they turn
  /// up in the thread with everything else, on the paper the module chose. What they must not be
  /// is a pencil line in the margin saying what happened — that is what four modules had for most
  /// of this build, which is to say no presence at all.
  Map<String, ThreadBody> get bodies => const {};

  /// The one sentence one of this module's events reads as away from the thread — in search
  /// results, in a notification, and in the standing line — or null if this is not its event.
  ///
  /// [who] is already resolved to the reader's own word for the author ('you', or their name), so
  /// a module never has to know who is holding the phone.
  String? sentence(Event e, String who) => null;

  /// How much of what is left of the desk this module gets, once every module has one row.
  ///
  /// The dates and the list are what anyone reads standing up, so they ask for twice what the
  /// others do. This was a table of two module ids in the Us region — the last place outside a
  /// module's own directory that named one — so a sixth module was silently on the small share
  /// whatever it was for.
  double get share => 1.0;

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
