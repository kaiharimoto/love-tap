// A highlighter is a wet pen dragged across a page, not a rectangle of yellow.
//
// The mark a search leaves on the note it landed on was `BoxDecoration(color:
// Accent.highlighterYellow)` filling the whole sheet: one flat translucent rectangle, edge to
// edge, which is the shape the anti-goal names and was the last literal fill in lib. A highlighter
// is wet — darker where two passes crossed, skipping where the paper's tooth was high, stopping
// where the hand stopped.
import 'dart:ui' as ui;

import 'package:desk/material/ink.dart';
import 'package:desk/material/library.dart';
import 'package:desk/regions/chat/note.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await MaterialLibrary.load();
    await InkPlates.load();
  });

  testWidgets('the mark is not a rectangle and does not reach the edges', (tester) async {
    if (!InkPlates.ready) {
      markTestSkipped('no ink plates packed');
      return;
    }
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      home: RepaintBoundary(
        key: key,
        child: ColoredBox(
          color: const Color(0xFFFFFFFF),
          child: SizedBox(
            width: 300,
            height: 120,
            child: CustomPaint(painter: highlighterFor('01M1QFFBPBHMPRMWZ9W05QDR4D')),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    late List<double> rows;
    late List<double> cols;
    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      final w = image.width, h = image.height;
      double ink(int x, int y) {
        final i = (y * w + x) * 4;
        // the wash is yellow over white: what it takes away is blue
        return (255 - bytes.getUint8(i + 2)).toDouble();
      }

      rows = [for (var y = 0; y < h; y++) List.generate(w, (x) => ink(x, y)).reduce((a, b) => a + b) / w];
      cols = [for (var x = 0; x < w; x++) List.generate(h, (y) => ink(x, y)).reduce((a, b) => a + b) / h];
    });

    final most = rows.reduce((a, b) => a > b ? a : b);
    expect(most, greaterThan(6.0), reason: 'nothing was drawn at all');
    // a fill is the same on every row; a pen is not
    final least = rows.reduce((a, b) => a < b ? a : b);
    expect(least, lessThan(most * 0.7),
        reason: 'every row carries the same amount of ink: $least against $most, which is a fill');
    // and it stops short of the left and right edges
    expect(cols.first, lessThan(most * 0.5), reason: 'the mark runs off the left edge');
    expect(cols.last, lessThan(most * 0.5), reason: 'the mark runs off the right edge');
  });

  test('the same note is highlighted the same way twice', () {
    final a = highlighterFor('abc');
    final b = highlighterFor('abc');
    expect(a.shouldRepaint(b), isFalse);
    expect(a.shouldRepaint(highlighterFor('abd')), isTrue);
  });
}
