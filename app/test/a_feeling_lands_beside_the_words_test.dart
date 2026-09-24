// An arriving feeling comes to rest beside the writing on the glass, not on top of it.
//
// The landing target was fixed -- a third of the way across, half way down -- so the thing landed
// on whatever was there. The cycle 3 critic watched 08's arriving `hold` park over the partner card
// and hide HAS LEFT, and a `squeeze` land on the `hold` caption so that it read `h..d`. Now the spot
// is chosen against the painted paragraphs under the stage when the feeling is let go.
//
// Anchored to the words, found by what they say (`find.text`), and to the object the app draws
// (`FeelingObject`), never to a coordinate: the card is put exactly where the old fixed target
// would have dropped the thing, computed from the same function the stage uses.
//
// Re-break: make `landingSpot` return `want` unmoved, and `it does not cover the card` fails.
import 'dart:async';

import 'package:desk/feelings/builtins.dart';
import 'package:desk/feelings/landing.dart';
import 'package:desk/material/assignment.dart';
import 'package:desk/material/library.dart';
import 'package:desk/material/objects.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String? absent;
  const stage = Size(360, 780);

  setUpAll(() async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    for (final channel in const [
      MethodChannel('xyz.luan/audioplayers'),
      MethodChannel('xyz.luan/audioplayers.global'),
    ]) {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async => null);
    }
    try {
      await MaterialLibrary.load();
    } catch (_) {
      absent = 'this bundle was packed without a material library '
          '(tools/pack_assets.py --seed=year puts it in)';
    }
  });

  final feeling = kBuiltInFeelings.first;
  const intensity = 0.8;
  final seed = (hashOf(feeling.id) & 0xffff) / 0xffff;
  // Where the fixed target put theirs, on a desk with nothing on it.
  final old = preferredSpot(stage, mine: false, seed: seed);

  Future<(Rect, List<Rect>)> land(WidgetTester tester) async {
    tester.view.physicalSize = stage * 3.0;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    final arrivals = StreamController<Arrival>.broadcast();
    addTearDown(arrivals.close);
    await tester.pumpWidget(MaterialApp(
      home: LandingStage(
        arrivals: arrivals.stream,
        child: Stack(children: [
          // The partner card, centred on the old target.
          Positioned(
            left: old.dx - 90,
            top: old.dy - 24,
            width: 180,
            height: 48,
            child: const Center(child: Text('HAS LEFT', style: TextStyle(fontSize: 28))),
          ),
          // And a thread caption just under it.
          Positioned(
            left: old.dx - 60,
            top: old.dy + 40,
            child: const Text('hold', style: TextStyle(fontSize: 24)),
          ),
        ]),
      ),
    ));
    await tester.pump();
    arrivals.add(Arrival(feeling: feeling, intensity: intensity, mine: false));
    await tester.pump();
    // Let it fall, bounce and come to rest, but not fade.
    var t = 0;
    while (t < (Fall.totalSeconds * 1000).ceil()) {
      await tester.pump(const Duration(milliseconds: 50));
      t += 50;
    }
    final object = tester.getRect(find.byType(FeelingObject));
    final words = [
      tester.getRect(find.text('HAS LEFT')),
      tester.getRect(find.text('hold')),
    ];
    return (object, words);
  }

  testWidgets('it does not cover the card or the caption', (tester) async {
    if (absent != null) return markTestSkipped(absent!);
    final (object, words) = await land(tester);
    // POPULATION: the scenario is one where the old target would have covered both.
    final oldSquare =
        Rect.fromCenter(center: old, width: objectSide(intensity), height: objectSide(intensity));
    for (final w in words) {
      expect(oldSquare.overlaps(w), isTrue, reason: 'the old target has to be over the words');
    }
    for (final w in words) {
      expect(object.overlaps(w), isFalse,
          reason: 'it came to rest at $object, over the words at $w');
    }
    expect(Offset.zero & stage, predicate<Rect>((s) => s.expandToInclude(object) == s),
        reason: 'and it is on the stage');
  });

  test('on an empty desk it lands where it always did', () {
    final spot = landingSpot(
        stage: stage, side: objectSide(intensity), mine: false, seed: seed, words: const []);
    expect(spot, old);
  });

  testWidgets('the words it reads are the painted ones', (tester) async {
    tester.view.physicalSize = stage * 3.0;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      home: SizedBox.expand(
        key: key,
        child: IndexedStack(index: 1, children: const [
          Text('not shown'),
          Text('shown'),
        ]),
      ),
    ));
    final box = key.currentContext!.findRenderObject()! as RenderBox;
    final rects = wordsOnTheGlass(box, box);
    expect(rects, [tester.getRect(find.text('shown'))],
        reason: 'the region the shell keeps alive but does not show is not on the glass');
  });
}
