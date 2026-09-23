// A feeling object under the dusk rig is its dusk render, not the day one set under the lamp.
//
// THE DEFECT THIS IS THE RULER FOR. blender/objects/objects.py skipped the object pass at dusk, so
// the library had a dusk SHADOW for every object and no dusk BODY for any. The app asked for
// `${id}_shadow_dusk` under the lamp and for `${id}` either way, so every feeling at dusk was lit by
// the day rig's sun and put down on a sheet lit by a 2700 K lamp from the other side
// (`the-feeling-objects-are-sprites-composited-over-the-scene`). Firing 51 rendered the 25 dusk
// bodies and made the body ask for its own light the way the shadow already did.
//
// RE-BREAK: make `bodyOf` return `id` unconditionally. The dusk case then asks for the day body
// and the first test fails on every object. The population clause means removing the dusk
// bodies from the bundle fails it too, instead of quietly falling back to day.

import 'package:desk/feelings/builtins.dart';
import 'package:desk/material/library.dart';
import 'package:desk/material/light.dart';
import 'package:desk/material/objects.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

List<String> _assetsAskedFor(WidgetTester tester) => [
      for (final image in tester.widgetList<Image>(find.byType(Image)))
        if (image.image is AssetImage) (image.image as AssetImage).assetName,
    ];

Widget _objectUnder(LightCondition condition, Feeling f) => MaterialApp(
      home: Scaffold(
        body: Light(
          condition: condition,
          child: Center(child: FeelingObject(feeling: f, size: 128, onPaper: false)),
        ),
      ),
    );

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await MaterialLibrary.load();
  });

  test('every object the library offers has a dusk body, and is not offered twice', () {
    final lib = MaterialLibrary.instance;
    final ids = lib.objectIds;
    expect(ids.length, 25, reason: 'the population the dusk bodies are counted against moved: $ids');
    expect(ids.where((id) => id.endsWith('_dusk')), isEmpty,
        reason: 'a dusk body is the same object under the lamp, not another one to choose');
    final missing = [for (final id in ids) if (!lib.hasObjectDuskBody(id)) id];
    expect(missing, isEmpty, reason: 'these objects are still drawn by day under the lamp');
    for (final id in ids) {
      expect(bodyOf(id, dusk: true), '${id}_dusk');
      expect(bodyOf(id, dusk: false), id);
    }
  });

  testWidgets('at dusk the clover asks for its dusk body and not the day one', (tester) async {
    final clover = kBuiltInFeelings.firstWhere((f) => f.object == 'obj_clover');
    await tester.pumpWidget(_objectUnder(LightCondition.dusk, clover));
    final asked = _assetsAskedFor(tester);
    expect(asked, contains(objectAsset('obj_clover_dusk')), reason: 'asked for: $asked');
    expect(asked, isNot(contains(objectAsset('obj_clover'))),
        reason: 'the day body under the lamp is two lights in one frame');
    expect(asked, contains(objectAsset('obj_clover_shadow_dusk')));
  });

  testWidgets('and by day it asks for the day body', (tester) async {
    final clover = kBuiltInFeelings.firstWhere((f) => f.object == 'obj_clover');
    await tester.pumpWidget(_objectUnder(LightCondition.day, clover));
    final asked = _assetsAskedFor(tester);
    expect(asked, contains(objectAsset('obj_clover')));
    expect(asked, isNot(contains(objectAsset('obj_clover_dusk'))));
  });
}
