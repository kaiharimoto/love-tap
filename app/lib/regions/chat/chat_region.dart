// Chat: the full chronological rendering of the spine, and the complete messenger.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../capture/bus.dart';
import '../../feelings/builtins.dart';
import '../../flags.dart';
import '../../feelings/registry.dart';
import '../../material/hands.dart';
import '../../material/fold.dart';
import '../../material/marks.dart';
import '../../material/objects.dart';
import '../../material/palette.dart';
import '../../material/slip.dart';
import '../../media/capture.dart';
import '../../media/local_uri.dart';
import '../../media/read_bytes.dart';
import '../../scope.dart';
import '../../transport/local/local_transport.dart';
import '../../spine/types.dart';
import '../../spine/projections/thread.dart';
import '../../voice/strings.dart';
import 'note.dart';
import '../../thread/renderers.dart';
import 'search_page.dart';
import 'viewer_page.dart';

class ChatRegion extends StatefulWidget {
  const ChatRegion({super.key});

  @override
  State<ChatRegion> createState() => _ChatRegionState();
}

class _ChatRegionState extends State<ChatRegion> with WidgetsBindingObserver {
  /// Where the reader's read marker stood when they opened the thread. Opening it writes a
  /// new one over everything, and a note that folds against the marker as it stands is
  /// folded for exactly one frame.
  int? _arrivedAt;

  final _text = TextEditingController();
  final _scroll = ItemScrollController();
  final _positions = ItemPositionsListener.create();
  /// A real pixel offset into the list, for the fling. See [CaptureBus.scrollBy].
  final _offset = ScrollOffsetController();

  /// The list itself, so the fling can reach the scroller underneath it.
  final _listKey = GlobalKey();

  /// The ids the thread held when this region was first drawn. A row that is not among them came
  /// across the wire while the region was open, and a folded one lands rather than being found.
  Set<String>? _openedWith;
  final _media = MediaCapture();
  final _recorder = VoiceRecorder();
  Timer? _draftTimer;
  Timer? _typingTimer;
  Timer? _readTimer;
  bool _typingSent = false;
  ThreadItem? _replyTo;

  ThreadItem? _editing;
  String? _highlightId;

  /// The search open in the thread's place, and the words it opened with.
  bool _searching = false;
  String _searchQuery = '';
  bool _recording = false;
  int _lastCount = 0;
  bool _draftLoaded = false;
  bool _attaching = false;

  /// The live scroll position of the thread's list.
  ///
  /// The positioned list keeps its scroller to itself — it takes an [ItemScrollController] and a
  /// [ScrollOffsetController], neither of which can set a pixel offset without an animation, and
  /// it hands out no [ScrollController]. The position is in the tree under it all the same: the
  /// first scrollable below the list's own element is the one it is drawing (the second exists
  /// only while it is crossfading between two indices, and is behind the first). Reaching it is
  /// what makes a driven fling a jump per frame rather than three hundred one-millisecond
  /// animations racing a compositor.
  ScrollPosition? _livePosition() {
    final ctx = _listKey.currentContext;
    if (ctx == null) return null;
    ScrollPosition? found;
    void look(Element e) {
      if (found != null) return;
      if (e is StatefulElement && e.state is ScrollableState) {
        final st = e.state as ScrollableState;
        if (st.position.hasPixels) found = st.position;
        return;
      }
      e.visitChildren(look);
    }
    ctx.visitChildElements(look);
    return found;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _text.addListener(_onTextChanged);
    if (Flags.capture || CaptureBus.wanted) _offerHandles();
  }

