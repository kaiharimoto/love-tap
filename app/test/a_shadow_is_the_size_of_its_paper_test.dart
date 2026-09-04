// A piece of paper's shadow is the size of the paper, wherever the paper is put.
//
// In Moments every voice note came out as a slip with a black torn rectangle under it, covering a
// quarter of the screen. The baked contact shadow is Positioned.fill, so it is the size of the
// Stack; the Stack is the size of the piece — except where something hands the piece tight
// constraints, which a square cell in a grid does. Then the piece stayed the height of what was
// written on it and the shadow stretched to fill the cell, until its dense middle was opaque.
//
// The thread never showed it because a list gives its rows loose constraints. So the case to hold
// is the tight one.
import 'package:desk/material/library.dart';
import 'package:desk/material/paper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await MaterialLibrary.load();
  });

  testWidgets('a torn piece in a square cell is no taller than what is on it', (tester) async {
    const cell = 240.0;
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: cell,
            height: cell,
            child: PaperPiece(
              stockId: 'lined_01',
              tearId: 'tear_004',
              safe: [0.1, 0.12, 0.06, 0.12],
              child: Text('41s'),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();

    final piece = tester.getSize(find.byType(PaperPiece));
    expect(piece.height, cell, reason: 'the widget itself fills the cell it was given');

    // what matters is the Stack inside it, which is what the shadow fills
    final stack = tester.getSize(find.descendant(
      of: find.byType(PaperPiece),
      matching: find.byType(Stack),
    ).first);
    expect(stack.height, lessThan(cell * 0.75),
        reason: 'the shadow fills this Stack, so a Stack the height of the cell is a shadow the '
            'height of the cell: ${stack.height} of $cell');
  });

  testWidgets('and in a list it is still the height of what is on it', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PaperPiece(
                stockId: 'lined_01',
                tearId: 'tear_004',
                safe: [0.1, 0.12, 0.06, 0.12],
                child: Text('two stops. put the kettle on the second one'),
              ),
            ],
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(tester.getSize(find.byType(PaperPiece)).height, lessThan(400));
  });
}
