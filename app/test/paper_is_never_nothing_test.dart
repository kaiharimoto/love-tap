// A piece of paper is never nothing.
//
// 17_setup_pwa came back as a page of dark text on bare wood — headings at about one-to-one
// contrast against the desk, no sheet under them anywhere. Whatever caused the render not to
// arrive, the failure mode was the wrong one: a sheet whose image is missing should be a plain
// sheet, not an absence, because text is written on paper and the app has no way to write it on
// wood. This is the guard.
import 'package:desk/material/paper.dart';
import 'package:desk/material/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Roughly how light a colour is, 0..1. The desk is dark and paper is not.
double _lightness(Color c) =>
    (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b);

void main() {
  testWidgets('a sheet whose render never arrives is still a sheet', (tester) async {
    // No asset bundle in a widget test, so every Image.asset in here fails to load. That is
    // exactly the case being checked.
    await tester.pumpWidget(const MaterialApp(
      home: ColoredBox(
        color: Color(0xFF5C5148),
        child: Center(
          child: PaperPiece(
            stockId: 'looseleaf_01',
            tearId: 'tear_004',
            width: 300,
            child: Text('two phones, one wire between them'),
          ),
        ),
      ),
    ));
    await tester.pump();

    final boxes = tester.widgetList<ColoredBox>(find.byType(ColoredBox)).toList();
    final paperish = boxes.where((b) => _lightness(b.color) > 0.7).toList();
    expect(paperish, isNotEmpty,
        reason: 'nothing paper-coloured was drawn, so the writing is sitting on the desk');
    expect(find.text('two phones, one wire between them'), findsOneWidget);
  });

  test('every stock has a colour, including ones nobody has thought of yet', () {
    for (final id in ['lined_01', 'graph_04', 'legal_02', 'index_02', 'looseleaf_01',
                      'spiral_01', 'sticky_yellow_01', 'sticky_pink_02', 'a_stock_from_2027']) {
      final c = Paper.forStock(id);
      expect(_lightness(c), greaterThan(0.7),
          reason: '$id came out at ${_lightness(c).toStringAsFixed(2)}, which is not paper');
    }
    // and the pink one is not the yellow one
    expect(Paper.forStock('sticky_pink_01'), isNot(Paper.forStock('sticky_yellow_01')));
  });
}
