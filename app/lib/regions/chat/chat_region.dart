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
      // a real scroll, by pixels, on the list's own controller. It used to re-enter the list at
      // a new index and alignment every step, and jumping to an index is not a scroll: the
      // positioned list tears down its active sliver and builds another one at the new index, so
      // every frame of the fling was a rebuild. The frame timings say what that cost — build p50
      // 20 ms, p95 1426, max 1785, against a raster that never leaves 166-212 — and the spikes
      // recur every third frame, which is the list swapping between its two children.
      // A duration, not zero: DrivenScrollActivity asserts duration > Duration.zero, and the
      // throw happens inside an async body where nothing sees it — the list simply did not move.
      // One millisecond of the driven clock is the shortest honest step.
      if (dy == 0 || !_scroll.isAttached) return;
      unawaited(_offset.animateScroll(offset: dy, duration: const Duration(milliseconds: 1)));
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
      if (mounted) setState(() => _replyTo = answerable);
      _text.text = 'the second one, then';
      if (mounted) setState(() {});
      await _scrollToAnchor(no.id);
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
      return {
        'visible': [for (final p in ps) if (p.index < items.length) items[p.index].id],
        // What each row on the glass says about itself. The artifact named for the messenger's
        // states carried no record of any row's state, so a critic could only read the marks off
        // the picture and count them all the same; there was nothing to check the picture against.
        'delivery': {
          for (final p in ps)
            if (p.index < items.length && items[p.index].event.author == AppScope.of(context).me)
              items[p.index].id: items[p.index].delivery.name,
        },
        'states_on_the_glass': {
          for (final d in {
            for (final p in ps)
              if (p.index < items.length && items[p.index].event.author == AppScope.of(context).me)
                items[p.index].delivery.name
          })
            d: [
              for (final p in ps)
                if (p.index < items.length &&
                    items[p.index].event.author == AppScope.of(context).me &&
                    items[p.index].delivery.name == d)
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
        'composer': _text.text,
        'attaching': _attaching,
        'replying_to': _replyTo?.id,
        'editing': _editing?.id,
        'anchor': _lastAnchor,
        // what kinds of paper are actually in the frame, so a claim that the messenger can carry
        // a voice note is answered by the picture rather than by this file
        'kinds': {
          for (final k in {for (final p in ps) if (p.index < items.length) items[p.index].type})
            k: [for (final p in ps) if (p.index < items.length && items[p.index].type == k) items[p.index].id].length,
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
      final window = _tightestWindow(items, wanted);
      if (window == null) return;
      _lastAnchor = 'types:${wanted.join(',')} at rows ${window.$1} to ${window.$2} of ${items.length}';
      // A third of the way down, measured from the stretch's *first* row: enough thread above it
      // to make the eight notes the chat hero's own standard asks for, with the rest continuing
      // below the fold, which is what a thread does. Anchoring the last row instead put the tall
      // one in the middle of the frame and left room for four.
      //
      // A whole video is a hundred and sixty points of screen and will not sit beside eight notes.
      // The hero used to ask for one anyway and got the top of it: three critics measured that
      // sliver and reported a video rendering as an empty strip, which was the framing rather than
      // the app. A video's own artifacts are the media viewer, where one is open and playing, and
      // the pile, where one is a print with the mark you press on it. What the hero asks for
      // instead is what a day of theirs looks like: a photograph with a reaction stuck to it, a
      // voice note, and the writing on both sides of it.
      _scroll.jumpTo(index: window.$1, alignment: 0.34);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      // Then look at where the last row of the stretch actually landed, and take it again if it
      // is under the composer. The first take framed the stretch's *first* row and hoped: on the
      // day the last row was a photograph seven hundred pixels tall, the shot came out with its
      // caption cut in half by the composer and the reaction stuck to its bottom corner — the one
      // thing the anchor had been asked for — entirely below the fold. What a row costs cannot be
      // known before it is laid out, so this measures rather than guesses.
      final last = _positions.itemPositions.value
          .where((p) => p.index == window.$2)
          .firstOrNull;
      if (last == null || last.itemTrailingEdge > _theComposersEdge) {
        _scroll.jumpTo(index: window.$2, alignment: 0.30);
        await Future<void>.delayed(const Duration(milliseconds: 40));
        // ...and if that pushed the row the stretch starts at off the top, it is the wrong shot:
        // a frame holding the last of the kinds and not the first is not the stretch. A whole
        // video is a hundred and sixty points and will not sit beside a voice note and eight
        // notes, so for that pair there is no framing that holds both whole and the first take
        // is the honest one. The record says which of the two this was.
        final startsHere =
            _positions.itemPositions.value.any((p) => p.index == window.$1);
        if (startsHere) {
          _lastAnchor = '$_lastAnchor, framed on its last row';
        } else {
          _scroll.jumpTo(index: window.$1, alignment: 0.34);
          _lastAnchor = '$_lastAnchor, framed on its first row: the stretch is taller than a frame';
          await Future<void>.delayed(const Duration(milliseconds: 40));
        }
      }
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

  /// Where the thread stops being visible: the composer sits over the bottom of it.
  static const double _theComposersEdge = 0.84;

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
  (int, int)? _tightestWindow(List<ThreadItem> items, List<String> wanted) {
    if (wanted.isEmpty) return null;
    final seen = <String, int>{};
    (int, int)? best;
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
      if (best == null || i - lo <= best.$2 - best.$1) best = (lo, i);
    }
    return best;
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
              // Finding something is a loop drawn round a word — on its own slip of paper, not
              // straight onto whatever the thread has scrolled under it. Drawn as bare ink it
              // overprinted the rows beneath: a completeness pass caught the word `search` and a
              // signal divider's timestamp sharing the same pixels. A thing you can pick up is a
              // thing that sits on something.
              Positioned(
                top: 2,
                right: 8,
                child: IntrinsicWidth(
                  child: Slip(
                    id: 'thread.search',
                    row: 1,
                    stock: 'index',
                    torn: false,
                    onTap: _search,
                    padding: const EdgeInsets.fromLTRB(9, 4, 11, 5),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Mark.loop(size: 15, colour: Pen.margin),
                      const SizedBox(width: 5),
                      Text(S.search, style: Hands.margin(size: 12.5)),
                    ]),
                  ),
                ),
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
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
        child: Slip(
          id: 'chat.writing',
          stock: 'looseleaf',
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
          child: Column(mainAxisSize: MainAxisSize.min, children: children),
        ),
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
    required this.onSend,
    required this.onRecordStart,
    required this.onRecordStop,
  });
  final TextEditingController controller;
  final TextStyle hand;
  final bool recording;
  final bool attaching;
  final VoidCallback onAttach;
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
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onAttach,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(2, 8, 8, 8),
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
