// A piece of paper on the desk.
//
// The composite, bottom to top: the contact shadow render (alpha only, out of the same Blender
// frame as the piece), then the paper stock cut to shape by a tear mask, then the edge-light
// render that puts the broken fibres back on the torn edge, then whatever is written on it.
// Nothing here is a rounded rectangle with a drop shadow: every layer is a render made under
// blender/rig/common.py, and the masks carry their fibres in their alpha.
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'falloff.g.dart';
import 'library.dart';
import 'palette.dart';
import 'light.dart';

/// Ask for the frame the framework does not ask for.
///
/// **This is the whole of why the first two screens a new person sees were flat colour.**
///
/// A render arrives asynchronously: the bytes are fetched, the codec decodes, and some time later
/// the widget is handed a `ui.Image` and says so — an `Image`'s stream listener calls `setState`,
/// a `MaskCache` continuation does the same. Every one of those paths ends in
/// `SchedulerBinding.ensureVisualUpdate`, and that method **only schedules a frame from
/// `idle` and `postFrameCallbacks`**. From the three phases inside a frame it returns without
/// scheduling anything, on the assumption that the frame already in flight will carry the change.
///
/// When the arrival lands during the *build* of a frame that assumption holds. When it lands
/// during that frame's paint, or in the microtasks between its phases, the subtree it belongs to
/// has already been painted, and the request is simply dropped: no frame is scheduled, nothing is
/// left dirty, and the screen keeps the last thing that was drawn. On a screen where anything at
/// all asks for a frame afterwards — a note landing, a caret blinking, a partner's name ticking
/// over — the render appears on that frame and nobody ever knew. On a screen with nothing moving
/// on it, nothing ever asks.
///
/// Both of the screens a fresh install shows are that screen. Measured at firing 28, against a
/// build with no capture hooks in it at all: `17_setup_pwa` at three seconds, eight seconds and
/// twenty seconds is 47.98% one exact RGB — `Paper.looseleaf`, the fallback colour, not any pixel
/// of the render — with another 23.87% of the frame the flat `DeskColour.day` under it, because
/// the desk's own render was dropped the same way. A pointer move does not fix it, a tap does not
/// fix it, a `visibilitychange` does not fix it, and the scheduler says `hasScheduledFrame=false`,
/// `schedulerPhase=idle`, `framesEnabled=true`, `lifecycle=resumed` for as long as you watch it.
/// One bare `scheduleFrame()` and nothing else puts both the paper and the desk on the glass:
/// 47.98% falls to 1.88%. The render tree was right the whole time; the frame was never asked for.
///
/// So every place in this app that draws a rendered surface asks for it here. From inside a frame
/// that is a post-frame callback, which runs at the end of the frame in flight and schedules the
/// next one; from outside a frame it is the `scheduleFrame` `ensureVisualUpdate` would have made
/// itself. It costs one empty frame per render that arrives late and nothing at all per render
/// that was already decoded, which is every render after the first screenful.
void askForAFrame() {
  final sched = SchedulerBinding.instance;
  switch (sched.schedulerPhase) {
    case SchedulerPhase.idle:
    case SchedulerPhase.postFrameCallbacks:
      sched.scheduleFrame();
    case SchedulerPhase.transientCallbacks:
    case SchedulerPhase.midFrameMicrotasks:
    case SchedulerPhase.persistentCallbacks:
      // The frame in flight is already past this subtree, so it is the next one that has to
      // carry the render. `addPostFrameCallback` does not schedule a frame on its own; it is
      // safe here only because a frame is in flight by definition in these three phases.
      sched.addPostFrameCallback((_) => sched.scheduleFrame());
  }
}

/// The `frameBuilder` every `Image.asset` in this app is given, so that a render arriving late is
/// a render that reaches the glass. See [askForAFrame] for what it is working around.
///
/// `wasSynchronouslyLoaded` is the case this does not need to do anything about: the image was in
/// the cache when the widget first built, so it was painted with everything else.
Widget paintWhenItArrives(BuildContext context, Widget child, int? frame, bool wasSynchronouslyLoaded) {
  if (frame != null && !wasSynchronouslyLoaded) askForAFrame();
  return child;
}

/// Decoded masks and lit edges, shared by every piece that draws them and bounded in bytes.
///
/// Until firing 52 this was a plain map with no eviction and no dispose, so every mask a session
/// had ever drawn stayed decoded until the app died: 181 MB after one visit to the search screen,
/// 228 MB after a walk through every captured screen, measured at firing 51. On an iPhone PWA that
/// is a WebKit tab reloaded under the person using it.
///
/// So the cache no longer lends its own handle to anything that keeps it. A piece that draws a
/// mask [hold]s it — a `ui.Image.clone()`, which shares the decoded pixels and costs nothing — and
/// [release]s it when it stops drawing it. The cache's own handles live in least-recently-used
/// order under [budget], and an eviction disposes only the cache's handle: pixels a piece on the
/// glass is still holding stay decoded until that piece lets go. So what is resident is exactly
/// what is on screen plus at most [budget] of what was, however many screens a session has seen.
///
/// Alpha-only packing is not a lever here and was measured not to be: a `ui.Image` has no
/// single-channel pixel format, so a grey mask decodes to the same four bytes a pixel (firing 51).
class MaskCache {
  /// Decoded bytes the cache keeps for pieces that are no longer drawing them. Ten of the largest
  /// masks (1024x824, 3.4 MB each) and their edges (packed at half, 0.8 MB) is about a screenful's
  /// worth to come back to.
  static const int budget = 48 << 20;

  static final Map<String, ui.Image> _images = {}; // insertion order is recency order
  static final Map<String, Future<ui.Image>> _loading = {};
  static final Map<String, int> _held = {};
  static final Map<String, List<int>> _sizes = {};
  static final Map<String, int> _bytes = {};

  /// The cache's own handle, or null. **Borrowed**: read it, draw with it this frame, and do not
  /// keep it — it may be disposed by the next eviction. Anything that keeps a mask calls [hold].
  static ui.Image? peek(String asset) => _images[asset];

