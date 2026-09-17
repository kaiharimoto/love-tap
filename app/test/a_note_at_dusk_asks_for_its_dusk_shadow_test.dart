// A note's contact shadow at dusk is a dusk render, and the app says so out loud.
//
// This test exists because the repository had written down the opposite. A queue item recorded that
// `assets/tears` holds four `*_shadow_dusk.png` and fifty-two without one, concluded that "nothing
// reads a tear's dusk shadow -- the app's _dusk suffix is for paper stocks and the desk plate, and
// no code path looks for one on a tear", and proposed deleting the four.
//
// There is such a code path. `PaperPiece.build` reads `Light.of(context)`, and `_bakedShadow` puts
// the resulting suffix straight into the asset name. Deleting the four would have taken the last
// four dusk contact shadows out of a build that asks for fifty-six of them; rendering the other
// fifty-two is the fix, and this test is what makes that a requirement rather than an opinion.
//
// Nothing else could have caught it. The asset is loaded with `errorBuilder: none`, so a tear whose
// dusk shadow was never rendered draws nothing at all and says nothing about it: at dusk, fifty-two
// of fifty-six notes silently lose their contact shadow while four keep theirs. The library half of
// this is tools/check/dusk_shadows.py; this is the app half, and it is the half that says the
// library is obliged to hold the file.
//
// To re-break it: drop the `$suffix` from paper.dart's `tearAsset('${tearId!}_shadow$suffix')` and
// the dusk case fails, naming the day asset it got instead.
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
    await tester.pump();

    final asked = _assetsAskedFor(tester);
    expect(
      asked,
      contains(tearAsset('tear_001_shadow_dusk')),
      reason: 'the contact shadow under the dusk rig is its own render, not the day one dimmed. '
          'What the tree asked for was: $asked',
    );
    expect(
      asked,
      isNot(contains(tearAsset('tear_001_shadow'))),
      reason: 'and it must not ask for the day shadow as well: the two fall in different '
          'directions, so drawing both puts two lights in one frame',
    );
  });

  testWidgets('and by day it asks for the day one', (tester) async {
    await tester.pumpWidget(_pieceUnder(LightCondition.day));
    await tester.pump();

    final asked = _assetsAskedFor(tester);
    expect(asked, contains(tearAsset('tear_001_shadow')),
        reason: 'the day case is the one that has always worked; it is here so that a change that '
            'makes the dusk case pass by making every case dusk does not go unnoticed. '
            'What the tree asked for was: $asked');
    expect(asked, isNot(contains(tearAsset('tear_001_shadow_dusk'))));
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
