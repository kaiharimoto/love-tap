// One renderer per event type, keyed by the id the registry declares.
//
// docs/EVENT_TYPES.md and spine/types.dart both promise that adding an event type is one entry in
// the registry and one renderer. That promise was not true twice over. First the `renderer` field
// named a directory that did not exist and no code read it, while the thread and the search
// results each carried their own copy of a per-type switch — so a type added to one and forgotten
// in the other rendered correctly in the thread and as a bare registry id in search. Then, when
// the switch became this table, the table lived in the chat region and drew every module's rows:
// a fifth module meant editing a file in a region that has nothing to do with it, and the module
// had no say in how its own events looked.
//
// So the table is assembled here, out of the region, from three places: the messenger's own
// bodies below, the feelings' (feelings/authored_row.dart), and each module's (`Module.bodies`).
// The same three own the sentence an event reads as away from the thread. thread_types_test holds
// both halves together — every id the registry declares has a body here, every body here is
// declared by a type — and module_costs_test holds the second promise: no file outside a module's
// own directory names that module's event types, except the spine registry.
//
// A renderer is a function from an event and its context to the widget that stands for it in the
// thread, plus the one sentence it reads as everywhere else — in search results, in a
// notification, and in the standing line on the lock screen. Both come from the same place, so
// they cannot disagree.
import 'package:flutter/material.dart';

import '../feelings/authored_row.dart';
import '../material/hands.dart';
import '../material/objects.dart';
import '../material/palette.dart';
import '../modules/registry.dart';
import '../spine/spine.dart';
import '../regions/chat/blob_widgets.dart';
import 'note_body.dart';

export 'note_body.dart' show NoteContext, ThreadBody, timeLabel, whenLabel, dayLabel;

Widget _written(NoteContext c) => Written(c.item.text ?? '', by: c.item.author, size: 19);

Widget _print(NoteContext c) => Print(
  item: c.item,
  hash: c.payload['blob'] as String,
  aspect: (c.payload['w'] as num) / (c.payload['h'] as num),
  caption: c.item.text,
);

Widget _printTab(NoteContext c) => Print(
  item: c.item,
  hash: c.payload['poster_blob'] as String,
  aspect: (c.payload['w'] as num) / (c.payload['h'] as num),
  caption: c.item.text,
  durationMs: (c.payload['duration_ms'] as num).toInt(),
);

Widget _stripWave(NoteContext c) => VoiceNotePlayer(
  hash: c.payload['blob'] as String,
  durationMs: (c.payload['duration_ms'] as num).toInt(),
  waveform: (c.payload['waveform'] as List).map((x) => (x as num).toDouble()).toList(),
);

/// A feeling that arrived: the object itself, at the size a thing is, with its name underneath in
/// the small hand a caption is written in.
///
/// It used to be the object at 96 points beside its name set in the author's own hand at 19 —
/// which is byte for byte the call [_written] makes for a message body, in the same ink, on the
/// same lined stock with the same tear and the same timestamp under it. A reader saw a message
/// that happened to say "hold". The row's whole job is that a gesture on one device arrives as a
/// sensation rather than as a sentence, so the object is now the row and the word is a caption.
Widget objectLanding(NoteContext c) {
  final f = c.registry.byId(c.payload['feeling_id'] as String? ?? '');
  if (f == null) return const SizedBox.shrink();
  final intensity = (c.payload['intensity'] as num?)?.toDouble() ?? 0.7;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    mainAxisSize: MainAxisSize.min,
    children: [
      FeelingObject(
        feeling: f,
        size: 128,
        intensity: intensity,
        // this one *is* the note: a drawn feeling is drawn on the sheet it arrived on, and a
        // scrap laid over it would be a sticker on a letter
        onPaper: false,
      ),
      const SizedBox(height: 4),
      Text(f.name, style: Hands.margin(size: 13), textAlign: TextAlign.center),
    ],
  );
}

/// The types that are a line in the margin rather than a piece of paper: state, the modules,
/// a ping, a feeling somebody made. All of them read as one sentence in pencil.
Widget marginSentence(NoteContext c) => Text(
  summaryOf(c.event, me: c.me),
  style: Hands.margin(size: 14).copyWith(color: Pen.margin),
);

/// Reactions, read markers, edits and deletes never stand as rows: they change a row that is
/// already there. A renderer is still declared for them so the registry has no holes, and it
/// says so rather than drawing nothing by accident.
Widget _neverARow(NoteContext c) => const SizedBox.shrink();

/// A nudge for later: what it says, and when it will say it, on a corner turned down.
Widget foldedClock(NoteContext c) {
  final p = c.event.payload;
  return Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(child: Written('${p['text'] ?? ''}', by: c.event.author, size: 17)),
      const SizedBox(width: 10),
      Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Stamped('later', size: 8.5, colour: Pen.margin),
          Text(whenLabel(p['fires_at']), style: Hands.margin(size: 12.5)),
        ],
      ),
    ],
  );
}

