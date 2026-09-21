// A photograph picked up off the desk.
//
// This was a black Material Scaffold with an AppBar — a lightbox, which is what every messenger
// does and which has nothing to do with the rest of this app. Here the desk stays under it and
// goes dark, the print comes up off the paper it was taped to, and what was written with it is on
// a slip underneath in the hand that wrote it. Pinch still zooms; a video still plays and loops.
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../material/assignment.dart';
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
import '../../material/desk.dart';

class ViewerPage extends StatefulWidget {
  const ViewerPage({super.key, required this.item});
  final ThreadItem item;

  static Future<void> open(BuildContext context, ThreadItem item) =>
      Navigator.of(context).push(PageRouteBuilder<void>(
        opaque: false,
        // The room goes quiet so you can look at this; it does not black out. docs/COLOR.md
        // section 8: what darkens in a viewer is the desk behind the photograph, from
        // `ground_day` to `ground_dusk` and no further, and never the sheet, the chrome or the
        // ink. This was 0xCC, which took the desk to OKLab L 0.198 -- well below dusk's 0.265 --
        // and 14_media_viewer.png measured body text at 1.43:1 underneath it. At 0x80 the desk
        // behind lands at L 0.268 against dusk's 0.265, which is the whole of what was wanted.
        // DIRECTION.md has forbidden this in four words since the beginning: never a dim overlay.
        // Lightening this to 0x80 put the desk at the right lightness and immediately showed
        // what the darkness had been hiding: the route is not opaque, so what sits behind a
        // translucent barrier is the live chat screen. The capture came back with the note's
        // text showing through itself twice and `put it back` sitting on top of the composer.
        // So the viewer stops tinting the room and brings its own -- same desk, same rig, at the
        // dusk condition, which is what DIRECTION.md means by night. The barrier does nothing
        // now: Desk is opaque and nothing shows through it.
        barrierColor: const Color(0x00000000),
        transitionDuration: const Duration(milliseconds: 200),
        // Material, because there is no Scaffold on this route and a Text with no Material over
        // it anywhere is drawn by Flutter in red under a double yellow underline — a diagnostic,
        // painted in release too. It put sixty-three thousand pure #FFFF00 pixels through the
        // search results and twelve thousand through the photograph's caption, two lines under
        // every line of writing, and it read as a design decision rather than as the error it is.
        // Transparency, so the desk is still what is under the page.
        pageBuilder: (_, _, _) => Material(
          type: MaterialType.transparency,
          child: Light(
            condition: LightCondition.dusk,
            child: Desk(child: ViewerPage(item: item)),
          ),
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
      // urgent: this is the thing on the screen. The five regions live in an IndexedStack, so
      // the Moments gallery is laid out and reading its own tiles while this page opens, and
      // without a lane of its own this read waits behind all of them. See BlobCache.
      final b = await BlobCache.get(spine, widget.item.event.payload['blob'] as String, urgent: true);
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
        // `full`, because this is the one picture in the app that magnifies: the
        // `InteractiveViewer` above goes to six times, so the pixels it will need are not
        // the pixels it is showing. Every other BlobImage decodes at the width it is drawn.
        child: Center(
            child: BlobImage(
                hash: p['blob'] as String, fit: BoxFit.contain, urgent: true, full: true)),
      );
    } else if (widget.item.type == 'video') {
      final v = _video;
      body = v == null
          ? Center(
              child: _error == null
                  ? BlobImage(hash: p['poster_blob'] as String, fit: BoxFit.contain, urgent: true)
                  : Text(_error!))
          : Center(child: AspectRatio(aspectRatio: v.value.aspectRatio, child: VideoPlayer(v)));
    } else {
      body = const SizedBox.shrink();
    }
    final dusk = Light.of(context) == LightCondition.dusk;
    final tilt = ((hashOf(widget.item.id) % 21) - 10) / 420.0;
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
                // Section 8: the thing that darkens in a viewer is the desk behind the
                // photograph. The way out is chrome, so it stays lit, and it is a word, so it is
                // on stock rather than on whatever the photograph happens to be.
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Strip(
                      id: 'put-it-back',
                      row: 4,
                      padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Mark.turnback(size: 20, colour: Pen.margin, seed: 7),
                          const SizedBox(width: 8),
                          const Stamped('put it back', size: 10),
                        ],
                      ),
                    ),
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
