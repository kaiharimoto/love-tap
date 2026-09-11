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

/// A length of time, said one way everywhere: `m:ss`.
///
/// One grammar and one rounding, because there were three of each. The viewer rounded 2500 ms to
/// `0:03` while the gallery truncated the same recording to `2s` and the thread row wrote `0:02`,
/// so one clip had three lengths in one evidence set. [total] is the length of a thing rather than
/// a position in it, and it rounds up — a two-and-a-half-second clip is not over at 0:02; a
/// position floors, because you are not three seconds in until you are.
///
/// A messenger critic read `0:00 / 0:03` off the viewer for a position of 625 ms in 2500 and
/// called the two ends of one readout inconsistent. They are, and deliberately: an elapsed clock
/// and a duration are two different questions, and every media player on earth answers them this
/// way. Tenths were tried here and reverted — one grammar for a length of time, everywhere, is a
/// rule three cycles of reports rest on, and the readout's oddity is confined to clips under three
/// seconds, which in this build only the seeded stubs are.
String clockOf(int ms, {bool total = false}) {
  final s = ms <= 0 ? 0 : (total ? (ms + 999) ~/ 1000 : ms ~/ 1000);
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// A day, said the way a person says it: `Tue 4 Aug` — and empty rather than echoed back when
/// there is no day at all.
///
/// Takes whatever the thing it is labelling keeps its time in — an ISO string out of a payload,
/// milliseconds off an event, a DateTime. It used to take only a string, and Moments passed it an
/// event's own `ts`, which is an integer: every voice note on that screen read `teo · ` with the
/// separator drawn and nothing after it.
String dayLabel(Object? when) {
  final t = switch (when) {
    String s => DateTime.tryParse(s),
    int ms => DateTime.fromMillisecondsSinceEpoch(ms),
    DateTime d => d,
    _ => null,
  };
  return t == null ? '' : DateFormat('EEE d MMM').format(t.toLocal());
}
