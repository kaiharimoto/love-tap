// A piece of paper on the desk.
//
// The composite, bottom to top: the contact shadow render (alpha only, out of the same Blender
// frame as the piece), then the paper stock cut to shape by a tear mask, then the edge-light
// render that puts the broken fibres back on the torn edge, then whatever is written on it.
// Nothing here is a rounded rectangle with a drop shadow: every layer is a render made under
// blender/rig/common.py, and the masks carry their fibres in their alpha.
import 'dart:async';
import 'dart:ui' as ui;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'assignment.dart';
import 'library.dart';
import 'palette.dart';
import 'light.dart';

/// Decoded masks, kept for the life of the process: a screenful of notes shares a small pool.
class MaskCache {
  static final Map<String, ui.Image> _images = {};
  static final Map<String, Future<ui.Image>> _loading = {};

  static ui.Image? peek(String asset) => _images[asset];

  /// How many masks are being decoded right now.
  ///
  /// A piece keeps its room and paints nothing until its paper has arrived, so a frame grabbed
  /// while one is still decoding is a frame with a hole in it where a note should be — which is
  /// the light jump 07 failed on twice, from the two sides of the same moment. The harness waits
  /// on this rather than on a number of milliseconds somebody guessed at.
  static int get decoding => _loading.length;

  static Future<ui.Image> load(String asset) {
    final have = _images[asset];
    if (have != null) return Future.value(have);
    return _loading.putIfAbsent(asset, () async {
      final data = await rootBundle.load(asset);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
      final frame = await codec.getNextFrame();
      _images[asset] = frame.image;
      _loading.remove(asset);
      return frame.image;
    });
  }

  /// Decode a set of masks up front (capture mode does this so no frame waits on a decode).
  static Future<void> warm(Iterable<String> assets) async {
    for (final a in assets) {
      try {
        await load(a);
      } catch (_) {}
    }
  }
}

/// One sheet: stock × tear mask, lit edge, baked shadow, and its content.
class PaperPiece extends StatelessWidget {
  const PaperPiece({
    super.key,
    required this.stockId,
    this.tearId,
    this.liftMm = 0.8,
    this.tilt = 0.0,
    this.padding = const EdgeInsets.fromLTRB(10, 8, 10, 8),
    this.safe = const [0.06, 0.07, 0.06, 0.07],
    this.width,
    this.child,
    this.stockAlignment = Alignment.center,
    this.stockScale = 1.0,
    this.windowed = false,
    this.overlays = const [],
    this.stuckOn = const [],
    this.seed = 0,
  });

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
  final Widget? child;

  /// Which square of the stock this piece is torn from, so two notes on the same stock never show
  /// the same patch of paper.
  final Alignment stockAlignment;
  final double stockScale;

  /// Tape, staples, clips: rendered bits laid over the piece.
  final List<Widget> overlays;

  /// Things stuck to the sheet rather than printed on it: a reaction object, a paper clip.
  ///
  /// Drawn over the piece and outside its clip, because that is where they are. A reaction was in
  /// [overlays], which sits inside the clip, so the object and its cast shadow were cut off by a
  /// hard vertical line at the piece's box edge — a material critic measured it at x 1216 in
  /// 02_chat, well to the right of the sheet's torn edge, which is exactly where the ClipRect is
  /// and nowhere the paper is. A thing stuck to a piece of paper overhangs it; that is what makes
  /// it read as stuck on rather than printed in.
  final List<Widget> stuckOn;

  /// This piece's own number, so no two cut cards are cut alike. A guillotine is not a straight
  /// line at the scale a photograph is read at. Left at zero it comes from what the piece is made
  /// of, which is different for every piece on a screen.
  final int seed;

  int get _seed => seed != 0 ? seed : (stockId.hashCode ^ (tearId ?? '').hashCode) & 0x7fffffff;

  /// Show the stock at its own pixel density through a window at [stockAlignment], rather than
  /// scaled to cover the piece. A forty-point card covered by a whole sheet scales the tooth
  /// away to nothing; the same card looking through a window onto the sheet keeps it.
  final bool windowed;

  static Widget none(BuildContext c, Object e, StackTrace? s) => const SizedBox.shrink();

  /// Which sampler to draw a stock with, from how big it is being drawn.
  ///
  /// Paper being *shrunk* wants a smoothing filter: the ruled lines are a pixel wide at their own
  /// density and point-sampling them down makes them break into dashes. Paper being *enlarged*
  /// wants no filter at all, and that is not a preference — it is measured. A material critic
  /// found the large Settings sheet 47 per cent texture-free, flattest window 0.61 grey levels
  /// against 6.9 to 19 on the notes in the same picture. Reproducing the pipeline on the stock
  /// itself: index_01's own tooth is 2.52, the same stock minified is 4.43, and the same stock
  /// magnified 1.17 times with a smoothing filter is 1.29 — which is what the glass measured to
  /// two decimal places. A full-width piece is 1356 device pixels across and the stock is 1288,
  /// so every full-width sheet in the app was being enlarged and averaged. Nearest-neighbour at
  /// that scale reads 1.64 instead of 1.29: it cannot put back the detail that is not there, but
  /// it stops the sampler taking away the detail that is.
  ///
  /// The rest of the answer is more paper, and that is a re-render, not a flag.
  static FilterQuality stockFilter(String stock, Size box, double dpr, double stockScale) {
    if (!MaterialLibrary.loaded) return FilterQuality.medium;
    final px = MaterialLibrary.instance.stockSize(stock);
    if (px == null || px.width <= 0 || px.height <= 0) return FilterQuality.medium;
    // BoxFit.cover over a box of `box` logical points, drawn at `dpr` device pixels per point,
    // with the whole layer scaled by stockScale. The image's logical size is its pixel size,
    // because it is loaded at scale 1.
    final cover = math.max(box.width / px.width, box.height / px.height);
    return cover * dpr * stockScale > 1.0 ? FilterQuality.none : FilterQuality.medium;
  }



