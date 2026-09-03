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

  @override
  Widget build(BuildContext context) {
    final dusk = Light.of(context) == LightCondition.dusk;
    final suffix = dusk ? '_dusk' : '';
    final stock = (!dusk || stockId.endsWith('_dusk')) ? stockId : '${stockId}_dusk';
    final content = Stack(
      children: [
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
              errorBuilder: (c, e, s) => const ColoredBox(color: Color(0xFFF1ECDF)),
            ),
          ),
        ),
        if (tearId != null)
          Positioned.fill(
            child: Image.asset(tearAsset('${tearId!}_edge'),
                fit: BoxFit.fill, gaplessPlayback: true, filterQuality: FilterQuality.medium, errorBuilder: none),
          ),
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
      child: SizedBox(
        width: width,
        child: Stack(
          children: [
            if (tearId != null)
              Positioned.fill(
                child: Transform.translate(
                  offset: shadowOffsetFor(liftMm),
                  child: Opacity(
                    opacity: shadowOpacityFor(liftMm),
                    child: Image.asset(tearAsset('${tearId!}_shadow$suffix'),
                        fit: BoxFit.fill, gaplessPlayback: true, errorBuilder: none),
                  ),
                ),
              ),
            piece,
          ],
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
    final width = constraints.hasBoundedWidth ? constraints.maxWidth : 320.0;
    final fL = _safe[0], fT = _safe[1], fR = _safe[2], fB = _safe[3];
    final child = this.child;
    if (child == null) {
      size = constraints.constrain(Size(width, 0));
      return;
    }
    final inner = (width * (1 - fL - fR) - _padding.horizontal).clamp(24.0, width);
    child.layout(BoxConstraints(maxWidth: inner), parentUsesSize: true);
    final content = child.size.height + _padding.vertical;
    final vertical = (1 - fT - fB).clamp(0.35, 1.0);
    final height = content / vertical;
    size = constraints.constrain(Size(width, height));
    (child.parentData! as BoxParentData).offset =
        Offset(width * fL + _padding.left, size.height * fT + _padding.top);
  }
}

/// Applies a mask image's alpha to its child. The masks are packed as white with the paper in
/// their alpha channel, so `dstIn` against an image shader keeps exactly the paper, fibres and all.
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
    unawaited(MaskCache.load(widget.maskAsset).then(
      (img) {
        if (mounted) setState(() => _mask = img);
      },
      onError: (Object _) {},
    ));
  }

  @override
  Widget build(BuildContext context) {
    final mask = _mask;
    if (mask == null) return widget.child;
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (Rect rect) {
        final m = Matrix4.identity()
          ..translateByDouble(rect.left, rect.top, 0, 1)
          ..scaleByDouble(rect.width / mask.width, rect.height / mask.height, 1, 1);
        return ImageShader(mask, TileMode.clamp, TileMode.clamp, m.storage,
            filterQuality: FilterQuality.medium);
      },
      child: widget.child,
    );
  }
}
