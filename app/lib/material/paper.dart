// A piece of paper on the desk.
//
// The composite, bottom to top: the contact shadow render (alpha only, out of the same Blender
// frame as the piece), then the paper stock cut to shape by a tear mask, then the edge-light
// render that puts the broken fibres back on the torn edge, then whatever is written on it.
// Nothing here is a rounded rectangle with a drop shadow: every layer is a render made under
// blender/rig/common.py, and the masks carry their fibres in their alpha.
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'library.dart';
import 'palette.dart';
import 'light.dart';

/// Decoded masks, kept for the life of the process: a screenful of notes shares a small pool.
class MaskCache {
  static final Map<String, ui.Image> _images = {};
  static final Map<String, Future<ui.Image>> _loading = {};

  static ui.Image? peek(String asset) => _images[asset];

  static Future<ui.Image> load(String asset) {
    final have = _images[asset];
    if (have != null) return Future.value(have);
    return _loading.putIfAbsent(asset, () async {
      final data = await rootBundle.load(asset);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
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
    this.overlays = const [],
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

  static Widget none(BuildContext c, Object e, StackTrace? s) => const SizedBox.shrink();



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
            gaplessPlayback: true,
            errorBuilder: none,
          ),
        ),
      ),
    );
  }

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
          child: Transform.scale(
            scale: stockScale,
            alignment: stockAlignment,
            child: Image.asset(
              paperAsset(stock),
              fit: BoxFit.cover,
              alignment: stockAlignment,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
              errorBuilder: PaperPiece.none,
            ),
          ),
        ),
        if (tearId != null)
          // sliced the same way the mask is, so the lit fibres on the torn edge keep the length
          // they were rendered at however tall the sheet turns out to be
          Positioned.fill(child: NineSliced(asset: tearAsset('${tearId!}_edge'))),
        _WithinTear(safe: safe, padding: padding, child: child ?? const SizedBox.shrink()),
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
        child: SizedBox(
          width: width,
          child: Stack(
            children: [
              // The contact shadow is not drawn here so much as uncovered: it came out of the same
              // render as the piece, already in the right place, already the right shape. All the
              // app does is put it back at the size it was framed at — wider than the piece, because
              // the part of a contact shadow anyone sees is the part the paper is not covering.
              if (tearId != null) _bakedShadow(context, suffix),
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
      }, onError: (Object _) {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mask = _mask;
    if (mask == null) return widget.child;
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (Rect rect) {
        final sliced = SlicedMasks.at(widget.maskAsset, mask, rect.size);
        final m = Matrix4.identity()..translateByDouble(rect.left, rect.top, 0, 1);
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
  static final Map<String, ui.Image> _images = {};
  static const _keep = 64;

  /// How much of a mask, in from each edge, is the torn edge itself rather than the paper inside
  /// it. Measured off the masks: the fibres reach about a fifth of the way in and the middle fifth
  /// is always solid, so four tenths is comfortably outside them.
  static const double edge = 0.4;

  static ui.Image at(String asset, ui.Image mask, Size size) {
    // rounded, so a note whose height moves by a pixel while its text lays out does not compose a
    // new mask every frame
    final w = size.width.round().clamp(1, 4096);
    final h = size.height.round().clamp(1, 4096);
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
    canvas.drawImageNine(
      mask,
      Rect.fromLTRB(mw * edge, mh * edge, mw * (1 - edge), mh * (1 - edge)),
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint()..filterQuality = FilterQuality.medium,
    );
    final image = recorder.endRecording().toImageSync(w, h);
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
