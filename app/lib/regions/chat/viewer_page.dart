// The media viewer: full-resolution photo with pinch zoom, video playback.
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../media/local_uri.dart';
import '../../scope.dart';
import '../../spine/projections/thread.dart';
import 'blob_widgets.dart';

class ViewerPage extends StatefulWidget {
  const ViewerPage({super.key, required this.item});
  final ThreadItem item;

  static Future<void> open(BuildContext context, ThreadItem item) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ViewerPage(item: item), fullscreenDialog: true));

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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: Text(widget.item.text ?? '')),
      body: GestureDetector(
        onTap: () {
          final v = _video;
          if (v != null) v.value.isPlaying ? v.pause() : v.play();
        },
        child: body,
      ),
    );
  }
}

// dart:io File without importing dart:io into a file the web build compiles.
class _FileShim {
  static dynamic of(Uri uri) => _fileFromUri(uri);
}

dynamic _fileFromUri(Uri uri) => throw UnsupportedError('replaced per platform');
