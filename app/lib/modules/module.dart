// A shared-life module.
//
// A module owns nothing: it writes its events into the single spine and reads them back as a
// projection, so its history is the couple's history and cannot drift. Adding one is a directory
// under modules/ and one line in registry.dart — the existing modules are not touched.
import 'package:flutter/widgets.dart';

import '../spine/spine.dart';

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
}

/// What a module is given: the log, who is holding the phone, the clock, and the one way to write.
class ModuleContext {
  const ModuleContext({
    required this.events,
    required this.me,
    required this.partner,
    required this.now,
    required this.emit,
  });

  /// Every event in the spine, in order. A module filters for its own.
  final List<Event> events;
  final Person me;
  final Person partner;
  final DateTime now;

  /// The only way anything is written.
  final Future<Event> Function(String type, Map<String, dynamic> payload) emit;

  List<Event> ofTypes(List<String> types) => events.where((e) => types.contains(e.type)).toList();
}
