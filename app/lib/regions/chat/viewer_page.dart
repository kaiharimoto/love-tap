// A photograph picked up off the desk.
//
// This was a black Material Scaffold with an AppBar — a lightbox, which is what every messenger
// does and which has nothing to do with the rest of this app. Here the desk stays under it and
// goes dark, the print comes up off the paper it was taped to, and what was written with it is on
// a slip underneath in the hand that wrote it. Pinch still zooms; a video still plays and loops.
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../material/hands.dart';
import '../../material/light.dart';
import '../../material/marks.dart';
import '../../material/palette.dart';
import '../../material/slip.dart';
import '../../media/local_uri.dart';
import '../../app.dart';
import '../../scope.dart';
import '../../spine/projections/thread.dart';
import 'blob_widgets.dart';

class ViewerPage extends StatefulWidget {
  const ViewerPage({super.key, required this.item});
  final ThreadItem item;

  static Future<void> open(BuildContext context, ThreadItem item) =>
      Navigator.of(context).push(PageRouteBuilder<void>(
        opaque: false,
        barrierColor: const Color(0xCC0E0A06),
        transitionDuration: const Duration(milliseconds: 200),
        // Material, because there is no Scaffold on this route and a Text with no Material over
        // it anywhere is drawn by Flutter in red under a double yellow underline — a diagnostic,
        // painted in release too. It put sixty-three thousand pure #FFFF00 pixels through the
        // search results and twelve thousand through the photograph's caption, two lines under
        // every line of writing, and it read as a design decision rather than as the error it is.
        // Transparency, so the desk is still what is under the page.
        pageBuilder: (_, _, _) => Material(
          type: MaterialType.transparency,
          child: ViewerPage(item: item),
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
      setState(() => _video = c);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  static dynamic _fileOf(Uri uri) => _FileShim.of(uri);

  @override
  void dispose() {
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
              onTap: () => Navigator.of(context).maybePop(),
              child: Padding(
                // clear of the tab strip: this sat on top of `chat` and `moments`
                padding: const EdgeInsets.only(bottom: 18 + kTabStrip),
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

// dart:io File without importing dart:io into a file the web build compiles.
class _FileShim {
  static dynamic of(Uri uri) => _fileFromUri(uri);
}

dynamic _fileFromUri(Uri uri) => throw UnsupportedError('replaced per platform');