/// The whole table: the messenger's own bodies, the feelings', and every module's.
///
/// Assembled rather than written out, because a module that cannot say how its own events look is
/// a module with a shared file in somebody else's region — which is what this was.
final Map<String, ThreadBody> kThreadRenderers = {
  'note': _written,
  'print': _print,
  'print_tab': _printTab,
  'strip_wave': _stripWave,
  'object_landing': objectLanding,
  'stuck_object': _neverARow,
  'edit_mark': _neverARow,
  'stub': _neverARow,
  'ink_dries': _neverARow,
  'margin_note': marginSentence,
  'margin_mark': marginSentence,
  'folded_clock': foldedClock,
  'new_feeling_card': newFeelingCard,
  for (final m in kModules) ...m.bodies,
};

/// The one sentence an event reads as away from the thread.
///
/// Search results, notification bodies and the ambient standing line all come through here, so a
/// type cannot say one thing in the thread and another on a lock screen.
String summaryOf(Event e, {Person? me}) {
  final p = e.payload;
  final who = me == null ? e.author.name : (e.author == me ? 'you' : e.author.name);
  switch (e.type) {
    case 'message':
      return (p['text'] as String?) ?? '';
    case 'photo':
      return (p['caption'] as String?)?.isNotEmpty == true
          ? '$who sent a photograph — ${p['caption']}'
          : '$who sent a photograph';
    case 'video':
      return '$who sent a video, ${_seconds(p['duration_ms'])}';
    case 'voice_note':
      return '$who left ${_seconds(p['duration_ms'])} of talking';
    case 'feeling':
      return '$who sent ${p['feeling_id']}';
    case 'reaction':
      return '$who put ${p['feeling_id']} on it';
    case 'message_edit':
      return '$who changed it to ${p['text']}';
    case 'message_delete':
      return '$who took it back';
    case 'read_marker':
      return '$who has read up to here';
    case 'state_declared':
      return _stateSentence(who, p, declared: true);
    case 'state_passive':
      return _stateSentence(who, p, declared: false);
    case 'ping':
      return '${p['text']} · ${whenLabel(p['fires_at'])}';
    case 'feeling_authored':
      return '$who made ${p['name']}';
    default:
      // A module's own events read in the module's own words: a date, a line off the list, a day
      // that matters, a ritual kept, a thing passed on. They used to be five cases in this switch,
      // which meant a fifth module had a sentence written for it in the chat region, or — as
      // happened — no sentence at all and its registry id shown to a reader.
      for (final m in kModules) {
        final line = m.sentence(e, who);
        if (line != null) return line;
      }
      return (p['text'] as String?) ?? e.type;
  }
}

String _seconds(Object? ms) {
  final n = (ms as num?)?.toInt() ?? 0;
  final s = (n / 1000).round();
  if (s < 60) return '$s seconds';
  final m = s ~/ 60;
  final rest = s % 60;
  return rest == 0 ? '$m minutes' : '$m minutes ${rest}s';
}

String _stateSentence(String who, Map<String, dynamic> p, {required bool declared}) {
  final signal = p['signal'] as String? ?? '';
  final value = p['value'];
  final words = '$value'.replaceAll('_', ' ');
  // The line about the person reading it is about *you*, and you takes a plural verb. It read
  // "you is heads down" and "you's phone is on normal", which is nobody's voice.
  final youAre = who == 'you';
  final are = youAre ? 'are' : 'is';
  final has = youAre ? 'have' : 'has';
  final was = youAre ? 'were' : 'was';
  final theirs = youAre ? 'your' : "$who's";
  return switch (signal) {
    'mood' => '$who $are $words',
    'availability' => '$who $are $words',
    'place' => '$who · $words',
    'need' => youAre ? 'you need ${_dial(value)}' : '$who needs ${_dial(value)}',
    'energy' => '$who $has ${_dial(value)} left',
    'status_line' => '$who: $words',
    'battery' => value == 'low' ? '$theirs phone is nearly out' : '$theirs phone is on $words',
    // a passive notice is a change, so it reads as one: the phone noticed them arrive, it did
    // not take a reading of where they are
    'at_home' => value == true || value == 'true' ? '$who got in' : '$who went out',
    'ringer' => '$theirs phone is on $words',
    'moving' => '$who $are $words',
    'network' => '$theirs signal is $words',
    'local_hour' => 'it is $words where $who $are',
    'last_active' => '$who $was up $words',
    'charging' => '$who $are charging',
    _ => '$who · $signal $words',
  };
}

String _dial(Object? value) {
  final n = value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  return switch (n) {
    <= 0 => 'nothing',
    1 => 'a little',
    2 => 'some',
    3 => 'a lot',
    _ => 'everything',
  };
}
