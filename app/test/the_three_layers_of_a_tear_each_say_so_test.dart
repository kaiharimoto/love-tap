// A torn piece of paper is three rendered layers, and all three say so.
//
// The mask, the lit edge and the baked contact shadow have three different geometries and three
// different fixes, and for three cycles only one of them appeared in `evidence/<artifact>
// .surfaces.json`: `CaptureHooks.paperSurfaces` walks the render tree for `RenderImage`, the
// shadow is an `Image.asset`, the edge is a `CustomPaint` and the mask never reaches paint as a
// widget at all. So firing 29's instruction to a successor — "establish which layer makes the
// stepped inner boundary before changing anything" — asked a reader to choose between three
// suspects while the sidecar could see one of them. 183 shadow draws across the committed set,
// and not one edge or mask draw anywhere in it.
//
// Nothing about what is drawn changes. This is the instrument, and this test is what keeps it:
// take the `RenderCustomPaint` branch out of `_collectSurfaces` and the edge layer vanishes from
// the sidecar with every other assertion in the suite still green.
import 'package:desk/capture/hooks.dart';
import 'package:desk/material/library.dart';
import 'package:desk/material/paper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await MaterialLibrary.load();
  });

  testWidgets('the mask, the lit edge and the shadow are all three declared', (tester) async {
    final lib = MaterialLibrary.instance;
    final tear = lib.writableTears.first;
    final stock = lib.stockVariants(lib.stocks.first).first;

    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    // Decode outside the fake-async zone: an image future never completes inside it, and a mask
    // that has not decoded leaves the sheet whole — which is the state that would make this test
    // pass for the wrong reason, because a whole sheet has no mask layer and no edge layer.
    await tester.runAsync(() async {
      await MaskCache.load(tearAsset(tear));
      await MaskCache.load(tearAsset('${tear}_edge'));
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            child: PaperPiece(
              id: 'the_piece_under_test',
              stockId: stock,
              tearId: tear,
              width: 300,
              child: const SizedBox(height: 200),
            ),
          ),
        ),
      ),
    ));
    // Interleaved with real time, so the `Image.asset` layers — the stock and the baked shadow —
    // actually fetch and decode. Inside the fake-async zone their futures never complete, and a
    // piece whose shadow never arrived would declare two layers and look like a pass.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    }
    expect(tester.takeException(), isNull);

    final surfaces = CaptureHooks.paperSurfaces();
    final mine = surfaces.where((s) => s['piece'] == 'the_piece_under_test').toList();
    expect(mine, isNotEmpty, reason: 'the piece declared no surface at all');

    Map<String, dynamic> layer(String fit) => mine.firstWhere(
          (s) => s['fit'] == fit,
          orElse: () => <String, dynamic>{},
        );

    // The contact shadow. It was an `Image.asset` until firing 45 and so had always been declared
    // for free; it is a `CustomPaint` now, and it is asked for by what it IS rather than by the
    // file it used to load, so that a failure here says the pump went wrong rather than that the
    // instrument did.
    final shadow = layer('contact');
    expect(shadow, isNotEmpty,
        reason: 'the contact shadow was not declared, so the piece never painted: $mine');
    expect(shadow['asset'], endsWith('_shadow.webp'),
        reason: 'a contact shadow names the render its profile was measured from, so that '
            'tools/check/tears.py still counts one draw per layer per piece: $shadow');
    expect(shadow['spill'], isA<num>(),
        reason: 'the number this layer turns on is how far it reaches outside the piece, in '
            'device pixels, and a shadow that does not declare it cannot be measured: $shadow');
    expect(shadow['spill'] as num, greaterThan(0),
        reason: 'a contact shadow with no spill is not a contact shadow');

    // The lit edge: the layer firing 29 could not name.
    final edge = layer('nine');
    expect(edge, isNotEmpty,
        reason: 'the lit edge was not declared. It is a CustomPaint, not a RenderImage, so a '
            'reader asking which of the three layers makes a stepped boundary can see two of '
            'the three: $mine');
    expect(edge['asset'], tearAsset('${tear}_edge'));
    expect((edge['src'] as List)[0], isPositive);
    expect((edge['drawn'] as List)[0], isPositive);
    expect(edge['slice'], isA<num>(), reason: 'a nine-slice that does not say where it slices');

    // The mask: the layer that cuts the sheet out, composed offscreen and applied as a shader,
    // and the only one of the three whose working resolution is neither the render's nor the
    // piece's. `composed` is that resolution.
    final mask = layer('mask');
    expect(mask, isNotEmpty,
        reason: 'the tear mask was not declared: $mine');
    expect(mask['asset'], tearAsset(tear));
    expect(mask['composed'], isA<List<Object?>>(),
        reason: 'the mask did not say what resolution its contour is defined at, which is the '
            'one number no screenshot and no other sidecar entry can give');
    final composed = (mask['composed'] as List).cast<int>();
    expect(composed[0], isPositive);
    expect(composed[1], isPositive);

    // And the magnifications are arithmetic rather than decoration, on every layer that reports
    // them: a declaration nobody can check is the failure this whole sidecar exists against.
    for (final s in [edge, mask]) {
      final fixed = (s['fixed'] as List).cast<num>();
      final centre = (s['centre'] as List).cast<num>();
      expect(fixed[0], greaterThan(0),
          reason: '${s['asset']} declares no magnification through its sliced edges');
      expect(centre[0], greaterThanOrEqualTo(0));
      expect(fixed[1], greaterThan(0));
    }

    // The edge layer is drawn straight onto the piece's own canvas, so its sliced edges land at
    // their own size in LOGICAL pixels — and are magnified by the device pixel ratio before
    // anybody sees them, unless the box is narrower than the two of them together and the whole
    // lattice shrinks to fit. Re-derived here from the piece's declared geometry rather than
    // asserted as a constant, because a constant would only say that the number did not change.
    final edgeFixed = (edge['fixed'] as List).cast<num>();
    final edgeSrc = (edge['src'] as List).cast<int>();
    final edgeDrawn = (edge['drawn'] as List).cast<int>();
    const dpr = 3.0;
    final slice = (edge['slice'] as num).toDouble();
    // the edge is packed smaller than the geometry it is laid out at (kEdgeDownsample), so each
    // decoded pixel covers that many laid-out ones, and the sidecar has to say so
    final k = (edge['downsample'] as num).toDouble();
    expect(k, kEdgeDownsample, reason: 'the lit edge does not declare the downsample it is drawn at');
    for (final axis in [0, 1]) {
      final wanted = edgeSrc[axis] * k * 2 * slice;          // logical px the two slices want
      final box = edgeDrawn[axis] / dpr;                     // logical px there are
      final expected = (box < wanted ? box / wanted : 1.0) * dpr * k;
      // `drawn` is rounded to a device pixel, and that rounding is multiplied by k with the rest
      expect(edgeFixed[axis], closeTo(expected, 0.002 * k),
          reason: 'the lit edge declares ${edgeFixed[axis]}x through its sliced edges on axis '
              '$axis, and its own src/drawn/slice say ${expected.toStringAsFixed(3)}x, so the '
              'declaration is decorative rather than arithmetic');
    }
    expect(edgeFixed[1], greaterThan(1.0),
        reason: 'the lit edge is drawn in logical pixels on a 3x screen, so its fibres cannot be '
            'at their own resolution unless the lattice had to shrink on this axis too');

    // ignore: avoid_print
    print('piece: mask ${(mask['src'] as List).join('x')} composed ${composed.join('x')} '
        'fixed ${(mask['fixed'] as List).join(',')} centre ${(mask['centre'] as List).join(',')}; '
        'edge ${(edge['src'] as List).join('x')} fixed ${edgeFixed.join(',')} '
        'centre ${(edge['centre'] as List).join(',')}');
  });
}
