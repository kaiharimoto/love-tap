// Whatever the far phone says, both meters stay on the strip.
//
// The standing strip's second row had no answer for running out of width. When
// `state availability heads_down` landed in 08 the two extra stamped words pushed the right-hand
// end off the paper: a coherence critic read `OUT HEADS DOWN RESTLESS NEED |||  E` at frame 560 —
// ENERGY cut to one letter, its meter and its trend arrow clipped away — and still clipped at
// frame 638, the last frame of the clip. A meter with no reading on it is worse than a smaller one.
@TestOn('vm')
library;

import 'package:desk/material/desk.dart';
import 'package:desk/material/library.dart';
import 'package:desk/spine/event.dart';
import 'package:desk/spine/projections/state.dart';
import 'package:desk/spine/types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PersonState _busy() => PersonState(Person.noor, {
      for (final e in <(String, Object)>[
        ('status_line', 'week one, and the room smells right again'),
        ('availability', 'heads_down'),
        ('mood', 'restless'),
        ('place', 'out'),
        ('need', 3),
        ('energy', 1),
        ('battery', 41),
      ])
        e.$1: SignalValue(signal: e.$1, value: e.$2, at: 0, declared: true),
    });

void main() {
  setUpAll(() async => MaterialLibrary.load());

  testWidgets('the strip keeps both meters at the width a phone actually is', (tester) async {
    for (final width in [320.0, 360.0, 390.0, 480.0]) {
      tester.view.physicalSize = Size(width * 3, 780 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PartnerStrip(partner: Person.noor, state: _busy(), nowMs: 0),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // both labels present, and both entirely inside the screen
      // a stamp is stamped in capitals
      for (final label in [signalLabel('need').toUpperCase(), signalLabel('energy').toUpperCase()]) {
        final f = find.text(label);
        expect(f, findsOneWidget, reason: 'no $label at ${width}pt');
        final box = tester.getRect(f);
        expect(box.right, lessThanOrEqualTo(width + 0.5),
            reason: '$label runs off the right edge at ${width}pt (${box.right})');
        expect(box.width, greaterThan(4.0), reason: '$label is squeezed to nothing at ${width}pt');
      }
      expect(tester.takeException(), isNull, reason: 'the strip overflowed at ${width}pt');
    }
  });
}
