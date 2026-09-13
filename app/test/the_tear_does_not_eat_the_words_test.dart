// A torn edge may take the paper. It may not take the writing.
//
// The safe insets the packer measures are fractions of the mask at the size it was *rendered* —
// 1024 by about 578 — and the mask is drawn as a nine-patch, which keeps its border cells at their
// rendered size whatever size the piece turns out to be. So on a piece shorter than the render the
// tear eats far more of it than the fraction says, and the writing is laid out against the
// fraction.
//
// An emotional critic measured what that costs on the one clip whose subject is a state change
// reaching the other phone: of the partner strip's state row — the surface that carries their
// state on every screen — 90.4 per cent of the ink sat on bare wood, median over 70 sampled
// frames, in 67 of them, and the words it destroyed were exactly TRAVELLING, HEADS DOWN, RESTLESS
// and QUIET. Contrast fell from 75.3 grey levels on the title row above, which is on paper, to
// 48.1 on the wood.
//
// Two things are asserted here, on the widgets rather than on a photograph: the library reports
// the tear's bite in the unit the piece is laid out in, and every word of the partner's strip is
// inside it.
import 'dart:async';

import 'package:desk/capture/bus.dart';
import 'package:desk/capture/hooks.dart';
import 'package:desk/material/desk.dart';
import 'package:desk/material/library.dart';
import 'package:desk/material/paper.dart';
import 'package:desk/spine/projections/state.dart';
import 'package:desk/spine/spine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The state 08_state_propagating drives: the one whose words the tear ate.
PersonState _theirs() {
  const at = 1756999000000;
  SignalValue v(String s, Object value) =>
      SignalValue(signal: s, value: value, at: at, declared: true);
  return PersonState(Person.noor, {
    'mood': v('mood', 'restless'),
    'availability': v('availability', 'heads_down'),
    'place': v('place', 'travelling'),
    'need': v('need', 3),
    'energy': v('energy', 1),
    'status_line': v('status_line', 'on the last train'),
  });
}

PersonState _andThen() {
  const at = 1756999500000;
  SignalValue v(String s, Object value) =>
      SignalValue(signal: s, value: value, at: at, declared: true);
  return PersonState(Person.noor, {
    'mood': v('mood', 'quiet'),
    'availability': v('availability', 'open'),
    'place': v('place', 'out'),
    'need': v('need', 1),
    'energy': v('energy', 3),
    'status_line': v('status_line', 'off the train'),
  });
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await MaterialLibrary.load();
  });

  test('the library says how far the tear eats in the unit a piece is laid out in', () {
    final lib = MaterialLibrary.instance;
    final ids = lib.writableTears;
    expect(ids, isNotEmpty);
    var deeperThanTheFraction = 0;
    for (final id in ids) {
      final bite = lib.tearBiteOf(id, 3.0);
      expect(bite, isNotNull, reason: '$id carries no measured band');
      final safe = lib.safeOf(id);
      // on a strip 86 points tall — the partner strip's own height
      if (bite![3] > safe[3] * 86) deeperThanTheFraction++;
    }
    expect(deeperThanTheFraction, greaterThan(0),
        reason: 'if no mask bites deeper than its fraction on an 86 pt strip there is nothing '
            'here to have gone wrong, and 08 measured it going wrong');
  });

  testWidgets('every word of the partner strip is on the paper', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: PartnerStrip(partner: Person.noor, state: _theirs(), nowMs: 1757000000000),
        ),
      ),
    ));
    await tester.pump();

    final pieces = find.byType(PaperPiece);
    expect(pieces, findsOneWidget);
    final piece = tester.widget<PaperPiece>(pieces);
    // the sheet as it is painted, which is the Stack the mask fills — not the widget's own box
    final box = tester.getRect(
        find.descendant(of: pieces, matching: find.byType(Stack)).first);
    final bite = piece.tearId == null
        ? const [0.0, 0.0, 0.0, 0.0]
        : (MaterialLibrary.instance.tearBiteOf(piece.tearId!, 3.0) ?? const [0.0, 0.0, 0.0, 0.0]);
    final safe = piece.safe;
    // the paper, as the nine-patch actually draws it: the deeper of the fraction and the band
    final paper = Rect.fromLTRB(
      box.left + (box.width * safe[0] > bite[0] ? box.width * safe[0] : bite[0]),
      box.top + (box.height * safe[1] > bite[1] ? box.height * safe[1] : bite[1]),
      box.right - (box.width * safe[2] > bite[2] ? box.width * safe[2] : bite[2]),
      box.bottom - (box.height * safe[3] > bite[3] ? box.height * safe[3] : bite[3]),
    );

    final words = find.byType(Text);
    expect(words, findsWidgets, reason: 'the strip said nothing at all');
    final offenders = <String>[];
    for (final e in words.evaluate()) {
      final t = e.widget as Text;
      final r = tester.getRect(find.byWidget(t));
      if (r.isEmpty) continue;
      final below = r.bottom - paper.bottom;
      final above = paper.top - r.top;
      final past = r.right - paper.right;
      if (below > 0.5 || above > 0.5 || past > 0.5) {
        offenders.add('"${t.data}" at $r: ${below > 0.5 ? '${below.toStringAsFixed(1)} pt below '
            'the paper' : ''}${above > 0.5 ? '${above.toStringAsFixed(1)} pt above it' : ''}'
            '${past > 0.5 ? '${past.toStringAsFixed(1)} pt past its right edge' : ''}');
      }
    }
    expect(offenders, isEmpty,
        reason: 'the strip is ${box.height.toStringAsFixed(1)} pt on ${piece.tearId}, whose tear '
            'eats ${bite[1].toStringAsFixed(1)} pt off the top and ${bite[3].toStringAsFixed(1)} '
            'off the bottom, leaving paper at $paper — and ${offenders.length} of the words are '
            'not on it:\n  ${offenders.join('\n  ')}');
  });

  testWidgets('a state change is a sheet being laid over the one that was there', (tester) async {
    // The one thing this surface exists for used to happen between two frames. An emotional critic
    // measured it on the clip whose whole subject is a state change reaching the other phone: the
    // cross-dissolve lasted two frames of a sixteen-frame take — 11.14 per cent mid-tone pixels at
    // frame 1, back to the 2.94 per cent baseline by frame 2 — and over the remaining fourteen the
    // board did not move at all. Nothing was animating it.
    CaptureBus.wanted = true;
    addTearDown(() {
      CaptureBus.wanted = false;
      CaptureBus.clear();
    });
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    Future<void> show(PersonState state) => tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 360,
                child: PartnerStrip(partner: Person.noor, state: state, nowMs: 1757000000000),
              ),
            ),
          ),
        ));

    await show(_theirs());
    await tester.pump();
    expect(find.byType(PaperPiece), findsOneWidget);

    await show(_andThen());
    await tester.pump();
    // both sheets on the desk: the one that was there, and the one being laid over it
    expect(find.byType(PaperPiece), findsNWidgets(2),
        reason: 'the new sheet replaced the old one between two frames, which is the fault');

    // and it is still happening a quarter of a second later, on the clock the harness drives
    for (var i = 0; i < 15; i++) {
      unawaited(DrivenClock.step(16));
      await tester.pump();
    }
    expect(find.byType(PaperPiece), findsNWidgets(2),
        reason: 'the change was over inside 240 ms — Motion.land is 420');

    for (var i = 0; i < 20; i++) {
      unawaited(DrivenClock.step(16));
      await tester.pump();
    }
    expect(find.byType(PaperPiece), findsOneWidget,
        reason: 'the old sheet is still on the desk after the whole of Motion.land');
  });
}
