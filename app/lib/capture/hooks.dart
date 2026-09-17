// Capture mode: the handles the evidence harness drives the app by.
//
// Nothing here changes what the app is; it only lets capture.sh reach the same buttons a thumb
// would, and step the clock frame by frame so a clip is a real recording of the app rather than a
// video of a browser trying to keep up. The handles exist only when the build was started with
// CAPTURE=true, so a real build has nothing to reach.
import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../flags.dart';
import '../material/assignment.dart';
import '../material/fold.dart';
import '../material/library.dart';
import '../scope.dart';
import 'bus.dart';
import 'hooks_stub.dart' if (dart.library.js_interop) 'hooks_web.dart' as impl;

/// What the harness can ask the app to do. Every entry answers with a JSON string: 'ok', or a
/// line naming what was missing, so capture.sh fails on the step rather than on the screenshot.
class CaptureHooks {
  CaptureHooks(this.scope);
  final AppScope scope;

  static CaptureHooks? _installed;
  static CaptureHooks? get installed => _installed;

  static void install(AppScope scope) {
    if (!Flags.capture) return;
    final hooks = CaptureHooks(scope);
    _installed = hooks;
    impl.expose(hooks);
  }

  Future<String> goToRegion(int index) async {
    final f = CaptureBus.goToRegion;
    if (f == null) return 'no shell';
    f(index);
    await _settle();
    return 'ok';
  }

  Future<String> scrollTo(String anchor) async {
    final f = CaptureBus.scrollTo;
    if (f == null) return 'chat is not on screen';
    await f(anchor);
    await _settle();
    return 'ok';
  }

  Future<String> sendFeeling(String feelingId, double intensity) async {
    final f = CaptureBus.sendFeeling;
    if (f == null) return 'no shell';
    await f(feelingId, intensity);
    await _settle();
    return 'ok';
  }

  Future<String> openCorner(bool open) async {
    final f = CaptureBus.openCorner;
    if (f == null) return 'no shell';
    f(open);
    await _settle();
    return 'ok';
  }

  /// Set one of my own signals, as if it had been declared on this phone or read off it.
  Future<String> setSignal(String signal, Object value, {bool declared = true}) async {
    await scope.emit(declared ? 'state_declared' : 'state_passive', {'signal': signal, 'value': value});
    await _settle();
    return 'ok';
  }

  /// Move the thread by [dy] logical pixels, once.
  Future<String> scrollBy(double dy) async {
    final f = CaptureBus.scrollBy;
    if (f == null) return 'chat is not on screen';
    f(dy);
    return 'ok';
  }

  /// Pair with the phone at [base] using the six words it is showing.
  ///
  /// The same call the setup list makes, not a shortcut past it: the words derive the key, and
  /// every request after this is signed with it. The capture harness needs it because the clip
  /// that shows a feeling crossing between two devices has to start with two devices that have
  /// actually been introduced.
  Future<String> pair(String base, String words) async {
    try {
      await scope.transport.completePairing(base, words);
      await _settle();
      return 'ok';
    } catch (e) {
      return 'pairing was refused: $e';
    }
  }

  /// Every delivery state at once, made rather than drawn.
  ///
  /// The try is not decoration. A Dart exception crossing into JS arrives at the harness as
  /// `Dart exception thrown from converted Future. Use the properties 'error' to fetch the boxed
  /// error` — which is a sentence about the bridge, not about what went wrong, and it is all the
  /// scene log had to show for an artifact that failed three runs in a row. Every handle that can
  /// fail says what failed.
  Future<String> stageStates() async {
    final f = CaptureBus.stageStates;
    if (f == null) return 'the shell is not up';
    try {
      await f();
    } catch (e, stack) {
      return 'staging the states threw: $e\n${stack.toString().split('\n').take(4).join('\n')}';
    }
    await _settle();
    return 'ok';
  }

  Future<String> openSender(bool open) async {
    final f = CaptureBus.openSender;
    if (f == null) return 'chat is not on screen';
    f(open);
    await _settle();
    return 'ok';
  }

  Future<String> openViewer(String eventId) async {
    final f = CaptureBus.openViewer;
    if (f == null) return 'chat is not on screen';
    try {
      await f(eventId);
    } on StateError catch (e) {
      return e.message;
    }
    await _settle();
    return 'ok';
  }

  Future<String> search(String query) async {
    final f = CaptureBus.search;
    if (f == null) return 'chat is not on screen';
    await f(query);
    await _settle();
    return 'ok';
  }

  Future<String> unfoldAll() async {
    final f = CaptureBus.unfoldAll;
    if (f == null) return 'chat is not on screen';
    f();
    await _settle();
    return 'ok';
  }

  Future<String> showWords() async {
    final f = CaptureBus.showWords;
    if (f == null) return 'settings is not on screen';
    await f();
    await _settle();
    return 'ok';
  }

