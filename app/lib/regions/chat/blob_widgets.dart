// Media from the blob store: images, voice notes, video posters.
import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../media/local_uri.dart';
import '../../scope.dart';
import '../../spine/spine.dart';
import '../../voice/strings.dart';
import 'viewer_page.dart';
import '../../spine/projections/thread.dart';
import '../../material/palette.dart';
import '../../material/paper.dart';
import '../../material/library.dart';
import '../../material/hands.dart';
import '../../material/assignment.dart';
import '../../material/marks.dart';

/// Process-wide cache of decoded blob bytes so scrolling never re-reads the store, and the only
/// place that decides how many of those reads the store is asked for at once.
///
/// It used to be the map alone, and `get` was a `putIfAbsent` that called `spine.blob` the instant
/// a widget asked. Every caller therefore issued its read immediately and the store served them in
/// the order they arrived. On the web the store is IndexedDB, which is one lane: a read is not
/// slow, it is queued, and it is queued behind every read issued before it.
///
/// That is survivable until two regions want blobs at the same moment, and `app.dart` guarantees
/// they will — the five regions live in an `IndexedStack`, so the Moments gallery is laid out and
/// is issuing reads for its tiles while the screen is showing chat. Open a photograph from the
/// thread and the viewer's own read goes to the back of a queue it did not make. Two captures have
/// photographed the result: firing 3 caught `04_moments` as a sheet of paper with every print
/// missing, firing 4 caught `14_media_viewer` as a bare desk with a caption and no photograph.
/// Firing 3 established that the prints are not lost — a twelve-second wait brings them all back —
/// which is what makes this a queue rather than a decode failure. A person on a phone sees an
/// empty frame for several seconds after tapping a photograph.
///
/// So the reads are held here instead, at most [inFlightLimit] of them in the store at once, and
/// the rest wait in a list this class can reorder. A read marked [urgent] — the thing a person is
/// actually looking at — is served before the background tiles that have not started yet. It
/// still waits for whatever is already in the store's lane, which is why the limit is small: the
/// limit is the worst case an urgent read can be made to wait.
///
/// The limit does not make the gallery slower in any way a person can see. The tiles were never
/// going to be decoded in one frame; they were going to be decoded in the order they were asked
/// for, and this changes only which order that is.
class BlobCache {
  /// How many reads the store is asked for at once.
  ///
  /// Small on purpose. An urgent read cannot overtake a read the store has already accepted, so
  /// this number is the length of the queue an urgent read can be stuck behind in the worst case.
  /// Above one, so a single slow blob cannot stall the gallery entirely.
  static const inFlightLimit = 4;

  static final Map<String, Future<StoredBlob?>> _futures = {};
  static final List<_Read> _waiting = [];
  static int _inFlight = 0;

  static Future<StoredBlob?> get(Spine spine, String hash, {bool urgent = false}) {
    final known = _futures[hash];
    if (known != null) {
      // The same blob can be asked for twice: a gallery tile and then the viewer opened on it.
      // The second ask cannot start a second read, but it can promote the first if it has not
      // left the queue yet, which is the case that matters — it is exactly the photograph the
      // person just tapped.
      if (urgent) {
        for (final r in _waiting) {
          if (r.hash == hash) r.urgent = true;
        }
        _start();
      }
      return known;
    }
    final read = _Read(spine, hash, urgent);
    _waiting.add(read);
    _futures[hash] = read.done.future;
    _start();
    return read.done.future;
  }

  static void _start() {
    while (_inFlight < inFlightLimit && _waiting.isNotEmpty) {
      var pick = _waiting.indexWhere((r) => r.urgent);
      if (pick < 0) pick = 0;
      final read = _waiting.removeAt(pick);
      _inFlight++;
      unawaited(_serve(read));
    }
  }

  static Future<void> _serve(_Read read) async {
    try {
      read.done.complete(await read.spine.blob(read.hash));
    } catch (e, st) {
      read.done.completeError(e, st);
    } finally {
      _inFlight--;
      _start();
    }
  }