  /// Capture mode: the same four things a thumb does in Chat, reachable from the harness.
  void _offerHandles() {
    CaptureBus.scrollTo = _scrollToAnchor;
    CaptureBus.openSender = (open) => setState(() => _attaching = open);
    // an event id, or a type ('photo', 'video') meaning one from the middle of that kind
    CaptureBus.openViewer = (idOrType) async {
      final items = AppScope.of(context).thread.items;
      var it = items.where((i) => i.id == idOrType).firstOrNull;
      if (it == null) {
        final ofType = items.where((i) => i.type == idOrType).toList();
        // Finding nothing is not the same as succeeding. A handle that returns quietly here is how
        // a capture of the media viewer becomes a second capture of the thread behind it.
        if (ofType.isEmpty) throw StateError('there is no $idOrType in the thread to open');
        it = ofType[ofType.length ~/ 2];
        await _scrollToAnchor(it.id);
      }
      if (!mounted) return;
      // Opened, not opened-and-closed: a Navigator.push does not complete until the page is
      // popped, so awaiting it here left the capture harness waiting for somebody to close the
      // viewer. The scene ran out of time with no shot taken and what shipped was the thread
      // behind it — which is exactly what the artifact was accused of being.
      unawaited(ViewerPage.open(context, it));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    };
    // The artifact of searching has to be a picture of searching: the sheet open, the words in
    // the field, the facets down the side and the hits under them. Jumping straight to the first
    // hit in the thread — which is what this did — produced a second picture of the thread.
    CaptureBus.search = (q) async {
      // Opened, not opened-and-closed: the search takes the thread's place in this region until
      // a hit is tapped or it is put away, so the harness gets a picture of searching — the
      // words in the field, the facets, the hits — with the shell still around it.
      setState(() {
        _searching = true;
        _searchQuery = q;
      });
      await Future<void>.delayed(const Duration(milliseconds: 240));
    };
    CaptureBus.scrollBy = (dy) {
      // One nudge of the thread's own scroller, which is what a frame of the scroll clip is:
      // a real scroll, by pixels, on the list's own position. It used to re-enter the list at a
      // new index and alignment every step, and jumping to an index is not a scroll: the
      // positioned list tears down its active sliver and builds another one at the new index, so
      // every frame of the fling was a rebuild. The frame timings say what that cost — build p50
      // 20 ms, p95 1426, max 1785, against a raster that never leaves 166-212 — and the spikes
      // recur every third frame, which is the list swapping between its two children.
      //
      // Then it was an animation a millisecond long, and that is why frames of the scroll clip
      // came back identical to the one before them. An animation moves on its ticker, and the
      // ticker is stepped by the browser's frame timestamp, not by the driven clock: on a
      // headless compositor running at about four frames a second, two frames the clock pumped
      // in one step can carry the same timestamp, the controller's value stays at zero, and the
      // thread does not move on a frame it was told to move on. Queueing the nudges made it
      // worse (three, five, six, then thirteen frames of three hundred), because each one then
      // waited for a ticker that had not run.
      //
      // The pixels are set, not animated. A jump is exactly what a frame of a fling is: the
      // simulation says how far the thread travelled since the last frame, and this puts it
      // there, inside the tick, before the frame is laid out. Nothing in the path depends on
      // wall-clock time, so a frame that did not move is now a thread that had nowhere to go —
      // and it says so, in the pixels it answers with.
      if (dy == 0) return 0.0;
      final p = _livePosition();
      if (p == null) return 0.0;
      final to = (p.pixels + dy).clamp(p.minScrollExtent, p.maxScrollExtent);
      final moved = to - p.pixels;
      if (moved == 0) return 0.0;
      p.jumpTo(to);
      return moved;
    };
    CaptureBus.scrollWhere = () {
      final p = _livePosition();
      if (p == null) return const <double>[];
      return [p.pixels, p.minScrollExtent, p.maxScrollExtent];
    };
    CaptureBus.stageStates = () async {
      // Real messages down the real path. The thread is paired with the far phone for this
      // capture, so what is written here leaves through the outbox and comes back with a sequence
      // the host gave it: `sent` is the host having taken it, and `read` is the far phone having
      // read it (the scene tells it to), not a marker built here by hand. The two states the host
      // would never produce on its own — a message still on its way, and one it refused — are
      // produced rather than annotated now. The refusal is the host's: the scene tells the far
      // phone to refuse the next thing it is pushed, and it answers with its own sentence. The one
      // on its way is simply one that has been written and not yet gone. Nothing here marks a row
      // with a state the app is not in — the marks were the fault: markInFlight changed nothing,
      // because a pending row already reads `sending` while the link is up, and the sync engine
      // cleared it in its own finally; and markRefused was cleared by the next round that pushed
      // the same event and got a seq for it.
      //
      // It used to append a read marker built by hand, with a sequence number it made up and an
      // id from the ULID factory, straight into the spine as if the host had sent it. That was
      // the one path in the app that minted an event for the other person, and it was the one
      // that threw only in the web build.
      final scope = AppScope.of(context);
      // The one the host will not take. The scene has already told the far phone `refuse 1`, so
      // this is pushed, answered with a refusal in the host's own words, and stays in the outbox
      // marked. It used to be `markRefused(id, 'the other phone is on an older version')` — the
      // near phone writing the other phone's answer down for it, which is a picture of the state
      // rather than the state.
      final no = await scope.emit('message', {'text': 'sending you the roster'});
      scope.sync.kick();
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      // Two that cross. The far phone read the thread before any of this was written, so these
      // sit above its read marker and come back `sent` — and everything under them in the frame
      // is `read`, which is the pair a reader has to be able to tell apart.
      await scope.emit('message', {'text': 'left the key under the pot'});
      final second = await scope.emit('message', {'text': 'and the bread, if there is any'});
      scope.sync.kick();
      await Future<void>.delayed(const Duration(milliseconds: 900));
      // A reaction and a reply, made the way a thumb makes them, so the states frame shows the
      // whole grammar of the messenger rather than four delivery marks. Both were in the app and
      // in no artifact: fifteen captures carried replying_to null and not one reaction.
      final theirs = scope.thread.items.lastWhere((i) => i.author != scope.me,
          orElse: () => scope.thread.items.first);
      await scope.emit('reaction', {'target': theirs.id, 'feeling_id': 'squeeze'});
      // An edit, through the composer, the way a thumb makes one: the message goes back into the
      // box with the edit banner over it and `_send` emits `message_edit` against its id. Not a
      // hand-built event — the same call the person's own send makes, so what the frame shows is
      // the path, not a drawing of it.
      final editable = scope.thread.items.where((i) => i.id == second.id).firstOrNull;
      if (mounted && editable != null) {
        setState(() {
          _editing = editable;
          _text.text = 'and the bread — there is half a loaf in the tin';
        });
        await _send();
      }
      // And one taken back: a row somebody deleted is a stub, not a gap, and that is a different
      // picture from a row that was never sent. Never the row that is still on its way — those
      // were the same note, and it read `took this back · read` while trying to show `sending`.
      final takeable = scope.thread.items.lastWhere(
          (i) => i.author == scope.me && i.type == 'message' && i.id != second.id && i.id != no.id,
          orElse: () => theirs);
      if (takeable.author == scope.me) {
        await scope.emit('message_delete', {'target': takeable.id});
      }
      // something they actually said, so the banner shows words rather than whatever the last
      // row happened to be
      final answerable = scope.thread.items.lastWhere(
          (i) => i.author != scope.me && i.id != theirs.id && (i.text ?? '').trim().isNotEmpty,
          orElse: () => theirs);
      // One reply that lands, made the way a thumb makes one: the banner goes up over the
      // composer and `_send` carries `reply_to` with the text. Every capture until now has shown
      // the *composer* holding a reply and no artifact has ever shown a delivered one tied to its
      // parent — `replying_to` was the only reply-shaped field in any of the seventeen reports,
      // and a messenger critic capped the whole row on that absence. The row that draws a landed
      // reply has existed since note.dart:106 and nothing ever photographed it.
      if (mounted) {
        setState(() {
          _replyTo = answerable;
          _text.text = 'the one by the door, i think';
        });
        await _send();
        await Future<void>.delayed(const Duration(milliseconds: 700));
      }
      if (mounted) setState(() => _replyTo = answerable);
      _text.text = 'the second one, then';
      if (mounted) setState(() {});
      // The two states nobody has ever seen: one still going, and one that has not left.
      //
      // `queued` and `sending` are the two a person sees when the wire is bad, and they appeared
      // in no artifact and in no report field in eight captures — which is the half of delivery
      // that matters most on a link between two phones in two houses. Neither is drawn here: the
      // transport is slowed so a push is genuinely in flight when the shutter opens, and then the
      // next few requests are dropped so a row is genuinely sitting in the outbox. The link stays
      // up, so the record still says connected; a phone that has gone offline would say so.
      final t = scope.transport;
      if (t is LocalTransport) {
        t.scriptedFaults.setLatency(const Duration(milliseconds: 6000));
        await scope.emit('message', {'text': 'ringing the vet at four'});
        scope.sync.kick();
        await Future<void>.delayed(const Duration(milliseconds: 260));
        // A handful of dropped requests, not forty: enough to keep this one row in the outbox
        // while the shutter opens, few enough that the rounds carrying everything else get
        // through. Forty starved the whole engine.
        t.scriptedFaults.dropNext(8);
        await scope.emit('message', {'text': 'and the thing for the door'});
        scope.sync.kick();
        await Future<void>.delayed(const Duration(milliseconds: 260));
        // And the wire goes back to normal. The latency is on every request, not on the one
        // message that asked for it, so leaving it set meant nothing else could settle either:
        // the record came back with five rows all reading `going` and no typing indicator, because
        // the far phone's own frame could not cross in the time the step waited for it. The row
        // that has to look like it is still going is the one the scene sends last, and it gets its
        // own latency then.
        t.scriptedFaults.setLatency(Duration.zero);
        scope.sync.kick();
        await Future<void>.delayed(const Duration(milliseconds: 900));
      }
      // pinned to the bottom, so the five states are the five rows above the composer rather than
      // whichever three fitted above the anchor
      await _scrollToAnchor('end');
    };
    CaptureBus.sendSlowly = (text, slowMs) async {
      final scope = AppScope.of(context);
      final t = scope.transport;
      if (t is LocalTransport) t.scriptedFaults.setLatency(Duration(milliseconds: slowMs));
      await scope.emit('message', {'text': text});
      // not awaited: the push is the thing being photographed, so the handle returns while it is
      // still going and the harness takes the picture into it
      scope.sync.kick();
      await Future<void>.delayed(const Duration(milliseconds: 120));
    };
    CaptureBus.unfoldAll = Folds.openAll;
    CaptureBus.chatReport = () {
      final ps = _positions.itemPositions.value.toList()..sort((a, b) => a.index.compareTo(b.index));
      final items = AppScope.of(context).thread.items;
      // A row the list reports as visible may be a sliver of itself with its writing above the top
      // edge or below the bottom one, and the record used to count that as a state on the glass:
      // 13 said `read: 1` for a row that is 125 device pixels of blank paper in the frame, and
      // there is no read mark anywhere in the picture. A row counts as on the glass only when the
      // whole of it is; anything clipped is listed separately with how much of it is showing, so
      // the record says what is in the frame and what is only nearly in it.
      bool whole(ItemPosition p) => p.itemLeadingEdge >= 0.0 && p.itemTrailingEdge <= 1.0;
      final shown = [for (final p in ps) if (p.index < items.length && whole(p)) p];
      final clipped = [for (final p in ps) if (p.index < items.length && !whole(p)) p];
      return {
        'visible': [for (final p in ps) if (p.index < items.length) items[p.index].id],
        'whole_on_the_glass': [for (final p in shown) items[p.index].id],
        'clipped_at_an_edge': {
          for (final p in clipped)
            items[p.index].id: double.parse(
                (((p.itemTrailingEdge.clamp(0.0, 1.0) - p.itemLeadingEdge.clamp(0.0, 1.0)) /
                        (p.itemTrailingEdge - p.itemLeadingEdge))
                    .clamp(0.0, 1.0)
                    .toStringAsFixed(3))),
        },
        // What each row on the glass says about itself. The artifact named for the messenger's
        // states carried no record of any row's state, so a critic could only read the marks off
        // the picture and count them all the same; there was nothing to check the picture against.
        // Only the rows that actually draw one. A delivery mark is about writing on its way, so a
        // row that has been taken back draws none — and the record used to count it anyway, which
        // is a record of something that is not in the frame. The word is the word on the paper.
        'delivery': {
          for (final p in ps)
            if (p.index < items.length && _drawsADeliveryMark(items[p.index]))
              items[p.index].id: {
                'state': items[p.index].delivery.name,
                'says': deliverySays(items[p.index].delivery),
              },
        },
        // counted over the rows that are wholly in the frame, because this number is a claim
        // about the picture
        'states_on_the_glass': {
          for (final d in {
            for (final p in shown)
              if (_drawsADeliveryMark(items[p.index])) deliverySays(items[p.index].delivery)
          })
            d: [
              for (final p in shown)
                if (_drawsADeliveryMark(items[p.index]) &&
                    deliverySays(items[p.index].delivery) == d)
                  items[p.index].id
            ].length,
        },
        'reactions': {
          for (final p in ps)
            if (p.index < items.length && items[p.index].reactions.isNotEmpty)
              items[p.index].id: items[p.index].reactions.length,
        },
        'edited': [
          for (final p in ps)
            if (p.index < items.length && items[p.index].edited) items[p.index].id
        ],
        'taken_back': [
          for (final p in ps)
            if (p.index < items.length && items[p.index].deleted) items[p.index].id
        ],
        'scroll': ps.isEmpty ? null : {'first': ps.first.index, 'last': ps.last.index, 'of': items.length},
        // how many of those rows are a piece of paper with most of itself on the glass, as against
        // a pencil line in the margin or a row peeking in at the edge
        'paper': [
          for (final p in ps)
            if (p.index < items.length && _isPaper(items[p.index].type)) items[p.index].id,
        ],
        'paper_whole_on_the_glass': _paperOnTheGlass(items).$2,
        // and what each of them cost, in logical pixels of the thread's own viewport, so a claim
        // about how much fits in a frame is answered by the frame
        'rows_cost': [
          for (final p in ps)
            if (p.index < items.length)
              {
                'row': p.index,
                'type': items[p.index].type,
                'tall': double.parse(
                    ((p.itemTrailingEdge - p.itemLeadingEdge) * _viewportTall).toStringAsFixed(1)),
                'top': double.parse((p.itemLeadingEdge * _viewportTall).toStringAsFixed(1)),
              },
        ],
        'viewport_tall': double.parse(_viewportTall.toStringAsFixed(1)),
        'composer': _text.text,
        'attaching': _attaching,
        'replying_to': _replyTo?.id,
        // and the replies that have actually landed and are on the glass, each with the row it
        // answers. `replying_to` alone is the composer holding one, which is a different thing:
        // a messenger critic read every report in the set, found the composer field six times and
        // a delivered reply nowhere, and capped the row on it.
        'replies_on_the_glass': {
          for (final p in shown)
            if (items[p.index].replyTo != null)
              items[p.index].id: items[p.index].replyTo,
        },
        'editing': _editing?.id,
        'anchor': _lastAnchor,
        // what kinds of paper are actually in the frame, so a claim that the messenger can carry
        // a voice note is answered by the picture rather than by this file
        'kinds': {
          for (final k in {for (final p in ps) if (p.index < items.length) items[p.index].type})
            k: [for (final p in ps) if (p.index < items.length && items[p.index].type == k) items[p.index].id].length,
        },
        // and the kinds that are on the glass without a row of their own: a reaction is an object
        // stuck to the note it answers, an edit is a caret on the row it changed, a delete is the
        // stub left behind, a read marker is a pair of ticks. A completeness pass counted the types
        // the capture can show against the eighteen the registry holds and found seven, because
        // these four are only ever folded onto somebody else's row and the record never named them.
        'folded_in': {
          'reaction': [
            for (final p in ps)
              if (p.index < items.length) ...items[p.index].reactions,
          ].length,
          'message_edit': [
            for (final p in ps)
              if (p.index < items.length && items[p.index].edited) items[p.index].id,
          ].length,
          'message_delete': [
            for (final p in ps)
              if (p.index < items.length && items[p.index].deleted) items[p.index].id,
          ].length,
          'read_marker': [
            for (final p in ps)
              if (p.index < items.length && items[p.index].delivery == Delivery.read) items[p.index].id,
          ].length,
        },
      };
    };
  }