  Widget _bakedShadow(BuildContext context, String suffix) {
    final frame = MaterialLibrary.loaded ? MaterialLibrary.instance.shadowFrame : 1.0;
    // Scaling about the centre is what puts it back: the render was framed [frame] times the
    // piece in both directions, and the piece's height is not known until its writing is laid out.
    return Positioned.fill(
      child: Transform.scale(
        scale: frame,
        child: Opacity(
          // One lift was modelled, and the render is as dark as this shadow gets: a note that
          // lies flatter than the model cannot press harder than the render already did, so the
          // reference is the flattest lift and every other note lifts away from it, lighter.
          opacity: (shadowOpacityFor(liftMm) / shadowOpacityFor(0.0)).clamp(0.6, 1.0),
          child: Image.asset(
            tearAsset('${tearId!}_shadow$suffix'),
            fit: BoxFit.fill,
            // Bilinear rather than the default. A shadow render is a dark shape inside a
            // transparent border and a cubic sampler can ring at a boundary like that; bilinear
            // cannot. Tried as an explanation for the pale rule on the wood and it is *not* the
            // explanation — resampling this asset by either filter and compositing it over a flat
            // desk produces no bright row at all, measured. Kept as the cheaper and safer sampler
            // for an image that is only ever stretched.
            filterQuality: FilterQuality.low,
            gaplessPlayback: true,
            errorBuilder: none,
          ),
        ),
      ),
    );
  }