  /// How many reads this cache is holding that have not come back: the ones the store has
  /// accepted and the ones still waiting for a lane.
  ///
  /// It exists for the capture harness. `window.__deskReady` means the app has painted a frame —
  /// the library is loaded, the spine is open, one frame is on the glass — and it says nothing
  /// about whether the region on screen has the pictures it asked for. `tools/capture/scene.js`
  /// waited on that flag and a fixed settle, so `04_moments` was photographed between two and
  /// five seconds after ready against a grid that took longer than that to fill, and the still
  /// that came out was indistinguishable from a grid that never fills. Three critics read it as
  /// the second. A shot that waits on this instead is a shot of what the screen becomes, and a
  /// scene that outruns the budget is recorded as slow rather than photographed blank.
  ///
  /// Process-wide rather than per-region, which is stricter and simpler: a region that is
  /// offstage inside the `IndexedStack` is never laid out, so it issues no reads of its own
  /// (measured in `scroll_cost_test.dart`), and what is outstanding is what the screen is
  /// waiting for.
  static int get outstanding => _inFlight + _waiting.length;

  static void forget(String hash) => _futures.remove(hash);

  /// Empties the cache and the queue. For tests, which share one process: a cached future from an
  /// earlier test is an answer to a question this one did not ask.
  @visibleForTesting
  static void reset() {
    _futures.clear();
    _waiting.clear();
    _inFlight = 0;
  }
}

class _Read {
  _Read(this.spine, this.hash, this.urgent);
  final Spine spine;
  final String hash;
  bool urgent;
  final Completer<StoredBlob?> done = Completer<StoredBlob?>();
}

class BlobImage extends StatelessWidget {
  const BlobImage({
    super.key,
    required this.hash,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.urgent = false,
    this.full = false,
  });
  final String hash;
  final double? width;
  final double? height;
  final BoxFit fit;

  /// Whether this is the picture somebody is looking at, rather than one of the many a region has
  /// laid out in the background. Set on the viewer and nowhere else: if every caller is urgent,
  /// none is.
  final bool urgent;

  /// Whether the picture can be magnified past the box it is drawn in.
  ///
  /// Only the viewer's photograph can: it is inside an `InteractiveViewer` at `maxScale: 6`, so
  /// the pixels it is going to need are not the pixels it is currently showing. Everything else
  /// in the app is drawn at one size and decoding it larger buys nothing.
  final bool full;

  @override
  Widget build(BuildContext context) {
    final spine = AppScope.of(context).spine;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    // The width to decode at is the width it is drawn at, and a picture inside an `AspectRatio`
    // has always been told that during layout. It used to be taken from [width] alone, and no
    // call site in the app ever passed one: the gallery, the thread and the viewer all put a
    // `BlobImage` inside something that constrains it and gave it no explicit width, so the
    // branch below was dead for the life of the build and every photograph was decoded at its
    // own resolution. A print 140 logical px across was 1200 px of source: nine times the pixels
    // it can show in each direction, per tile, eighteen tiles to a screen, on the region whose
    // capture came back with no thumbnail in it.
    return LayoutBuilder(
      builder: (context, box) {
        final drawn = width ?? (box.maxWidth.isFinite ? box.maxWidth : null);
        return FutureBuilder<StoredBlob?>(
          future: BlobCache.get(spine, hash, urgent: urgent),
          builder: (context, snap) {
            final b = snap.data;
            if (b == null) {
              // Two different things, and they used to say the same sentence. A read that has not
              // come back yet is a picture on its way; a read that came back with nothing is a
              // picture this device does not have. Telling a reader which is not a nicety — it
              // told this build's own triage the wrong one, and three critics scored a capture as
              // a broken screen when it was a slow one.
              final arriving = snap.connectionState != ConnectionState.done;
              return SizedBox(
                width: width,
                height: height ?? 160,
                child: Center(
                  child: Text(arriving ? S.fetching : S.pictureNotHere,
                      style: const TextStyle(fontSize: 12)),
                ),
              );
            }
            return Image.memory(
              b.bytes,
              width: width,
              height: height,
              fit: fit,
              gaplessPlayback: true,
              cacheWidth: full || drawn == null ? null : (drawn * dpr).round(),
            );
          },
        );
      },
    );
  }
}