  /// The decoded size of [asset] as `[width, height]`, remembered past eviction, so that a reader
  /// like `CaptureHooks.paperSurfaces` can declare a piece whose mask the cache has let go of.
  static List<int>? sizeOf(String asset) => _sizes[asset];

  /// A handle of the piece's own on a decoded [asset], or null if it is not decoded. The caller
  /// owns it and must [release] it.
  static ui.Image? hold(String asset) {
    final have = _images.remove(asset);
    if (have == null) return null;
    _images[asset] = have; // most recently used
    _held[asset] = (_held[asset] ?? 0) + 1;
    return have.clone();
  }

  /// Decode [asset] if need be, then [hold] it.
  static Future<ui.Image> holdWhenLoaded(String asset) async {
    for (;;) {
      await load(asset);
      // between the decode and this line another decode may have evicted it; decode it again
      final held = hold(asset);
      if (held != null) return held;
    }
  }

  /// Give back a handle [hold] or [holdWhenLoaded] returned.
  static void release(String asset, ui.Image image) {
    image.dispose();
    final n = (_held[asset] ?? 1) - 1;
    if (n <= 0) {
      _held.remove(asset);
      // it is idle now, and may be what tips the idle bytes over
      _evict(keep: '');
    } else {
      _held[asset] = n;
    }
  }

  /// Decode [asset] into the cache. The image it completes with is the cache's own handle and is
  /// borrowed, exactly as [peek]'s is.
  static Future<ui.Image> load(String asset) {
    final have = _images[asset];
    if (have != null) return Future.value(have);
    return _loading.putIfAbsent(asset, () async {
      try {
        final data = await rootBundle.load(asset);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final frame = await codec.getNextFrame();
        final image = frame.image;
        _images[asset] = image;
        _sizes[asset] = [image.width, image.height];
        _bytes[asset] = image.width * image.height * 4;
        _evict(keep: asset);
        return image;
      } finally {
        _loading.remove(asset);
      }
    });
  }

  /// Oldest first, drop the cache's handles on masks nobody is holding until what nobody is
  /// holding fits in [budget]. Never [keep], which has just been asked for.
  static void _evict({required String keep}) {
    var idle = idleBytes;
    if (idle <= budget) return;
    for (final asset in _images.keys.toList()) {
      if (idle <= budget) break;
      if (asset == keep || (_held[asset] ?? 0) > 0) continue;
      _images.remove(asset)!.dispose();
      idle -= _bytes[asset] ?? 0;
    }
  }

  /// Bytes decoded for masks some piece is holding: what is on the glass.
  static int get heldBytes => _sum(_images.keys.where((a) => (_held[a] ?? 0) > 0));

  /// Bytes the cache keeps for masks nobody is holding. Never more than [budget] once a decode has
  /// finished, apart from the one mask just decoded.
  static int get idleBytes => _sum(_images.keys.where((a) => (_held[a] ?? 0) == 0));

  /// Everything decoded: [heldBytes] plus [idleBytes]. Clones share their pixels, so a mask five
  /// pieces are holding is counted once.
  static int get residentBytes => heldBytes + idleBytes;

  static int _sum(Iterable<String> assets) => assets.fold(0, (t, a) => t + (_bytes[a] ?? 0));

  /// Masks asked for and still decoding. A piece draws whole, or with its 1024 mask, until they
  /// land, so the shutter counts them as pictures not yet on the glass.
  static int get decoding => _loading.length;

  /// Decode a set of masks up front (capture mode does this so no frame waits on a decode).
  static Future<void> warm(Iterable<String> assets) async {
    for (final a in assets) {
      try {
        await load(a);
      } catch (_) {}
    }
  }
}

/// What every widget that draws a decoded mask does with it: [MaskCache.hold] it while it draws
/// it, [MaskCache.release] it when it stops, and rebuild when a mask that was still decoding
/// arrives. Three widgets did this by hand with the cache's own handle, which is what kept every
/// mask a session had seen decoded forever.
mixin HoldsAMask<T extends StatefulWidget> on State<T> {
  /// The asset this widget draws now.
  String get heldAsset;

  /// This widget's own handle, or null while the mask decodes or when it failed to.
  ui.Image? get held => _held;
  ui.Image? _held;
  String? _heldFor;

  @override
  void initState() {
    super.initState();
    _take();
  }

  @override
  void didUpdateWidget(T oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_heldFor != heldAsset) {
      _let();
      _take();
    }
  }

  @override
  void dispose() {
    _let();
    super.dispose();
  }

  void _let() {
    final h = _held, a = _heldFor;
    _held = null;
    _heldFor = null;
    if (h != null && a != null) MaskCache.release(a, h);
  }

  void _take() {
    final asset = heldAsset;
    _heldFor = asset;
    final now = MaskCache.hold(asset);
    if (now != null) {
      _held = now;
      return;
    }
    unawaited(MaskCache.holdWhenLoaded(asset).then((img) {
      // unmounted, or asked for another asset while this one decoded: give it straight back
      if (!mounted || _heldFor != asset || _held != null) {
        MaskCache.release(asset, img);
        return;
      }
      setState(() => _held = img);
      // A decode finishing inside a frame has its rebuild dropped; see [askForAFrame].
      askForAFrame();
    }, onError: (Object _) {}));
  }
}

/// The full-resolution copy of a mask, held only while the piece drawing it is too big for the
/// packed 1024 one.
///
/// Past 1.6x its mask on an axis, [SlicedMasks.sliceFor] has to give the fixed bands up to hold
/// the centre at [SlicedMasks.cap], and at its [SlicedMasks.fibres] floor it cannot: the setup
/// sheet's torn left and right edges were drawn at 13.9x, settings' at 9.2x (firing 54, off the
/// committed sidecars). The pixels to draw them finer were in `assets/tears` all along and were
/// thrown away by the packer. `tools/pack_assets.py` now keeps them in `assets/tears/hi/`, and a
/// piece asks for its mask's copy there only when it is that big, so the 1.5-4x residency is
/// spent on the few big sheets on the glass and never on a screenful of notes.
///
/// Which mask a big sheet draws is picked by a hash of its id, so this cannot be a list of five
/// named masks: every mask has its finer copy, and size decides.
class FinerMask {
  FinerMask(this._arrived);

