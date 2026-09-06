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

import '../../feelings/builtins.dart';
import '../../feelings/registry.dart';
import '../../material/hands.dart';
import '../../material/marks.dart';
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
Widget marginSentence(NoteContext c) =>
    Text(summaryOf(c.event, me: c.me), style: Hands.margin(size: 14).copyWith(color: Pen.margin));

/// Reactions, read markers, edits and deletes never stand as rows: they change a row that is
/// already there. A renderer is still declared for them so the registry has no holes, and it
/// says so rather than drawing nothing by accident.
Widget _neverARow(NoteContext c) => const SizedBox.shrink();

// ---- the module events: each its own kind of paper -----------------------------------------
// A date, a line off the list, a day that matters, a ritual kept, a thing passed on, a nudge, a
// feeling somebody made. They used to be one pencil sentence in the margin whatever they were,
// which is to say the four modules had no presence in the thread at all; and the same event drew
// as a torn slip in Us, a bare row in Moments and a margin line here — three surfaces for one
// thing. Each of these is the body written on the event's own paper (material/assignment.dart
// picks the stock by type: index for dates and days, looseleaf for the list, graph for rituals),
// and Moments draws the same body on the same paper, so one event is one piece of paper wherever
// it turns up.

String _dayLabel(Object? iso) {
  final t = iso is String ? DateTime.tryParse(iso) : null;
  if (t == null) return '';
  return DateFormat('EEE d MMM').format(t.toLocal());
}

/// A ticket stub: the plan stamped along the top, the title in the hand that wrote it, and the
/// day and place under a perforation.
Widget ticketStub(NoteContext c) {
  final p = c.event.payload;
  final when = p['when'] == null ? '' : _when(p['when']);
  final place = (p['place'] as String?) ?? '';
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(children: [
        Stamped(_verb(p['action']).trim().isEmpty ? 'a date' : _verb(p['action']).trim(), size: 9, colour: Pen.margin),
        const Spacer(),
        if (when.isNotEmpty) Text(when, style: Hands.margin(size: 12)),
      ]),
      const SizedBox(height: 4),
      Written('${p['title'] ?? ''}', by: c.event.author, size: 18),
      if (place.isNotEmpty) ...[
        const SizedBox(height: 2),
        Text(place, style: Hands.margin(size: 13)),
      ],
      const Padding(padding: EdgeInsets.only(top: 6), child: RuleLine(seed: 41, weight: 0.8)),
    ],
  );
}

/// A line off the list: a box drawn in pencil, ticked when it was done, and the line struck
/// through when it came off.
Widget listLine(NoteContext c) {
  final p = c.event.payload;
  final action = '${p['action']}';
  final done = action == 'ticked';
  final gone = action == 'dropped';
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 3, right: 9),
        child: SizedBox(
          width: 16,
          height: 16,
          child: Stack(children: [
            const Positioned.fill(child: CustomPaint(painter: _PencilBox())),
            if (done) Positioned(left: 1, top: -4, child: Mark.tick(size: 18, colour: c.event.author == Person.noor ? Pen.ballpoint : Pen.graphite)),
          ]),
        ),
      ),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${p['text'] ?? ''}',
              style: Hands.of(c.event.author, size: 17).copyWith(
                decoration: gone ? TextDecoration.lineThrough : null,
                decorationColor: Pen.margin,
                decorationThickness: 1.4,
              ),
            ),
            Text(
              switch (action) {
                'ticked' => 'done',
                'unticked' => 'back on the list',
                'dropped' => 'off the list',
                _ => 'put down',
              },
              style: Hands.margin(size: 11.5),
            ),
          ],
        ),
      ),
    ],
  );
}

class _PencilBox extends CustomPainter {
  const _PencilBox();
  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(0.8, 0.8, size.width - 1.6, size.height - 1.6);
    final path = Path()
      ..moveTo(r.left, r.top + 0.6)
      ..lineTo(r.right - 0.4, r.top)
      ..lineTo(r.right, r.bottom - 0.5)
      ..lineTo(r.left + 0.5, r.bottom)
      ..close();
    canvas.drawPath(path, Paint()..color = Pen.margin..style = PaintingStyle.stroke..strokeWidth = 1.1);
  }

  @override
  bool shouldRepaint(_PencilBox old) => false;
}

