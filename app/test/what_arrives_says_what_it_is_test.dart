// The thing that lands says whose it is and when, on something you can read it against.
//
// A coherence critic found the same feeling on the glass twice at once in 15 — written
// 'tuesday soup / 20:35 · noor' in the Pulse shelf, and lying across the state card above it with
// no name, no time and no sender. One event drawn two incompatible ways.
//
// The first fix wrote the name straight onto whatever the object had landed on, in the hand the
// desk is written in, which is a pale warm grey. On wood it reads at 4.94:1; on paper it is a
// ghost, and 07 frame 360 of the eleventh capture shows it drawn through the rituals card's own
// writing — which is exactly as useful as carrying no name. No one colour reads on both grounds,
// so the label brings its own.
@TestOn('vm')
library;

import 'dart:async';

import 'package:desk/feelings/builtins.dart';
import 'package:desk/feelings/landing.dart';
import 'package:desk/material/library.dart';
import 'package:desk/material/objects.dart';
import 'package:desk/material/slip.dart';
import 'package:desk/spine/event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async => MaterialLibrary.load());

  testWidgets('a feeling that lands carries its name, on paper', (tester) async {
    const dpr = 3.0;
    tester.view.physicalSize = const Size(360 * dpr, 780 * dpr);
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.reset);

    final f = kBuiltInFeelings.firstWhere((f) => f.id == 'hold');
    final arrivals = StreamController<Arrival>.broadcast();
    addTearDown(arrivals.close);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LandingStage(
          arrivals: arrivals.stream,
          child: const ColoredBox(color: Color(0xFF4C3E32), child: SizedBox.expand()),
        ),
      ),
    ));
    await tester.pump();

    // nothing has arrived: nothing is drawn
    expect(find.byType(FeelingObject), findsNothing);
    expect(find.text(f.name), findsNothing);

    arrivals.add(Arrival(
      feeling: f,
      intensity: 0.8,
      mine: false,
      from: Person.noor,
      at: DateTime.utc(2026, 9, 3, 20, 26),
    ));
    await tester.pump();
    // far enough in that it has touched the desk: the label comes in when the object does
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(find.byType(FeelingObject), findsOneWidget);
    expect(find.text(f.name), findsOneWidget,
        reason: 'the thing that arrived carries no name');
    expect(find.textContaining('20:26'), findsWidgets,
        reason: 'the thing that arrived carries no time');
    expect(find.textContaining(Person.noor.name), findsWidgets,
        reason: 'the thing that arrived does not say who sent it');

    // and the name is on paper, so it is legible on whatever the object landed on
    expect(
      find.ancestor(of: find.text(f.name), matching: find.byType(Slip)),
      findsOneWidget,
      reason: 'the name is written straight onto the ground, and the ground is whatever the region '
          'had drawn there',
    );
  });
}
