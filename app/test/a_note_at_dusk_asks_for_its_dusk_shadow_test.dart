// A note's contact shadow at dusk is a dusk render, and the app says so out loud.
//
// RE-EXPRESSED AT FIRING 45, REQUIREMENT KEPT, MECHANISM CHANGED. The requirement is the sentence
// above and it has not moved: the shadow under the dusk rig is the dusk renders' own lighting and
// not the day one dimmed, and the app must not use both in one frame. What changed is how the app
// can be asked. `_bakedShadow` used to name `tear_XXX_shadow_dusk` to the bundle, so the question
// was `which assets did the tree ask for`; since firing 45 the shadow is laid procedurally from a
// profile MEASURED off those renders, so nothing asks the bundle for one and that question now
// answers `none` whatever the app does -- which is the shape of failure WORKER_PROMPT 3d is
// written against, a count that falls because the thing left the screen.
//
// So it asks what the app DECLARES instead, which is a stronger anchor than a bundle call: the
// contact shadow surface in `CaptureHooks.paperSurfaces()` carries `render`, the render its
// profile came from. `ShadowFalloff.byTearDusk` is generated from `*_shadow_dusk.webp` and
// `byTearDay` from `*_shadow.webp`, so the two are still two sets of renders and the library is
// still obliged to hold all fifty-six of each -- which is what `tools/check/dusk_shadows.py`
// checks from the other side.
//
// This test exists because the repository had written down the opposite. A queue item recorded that
// `assets/tears` holds four `*_shadow_dusk.png` and fifty-two without one, concluded that "nothing
// reads a tear's dusk shadow -- the app's _dusk suffix is for paper stocks and the desk plate, and
// no code path looks for one on a tear", and proposed deleting the four.
//
// There is such a code path. `PaperPiece.build` reads `Light.of(context)` and hands the condition
// to `_contactShadow`, which is what picks the table. Deleting the four would have taken the last
// four dusk contact shadows out of a build that uses fifty-six of them; rendering the other
// fifty-two was the fix, and this test is what made that a requirement rather than an opinion.
//
// (Firing 44 measured that it has since been done: `assets/tears` holds 56 `*_shadow_dusk.png` and
// `app/assets/tears` 56 `*_shadow_dusk.webp`. The obligation is what keeps it that way.)
//
// Nothing else could have caught it, and that is still true in the new shape. A tear with no dusk
// render falls back to the pooled profile and declares no `render` at all, so it goes quiet rather
// than wrong -- exactly as `errorBuilder: none` used to swallow a missing asset. The library half
// of this is tools/check/dusk_shadows.py; this is the app half, and it is the half that says the
// library is obliged to hold the file.
//
// To re-break it: make paper.dart's `_contactShadow` pass `LightCondition.day` instead of the
// condition it read, and the dusk case fails, naming the day render it got instead.
import 'package:desk/capture/hooks.dart';
import 'package:desk/material/library.dart';
import 'package:desk/material/light.dart';
import 'package:desk/material/paper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every asset name the pumped tree is asking the bundle for.
List<String> _assetsAskedFor(WidgetTester tester) {
  final names = <String>[];
  for (final image in tester.widgetList<Image>(find.byType(Image))) {
    final provider = image.image;
    if (provider is AssetImage) names.add(provider.assetName);
    if (provider is ExactAssetImage) names.add(provider.assetName);
  }
  return names;
}

/// Every render the pumped tree says its contact shadows were measured from.
List<String> _shadowRendersDeclared() => [
      for (final s in CaptureHooks.paperSurfaces())
        if (s['fit'] == 'contact' && s['render'] != null) s['render'] as String,
    ];

Widget _pieceUnder(LightCondition condition) => MaterialApp(
      home: Scaffold(
        body: Light(
          condition: condition,
          child: const Center(
            child: SizedBox(
              width: 260,
              child: PaperPiece(
                stockId: 'lined_01',
                tearId: 'tear_001',
                safe: [0.1, 0.12, 0.06, 0.12],
                child: Text('the lamp is on'),
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await MaterialLibrary.load();
  });

  testWidgets('at dusk a torn note asks for the dusk contact shadow', (tester) async {
    await tester.pumpWidget(_pieceUnder(LightCondition.dusk));
    // the mask decodes off the real bundle, so the shadow has an outline to be laid around
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    }

    final declared = _shadowRendersDeclared();
    expect(
      declared,
      contains('tear_001_shadow_dusk'),
      reason: 'the contact shadow under the dusk rig is its own render, not the day one dimmed. '
          'What the tree declared was: $declared',
    );
    expect(
      declared,
      isNot(contains('tear_001_shadow')),
      reason: 'and it must not use the day shadow as well: the two fall in different '
          'directions, so drawing both puts two lights in one frame',
    );
    // and the stock still answers to the bundle, so a change that stops the dusk rig reaching the
    // piece at all cannot pass this file
    expect(_assetsAskedFor(tester), contains(paperAsset('lined_01_dusk')));
  });

  testWidgets('and by day it asks for the day one', (tester) async {
    await tester.pumpWidget(_pieceUnder(LightCondition.day));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    }

    final declared = _shadowRendersDeclared();
    expect(declared, contains('tear_001_shadow'),
        reason: 'the day case is the one that has always worked; it is here so that a change that '
            'makes the dusk case pass by making every case dusk does not go unnoticed. '
            'What the tree declared was: $declared');
    expect(declared, isNot(contains('tear_001_shadow_dusk')));
  });

  test('the library can be asked whether a render is there, which is the guard nobody calls', () {
    // hasTearRender is the function the app would use to avoid asking for an asset that is not in
    // the library. It is dead code today -- paper.dart names the asset unconditionally and lets
    // errorBuilder swallow the miss -- and it is asserted here so that the guard cannot be quietly
    // deleted as unused while the thing it guards against is still live.
    final lib = MaterialLibrary.instance;
    expect(lib.hasTearRender('tear_001', '_shadow'), isTrue,
        reason: 'tear_001 has a day contact shadow in every build');
    expect(lib.hasTearRender('tear_001', '_no_such_pass'), isFalse);
  });
}
