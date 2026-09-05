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

/// Process-wide cache of decoded blob bytes so scrolling never re-reads the store.
///
/// At most a few reads are in flight at once. The store answered every request it was given, in
/// the order it was given them, and the gallery gave it a hundred and twenty-nine at once, so
/// the pictures on screen queued behind the pictures a screen and a half below. Now the tiles
/// that ask first are the tiles that are built first, which are the ones being looked at.
class BlobCache {
  static final Map<String, Future<StoredBlob?>> _futures = {};
  static final Set<String> _resolved = {};
  static int _inFlight = 0;
  static final List<Completer<void>> _waiting = [];
  static const width = 6;

  static Future<StoredBlob?> get(Spine spine, String hash) => _futures.putIfAbsent(hash, () async {
        final b = await _limited(() => spine.blob(hash));
        // arrived means arrived: a hash the store does not hold is answered, not delivered
        if (b != null) _resolved.add(hash);
        return b;
      });

  static Future<T> _limited<T>(Future<T> Function() read) async {
    if (_inFlight >= width) {
      final turn = Completer<void>();
      _waiting.add(turn);
      await turn.future; // the slot is handed over, not counted twice
    } else {
      _inFlight++;
    }
    try {
      return await read();
    } finally {
      if (_waiting.isNotEmpty) {
        _waiting.removeAt(0).complete();
      } else {
        _inFlight--;
      }
    }
  }

  static void forget(String hash) {
    _futures.remove(hash);
    _resolved.remove(hash);
  }

  /// For the capture report: how many pictures were asked for and how many have come.
  static Map<String, int> stats() => {
        'asked': _futures.length,
        'arrived': _resolved.length,
        'reading': _inFlight,
        'waiting': _waiting.length,
      };
}

class BlobImage extends StatelessWidget {
  const BlobImage({
    super.key,
    required this.hash,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    this.quiet = false,
  });
  final String hash;
  final double? width;
  final double? height;
  final BoxFit fit;

  /// Decode the picture at about the size it is shown, not the size it was taken: a thumbnail
  /// three hundred pixels wide has no use for a twelve-megapixel bitmap in memory.
  final int? cacheWidth;

  /// A picture that has not come yet is a blank print, not a sentence about fetching. In a
  /// pile of prints the sentence was the only thing on five tiles at once, and it read as the
  /// app announcing it was slow.
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    final spine = AppScope.of(context).spine;
    return FutureBuilder<StoredBlob?>(
      future: BlobCache.get(spine, hash),
      builder: (context, snap) {
        final b = snap.data;
        if (b == null) {
          return SizedBox(
            width: width,
            height: height ?? (quiet ? null : 160),
            child: quiet
                ? const ColoredBox(color: Color(0x14000000))
                : const Center(child: Text(S.fetching, style: TextStyle(fontSize: 12))),
          );
        }
        return Image.memory(
          b.bytes,
          width: width,
          height: height,
          fit: fit,
          cacheWidth: cacheWidth,
          gaplessPlayback: true,
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
                    child: Image.asset(bitAsset(tape), width: 60, errorBuilder: PaperPiece.none),
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