  /// Land the thread on an anchor: an event id, a fraction of the way through, the end, or
  /// `types:a,b` — the tightest stretch of the real thread that holds one of each of those kinds.
  ///
  /// The last form is how a capture frames a voice note beside a video without anybody writing
  /// down a row number: a fraction is only ever right for one build of the seed, and the day a
  /// row is added it points at bare desk instead. This asks the thread where those kinds actually
  /// sit and goes there.
  Future<void> _scrollToAnchor(String anchor) async {
    final items = AppScope.of(context).thread.items;
    if (items.isEmpty || !_scroll.isAttached) return;
    int index;
    if (anchor == 'end') {
      // the spacer, pinned to the bottom of the viewport, which leaves the newest note whole
      // above it however tall it turned out to be
      _scroll.jumpTo(index: items.length, alignment: 0.985);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      return;
    } else if (anchor.startsWith('types:')) {
      final wanted = anchor.substring(6).split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      final windows = _tightestWindows(items, wanted);
      if (windows.isEmpty) return;
      // Every equally tight stretch, tried and *measured*, latest first, until one of them holds
      // the hero's own standard.
      //
      // The hero's standard is eight notes on eight different torn edges — it is the frame the
      // material row is judged on at three hundred per cent. Which stretch of a year does that
      // cannot be worked out in advance: it depends on how tall each row turns out, and a row's
      // height is how much writing is on it, how many words wrapped, whether something is stuck
      // to it. Guessing it from the text length got six notes, then seven. So this asks the
      // thread. It goes to a stretch, lets it lay out, counts what actually landed on the glass,
      // and keeps the best framing it has seen — stopping at the first that meets the standard,
      // which is the most recent one, because the most recent is what now looks like.
      (int, int)? chosen;
      var chosenAlign = _wheresToStand.first;
      var most = -1;
      var mostWhole = -1;
      var tried = 0;
      for (final w in windows) {
        if (tried >= _framingsToTry) break;
        for (final align in _wheresToStand) {
          tried++;
          _scroll.jumpTo(index: w.$1, alignment: align);
          await Future<void>.delayed(const Duration(milliseconds: 40));
          // the rows that were asked for have to be whole in the frame, or the framing is not a
          // picture of them: a photograph seven hundred pixels tall once came out as a sliver
          // with its caption cut in half by the edge, and three critics measured the sliver
          if (!_wholeOnTheGlass(w)) continue;
          // How much paper is on the glass, and how much of it is whole. The first is the
          // standard's own count — a thread runs off the top of the frame, and a note the edge
          // crosses is a note on the screen. The second is what the picture is worth looking at:
          // between two framings that show the same amount of paper, the one that shows more of
          // it whole is the better photograph.
          final (onIt, whole) = _paperOnTheGlass(items);
          if (onIt > most || (onIt == most && whole > mostWhole)) {
            most = onIt;
            mostWhole = whole;
            chosen = w;
            chosenAlign = align;
          }
        }
        if (most >= _theHerosStandard && mostWhole >= _theHerosStandard - 1) break;
      }
      if (chosen == null) {
        // nothing framed the stretch whole; the first one, framed from the top, is the honest shot
        chosen = windows.first;
        _scroll.jumpTo(index: chosen.$1, alignment: _wheresToStand.first);
        await Future<void>.delayed(const Duration(milliseconds: 40));
        _lastAnchor = 'types:${wanted.join(',')} at rows ${chosen.$1} to ${chosen.$2} of '
            '${items.length}: no framing held the stretch whole';
        return;
      }
      _scroll.jumpTo(index: chosen.$1, alignment: chosenAlign);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      _lastAnchor = 'types:${wanted.join(',')} at rows ${chosen.$1} to ${chosen.$2} of '
          '${items.length}, $most sheets on the glass and $mostWhole of them whole, the best of '
          '$tried framings of ${windows.length} stretches';
      return;
    } else {
      final fraction = double.tryParse(anchor);
      index = fraction != null
          ? (fraction.clamp(0.0, 1.0) * (items.length - 1)).round()
          : items.indexWhere((it) => it.id == anchor);
    }
    if (index < 0) return;
    _lastAnchor = 'row $index of ${items.length}';
    _scroll.jumpTo(index: index, alignment: 0.35);
    await Future<void>.delayed(const Duration(milliseconds: 40));
  }

