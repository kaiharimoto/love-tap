// A stock being enlarged must not be smoothed on the way.
//
// The measurement this exists to hold: index_01's own tooth is 2.52 grey levels of high-pass
// standard deviation; the same stock minified reads 4.43; the same stock magnified 1.17 times
// through a smoothing filter reads 1.29, and 1.26 is what a material critic measured on the large
// Settings sheet in 05_settings.png. A full-width piece in the capture viewport is 1356 device
// pixels across and the A5 stocks are 1288, so every full-width sheet was being enlarged and
// averaged. Nearest-neighbour cannot put back detail that is not there; it stops the sampler
// taking away the detail that is.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desk/material/library.dart';
import 'package:desk/material/paper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await MaterialLibrary.load();
  });

  test('the library knows how big a stock is', () {
    final s = MaterialLibrary.instance.stockSize('index_01');
    expect(s, isNotNull);
    expect(s!.width, greaterThan(100));
    expect(MaterialLibrary.instance.stockSize('no_such_stock'), isNull);
  });

  test('a stock drawn larger than itself is drawn without a filter', () {
    final px = MaterialLibrary.instance.stockSize('index_01')!;
    // a full-width Settings card: 452 logical points across at three device pixels a point, tall
    // enough that the stock's short side is what binds
    const dpr = 3.0;
    final tall = Size(452, px.height / dpr * 1.4);
    expect(PaperPiece.stockFilter('index_01', tall, dpr, 1.12), FilterQuality.none);
  });

  test('a stock drawn smaller than itself keeps its smoothing filter', () {
    // a note in the thread: the piece is a fraction of the stock, and point-sampling the ruled
    // lines down would break them into dashes
    const dpr = 3.0;
    expect(PaperPiece.stockFilter('lined_01', const Size(300, 160), dpr, 1.15),
        FilterQuality.medium);
  });

  test('a stock the library has never heard of falls back rather than throwing', () {
    expect(PaperPiece.stockFilter('no_such_stock', const Size(300, 160), 3.0, 1.0),
        FilterQuality.medium);
  });
}
