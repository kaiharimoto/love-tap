// A note in the thread: the material rendering of one spine event.
//
// Every row is a piece of paper torn from a stock, written in its author's hand, lying on the desk
// with the contact shadow that came out of its own render. Replies are pinned over a torn strip of
// the note they answer; reactions are objects stuck to the paper; delivery and read are marks in
// the margin rather than rows.
import 'package:flutter/material.dart';

import '../../feelings/builtins.dart';
import '../../feelings/registry.dart';
import '../../material/assignment.dart';
import '../../material/hands.dart';
import '../../material/library.dart';
import '../../material/objects.dart';
import '../../material/fold.dart';
import '../../material/paper.dart';
import '../../material/palette.dart';
import '../../scope.dart';
import '../../spine/projections/thread.dart';
import '../../spine/spine.dart';
import '../../voice/strings.dart';
import 'renderers.dart';

/// The width a note takes on the desk, as a fraction of the region's width.
const double _noteWidthFraction = 0.76;

class Note extends StatelessWidget {
  const Note({
    super.key,
    required this.item,
    required this.registry,
    required this.onLongPress,
    required this.row,
    this.highlight = false,
  });

  final ThreadItem item;

  /// Where this note sits in the thread: what decides which tear it was torn along.
  final int row;
  final FeelingRegistry registry;
  final VoidCallback onLongPress;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final lib = MaterialLibrary.loaded ? MaterialLibrary.instance : null;
    final mine = item.author == scope.me;
    final e = item.event;

    // margin events: a pencil line beside the thread, not a piece of paper
    if (_isMarginal(item.type)) return _MarginLine(item: item, registry: registry);

    final width = MediaQuery.sizeOf(context).width * _noteWidthFraction;
    final stock = lib == null ? '' : stockVariantFor(e, lib);
    final tear = lib == null ? null : tearFor(e, lib, row: row);
    final lift = liftFor(e);
    final tilt = tiltFor(e) + (mine ? -0.004 : 0.004);

    // A note of theirs that has not been read yet lies folded, the way one passed across a table
    // does, and opens when it is touched. Nothing of mine is ever folded: I wrote it.
    final folded = !mine && (e.seq ?? 0) > (scope.thread.readUpto[scope.me] ?? 0);

    final piece = PaperPiece(
      stockId: stock,
      tearId: tear,
      liftMm: lift,
      tilt: tilt,
      width: width,
      stockAlignment: _patchOf(e),
      stockScale: 1.15,
      padding: const EdgeInsets.fromLTRB(14, 9, 14, 8),
      safe: lib == null || tear == null ? const [0.06, 0.07, 0.06, 0.07] : lib.safeOf(tear),
      overlays: [
        if (item.reactions.isNotEmpty)
          Positioned(
            right: 14,
            bottom: -6,
            child: Row(
              children: [
                for (final r in item.reactions.take(3))
                  Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: FeelingObject(
                      feeling: registry.byId(r.feelingId) ?? kBuiltInFeelings.first,
                      size: 46,
                      intensity: 0.6,
                      tilt: (r.eventId.hashCode % 20 - 10) / 90,
                    ),
                  ),
              ],
            ),
          ),
        if (highlight)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(decoration: const BoxDecoration(color: Accent.highlighterYellow)),
            ),
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.replyTo != null) _ReplyStrip(target: item.replyTo!, registry: registry),
          _body(context, scope),
          const SizedBox(height: 3),
          _Margin(item: item, mine: mine),
        ],
      ),
    );

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Padding(
          padding: EdgeInsets.fromLTRB(mine ? 40 : 14, 4, mine ? 14 : 40, 4),
          child: folded ? FoldedNote(width: width, child: piece) : piece,
        ),
      ),
    );
  }

  static bool _isMarginal(String type) => const {
    'state_declared',
    'state_passive',
    'ritual_kept',
    'milestone',
    'date_event',
    'todo_event',
    'ping',
    'feeling_authored',
  }.contains(type);

  /// Which square of the stock this note is torn from, so two notes never show the same paper.
  static Alignment _patchOf(Event e) {
    final h = hashOf(e.id);
    return Alignment(((h % 100) / 50.0) - 1.0, (((h >> 7) % 100) / 50.0) - 1.0);
  }

  /// The thread's half of the registry's promise: a type names the renderer that draws it, and
  /// renderers.dart is where they live. There is no switch on the type here and no second one in
  /// search, so the two cannot drift apart the way they had.
  Widget _body(BuildContext context, AppScope scope) {
    if (item.deleted) {
      return Written(S.tookBack, by: item.author, size: 17, colour: Pen.margin);
    }
    final spec = kEventTypeById[item.type];
    final draw = spec == null ? null : kThreadRenderers[spec.renderer];
    if (draw == null) return Written(item.text ?? item.type, by: item.author, size: 18);
    return draw(NoteContext(item: item, registry: registry, me: scope.me, context: context));
  }
}

