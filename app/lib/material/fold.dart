// A note opening: the rendered fold sequence, played frame by frame.
//
// Nothing here transforms a flat image. Every frame is its own Cycles render of a sheet creased
// along real hinge lines under the one light rig, with the contact shadow in the same frame, so
// the light breaks across the crease as the flap turns and the shadow moves with the paper. The
// widget's whole job is to hold the frames in memory before the motion starts and then show them
// in order, because a fold that stutters while it decodes is worse than no fold at all.
//
// A note that arrived folded is a letter, and it stays one. It used to turn into something else
// at the end: the sequence played to its last frame, that frame was taken down, and the torn note
// the event would otherwise have been faded up in its place — from nothing, on the wall clock, in
// the gap between two screenshots. The clip ended on a blank rectangle and the frame checker
// called the swap a jump in the light. Now the sheet that opens is the sheet the writing is on:
// the ink comes up on the creased paper as it settles flat, and the row keeps that paper for as
// long as it is on screen.
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

  /// The last frame, decoded on demand: what a note that was opened earlier lies open as.
  Future<ui.Image?> last() async {
    if (length == 0) return null;
    final i = length - 1;
    if (!_held.containsKey(i)) await _decode(i);
    return _held[i];
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
    // let go of everything well behind the playhead — except the last frame, which every opened
    // letter on the screen is lying flat as
    final drop = _held.keys.where((i) => i < from - (window - _ahead) && i != length - 1).toList();
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

/// What lies on the sheet: drawn over the frame, given how far open the sheet is (0 folded, 1
/// flat) and the size the frame is being drawn at.
typedef SheetOverlay = Widget Function(BuildContext context, double progress, Size sheet);

/// Plays a fold sequence once and then calls [onOpen].
///
/// In capture mode the frame is chosen by the driven clock rather than by a ticker, so a clip is
/// a recording of the app at known times rather than whatever the browser managed.
///
/// One of these carries a letter through its whole life: lying folded ([autoplay] false), opening
/// (autoplay turned on later, see [didUpdateWidget]), and lying open, which is the last frame held
/// with [overlay] drawn on it. Nothing is swapped out on the way, so nothing jumps.
class Unfolding extends StatefulWidget {
  const Unfolding({
    super.key,
    required this.seq,
    required this.width,
    this.autoplay = true,
    this.onOpen,
    this.holdFirst = Duration.zero,
    this.startOpen = false,
    this.overlay,
  });

  final String seq;
  final double width;
  final bool autoplay;
  final VoidCallback? onOpen;

  /// How long the note lies there folded before it starts to open.
  final Duration holdFirst;

  /// Begin on the last frame, fully open: a letter that was opened earlier and is drawn again.
  final bool startOpen;

  /// What lies on the sheet, drawn over the frame.
  final SheetOverlay? overlay;

  @override
  State<Unfolding> createState() => _UnfoldingState();
}

class _UnfoldingState extends State<Unfolding> with SingleTickerProviderStateMixin {
  FoldFrames? _frames;
  Ticker? _ticker;
  StreamSubscription<Duration>? _driven;
  Duration _elapsed = Duration.zero;
  bool _started = false;
  bool _done = false;

  /// The last frame actually drawn: if decoding falls a frame behind, the note holds rather than
  /// blinking out, which is what a dropped frame would look like.
  ui.Image? _lastDrawn;

  static const _frameRate = 60;

  @override
  void initState() {
    super.initState();
    _done = widget.startOpen;
    FoldFrames.load(widget.seq).then((f) async {
      if (!mounted) return;
      if (widget.startOpen) {
        // straight to the sheet lying flat, with nothing to play
        _lastDrawn = await f.last();
        if (!mounted) return;
      }
      setState(() => _frames = f);
      if (widget.autoplay && !widget.startOpen) _start();
    });
  }

  @override
  void didUpdateWidget(Unfolding old) {
    super.didUpdateWidget(old);
    // the same widget, asked to open: the folded sheet starts to turn without being replaced
    if (widget.autoplay && !old.autoplay && !_started && !_done && _frames != null) _start();
  }

  void _start() {
    _started = true;
    if (DrivenClock.enabled) {
      final from = DrivenClock.now;
      _driven = DrivenClock.ticks.listen((now) => _advance(now - from));
      return;
    }
    _ticker = createTicker(_advance)..start();
  }

  Duration get _length {
    final f = _frames;
    if (f == null || f.length == 0) return Duration.zero;
    return Duration(microseconds: f.length * 1000000 ~/ _frameRate);
  }

  void _advance(Duration elapsed) {
    if (!mounted || _done) return;
    final f = _frames;
    if (f == null || f.length == 0) return;
    setState(() => _elapsed = elapsed);
    final after = elapsed - widget.holdFirst;
    if (after >= _length) {
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

  /// How far open the sheet is, 0 to 1.
  double get progress {
    if (_done || widget.startOpen) return 1.0;
    final total = _length;
    if (total == Duration.zero || !_started) return 0.0;
    final after = _elapsed - widget.holdFirst;
    if (after.isNegative) return 0.0;
    return (after.inMicroseconds / total.inMicroseconds).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final f = _frames;
    if (f == null || f.length == 0) return SizedBox(width: widget.width, height: _height);
    final p = progress;
    final i = _done ? f.length - 1 : (p * (f.length - 1)).round().clamp(0, f.length - 1);
    final image = f.at(i) ?? _lastDrawn;
    if (image == null) return SizedBox(width: widget.width, height: _height);
    _lastDrawn = image;
    final size = Size(widget.width, widget.width * image.height / image.width);
    final overlay = widget.overlay;
    return SizedBox(
      width: size.width,
      height: size.height,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _FramePainter(image))),
          if (overlay != null) overlay(context, p, size),
        ],
      ),
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

/// A note that arrived and has not been opened yet: it lies folded until it is touched, and when
/// it opens the writing is on the sheet that opened.
///
/// This is the only place a fold sequence appears in the thread, and it is why the sequences exist:
/// their notes arrive folded because that is what a note passed across a table is.
class FoldedNote extends StatefulWidget {
  const FoldedNote({
    super.key,
    required this.id,
    required this.width,
    required this.child,
    this.letter,
    this.seq = 'unfold_thirds',
    this.arriving = false,
  });

  /// The event this is the paper of. Opened once, it stays open however many times the row is
  /// built: a lazy list throws a row away when it scrolls off and makes a new one when it comes
  /// back, and a letter you had opened re-folding itself behind your back is a fault.
  final String id;
  final double width;

  /// The note as it would be drawn on its own torn paper: what is shown when no sequence is baked.
  final Widget child;

  /// What is written on the letter — the same content as [child], without the torn paper — drawn
  /// on the creased sheet as it settles flat. Without it the sheet opens blank and [child] is shown
  /// in its place once it has.
  final Widget? letter;
  final String seq;

  /// This note has just arrived: it lands on the desk rather than being there already.
  final bool arriving;

  /// Whether a fold sequence is on disk at all. Without one the note simply lies flat, which is
  /// honest: there is no substitute drawn in code for a render that has not been made.
  static bool get available =>
      MaterialLibrary.loaded && (MaterialLibrary.instance.folds[_defaultSeq] ?? 0) >= 60;
  static const _defaultSeq = 'unfold_thirds';

  /// Where the writing goes on the open sheet, as fractions of the frame: inside the paper, clear
  /// of the shadow that runs off its lower right. Measured against the packed frames.
  static const inset = [0.075, 0.085, 0.095, 0.17];

  /// The writing comes up over the last part of the sequence, while the sheet is settling flat.
  /// Starting it only once the sequence had finished is what left the clip ending on blank paper.
  static const inkFrom = 0.84;

  @override
  State<FoldedNote> createState() => _FoldedNoteState();
}

class _FoldedNoteState extends State<FoldedNote> {
  bool _opening = false;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    if (Folds.wasOpened(widget.id)) {
      _opening = true;
      _open = true;
    }
    Folds.whenAsked(_open2);
  }

  void _open2() {
    if (mounted && !_opening) setState(() => _opening = true);
  }

  void _opened() {
    Folds.markOpened(widget.id);
    if (mounted) setState(() => _open = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!FoldedNote.available) return widget.child;
    final letter = widget.letter;
    // No letter to write on the sheet: the sheet opens and the torn note is shown once it has.
    // Kept for callers that have nothing but a finished piece of paper.
    if (letter == null && _open) return widget.child;

    Widget sheet = Unfolding(
      seq: widget.seq,
      width: widget.width,
      autoplay: _opening,
      startOpen: _open && Folds.wasOpened(widget.id),
      onOpen: _opened,
      overlay: letter == null ? null : (ctx, p, size) => _ink(ctx, p, size, letter),
    );
    if (!_opening) {
      sheet = GestureDetector(onTap: () => setState(() => _opening = true), child: sheet);
    }
    if (widget.arriving) {
      // It lands: a little above the desk and a little large, dropping and settling into its place
      // on the clock the rest of the app moves on. Its shadow is in the frame, so what moves is
      // the whole sheet, the way a folded note tossed onto a table does.
      sheet = Settling(
        duration: Motion.land,
        curve: Motion.drop,
        builder: (_, t, child) => Opacity(
          opacity: (t * 4).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, -18 * (1 - t)),
            child: Transform.scale(scale: 1.06 - 0.06 * t, alignment: Alignment.topCenter, child: child),
          ),
        ),
        child: sheet,
      );
    }
    return sheet;
  }

  Widget _ink(BuildContext context, double p, Size size, Widget letter) {
    final ink = ((p - FoldedNote.inkFrom) / (1.0 - FoldedNote.inkFrom)).clamp(0.0, 1.0);
    if (ink <= 0) return const SizedBox.shrink();
    final i = FoldedNote.inset;
    final inner = size.width * (1 - i[0] - i[2]);
    return Positioned.fill(
      child: Padding(
        padding: EdgeInsets.fromLTRB(size.width * i[0], size.height * i[1], size.width * i[2], size.height * i[3]),
        child: Opacity(
          opacity: ink,
          // a letter is the size it is; writing that will not fit is written smaller, the way a
          // person running out of page writes smaller, rather than running off the paper
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topLeft,
            child: SizedBox(width: inner, child: letter),
          ),
        ),
      ),
    );
  }
}

/// Called from capture mode and from the thread: open every folded note on screen at once, so the
/// unfolding clip is of the app rather than of a thumb. Also the record of which letters have been
/// opened, so a row that is rebuilt lies open rather than re-folding itself.
class Folds {
  static final List<VoidCallback> _waiting = [];
  static final Set<String> _opened = {};

  static void whenAsked(VoidCallback open) => _waiting.add(open);

  static void openAll() {
    for (final open in List.of(_waiting)) {
      open();
    }
    _waiting.clear();
  }

  static bool wasOpened(String id) => _opened.contains(id);
  static void markOpened(String id) => _opened.add(id);

  @visibleForTesting
  static void reset() {
    _waiting.clear();
    _opened.clear();
  }
}
