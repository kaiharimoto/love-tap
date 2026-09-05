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
import '../../material/marks.dart';
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
    required this.unreadFrom,
    this.highlight = false,
  });

  final ThreadItem item;

  /// Where this note sits in the thread: what decides which tear it was torn along.
  final int row;

  /// The seq the reader's read marker stood at when they opened the thread. A note above it was
  /// already read; a note below it was waiting for them.
  final int unreadFrom;
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
    if (_isMarginal(item.type)) return _MarginLine(item: item, me: scope.me);

    final width = MediaQuery.sizeOf(context).width * _noteWidthFraction;
    final stock = lib == null ? '' : stockVariantFor(e, lib);
    final tear = lib == null ? null : tearFor(e, lib, row: row);
    final lift = liftFor(e);
    final tilt = tiltFor(e) + (mine ? -0.004 : 0.004);

    // A note of theirs that had not been read when the thread was opened lies folded, the way one
    // passed across a table does, and opens when it is touched. Nothing of mine is ever folded:
    // I wrote it.
    //
    // Against the read marker as it stands, rather than as it stood on arrival, nothing is ever
    // folded for longer than one frame: opening the thread writes a read marker over everything
    // in it, the note rebuilds unfolded, and it goes from folded to flat with nothing in between.
    // Which is why the unfolding clip was two hundred and forty identical frames.
    // A thrown object is not a folded note. A feeling arrives by being thrown across the desk and
    // landing on it; there is nothing to unfold, and folding it meant the row rendered as fold
    // frame 0000 — a square-cornered blank cream slab — for as long as it was unread, which on
    // 08_state_propagating was for ever, because nothing ever taps it. Two of the three things the
    // far phone sent arrived as blank paper.
    final thrown = kThreadRenderers[kEventTypeById[item.type]?.renderer] == objectLanding;
    final folded = !mine && !thrown && (e.seq ?? 0) > unreadFrom;

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

  /// Which types are a line in the margin rather than a piece of paper — asked of the registry,
  /// not of a list kept here. The registry already says it: those are exactly the types whose
  /// renderer is the margin sentence. A list here would be a third place a type has to be added
  /// to, and the two that existed had already drifted.
  static bool _isMarginal(String type) =>
      kEventTypeById[type]?.renderer != null &&
      kThreadRenderers[kEventTypeById[type]!.renderer] == marginSentence;

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
    // Each state has its own mark as well as its own word. Five grey lowercase words at the same
    // size in the same place is not five states: a message that failed to send looked exactly
    // like one that had been read, which is the kind of thing that sends somebody back to
    // Instagram on the first day.
    final words = <String>[
      timeLabel(item.ts),
      if (item.writtenEarlier) S.writtenEarlier,
      if (item.edited) S.edited,
    ];
    return Opacity(
      opacity: 0.78,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // the time, and what happened to the note, and how far it got — on a narrow note with
          // all three of those to say, this ran off the edge of the paper
          Flexible(
            child: Text(words.join(' · '),
                style: Hands.margin(size: 12), maxLines: 1, overflow: TextOverflow.fade,
                softWrap: false),
          ),
          if (item.edited)
            const Padding(padding: EdgeInsets.only(left: 5), child: _EditCaret()),
          if (mine) ...[
            const SizedBox(width: 7),
            _DeliveryMark(delivery: item.delivery, id: item.id),
          ],
        ],
      ),
    );
  }
}

/// The caret a person puts in when they change a word.
class _EditCaret extends StatelessWidget {
  const _EditCaret();
  @override
  Widget build(BuildContext context) => Mark.turnback(size: 11, colour: Pen.margin, seed: 3);
}

/// What happened to something you wrote, as a mark rather than a word alone.
///
///   queued   a dash, unfinished: it has not left
///   sending  the same dash with a line running off it
///   sent     one tick
///   read     one tick and the word, in the ink of the person who read it
///   refused  a cross, in red, and the reason on the paper
class _DeliveryMark extends StatelessWidget {
  const _DeliveryMark({required this.delivery, required this.id});
  final Delivery delivery;
  final String id;

  @override
  Widget build(BuildContext context) {
    final seed = id.hashCode & 0x7fff;
    return switch (delivery) {
      Delivery.queued => Row(mainAxisSize: MainAxisSize.min, children: [
          Text(S.waitingToSend, style: Hands.margin(size: 12)),
          const SizedBox(width: 4),
          Mark.clip(size: 12, colour: Pen.margin, seed: seed),
        ]),
      Delivery.sending => Row(mainAxisSize: MainAxisSize.min, children: [
          Text(S.sending, style: Hands.margin(size: 12)),
          const SizedBox(width: 4),
          Mark.ticks(size: 12, colour: Pen.margin, seed: seed),
        ]),
      Delivery.sent => Row(mainAxisSize: MainAxisSize.min, children: [
          Text(S.sent, style: Hands.margin(size: 12)),
          const SizedBox(width: 4),
          Mark.tick(size: 12, colour: Pen.margin, seed: seed),
        ]),
      Delivery.read => Row(mainAxisSize: MainAxisSize.min, children: [
          Text(S.read, style: Hands.margin(size: 12).copyWith(color: Pen.ballpoint)),
          const SizedBox(width: 4),
          Mark.tick(size: 12, colour: Pen.ballpoint, seed: seed),
          Mark.tick(size: 12, colour: Pen.ballpoint, seed: seed + 1),
        ]),
      Delivery.refused => Row(mainAxisSize: MainAxisSize.min, children: [
          Text(S.refused, style: Hands.margin(size: 12).copyWith(color: Pen.red)),
          const SizedBox(width: 4),
          Mark.cross(size: 12, colour: Pen.red, seed: seed),
        ]),
    };
  }
}

/// A line in the margin of the desk: a rule, the sentence, and when it was written.
///
/// The sentence is [summaryOf] and nothing else. This class used to keep its own switch over the
/// same eight types, and the two had drifted: a scheduled ping read as
/// `one hour, then stop · 2026-04-23T16:00:00+01:00` in the thread and as
/// `one hour, then stop · Thu 23 Apr` in search, off the same event. A person was being shown a
/// stored field. Two sentences for one event is one sentence too many.
class _MarginLine extends StatelessWidget {
  const _MarginLine({required this.item, required this.me});
  final ThreadItem item;
  final Person me;

  @override
  Widget build(BuildContext context) {
    final text = summaryOf(item.event, me: me);
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 6, 26, 6),
      child: Row(
        children: [
          Container(width: 14, height: 1, color: Pen.onWood.withValues(alpha: 0.55)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: Hands.onDesk(size: 13))),
          Text(timeLabel(item.ts), style: Hands.onDesk(size: 11.5)),
        ],
      ),
    );
  }
}
