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
import 'dart:io';
import 'dart:ui' as ui;

import 'package:desk/material/library.dart';
import 'package:desk/material/paper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  _unconstrainedIsTheSizeOfItsWriting();
  _theInsetIsWhatTheAssetsSay();
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

// ---------------------------------------------------------------------------------------------
// And a piece nothing is constraining is the width of what is on it.
//
// PaperPiece fell back to a flat 320 logical points whenever its width was unbounded — a slip in
// a horizontally scrolling row, which is what every filter chip in Moments is. The chip reading
// `both` came out nine hundred and sixty device pixels wide, two thirds of the screen, and the
// third chip was off the right edge of the artifact entirely.
void _unconstrainedIsTheSizeOfItsWriting() {
  testWidgets('a piece with nothing constraining it is the width of its writing', (tester) async {
    late Size narrow;
    late Size wide;
    for (final (label, out) in [('both', 0), ('a much longer label than that', 1)]) {
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            PaperPiece(
              key: const ValueKey('chip'),
              stockId: '',
              padding: const EdgeInsets.fromLTRB(11, 5, 11, 6),
              child: Text(label, textDirection: TextDirection.ltr),
            ),
          ]),
        ),
      ));
      final size = tester.getSize(find.byKey(const ValueKey('chip')));
      if (out == 0) narrow = size; else wide = size;
    }
    expect(narrow.width, lessThan(120),
        reason: 'a four-letter chip came out ${narrow.width} points wide');
    expect(wide.width, greaterThan(narrow.width),
        reason: 'both labels came out the same width, so the width is not the writing');
  });
}

/// The rect the paper occupies inside a shadow render, recomputed from the packed assets.
///
/// `PaperPiece._bakedShadow` places the render by this rect rather than by the frame it was baked
/// at, because the piece's own mask is nine-sliced to fill the piece box: mapped by the frame, the
/// render's paper edge lands at 0.986 of a box whose paper ends at 1.0, and the whole penumbra —
/// the only part of a contact shadow anybody can see — is drawn under opaque paper. The eleventh
/// capture measured what that costs: the desk four to fourteen pixels under a sheet is 3.6 grey
/// levels darker than forty-five to sixty-five below it in the chat hero, 0.05 in search, −0.17 in
/// the pulse and −1.64 in Moments, against a floor of 6 that holes.py takes from a capture where it
/// worked. The one still that passes is Settings, whose cards are cut rather than torn and get the
/// painted shadow instead.
///
/// The constant is a measurement, so this is the measurement. A re-render that moves the paper
/// inside the frame fails here rather than quietly flattening every shadow in the app again.
void _theInsetIsWhatTheAssetsSay() {
  testWidgets('the shadow inset is the rect the paper actually occupies in the renders',
      (tester) async {
    const frame = 1.25; // relief.shadow_frame in app/assets/INDEX.json
    final masks = Directory('assets/tears')
        .listSync()
        .whereType<File>()
        .map((f) => f.path)
        .where((p) => !p.contains('_shadow') && !p.contains('_dusk') && p.endsWith('.webp'))
        .where((p) => File(p.replaceAll('.webp', '_shadow.webp')).existsSync())
        .toList()
      ..sort();
    expect(masks.length, greaterThan(20), reason: 'no packed tears to measure');
    // every fifth one: decoding all fifty-six is a minute of test time for the same answer
    final sample = [for (var i = 0; i < masks.length; i += 5) masks[i]];

    final got = <String, List<double>>{'l': [], 't': [], 'r': [], 'b': []};
    await tester.runAsync(() async {
      for (final path in sample) {
        final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
        final image = (await codec.getNextFrame()).image;
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        final w = image.width, h = image.height;
        final px = data!.buffer.asUint8List();
        var l = w, t = h, r = -1, b = -1;
        for (var y = 0; y < h; y += 2) {
          for (var x = 0; x < w; x += 2) {
            if (px[(y * w + x) * 4 + 3] < 12) continue;
            if (x < l) l = x;
            if (x > r) r = x;
            if (y < t) t = y;
            if (y > b) b = y;
          }
        }
        image.dispose();
        expect(r, greaterThan(0), reason: '$path has no alpha in it');
        // where the mask's paper sits once the frame is [frame] times the piece, centred
        got['l']!.add((l / w + (frame - 1) / 2) / frame);
        got['t']!.add((t / h + (frame - 1) / 2) / frame);
        got['r']!.add((r / w + (frame - 1) / 2) / frame);
        got['b']!.add((b / h + (frame - 1) / 2) / frame);
      }
    });

    double median(List<double> v) {
      final s = [...v]..sort();
      return s[s.length ~/ 2];
    }

    const used = Rect.fromLTRB(0.113, 0.122, 0.887, 0.875);
    for (final (name, m, want) in [
      ('left', median(got['l']!), used.left),
      ('top', median(got['t']!), used.top),
      ('right', median(got['r']!), used.right),
      ('bottom', median(got['b']!), used.bottom),
    ]) {
      expect((m - want).abs(), lessThan(0.02),
          reason: 'the $name of the paper inside a shadow render is $m now, '
              'and PaperPiece._bakedShadow places them by $want');
    }
  });
}