  final void Function() _arrived;
  ui.Image? _image;
  String? _asset;

  /// Bumped when the finer copy lands, so a painter built before it knows to repaint.
  int get generation => _generation;
  int _generation = 0;

  /// The asset and image to compose a piece of [size] logical pixels from: [base]'s finer copy
  /// when the piece is too big for [base] and the copy has decoded, and [base] otherwise.
  (String, ui.Image) pick(String baseAsset, ui.Image base, Size size, double dpr) {
    if (!SlicedMasks.wantsFiner(base, size, dpr)) return (baseAsset, base);
    final finer = finerTearAsset(baseAsset);
    if (_asset != finer) {
      release();
      _asset = finer;
      final now = MaskCache.hold(finer);
      if (now != null) {
        _image = now;
      } else {
        unawaited(MaskCache.holdWhenLoaded(finer).then((img) {
          if (_asset != finer || _image != null) {
            MaskCache.release(finer, img);
            return;
          }
          _image = img;
          _generation++;
          _arrived();
        }, onError: (Object _) {}));
      }
    }
    final img = _image;
    return img == null ? (baseAsset, base) : (finer, img);
  }

  /// Give the finer copy back, if one is held. Call from `dispose`.
  void release() {
    final i = _image, a = _asset;
    _image = null;
    _asset = null;
    if (i != null && a != null) MaskCache.release(a, i);
  }
}

/// One sheet: stock × tear mask, lit edge, baked shadow, and its content.
class PaperPiece extends StatelessWidget {
  const PaperPiece({
    super.key,
    this.id,
    required this.stockId,
    this.tearId,
    this.liftMm = 0.8,
    this.tilt = 0.0,
    this.padding = const EdgeInsets.fromLTRB(10, 8, 10, 8),
    this.safe = const [0.06, 0.07, 0.06, 0.07],
    this.width,
    this.hug = false,
    this.child,
    this.stockAlignment = Alignment.center,
    this.stockScale = 1.0,
    this.besideTheMargin = false,
    this.overlays = const [],
  });

  /// What this piece of paper is, in the app's own words — `facet_written`, `search_query`,
  /// `empty.chat`, an event id. Null where nothing named it.
  ///
  /// It is carried into `evidence/<artifact>.surfaces.json` as `piece`, so a measurement can say
  /// which surfaces it is about without inferring it from an asset path or a coordinate. See
  /// `CaptureHooks.paperSurfaces`.
  final String? id;

  /// A paper stock variant id, e.g. `lined_02`.
  final String stockId;

  /// A tear mask id, e.g. `tear_017`. Null leaves the sheet whole.
  final String? tearId;

  /// How far the piece lifts off the desk: how far and how soft its shadow is.
  final double liftMm;

  /// Radians. Paper never lies square to the desk.
  final double tilt;

  /// Extra room inside the safe area, in logical pixels.
  final EdgeInsets padding;

  /// How far in from each edge (left, top, right, bottom, as fractions of the piece) the tear
  /// cannot reach. tools/pack_assets.py measures this from the mask itself.
  final List<double> safe;
  final double? width;

  /// Take the width of what is written on this piece, even where something above it offers a
  /// width to fill.
  ///
  /// A piece with nothing constraining it is already the width of its writing — that is the
  /// `else` branch in [_RenderWithinTear.performLayout], and it is how a slip behaves in a `Row`,
  /// which hands its children an unbounded main axis. A `Wrap` does not: it lays every child out
  /// against its own `maxWidth`, so a piece of paper inside one grows to fill the line and the
  /// `Wrap` never wraps — it becomes a vertical stack of full-width sheets, one per child. That
  /// is what thirteen facet tabs on the search screen were, and between them they took 63% of the
  /// frame and left one and a half results underneath.
  ///
  /// The width is still clamped by the incoming constraints at the end of layout, so a label
  /// longer than the screen is bounded rather than overflowing.
  final bool hug;
  final Widget? child;

  /// Which square of the stock this piece is torn from, so two notes on the same stock never show
  /// the same patch of paper.
  final Alignment stockAlignment;
  final double stockScale;

  /// Cut this piece from the paper to the right of its stock's printed margin rule, so the words
  /// on it are never laid across the rule. On a pad you write beside the red line; a word across
  /// it sits on the darkest ground in the library, and at dusk no ink in the ladder reads there
  /// (`a-word-is-written-across-the-printed-margin-rule`, firing 47). The stock is drawn from its
  /// right edge, just enough larger that the rule falls off the piece's left edge -- which a piece
  /// can do because it is torn from a sheet, and a sheet is wider than what is torn from it.
  /// A stock with no rule is drawn exactly as [stockScale] and [stockAlignment] say.
  final bool besideTheMargin;

  /// [stockScale] and [stockAlignment] for [stock], moved past its margin rule when
  /// [besideTheMargin] asks and the library says where the rule is.
  (double, Alignment) stockFraming(String stock) {
    if (!besideTheMargin || !MaterialLibrary.loaded) return (stockScale, stockAlignment);
    final m = MaterialLibrary.instance.paperMargin[stock];
    if (m == null) return (stockScale, stockAlignment);
    // drawn from the right edge, the rule sits (1 - m[1]) of the stock's width in from it; that
    // has to be the whole piece, plus a little for the tilt and the torn edge
    final scale = math.max(stockScale, 1.06 / (1 - m[1]));
    return (scale, Alignment(1, stockAlignment.y));
  }

  /// Tape, staples, clips: rendered bits laid over the piece.
  final List<Widget> overlays;

  static Widget none(BuildContext c, Object e, StackTrace? s) => const SizedBox.shrink();



