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

/// The frames of one sequence, decoded a window at a time.
///
/// A hundred and fifty frames at 460 by 405 is a hundred and twelve megabytes of decoded texture,
/// which is more than WebKit will hold for one animation on a phone. So the sequence is never all
/// in memory: a window of frames ahead of the playhead is decoded, and frames well behind it are
/// dropped. The window is sized so that decoding keeps ahead of sixty frames a second on the
/// slowest thing this has to run on, and so that the whole of it stays inside about a quarter of
/// the budget one sequence is allowed.
class FoldFrames {
  FoldFrames._(this.seq, this.length);

  final String seq;
  final int length;

  /// How many frames are held at once, and how far ahead decoding runs.
  static const window = 36;
  static const _ahead = 24;

  final Map<int, ui.Image> _held = {};
  final Set<int> _loading = {};
  int _playhead = 0;

  static String? _current;
  static FoldFrames? _instance;

  /// What the capture report says about the sequence: enough to tell a clip that did not play
  /// from a clip that played over frames that never decoded.
  static Map<String, dynamic> get state {
    final f = _instance;
    if (f == null) return {'sequence': null};
    return {
      'sequence': f.seq,
      'length': f.length,
      'decoded': f._held.length,
      'decoding': f._loading.length,
      'playhead': f._playhead,
      'held_from': f._held.isEmpty ? null : f._held.keys.reduce((a, b) => a < b ? a : b),
      'held_to': f._held.isEmpty ? null : f._held.keys.reduce((a, b) => a > b ? a : b),
    };
  }

  static Future<FoldFrames> load(String seq) async {
    if (_current == seq && _instance != null) return _instance!;
    _instance?.dispose();
    final count = MaterialLibrary.loaded ? (MaterialLibrary.instance.folds[seq] ?? 0) : 0;
    final frames = FoldFrames._(seq, count);
    _current = seq;
    _instance = frames;
    await frames._fill(0);
    return frames;
  }

  /// The frame at [i] if it is decoded, and otherwise the last one before it that is.
  ///
  /// Asking for exactly [i] and taking nothing else is what made the unfolding clip a still: the
  /// playhead is driven by the clock and the decoder is driven by the machine, the clock wins,
  /// and every single frame of a four-second grab asked for a frame that was one ahead of what
  /// had been decoded — so the note sat on frame zero for the whole take and then jumped open.
  /// A note that opens a little behind is a note opening. A note that holds still is not.
  ui.Image? at(int i) {
    if (i != _playhead) {
      _playhead = i;
      unawaited(_fill(i));
    }
    final exact = _held[i];
    if (exact != null) return exact;
    var best = -1;
    for (final k in _held.keys) {
      if (k <= i && k > best) best = k;
    }
    return best < 0 ? null : _held[best];
  }

  Future<void> _fill(int from) async {
    // decoded together rather than one after another: a chain of twenty-four awaits is twenty-four
    // round trips through the event loop before the first frame after the playhead is ready
    final want = <int>[];
    for (var i = from; i < from + _ahead && i < length; i++) {
      if (_held.containsKey(i) || _loading.contains(i)) continue;
      _loading.add(i);
      want.add(i);
    }
    await Future.wait(want.map(_decode));
    // let go of everything well behind the playhead
    final drop = _held.keys.where((i) => i < from - (window - _ahead)).toList();
    for (final i in drop) {
      _held.remove(i)?.dispose();
    }
  }

  Future<void> _decode(int i) async {
    try {
      final data = await rootBundle.load(foldFrameAsset(seq, i));
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      _held[i] = (await codec.getNextFrame()).image;
    } catch (_) {
      // a sequence that stops short plays as far as it goes rather than throwing under a note
    } finally {
      _loading.remove(i);
    }
  }

  void dispose() {
    for (final image in _held.values) {
      image.dispose();
    }
    _held.clear();
    if (identical(_instance, this)) {
      _instance = null;
      _current = null;
    }
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

  /// The last frame actually drawn: if decoding falls a frame behind, the note holds rather than
  /// blinking out, which is what a dropped frame would look like.
  ui.Image? _lastDrawn;

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

  /// How tall this is going to be, before any of it has decoded.
  ///
  /// A note whose height came from its first decoded frame was zero high until the decoder caught
  /// up, and then it was not: everything under it moved, and a thread scrolled to its end scrolled
  /// past the very note that was about to open. The shape of a frame is in the library, written
  /// there by tools/pack_assets.py off the frame itself.
  double get _height {
    final size = MaterialLibrary.loaded
        ? MaterialLibrary.instance.foldSize[widget.seq]
        : null;
    if (size == null || size.width == 0) return widget.width;
    return widget.width * size.height / size.width;
  }

  @override
  Widget build(BuildContext context) {
    final f = _frames;
    if (f == null || f.length == 0) return SizedBox(width: widget.width, height: _height);
    final after = _elapsed - widget.holdFirst;
    final i = after.isNegative ? 0 : (after.inMilliseconds * _frameRate ~/ 1000).clamp(0, f.length - 1);
    final image = f.at(i) ?? _lastDrawn;
    if (image == null) return SizedBox(width: widget.width, height: _height);
    _lastDrawn = image;
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
    if (!FoldedNote.available) return widget.child;
    // The three states are three different heights — a folded sheet, the sequence playing, the
    // note with the writing on it — and swapping between them moved everything underneath by a
    // hundred points in one frame. The note keeps its place in the thread while it changes shape.
    return AnimatedSize(
      duration: Motion.settle,
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: _face(context),
    );
  }

  Widget _face(BuildContext context) {
    if (_open) {
      // The last frame of the sequence is the sheet lying flat, and the note is the same sheet
      // with the writing on it — but they are not the same height, and cutting from one to the
      // other is a twitch at the end of every note anyone opens. In a clip it is a jump in the
      // light, which is how a recording stitched out of two takes gives itself away. So the note
      // arrives over the frame it is replacing rather than instead of it.
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: Motion.settle,
        curve: Curves.easeOut,
        builder: (_, t, child) => Opacity(opacity: t.clamp(0.0, 1.0), child: child),
        child: widget.child,
      );
    }
    if (_opening) {
      return Unfolding(
        seq: widget.seq,
        width: widget.width,
        // long enough for a reader to see the note lying folded, short enough that the clip
        // is the note opening rather than the note sitting there
        holdFirst: Flags.capture ? const Duration(milliseconds: 200) : Duration.zero,
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
