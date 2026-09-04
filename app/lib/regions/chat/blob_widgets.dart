// Media from the blob store: images, voice notes, video posters.
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

/// Process-wide cache of decoded blob bytes so scrolling never re-reads the store.
class BlobCache {
  static final Map<String, Future<StoredBlob?>> _futures = {};

  static Future<StoredBlob?> get(Spine spine, String hash) => _futures.putIfAbsent(hash, () => spine.blob(hash));

  static void forget(String hash) => _futures.remove(hash);
}

class BlobImage extends StatelessWidget {
  const BlobImage({super.key, required this.hash, this.width, this.height, this.fit = BoxFit.cover});
  final String hash;
  final double? width;
  final double? height;
  final BoxFit fit;

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
            height: height ?? 160,
            child: const Center(child: Text(S.fetching, style: TextStyle(fontSize: 12))),
          );
        }
        return Image.memory(b.bytes, width: width, height: height, fit: fit, gaplessPlayback: true);
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
        IconButton(
          tooltip: _playing ? S.pause : S.play,
          icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
          onPressed: _toggle,
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
