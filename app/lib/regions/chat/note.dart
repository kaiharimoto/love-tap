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
import '../../material/slip.dart';

/// The width a note takes on the desk, as a fraction of the region's width.
const double _noteWidthFraction = 0.76;

/// Whether this row is lying folded shut, and so whether its writing has been seen.
///
/// This used to be one expression inside [Note.build] and nothing else could ask it. That is why
/// the read receipt could lie: `AppScope.markRead()` advanced the marker over the whole thread
/// six hundred milliseconds after the region opened, while a note of theirs above the reader's
/// frozen arrival marker was still drawn folded. The app told the other person `read` for a sheet
/// the reader had not opened and could not have read. A receipt that fires on a closed envelope is
/// worse than no receipt at all.
///
/// So the predicate lives here, once, and both the rendering and the receipt ask it. Two
/// questions answered by two copies of the same condition is how they drift apart.
///
/// [FoldedNote.available] is part of it and not an afterthought: with no fold sequence on disk
/// the note lies flat and its writing is on the screen, so nothing is hidden and the marker may
/// honestly advance. Nothing of mine is ever folded, a thrown object lands face up with nothing
/// to unfold, and a margin line is not a sheet of paper at all.
///
/// [foldsAvailable] overrides that reading for a caller that cannot ask. `reliability_test.dart`
/// is the one: loading the material library needs the widget binding, and a file that
/// initialises the widget binding has every HTTP request answered 400 by the test harness --
/// which is the transport that test is built on. Passing it explicitly says "assume the sheet
/// can fold, and tell me about the shape of this thread", which is the question that matters
/// there and is not a question about the asset directory.
bool noteLiesFolded(
  ThreadItem item, {
  required Person me,
  required int unreadFrom,
  bool? foldsAvailable,
}) {
  if (!(foldsAvailable ?? FoldedNote.available)) return false;
  if (item.author == me) return false;
  if (Note._isMarginal(item.type)) return false;
  if (kThreadRenderers[kEventTypeById[item.type]?.renderer] == objectLanding) return false;
  return (item.event.seq ?? 0) > unreadFrom;
}

/// The highest seq a read marker may honestly advance to, given what is still folded.
///
/// A read marker is a watermark -- `upto_seq` -- so it cannot say "I read 12 and 14 but not 13".
/// The truthful watermark is therefore the last row before the first folded sheet the reader has
/// not opened. Everything at or below it is either mine, or thrown, or was already read when the
/// thread was opened, or has been opened since; every one of those the reader has actually seen.
///
/// Returns 0 where even the first row with a seq is folded and unopened: there is nothing honest
/// to advance to. Zero rather than null on purpose -- `markRead`'s ceiling is nullable and null
/// there means "no ceiling, mark everything", which is the opposite of what this case means. A
/// read marker starts at 0 and never goes backwards, so 0 is the value that moves nothing.
int seenUpto(
  List<ThreadItem> items, {
  required Person me,
  required int unreadFrom,
  required Set<int> opened,
  bool? foldsAvailable,
}) {
  var last = 0;
  for (final item in items) {
    final seq = item.event.seq;
    if (seq == null) continue;
    if (!opened.contains(seq) &&
        noteLiesFolded(item,
            me: me, unreadFrom: unreadFrom, foldsAvailable: foldsAvailable)) {
      return last;
    }
    last = seq;
  }
  return last;
}

