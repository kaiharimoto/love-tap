// A photograph picked up off the desk.
//
// This was a black Material Scaffold with an AppBar — a lightbox, which is what every messenger
// does and which has nothing to do with the rest of this app. Here the desk stays under it and
// goes dark, the print comes up off the paper it was taped to, and what was written with it is on
// a slip underneath in the hand that wrote it. Pinch still zooms; a video still plays and loops.
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../capture/bus.dart';
import '../../material/desk.dart';
import '../../material/hands.dart';
import '../../material/light.dart';
import '../../material/marks.dart';
import '../../material/palette.dart';
import '../../material/slip.dart';
import '../../media/local_uri.dart';
import '../../scope.dart';
import '../../spine/projections/thread.dart';
import '../../voice/strings.dart';
import 'blob_widgets.dart';

class ViewerPage extends StatefulWidget {
  const ViewerPage({super.key, required this.item});
  final ThreadItem item;

  /// A print held up to look at covers the desk: its own desk under it, nothing of the thread
  /// showing through. It was a translucent page over the thread, and what came through the scrim
  /// was the composer, the tabs and the same caption a second time under the print.
  static Future<void> open(BuildContext context, ThreadItem item) =>
      Navigator.of(context).push(PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 200),
        // Material, because there is no Scaffold on this route and a Text with no Material over
        // it anywhere is drawn by Flutter in red under a double yellow underline — a diagnostic,
        // painted in release too. It put sixty-three thousand pure #FFFF00 pixels through the
        // search results and twelve thousand through the photograph's caption, two lines under
        // every line of writing, and it read as a design decision rather than as the error it is.
        // Transparency, so the desk is still what is under the page.
        pageBuilder: (_, _, _) => Material(
          type: MaterialType.transparency,
          child: Desk(child: ViewerPage(item: item)),
        ),
      ));

  @override
  State<ViewerPage> createState() => _ViewerPageState();
}

class _ViewerPageState extends State<ViewerPage> {
  VideoPlayerController? _video;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Same reason as the search page: the viewer is a route over Chat's slot, the hooks dispatch
    // on the region index, and Chat's report reads a list the viewer has covered. The thing on
    // the glass says what it is showing.
    CaptureBus.viewerReport = () => {
          'item': widget.item.event.id,
          'kind': widget.item.type,
          'caption': widget.item.event.payload['caption'],
          'blob': widget.item.event.payload['blob'],
          'video': _video == null
              ? null
              : {
                  'initialised': _video!.value.isInitialized,
                  'playing': _video!.value.isPlaying,
                  'position_ms': _video!.value.position.inMilliseconds,
                  'duration_ms': _video!.value.duration.inMilliseconds,
                },
          if (_error != null) 'error': _error,
        };
    if (widget.item.type == 'video') _loadVideo();
  }

  Future<void> _loadVideo() async {
    try {
      final spine = AppScope.of(context).spine;
      final b = await BlobCache.get(spine, widget.item.event.payload['blob'] as String);
      if (b == null) return;
      final uri = await localUriFor(b.hash, b.bytes, b.mime);
      final c = isWebPlatform ? VideoPlayerController.networkUrl(uri) : VideoPlayerController.file(_fileOf(uri));
      await c.initialize();
      await c.setLooping(true);
      await c.play();
      if (!mounted) return;
      // the strip under the print says where the film is, so it has to be told when that moves
      c.addListener(_moved);
      setState(() => _video = c);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  static dynamic _fileOf(Uri uri) => _FileShim.of(uri);

  /// The playhead moved: redraw the strip, and no oftener than a tenth of a second, because a
  /// video player notifies on every frame it decodes and the strip is a pencil line.
  void _moved() {
    final v = _video;
    if (!mounted || v == null) return;
    final at = v.value.position.inMilliseconds ~/ 100;
    if (at == _shownAt && v.value.isPlaying == _shownPlaying) return;
    setState(() {
      _shownAt = at;
      _shownPlaying = v.value.isPlaying;
    });
  }

  int _shownAt = -1;
  bool _shownPlaying = false;

  @override
  void dispose() {
    CaptureBus.viewerReport = null;
    _video?.removeListener(_moved);
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.item.event.payload;
    Widget body;
    if (widget.item.type == 'photo') {
      body = InteractiveViewer(
        maxScale: 6,
        child: Center(child: BlobImage(hash: p['blob'] as String, fit: BoxFit.contain)),
      );
    } else if (widget.item.type == 'video') {
      final v = _video;
      body = v == null
          ? Center(child: _error == null ? BlobImage(hash: p['poster_blob'] as String, fit: BoxFit.contain) : Text(_error!))
          : Center(child: AspectRatio(aspectRatio: v.value.aspectRatio, child: VideoPlayer(v)));
    } else {
      body = const SizedBox.shrink();
    }
    final dusk = Light.of(context) == LightCondition.dusk;
    final tilt = ((widget.item.id.hashCode % 21) - 10) / 420.0;
    return GestureDetector(
      onTap: () {
        final v = _video;
        if (v != null) {
          v.value.isPlaying ? v.pause() : v.play();
        } else {
          Navigator.of(context).maybePop();
        }
      },
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            // the print itself, lifted: a real drop under it because it is being held up off
            // the desk rather than lying on it
            Flexible(
              flex: 12,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Transform.rotate(
                  angle: tilt,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Shadow.warm.withValues(alpha: dusk ? 0.68 : 0.55),
                          blurRadius: 34,
                          spreadRadius: 2,
                          offset: const Offset(9, 16),
                        ),
                      ],
                    ),
                    child: body,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            // What a film says about itself. A critic stepping this frame found a video playing —
            // the app's own record said kind video, initialised, playing, at 1530 ms of 2500 —
            // with nothing on the glass saying so: no mark to press, no length, no playhead, and
            // nothing to tell it from a photograph. A film in a drawer of prints is the one that
            // has a strip of frames down its edge.
            if (widget.item.type == 'video')
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 26),
                child: _FilmStrip(
                  video: _video,
                  fallbackMs: (widget.item.event.payload['duration_ms'] as num?)?.toInt() ?? 0,
                  onTap: () {
                    final v = _video;
                    if (v == null) return;
                    v.value.isPlaying ? v.pause() : v.play();
                  },
                  onSeek: (fraction) {
                    final v = _video;
                    if (v == null || !v.value.isInitialized) return;
                    v.seekTo(v.value.duration * fraction.clamp(0.0, 1.0));
                  },
                ),
              ),
            if (widget.item.type == 'video') const SizedBox(height: 12),
            if ((widget.item.text ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 26),
                child: Slip(
                  id: 'viewer_${widget.item.id}',
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: Written(widget.item.text!, by: widget.item.author, size: 18),
                ),
              ),
            const Spacer(),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).maybePop(),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 26),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Mark.turnback(size: 20, colour: Pen.onWood, seed: 7),
                    const SizedBox(width: 8),
                    Stamped('put it back', size: 10, colour: Pen.onWood),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The strip under a film: the mark you press, where the playhead is, and how long it runs.
