// A person's words are written beside a pad's red margin rule, not across it.
//
// Legal, lined and spiral stocks carry a printed red rule at about 23% of their width. A word laid
// across it sits on the darkest ground in the library -- at dusk no ink in COLOR.md's ladder reads
// there (evidence/dusk_ground.json, `a-word-is-written-across-the-printed-margin-rule`) -- and the
// partner's strip, which is on every screen, laid its status line straight across it. Firing 54's
// render of the strip found the rule as 65 red pixels inside the status line's box.
//
// The pack now says where each stock's rule is (INDEX.json `paper_margin`), and a piece asked to
// be `besideTheMargin` is cut from the paper to the right of it. Measured here as arithmetic on
// the framing, for every ruled stock, and as pixels in `a_pressed_clover_is_on_the_strip_test`.
//
// RE-BREAK: have `stockFraming` return `(stockScale, stockAlignment)` unchanged.
import 'package:desk/material/library.dart';
import 'package:desk/material/paper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await MaterialLibrary.load();
  });

  test('the pack says where the rule is on every ruled stock', () {
    final margins = MaterialLibrary.instance.paperMargin;
    for (final family in ['legal', 'lined', 'spiral']) {
      final ruled = MaterialLibrary.instance.paper.where((e) => e.id.startsWith(family)).toList();
      expect(ruled, isNotEmpty);
      for (final e in ruled) {
        final m = margins[e.id];
        expect(m, isNotNull, reason: '${e.id} is a $family stock and the pack found no rule on it');
        expect(m![0], inInclusiveRange(0.15, 0.32), reason: '${e.id} rule at ${m.join('-')}');
      }
    }
  });

  test('a piece beside the margin does not have the rule on it', () {
    // The piece is the width of the strip or the pulse card; the stock is drawn cover by width
    // and then scaled about its right edge, so the rule's left edge lands at
    // right - scale * width * (1 - m[0]) and has to be at or left of the piece's own left edge.
    const width = 460.0;
    for (final entry in MaterialLibrary.instance.paperMargin.entries) {
      final piece = PaperPiece(stockId: entry.key, besideTheMargin: true, child: const SizedBox());
      final (scale, align) = piece.stockFraming(entry.key);
      expect(align.x, 1.0);
      final ruleRight = width - scale * width * (1 - entry.value[1]);
      expect(ruleRight, lessThanOrEqualTo(0),
          reason: '${entry.key}: the rule still ends ${ruleRight.toStringAsFixed(1)} px into the piece');
      // and a piece that did not ask is framed as it always was
      final plain = PaperPiece(stockId: entry.key, child: const SizedBox());
      expect(plain.stockFraming(entry.key), (1.0, Alignment.center));
    }
  });
}
