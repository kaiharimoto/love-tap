// A thing thrown to you lands on the desk, not across the letter you are reading.
//
// The stage drew the arriving object at 0.52 of the screen height and left it there for the whole
// length of the haptic pattern. A coherence critic measured what that costs: Pulse's partner-state
// card covered for 106 frames, Settings' 'the two phones' card for 77, and Us's 'DATES THAT
// MATTER' row for 92 — 1.2 to 1.7 seconds each of one region's content hidden under another
// region's event. It lands low now, on the band of desk every region leaves above the tab strip,
// and it is put away as soon as it has finished bouncing; the pattern plays on with it filed.
//
// What is read here is the geometry, at every intensity and for every feeling in the vocabulary,
// because the landing place is a function of both.
import 'dart:async';

import 'package:desk/app.dart' show kTabStrip;
import 'package:desk/feelings/builtins.dart';
import 'package:desk/feelings/landing.dart';
import 'package:desk/material/library.dart';
import 'package:desk/material/objects.dart';
import 'package:desk/material/slip.dart';
import 'package:desk/spine/spine.dart' show Person;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await MaterialLibrary.load();
  });

  test('it is put away as soon as it has landed, not when the pattern ends', () {
    for (final f in kBuiltInFeelings) {
      for (final i in const [0.3, 0.55, 1.0]) {
        final dwell = Fall.dwellSeconds(f, i);
        final rest = Fall.restSeconds(f, i);
        expect(dwell, lessThanOrEqualTo(rest + 1e-9),
            reason: '${f.id} is put away after the pattern it is meant to be played under');
        expect(dwell, lessThanOrEqualTo(0.62),
            reason: '${f.id} at $i lies on the glass for ${dwell}s');
        // and it is still there long enough to have actually landed
        expect(dwell, greaterThanOrEqualTo(Fall.contacts(i).last - 1e-9),
            reason: '${f.id} at $i is put away before it has stopped bouncing');
      }
    }
  });

  testWidgets('the object and its label stay on the desk, clear of the tab strip',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    final floor = size.height - kTabStrip;

    // the four feelings whose objects sit largest in their own render, at full throw
    final biggest = [...kBuiltInFeelings]
      ..sort((a, b) => FeelingObject.boxFor(b, 190).compareTo(FeelingObject.boxFor(a, 190)));

    for (final f in biggest.take(4)) {
      final arrivals = StreamController<Arrival>.broadcast();
      addTearDown(arrivals.close);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          // Keyed by the feeling: without it the second pump keeps the first stage's State, which
          // subscribed to the first stream in initState and never hears the second arrival.
          body: LandingStage(
            key: ValueKey(f.id),
            arrivals: arrivals.stream,
            child: const SizedBox.expand(),
          ),
        ),
      ));
      arrivals.add(Arrival(
        feeling: f,
        intensity: 1.0,
        mine: false,
        from: Person.noor,
        at: DateTime.utc(2026, 9, 3, 20, 35),
      ));
      await tester.pump();
      // past the last bounce, where it is lying still and the label is written
      await tester.pump(Duration(milliseconds: (Fall.contacts(1.0).last * 1000).round() + 20));

      final object = tester.getRect(find.byType(FeelingObject).first);
      expect(object.bottom, lessThanOrEqualTo(floor),
          reason: '${f.id} lands ${object.bottom - floor} points into the tab strip');
      expect(object.top, greaterThan(size.height * 0.45),
          reason: '${f.id} lands across the middle of the page at ${object.top}');

      final label = find.byType(Slip);
      expect(label, findsOneWidget, reason: '${f.id} arrived with nothing written on it');
      final written = tester.getRect(label);
      expect(written.bottom, lessThanOrEqualTo(floor),
          reason: 'the label of ${f.id} is behind the tab strip');
      expect(written.left, greaterThanOrEqualTo(0.0));
      expect(written.right, lessThanOrEqualTo(size.width));
    }
  });
}
