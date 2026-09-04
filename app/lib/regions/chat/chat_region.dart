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
import '../../spine/projections/thread.dart';
import '../../voice/strings.dart';
import 'note.dart';
import 'search_page.dart';
import 'viewer_page.dart';

class ChatRegion extends StatefulWidget {
  const ChatRegion({super.key});

  @override
  State<ChatRegion> createState() => _ChatRegionState();
}

class _ChatRegionState extends State<ChatRegion> with WidgetsBindingObserver {
  final _text = TextEditingController();
  final _scroll = ItemScrollController();
  final _positions = ItemPositionsListener.create();
  final _media = MediaCapture();
  final _recorder = VoiceRecorder();
  Timer? _draftTimer;
  Timer? _typingTimer;
  Timer? _readTimer;
  bool _typingSent = false;
  ThreadItem? _replyTo;
  ThreadItem? _editing;
  String? _highlightId;
  bool _recording = false;
  int _lastCount = 0;
  bool _draftLoaded = false;
  bool _attaching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _text.addListener(_onTextChanged);
    if (Flags.capture) _offerHandles();
  }

  /// Capture mode: the same four things a thumb does in Chat, reachable from the harness.
  void _offerHandles() {
    CaptureBus.scrollTo = _scrollToAnchor;
    CaptureBus.openSender = (open) => setState(() => _attaching = open);
    // an event id, or a type ('photo', 'video') meaning the most recent one of that kind
    CaptureBus.openViewer = (idOrType) async {
      final items = AppScope.of(context).thread.items;
      var it = items.where((i) => i.id == idOrType).firstOrNull;
      if (it == null) {
        final ofType = items.where((i) => i.type == idOrType).toList();
        if (ofType.isEmpty) return;
        it = ofType[ofType.length ~/ 2];
        await _scrollToAnchor(it.id);
      }
      if (!mounted) return;
      await ViewerPage.open(context, it);
    };
    CaptureBus.search = (q) => _land(q);
    CaptureBus.unfoldAll = Folds.openAll;
    CaptureBus.chatReport = () {
      final ps = _positions.itemPositions.value.toList()..sort((a, b) => a.index.compareTo(b.index));
      final items = AppScope.of(context).thread.items;
      return {
        'visible': [for (final p in ps) if (p.index < items.length) items[p.index].id],
        'scroll': ps.isEmpty ? null : {'first': ps.first.index, 'last': ps.last.index, 'of': items.length},
        'composer': _text.text,
        'attaching': _attaching,
        'replying_to': _replyTo?.id,
        'editing': _editing?.id,
      };
    };
  }

  /// Land the thread on an anchor: an event id, a fraction of the way through, or the end.
  Future<void> _scrollToAnchor(String anchor) async {
    final items = AppScope.of(context).thread.items;
    if (items.isEmpty || !_scroll.isAttached) return;
    int index;
    if (anchor == 'end') {
      index = items.length - 1;
    } else {
      final fraction = double.tryParse(anchor);
      index = fraction != null
          ? (fraction.clamp(0.0, 1.0) * (items.length - 1)).round()
          : items.indexWhere((it) => it.id == anchor);
    }
    if (index < 0) return;
    _scroll.jumpTo(index: index, alignment: 0.35);
    await Future<void>.delayed(const Duration(milliseconds: 40));
  }

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
      if (n > 0 && _scroll.isAttached) _scroll.jumpTo(index: n - 1, alignment: 0.8);
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
        builder: (ctx) => Container(
          color: const Color(0xFFF1ECDF),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(padding: EdgeInsets.fromLTRB(22, 12, 0, 0), child: RuleLine(seed: 41)),
                for (final w in words)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.pop(ctx, w),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 11, 24, 11),
                      child: Text(w, style: Hands.teo(size: 20)),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      );

  /// The vocabulary, as objects on the desk, grouped by family the way docs/FEELINGS.md groups it.
  Future<Feeling?> _pickFeeling(FeelingRegistry registry) => showModalBottomSheet<Feeling>(
        context: context,
        backgroundColor: Colors.transparent,
        barrierColor: Shadow.warm.withValues(alpha: 0.18),
        builder: (ctx) => Container(
          color: const Color(0xFFF1ECDF),
          child: SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
        ),
      );

  Future<void> _search() async {
    final id = await SearchPage.open(context);
    if (id == null || !mounted) return;
    _goTo(id);
  }

  /// Run a query without the sheet and stop on the first hit: what the harness does, and what the
  /// sheet does once a hit is tapped.
  Future<void> _land(String query) async {
    final hits = AppScope.of(context).spine.search(query);
    if (hits.isEmpty || !mounted) return;
    _goTo(hits.first.event.id);
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
    final registry = FeelingRegistry(scope.spine.all);
    if (items.length != _lastCount) {
      final wasAtEnd = _lastCount == 0 || _nearEnd();
      _lastCount = items.length;
      _scheduleRead();
      if (wasAtEnd) _scrollToEnd();
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
                      itemPositionsListener: _positions,
                      itemCount: items.length,
                      initialScrollIndex: items.length - 1,
                      initialAlignment: 0.8,
                      itemBuilder: (context, i) {
                        final it = items[i];
                        return Note(
                          key: ValueKey(it.id),
                          item: it,
                          row: i,
                          registry: registry,
                          highlight: it.id == _highlightId,
                          onLongPress: () => _actions(it, registry),
                        );
                      },
                    ),
              // finding something is a loop drawn round a word, up in the margin
              Positioned(
                top: 0,
                right: 8,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _search,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 4, 4, 10),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Mark.loop(size: 17, colour: Pen.margin),
                      const SizedBox(width: 5),
                      Text(S.search, style: Hands.margin(size: 13)),
                    ]),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (scope.partnerTyping)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 2, 18, 2),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('${scope.partner.name} ${S.typing}', style: Hands.margin(size: 13)),
            ),
          ),
        if (_replyTo != null || _editing != null)
          _Answering(
            label: _editing != null ? S.editHint : '${S.replyingTo} ${_replyTo!.text ?? _replyTo!.type}',
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
      ],
    );
  }

  bool _nearEnd() {
    final ps = _positions.itemPositions.value;
    if (ps.isEmpty) return true;
    final maxIndex = ps.map((p) => p.index).reduce((a, b) => a > b ? a : b);
    return maxIndex >= _lastCount - 2;
  }
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
                    hintStyle: Hands.margin(size: 16),
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
              child: Text(S.send, style: Hands.margin(size: 16)),
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
                  child: Text(word, style: Hands.teo(size: 16)),
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