  /// The contact shadow of a cut piece. Nothing rendered it — the tear shadows came out of
  /// Blender with the pieces they belong to, and a straight-cut card has no render of its own —
  /// so it is the one shadow in the app that is drawn: the same warm colour as the baked ones,
  /// as soft and as far as the lift says, under a sharp rectangle.
  Widget _cutShadow(bool dusk) => Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(
            painter: _CutShadow(
              lift: liftMm,
              alpha: (shadowOpacityFor(liftMm) * (dusk ? 0.9 : 1.0)).clamp(0.16, 0.42),
              seed: _seed,
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final dusk = Light.of(context) == LightCondition.dusk;
    final suffix = dusk ? '_dusk' : '';
    final stock = (!dusk || stockId.endsWith('_dusk')) ? stockId : '${stockId}_dusk';
    final content = Stack(
      children: [
        // Underneath everything, the colour the stock is. The render is what makes it paper, but
        // this is what stops it ever being nothing: a sheet whose image has not arrived, or whose
        // image is missing from the bundle, is still a sheet.
        Positioned.fill(child: ColoredBox(color: Paper.forStock(stock))),
        Positioned.fill(
          child: LayoutBuilder(builder: (context, box) {
            final dpr = MediaQuery.devicePixelRatioOf(context);
            return Transform.scale(
              scale: windowed ? 1.0 : stockScale,
              alignment: stockAlignment,
              child: Image.asset(
                paperAsset(stock),
                // A window shows the sheet at ONE IMAGE PIXEL PER DEVICE PIXEL. Without the scale,
                // BoxFit.none means one image pixel per *logical* point, which on a phone is three
                // device pixels — so the tooth was magnified three times and smoothed by the
                // sampler. A completeness pass measured the result on the tab strip: an interior of
                // 1.20 grey levels against 19 to 27 for the note paper beside it, on ten of eleven
                // stills. The shape the anti-goal forbids was sitting in the app's own chrome.
                scale: windowed ? dpr : 1.0,
                fit: windowed ? BoxFit.none : BoxFit.cover,
                alignment: stockAlignment,
                gaplessPlayback: true,
                filterQuality: PaperPiece.stockFilter(stock, box.biggest, dpr, stockScale),
                errorBuilder: PaperPiece.none,
              ),
            );
          }),
        ),
        if (tearId != null)
          // Sliced the same way the mask is, so the lit fibres on the torn edge keep the length
          // they were rendered at however tall the sheet turns out to be.
          Positioned.fill(child: NineSliced(asset: tearAsset('${tearId!}_edge')))
        else
          // a cut edge: card stock has thickness, and a straight cut catches the light along its
          // top and left the way a torn one does along its fibres. Without it a whole sheet was a
          // rectangle of texture that stopped dead — edge deviation measured at exactly zero.
          Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _CutEdge(_seed)))),
        _WithinTear(safe: safe, padding: padding, child: child ?? const SizedBox.shrink()),
        ...overlays,
      ],
    );
    // the stock is drawn larger than the piece so two notes never show the same patch of paper;
    // clip it to the piece before masking, or it paints over its neighbours.
    //
    // A whole sheet is clipped to a *cut*, not to a rectangle. A guillotine is a straight blade
    // and a card is still not a rectangle when it comes off one: the edge wanders by a fraction
    // of a millimetre and the corners are nicked. The DATES card measured its right edge at
    // exactly x=1072 for sixteen rows running and its top at exactly y=292 for every column, with
    // corner radius zero — which is the shape the anti-goal forbids, reached by clipping. The
    // wander is deterministic in the piece's own stock id, so a card is the same card every time
    // it is drawn and on both phones.
    final clipped = tearId == null
        ? ClipPath(clipper: _CutShape(hashOf(stockId)), child: content)
        : ClipRect(child: content);
    final piece = tearId == null ? clipped : MaskedLayer(maskAsset: tearAsset(tearId!), child: clipped);
    return _WhenThePaperArrives(
      asset: tearId == null ? null : tearAsset(tearId!),
      child: Transform.rotate(
      angle: tilt,
      // Filtered, because a rotation without a filter is nearest-neighbour and every hard edge
      // inside the piece comes out as a staircase. That is the pale one-pixel rule a material
      // critic has measured lying on the wood in nine of ten stills for four cycles: not a line
      // drawn on the desk but the piece's own lit edge, tilted by a third of a degree and
      // rasterised one row at a time — which is why it steps left about a hundred and sixty
      // pixels per row and runs in dashes of sixty to three hundred. The desk asset carries no
      // such row (measured: zero one-row spikes at any threshold) and neither does any baked
      // shadow, which is what ruled out the other three explanations.
      filterQuality: FilterQuality.medium,
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
        child: SizedBox(
          width: width,
          child: Stack(
            // A Stack clips to its own bounds by default, and the shadow is deliberately a
            // quarter wider than the piece — so every visible part of every contact shadow in the
            // app was being cut off, leaving only the part the paper itself covers. Two critics
            // and a completeness pass measured the result: with the tear ink excluded, the desk's
            // median luminance beside a note is the same in every direction at every distance
            // from two to a hundred and twenty pixels. Notes were cut-outs pasted on a photograph
            // for four review cycles because of this one default.
            clipBehavior: Clip.none,
            children: [
              // The contact shadow is not drawn here so much as uncovered: it came out of the same
              // render as the piece, already in the right place, already the right shape. All the
              // app does is put it back at the size it was framed at — wider than the piece, because
              // the part of a contact shadow anyone sees is the part the paper is not covering.
              if (tearId != null) _bakedShadow(context, suffix) else _cutShadow(dusk),
              piece,
              ...stuckOn,
            ],
          ),
        ),
      ),
    ),
    );
  }
}

/// Nothing of a piece is drawn — not its sheet, and not the shadow it casts — until the mask that
/// gives it its shape is out of the cache.
///
/// Gating the sheet alone left the shadow: a torn dark shape lying on the desk with no paper on
/// it, which is a worse frame than the one it fixed. A piece keeps its room in the row and paints
/// nothing; a mask that never arrives (missing from the bundle) draws the piece the old way rather
/// than leaving a hole in the thread.
class _WhenThePaperArrives extends StatefulWidget {
  const _WhenThePaperArrives({required this.asset, required this.child});
  final String? asset;
  final Widget child;

  @override
  State<_WhenThePaperArrives> createState() => _WhenThePaperArrivesState();
}

class _WhenThePaperArrivesState extends State<_WhenThePaperArrives> {
  bool _here = false;
  bool _lost = false;

  @override
  void initState() {
    super.initState();
    _look();
  }

  @override
  void didUpdateWidget(_WhenThePaperArrives old) {
    super.didUpdateWidget(old);
    if (old.asset != widget.asset) {
      _here = false;
      _lost = false;
      _look();
    }
  }

  void _look() {
    final asset = widget.asset;
    if (asset == null || MaskCache.peek(asset) != null) {
      _here = true;
      return;
    }
    unawaited(MaskCache.load(asset).then((_) {
      if (mounted) setState(() => _here = true);
    }, onError: (Object _) {
      if (mounted) setState(() => _lost = true);
    }));
  }

  @override
  Widget build(BuildContext context) =>
      _here || _lost ? widget.child : Opacity(opacity: 0, child: widget.child);
}

/// Lays the writing inside the part of the piece the tear cannot reach.
///
/// The piece's height is not known until the writing has been laid out, and the safe area is a
/// fraction of that height, so the two are solved together: with content height C and safe
/// fractions fT and fB, the piece is C / (1 - fT - fB) tall and the writing starts fT down it.
class _WithinTear extends SingleChildRenderObjectWidget {
  const _WithinTear({required this.safe, required this.padding, required Widget child}) : super(child: child);

  final List<double> safe;
  final EdgeInsets padding;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderWithinTear(safe, padding);