class _ReplyStrip extends StatelessWidget {
  const _ReplyStrip({required this.target, required this.registry});
  final Event target;
  final FeelingRegistry registry;

  @override
  Widget build(BuildContext context) {
    final text = switch (target.type) {
      'message' => target.payload['text'] as String? ?? '',
      'photo' => S.photo,
      'video' => S.video,
      'voice_note' => S.voiceNote,
      'feeling' => registry.byId(target.payload['feeling_id'] as String)?.name ?? '',
      _ => target.type,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.only(left: 8, bottom: 4),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Pen.margin, width: 1.2)),
      ),
      child: Written(text, by: target.author, size: 15, colour: Pen.margin, maxLines: 2),
    );
  }
}

/// The pencil line under a note: when it was written, whether it has been read.
class _Margin extends StatelessWidget {
  const _Margin({required this.item, required this.mine});
  final ThreadItem item;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final bits = <String>[
      timeLabel(item.ts),
      if (item.writtenEarlier) S.writtenEarlier,
      if (item.edited) S.edited,
      if (mine)
        switch (item.delivery) {
          Delivery.waiting => S.waitingToSend,
          Delivery.sent => S.sent,
          Delivery.read => S.read,
        },
    ];
    return Opacity(opacity: 0.75, child: Text(bits.join(' · '), style: Hands.margin(size: 12)));
  }
}

/// Module and state events: a mark in the margin of the desk rather than a note of their own.
/// Something one of them said about themselves, written the way they would say it rather than the
/// way it is stored. `mood: low` is a field; "noor · low" is a person telling you something.
String _declared(String who, Map<String, dynamic> p) {
  final signal = p['signal'] as String?;
  final value = p['value'];
  return switch (signal) {
    'mood' => '$who · $value',
    'status_line' => '$who · $value',
    'availability' => '$who is $value',
    'place' => '$who · $value',
    'need' => '$who needs ${_dial(value)}',
    'energy' => '$who has ${_dial(value)} left',
    _ => '$who · $value',
  };
}

/// The three things a phone notices that are worth saying out loud. Everything else it knows stays
/// on the partner strip, where it is a fact about them rather than a line in the conversation.
String _noticed(String who, Map<String, dynamic> p) {
  final value = p['value'];
  return switch (p['signal']) {
    'battery' => "$who's phone is nearly out",
    'at_home' => value == true ? '$who got in' : '$who went out',
    'ringer' => value == 'silent' ? "$who's phone went quiet" : "$who's phone is on again",
    _ => '$who · $value',
  };
}

String _dial(Object? value) {
  final n = (value is num) ? value.round() : 2;
  return switch (n) {
    <= 0 => 'nothing',
    1 => 'a little',
    2 => 'some',
    3 => 'a lot',
    _ => 'everything',
  };
}

class _MarginLine extends StatelessWidget {
  const _MarginLine({required this.item, required this.registry});
  final ThreadItem item;
  final FeelingRegistry registry;

  @override
  Widget build(BuildContext context) {
    final p = item.event.payload;
    final who = item.author.name;
    final text = switch (item.type) {
      'state_declared' => _declared(who, p),
      'state_passive' => _noticed(who, p),
      'date_event' => '${p['action']} · ${p['title']}${p['rating'] != null ? ' · ${p['rating']}/5' : ''}',
      'todo_event' => '${p['action']} · ${p['text']}',
      'milestone' => '${p['title']} · ${p['date']}',
      'ritual_kept' => 'kept · ${p['title']}',
      'ping' => '${p['text']} · ${p['fires_at']}',
      'feeling_authored' => 'a new one · ${p['name']}',
      _ => item.type,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 6, 26, 6),
      child: Row(
        children: [
          Container(width: 14, height: 1, color: Pen.margin.withValues(alpha: 0.5)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: Hands.margin(size: 13))),
          Text(timeLabel(item.ts), style: Hands.margin(size: 11.5)),
        ],
      ),
    );
  }
}