  /// The contact shadow, laid around the piece's OWN outline at the width the render's falloff
  /// actually has — not the render stretched to the shape of whatever box the piece turned out
  /// to be.
  ///
  /// **What this used to be, and why it is not that any more.** It was the shadow render drawn
  /// `Positioned.fill` with `BoxFit.fill` inside a `Transform.scale(shadowFrame)`, which made the
  /// spill a tenth of the PIECE on each side. A margin strip 111 device pixels tall got 11 px of
  /// spill and a note 974 px tall got 97, for a shadow that is one millimetre wide either way, so
  /// the render's 85-row falloff was averaged away on the strips and blown up on the notes.
  /// Measured at firing 42 over 87 pieces on six artifacts, by each piece's own declared rect: at
  /// more than 6:1 of aspect distortion the visible contact band had a median width of 0 px, at
  /// 2–6:1 it was 6 px, and at 2:1 or less it was 9.5 px. The spill was proportional to the paper
  /// instead of to the lift, which is not what a contact shadow is.
  ///
  /// Three routes were tried and measured before this one. Picking a mask whose aspect suits the
  /// piece cannot reach it — 70 of 172 draws need an aspect wider than the widest of the 56 masks
  /// (firing 41). `BoxFit.cover` preserves the sampling and breaks the hug. And a nine-slice
  /// cannot be aimed either, for a reason firing 45 had to measure rather than assert: the falloff
  /// belongs to the RENDER's outline, and that outline sits a median of 8.73 mm inside the piece's
  /// box on its worst torn side — 7.28 times the falloff's own 1.2 mm, and never less than
  /// 2.70 mm on any of the 91 torn sides — so any slice drawn at the box cuts the falloff along
  /// exactly the torn edges, and leaves it in the stretched middle.
  ///
  /// So the falloff is laid around the outline instead, at the physical width `light.dart` says a
  /// millimetre is. The profile is [ShadowFalloff], measured off these same renders by
  /// `tools/check/shadow_falloff.py` — the brief asks for a shadow `baked from the render's own
  /// lighting rather than applied as a uniform blur`, and a `MaskFilter.blur` is that uniform blur
  /// and is the anti-goal. The shape is the renders'; only the stretching is gone.
  Widget _contactShadow(BuildContext context, LightCondition condition) {
    return Positioned.fill(
      child: ContactShadow(
        tearId: tearId!,
        condition: condition,
        // One lift was modelled, and the render is as dark as this shadow gets: a note that
        // lies flatter than the model cannot press harder than the render already did, so the
        // reference is the flattest lift and every other note lifts away from it, lighter.
        //
        // The lift is still carried HERE and not in the width, deliberately. The library bakes one
        // lift (`relief.json` `lift_mm` 2.4) and one falloff (1.2 mm), so a penumbra-per-millimetre
        // law drawn from it would be extrapolated from a single measurement — and every `liftMm` in
        // this app is far below the baked one, 0.25 to 1.46, so a linear law would put the visible
        // band at 1.4–8.3 device pixels at dpr 3. Inventing that curve is the thing this route
        // exists to avoid; a second baked lift is what would make it honest.
        opacity: (shadowOpacityFor(liftMm) / shadowOpacityFor(0.0)).clamp(0.6, 1.0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dusk = Light.of(context) == LightCondition.dusk;
    final stock = (!dusk || stockId.endsWith('_dusk')) ? stockId : '${stockId}_dusk';
    final framing = stockFraming(stock);
    final content = Stack(
      children: [
        // Underneath everything, the colour the stock is. The render is what makes it paper, but
        // this is what stops it ever being nothing: a sheet whose image has not arrived, or whose
        // image is missing from the bundle, is still a sheet.
        Positioned.fill(child: ColoredBox(color: Paper.forStock(stock))),
        Positioned.fill(
          child: Transform.scale(
            scale: framing.$1,
            alignment: framing.$2,
            child: Image.asset(
              paperAsset(stock),
              fit: BoxFit.cover,
              alignment: framing.$2,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
              frameBuilder: paintWhenItArrives,
              errorBuilder: PaperPiece.none,
            ),
          ),
        ),
        if (tearId != null)
          // sliced the same way the mask is, so the lit fibres on the torn edge keep the length
          // they were rendered at however tall the sheet turns out to be
          Positioned.fill(
              child: NineSliced(asset: tearAsset('${tearId!}_edge'), downsample: kEdgeDownsample)),
        _WithinTear(
            safe: safe, padding: padding, hug: hug, child: child ?? const SizedBox.shrink()),
        ...overlays,
      ],
    );
    // the stock is drawn larger than the piece so two notes never show the same patch of paper;
    // clip it to the piece before masking, or it paints over its neighbours
    final clipped = ClipRect(child: content);
    final piece = tearId == null ? clipped : MaskedLayer(maskAsset: tearAsset(tearId!), child: clipped);
    return Transform.rotate(
      angle: tilt,
      // The shadow is Positioned.fill, so it is the size of the Stack; the Stack is the size of
      // the piece, except where something hands the piece tight constraints — a square cell in a
      // grid — and then the shadow stretches to fill the cell while the piece stays the height of
      // what is written on it. In Moments that put a black torn rectangle under every voice note:
      // a contact shadow blown up until its dense middle covered a quarter of the screen.
      //
      // Align passes loose constraints down whatever it is given, so the Stack is the size of the
      // piece again and the shadow is the piece's own.
      child: Align(
        alignment: Alignment.topCenter,
        heightFactor: 1.0,
        // And the width too, when the piece is hugging. An `Align` with no `widthFactor` takes
        // the whole of a bounded width, so a sheet that had just been laid out at the width of
        // its own label was handed back to the `Wrap` as a full-width box with the label
        // centred in it — the same vertical stack, with the tear in the middle of the line
        // instead of across it.
        widthFactor: hug ? 1.0 : null,
        child: SizedBox(
          width: width,
          child: Stack(
            children: [
              // The contact shadow is not drawn here so much as uncovered: it came out of the same
              // render as the piece, already in the right place, already the right shape. All the
              // app does is put it back at the size it was framed at — wider than the piece, because
              // the part of a contact shadow anyone sees is the part the paper is not covering.
              if (tearId != null)
                _contactShadow(context, dusk ? LightCondition.dusk : LightCondition.day),
              piece,
            ],
          ),
        ),
      ),
    );
  }
}

/// Lays the writing inside the part of the piece the tear cannot reach.
///
/// The piece's height is not known until the writing has been laid out, and the safe area is a
/// fraction of that height, so the two are solved together: with content height C and safe
/// fractions fT and fB, the piece is C / (1 - fT - fB) tall and the writing starts fT down it.
class _WithinTear extends SingleChildRenderObjectWidget {
  const _WithinTear(
      {required this.safe, required this.padding, required this.hug, required Widget child})
      : super(child: child);

  final List<double> safe;
  final EdgeInsets padding;
  final bool hug;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderWithinTear(safe, padding, hug);

  @override
  void updateRenderObject(BuildContext context, _RenderWithinTear renderObject) {
    renderObject
      ..safe = safe
      ..padding = padding
      ..hug = hug;
  }
}

class _RenderWithinTear extends RenderShiftedBox {
  _RenderWithinTear(this._safe, this._padding, this._hug) : super(null);

  List<double> _safe;
  EdgeInsets _padding;
  bool _hug;

  set hug(bool v) {
    if (_hug == v) return;
    _hug = v;
    markNeedsLayout();
  }

  set safe(List<double> v) {
    if (_safe == v) return;
    _safe = v;
    markNeedsLayout();
  }

  set padding(EdgeInsets v) {
    if (_padding == v) return;
    _padding = v;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final fL = _safe[0], fT = _safe[1], fR = _safe[2], fB = _safe[3];
    final child = this.child;
    if (child == null) {
      size = constraints.constrain(Size(constraints.hasBoundedWidth ? constraints.maxWidth : 0, 0));
      return;
    }
    final double width;
    if (constraints.hasBoundedWidth && !_hug) {
      width = constraints.maxWidth;
      final inner = (width * (1 - fL - fR) - _padding.horizontal).clamp(24.0, width);
      child.layout(BoxConstraints(maxWidth: inner), parentUsesSize: true);
    } else {
      // Nothing is constraining the width — a slip in a horizontal strip of them, a chip in a
      // scrolling row. It used to fall back to a flat 320 points, so a filter chip reading
      // `both` was two thirds of the screen wide and the third chip was off the edge of it.
      // A piece with no width given is the width of what is written on it.
      //
      // `hug` takes this branch on purpose where there *is* a bound, because a `Wrap` bounds its
      // children at its own width and a sheet that fills the line it is on is a sheet the `Wrap`
      // can never put two of on one line. `constraints.constrain` below still clamps the result,
      // so a label wider than the screen is bounded here rather than overflowing later.
      child.layout(const BoxConstraints(), parentUsesSize: true);
      final horizontal = (1 - fL - fR).clamp(0.35, 1.0);
      width = (child.size.width + _padding.horizontal) / horizontal;
    }
    final content = child.size.height + _padding.vertical;
    final vertical = (1 - fT - fB).clamp(0.35, 1.0);
    final height = content / vertical;
    size = constraints.constrain(Size(width, height));
    (child.parentData! as BoxParentData).offset = Offset(
      width * fL + _padding.left,
      size.height * fT + _padding.top,
    );
  }
}

/// Applies a mask image's alpha to its child. The masks are packed as white with the paper in
/// their alpha channel, so `dstIn` against the mask keeps exactly the paper, fibres and all.
///
/// The mask is nine-sliced before it is applied, and that is the whole reason this is more than a
/// ShaderMask. A mask is about 1024x580; the setup sheet is 1440x2600. Stretched to fill, every
/// fibre along the torn edge is pulled four and a half times its own length, and a sheet that
/// reads as paper at note size reads as fur at page size. Sliced, the four corners and the four
/// edges keep the scale they were rendered at and only the middle — which is solid paper — is
/// stretched.
///
/// It is done by composing the slice into one image at the size the piece turned out to be, and
/// then applying *that* as an ordinary shader. The obvious way — a render object that opens a
/// layer, paints the child and draws the mask over it with dstIn — does not work: after
/// `PaintingContext.paintChild` the context may be on a different canvas, so the saveLayer and the
/// restore land on two different ones. It failed loudly, in the way this class of mistake does:
/// the mask was not applied at all, every sheet in the app came out a rectangle, and the engine
/// eventually threw `call_indirect to a signature that does not match`.
class MaskedLayer extends StatefulWidget {
  const MaskedLayer({super.key, required this.maskAsset, required this.child});
  final String maskAsset;
  final Widget child;

  @override
  State<MaskedLayer> createState() => _MaskedLayerState();
}

class _MaskedLayerState extends State<MaskedLayer> with HoldsAMask<MaskedLayer> {
  @override
  String get heldAsset => widget.maskAsset;

  late final FinerMask _finer = FinerMask(() {
    if (mounted) setState(() {});
    askForAFrame();
  });

  @override
  void dispose() {
    _finer.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // a mask that is not decoded yet leaves the sheet whole rather than blank
    final mask = held;
    if (mask == null) return widget.child;
    // Composed at device pixels, not logical ones. A note is about 340 points wide and the screen
    // it is on is three times that, so a mask composed at 340 would be upsampled threefold before
    // anybody saw it — and the row this material is judged on is judged at three hundred per cent
    // on exactly this. The shader scales it back down.
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (Rect rect) {
        final (asset, source) = _finer.pick(widget.maskAsset, mask, rect.size, dpr);
        SlicedMasks.drawnWith[SlicedMasks.composedKey(widget.maskAsset, rect.size)] = asset;
        final sliced = SlicedMasks.at(asset, source, rect.size, dpr);
        final m = Matrix4.identity()
          ..translateByDouble(rect.left, rect.top, 0, 1)
          ..scaleByDouble(rect.width / sliced.width, rect.height / sliced.height, 1, 1);
        return ImageShader(sliced, TileMode.clamp, TileMode.clamp, m.storage,
            filterQuality: FilterQuality.medium);
      },
      child: widget.child,
    );
  }
}

/// Masks composed at the size a piece turned out to be, kept so a screenful of notes composes
/// each shape once rather than once a frame.
class SlicedMasks {
  static final Map<String, ui.Image> _images = {}; // insertion order is recency order

  /// Decoded bytes of composed masks kept, least recently used dropped first. It was 64 images
  /// until firing 52, and one composition can be 1024x3296 — 13.5 MB — so a count bounded
  /// nothing. A screen whose pieces need more than this still draws every one: an image dropped
  /// here is disposed only as this cache's handle, and a shader already built on it keeps its own.
  static const int budget = 48 << 20;

  /// Bytes of composed masks held now.
  static int get bytes => _images.values.fold(0, (t, i) => t + i.width * i.height * 4);

  /// The resolution a mask was last composed at, for the logical box it was composed for:
  /// `'<asset>@<logical w>x<logical h>'` to `[composed w, composed h]`, both in device pixels.
  ///
  /// This is the number the tear's own contour is defined at, and it is not the mask render's
  /// size: [at] clamps the composition to the mask's own width and to four times its height, so a
  /// sheet wider than its mask has its torn edge resampled up by the shader afterwards. Nothing
  /// visible could say so — the composed image never leaves this class — and the surfaces sidecar
  /// now carries it, so a reader can tell a mask that is upsampled from a lit edge that is.
  /// See `CaptureHooks.paperSurfaces`.
  static final Map<String, List<int>> composedAt = {};

  static String composedKey(String asset, Size box) =>
      '$asset@${box.width.round()}x${box.height.round()}';

  /// How much of a mask, in from each edge, is the torn edge itself rather than the paper inside
  /// it. Measured off the masks: the fibres reach about a fifth of the way in and the middle fifth
  /// is always solid, so four tenths is comfortably outside them.
  static const double edge = 0.4;

  /// How thin the fixed band may get on a piece much larger than its mask. Measured at firing 51
  /// over the 56 packed masks as the 99th-percentile depth, per column, at which the alpha first
  /// holds solid: p50 0.05-0.12 by edge, and at most 0.227 on the five masks that back the big
  /// sheets (tear_004, 020, 031, 036, 043). A quarter keeps every one of those fibres at the scale
  /// it was rendered at.
  static const double fibres = 0.25;

  /// The centre-band magnification the slice tries to stay under, which is this item's own floor:
  /// a torn left or right edge's treads are as long as the vertical magnification of the band they
  /// fall in.
  static const double cap = 4.0;

  /// The slice fraction for one axis of a mask [src] source pixels long composed into [dst].
  ///
  /// At a fixed 0.4 every pixel of height past the two fixed bands is poured into the middle fifth
  /// of the source, so the setup sheet's left and right contours were drawn at 19.5x -- four times
  /// worse than not slicing at all (firing 44, off the sidecar). So the fixed bands give way as the
  /// piece grows, just far enough to hold the centre at [cap], and never thinner than [fibres].
  /// A piece up to 1.6x its mask on an axis is sliced exactly as before, which is 156 of the 172
  /// torn pieces in the set.
  static double sliceFor(double src, double dst) {
    if (src <= 0) return edge;
    final f = (cap * src - dst) / (2 * src * (cap - 1));
    return f.clamp(fibres, edge).toDouble();
  }

  /// Whether a piece of [size] logical pixels is too big for [mask]: past the point on either axis
  /// where [sliceFor] starts giving the fixed bands up, which is 1.6x. Below it the mask is sliced
  /// exactly as it always was and nothing finer is decoded (see [FinerMask]).
  static bool wantsFiner(ui.Image mask, Size size, double dpr) =>
      sliceFor(mask.width.toDouble(), size.width * dpr) < edge ||
      sliceFor(mask.height.toDouble(), size.height * dpr) < edge;

  /// Which asset a piece's mask was actually composed from, keyed by the asset it asked for and
  /// its box: `composedKey(tearAsset(id), box)` to `tearAsset(id)` or `finerTearAsset(id)`. So
  /// `CaptureHooks.paperSurfaces` declares the mask that cut the paper, at its own size.
  static final Map<String, String> drawnWith = {};

  static ui.Image at(String asset, ui.Image mask, Size size, double dpr) {
    // rounded, so a note whose height moves by a pixel while its text lays out does not compose a
    // new mask every frame; and never larger than the mask itself, because upsampling a render is
    // not the same as having rendered it larger
    final w = (size.width * dpr).round().clamp(1, mask.width);
    final h = (size.height * dpr).round().clamp(1, mask.height * 4);
    final key = '$asset@${w}x$h';
    composedAt[composedKey(asset, size)] = [w, h];
    final have = _images.remove(key);
    if (have != null) return _images[key] = have; // most recently used
    var total = bytes + w * h * 4;
    while (total > budget && _images.isNotEmpty) {
      final oldest = _images.keys.first;
      final gone = _images.remove(oldest)!;
      total -= gone.width * gone.height * 4;
      gone.dispose();
    }
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final mw = mask.width.toDouble(), mh = mask.height.toDouble();
    final ex = sliceFor(mw, w.toDouble()), ey = sliceFor(mh, h.toDouble());
    canvas.drawImageNine(
      mask,
      Rect.fromLTRB(mw * ex, mh * ey, mw * (1 - ex), mh * (1 - ey)),
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint()..filterQuality = FilterQuality.medium,
    );
    final image = recorder.endRecording().toImageSync(w, h);
    _images[key] = image;
    return image;
  }
}

/// How many times smaller the lit edges are packed than the masks they light, on each axis.
///
/// `tools/pack_assets.py` writes `*_edge.webp` at half the mask's size, and [NinePainter] draws it
/// at the mask's geometry, so nothing on the glass moves: only the resolution of a soft light band
/// does. Until firing 54 the edges were packed at the masks' 1024 and were the larger half of what
/// a screen holds decoded -- 78.0 MB of `12_search`'s 158 MB, for a band that is a glow and not a
/// cut. Measured off that screen's 41 declared edges before the change: drawn at their own
/// geometry over paper, a 2x edge differs from the 1024 one by at most 0.26/255 over a piece and
/// 1.1/255 over the band itself; 3x reaches 2.1/255 on the band, which is why it is 2.
/// `test/the_lit_edge_is_packed_at_half_test.dart` holds the pack to it.
const double kEdgeDownsample = 2;

/// An image drawn as a nine-slice: the four corners and the four edges at the scale they were
/// rendered at, and only the middle stretched.
///
/// Image's own `centerSlice` cannot do this here — it asserts that the fit leaves the whole source
/// visible, and every one of these is drawn into a box of a different shape from the render. So
/// the image is decoded through the same cache the masks use and drawn straight.
class NineSliced extends StatefulWidget {
  const NineSliced(
      {super.key, required this.asset, this.edge = 0.4, this.opacity = 1.0, this.downsample = 1.0});

  final String asset;

  /// How many times smaller [asset] was packed than the geometry it is drawn at. The slices land
  /// where a full-size render's would; see [kEdgeDownsample].
  final double downsample;

  /// How much of the render, in from each edge, is the torn edge itself rather than the paper
  /// inside it. Measured off the masks: the fibres reach about a fifth of the way in and the
  /// middle fifth is always solid, so four tenths is comfortably outside them.
  final double edge;
  final double opacity;

  @override
  State<NineSliced> createState() => _NineSlicedState();
}

class _NineSlicedState extends State<NineSliced> with HoldsAMask<NineSliced> {
  @override
  String get heldAsset => widget.asset;

  @override
  Widget build(BuildContext context) {
    final image = held;
    if (image == null) return const SizedBox.shrink();
    return CustomPaint(
        painter: NinePainter(widget.asset, image, widget.edge, widget.opacity, widget.downsample));
  }
}

/// Public, and carrying the asset it draws, so that [CaptureHooks.paperSurfaces] can declare a
/// lit edge the way it already declares a baked shadow.
///
/// A torn piece is three rendered layers with three geometries — the mask, this, and the contact
/// shadow — and until firing 44 only the shadow appeared in `evidence/<artifact>.surfaces.json`,
/// because the sidecar is built by walking the render tree for `RenderImage` and this is a
/// `CustomPaint`. So a reader asking which of the three makes a stepped boundary could see one of
/// the three suspects. Nothing about what is drawn changes; the painter simply says what it is.
class NinePainter extends CustomPainter {
  NinePainter(this.asset, this.image, this.edge, this.opacity, [this.downsample = 1.0]);

  /// The asset this draws, e.g. `assets/tears/tear_004_edge.webp`.
  final String asset;
  final ui.Image image;
  final double edge;
  final double opacity;

  /// See [NineSliced.downsample].
  final double downsample;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final w = image.width.toDouble(), h = image.height.toDouble();
    // drawImageNine lays the slices down at one canvas unit a source pixel, so an image packed
    // [downsample] times smaller is drawn on a canvas that many times larger: the slices, and
    // the shrink-to-fit when the box is narrower than them, land exactly where the full-size
    // render's did
    canvas.save();
    canvas.scale(downsample);
    canvas.drawImageNine(
      image,
      Rect.fromLTRB(w * edge, h * edge, w * (1 - edge), h * (1 - edge)),
      Offset.zero & (size / downsample),
      Paint()
        ..filterQuality = FilterQuality.medium
        ..color = Color.fromRGBO(0, 0, 0, opacity),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(NinePainter old) =>
      !identical(old.image, image) ||
      old.edge != edge ||
      old.opacity != opacity ||
      old.downsample != downsample;
}

/// The contact shadow of one piece: the library's measured falloff laid around the piece's own
/// torn outline, at the physical width `light.dart` says a millimetre is.
///
/// See [PaperPiece._contactShadow] for what this replaced and for the three routes that were
/// measured and refused first.
class ContactShadow extends StatefulWidget {
  const ContactShadow({
    super.key,
    required this.tearId,
    required this.condition,
    this.opacity = 1.0,
  });

  /// The tear this piece is cut to, e.g. `tear_004`. Its mask is the outline the shadow is laid
  /// around — composed the same way [MaskedLayer] composes it, so the shadow and the paper agree
  /// about where the edge is — and its `*_shadow` render is where the profile was measured.
  final String tearId;

  /// Which rig's renders the profile was measured from. The requirement
  /// `a_note_at_dusk_asks_for_its_dusk_shadow_test.dart` was written for — a shadow at dusk is the
  /// dusk rig's own lighting and not the day one dimmed — lives here now that the app no longer
  /// names a shadow asset.
  final LightCondition condition;

  final double opacity;

  @override
  State<ContactShadow> createState() => _ContactShadowState();
}

class _ContactShadowState extends State<ContactShadow> with HoldsAMask<ContactShadow> {
  @override
  String get heldAsset => tearAsset(widget.tearId);

  // the same choice [MaskedLayer] makes for the same piece, so the outline the shadow is laid
  // around is the outline the paper was cut to
  late final FinerMask _finer = FinerMask(() {
    if (mounted) setState(() {});
    askForAFrame();
  });

  @override
  void dispose() {
    _finer.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // a mask that is not decoded yet draws no shadow rather than a black rectangle
    final mask = held;
    if (mask == null) return const SizedBox.shrink();
    return CustomPaint(
      painter: ContactShadowPainter(
        tearId: widget.tearId,
        mask: mask,
        condition: widget.condition,
        opacity: widget.opacity,
        dpr: MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0,
        finer: _finer,
      ),
    );
  }
}

/// Public, and carrying the profile it laid and the spill it laid it over, so that
/// [CaptureHooks.paperSurfaces] can declare a contact shadow the way it already declares the mask
/// and the lit edge.
///
/// Before firing 45 the shadow was an `Image.asset`, so the sidecar saw it for free as a
/// `RenderImage` and every measurement of this item was written against that. A procedural shadow
/// that said nothing would have taken the shadow surfaces out of `evidence/*.surfaces.json`
/// entirely — and this item's own clause (c) asserts the piece count does not fall, so the fix
/// would have deleted the evidence that judges it. It says what it drew instead.
class ContactShadowPainter extends CustomPainter {
  ContactShadowPainter({
    required this.tearId,
    required this.mask,
    required this.condition,
    required this.opacity,
    required this.dpr,
    this.finer,
  }) : _generation = finer?.generation ?? 0;

  /// Where a piece too big for its packed mask gets the finer one; see [FinerMask]. Null draws
  /// from [mask] whatever the size.
  final FinerMask? finer;

  /// [FinerMask.generation] when this painter was built: the finer copy landing repaints.
  final int _generation;

  /// The tear whose outline this shadow is laid around, e.g. `tear_004`.
  final String tearId;
  final ui.Image mask;
  final LightCondition condition;
  final double opacity;
  final double dpr;

  /// The mask asset the outline comes from, e.g. `assets/tears/tear_004.webp`.
  String get asset => tearAsset(tearId);

  /// The profile laid down: this tear's own render where the library has it, and the pooled
  /// profile over all fifty-six where it does not.
  List<double> get profile => ShadowFalloff.forTear(tearId, condition.name);

  /// The render the profile was measured from, e.g. `tear_004_shadow_dusk`, or null where the
  /// pooled profile was used. This is the surface's provenance, and it is what
  /// `a_note_at_dusk_asks_for_its_dusk_shadow_test.dart` holds the app to.
  String? get render => ShadowFalloff.renderFor(tearId, condition.name);

  /// How far the shadow reaches outside the piece, in logical pixels. This is the whole point of
  /// the class: it is a physical width, the same on a margin strip and on a full sheet, and it
  /// does not know how big the piece is.
  static double get spill => ShadowFalloff.reachMm * kShadowPerMm;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || opacity <= 0) return;
    final (outline, source) = finer?.pick(asset, mask, size, dpr) ?? (asset, mask);
    final composed = ContactShadows.at(outline, source, size, dpr, condition, profile);
    if (composed == null) return;
    final dst = Rect.fromLTWH(-spill, -spill, size.width + 2 * spill, size.height + 2 * spill);
    canvas.drawImageRect(
      composed,
      Rect.fromLTWH(0, 0, composed.width.toDouble(), composed.height.toDouble()),
      dst,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..color = Color.fromRGBO(0, 0, 0, opacity),
    );
  }

  @override
  bool shouldRepaint(ContactShadowPainter old) =>
      old.tearId != tearId ||
      !identical(old.mask, mask) ||
      !identical(old.finer, finer) ||
      old._generation != _generation ||
      old.condition != condition ||
      old.opacity != opacity ||
      old.dpr != dpr;
}

/// Contact shadows composed at the size a piece turned out to be, kept so a screenful of notes
/// composes each shape once rather than once a frame — the same bargain [SlicedMasks] makes, for
/// the same reason.
class ContactShadows {
  static final Map<String, ui.Image> _images = {};
  static const int _keep = 24;