  /// The hero's own standard: eight rows on the glass, each on its own torn edge.
  static const int _theHerosStandard = 8;

  /// How many framings the search will try before it settles for the best it has seen. Each one
  /// is a jump and a layout of the whole viewport, which is a few hundredths of a second.
  static const int _framingsToTry = 400;

  /// How many rows longer than the shortest a stretch may be and still be worth framing.
  static const int _slack = 10;

  /// Where the stretch's first row sits in the frame. The thread you write on is a sheet *below*
  /// the list, not over it, so the whole viewport is thread: framing a third of the way down was
  /// throwing away a row's worth of room. Three of them, because where a row lands decides
  /// whether the row after it is whole on the glass or half under the edge.
  static const List<double> _wheresToStand = [0.02, 0.14, 0.28, 0.45, 0.62, 0.78];

  /// Whether every row of [w] is whole in the frame.
  bool _wholeOnTheGlass((int, int) w) {
    for (var i = w.$1; i <= w.$2; i++) {
      final p = _positions.itemPositions.value.where((x) => x.index == i).firstOrNull;
      if (p == null || p.itemLeadingEdge < 0 || p.itemTrailingEdge > 1) return false;
    }
    return true;
  }

  /// How many pieces of paper landed on the glass, and how many of those are mostly whole.
  ///
  /// Not every row is paper: a pencil line in the margin has no torn edge and is not a note to
  /// anyone looking at the picture, and the hero's standard is eight notes on eight different
  /// torn edges. A note the top of the frame crosses is still a note on the screen — a thread
  /// runs off the frame in both directions, which is what a thread does — so it counts for the
  /// first number and not for the second.
  (int, int) _paperOnTheGlass(List<ThreadItem> items) {
    var onIt = 0;
    var whole = 0;
    for (final p in _positions.itemPositions.value) {
      if (p.index >= items.length) continue;
      if (!_isPaper(items[p.index].type)) continue;
      final tall = p.itemTrailingEdge - p.itemLeadingEdge;
      if (tall <= 0) continue;
      onIt++;
      final shown = p.itemTrailingEdge.clamp(0.0, 1.0) - p.itemLeadingEdge.clamp(0.0, 1.0);
      if (shown / tall >= 0.6) whole++;
    }
    return (onIt, whole);
  }