///
/// Drawn, not set: a pencil rule with the part that has played inked in, the same play and hold
/// marks the voice note carries, and the times in the margin hand. On its own slip, because a
/// thing you can press is a thing that sits on something.
class _FilmStrip extends StatelessWidget {
  const _FilmStrip({required this.video, required this.fallbackMs, required this.onTap, required this.onSeek});
  final VideoPlayerController? video;
  final int fallbackMs;
  final VoidCallback onTap;
  final void Function(double fraction) onSeek;

  static String _clock(int ms) {
    final s = (ms / 1000).round();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final v = video?.value;
    final ready = v != null && v.isInitialized && v.duration.inMilliseconds > 0;
    final total = ready ? v.duration.inMilliseconds : fallbackMs;
    final at = ready ? v.position.inMilliseconds : 0;
    final progress = total == 0 ? 0.0 : (at / total).clamp(0.0, 1.0);
    return Slip(
      id: 'viewer.film',
      row: 3,
      stock: 'index',
      padding: const EdgeInsets.fromLTRB(12, 8, 14, 9),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: ready && v.isPlaying ? S.pause : S.play,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(2, 2, 10, 2),
                child: ready && v.isPlaying
                    ? Mark.hold(size: 19, colour: Pen.graphite)
                    : Mark.play(size: 19, colour: Pen.graphite),
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => onSeek(d.localPosition.dx / box.maxWidth),
                onHorizontalDragUpdate: (d) => onSeek(d.localPosition.dx / box.maxWidth),
                child: SizedBox(
                  height: 20,
                  child: CustomPaint(painter: _Playhead(progress)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text('${_clock(at)} / ${_clock(total)}', style: Hands.margin(size: 12)),
        ],
      ),
    );
  }
}

class _Playhead extends CustomPainter {
  _Playhead(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final rest = Paint()
      ..color = Pen.graphite.withValues(alpha: 0.30)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final done = Paint()
      ..color = Pen.graphite
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), rest);
    final x = size.width * progress;
    if (x > 0) canvas.drawLine(Offset(0, y), Offset(x, y), done);
    // where it is now: a pencil tick standing on the rule rather than a dot on a track
    canvas.drawLine(Offset(x, y - 6), Offset(x, y + 6), done);
  }

  @override
  bool shouldRepaint(_Playhead old) => old.progress != progress;
}

// dart:io File without importing dart:io into a file the web build compiles.
class _FileShim {
  static dynamic of(Uri uri) => _fileFromUri(uri);
}

dynamic _fileFromUri(Uri uri) => throw UnsupportedError('replaced per platform');
