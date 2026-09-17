// The app declares where its writing is, in the coordinates of the picture taken of it.
//
// `tools/check/legibility.py` found writing by looking for marks shaped like glyphs — its own
// docstring says so — and a surface that acquires texture acquires glyph-shaped marks. When the
// corrected day illuminant stopped the torn paper lips clipping to flat white, 137 runs arrived in
// one capture that had never existed, 102 of them below the floor: a 74% failure rate against 21%
// on the runs that were really there. The instrument's noise had grown larger than the changes it
// was being used to judge.
//
// `CaptureHooks.textRuns` is the answer to that: the app knows where its text is, so it says so,
// and the tool measures only inside what was declared. `tools/check/legibility_selftest.py` proves
// the tool half — that declaring removes fibre, keeps writing, and that undoing the declaration
// brings the failures straight back. This is the app half.
//
// What it exists to catch is a declaration that is *nearly* right. A rect in logical pixels rather
// than device pixels is wrong by exactly the device pixel ratio, which on a screen of writing puts
// every line somewhere between the lines; a rect that is never transformed out of its own local
// space is wrong by wherever the paragraph sits. Neither throws, neither looks wrong in a JSON
// file, and the only symptom of either is a legibility report that quietly measures less and less.
// So every assertion here is against what the framework says the same paragraph's rect is.
import 'package:desk/capture/hooks.dart';
import 'package:desk/material/hands.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const double _dpr = 3.0;
const Size _physical = Size(1440, 3120);       // the PWA still, as the scenes take it
const Size _logical = Size(480, 1040);

/// Where each line is put, and what it is written in — one of each thing the app writes with.
const _lines = <String, Offset>{
  'the canal has gone all dimples': Offset(24, 80),
  'one hour then stop': Offset(40, 300),
  'i left the small pan on the hob': Offset(16, 520),
  'TUESDAY': Offset(300, 700),
  'delivered': Offset(60, 820),
};

Widget _style(String text) {
  if (text == 'TUESDAY') return Text(text, style: Hands.stamp());
  if (text == 'delivered') return Text(text, style: Hands.margin());
  return Text(text, style: Hands.noor());
}

Future<void> _pumpWriting(WidgetTester tester, {double top = 0}) async {
  tester.view.physicalSize = _physical;
  tester.view.devicePixelRatio = _dpr;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Stack(
        children: [
          for (final e in _lines.entries)
            Positioned(left: e.value.dx, top: e.value.dy + top, child: _style(e.key)),
        ],
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  testWidgets('every drawn word is declared where the framework says it is', (tester) async {
    await _pumpWriting(tester);
    final runs = CaptureHooks.textRuns();
    expect(runs.length, _lines.length,
        reason: 'five lines were drawn and ${runs.length} were declared');

    for (final text in _lines.keys) {
      final declared = runs.where((r) => r['text'] == text).toList();
      expect(declared, hasLength(1), reason: 'nothing declared for the words "$text"');
      final r = (declared.single['rect'] as List).cast<int>();
      // What the framework says the same paragraph's rect is, clipped to the frame: a paragraph
      // laid out wider than the screen is declared as the part of it that is in the picture, and
      // `getRect` does not clip.
      final box = tester.getRect(find.text(text)).intersect(Offset.zero & _logical);

      // The ratio. `getRect` is in logical pixels and the PNG is in device pixels, and the whole
      // instrument is only as good as these four lines.
      expect(r[0], closeTo(box.left * _dpr, 2), reason: 'left of "$text"');
      expect(r[1], closeTo(box.top * _dpr, 2), reason: 'top of "$text"');
      expect(r[2], closeTo(box.width * _dpr, 3), reason: 'width of "$text"');
      expect(r[3], closeTo(box.height * _dpr, 3), reason: 'height of "$text"');

      // Lines live inside the paragraph they came out of, or they were never transformed with it.
      for (final line in (declared.single['lines'] as List).cast<List>()) {
        final l = line.cast<int>();
        expect(l[0] >= r[0] - 2 && l[1] >= r[1] - 2 &&
            l[0] + l[2] <= r[0] + r[2] + 2 && l[1] + l[3] <= r[1] + r[3] + 2, isTrue,
            reason: 'a line at $l is outside its own paragraph at $r, for "$text"');
      }
    }
  });

  testWidgets('the type size and the hand are declared, not guessed at', (tester) async {
    await _pumpWriting(tester);
    final byText = {for (final r in CaptureHooks.textRuns()) r['text'] as String: r};

    // legibility.py splits body from large at a device-pixel height, and until this handle it took
    // that height off the bounding box of the marks it found — which on a line with no ascender
    // and no descender in it is several points short of the type size.
    for (final run in byText.values) {
      expect(run['px'] as double, closeTo((run['points'] as double) * _dpr, 0.51),
          reason: 'points and px disagree for "${run['text']}"');
    }
    expect(byText['the canal has gone all dimples']!['role'], 'hand');
    expect(byText['the canal has gone all dimples']!['family'], 'NoorHand');
    expect(byText['TUESDAY']!['role'], 'stamp');
    expect(byText['TUESDAY']!['family'], 'DeskStamp');
    // The margin pencil is TeoHand and Pen.margin is now the same value as Pen.stamp, so nothing
    // here separates it from a hand. It is declared as what it is written with, and no more.
    expect(byText['delivered']!['role'], 'hand');
    expect(byText['delivered']!['ink'], isNotEmpty);
  });

  testWidgets('nothing is declared outside the frame the picture is of', (tester) async {
    // Everything pushed most of the way off the bottom: the tool must never be handed permission
    // to read pixels that are not in the file.
    await _pumpWriting(tester, top: _logical.height - 120);
    final runs = CaptureHooks.textRuns();
    final w = _physical.width.round();
    final h = _physical.height.round();
    for (final run in runs) {
      final r = (run['rect'] as List).cast<int>();
      expect(r[0] >= 0 && r[1] >= 0 && r[0] + r[2] <= w && r[1] + r[3] <= h, isTrue,
          reason: 'declared $r outside the ${w}x$h frame, for "${run['text']}"');
      for (final line in (run['lines'] as List).cast<List>()) {
        final l = line.cast<int>();
        expect(l[0] >= 0 && l[1] >= 0 && l[0] + l[2] <= w && l[1] + l[3] <= h, isTrue,
            reason: 'a declared line $l is outside the frame, for "${run['text']}"');
      }
    }
    expect(runs.length, lessThan(_lines.length),
        reason: 'four of the five lines were pushed off the bottom and all five were still '
            'declared, so nothing is being clipped at all');
  });

  testWidgets('a paragraph with no letters in it is not writing', (tester) async {
    tester.view.physicalSize = _physical;
    tester.view.devicePixelRatio = _dpr;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(children: [
          Positioned(left: 20, top: 100, child: Text('   ', style: Hands.noor())),
          Positioned(left: 20, top: 200, child: Text('', style: Hands.noor())),
          Positioned(left: 20, top: 300, child: Text('here', style: Hands.noor())),
        ]),
      ),
    ));
    await tester.pump();
    final runs = CaptureHooks.textRuns();
    expect(runs.map((r) => r['text']), ['here']);
  });
}
