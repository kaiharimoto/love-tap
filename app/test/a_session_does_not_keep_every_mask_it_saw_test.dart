// A session does not keep every mask it has ever drawn.
//
// THE DEFECT THIS IS THE RULER FOR. `MaskCache` was a static map with no eviction and no dispose,
// and masks, lit edges and contact shadows all went through it, so every tear a session had drawn
// stayed decoded until the app died. Firing 51 measured it off INDEX.json and the committed
// sidecars: 181 MB after one visit to 12_search, 228 MB after a walk through every captured screen.
// Residency grew with the number of screens visited and nothing ever gave it back.
//
// THE MEASUREMENT, read from the caches themselves as the item asks: walk a long run of torn
// pieces one screen at a time, each replacing the last, and after every screen read
// `MaskCache.residentBytes` and `SlicedMasks.bytes`. What nobody is drawing must stay under the
// stated budget however many screens have gone by, and the piece on the glass must still have its
// mask — the population clause, so that the number cannot fall by a piece silently drawing
// nothing.
//
// RE-BREAK, run at firing 52: make `MaskCache._evict` return at once. The first test fails at
// screen 10 with 61 MB kept that nobody draws, and the second ends its walk holding 273 MB idle.
// Restored, the walk decodes 265 MB over 23 screens and never has more than 57 MB resident.
import 'package:desk/material/library.dart';
import 'package:desk/material/paper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _screen(String stock, List<String> tears) => Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        children: [
          for (final t in tears)
            PaperPiece(
              stockId: stock,
              tearId: t,
              width: 300,
              padding: EdgeInsets.zero,
              safe: const [0, 0, 0, 0],
              child: const SizedBox(height: 40),
            ),
        ],
      ),
    );

Future<void> _decode(WidgetTester tester, Iterable<String> tears) => tester.runAsync(() async {
      // outside the fake-async zone, where an image future never completes
      for (final t in tears) {
        await MaskCache.load(tearAsset(t));
        await MaskCache.load(tearAsset('${t}_edge'));
      }
    });

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await MaterialLibrary.load();
  });

  testWidgets('what nobody is drawing stays under the budget, however many screens went by',
      (tester) async {
    final lib = MaterialLibrary.instance;
    final stock = lib.stockVariants(lib.stocks.first).first;
    final tears = lib.writableTears.toList();
    // enough screens that keeping them all would be several budgets over
    expect(tears.length, greaterThanOrEqualTo(20));

    var peakResident = 0, everDecoded = 0;
    for (var i = 0; i + 1 < tears.length; i += 2) {
      final screen = tears.sublist(i, i + 2);
      await _decode(tester, screen);
      await tester.pumpWidget(_screen(stock, screen));
      await tester.pump();

      everDecoded += screen.fold<int>(0, (t, a) {
        final m = MaskCache.sizeOf(tearAsset(a))!, e = MaskCache.sizeOf(tearAsset('${a}_edge'))!;
        return t + m[0] * m[1] * 4 + e[0] * e[1] * 4;
      });
      // the population: both pieces on this screen are holding their mask, edge and shadow outline
      for (final t in screen) {
        expect(MaskCache.peek(tearAsset(t)), isNotNull, reason: 'screen $i lost $t while drawing it');
      }
      expect(MaskCache.heldBytes, greaterThan(0), reason: 'screen $i drew no mask at all');

      expect(MaskCache.idleBytes, lessThanOrEqualTo(MaskCache.budget),
          reason: 'after screen $i the cache keeps ${MaskCache.idleBytes >> 20} MB nobody draws');
      expect(SlicedMasks.bytes, lessThanOrEqualTo(SlicedMasks.budget));
      if (MaskCache.residentBytes > peakResident) peakResident = MaskCache.residentBytes;
    }
    // and the walk was one that an unbounded cache would have failed: it decoded far more than
    // the budget, and what stayed resident at its worst was the budget plus one screen
    expect(everDecoded, greaterThan(3 * MaskCache.budget));
    expect(peakResident, lessThan(MaskCache.budget + (24 << 20)));
    // ignore: avoid_print
    print('decoded ${everDecoded >> 20} MB over ${tears.length ~/ 2} screens; '
        'peak resident ${peakResident >> 20} MB; composed ${SlicedMasks.bytes >> 20} MB');
  });

  testWidgets('a piece still on the glass keeps its mask through every eviction', (tester) async {
    final lib = MaterialLibrary.instance;
    final stock = lib.stockVariants(lib.stocks.first).first;
    final tears = lib.writableTears.toList();
    final stays = tears.first;

    for (final t in tears.skip(1)) {
      await _decode(tester, [stays, t]);
      await tester.pumpWidget(_screen(stock, [stays, t]));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'drawing $stays next to $t');
    }
    // held the whole way, so never evicted and never disposed under the piece drawing it
    expect(MaskCache.peek(tearAsset(stays)), isNotNull);

    // and once nothing draws it, it is let go of and counts as idle, not held
    await tester.pumpWidget(const SizedBox());
    expect(MaskCache.heldBytes, 0);
    expect(MaskCache.idleBytes, lessThanOrEqualTo(MaskCache.budget));
  });
}
