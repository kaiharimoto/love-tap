// A slip torn from a receipt is torn from its blank end, whatever shape the slip is.
//
// `receipt_01` is a till roll whose top half is its own faded thermal print. The app chose it on
// purpose in three places -- a planned date, a voice note, noor's slip pool -- and wrote over the
// print, and three critics at cycle 3 read the result as "pixelated grey pseudo-text blocks, a
// mosaic of mojibake". [PaperPiece.blankFraming] frames a printed stock by the size the piece
// turned out to be, so that only its blank rows ([kBlankPaper]) lie under it.
//
// Held here through the same declaration the capture reads: every piece's stock entry in
// `CaptureHooks.paperSurfaces`, placed against its mask's rect with the arithmetic
// `tools/check/receipt_print.py` uses. Re-break by framing the receipt the way every other stock
// is framed and the wide slips fail on the printed rows.
import 'package:desk/capture/hooks.dart';
import 'package:desk/material/library.dart';
import 'package:desk/material/paper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The rows of the render under [piece], as fractions: the ruler's arithmetic, in Dart.
(double, double) _rowsUnder(Map<String, dynamic> e, List<num> piece) {
  final src = (e['src'] as List).cast<num>(), drawn = (e['drawn'] as List).cast<num>();
  final rect = (e['rect'] as List).cast<num>(), align = (e['align'] as List).cast<num>();
  final k = [drawn[0] / src[0], drawn[1] / src[1]].reduce((a, b) => a > b ? a : b);
  final t = rect[3] / drawn[1];
  final y0 = (src[1] - drawn[1] / k) * (align[1] + 1) / 2;
  final top = y0 + (piece[1] - rect[1]) / t / k;
  final bottom = y0 + (piece[1] + piece[3] - rect[1]) / t / k;
  return (top / src[1], bottom / src[1]);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await MaterialLibrary.load();
  });

  testWidgets('no slip cut from the receipt shows its printout', (tester) async {
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    const tear = 'tear_001';
    await tester.runAsync(() async {
      await MaskCache.load(tearAsset(tear));
      await MaskCache.load(tearAsset('${tear}_edge'));
    });
    final blank = kBlankPaper['receipt_01']!;

    // a voice-note slip, a planned date, a square and a tall one; three patches of each
    const shapes = [Size(340, 90), Size(380, 216), Size(220, 220), Size(150, 420)];
    const patches = [Alignment(-1, -1), Alignment(0.3, 0), Alignment(1, 1)];
    for (final stock in ['receipt_01', 'receipt_01_dusk']) {
      for (final shape in shapes) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                // side by side when they are tall, so all three are on the glass and painted
                child: Flex(
                  direction: shape.height > 250 ? Axis.horizontal : Axis.vertical,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final (i, patch) in patches.indexed)
                      PaperPiece(
                        id: 'slip$i',
                        stockId: stock,
                        tearId: tear,
                        width: shape.width,
                        stockAlignment: patch,
                        stockScale: 1.12,
                        child: SizedBox(height: shape.height),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        }
        expect(tester.takeException(), isNull);
        final surfaces = CaptureHooks.paperSurfaces();
        for (var i = 0; i < patches.length; i++) {
          final mine = surfaces.where((s) => s['piece'] == 'slip$i').toList();
          final paper = mine.firstWhere(
            (s) => '${s['asset']}'.contains('paper/receipt_01'),
            orElse: () => fail('slip$i declared no receipt stock: $mine'),
          );
          final mask = mine.firstWhere(
            (s) => s['fit'] == 'mask',
            orElse: () => fail('slip$i declared no mask: $mine'),
          );
          expect(
            paper['align'],
            isA<List<Object?>>(),
            reason:
                'the stock does not declare where its cover is aligned, so nobody can say '
                'which rows of it are under the piece',
          );
          final (top, bottom) = _rowsUnder(paper, (mask['rect'] as List).cast<num>());
          // ignore: avoid_print
          print(
            '$stock ${shape.width.toInt()}x${shape.height.toInt()} patch ${patches[i]}: '
            'rows ${top.toStringAsFixed(3)}-${bottom.toStringAsFixed(3)}, '
            'scale ${paper['scale']}',
          );
          expect(
            top,
            greaterThanOrEqualTo(blank.$3 - 0.005),
            reason:
                'a ${shape.width.toInt()}x${shape.height.toInt()} slip shows the receipt '
                'from row ${top.toStringAsFixed(3)}, and its print runs to 0.48',
          );
          expect(
            bottom,
            lessThanOrEqualTo(blank.$4 + 0.005),
            reason: 'the slip runs past the end of the roll',
          );
        }
      }
    }
  });
}