  /// How tall the thread's own viewport is, in logical pixels. Item positions are fractions of
  /// it, and a fraction says nothing about whether another note would have fitted.
  double get _viewportTall => _livePosition()?.viewportDimension ?? 0;

  /// Whether this row draws a delivery mark: mine, and not taken back.
  bool _drawsADeliveryMark(ThreadItem it) =>
      it.event.author == AppScope.of(context).me && !it.deleted;

  /// Whether a row of this kind is a piece of paper with a torn edge.
  ///
  /// Said by naming what is not one, and by the renderer rather than the type. The first version
  /// of this listed the seven types that are notes and five of them belonged to modules — which is
  /// a per-module table in a region, the thing `module_costs_test` exists to stop, and it stopped
  /// it. A module's row is paper by default, which is what a module's row is: a ticket stub, a
  /// line on a list, a stamped card. What is not paper is a mark made on something else — a thrown
  /// object, a reaction stuck to a note, a pencil line in the margin, the mark left where a note
  /// was taken back.
  static bool _isPaper(String type) {
    final renderer = kEventTypeById[type]?.renderer;
    return renderer != null &&
        !const {
          'object_landing', 'stuck_object', 'margin_note', 'margin_mark',
          'edit_mark', 'stub', 'ink_dries',
        }.contains(renderer);
  }