class VoiceNotePlayer extends StatefulWidget {
  const VoiceNotePlayer({super.key, required this.hash, required this.durationMs, required this.waveform});
  final String hash;
  final int durationMs;
  final List<double> waveform;

  @override
  State<VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<VoiceNotePlayer> {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((s) {
      if (!mounted) return;
      setState(() => _playing = s == PlayerState.playing);
    });
    _player.onPositionChanged.listen((d) {
      if (!mounted || widget.durationMs == 0) return;
      setState(() => _progress = (d.inMilliseconds / widget.durationMs).clamp(0, 1));
    });
    _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _playing = false;
        _progress = 0;
      });
    });
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
      return;
    }
    final spine = AppScope.of(context).spine;
    final b = await BlobCache.get(spine, widget.hash);
    if (b == null) return;
    final uri = await localUriFor(b.hash, b.bytes, b.mime);
    if (isWebPlatform) {
      await _player.play(UrlSource(uri.toString()));
    } else {
      await _player.play(DeviceFileSource(uri.toFilePath()));
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final secs = (widget.durationMs / 1000).round();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Drawn, not set: the last icon in the app was a Material play arrow, and a glyph out of
        // an icon font sitting on a torn sheet reads as a sticker stuck to it.
        Semantics(
          button: true,
          label: _playing ? S.pause : S.play,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 10, 6),
              child: _playing
                  ? Mark.hold(size: 20, colour: Pen.graphite)
                  : Mark.play(size: 20, colour: Pen.graphite),
            ),
          ),
        ),
        SizedBox(
          width: 160,
          height: 28,
          child: CustomPaint(painter: _WavePainter(widget.waveform, _progress, Theme.of(context).colorScheme.onSurface)),
        ),
        const SizedBox(width: 8),
        Text('${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.wave, this.progress, this.colour);
  final List<double> wave;
  final double progress;
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    if (wave.isEmpty) return;
    final n = wave.length;
    final w = size.width / n;
    final played = Paint()..color = colour;
    final rest = Paint()..color = colour.withValues(alpha: 0.35);
    for (var i = 0; i < n; i++) {
      final h = (wave[i].clamp(0.05, 1.0)) * size.height;
      final x = i * w;
      canvas.drawRect(Rect.fromLTWH(x + w * 0.2, (size.height - h) / 2, w * 0.6, h), i / n < progress ? played : rest);
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.progress != progress || old.wave != wave;
}

/// Bytes of a blob for the viewer (photo full-res, video).
Future<Uint8List?> blobBytes(BuildContext context, String hash) async =>
    (await BlobCache.get(AppScope.of(context).spine, hash))?.bytes;


/// A photograph or a video still, taped to the note at two corners.
class Print extends StatelessWidget {
  const Print({super.key, required this.item, required this.hash, required this.aspect, this.caption, this.durationMs});
  final ThreadItem item;
  final String hash;
  final double aspect;
  final String? caption;
  final int? durationMs;

  @override
  Widget build(BuildContext context) {
    final lib = MaterialLibrary.loaded ? MaterialLibrary.instance : null;
    final bits = lib?.bits ?? const [];
    final tape = bits.isEmpty ? null : bits[hashOf(item.id) % bits.length].id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => ViewerPage.open(context, item),
          child: Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(
                aspectRatio: aspect,
                child: BlobImage(hash: hash, fit: BoxFit.cover),
              ),
              if (tape != null)
                Positioned(
                  left: -10,
                  top: -8,
                  child: Transform.rotate(
                    angle: -0.5,
                    child: Image.asset(bitAsset(tape), width: 60,
                  frameBuilder: paintWhenItArrives, errorBuilder: PaperPiece.none),
                  ),
                ),
              if (durationMs != null)
                Positioned(
                  right: 8,
                  bottom: 6,
                  child: Stamped('${(durationMs! / 1000).round()}s', size: 11, colour: Pen.margin),
                ),
            ],
          ),
        ),
        if (caption != null && caption!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Written(caption!, by: item.author, size: 17),
          ),
      ],
    );
  }
}

/// The note being answered, as a torn strip pinned above the reply.