  /// Everything the capture log needs: what is on screen and what produced it. The tear and stock
  /// ids are recomputed from the same assignment the renderer used, so tools/check/tear_repeat.py
  /// is checking the frame rather than trusting a note the app left itself.
  Map<String, dynamic> report() {
    final chat = CaptureBus.chatReport?.call() ?? const <String, dynamic>{};
    final lib = MaterialLibrary.loaded ? MaterialLibrary.instance : null;
    final visible = (chat['visible'] as List?)?.cast<String>() ?? const <String>[];
    final rows = {for (var i = 0; i < scope.thread.items.length; i++) scope.thread.items[i].id: i};
    final byId = {for (final e in scope.spine.all) e.id: e};
    final tears = <String, String?>{};
    final stocks = <String, String>{};
    for (final id in visible) {
      final e = byId[id];
      if (e == null || lib == null) continue;
      tears[id] = tearFor(e, lib, row: rows[id] ?? 0);
      stocks[id] = stockVariantFor(e, lib);
    }
    return {
      'region': CaptureBus.regionIndex,
      'visible': visible,
      'tears': tears,
      'stocks': stocks,
      'scroll': chat['scroll'],
      'now': scope.clock.now().toIso8601String(),
      'driven_ms': DrivenClock.now.inMilliseconds,
      'seed': Flags.captureSeed,
      'events': scope.spine.length,
      'transport': scope.transport.name,
      'link': scope.link.state.name,
      'me': scope.me.name,
      'masks_in_pool': lib?.tearMasks.length ?? 0,
      'writable_masks': lib?.writableTears.length ?? 0,
      // What the app is lit by, and whether the library it is drawing from actually has that
      // half baked. A dusk build with no dusk paper in it looks exactly like a day build, and
      // the crop taken from it came out byte-identical to the day one.
      'light': Flags.light,
      'has_dusk_paper': lib?.hasDusk ?? false,
      'paper_stocks': lib?.paper.length ?? 0,
      'setup_showing': CaptureBus.setupShowing,
      // a clip of a note opening that does not open is either a sequence nothing asked to play
      // or a sequence whose frames never decoded, and from the outside they look the same
      'fold': FoldFrames.state,
    };
  }

  /// Every text run the app has drawn, in the pixel coordinates of the screenshot about to be
  /// taken of it.
  ///
  /// `tools/check/legibility.py` finds writing by looking for marks shaped like glyphs, and says
  /// so in its own docstring. That was the only thing it could do from a PNG, and it is why the
  /// capture at `097bea5` grew 137 runs that had never existed: when the corrected illuminant
  /// stopped the torn paper lips clipping to flat white, their fibre steps stopped being flat and
  /// became marks. 102 of those 137 were below the floor, a 74% failure rate against 21% on the
  /// 622 runs that were really there, and the noise was larger than the change it was being used
  /// to judge.
  ///
  /// The app knows where its text is. This says so, so a run is declared rather than guessed at.
  /// Nothing here measures anything: the contrast arithmetic stays in the tool, against the real
  /// pixels, because the whole point of reading the artifact is that the antialiasing and the
  /// fibre and the shadow are in it. All this changes is *where the tool is allowed to look*.
  ///
  /// One entry per paragraph, with its line boxes, because a line is the unit a person reads and
  /// the unit `runs_of` was already grouping toward. Rects are integer device pixels — the PNG's
  /// own coordinate space, logical pixels times the view's devicePixelRatio — and are clipped to
  /// the view, so a paragraph scrolled half off the bottom declares only the half that was drawn.
  ///
  /// What is deliberately NOT here: any claim that a declared run is visible. A paragraph inside
  /// a zero opacity, or behind another sheet, is still in the render tree and still declared. That
  /// is safe in the only direction that matters, because the tool intersects this with the marks
  /// it finds: a run nobody can see contributes no marks and produces no reading. Declaring is
  /// permission to measure, not an assertion that there is something to measure.
  ///
  /// Static, like `DrivenClock.step`, because it reads the framework rather than the app: it needs
  /// no spine, no transport and no library, and a test of it should not have to stand one up.
  static List<Map<String, dynamic>> textRuns() {
    final out = <Map<String, dynamic>>[];
    for (final view in RendererBinding.instance.renderViews) {
      // The frame is the view's PHYSICAL size, and the transform to the view is already in
      // physical pixels: `RenderView` converts logical to device in its own paint transform, so
      // `getTransformTo(view)` lands in the picture's coordinates without anything here
      // multiplying by the ratio. Doing it again is the exact mistake this is written to avoid,
      // and it is silent -- every rect comes out a factor of the device pixel ratio too far down
      // and to the right, which on a screen of writing is somewhere between the lines.
      final size = view.flutterView.physicalSize;
      _collectRuns(view, view, view.flutterView.devicePixelRatio, Offset.zero & size, out);
    }
    return out;
  }