  /// The shortest run of rows holding at least one of every kind in [wanted], latest such run
  /// first — a couple's year has several, and the most recent is the one that looks like now.
  /// Null when the thread has no run holding all of them.
  ///
  /// A kind is an event type, or one of two things a row *is* rather than is of:
  ///
  ///   - `reacted` — a row with something stuck to it. A reaction is not a row of its own (the
  ///     registry says `rowInThread: false`), so no list of types can ask for one, and a critic
  ///     stepping every row of three artifacts and three hundred frames found not one reaction in
  ///     the evidence while four hundred and thirty sit in the seeded year.
  ///   - `reply` — a row written in answer to another, which carries the strip of the one it
  ///     answers pinned above it.
  List<(int, int)> _tightestWindows(List<ThreadItem> items, List<String> wanted) {
    if (wanted.isEmpty) return const [];
    final seen = <String, int>{};
    final tight = <(int, int)>[];
    var shortest = 1 << 30;
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      final kinds = <String>{
        it.type,
        if (it.reactions.isNotEmpty) 'reacted',
        if (it.replyTo != null) 'reply',
      };
      final here = kinds.where(wanted.contains);
      if (here.isEmpty) continue;
      for (final k in here) {
        seen[k] = i;
      }
      if (seen.length < wanted.length) continue;
      final lo = seen.values.reduce((a, b) => a < b ? a : b);
      final span = i - lo;
      if (span < shortest) shortest = span;
      tight.add((lo, i));
    }
    // Not only the shortest: every stretch within a few rows of it.
    //
    // Asking for a voice note and a reaction found six stretches in a year, because it read that
    // as one row being both, and six framings of six places is not a search. A voice note with a
    // photograph two rows below it that somebody has stuck a reaction to is the same day and a
    // truer picture of one. What the slack buys is room to look: dozens of stretches instead of
    // six, and the standard is eight notes on the glass, which is a property of what surrounds a
    // stretch rather than of the stretch itself.
    tight.removeWhere((w) => w.$2 - w.$1 > shortest + _slack);
    // Latest first, but paper first of all.
    //
    // A couple's year has dozens of stretches holding one of each kind and the most recent is the
    // one that looks like now, so recency is how ties are broken. What decides the order is how
    // much paper surrounds a stretch: the standard is eight notes on eight torn edges, a stretch
    // sitting among pencil lines in the margin and thrown objects cannot meet it however it is
    // framed, and every framing tried is a jump and a layout of a viewport onto eight thousand
    // rows. Ordered by recency alone the search laid out a hundred and ninety-eight framings
    // before it found the one; this is the same search with the promising places first.
    final ordered = tight.reversed.toList();
    int paperAround((int, int) w) {
      var n = 0;
      for (var i = w.$1 - 2; i <= w.$1 + 8 && i < items.length; i++) {
        if (i >= 0 && _isPaper(items[i].type)) n++;
      }
      return n;
    }
    final promise = {for (final w in ordered) w: paperAround(w)};
    ordered.sort((a, b) => promise[b]!.compareTo(promise[a]!));
    return ordered;
  }

  /// Where the last `scrollTo` put the thread, in the thread's own words, for the scene log.
  String? _lastAnchor;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_draftLoaded) {
      _draftLoaded = true;
      AppScope.of(context).spine.meta('draft.chat').then((d) {
        if (d != null && d.isNotEmpty && _text.text.isEmpty) _text.text = d;
      });
    }
    _scheduleRead();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _text.dispose();
    _draftTimer?.cancel();
    _typingTimer?.cancel();
    _readTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  // ---- drafts and typing --------------------------------------------------------------------
  void _onTextChanged() {
    final scope = AppScope.of(context);
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 400), () => scope.spine.setMeta('draft.chat', _text.text));
    if (_text.text.isNotEmpty && !_typingSent) {
      _typingSent = true;
      scope.sendTyping(true);
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 4), () {
      _typingSent = false;
      scope.sendTyping(false);
    });
  }

  void _scheduleRead() {
    _readTimer?.cancel();
    _readTimer = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      AppScope.of(context).markRead();
    });
  }

  // ---- sending --------------------------------------------------------------------------------
  Future<void> _send() async {
    final scope = AppScope.of(context);
    final text = _text.text.trim();
    if (text.isEmpty) return;
    final editing = _editing;
    final replyTo = _replyTo;
    _text.clear();
    setState(() {
      _editing = null;
      _replyTo = null;
    });
    await scope.spine.setMeta('draft.chat', null);
    _typingSent = false;
    scope.sendTyping(false);
    if (editing != null) {
      await scope.emit('message_edit', {'target': editing.id, 'text': text});
    } else {
      await scope.emit('message', {'text': text, if (replyTo != null) 'reply_to': replyTo.id});
    }
    _scrollToEnd();
  }

  Future<void> _sendPhoto({bool camera = false}) async {
    final scope = AppScope.of(context);
    final m = await _media.pickPhoto(camera: camera);
    if (m == null) return;
    final hash = await scope.spine.putBlob(m.bytes, m.mime);
    await scope.emit('photo', {'blob': hash, 'w': m.w, 'h': m.h, 'mime': m.mime, if (_replyTo != null) 'reply_to': _replyTo!.id});
    setState(() => _replyTo = null);
    _scrollToEnd();
  }

  Future<void> _sendVideo({bool camera = false}) async {
    final scope = AppScope.of(context);
    final m = await _media.pickVideo(camera: camera);
    if (m == null) return;
    final hash = await scope.spine.putBlob(m.bytes, m.mime);
    // poster: a flat placeholder until the app can decode a frame on both platforms
    final poster = await scope.spine.putBlob(kPosterPng, 'image/png');
    await scope.emit('video', {'blob': hash, 'poster_blob': poster, 'duration_ms': m.durationMs ?? 0, 'w': m.w, 'h': m.h, 'mime': m.mime});
    _scrollToEnd();
  }

  Future<void> _startRecording() async {
    final path = await recordingPath();
    final ok = await _recorder.start(path);
    if (ok) setState(() => _recording = true);
  }

  Future<void> _stopRecording() async {
    if (!_recording) return;
    setState(() => _recording = false);
    final scope = AppScope.of(context);
    final r = await _recorder.stop(readBytesAt);
    if (r == null || r.$3 < 500) return;
    final hash = await scope.spine.putBlob(r.$1, r.$2);
    await scope.emit('voice_note', {'blob': hash, 'duration_ms': r.$3, 'waveform': r.$4, 'mime': r.$2});
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final n = AppScope.of(context).thread.items.length;
      // Onto the spacer that sits under the newest note, exactly as the thread does when it
      // opens. It used to put the newest note's *top* four fifths of the way down the screen, so
      // anything more than a line of it ran off the bottom behind the composer: the thing that
      // had just arrived was the one thing you could not read.
      if (n > 0 && _scroll.isAttached) _scroll.jumpTo(index: n, alignment: 0.985);
    });
  }

  // ---- actions ---------------------------------------------------------------------------------
  Future<void> _actions(ThreadItem item, FeelingRegistry registry) async {
    final scope = AppScope.of(context);
    final mine = item.author == scope.me;
    final choices = <String>[
      // first, because it is the only thing to be done about a row that did not go
      if (mine && item.delivery == Delivery.refused) S.sendAgain,
      S.reply,
      S.react,
      if (mine && item.type == 'message' && !item.deleted) S.edit,
      if (mine && !item.deleted) S.delete,
    ];
    final picked = await _pickWord(context, choices);
    if (picked == null || !mounted) return;
    if (picked == S.reply) {
      setState(() => _replyTo = item);
    } else if (picked == S.react) {
      final f = await _pickFeeling(registry);
      if (f != null && mounted) await AppScope.of(context).emit('reaction', {'target': item.id, 'feeling_id': f.id});
    } else if (picked == S.edit) {
      setState(() {
        _editing = item;
        _text.text = item.text ?? '';
      });
    } else if (picked == S.delete) {
      await AppScope.of(context).emit('message_delete', {'target': item.id});
    } else if (picked == S.sendAgain) {
      scope.spine.sendAgain(item.id);
      scope.sync.kick();
    }
  }

  /// What can be done to a note: the words, written out, on the desk under it.
  Future<String?> _pickWord(BuildContext context, List<String> words) => showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.transparent,
        barrierColor: Shadow.warm.withValues(alpha: 0.18),
        builder: (ctx) => DeskSheet(
          id: 'what.can.be.done',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(padding: EdgeInsets.only(bottom: 2), child: RuleLine(seed: 41)),
              for (final w in words)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.pop(ctx, w),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(w, style: Hands.teo(size: 20)),
                  ),
                ),
            ],
          ),
        ),
      );

  /// The vocabulary, as objects on the desk, grouped by family the way docs/FEELINGS.md groups it.
  Future<Feeling?> _pickFeeling(FeelingRegistry registry) => showModalBottomSheet<Feeling>(
        context: context,
        backgroundColor: Colors.transparent,
        barrierColor: Shadow.warm.withValues(alpha: 0.18),
        builder: (ctx) => DeskSheet(
          id: 'the.vocabulary',
          row: 2,
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            children: [
                for (final fam in Family.values)
                  if (registry.family(fam).isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 10, 0, 6),
                      child: Stamped(fam.label, size: 10),
                    ),
                    Wrap(
                      spacing: 14,
                      runSpacing: 10,
                      children: [
                        for (final f in registry.family(fam))
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => Navigator.pop(ctx, f),
                            child: SizedBox(
                              width: 62,
                              child: Column(
                                children: [
                                  FeelingObject(feeling: f, size: 42, intensity: 0.7),
                                  Text(f.name, textAlign: TextAlign.center, style: Hands.margin(size: 11)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
          ],
          ),
        ),
      );

  void _search() => setState(() {
        _searching = true;
        _searchQuery = '';
      });

  void _searchDone(String? id) {
    setState(() => _searching = false);
    if (id == null) return;
    // the thread is being rebuilt in the search's place; it can be scrolled once it is there
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _goTo(id);
    });
  }

  void _goTo(String id) {
    final items = AppScope.of(context).thread.items;
    final i = items.indexWhere((it) => it.id == id);
    if (i < 0) return;
    setState(() => _highlightId = id);
    if (_scroll.isAttached) _scroll.scrollTo(index: i, duration: const Duration(milliseconds: 300), alignment: 0.3);
    Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _highlightId = null);
    });
  }

  // ---- build -----------------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final items = scope.thread.items;
    final registry = scope.feelings;
    if (items.length != _lastCount) {
      final wasAtEnd = _lastCount == 0 || _nearEnd();
      _lastCount = items.length;
      _scheduleRead();
      if (wasAtEnd) _scrollToEnd();
    }
    if (_searching) {
      return SearchPage(key: ValueKey('search.$_searchQuery'), initialQuery: _searchQuery, onDone: _searchDone);
    }
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              items.isEmpty
                  ? const EmptySurface(id: 'chat', line: S.emptyChat, aside: S.emptyChatAside)
                  : ScrollablePositionedList.builder(
                      key: _listKey,
                      itemScrollController: _scroll,
                      scrollOffsetController: _offset,
                      itemPositionsListener: _positions,
                      // one more than there are notes: the last index is a hand's width of bare
                      // desk under the newest note. Without it there is nothing to scroll the
                      // newest note *to* — the list positions an item by its leading edge, so
                      // `the end` put the last note's top part way down the screen and let the
                      // rest of it run under the composer.
                      itemCount: items.length + 1,
                      initialScrollIndex: items.length,
                      initialAlignment: 0.985,
                      itemBuilder: (context, i) {
                        if (i == items.length) return const SizedBox(height: 10);
                        final it = items[i];
                        return Note(
                          key: ValueKey(it.id),
                          item: it,
                          row: i,
                          unreadFrom: _arrivedAt ??= scope.thread.readUpto[scope.me] ?? 0,
                          registry: registry,
                          highlight: it.id == _highlightId,
                          // not in the thread when it was opened: it has just arrived
                          arrived: !(_openedWith ??= {for (final x in items) x.id}).contains(it.id),
                          onLongPress: () => _actions(it, registry),
                        );
                      },
                    ),
            ],
          ),
        ),
        // Everything you write and everything the app says about what you are writing sits on one
        // sheet at the bottom of the desk. It used to be drawn straight onto the wood, and wood is
        // dark: the reply banner measured 1.78:1, the attachment row 2.19:1 and the draft 2.22:1
        // against a placeholder at 4.44:1 — the text you type was half as legible as the prompt
        // telling you to type it. You write on paper. Everything under here is on paper.
        _WritingPad(children: [
        if (scope.partnerTyping)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('${scope.partner.name} ${S.typing}',
                  style: Hands.margin(size: 13).copyWith(color: Pen.margin)),
            ),
          ),
        if (_replyTo != null || _editing != null)
          _Answering(
            // A row without text — a state, a ritual, a day that mattered — still has a sentence
            // in the couple's own words; what it must never show is its registry id. The banner
            // read 'answering state_declared' on a captured frame, which is the app talking to
            // itself in front of somebody.
            label: _editing != null
                ? S.editHint
                : '${S.replyingTo} ${_replyTo!.text ?? summaryOf(_replyTo!.event, me: scope.me)}',
            onDrop: () => setState(() {
              _replyTo = null;
              if (_editing != null) _text.clear();
              _editing = null;
            }),
          ),
        if (_attaching)
          _AttachStrip(
            onPick: (what) {
              setState(() => _attaching = false);
              switch (what) {
                case 'photo':
                  _sendPhoto();
                case 'camera':
                  _sendPhoto(camera: true);
                case 'video':
                  _sendVideo();
                case 'film':
                  _sendVideo(camera: true);
              }
            },
          ),
        _Composer(
          controller: _text,
          hand: Hands.of(scope.me, size: 18),
          recording: _recording,
          attaching: _attaching,
          onAttach: () => setState(() => _attaching = !_attaching),
          onSearch: _search,
          onSend: _send,
          onRecordStart: _startRecording,
          onRecordStop: _stopRecording,
        ),
        ]),
      ],
    );
  }

  /// Whether the thread is showing its own end — the spacer, or one of the last two notes. What
  /// decides whether something arriving brings itself into view or waits where it is: a thread
  /// somebody has scrolled back through does not yank itself away from them.
  bool _nearEnd() {
    final ps = _positions.itemPositions.value;
    if (ps.isEmpty) return true;
    final maxIndex = ps.map((p) => p.index).reduce((a, b) => a > b ? a : b);
    return maxIndex >= _lastCount - 2;
  }
}