class Note extends StatelessWidget {
  const Note({
    super.key,
    required this.item,
    required this.registry,
    required this.onLongPress,
    required this.row,
    required this.unreadFrom,
    this.onOpened,
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

  /// Called once this row's writing is actually on the screen, so the thread can let the read
  /// marker past it. A folded note that nobody opens never fires it, which is the whole point.
  final VoidCallback? onOpened;
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
    final folded = noteLiesFolded(item, me: scope.me, unreadFrom: unreadFrom);

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
                      tilt: (hashOf(r.eventId) % 20 - 10) / 90,
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
          if (_marginBelongs(thrown, mine)) _Margin(item: item, mine: mine),
          // Under the margin rather than in it: the reason and the way out of it are a block, and
          // the margin is one line that already runs off a narrow note with three things in it.
          if (mine && item.delivery == Delivery.refused) _Refused(item: item),
        ],
      ),
    );

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Padding(
          padding: EdgeInsets.fromLTRB(mine ? 40 : 14, 4, mine ? 14 : 40, 4),
          child: folded
              ? FoldedNote(width: width, onOpened: onOpened, child: piece)
              : piece,
        ),
      ),
    );
  }

  /// Whether this row gets the pencil line under it: the time it was written, whether it was
  /// edited, how far it got, whether they have read it.
  ///
  /// A message gets one. A feeling does not, once it has landed. 13_messenger_states.png is the
  /// row's own named failure mode twice over: `empty chair / Thu 3 Sep . 17:19 read` sat under a
  /// drawn object in furniture identical, line for line, to `left the key under the pot /
  /// Thu 3 Sep . 19:40 read` fourteen hundred pixels below it. A gesture that arrives as a
  /// sensation and then comes to rest as a message with a receipt on it is a message; the row is
  /// about the difference, and cycle 3 fixed the arrival and left the resting state alone.
  ///
  /// It keeps the line while it is still in the outbox, because a feeling that has not gone has
  /// something to say and something to be done about it -- that is the `try again` from the item
  /// above this one, and it is on the same pencil line. Once it has gone there is nothing to say:
  /// it is a thing on the desk, and a thing on the desk has no delivery state written under it.
  bool _marginBelongs(bool thrown, bool mine) {
    if (!thrown) return true;
    if (!mine) return false;
    return item.delivery != Delivery.sent && item.delivery != Delivery.read;
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
    // The thinning is `Pen.marginThinning` and not a number written here. It was 0.78, applied
    // at this one call site and visible to nothing else, and it took the whole of the margin
    // ink's headroom over the body floor: thirteen of the eighty-four runs below floor in the
    // capture at `9dec301` were this Row's timestamps -- sixteen of them are timestamps at all,
    // and the thirteen at px 36 are the ones drawn here -- six among the worst twelve in the set. The ink is derived to sit exactly at the ink ceiling of the ladder, so there is no
    // gap here to spend on being faint; a margin note is set back by being small, by being
    // pencil and by being at the edge of the note, not by being washed toward the paper.
    return Opacity(
      opacity: Pen.marginThinning,
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
            _DeliveryMark(item: item),
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
///   refused  a cross, in red, the reason, and something to press to send it again
class _DeliveryMark extends StatelessWidget {
  const _DeliveryMark({required this.item});
  final ThreadItem item;

  Delivery get delivery => item.delivery;
  String get id => item.id;

  @override
  Widget build(BuildContext context) {
    final seed = hashOf(id) & 0x7fff;
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
      // Only the mark and the words here: what to do about it is a block of its own under the
      // margin, because three things in the margin Row overflowed the note by 101 pixels and the
      // third was clipped off the edge of the paper.
      Delivery.refused => Row(mainAxisSize: MainAxisSize.min, children: [
          Text(S.refused, style: Hands.margin(size: 12).copyWith(color: Pen.red)),
          const SizedBox(width: 4),
          Mark.cross(size: 12, colour: Pen.red, seed: seed),
        ]),
    };
  }
}

/// The one state a person has to be able to do something about.
///
/// Every other delivery state is news. This one is a dead end unless the row offers a way out of
/// it, and it offered none: a message the host would not take sat there marked, for ever, while
/// the sync engine re-offered it behind the person's back and the margin never changed. The row
/// now says what happened, why, and what to press — in that order, because the reason is what
/// decides whether pressing it is worth anything.
class _Refused extends StatelessWidget {
  const _Refused({required this.item});
  final ThreadItem item;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final seed = (hashOf(item.id) & 0x7fff) + 2;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.refusedWhy != null)
            Text(item.refusedWhy!, style: Hands.margin(size: 11.5), maxLines: 2),
          // A turn-back mark: the same one the app puts in when a word is changed, which is what
          // sending it again is. `opaque` and the padding together are the press — twelve-point
          // handwriting is not a tap target on its own.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => scope.sendAgain(item.id),
            child: Padding(
              padding: const EdgeInsets.only(top: 3, right: 10, bottom: 2),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Mark.turnback(size: 12, colour: Pen.red, seed: seed),
                const SizedBox(width: 4),
                Text(S.tryAgain, style: Hands.margin(size: 12.5).copyWith(color: Pen.red)),
              ]),
            ),
          ),
        ],
      ),
    );
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
          // A rule is a shape, not a word, so it may stay on the wood — at the stamp's own ink
          // rather than the chalky tone, because there is no chalky tone any more.
          Container(width: 14, height: 1, color: Pen.margin.withValues(alpha: 0.55)),
          const SizedBox(width: 8),
          // The sentence is a word, so it is on paper.
          Flexible(
            child: Strip(
              id: 'margin-${item.event.id}',
              row: hashOf(item.id),
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(text,
                        style: Hands.margin(size: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 8),
                  Text(timeLabel(item.ts), style: Hands.margin(size: 11.5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
