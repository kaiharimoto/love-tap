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
import '../../thread/renderers.dart';

/// The width a note takes on the desk, as a fraction of the region's width.
const double _noteWidthFraction = 0.76;

/// How many rows of the thread have been built since this was last reset.
///
/// A fling is measured in rows built, not in milliseconds: the fault a critic found was that
/// every frame of the scroll clip re-entered the list at a new index, which tears the active
/// sliver down and builds another — build cost p50 20 ms, p95 1426, max 1785, against a raster
/// that never left 166-212. Rows built per frame says that in a number that does not depend on
/// what else the machine is doing.
class ThreadRowStats {
  static int built = 0;
  static void reset() => built = 0;
}

class Note extends StatelessWidget {
  const Note({
    super.key,
    required this.item,
    required this.registry,
    required this.onLongPress,
    required this.row,
    required this.unreadFrom,
    this.highlight = false,
    this.arrived = false,
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

  /// This note was not in the thread when it was opened: it has just come across the wire, and a
  /// folded note that has just come across lands on the desk rather than being found there.
  final bool arrived;

  @override
  Widget build(BuildContext context) {
    ThreadRowStats.built++;
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

    // what is written on the paper, whichever paper it turns out to be
    final writing = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (item.replyTo != null) _ReplyStrip(target: item.replyTo!, registry: registry),
        _body(context, scope),
        const SizedBox(height: 3),
        // A note that was taken back does not report how far it got. It said `read ✓✓` under the
        // words "took it back", which is a delivery state for writing that is not there any more,
        // and a critic reading the states artifact found the taken-back row indistinguishable
        // from an ordinary message. The time stays: the thread's order is still a fact.
        _Margin(item: item, mine: mine && !item.deleted),
      ],
    );

    final piece = PaperPiece(
      stockId: stock,
      tearId: tear,
      liftMm: lift,
      tilt: tilt,
      width: width,
      stockAlignment: _patchOf(e, stock),
      stockScale: 1.15,
      padding: const EdgeInsets.fromLTRB(14, 9, 14, 8),
      safe: lib == null || tear == null ? const [0.06, 0.07, 0.06, 0.07] : lib.safeOf(tear),
      overlays: [
        // and nothing is stuck to it any more either: what they were stuck to is gone
        if (item.reactions.isNotEmpty && !item.deleted)
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
      child: writing,
    );

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Padding(
          padding: EdgeInsets.fromLTRB(mine ? 40 : 14, 4, mine ? 14 : 40, 4),
          // A folded note is a letter: it opens, and the writing is on the sheet that opened. The
          // torn piece is what it would be if no sequence were baked.
          child: folded
              ? FoldedNote(
                  id: item.id,
                  width: width,
                  letter: writing,
                  // the name on the outside, in the hand of the one who folded it: a folded note
                  // is addressed, and this is what the reader sees before opening it
                  outside: Text(scope.me.name, style: Hands.of(e.author, size: 17)),
                  arriving: arrived,
                  child: piece,
                )
              : piece,
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
  /// Which part of the sheet this piece was torn from.
  ///
  /// Never the bound edge. A spiral pad and a looseleaf sheet are rendered with their punched
  /// holes as real geometry, and a piece cropped at random landed on that column about one time in
  /// twenty — a row of coil holes down the left of a note with the writing running straight over
  /// them, which is what the eye goes to first. A page pulled out of a pad keeps the fringe the
  /// coil left and not the holes it tore through, so the crop starts past them.
  static Alignment _patchOf(Event e, String stock) {
    final h = hashOf(e.id);
    final bound = stock.startsWith('spiral') || stock.startsWith('looseleaf');
    final x = ((h % 100) / 50.0) - 1.0;
    return Alignment(bound ? x.abs().clamp(0.15, 1.0) : x, (((h >> 7) % 100) / 50.0) - 1.0);
  }

  /// The thread's half of the registry's promise: a type names the renderer that draws it, and
  /// thread/renderers.dart is where they live. There is no switch on the type here and no second one in
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
      // The time, what happened to the note, and how far it got. On a narrow note with all three
      // to say — a short line that would not go — the row ran thirty-three pixels off the edge of
      // the paper and the delivery mark was the part that went, which is the one part that must
      // never go. It wraps onto a second line instead.
      child: Wrap(
        alignment: WrapAlignment.start,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 7,
        runSpacing: 1,
        children: [
          Text(words.join(' · '),
              style: Hands.margin(size: 12), maxLines: 1, overflow: TextOverflow.fade,
              softWrap: false),
          if (item.edited) const _EditCaret(),
          if (mine) _DeliveryMark(delivery: item.delivery, id: item.id),
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

  /// The words and the mark, side by side, never wider than the paper they are on: on a short
  /// note `it would not go ×` is wider than the note itself, and the part that ran off the edge
  /// was the mark saying it had not gone.
  static Widget _said(String words, Widget mark, {Color? ink}) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        // the words give way, never the mark: a Wrap hands its child a bounded width, so this
        // fades rather than running off the paper
        Flexible(
          child: Text(words,
              style: ink == null
                  ? Hands.margin(size: 12)
                  : Hands.margin(size: 12).copyWith(color: ink),
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false),
        ),
        const SizedBox(width: 4),
        mark,
      ]);

  @override
  Widget build(BuildContext context) {
    final seed = id.hashCode & 0x7fff;
    return switch (delivery) {
      Delivery.queued => _said(S.waitingToSend, Mark.clip(size: 12, colour: Pen.margin, seed: seed)),
      Delivery.sending => _said(S.sending, Mark.ticks(size: 12, colour: Pen.margin, seed: seed)),
      Delivery.sent => _said(S.sent, Mark.tick(size: 12, colour: Pen.margin, seed: seed)),
      Delivery.read => _said(
          S.read,
          Row(mainAxisSize: MainAxisSize.min, children: [
            Mark.tick(size: 12, colour: Pen.ballpoint, seed: seed),
            Mark.tick(size: 12, colour: Pen.ballpoint, seed: seed + 1),
          ]),
          ink: Pen.ballpoint),
      Delivery.refused => _said(S.refused, Mark.cross(size: 12, colour: Pen.red, seed: seed), ink: Pen.red),
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