/// The sheet at the bottom of the desk that everything you are writing sits on: the draft, the
/// line saying what is being answered, what else can go in the envelope, and the note that they
/// are writing too.
///
/// One piece of paper rather than four things on wood. Four surfaces drawn straight onto the desk
/// measured 1.76 to 2.22 to 1 — a draft you could not read, under a placeholder you could.
class _WritingPad extends StatelessWidget {
  const _WritingPad({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Stack(
        // the shadow this sheet throws falls on the thread above it, which is outside this box
        clipBehavior: Clip.none,
        children: [
          // The sheet you write on lies over the bottom of the thread, and a sheet lying over
          // another one throws a shadow onto it. Without this the thread simply stopped: measured
          // on the hero, the last note ended in "a 138-grey step in a single un-antialiased pixel
          // row across 804 columns", with the desk two pixels beneath it reading 94.64 against
          // 94.61 twelve pixels away — a 0.03-grey difference where every other sheet on the
          // screen carries a shadow about forty grey deep. A cut with no shadow under it is a
          // hole in the picture, not a sheet in front of another sheet.
          Positioned(
            left: 8,
            right: 8,
            top: -13,
            height: 14,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Shadow.warm.withValues(alpha: 0.0),
                      Shadow.warm.withValues(alpha: 0.30),
                    ],
                    stops: const [0.0, 1.0],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Slip(
              id: 'chat.writing',
              stock: 'looseleaf',
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
              child: Column(mainAxisSize: MainAxisSize.min, children: children),
            ),
          ),
        ],
      );
}

/// The composer: a ruled line to write on, a clip for what else can go in the envelope, three
/// ticks that swell while a voice note is being made, and the word send.
class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.hand,
    required this.recording,
    required this.attaching,
    required this.onAttach,
    required this.onSearch,
    required this.onSend,
    required this.onRecordStart,
    required this.onRecordStop,
  });
  final TextEditingController controller;
  final TextStyle hand;
  final bool recording;
  final bool attaching;
  final VoidCallback onAttach;
  final VoidCallback onSearch;
  final VoidCallback onSend;
  final VoidCallback onRecordStart;
  final VoidCallback onRecordStop;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Finding something lives on the sheet at the bottom of the desk, beside the clip and
          // the ticks, rather than pinned over the thread.
          //
          // It used to be a slip floating top right with the year scrolling under it, and opaque
          // paper over a message is a message you cannot read: a completeness pass measured it
          // covering thread text in 84 of the scroll clip's 300 frames. A strip of its own above
          // the list costs a row of desk — the hero framing went from seven whole sheets to six —
          // and this costs none: the composer is already there, and it is already the row of marks
          // this thread is worked from.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onSearch,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 6, 8),
              child: Mark.loop(size: 19, colour: Pen.margin),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onAttach,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
              child: Mark.clip(size: 21, colour: attaching ? Pen.ballpoint : Pen.margin),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 6,
                  style: hand,
                  cursorColor: Pen.ballpoint,
                  cursorWidth: 1.2,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.fromLTRB(0, 6, 0, 5),
                    hintText: recording ? S.recording : S.composerHint,
                    hintStyle: Hands.margin(size: 16).copyWith(color: Pen.margin),
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                  ),
                ),
                const RuleLine(seed: 29),
              ],
            ),
          ),
          GestureDetector(
            onLongPressStart: (_) => onRecordStart(),
            onLongPressEnd: (_) => onRecordStop(),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
              child: Mark.ticks(
                size: 22,
                level: recording ? 1 : 0,
                colour: recording ? Pen.red : Pen.margin,
              ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onSend,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(2, 6, 2, 8),
              child: Text(S.send, style: Hands.margin(size: 16).copyWith(color: Pen.ballpoint)),
            ),
          ),
        ],
      ),
    );
  }
}

