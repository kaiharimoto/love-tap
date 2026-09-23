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
import '../material/desk.dart';
import '../material/fold.dart';
import '../material/library.dart';
import '../material/paper.dart';
import '../regions/chat/blob_widgets.dart';
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

  /// The other phone starts or stops writing.
  Future<String> partnerTyping(bool on) async {
    final f = CaptureBus.partnerTyping;
    if (f == null) return 'no shell';
    f(on);
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

  /// Move the settings page by [dy] logical pixels, once, so a scene can reach the interrupt
  /// matrix at the bottom of it.
  Future<String> settingsScrollBy(double dy) async {
    final f = CaptureBus.settingsScrollBy;
    if (f == null) return 'settings is not on screen';
    f(dy);
    await _settle();
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
      // What the screen is still waiting for. `__deskReady` means a frame was painted, not
      // that the pictures arrived; this is the difference, and it is written into every
      // scene log so a still taken over an unfilled grid can never again be read as a still
      // of a grid that does not fill.
      'blobs_pending': BlobCache.outstanding,
      // And what is still not ON THE GLASS, which is a different number and is the one the
      // shutter actually needs. See [picturesPending].
      'pictures_pending': picturesPending(),
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
  /// Only what is painted. A subtree the framework does not put on the glass -- a zero opacity, an
  /// `Offstage`, the four regions of the `IndexedStack` that are built and not shown -- is not
  /// declared, because a declaration is permission to measure those pixels, and pixels where a
  /// hidden paragraph would be are somebody else's. See [_painted].
  ///
  /// What is still NOT claimed is that a declared run is legible, or even that there is ink in it.
  /// A paragraph behind another sheet is painted and declared and contributes nothing, because the
  /// tool intersects this with the marks it finds. Declaring is permission to measure, not an
  /// assertion that there is something to measure.
  ///
  /// Static, like `DrivenClock.step`, because it reads the framework rather than the app: it needs
  /// no spine, no transport and no library, and a test of it should not have to stand one up.
  /// How many pictures the screen has asked for and has not got on the glass yet: a painted
  /// `RenderImage` that is laid out with a real size and whose `image` is still null.
  ///
  /// **This is the number `blobs_pending` was believed to be, and is not.** [BlobCache.outstanding]
  /// counts READS -- how many blobs the store has been asked for and has not answered. A read
  /// coming back is bytes arriving in Dart, and bytes arriving is not a picture: `Image.memory`
  /// then has to decode them, which is a second asynchronous step that nothing was counting. The
  /// two numbers differ by exactly one frame plus a decode, and the shutter fits in that gap.
  ///
  /// It fitted in it on firing 39's capture and nothing said so. `evidence/logs/04_moments.json`
  /// records `waited_ms 6969, pending_at_shot 0` and the report says `blobs_pending 0`, so the
  /// harness believed the gallery had filled. Three of its tiles are blank index card in the PNG
  /// -- the paper's own rules run straight through the photograph's box, which is what paper
  /// showing through a picture that is not there looks like. And `04_moments.surfaces.json`, which
  /// `scene.js` collects AFTER the screenshot, declares a decoded 375x500 image in every one of
  /// those boxes: between the shutter and the sidecar, the three pictures arrived.
  ///
  /// So the artifact and the sidecar disagreed about the same frame and no gate could see it. The
  /// harness waited for the reads, which were done, and photographed the screen one decode early.
  ///
  /// A blob that resolves to nothing is NOT counted here and must not be: [BlobImage] draws
  /// `S.pictureNotHere` in words for that case, and words are a `RenderParagraph`. So a picture
  /// this phone does not have says so and the shutter goes; only a picture that is on its way
  /// holds it, and it holds it on the same budget [BlobCache.outstanding] is held on.
  static int picturesPending() {
    var waiting = 0;
    void walk(RenderObject node) {
      if (node is RenderImage &&
          node.image == null &&
          node.hasSize &&
          !node.size.isEmpty) {
        waiting++;
      }
      node.visitChildren((child) {
        if (_painted(node, child)) walk(child);
      });
    }
    for (final view in RendererBinding.instance.renderViews) {
      walk(view);
    }
    return waiting;
  }

  /// Every rendered surface the app put on the glass, with the size of the render it came from
  /// and the size it was drawn at.
  ///
  /// This exists because three cycles of review argued about a flat cream rectangle from the
  /// outside and got it wrong twice. `10_first_run`, `17_setup_pwa` and the bare part of
  /// `01_pulse` measure as one RGB value over a large fraction of the frame, which is the named
  /// failure of the whole visual concept, and the two diagnoses made from the pixels alone were
  /// that a stock render was missing and then that the `ColoredBox` fallback in
  /// `material/paper.dart` was showing through. Both were wrong. A build with that fallback set
  /// to magenta put no magenta pixel anywhere in the frame: every sheet, the flat one included,
  /// has its render over it.
  ///
  /// What no screenshot can say is how big that render was and how big it was drawn. A sheet
  /// magnified past its own resolution has its tooth resampled away, and the result is a flat
  /// fill that looks exactly like a missing asset. So the app says it, at the moment of the shot,
  /// the way it already says where its words are.
  ///
  /// `scale` is the magnification: the drawn size in device pixels over the render's own pixels,
  /// on the axis `fit` actually scales by. Above 1.0 the app is showing paper it does not have.
  ///
  /// Painted-ness is decided by [_painted], exactly as it is for the text runs, so an offstage
  /// region's four screens of paper are not declared.
  ///
  /// **A torn piece is three layers and until firing 44 this could see one of them.** The walk is
  /// for `RenderImage`, so the baked contact shadow — an `Image.asset` — appeared in every sidecar
  /// in the set, 183 draws across it, while the tear mask (composed offscreen and applied as a
  /// shader) and the lit edge (a `CustomPaint`) appeared nowhere. The three have three different
  /// geometries and three different fixes, so firing 29's instruction to establish which of them
  /// makes the stepped inner boundary on `17_setup_pwa` before changing anything asked a reader
  /// to choose between three suspects from a sidecar that could see one. Both now declare
  /// themselves, with the numbers their own geometry turns on:
  ///
  /// * `fit: nine` — the lit edge. `fixed` and `centre` are how far it magnifies what it draws,
  ///   in device pixels per source pixel, through the sliced edges and through the stretched
  ///   middle. It draws onto the piece's own canvas, so its slices land at their own size in
  ///   *logical* pixels and the device pixel ratio multiplies them.
  /// * `fit: mask` — the tear mask. `composed` is the resolution its contour is actually defined
  ///   at, which is neither the render's size nor the piece's: `SlicedMasks.at` clamps the
  ///   composition to the mask's own width and four times its height. `fixed` and `centre` carry
  ///   both magnifications multiplied together, so the two nine-sliced layers of one piece are
  ///   directly comparable.
  ///
  /// * `fit: contact` — the contact shadow. It stopped being an `Image.asset` at firing 45, so
  ///   it would have dropped out of every sidecar in the set exactly as the other two had been
  ///   missing from it; `spill` is how far it reaches outside the piece in device pixels, which
  ///   is the number `the-tear-shadow-is-stretched-six-to-one-and-becomes-a-hard-bar` is about,
  ///   and `render` is the render its profile was measured from.
  ///
  /// Nothing about what is drawn changed when the first two were added.
  static List<Map<String, dynamic>> paperSurfaces() {
    // The asset name lives on the widget and the size lives on the render object, so the element
    // tree is walked once to pair them up and the render tree is walked after, where the paint
    // order and the visibility rules already are.
    final names = <RenderObject, String>{};
    // And which piece of paper each image belongs to, where the piece has a name. An asset path
    // says what stock a surface is torn from and nothing about what it *is*: `12_search.png` drew
    // nineteen surfaces on `index_01` and `index_02`, of which one was the query slip and twelve
    // were facet tabs, and no reader of the sidecar could tell them apart. A measurement that
    // cannot name the object it is about is the failure WORKER_PROMPT 3d is written against, so
    // the piece says its own id and the sidecar carries it.
    final pieces = <RenderObject, String>{};
    void pair(Element el, String? piece) {
      final w = el.widget;
      if (w is PaperPiece && w.id != null) piece = w.id;
      final provider = w is Image ? w.image : null;
      if (provider is AssetImage) {
        // `el.renderObject` is the nearest render object at or under the element, and for an
        // `Image` that is its `Semantics` wrapper rather than the `RenderImage` -- so the name
        // was landing on a key nothing else ever looked up, and every surface came back with an
        // empty asset. Descend to the image itself.
        final ro = _imageUnder(el);
        if (ro != null) {
          names[ro] = provider.assetName;
          if (piece != null) pieces[ro] = piece;
        }
      }
      // The three layers that are not `RenderImage` and so were invisible to every sidecar in
      // the set. The lit edge and the contact shadow carry what they need on their painters; the
      // mask does not reach paint as a widget at all, so its asset is keyed onto the
      // `RenderShaderMask` that applies it. All three want the piece id for the same reason the
      // images do -- a surface that cannot name the object it is about is WORKER_PROMPT 3d's
      // failure, and this item's clause (c) counts pieces, not draws.
      if (w is NineSliced || w is ContactShadow) {
        final ro = _under<RenderCustomPaint>(el);
        if (ro != null && piece != null) pieces[ro] = piece;
      }
      if (w is MaskedLayer) {
        final ro = _under<RenderShaderMask>(el);
        if (ro != null) {
          names[ro] = w.maskAsset;
          if (piece != null) pieces[ro] = piece;
        }
      }
      final owner = piece;
      el.visitChildren((child) => pair(child, owner));
    }
    WidgetsBinding.instance.rootElement?.visitChildren((el) => pair(el, null));

    final out = <Map<String, dynamic>>[];
    for (final view in RendererBinding.instance.renderViews) {
      _collectSurfaces(view, view, view.flutterView.devicePixelRatio, names, pieces, out);
    }
    return out;
  }

  /// The `RenderImage` an `Image` element eventually paints with, past whatever it is wrapped in.
  static RenderImage? _imageUnder(Element el) => _under<RenderImage>(el);

  /// The first render object of type [T] at or under [el].
  ///
  /// An element's `renderObject` is the nearest one at or *under* it, which for an `Image` is its
  /// `Semantics` wrapper and for a `NineSliced` is whatever its state built this frame. So the
  /// walk down is the general case and every caller needs it.
  static T? _under<T extends RenderObject>(Element el) {
    final ro = el.renderObject;
    if (ro is T) return ro;
    T? found;
    void down(RenderObject node) {
      if (found != null) return;
      if (node is T) {
        found = node;
        return;
      }
      node.visitChildren(down);
    }
    if (ro != null) down(ro);
    return found;
  }

  static void _collectSurfaces(RenderObject node, RenderView view, double dpr,
      Map<RenderObject, String> names, Map<RenderObject, String> pieces,
      List<Map<String, dynamic>> out) {
    if (node is RenderImage) {
      final img = node.image;
      if (img != null && node.hasSize && node.size.width > 0 && node.size.height > 0) {
        final box = node.size;
        final sx = box.width * dpr / img.width;
        final sy = box.height * dpr / img.height;
        // cover and fill both stretch to the box; cover takes the larger of the two so the box is
        // filled, fill takes each axis separately and the larger one is what shows first.
        final scale = sx > sy ? sx : sy;
        final rect = MatrixUtils.transformRect(node.getTransformTo(view), Offset.zero & box);
        out.add({
          'asset': names[node] ?? '',
          'src': [img.width, img.height],
          'drawn': [(box.width * dpr).round(), (box.height * dpr).round()],
          'scale': double.parse(scale.toStringAsFixed(3)),
          'fit': node.fit?.name ?? '',
          'rect': [rect.left.round(), rect.top.round(), rect.width.round(), rect.height.round()],
          if (pieces[node] != null) 'piece': pieces[node],
        });
      }
    }
    // The lit edge: a `CustomPaint`, drawn with `drawImageNine` straight onto the piece's canvas,
    // so its sliced edges land at their own size in LOGICAL pixels and are magnified by the
    // device pixel ratio before anybody sees them. `fixed` and `centre` say so in device pixels
    // per source pixel, which is the unit the mask's entry below reports in too, so the two
    // nine-sliced layers of one piece can be compared against each other.
    if (node is RenderCustomPaint) {
      final painter = node.painter;
      if (painter is NinePainter && node.hasSize && !node.size.isEmpty) {
        final box = node.size;
        final img = painter.image;
        final fx = _nineScale(img.width.toDouble(), box.width, painter.edge);
        final fy = _nineScale(img.height.toDouble(), box.height, painter.edge);
        final scale = fx[0] * dpr > fy[0] * dpr ? fx[0] * dpr : fy[0] * dpr;
        final rect = MatrixUtils.transformRect(node.getTransformTo(view), Offset.zero & box);
        out.add({
          'asset': painter.asset,
          'src': [img.width, img.height],
          'drawn': [(box.width * dpr).round(), (box.height * dpr).round()],
          'scale': double.parse(scale.toStringAsFixed(3)),
          'fit': 'nine',
          'slice': painter.edge,
          'fixed': [
            double.parse((fx[0] * dpr).toStringAsFixed(3)),
            double.parse((fy[0] * dpr).toStringAsFixed(3)),
          ],
          'centre': [
            double.parse((fx[1] * dpr).toStringAsFixed(3)),
            double.parse((fy[1] * dpr).toStringAsFixed(3)),
          ],
          'rect': [rect.left.round(), rect.top.round(), rect.width.round(), rect.height.round()],
          if (pieces[node] != null) 'piece': pieces[node],
        });
      }
    }
    // The contact shadow: no longer a render drawn into the piece's box, so no longer a
    // `RenderImage` the walk sees for free. `spill` is the number this item turns on -- how far
    // the shadow reaches outside the piece, in device pixels. It is a PHYSICAL width, the same on
    // a margin strip and on a full sheet, where before firing 45 it was a tenth of the piece on
    // each side and so 11 px on a strip and 97 px on a note. `render` is where the profile was
    // measured, which is what says the dusk rig's shadow is its own lighting rather than the day
    // one dimmed.
    if (node is RenderCustomPaint) {
      final painter = node.painter;
      if (painter is ContactShadowPainter && node.hasSize && !node.size.isEmpty) {
        final box = node.size;
        final img = painter.mask;
        final composed = ContactShadows.composedAt[
            ContactShadows.composedKey(painter.asset, box, painter.condition)];
        final rect = MatrixUtils.transformRect(node.getTransformTo(view), Offset.zero & box);
        final spill = ContactShadowPainter.spill * dpr;
        out.add({
          'asset': painter.render == null
              ? painter.asset
              : 'assets/tears/${painter.render}.webp',
          'src': [img.width, img.height],
          'composed': ?composed,
          'drawn': [(box.width * dpr).round(), (box.height * dpr).round()],
          'scale': 1.0,
          'fit': 'contact',
          'spill': double.parse(spill.toStringAsFixed(3)),
          'profile': painter.profile.length,
          'condition': painter.condition.name,
          'render': ?painter.render,
          'rect': [rect.left.round(), rect.top.round(), rect.width.round(), rect.height.round()],
          if (pieces[node] != null) 'piece': pieces[node],
        });
      }
    }
    // The tear mask: nine-sliced into an offscreen image at device pixels and then applied as a
    // shader, so it is magnified TWICE — once by whatever `SlicedMasks.at` had to clamp the
    // composition to, and once by the shader stretching that composition over the piece.
    // `composed` is the resolution the torn contour is actually defined at; `fixed` and `centre`
    // are the two magnifications multiplied together, in device pixels per source pixel.
    if (node is RenderShaderMask && names[node] != null && node.hasSize && !node.size.isEmpty) {
      final asset = names[node]!;
      final mask = MaskCache.peek(asset);
      final composed = SlicedMasks.composedAt[SlicedMasks.composedKey(asset, node.size)];
      if (mask != null && composed != null) {
        final box = node.size;
        // per axis since firing 51: the fixed band gives way on a piece much larger than its mask
        final ex = SlicedMasks.sliceFor(mask.width.toDouble(), composed[0].toDouble());
        final ey = SlicedMasks.sliceFor(mask.height.toDouble(), composed[1].toDouble());
        final fx = _nineScale(mask.width.toDouble(), composed[0].toDouble(), ex);
        final fy = _nineScale(mask.height.toDouble(), composed[1].toDouble(), ey);
        // and then the shader, which stretches the whole composition over the piece
        final sx = box.width * dpr / composed[0];
        final sy = box.height * dpr / composed[1];
        final scale = sx > sy ? sx : sy;
        final rect = MatrixUtils.transformRect(node.getTransformTo(view), Offset.zero & box);
        out.add({
          'asset': asset,
          'src': [mask.width, mask.height],
          'composed': composed,
          'drawn': [(box.width * dpr).round(), (box.height * dpr).round()],
          'scale': double.parse(scale.toStringAsFixed(3)),
          'fit': 'mask',
          'slice': [ex, ey],
          'fixed': [
            double.parse((fx[0] * sx).toStringAsFixed(3)),
            double.parse((fy[0] * sy).toStringAsFixed(3)),
          ],
          'centre': [
            double.parse((fx[1] * sx).toStringAsFixed(3)),
            double.parse((fy[1] * sy).toStringAsFixed(3)),
          ],
          'rect': [rect.left.round(), rect.top.round(), rect.width.round(), rect.height.round()],
          if (pieces[node] != null) 'piece': pieces[node],
        });
      }
    }
    node.visitChildren((child) {
      if (_painted(node, child)) _collectSurfaces(child, view, dpr, names, pieces, out);
    });
  }

  /// How far a nine-slice magnifies what it draws on one axis: `[through the sliced edges,
  /// through the stretched middle]`, in destination units per source pixel.
  ///
  /// The two sliced edges are drawn at their own size, which is why a nine-slice keeps its fibres
  /// — unless the box is narrower than the two of them together, and then the whole lattice is
  /// shrunk proportionally and there is no middle left at all. Everything downstream of the draw
  /// (a device pixel ratio, a shader stretching the result again) is the caller's to multiply in.
  static List<double> _nineScale(double src, double dst, double edge) {
    final fixed = src * 2 * edge;
    final shrink = fixed <= 0 ? 1.0 : (dst < fixed ? dst / fixed : 1.0);
    final middleSrc = src * (1 - 2 * edge);
    final middleDst = dst - fixed * shrink;
    if (middleSrc <= 0 || middleDst <= 0) return [shrink, 0.0];
    return [shrink, middleDst / middleSrc];
  }

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
    // Paint order first: anything already collected that this surface covers was painted before
    // it and is not on the glass. [_hideUnder] explains why this is a separate question from
    // `paintsChild`, and `OpaqueSurface` in material/desk.dart explains why the app has to answer
    // it rather than the framework.
    if (node is RenderOpaqueSurface) _hideUnder(node, view, bounds, out);
    if (node is RenderParagraph) _paragraph(node, view, dpr, bounds, out);
    // Visited even for a paragraph: a RenderParagraph can carry inline widget children, and one
    // of those can be another paragraph.
    node.visitChildren((child) {
      if (_painted(node, child)) _collectRuns(child, view, dpr, bounds, out);
    });
  }

  /// Whether [parent] actually puts [child] on the glass, rather than merely having built it.
  ///
  /// This is not a nicety. `app.dart` keeps all five regions alive in an `IndexedStack` and shows
  /// one, so the render tree carries five screens' worth of writing at any moment, laid out at
  /// plausible positions on top of each other. Measured on `02_chat`, walking every child declared
  /// 233 lines of which 127 overlapped another by more than half, and `wake me`, `quietly` and
  /// `not at all` each appeared fourteen times over. Declaring those would hand the tool
  /// permission to read pixels where a hidden paragraph *would* be, which is the one way this
  /// could let a piece of surface back in wearing a line of text's rect.
  ///
  /// `paintsChild` is the framework's own answer and covers the general cases: a zero opacity, an
  /// `Offstage`, an invisible `Visibility`, a list child kept alive but scrolled out of the
  /// viewport. `RenderIndexedStack` is the exception that does not implement it -- it paints one
  /// child and says so nowhere but in its own `paintStack` -- so it is asked directly.
  static bool _painted(RenderObject parent, RenderObject child) {
    if (!parent.paintsChild(child)) return false;
    if (parent is RenderIndexedStack) return identical(child, _shownChildOf(parent));
    return true;
  }

  /// Drop every run already collected that [surface] completely covers.
  ///
  /// `visitChildren` is paint order -- a `Stack`'s children are visited in the order they are
  /// painted, and the `Navigator`'s overlay hands its entries over bottom first -- so everything
  /// in [out] when this runs was painted before this surface and is behind it.
  ///
  /// `_painted` cannot reach this case. It asks the framework whether a parent paints a child,
  /// and the answer is yes for both routes under a stacked one: the overlay lays its offstage
  /// entries out and declines to paint them without overriding `paintsChild` to say so. This is
  /// the same shape as the `RenderIndexedStack` exception and one level further out.
  ///
  /// Only a run entirely inside the surface is dropped. A paragraph that is half covered is
  /// still partly on the glass, and the pixels it names are still partly its own; declaring it
  /// is the honest answer and the tool intersects it with the marks it finds. This errs toward
  /// declaring, which is the direction that costs a false failure rather than a missed one, and
  /// is the direction to err in only because the alternative -- guessing at a partial cover --
  /// would hand the tool permission to stop looking at real text.
  static void _hideUnder(
      RenderBox surface, RenderView view, Rect bounds, List<Map<String, dynamic>> out) {
    if (out.isEmpty || !surface.attached || !surface.hasSize || surface.size.isEmpty) return;
    final cover = MatrixUtils
        .transformRect(surface.getTransformTo(view), Offset.zero & surface.size)
        .intersect(bounds);
    if (cover.isEmpty) return;
    // A pixel of slack at the edges, because a declared rect is rounded outward by `_px` and a
    // sheet that covers the view exactly would otherwise fail to cover a run at its own edge.
    final c = cover.inflate(1.0);
    out.removeWhere((run) {
      final r = (run['rect'] as List).cast<int>();
      return c.left <= r[0] && c.top <= r[1] &&
          c.right >= r[0] + r[2] && c.bottom >= r[1] + r[3];
    });
  }

  static RenderBox? _shownChildOf(RenderIndexedStack stack) {
    final at = stack.index;
    if (at == null || at < 0) return null;
    var child = stack.firstChild;
    for (var i = 0; child != null && i < at; i++) {
      child = stack.childAfter(child);
    }
    return child;
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

    // Where this paragraph is actually allowed to put ink: every clip between it and the view,
    // intersected, and not merely the edge of the frame.
    //
    // `bounds` was standing in for that, and a scrollable's last child is laid out past the end of
    // its viewport and clipped there rather than moved. So a note half under the end of the thread
    // declared the whole of its box, and `scene.js` -- which clamps a declared rect into the frame
    // -- turned what was left into a run inside the picture. `02_chat` declared a message two
    // pixels tall at y=3118 of a 3120-pixel frame, in a band where the tab strip is drawn and that
    // message is not; `05_settings` and `17_setup_pwa` each declared two lines across the strip
    // the same way. The tool then reads pixels inside a rect where the app draws nothing, and the
    // sidecar's `offscreen: 0` is true only because nothing was ever fully outside.
    final clip = _paintClip(p, view, bounds);
    if (clip.isEmpty) return;
    final Matrix4 toView = p.getTransformTo(view);
    Rect? box(Rect local) {
      final r = MatrixUtils.transformRect(toView, local).intersect(clip);
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

  /// The rectangle [node] may paint in, in the view's pixels: [bounds] narrowed by every clip its
  /// ancestors impose. `describeApproximatePaintClip` is the framework's own answer for one
  /// parent -- a viewport, a `ClipRect`, a `ClipPath`'s bounding box -- and null from a parent
  /// that clips nothing, which is most of them.
  static Rect _paintClip(RenderObject node, RenderView view, Rect bounds) {
    var out = bounds;
    RenderObject child = node;
    var parent = child.parent;
    while (parent != null) {
      final local = parent.describeApproximatePaintClip(child);
      if (local != null) {
        out = out.intersect(MatrixUtils.transformRect(parent.getTransformTo(view), local));
        if (out.isEmpty) return Rect.zero;
      }
      child = parent;
      parent = child.parent;
    }
    return out;
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
      await DrivenClock.step(const Duration(milliseconds: 16));
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

  /// The period of one frame of a clip assembled at [fps], as an exact duration.
  ///
  /// A clip is a directory of frames handed to ffmpeg at a frame rate, and the clock has to
  /// advance by exactly that frame's worth of time between one shot and the next or the recording
  /// is not of the app at the times it claims. Sixty frames a second is 16.667 ms and not 16, and
  /// the 4% those two differ by is not a rounding detail: a sequence indexed at 60 fps falls one
  /// frame behind every 400 ms, so the shot at that moment catches the frame before it again.
  /// That is the whole of 06_unfolding.mp4's mid-motion stall -- one repeat every twenty-five
  /// frames, at recorded frames 44, 94, 144, 169, 244, 269 -- and it is why this takes a Duration
  /// rather than a whole number of milliseconds.
  static Duration period(double fps) => Duration(microseconds: (1000000 / fps).round());

  /// Advance by [by] and let the framework produce exactly one frame.
  static Future<void> step(Duration by) async {
    _now += by;
    if (_ticks.hasListener) _ticks.add(_now);
    final done = Completer<void>();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!done.isCompleted) done.complete();
    });
    SchedulerBinding.instance.scheduleFrame();
    await done.future.timeout(const Duration(seconds: 2), onTimeout: () {});
  }
}
