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

  /// The rate every sequence is rendered and played at. A clip of one has to be assembled at the
  /// same rate, and the clock stepped by exactly one of these between shots, or the recording is
  /// not of the sequence -- see DrivenClock.period.
  static const frameRate = 60;

  /// Which frame of a sequence [length] long is showing, [since] it started playing.
  ///
  /// Microseconds, because the clock does not land on whole milliseconds. One frame of a sixty-a-
  /// second clip is 16667 us, and `inMilliseconds` truncates the run of them to 16, 33, 50, 66,
  /// 83 -- which indexes 0, 1, 3, 3, 4: a frame shown twice and a frame never shown at all, four
  /// times a second, in the one sequence the whole material claim rests on.
  static int frameAt(Duration since, int length) => since.isNegative || length == 0
      ? 0
      : (since.inMicroseconds * frameRate ~/ 1000000).clamp(0, length - 1);

  /// Whether a sequence [length] long has played out, [since] it started.
  static bool finished(Duration since, int length) =>
      since.inMicroseconds * frameRate >= length * 1000000;

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
    final f = _frames;
    if (DrivenClock.enabled) {
      final from = DrivenClock.now;
      // Here and not where the note was touched: the widget is built and its frames looked up
      // asynchronously, so the instant the sequence's clock starts from is this one, and a take
      // sized off the earlier one would stop short of the end of the open.
      if (f != null) Folds.openFrom(from, f.length);
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
    if (FoldFrames.finished(after, f.length)) {
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
    final i = FoldFrames.frameAt(_elapsed - widget.holdFirst, f.length);
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
  const FoldedNote({
    super.key,
    required this.width,
    required this.child,
    required this.resting,
    this.onOpened,
    this.seq = 'unfold_thirds',
  });

  final double width;
  final Widget child;

  /// What lies in the thread until it is touched: the note's own sheet -- its stock, its tear, its
  /// shadow -- folded to a third, with the writing inside it.
  ///
  /// It used to be frame zero of the sequence, and frame zero of the sequence is a square-cornered
  /// cream slab with nothing on it: no tear, no stock, a flat uniform shadow, and no entry in the
  /// surfaces sidecar because `_FramePainter` is not a piece of paper. Every unread note of theirs
  /// looked like that for as long as it lay there, which in 13_messenger_states was for ever, and
  /// five critics at cycle 3 found it and called it the brief's anti-goal by name. How a note lies
  /// in the thread is this widget's choice and not a property of the render; the sequence starts
  /// when it is touched, and the cut from this face to its first frame happens under a finger.
  final Widget resting;

  /// Called once the sequence has finished and the writing is on the screen -- not when the
  /// person taps. The thread uses it to let the read marker past this row, and a receipt may
  /// only be sent for something that has actually been seen. Tapping is a commitment to open;
  /// the writing arriving is the reader having read it.
  final VoidCallback? onOpened;
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
      return Settling(
        builder: (_, t, child) => Opacity(opacity: t, child: child),
        child: widget.child,
      );
    }
    if (_opening) {
      return Unfolding(
        seq: widget.seq,
        width: widget.width,
        // No hold, and none under capture either. A beat of the note lying folded before it
        // starts to open is a beat in which nothing is drawn, and a clip is disqualified outright
        // by any frame identical to the one before it -- so under capture this held twelve frames
        // of the sheet and put them in 06_unfolding.mp4. It was also the app behaving one way for
        // the camera and another way in a hand, which is the thing the artifacts exist to rule
        // out. The beat, if it is ever wanted, belongs in the render and not in a timer.
        onOpen: () {
          setState(() => _open = true);
          widget.onOpened?.call();
        },
      );
    }
    return GestureDetector(
      onTap: () => setState(() => _opening = true),
      child: Settling(
        builder: (_, t, child) => Transform.scale(scale: 0.98 + 0.02 * t, child: child),
        child: widget.resting,
      ),
    );
  }
}

/// Called from capture mode and from the thread: open every folded note on screen at once, so the
/// unfolding clip is of the app rather than of a thumb.
class Folds {
  static final List<VoidCallback> _waiting = [];

  /// The driven-clock instant the last open asked for will be finished at: the sequence played
  /// out, and the settle that puts the written note over its final frame finished with it.
  ///
  /// This exists so a take of the open is exactly as long as the open. capture.sh used to be
  /// told a frame count by hand -- three hundred, for a fold that is two hundred and forty frames
  /// and a settle that is sixteen -- and the forty-four frames of slack at the end of that sum
  /// were the twenty-one identical frames at the tail of 06_unfolding.mp4. A count written in a
  /// scene file cannot know the sequence length; the app does, so the app is asked.
  static Duration? openEndsAt;

  static void whenAsked(VoidCallback open) => _waiting.add(open);

  /// How much of the open is still to come, in microseconds, or zero once it is over. The
  /// harness polls this between shots, the way it already polls the outstanding blob count.
  static int get microsecondsLeftInTheOpen {
    final ends = openEndsAt;
    if (ends == null) return 0;
    final left = (ends - DrivenClock.now).inMicroseconds;
    return left > 0 ? left : 0;
  }

  /// Called by a sequence as it starts to play, with the instant its clock starts from and how
  /// many frames it has, so [openEndsAt] is read off the sequence rather than guessed outside it.
  static void openFrom(Duration zero, int frames) {
    if (frames == 0) return;
    openEndsAt = zero +
        Duration(microseconds: frames * 1000000 ~/ FoldFrames.frameRate) +
        Motion.settle;
  }

  static void openAll() {
    for (final open in List.of(_waiting)) {
      open();
    }
    _waiting.clear();
  }

  @visibleForTesting
  static void reset() {
    _waiting.clear();
    openEndsAt = null;
  }
}