/// A day that matters: stamped, with its date, the way a card is kept.
Widget stampedCard(NoteContext c) {
  final p = c.event.payload;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Stamped('${p['title'] ?? ''}', size: 11.5),
      const SizedBox(height: 5),
      Text(_dayLabel(p['date']).isEmpty ? _when(p['date']) : _dayLabel(p['date']), style: Hands.margin(size: 13)),
    ],
  );
}

/// A ritual kept: the name in the hand, and a tally stroke for the keeping.
Widget tallyMark(NoteContext c) {
  final p = c.event.payload;
  final n = ((p['streak'] as num?) ?? (p['count'] as num?) ?? 1).toInt().clamp(1, 7);
  return Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(child: Written('${p['title'] ?? ''}', by: c.event.author, size: 17)),
      const SizedBox(width: 8),
      SizedBox(width: 6.0 * n + 8, height: 18, child: CustomPaint(painter: _Tally(n, c.event.author == Person.noor ? Pen.ballpoint : Pen.graphite))),
      const SizedBox(width: 6),
      Stamped('kept', size: 9, colour: Pen.margin),
    ],
  );
}

class _Tally extends CustomPainter {
  const _Tally(this.n, this.colour);
  final int n;
  final Color colour;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = colour..strokeWidth = 1.6..strokeCap = StrokeCap.round;
    for (var i = 0; i < n; i++) {
      final x = 4.0 + i * 6.0;
      final lean = (i % 2 == 0 ? 0.6 : -0.4);
      canvas.drawLine(Offset(x + lean, 2), Offset(x - lean, size.height - 2), paint);
    }
    if (n >= 5) {
      canvas.drawLine(Offset(1, size.height - 4), Offset(4.0 + 5 * 6.0 - 2, 3), paint..strokeWidth = 1.3);
    }
  }

  @override
  bool shouldRepaint(_Tally old) => old.n != n || old.colour != colour;
}

/// Something passed between them — a book, a film — as the card off a shelf.
Widget shelfCard(NoteContext c) {
  final p = c.event.payload;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Written('${p['title'] ?? ''}', by: c.event.author, size: 18),
      const SizedBox(height: 3),
      Stamped(
        switch ('${p['action']}') { 'started' => 'started', 'finished' => 'finished', _ => 'passed on' },
        size: 9,
        colour: Pen.margin,
      ),
    ],
  );
}

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
          Text(_when(p['fires_at']), style: Hands.margin(size: 12.5)),
        ],
      ),
    ],
  );
}

/// A feeling somebody made: the object itself, its name in their hand, and who made it.
Widget newFeelingCard(NoteContext c) {
  final p = c.event.payload;
  final f = c.registry.byId('${p['feeling_id']}');
  return Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      if (f != null) FeelingObject(feeling: f, size: 58, intensity: 0.7),
      if (f != null) const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Written('${p['name'] ?? f?.name ?? ''}', by: c.event.author, size: 18),
            Text('a new one, ${c.event.author == c.me ? 'yours' : c.event.author.name}\'s · ${p['family'] ?? f?.family.label ?? ''}',
                style: Hands.margin(size: 12)),
          ],
        ),
      ),
    ],
  );
}

const Map<String, ThreadBody> kThreadRenderers = {
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
  'ticket_stub': ticketStub,
  'list_line': listLine,
  'stamped_card': stampedCard,
  'tally_mark': tallyMark,
  'shelf_card': shelfCard,
  'folded_clock': foldedClock,
  'new_feeling_card': newFeelingCard,
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
    case 'passed_on':
      return switch (p['action']) {
        'started' => '$who started ${p['title']}',
        'finished' => '$who finished ${p['title']}',
        _ => '$who passed on ${p['title']}',
      };
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
      'said' => 'said of',
      'remembered' => 'remembering',
      'scheduled' => 'booked',
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

