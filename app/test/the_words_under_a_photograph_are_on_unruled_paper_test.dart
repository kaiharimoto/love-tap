// The words under a photograph are written on paper with no printed rules across them.
//
// The viewer's caption named no stock, so it took whichever its id hashed to, and the seeded
// photograph's id hashes to `graph`: NoorHand at 54 px with blue-grey rules through every
// letter, ink core 2.94 against a floor of 4.5 on 14_media_viewer, while the same ink read 10.52
// against the paper beside it. The ink was never the problem; the ground was.
//
// Held on the renders themselves, not on a name: every variant of [ViewerPage.captionStock], day
// and dusk, is measured for printed rules the way firing 60 measured the library -- the std of
// the row means across the middle of the sheet -- and must read as unruled. So do the ruled
// stocks, to show the measure can tell them apart; and the seeded caption's id is shown to hash
// to a ruled stock, which is what the viewer drew before it named one.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:desk/material/assignment.dart';
import 'package:desk/material/library.dart';
import 'package:desk/regions/chat/viewer_page.dart';
import 'package:flutter_test/flutter_test.dart';

/// The std of the row means over the middle of [asset]: rows 30-90%, columns 15-85%.
Future<double> _rules(String asset) async {
  final codec = await ui.instantiateImageCodec(File(asset).readAsBytesSync());
  final img = (await codec.getNextFrame()).image;
  final data = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final px = data.buffer.asUint8List();
  final w = img.width, h = img.height;
  final means = <double>[];
  for (var y = (h * 0.3).round(); y < (h * 0.9).round(); y++) {
    var sum = 0.0, n = 0;
    for (var x = (w * 0.15).round(); x < (w * 0.85).round(); x++) {
      final i = (y * w + x) * 4;
      sum += 0.299 * px[i] + 0.587 * px[i + 1] + 0.114 * px[i + 2];
      n++;
    }
    means.add(sum / n);
  }
  img.dispose();
  final m = means.reduce((a, b) => a + b) / means.length;
  return math.sqrt(means.map((v) => (v - m) * (v - m)).reduce((a, b) => a + b) / means.length);
}

void main() {
  const unruled = 3.5;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await MaterialLibrary.load();
  });

  test('the caption stock has no printed rules, day or dusk, and the ruled stocks do', () async {
    final lib = MaterialLibrary.instance;
    final caption = lib.stockVariants(ViewerPage.captionStock);
    expect(caption, isNotEmpty, reason: 'the library has no ${ViewerPage.captionStock}');
    for (final id in caption) {
      for (final v in [id, '${id}_dusk']) {
        final r = await _rules('assets/paper/$v.webp');
        // ignore: avoid_print
        print('$v: rows ${r.toStringAsFixed(2)}');
        expect(r, lessThan(unruled), reason: '$v has rules printed across it');
      }
    }
    for (final ruled in ['graph', 'lined', 'legal']) {
      final v = '${lib.stockVariants(ruled).first}_dusk';
      final r = await _rules('assets/paper/$v.webp');
      // ignore: avoid_print
      print('$v: rows ${r.toStringAsFixed(2)}');
      expect(r, greaterThan(unruled), reason: 'the measure cannot see the rules on $v');
    }
  });

  test('the seeded caption would have hashed to graph paper', () {
    // Slip's own choice when no stock is named, for the photograph 14_media_viewer holds up
    const stocks = ['index', 'lined', 'looseleaf', 'graph', 'receipt', 'legal'];
    expect(stocks[hashOf('viewer_01KKP9AZEGXQ38N9BVB70W8KDR') % stocks.length], 'graph');
  });
}