  /// Composing the shadow for a sheet four thousand device pixels tall at device resolution would
  /// allocate about twenty megabytes of it, and there is nothing in it that needs the resolution:
  /// the falloff is 1.2 mm wide and the tear's own roughness is a couple of millimetres, so past
  /// this the composition is done smaller and scaled back up on the way to the glass. Unlike
  /// upsampling a render, nothing is lost that was ever measured — the profile is a smooth
  /// function being rasterised, not a photograph being stretched.
  static const int _maxSide = 768;

  /// The resolution each shadow was last composed at, in device pixels, and the spill it was
  /// composed with. `CaptureHooks.paperSurfaces` carries it, so a reader of the sidecar can tell a
  /// shadow that was composed small from one that was not.
  static final Map<String, List<int>> composedAt = {};

  static String composedKey(String asset, Size box, LightCondition condition) =>
      '$asset@${box.width.round()}x${box.height.round()}@${condition.name}';

  /// The falloff laid around [asset]'s outline for a piece of [box] logical pixels.
  ///
  /// Null where the piece is too small to carry a shadow at all, which is not a failure: a piece
  /// one pixel wide has no outline to hug.
  static ui.Image? at(String asset, ui.Image mask, Size box, double dpr,
      LightCondition condition, List<double> profile) {
    final spillPx = ContactShadowPainter.spill * dpr;
    final fullW = box.width * dpr + 2 * spillPx;
    final fullH = box.height * dpr + 2 * spillPx;
    if (fullW < 2 || fullH < 2) return null;
    final shrink = math.min(1.0, _maxSide / math.max(fullW, fullH));
    final w = (fullW * shrink).round().clamp(2, _maxSide);
    final h = (fullH * shrink).round().clamp(2, _maxSide);
    final key = '$asset@${w}x$h@${condition.name}';
    composedAt[composedKey(asset, box, condition)] = [w, h];
    final have = _images[key];
    if (have != null) return have;

    // The outline is the piece's own: the same composition `MaskedLayer` cuts the paper with, so
    // the shadow cannot disagree with the edge it belongs to about where that edge is.
    final outline = SlicedMasks.at(asset, mask, box, dpr);
    final inner = Rect.fromLTWH(
      spillPx * shrink,
      spillPx * shrink,
      box.width * dpr * shrink,
      box.height * dpr * shrink,
    );
    final src = Rect.fromLTWH(0, 0, outline.width.toDouble(), outline.height.toDouble());
    // one step of the profile, in the pixels of this composition
    final step = ShadowFalloff.stepMm * kShadowPerMm * dpr * shrink;

    final recorder = ui.PictureRecorder();
    final bounds = Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());
    final canvas = Canvas(recorder, bounds);
    // Outermost ring first, then inward. Each ring is the outline dilated by its own distance, so
    // the band between two rings ends up carrying the profile's value at the outer of the two —
    // and because the rings are drawn over each other with srcOver rather than replacing, each is
    // asked for the INCREMENT that lands the accumulation on its target. Drawing each ring at its
    // own alpha instead would compound them and the shadow would come out far too dark.
    double covered = 0.0;
    for (var i = profile.length - 1; i >= 0; i--) {
      final target = profile[i];
      if (target <= covered) continue;
      final increment = (target - covered) / (1.0 - covered);
      final radius = i * step;
      final ink = Paint()
        ..filterQuality = FilterQuality.medium
        ..colorFilter = ui.ColorFilter.mode(
            Color.fromRGBO(0, 0, 0, increment.clamp(0.0, 1.0)), BlendMode.srcIn);
      if (radius >= 0.5) {
        canvas.saveLayer(
            bounds, Paint()..imageFilter = ui.ImageFilter.dilate(radiusX: radius, radiusY: radius));
        canvas.drawImageRect(outline, src, inner, ink);
        canvas.restore();
      } else {
        canvas.drawImageRect(outline, src, inner, ink);
      }
      covered = target;
    }
    final image = recorder.endRecording().toImageSync(w, h);
    if (_images.length >= _keep) {
      final oldest = _images.keys.first;
      _images.remove(oldest)?.dispose();
    }
    _images[key] = image;
    return image;
  }
}
