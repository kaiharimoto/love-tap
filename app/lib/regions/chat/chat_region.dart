// Chat: the full chronological rendering of the spine, and the complete messenger.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../feelings/builtins.dart';
import '../../feelings/registry.dart';
import '../../media/capture.dart';
import '../../media/local_uri.dart';
import '../../media/read_bytes.dart';
import '../../scope.dart';
import '../../spine/projections/thread.dart';
import '../../voice/strings.dart';
import 'rows.dart';
import 'search_page.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _text.addListener(_onTextChanged);
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
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text(S.reply),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _replyTo = item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_reaction_outlined),
              title: const Text(S.react),
              onTap: () async {
                Navigator.pop(ctx);
                final f = await _pickFeeling(registry);
                if (f != null) await scope.emit('reaction', {'target': item.id, 'feeling_id': f.id});
              },
            ),
            if (mine && item.type == 'message' && !item.deleted)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text(S.edit),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _editing = item;
                    _text.text = item.text ?? '';
                  });
                },
              ),
            if (mine && !item.deleted)
              ListTile(
                leading: const Icon(Icons.undo),
                title: const Text(S.delete),
                onTap: () async {
                  Navigator.pop(ctx);
                  await scope.emit('message_delete', {'target': item.id});
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<Feeling?> _pickFeeling(FeelingRegistry registry) => showModalBottomSheet<Feeling>(
        context: context,
        builder: (ctx) => SafeArea(
          child: ListView(
            children: [
              for (final fam in Family.values)
                ExpansionTile(
                  title: Text(fam.label),
                  initiallyExpanded: true,
                  children: [
                    Wrap(
                      spacing: 6,
                      children: [
                        for (final f in registry.family(fam))
                          ActionChip(label: Text(f.name), onPressed: () => Navigator.pop(ctx, f)),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
      );

  Future<void> _search() async {
    final id = await SearchPage.open(context);
    if (id == null || !mounted) return;
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
        Row(
          children: [
            const Spacer(),
            IconButton(tooltip: S.search, icon: const Icon(Icons.search), onPressed: _search),
          ],
        ),
        Expanded(
          child: items.isEmpty
              ? const Center(child: Text(S.emptyChat))
              : ScrollablePositionedList.builder(
                  itemScrollController: _scroll,
                  itemPositionsListener: _positions,
                  itemCount: items.length,
                  initialScrollIndex: items.length - 1,
                  initialAlignment: 0.8,
                  itemBuilder: (context, i) {
                    final it = items[i];
                    return ThreadRow(
                      key: ValueKey(it.id),
                      item: it,
                      registry: registry,
                      highlight: it.id == _highlightId,
                      onLongPress: () => _actions(it, registry),
                    );
                  },
                ),
        ),
        if (scope.partnerTyping)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(alignment: Alignment.centerLeft, child: Text('${scope.partner.name} ${S.typing}', style: Theme.of(context).textTheme.bodySmall)),
          ),
        if (_replyTo != null || _editing != null)
          ListTile(
            dense: true,
            leading: Icon(_editing != null ? Icons.edit_outlined : Icons.reply),
            title: Text(_editing != null ? S.editHint : '${S.replyingTo}: ${_replyTo!.text ?? _replyTo!.type}', maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                _replyTo = null;
                if (_editing != null) _text.clear();
                _editing = null;
              }),
            ),
          ),
        _Composer(
          controller: _text,
          recording: _recording,
          onSend: _send,
          onPhoto: _sendPhoto,
          onVideo: _sendVideo,
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

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.recording,
    required this.onSend,
    required this.onPhoto,
    required this.onVideo,
    required this.onRecordStart,
    required this.onRecordStop,
  });
  final TextEditingController controller;
  final bool recording;
  final VoidCallback onSend;
  final Future<void> Function({bool camera}) onPhoto;
  final Future<void> Function({bool camera}) onVideo;
  final VoidCallback onRecordStart;
  final VoidCallback onRecordStop;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.attach_file),
            onSelected: (v) {
              switch (v) {
                case 'photo':
                  onPhoto();
                case 'camera':
                  onPhoto(camera: true);
                case 'video':
                  onVideo();
                case 'video_camera':
                  onVideo(camera: true);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'photo', child: Text('a photo')),
              PopupMenuItem(value: 'camera', child: Text('take a photo')),
              PopupMenuItem(value: 'video', child: Text('a video')),
              PopupMenuItem(value: 'video_camera', child: Text('film something')),
            ],
          ),
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 6,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(hintText: recording ? S.recording : S.composerHint, border: const OutlineInputBorder()),
            ),
          ),
          GestureDetector(
            onLongPressStart: (_) => onRecordStart(),
            onLongPressEnd: (_) => onRecordStop(),
            child: Tooltip(
              message: S.holdToRecord,
              child: Icon(recording ? Icons.mic : Icons.mic_none, color: recording ? Colors.red : null, size: 28),
            ),
          ),
          IconButton(tooltip: S.send, icon: const Icon(Icons.send), onPressed: onSend),
        ],
      ),
    );
  }
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