/// The line that says what is being answered or changed, written in the margin beside the
/// composer rather than shown as a card.
class _Answering extends StatelessWidget {
  const _Answering({required this.label, required this.onDrop});
  final String label;
  final VoidCallback onDrop;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 2, 14, 0),
        child: Row(
          children: [
            Mark.turnback(size: 17),
            const SizedBox(width: 6),
            Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Hands.margin(size: 14))),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onDrop,
              child: Padding(padding: const EdgeInsets.all(6), child: Mark.cross(size: 14)),
            ),
          ],
        ),
      );
}

/// What else can go in: four words on the desk, not a menu.
class _AttachStrip extends StatelessWidget {
  const _AttachStrip({required this.onPick});
  final void Function(String what) onPick;

  static const _choices = [
    ('photo', 'a photo'),
    ('camera', 'take one'),
    ('video', 'a video'),
    ('film', 'film something'),
  ];

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(30, 4, 14, 2),
        child: Row(
          children: [
            for (final (id, word) in _choices)
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onPick(id),
                  child: Text(word, style: Hands.teo(size: 16).copyWith(color: Pen.ballpoint)),
                ),
              ),
          ],
        ),
      );
}

/// A 1×1 grey PNG used as a video poster until frame extraction exists on both platforms.
final Uint8List kPosterPng = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01,
  0x00, 0x00, 0x00, 0x01, 0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41,
  0x54, 0x08, 0xD7, 0x63, 0x60, 0x60, 0x60, 0x00, 0x00, 0x00, 0x04, 0x00, 0x01, 0x27, 0x34, 0x27, 0x0A, 0x00, 0x00, 0x00,
  0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

// unused import guard for platforms without file paths
// ignore: unused_element
final _keep = isWebPlatform;
