// One renderer per event type, keyed by the id the registry declares.
//
// docs/EVENT_TYPES.md and spine/types.dart both promise that adding an event type is one entry in
// the registry and one renderer. That promise was not true: the `renderer` field named a directory
// that did not exist and no code read it, while the thread and the search results each carried
// their own copy of a per-type switch — so a type added to one and forgotten in the other rendered
// correctly in the thread and as a bare registry id in search. This file is the renderer half of
// the promise, and thread_types_test asserts the two halves match: every id the registry declares
// has a renderer here, and every renderer here is declared by a type.
//
// A renderer is a function from an event and its context to the widget that stands for it in the
// thread, plus the one sentence it reads as everywhere else — in search results, in a
// notification, and in the standing line on the lock screen. Both come from the same place, so
// they cannot disagree.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../feelings/registry.dart';
import '../../material/hands.dart';
import '../../material/objects.dart';
import '../../material/palette.dart';
import '../../spine/projections/thread.dart';
import '../../spine/spine.dart';
import 'blob_widgets.dart';

String timeLabel(int ts) =>
    DateFormat('EEE d MMM · HH:mm').format(DateTime.fromMillisecondsSinceEpoch(ts).toLocal());

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

typedef ThreadBody = Widget Function(NoteContext c);

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

Widget _objectLanding(NoteContext c) {
  final f = c.registry.byId(c.payload['feeling_id'] as String? ?? '');
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (f != null)
        FeelingObject(
          feeling: f,
          size: 96,
          intensity: (c.payload['intensity'] as num?)?.toDouble() ?? 0.7,
          // this one *is* the note: a drawn feeling is drawn on the sheet it arrived on, and a
          // scrap laid over it would be a sticker on a letter
          onPaper: false,
        ),
      const SizedBox(width: 10),
      Flexible(child: Written(f?.name ?? '', by: c.item.author, size: 19)),
    ],
  );
}

/// The types that are a line in the margin rather than a piece of paper: state, the modules,
/// a ping, a feeling somebody made. All of them read as one sentence in pencil.
Widget marginSentence(NoteContext c) =>
    Text(summaryOf(c.event, me: c.me), style: Hands.margin(size: 14).copyWith(color: Pen.margin));

/// Reactions, read markers, edits and deletes never stand as rows: they change a row that is
/// already there. A renderer is still declared for them so the registry has no holes, and it
/// says so rather than drawing nothing by accident.
Widget _neverARow(NoteContext c) => const SizedBox.shrink();

const Map<String, ThreadBody> kThreadRenderers = {
  'note': _written,
  'print': _print,
  'print_tab': _printTab,
  'strip_wave': _stripWave,
  'object_landing': _objectLanding,
  'stuck_object': _neverARow,
  'edit_mark': _neverARow,
  'stub': _neverARow,
  'ink_dries': _neverARow,
  'margin_note': marginSentence,
  'margin_mark': marginSentence,
  'ticket_stub': marginSentence,
  'list_line': marginSentence,
  'stamped_card': marginSentence,
  'tally_mark': marginSentence,
  'folded_clock': marginSentence,
  'new_feeling_card': marginSentence,
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
    case 'date_event':
      final where = (p['place'] as String?)?.isNotEmpty == true ? ' at ${p['place']}' : '';
      final when = p['when'] == null ? '' : ' · ${_when(p['when'])}';
      return '${_verb(p['action'])} ${p['title']}$where$when';
    case 'todo_event':
      return '${_verb(p['action'])} ${p['text']}';
    case 'milestone':
      return '${p['title']} · ${_when(p['date'])}';
    case 'ritual_kept':
      return '${p['title']} · kept';
    case 'ping':
      return '${p['text']} · ${_when(p['fires_at'])}';
    case 'feeling_authored':
      return '$who made ${p['name']}';
    default:
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

/// The module verbs, in the words a person would use about their own list.
String _verb(Object? action) => switch ('$action') {
      'planned' => 'planning',
      'moved' => 'moved',
      'done' || 'been' => 'went to',
      'cancelled' => 'called off',
      'added' => 'put down',
      'ticked' => 'done:',
      'unticked' => 'back on the list:',
      'dropped' => 'off the list:',
      _ => '',
    };

String _when(Object? at) {
  final t = DateTime.tryParse('$at');
  return t == null ? '$at' : DateFormat('EEE d MMM').format(t.toLocal());
}

String _stateSentence(String who, Map<String, dynamic> p, {required bool declared}) {
  final signal = p['signal'] as String? ?? '';
  final value = p['value'];
  final words = '$value'.replaceAll('_', ' ');
  return switch (signal) {
    'mood' => '$who is $words',
    'availability' => '$who is $words',
    'place' => '$who · $words',
    'need' => '$who needs ${_dial(value)}',
    'energy' => '$who has ${_dial(value)} left',
    'status_line' => '$who: $words',
    'battery' => value == 'low' ? "$who's phone is nearly out" : "$who's phone is on $words",
    // a passive notice is a change, so it reads as one: the phone noticed them arrive, it did
    // not take a reading of where they are
    'at_home' => value == true || value == 'true' ? '$who got in' : '$who went out',
    'ringer' => "$who's phone is on $words",
    'moving' => '$who is $words',
    'network' => "$who's signal is $words",
    'local_hour' => "it is $words where $who is",
    'last_active' => '$who was up $words',
    'charging' => '$who is charging',
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

