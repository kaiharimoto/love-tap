// A sheet of paper is a sheet of paper wherever you meet it.
//
// The app did not know how big a millimetre was. Every stock is printed at 8.57 pixels to the
// millimetre and every piece drew its stock at whatever scale that piece happened to be, so the
// same ruled paper appeared at rule pitches from 61.5 to 178.5 device pixels across ten stills — a
// ratio of 2.9, measured in logs/lines.json — and the tooth on a wide sheet was averaged away by
// the sampler that magnified it: 2.52 grey levels at the stock's own density, 1.26 on the large
// Settings sheet.
//
// A piece takes a window of its stock at the stock's own density now, wherever there is enough
// paper for it, and falls back to covering when there is not, because a sheet with a hole in it is
// worse than a sheet at the wrong size.
import 'package:desk/material/library.dart';
import 'package:desk/material/paper.dart';
import 'package:desk/material/slip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _draw(WidgetTester tester, Widget child, {double dpr = 3.0}) async {
  tester.view.physicalSize = Size(480 * dpr, 1040 * dpr);
  tester.view.devicePixelRatio = dpr;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUpAll(() async => MaterialLibrary.load());

  testWidgets('a note takes its paper at the paper\'s own density', (tester) async {
    PaperPiece.drawnNative = 0;
    PaperPiece.drawnStretched = 0;
    await _draw(
      tester,
      const Center(
        child: SizedBox(
          width: 340,
          height: 180,
          child: Slip(id: 'test.note', row: 0, stock: 'lined_01', child: Text('a line')),
        ),
      ),
    );
    expect(PaperPiece.drawnStretched, 0,
        reason: 'a note is smaller than a sheet and had its paper stretched anyway');
    expect(PaperPiece.drawnNative, greaterThan(0), reason: 'nothing drew any paper');
  });

  testWidgets('and a piece with more glass than there is paper still gets paper', (tester) async {
    PaperPiece.drawnNative = 0;
    PaperPiece.drawnStretched = 0;
    // taller than any stock at one image pixel per device pixel
    await _draw(
      tester,
      const SizedBox(
        width: 470,
        height: 1030,
        child: Slip(
          id: 'test.tall',
          row: 1,
          stock: 'index_01',
          child: SizedBox(width: 440, height: 1000),
        ),
      ),
    );
    expect(PaperPiece.drawnNative + PaperPiece.drawnStretched, greaterThan(0),
        reason: 'nothing drew any paper');
    expect(PaperPiece.drawnStretched, greaterThan(0),
        reason: 'a piece taller than its stock claimed to be at the stock\'s own density, which '
            'would mean a hole in it');
  });

  test('the library knows how big every stock is, which is what this rests on', () {
    for (final e in MaterialLibrary.instance.paper) {
      final s = MaterialLibrary.instance.stockSize(e.id);
      expect(s, isNotNull, reason: '${e.id} has no size in the index');
      expect(s!.width, greaterThan(400));
      expect(s.height, greaterThan(400));
    }
  });
}