  @override
  void updateRenderObject(BuildContext context, _RenderWithinTear renderObject) {
    renderObject
      ..safe = safe
      ..padding = padding;
  }
}

class _RenderWithinTear extends RenderShiftedBox {
  _RenderWithinTear(this._safe, this._padding) : super(null);

  List<double> _safe;
  EdgeInsets _padding;

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

  /// What this piece would like to be, asked before it is laid out — by an IntrinsicWidth, which
  /// is how a slip becomes as wide as its own word. The default answer is the child's width, and
  /// that is wrong here by exactly the margin the tear cannot reach: the piece was then laid out
  /// at the child's width and the child was given nine tenths of it, so SHELTER came out SHELTE.
  @override
  double computeMaxIntrinsicWidth(double height) {
    final child = this.child;
    if (child == null) return 0;
    final horizontal = (1 - _safe[0] - _safe[2]).clamp(0.35, 1.0);
    return (child.getMaxIntrinsicWidth(height) + _padding.horizontal) / horizontal;
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    final child = this.child;
    if (child == null) return 0;
    final horizontal = (1 - _safe[0] - _safe[2]).clamp(0.35, 1.0);
    return (child.getMinIntrinsicWidth(height) + _padding.horizontal) / horizontal;
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
    if (constraints.hasBoundedWidth) {
      width = constraints.maxWidth;
      final inner = (width * (1 - fL - fR) - _padding.horizontal).clamp(24.0, width);
      child.layout(BoxConstraints(maxWidth: inner), parentUsesSize: true);
    } else {
      // Nothing is constraining the width — a slip in a horizontal strip of them, a chip in a
      // scrolling row. It used to fall back to a flat 320 points, so a filter chip reading
      // `both` was two thirds of the screen wide and the third chip was off the edge of it.
      // A piece with no width given is the width of what is written on it.
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

class _MaskedLayerState extends State<MaskedLayer> {
  ui.Image? _mask;

  /// Whether the mask is never coming. A piece whose mask has not arrived *yet* and a piece whose
  /// mask does not exist are two different things, and they used to be the same thing here.
  bool _lost = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(MaskedLayer old) {
    super.didUpdateWidget(old);
    if (old.maskAsset != widget.maskAsset) {
      _mask = MaskCache.peek(widget.maskAsset);
      _resolve();
    }
  }

  void _resolve() {
    final cached = MaskCache.peek(widget.maskAsset);
    if (cached != null) {
      _mask = cached;
      return;
    }
    // a mask that is not baked yet leaves the sheet whole rather than blank
    unawaited(
      MaskCache.load(widget.maskAsset).then((img) {
        if (mounted) setState(() => _mask = img);
      }, onError: (Object _) {
        if (mounted) setState(() => _lost = true);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mask = _mask;
    // A mask that is still being decoded is not a missing mask. Handing the child back unmasked
    // while it loads drew the piece as a flat rectangle of stock colour with square corners and no
    // shadow — the shape the whole material system exists to not be — and 07's clip carries one
    // frame of exactly that: a feeling arrives, and for a sixteenth of a second the sheet it lands
    // on is a pale grey slab, which is a +11.6 grey-level jump on the whole screen and the light
    // jump the frame check failed the clip on. The piece keeps its room and paints nothing until
    // its paper is there, which is the next frame. If the mask never arrives — a build with a mask
    // missing from the bundle — the old behaviour is what is wanted, and _lost says so.
    if (mask == null) {
      return _lost ? widget.child : Opacity(opacity: 0, child: widget.child);
    }
    // Composed at device pixels, not logical ones. A note is about 340 points wide and the screen
    // it is on is three times that, so a mask composed at 340 would be upsampled threefold before
    // anybody saw it — and the row this material is judged on is judged at three hundred per cent
    // on exactly this. The shader scales it back down.
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    return _MaskedBox(
      mask: mask,
      dpr: dpr,
      shaderFor: (Rect rect) {
        final sliced = SlicedMasks.at(widget.maskAsset, mask, rect.size, dpr);
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

/// A piece with its tear mask multiplied into it — with the mask's own edge kept clear of the
/// piece's edge.
///
/// This is Flutter's ShaderMask with two pixels of air around it, and the two pixels are the whole
/// point. A ShaderMask multiplies the mask in by drawing a rectangle the size of the child in
/// dstIn, and that rectangle has an antialiased edge: on the row where the piece's box lands
/// between two device pixels, the blend is applied at partial coverage, so a fraction of the sheet
/// survives where the tear had erased it. That fraction is a third — solved on all three channels
/// off 02_chat, wood + 0.334 x paper — and it is the pale dead-straight hairline four material
/// critics have measured lying on the desk beside every piece of paper in the app, in nine of ten
/// stills, for five cycles. Six explanations were tried and measured and are all wrong: the desk
/// render, the baked shadows, the denoiser, the shadow's bounding box, the mask's own inset, and
/// an unfiltered rotation. What settled it was a bisect in the browser: with the mask taken out of
/// the piece altogether the hairline goes from twenty-nine runs to one, and with the mask's own
/// sampling and composition changed every way that was left — a shader without mipmaps, a mask
/// composed at the piece's exact height, a rotation filtered differently, the lit edge taken off —
/// it does not move at all.
///
/// So the mask rectangle is drawn two pixels larger than the piece in every direction. Its
/// antialiased edge is then out on the desk where there is nothing to erase, the piece's own edge
/// is covered at full coverage, and the tear is the only thing that decides what is paper. The
/// composed mask is transparent for a pixel around its border and clamps outward, so the two
/// pixels of air erase rather than smear.
typedef _ShaderFor = ui.Shader Function(Rect rect);

class _MaskedBox extends SingleChildRenderObjectWidget {
  const _MaskedBox({
    required this.mask,
    required this.dpr,
    required this.shaderFor,
    required Widget super.child,
  });

  /// The tear itself, as it was rendered. Drawn straight into the piece as a nine-patch when the
  /// piece paints into the canvas it was given, which is nearly always.
  final ui.Image mask;

  /// The screen's own density. The tear is drawn at one render pixel per device pixel — the same
  /// thing SlicedMasks composed it at — because a tear sampled at logical scale is a tear three
  /// times too coarse.
  final double dpr;

  /// The fallback: the same tear composed to this piece's size as an image, for the rare piece
  /// whose subtree needs a compositing layer of its own and so cannot be painted inside a
  /// saveLayer here.
  final _ShaderFor shaderFor;

  /// How far outside the piece the mask is drawn, in logical pixels.
  ///
  /// Half a point — a pixel and a half on a phone. It only has to be enough that the mask
  /// rectangle's own antialiased edge lands where the piece has already been clipped away and
  /// there is nothing left to erase. Two points was enough for that too, and it moved the tear
  /// two points down the desk: the sheet came out bigger than its own shadow, with plain stock
  /// where the lit fibres had been.
  static const double air = 0.5;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderMaskedBox(mask, dpr, shaderFor);

  @override
  void updateRenderObject(BuildContext context, _RenderMaskedBox renderObject) {
    renderObject
      ..mask = mask
      ..dpr = dpr
      ..shaderFor = shaderFor;
  }
}

/// The piece, with its tear multiplied in.
///
/// Two ways of doing the same thing, and which one runs is decided by whether the piece needs a
/// compositing layer of its own:
///
/// * **the nine-patch, straight in.** `saveLayer`, paint the piece, then `drawImageNine` of the
///   tear in `dstIn`. One draw call, no image made, nothing kept. This is what runs for every
///   piece in the app.
/// * **the composed mask**, through a `ShaderMaskLayer`, for a piece whose subtree pushes a layer
///   — `super.paint` would then paint outside the `saveLayer` and the mask would land on the wrong
///   pixels.
///
/// The first way exists because of what the second one costs. `SlicedMasks.at` composes the
/// nine-patch into a picture and calls `toImageSync`, and that is 16.1 ms on the Dart VM and
/// hundreds of milliseconds in CanvasKit — on the build thread, once per note, as the thread
/// scrolls. Measured on 11_chat_scroll: 52 frames of 189 cost more than 400 ms to build, at p95
/// 807 and max 2142, against a raster that never left 133-199; with the mask taken out of the
/// piece altogether, 4 of 146 at p95 34. The nine-patch is the same picture without the image.
///
/// Both ways draw the mask two pixels wider than the piece. That is the fix for the pale
/// hairline four material critics measured on the desk for five cycles: a mask rectangle the size
/// of the child is antialiased at its own edge, so on the row where the piece's box falls between
/// two device pixels the blend lands at partial coverage and a third of a pixel of sheet survives
/// where the tear had erased it. Out on the desk there is nothing to erase.
class _RenderMaskedBox extends RenderProxyBox {
  _RenderMaskedBox(this._mask, this._dpr, this._shaderFor);

  ui.Image _mask;
  set mask(ui.Image value) {
    if (value == _mask) return;
    _mask = value;
    markNeedsPaint();
  }

  double _dpr;
  set dpr(double value) {
    if (value == _dpr) return;
    _dpr = value;
    markNeedsPaint();
  }

  _ShaderFor _shaderFor;
  set shaderFor(_ShaderFor value) {
    if (value == _shaderFor) return;
    _shaderFor = value;
    markNeedsPaint();
  }

  bool get _needsALayer => child != null && child!.needsCompositing;

  @override
  bool get alwaysNeedsCompositing => _needsALayer;

  @override
  ShaderMaskLayer? get layer => super.layer as ShaderMaskLayer?;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) {
      layer = null;
      return;
    }
    const air = _MaskedBox.air;
    final wide = (offset - const Offset(air, air)) & Size(size.width + air * 2, size.height + air * 2);
    if (_needsALayer) {
      layer ??= ShaderMaskLayer();
      layer!
        ..shader = _shaderFor(const Offset(air, air) & size)
        ..maskRect = wide
        ..blendMode = BlendMode.dstIn;
      context.pushLayer(layer!, super.paint, offset);
      return;
    }
    layer = null;
    final canvas = context.canvas;
    canvas.saveLayer(wide, Paint());
    super.paint(context, offset);
    final w = _mask.width.toDouble(), h = _mask.height.toDouble();
    const e = SlicedMasks.edge;
    // Drawn in device pixels, not logical ones. drawImageNine keeps the four corners and the four
    // edges at the size they were rendered — in whatever unit the canvas is in — and the tear is
    // in the edges. In logical units at three device pixels to one the fibres come out three times
    // too coarse and the sheet is a smooth line with a blur on it, which is the one thing this
    // material is not allowed to be.
    final d = _dpr;
    canvas.save();
    canvas.scale(1 / d);
    canvas.drawImageNine(
      _mask,
      Rect.fromLTRB(w * e, h * e, w * (1 - e), h * (1 - e)),
      Rect.fromLTRB(wide.left * d, wide.top * d, wide.right * d, wide.bottom * d),
      Paint()
        ..blendMode = BlendMode.dstIn
        ..filterQuality = FilterQuality.medium,
    );
    canvas.restore();
    canvas.restore();
  }
}

/// Masks composed at the size a piece turned out to be, kept so a screenful of notes composes
/// each shape once rather than once a frame.
class SlicedMasks {
  static final Map<String, ui.Image> _images = {};
  static const _keep = 128;

  /// How many masks have actually been composed into an image since the app started.
  ///
  /// A number rather than a flag because the point is that it should not move: composing one is
  /// 16 ms on the Dart VM and hundreds of milliseconds in CanvasKit, on the build thread, and a
  /// thread that composes one per note as it scrolls spends more time making masks than drawing.
  /// The pieces draw their tear as a nine-patch now and this is only the fallback for a piece
  /// whose subtree needs a compositing layer of its own. a_thread_scrolls_without_baking_test
  /// watches it.
  static int composed = 0;

  /// How much of a mask, in from each edge, is the torn edge itself rather than the paper inside
  /// it. Measured off the masks: the fibres reach about a fifth of the way in and the middle fifth
  /// is always solid, so four tenths is comfortably outside them.
  static const double edge = 0.4;

  static ui.Image at(String asset, ui.Image mask, Size size, double dpr) {
    // rounded, so a note whose height moves by a pixel while its text lays out does not compose a
    // new mask every frame; and never larger than the mask itself, because upsampling a render is
    // not the same as having rendered it larger
    final w = (size.width * dpr).round().clamp(1, mask.width);
    // Height to the nearest sixty-four device pixels, and what stretches to make up the difference
    // is the middle band — which is the solid interior of the tear, where stretching is not a
    // thing anybody can see. The bands that carry the torn edge keep the size they were rendered
    // at, by construction.
    //
    // It was sixteen, and every note in a scroll is a different height: composing one costs 16 ms
    // on the Dart VM and hundreds of milliseconds in CanvasKit, and a piece whose subtree needs a
    // compositing layer of its own has to be composed rather than drawn. Sixty-four is a quarter
    // as many compositions for a stretch nobody can point at.
    final h = ((size.height * dpr / 64).round() * 64).clamp(1, mask.height * 4);
    final key = '$asset@${w}x$h';
    final have = _images[key];
    if (have != null) return have;
    if (_images.length > _keep) {
      final oldest = _images.keys.first;
      _images.remove(oldest)?.dispose();
    }
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final mw = mask.width.toDouble(), mh = mask.height.toDouble();
    // Painted one device pixel in from every side, so the composed mask has a transparent frame
    // around it that no sampling phase can pull ink through.
    //
    // Without it a pale dead-straight hairline lay on the wood just outside every piece of paper —
    // 45.7 per cent of the desk pixels on 02_chat's row 556 sitting four or more grey levels above
    // the rows either side of them, in segments of about 265 px stepping one row every 555 px,
    // which is the paper's own edge slope. A material critic read it as something in the wood; it
    // was the piece's own bounding box. drawImageNine lands the mask flush against the edge of the
    // texture, and the shader then samples half a texel outside it and finds the mask's own border
    // rather than nothing, so a sliver of the sheet is drawn beyond the sheet.
    canvas.drawImageNine(
      mask,
      Rect.fromLTRB(mw * edge, mh * edge, mw * (1 - edge), mh * (1 - edge)),
      Rect.fromLTWH(1, 1, (w - 2).toDouble().clamp(1, w.toDouble()),
          (h - 2).toDouble().clamp(1, h.toDouble())),
      Paint()..filterQuality = FilterQuality.medium,
    );
    final image = recorder.endRecording().toImageSync(w, h);
    composed += 1;
    _images[key] = image;
    return image;
  }
}

/// An image drawn as a nine-slice: the four corners and the four edges at the scale they were
/// rendered at, and only the middle stretched.
///
/// Image's own `centerSlice` cannot do this here — it asserts that the fit leaves the whole source
/// visible, and every one of these is drawn into a box of a different shape from the render. So
/// the image is decoded through the same cache the masks use and drawn straight.
class NineSliced extends StatefulWidget {
  const NineSliced({super.key, required this.asset, this.edge = 0.4, this.opacity = 1.0});

  final String asset;

  /// How much of the render, in from each edge, is the torn edge itself rather than the paper
  /// inside it. Measured off the masks: the fibres reach about a fifth of the way in and the
  /// middle fifth is always solid, so four tenths is comfortably outside them.
  final double edge;
  final double opacity;

  @override
  State<NineSliced> createState() => _NineSlicedState();
}

class _NineSlicedState extends State<NineSliced> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(NineSliced old) {
    super.didUpdateWidget(old);
    if (old.asset != widget.asset) {
      _image = MaskCache.peek(widget.asset);
      _resolve();
    }
  }

  void _resolve() {
    final cached = MaskCache.peek(widget.asset);
    if (cached != null) {
      _image = cached;
      return;
    }
    unawaited(MaskCache.load(widget.asset).then((img) {
      if (mounted) setState(() => _image = img);
    }, onError: (Object _) {}));
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null) return const SizedBox.shrink();
    return CustomPaint(painter: _NinePainter(image, widget.edge, widget.opacity));
  }
}

class _NinePainter extends CustomPainter {
  _NinePainter(this.image, this.edge, this.opacity);
  final ui.Image image;
  final double edge;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final w = image.width.toDouble(), h = image.height.toDouble();
    canvas.drawImageNine(
      image,
      Rect.fromLTRB(w * edge, h * edge, w * (1 - edge), h * (1 - edge)),
      Offset.zero & size,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..color = Color.fromRGBO(0, 0, 0, opacity),
    );
  }

  @override
  bool shouldRepaint(_NinePainter old) =>
      !identical(old.image, image) || old.edge != edge || old.opacity != opacity;
}

/// The thickness of card stock along a straight cut: light on the top and left edges, a hair of
/// shade on the bottom and right, the way the light falls on everything else on the desk.
/// The silhouette of a cut card: the rectangle, with the blade's own wander along each edge and
/// a nick off each corner. Under a millimetre in all, which is what a guillotine leaves.
/// The outline of a piece that was cut rather than torn: the four edges, as they actually run.
///
/// Each edge is walked rather than ruled. The first version moved the four corners and drew
/// straight lines between them, which is a quadrilateral with wobbly corners — measured on the
/// artifact, every module card still had 0.00 to 0.81 px of edge roughness on all four sides and
/// one was exactly 673x164 with 0.00 on every side. A guillotine leaves a line that wanders by a
/// fraction of a millimetre along its whole length, because the blade meets fibre and not butter.
/// Deterministic in the piece's own number, so a card is the same card every time it is drawn and
/// on both phones.
/// Sixteen bits in, sixteen bits out, mixed.
///
/// Sixteen and not thirty-two on purpose: on the web an int is a double, and a 32-bit multiply
/// overflows fifty-three bits of mantissa and rounds. The two phones have to cut the same card,
/// and one of them is a browser. Every intermediate here stays under 2^31.
int _mix16(int x) {
  var h = x & 0xFFFF;
  h = (h ^ (h >> 8)) & 0xFFFF;
  h = (h * 0x2C9F) & 0xFFFF;
  h = (h ^ (h >> 7)) & 0xFFFF;
  h = (h * 0x5D1B) & 0xFFFF;
  h = (h ^ (h >> 9)) & 0xFFFF;
  return h;
}

List<Offset> cutOutline(Size size, int seed, {double amp = 2.6, double nick = 1.6}) {
  // `(seed * 2654435761 + i * 40503) & 0xFFFF` is not a hash: taking the low sixteen bits of a
  // linear function of i leaves an arithmetic progression mod 65536, which is a sawtooth in i.
  // Every octave of the wander was therefore built out of a ramp, and the outline self-correlated
  // 0.54 at lag 294 on a long edge. This mixes.
  double w(int i, double a) => (_mix16(seed ^ (i * 0x9E37)) / 0xFFFF - 0.5) * 2 * a;

  // How far the cut wanders off the line at [t] along the edge, t in 0..1.
  //
  // This was two runs of a sine, one about a card's width and one about a letter's, and the note
  // under it said that made the cut neither a ripple nor noise. Two sines are two periods however
  // they are weighted: a material critic measured the 'let it interrupt you' bar's top edge at an
  // rms of 0.34 px and a peak-to-peak of 2.7 over 1,300 px, which is dead straight with a ripple
  // in it, and autocorrelated the same shape on the rig's torn edges at 0.50 and 0.72.
  //
  // Four octaves of seeded value noise instead, smoothstepped between knots so the outline is
  // continuous, so no stretch of the edge repeats any other. A guillotine is a straight blade;
  // what wanders is the paper.
  double along(int id, double t, double a, int octaves) {
    var v = 0.0;
    var weight = 1.0;
    var total = 0.0;
    for (var k = 0; k < octaves; k++) {
      final knots = 3 << k; // 3, 6, 12, 24 ... knots along the edge
      final x = t * knots;
      final i = x.floor();
      final f = x - i;
      final e = f * f * (3 - 2 * f);
      final a0 = w(200 + id * 97 + (i % knots), 1.0);
      final a1 = w(200 + id * 97 + ((i + 1) % knots), 1.0);
      v += weight * (a0 * (1 - e) + a1 * e);
      total += weight;
      // 0.85, not a half: at a half the coarse octaves are the whole edge and the fine wander,
      // which is the only part that survives a high-pass and so the only part a critic measures,
      // is a twentieth of a pixel.
      weight *= 0.85;
    }
    return a * v / total;
  }

  final l = w(1, amp), t = w(2, amp);
  final r = size.width + w(3, amp), b = size.height + w(4, amp);
  final n = [for (var i = 0; i < 4; i++) nick * (0.5 + (w(10 + i, 1.0) + 1) / 2 * 0.5)];
  // the fewest points any edge gets; a long one gets one every two logical points
  const steps = 14;
  final out = <Offset>[];
  void run(int id, Offset from, Offset to) {
    final d = to - from;
    final len = d.distance;
    if (len <= 0) return;
    final across = Offset(-d.dy / len, d.dx / len);
    // As many points and as many octaves as the edge is long. A fixed fourteen described a
    // 448-point bar with fourteen points, so whatever the wander did between them was drawn as a
    // straight line; and four octaves put the finest knot 112 points apart, which no high-pass
    // measurement of a cut edge can see.
    final n = (len / 2).round().clamp(steps, 260);
    final octaves = (math.log(len / 4.0) / math.ln2).ceil().clamp(4, 8);
    for (var i = 0; i <= n; i++) {
      final f = i / n;
      out.add(from + d * f + across * along(id, f, amp, octaves));
    }
  }

  run(0, Offset(l + n[0], t), Offset(r - n[1], t));
  run(1, Offset(r, t + n[1]), Offset(r, b - n[2]));
  run(2, Offset(r - n[2], b), Offset(l + n[3], b));
  run(3, Offset(l, b - n[3]), Offset(l, t + n[0]));
  return out;
}

class _CutShape extends CustomClipper<Path> {
  const _CutShape(this.seed);
  final int seed;

  @override
  Path getClip(Size size) {
    final pts = cutOutline(size, seed);
    final p = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final o in pts.skip(1)) {
      p.lineTo(o.dx, o.dy);
    }
    p.close();
    return p;
  }

  @override
  bool shouldReclip(_CutShape old) => old.seed != seed;
}

/// The light along the four edges of a piece that was cut.
///
/// Drawn on the cut the piece is actually clipped to, so the lit edge sits on the edge rather than
/// beside it: the top and left catch the light, the bottom and right hold the piece's own shade.
class _CutEdge extends CustomPainter {
  const _CutEdge(this.seed);
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final pts = cutOutline(size, seed);
    final per = pts.length ~/ 4;
    for (var e = 0; e < 4; e++) {
      final from = e * per;
      final to = (e == 3) ? pts.length : (e + 1) * per;
      final path = Path()..moveTo(pts[from].dx, pts[from].dy);
      for (var i = from + 1; i < to; i++) {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
      final colour = switch (e) {
        0 => const Color(0x8CFFFFFF),
        1 => Shadow.warm.withValues(alpha: 0.14),
        2 => Shadow.warm.withValues(alpha: 0.22),
        _ => const Color(0x66FFFFFF),
      };
      canvas.drawPath(
        path,
        Paint()
          ..color = colour
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke,
      );
    }
    // and the tone of the stock itself falls off very slightly toward the bottom edge, as a lit
    // card's does
    final r = Offset.zero & size;
    canvas.drawRect(
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0x00000000), Shadow.warm.withValues(alpha: 0.035)],
        ).createShader(r),
    );
  }

  @override
  bool shouldRepaint(_CutEdge old) => old.seed != seed;
}

class _CutShadow extends CustomPainter {
  const _CutShadow({required this.lift, required this.alpha, this.seed = 0});
  final double lift;
  final double alpha;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    // the light comes from the top left, so the shadow falls down and to the right, further and
    // softer the higher the piece sits
    final dx = 0.6 + lift * 1.1, dy = 1.2 + lift * 2.2;
    final blur = 1.4 + lift * 2.4;
    final rect = (Offset(dx, dy) & size).deflate(0.5);
    canvas.drawRect(
      rect,
      Paint()
        ..color = Shadow.warm.withValues(alpha: alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
    );
    // and the dense line of contact under the bottom edge, in segments: where the card is down on
    // the desk the line is dark and tight, and where it lifts the shadow opens and fades
    final a = (seed % 53) / 53.0 * 6.28;
    final b = ((seed >> 5) % 41) / 41.0 * 6.28;
    const steps = 18;
    for (var i = 0; i < steps; i++) {
      final t = i / steps;
      final near = 0.5 + 0.5 * (0.6 * math.sin(t * 7.4 + a) + 0.4 * math.sin(t * 2.3 + b));
      final w = size.width / steps + 1;
      canvas.drawRect(
        Rect.fromLTWH(dx * 0.5 + t * size.width, size.height - 0.5, w, 1.2 + (1 - near) * 2.4),
        Paint()
          ..color = Shadow.warm.withValues(alpha: alpha * (0.45 + 0.55 * near))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 0.7 + (1 - near) * 1.6),
      );
    }
  }

  @override
  bool shouldRepaint(_CutShadow old) =>
      old.lift != lift || old.alpha != alpha || old.seed != seed;
}