  static void _collectRuns(
      RenderObject node, RenderView view, double dpr, Rect bounds, List<Map<String, dynamic>> out) {
    if (node is RenderParagraph) _paragraph(node, view, dpr, bounds, out);
    // Visited even for a paragraph: a RenderParagraph can carry inline widget children, and one
    // of those can be another paragraph.
    node.visitChildren((child) => _collectRuns(child, view, dpr, bounds, out));
  }

  static void _paragraph(
      RenderParagraph p, RenderView view, double dpr, Rect bounds, List<Map<String, dynamic>> out) {
    if (!p.attached || !p.hasSize || p.size.isEmpty) return;
    final span = p.text;
    // Offsets are counted with the placeholders in, because that is the string the paragraph
    // indexes by; the emptiness test is taken without them, because a row of inline widgets with
    // no letters in it is not writing.
    final indexed = span.toPlainText();
    final visible = span.toPlainText(includePlaceholders: false).trim();
    if (visible.isEmpty) return;

    final Matrix4 toView = p.getTransformTo(view);
    Rect? box(Rect local) {
      final r = MatrixUtils.transformRect(toView, local).intersect(bounds);
      if (r.isEmpty || r.width < 1 || r.height < 1) return null;
      return r;
    }

    final whole = box(Offset.zero & p.size);
    if (whole == null) return;

    List<Rect> lines = const [];
    try {
      lines = p
          .getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: indexed.length))
          .map((b) => b.toRect())
          .map(box)
          .whereType<Rect>()
          .toList();
    } catch (_) {
      // A paragraph whose layout the framework will not hand back a selection for is still a
      // paragraph; its own rect is a coarser but honest declaration.
      lines = const [];
    }
    if (lines.isEmpty) lines = [whole];

    final style = span.style;
    final points = style?.fontSize ?? 14.0;
    out.add({
      'rect': _px(whole),
      'lines': [for (final l in lines) _px(l)],
      // The type size as the app asked for it, and again in the screenshot's own pixels. The
      // second is the one that matters: legibility.py splits body from large at a device-pixel
      // height, and until now it took that height off the bounding box of the marks it found,
      // which for a line with no ascenders or descenders in it is most of a point size short.
      'points': double.parse(points.toStringAsFixed(2)),
      'px': double.parse((p.textScaler.scale(points) * dpr).toStringAsFixed(2)),
      'family': style?.fontFamily ?? '',
      'role': _role(style?.fontFamily),
      'ink': _hex(style?.color),
      // Kept so a failing run can be read as a sentence instead of cropped out of a PNG at 300%,
      // which is what firing 9 had to do to establish that the extra runs were fibre.
      'text': visible.length > 64 ? '${visible.substring(0, 63)}…' : visible,
      'chars': visible.length,
    });
  }

  /// A rect already in the picture's own pixels, rounded outward so a mark on the edge of a line
  /// is inside the line rather than a pixel outside it.
  static List<int> _px(Rect r) => [r.left.floor(), r.top.floor(), r.width.ceil(), r.height.ceil()];

  /// What kind of writing this is, in the app's own vocabulary and not the tool's.
  ///
  /// Only what the font actually settles. `Hands.margin` is `TeoHand` and `Pen.margin` is now the
  /// same value as `Pen.stamp`, so there is no test here that separates a margin pencil from a
  /// hand, and inventing one would be the same inference this handle exists to remove.
  static String _role(String? family) {
    switch (family) {
      case 'DeskStamp':
        return 'stamp';
      case 'NoorHand':
      case 'TeoHand':
        return 'hand';
      default:
        return 'printed';
    }
  }

  static String _hex(Color? c) {
    if (c == null) return '';
    int chan(double v) => (v * 255).round().clamp(0, 255);
    return '${chan(c.a).toRadixString(16).padLeft(2, '0')}'
        '${chan(c.r).toRadixString(16).padLeft(2, '0')}'
        '${chan(c.g).toRadixString(16).padLeft(2, '0')}'
        '${chan(c.b).toRadixString(16).padLeft(2, '0')}';
  }

  /// Let the framework finish what the handle started before the harness takes the shot.
  static Future<void> _settle() async {
    for (var i = 0; i < 3; i++) {
      await Future<void>.delayed(Duration.zero);
      await DrivenClock.step(16);
    }
  }
}

/// The driven clock: in capture mode animations advance only when the harness says so, so every
/// frame of a clip is a real frame of the app at a known time.
class DrivenClock {
  static bool get enabled => Flags.capture;
  static Duration _now = Duration.zero;
  static final StreamController<Duration> _ticks = StreamController.broadcast();

  static Duration get now => _now;
  static Stream<Duration> get ticks => _ticks.stream;

  /// Advance by [ms] and let the framework produce exactly one frame.
  static Future<void> step(int ms) async {
    _now += Duration(milliseconds: ms);
    if (_ticks.hasListener) _ticks.add(_now);
    final done = Completer<void>();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!done.isCompleted) done.complete();
    });
    SchedulerBinding.instance.scheduleFrame();
    await done.future.timeout(const Duration(seconds: 2), onTimeout: () {});
  }
}
