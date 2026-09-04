// A note opening: the rendered fold sequence, played frame by frame.
//
// Nothing here transforms a flat image. Every frame is its own Cycles render of a sheet creased
// along real hinge lines under the one light rig, with the contact shadow in the same frame, so
// the light breaks across the crease as the flap turns and the shadow moves with the paper. The
// widget's whole job is to hold the frames in memory before the motion starts and then show them
// in order, because a fold that stutters while it decodes is worse than no fold at all.
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';

import '../capture/hooks.dart';
import '../flags.dart';
import 'library.dart';
import 'motion.dart';

/// The frames of one sequence, decoded once and shared.
///
/// A whole sequence at display size is a few tens of megabytes decoded, which is inside WebKit's
/// texture budget for one sequence at a time but not for four, so only the sequence being played
/// is held and the previous one is dropped when a new one is asked for.
class FoldFrames {
  FoldFrames._(this.seq, this.frames);
  final String seq;
  final List<ui.Image> frames;

  int get length => frames.length;

  static String? _held;
  static Future<FoldFrames>? _pending;

  static Future<FoldFrames> load(String seq) {
    if (_held == seq && _pending != null) return _pending!;
    final previous = _pending;
    _held = seq;
    _pending = _decode(seq);
    // let the old sequence go as soon as the new one is in hand
    previous?.then((old) {
      if (old.seq != seq) {
        for (final image in old.frames) {
          image.dispose();
        }
      }
    });
    return _pending!;
  }

  static Future<FoldFrames> _decode(String seq) async {
    final count = MaterialLibrary.loaded ? (MaterialLibrary.instance.folds[seq] ?? 0) : 0;
    final images = <ui.Image>[];
    for (var i = 0; i < count; i++) {
      try {
        final data = await rootBundle.load(foldFrameAsset(seq, i));
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        images.add((await codec.getNextFrame()).image);
      } catch (_) {
        break; // a short sequence plays as far as it goes rather than throwing under a note
      }
    }
    return FoldFrames._(seq, images);
  }
}

/// Plays a fold sequence once and then calls [onOpen].
///
/// In capture mode the frame is chosen by the driven clock rather than by a ticker, so a clip is
/// a recording of the app at known times rather than whatever the browser managed.
class Unfolding extends StatefulWidget {
  const Unfolding({
    super.key,
    required this.seq,
    required this.width,
    this.autoplay = true,
    this.onOpen,
    this.holdFirst = Duration.zero,
  });

  final String seq;
  final double width;
  final bool autoplay;
  final VoidCallback? onOpen;

  /// How long the note lies there folded before it starts to open.
  final Duration holdFirst;

  @override
  State<Unfolding> createState() => _UnfoldingState();
}

class _UnfoldingState extends State<Unfolding> with SingleTickerProviderStateMixin {
  FoldFrames? _frames;
  Ticker? _ticker;
  StreamSubscription<Duration>? _driven;
  Duration _elapsed = Duration.zero;
  bool _done = false;

  static const _frameRate = 60;

  @override
  void initState() {
    super.initState();
    FoldFrames.load(widget.seq).then((f) {
      if (!mounted) return;
      setState(() => _frames = f);
      if (widget.autoplay) _start();
    });
  }

  void _start() {
    if (DrivenClock.enabled) {
      final from = DrivenClock.now;
      _driven = DrivenClock.ticks.listen((now) => _advance(now - from));
      return;
    }
    _ticker = createTicker(_advance)..start();
  }

  void _advance(Duration elapsed) {
    if (!mounted || _done) return;
    final f = _frames;
    if (f == null || f.length == 0) return;
    setState(() => _elapsed = elapsed);
    final after = elapsed - widget.holdFirst;
    if (after.inMilliseconds >= f.length * 1000 / _frameRate) {
      _done = true;
      _ticker?.stop();
      _driven?.cancel();
      widget.onOpen?.call();
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _driven?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = _frames;
    if (f == null || f.length == 0) return SizedBox(width: widget.width);
    final after = _elapsed - widget.holdFirst;
    final i = after.isNegative ? 0 : (after.inMilliseconds * _frameRate ~/ 1000).clamp(0, f.length - 1);
    final image = f.frames[i];
    return SizedBox(
      width: widget.width,
      height: widget.width * image.height / image.width,
      child: CustomPaint(painter: _FramePainter(image)),
    );
  }
}

class _FramePainter extends CustomPainter {
  _FramePainter(this.image);
  final ui.Image image;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_FramePainter old) => !identical(old.image, image);
}

/// A note that arrived and has not been opened yet: it lies folded until it is touched.
///
/// This is the only place a fold sequence appears in the thread, and it is why the sequences exist:
/// their notes arrive folded because that is what a note passed across a table is.
class FoldedNote extends StatefulWidget {
  const FoldedNote({super.key, required this.width, required this.child, this.seq = 'unfold_thirds'});

  final double width;
  final Widget child;
  final String seq;

  /// Whether a fold sequence is on disk at all. Without one the note simply lies flat, which is
  /// honest: there is no substitute drawn in code for a render that has not been made.
  static bool get available =>
      MaterialLibrary.loaded && (MaterialLibrary.instance.folds[_defaultSeq] ?? 0) >= 60;
  static const _defaultSeq = 'unfold_thirds';

  @override
  State<FoldedNote> createState() => _FoldedNoteState();
}

class _FoldedNoteState extends State<FoldedNote> {
  bool _opening = false;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    Folds.whenAsked(_open2);
  }

  void _open2() {
    if (mounted && !_opening) setState(() => _opening = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_open || !FoldedNote.available) return widget.child;
    if (_opening) {
      return Unfolding(
        seq: widget.seq,
        width: widget.width,
        holdFirst: Flags.capture ? const Duration(milliseconds: 600) : Duration.zero,
        onOpen: () => setState(() => _open = true),
      );
    }
    return GestureDetector(
      onTap: () => setState(() => _opening = true),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.98, end: 1.0),
        duration: Motion.settle,
        builder: (_, t, child) => Transform.scale(scale: t, child: child),
        child: Unfolding(seq: widget.seq, width: widget.width, autoplay: false),
      ),
    );
  }
}

/// Called from capture mode and from the thread: open every folded note on screen at once, so the
/// unfolding clip is of the app rather than of a thumb.
class Folds {
  static final List<VoidCallback> _waiting = [];

  static void whenAsked(VoidCallback open) => _waiting.add(open);

  static void openAll() {
    for (final open in List.of(_waiting)) {
      open();
    }
    _waiting.clear();
  }

  @visibleForTesting
  static void reset() => _waiting.clear();
}
