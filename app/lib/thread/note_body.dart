// What a renderer is handed, and the two or three labels every renderer needs.
//
// This is the smallest thing a module has to know about the thread in order to draw its own rows
// there. It lives outside every region on purpose: the bodies for a date, a line off the list, a
// day that matters, a ritual kept and a thing passed on used to be written in the chat region's
// own file, so adding a fifth module meant editing a sixth shared file in a region that has
// nothing to do with it. A module now brings its own bodies (`Module.bodies`) and its own
// sentence (`Module.sentence`), and what it imports to do that is this file and nothing else.
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../feelings/registry.dart';
import '../spine/projections/thread.dart';
import '../spine/spine.dart';

/// Everything a renderer is allowed to know.
class NoteContext {
  const NoteContext({
    required this.item,
    required this.registry,
    required this.me,
    required this.context,
  });

  final ThreadItem item;
  final FeelingRegistry registry;
  final Person me;
  final BuildContext context;

  Event get event => item.event;
  Map<String, dynamic> get payload => item.event.payload;
  bool get mine => item.author == me;
}

/// A row in the thread: an event, and the widget that stands for it.
typedef ThreadBody = Widget Function(NoteContext c);

/// The line under a piece of paper: the day and the time it was written.
String timeLabel(int ts) =>
    DateFormat('EEE d MMM · HH:mm').format(DateTime.fromMillisecondsSinceEpoch(ts).toLocal());

/// A day, in the words a person would say it in. Anything that is not a date comes back as it
/// was — a stored timestamp shown to a reader is a fault, and this is where it would show.
String whenLabel(Object? at) {
  final t = DateTime.tryParse('$at');
  return t == null ? '$at' : DateFormat('EEE d MMM').format(t.toLocal());
}

/// The same, but empty rather than echoed when there is no day at all.
String dayLabel(Object? iso) {
  final t = iso is String ? DateTime.tryParse(iso) : null;
  return t == null ? '' : DateFormat('EEE d MMM').format(t.toLocal());
}
