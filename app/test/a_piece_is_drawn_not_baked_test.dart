// What a piece costs to draw, and where the search mark is allowed to sit.
//
// tools/check/tears.py fails 02_chat.png unless eight rows were on the glass, each on its own
// torn edge. Which stretch of a year does that cannot be worked out from the text: it depends on
// how tall each row lays out — how many words wrapped, what is stuck to it, whether it carries a
// waveform. Estimating it from the length of the writing framed six notes, then seven, and the
// artifact was recorded missing on its own standard twice. So the app measures instead, and so
// does this: the same seeded year, on a surface the size of the one the scene shoots, through
// the same handle the harness pulls.
import 'dart:io';

import 'package:desk/material/hands.dart';
import 'package:desk/spine/event.dart';
import 'package:desk/material/library.dart';
import 'package:desk/material/paper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  _plainPieceComposesNothing();
  _writingComposesNothing();
  _searchDoesNotCoverTheThread();
  _aNoteComposesNothing();
}

/// A piece with handwriting on it: the case every note in the thread actually is.
///
/// The pen's coverage plate used to go on as a `ShaderMask` over the words, which is a compositing
/// layer, so the piece under it could not have its tear drawn straight into the canvas and had to
/// bake it into an image instead — hundreds of milliseconds in CanvasKit, on the build thread,
/// once per note as the thread scrolls, and 203 of 793 frames of a scroll over 400 ms to build.
/// The plate is the paint the glyphs are drawn with now. Same ink, no layer.
void _writingComposesNothing() {
  test('writing on a piece of paper does not push a layer over it', () {
    // Read from the source rather than rendered, and the reason is worth writing down: rendering
    // it hangs this binding — a piece with a hand font on it inside a masked box never settles,
    // and the suite that a capture now waits on cannot afford a test that does not finish.
    //
    // The real measurement is on the artifact. The capture report carries `masks_composed` —
    // `SlicedMasks.composed`, how many tear masks the run had to bake — and for a scroll it should
    // read nothing at all. A number off a browser drawing a fourteen-thousand-event year is worth
    // more than a number off a software rasteriser drawing one note.
    final hands = File('lib/material/hands.dart').readAsStringSync();
    final written = hands.substring(hands.indexOf('class Written'));
    expect(written.contains('Inked('), isFalse,
        reason: 'Written wraps its text in a ShaderMask again, so every piece of paper with '
            'writing on it bakes its tear instead of drawing it');
    expect(written.contains('inked: true'), isTrue,
        reason: 'Written no longer asks for the pen\'s plate at all, so the ink is flat');

    final ink = File('lib/material/ink.dart').readAsStringSync();
    expect(ink.contains('final Map<String, ui.ImageShader> _shaders'), isTrue,
        reason: 'the plate\'s shader is built on every call again — a note builds its text on '
            'every frame it is on screen, and that is what made this unusable the first time');
  });
}

/// One piece of paper with writing on it: the case every note in the thread is, and the case the
/// nine-patch is for. It composes nothing.
void _plainPieceComposesNothing() {
  testWidgets('a plain piece draws its tear without baking it', (tester) async {
    await MaterialLibrary.load();
    final tear = MaterialLibrary.instance.writableTears.first;
    await tester.runAsync(() async {
      await MaskCache.load(tearAsset(tear));
      await MaskCache.load(tearAsset('${tear}_edge'));
    });
    final was = SlicedMasks.composed;
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: ColoredBox(
        color: const Color(0xFF62503C),
        child: Center(
          child: SizedBox(
            width: 340,
            child: PaperPiece(
              stockId: 'lined_02',
              tearId: tear,
              liftMm: 0.9,
              tilt: 0.006,
              child: const Text('back by six. the pigeon is still on the cupboard'),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(SlicedMasks.composed - was, 0,
        reason: 'a plain note baked its tear into an image — 16 ms on this machine and hundreds of '
            'milliseconds in CanvasKit, on the build thread, once per note as the thread scrolls');
  });
}

/// Chrome that covers what it is chrome for.
void _searchDoesNotCoverTheThread() {
  testWidgets('the search mark is not over the thread', (tester) async {
    final src = File('lib/regions/chat/chat_region.dart').readAsStringSync();
    expect(src.contains('onTap: onSearch'), isTrue, reason: 'nothing reaches the search any more');
    expect(src.contains("id: 'thread.search'"), isFalse,
        reason: 'the search mark is a slip of its own again. Pinned over the list it covered thread '
            'text in 84 of the scroll clip’s 300 frames; in a strip above the list it cost the hero '
            'framing a whole sheet. It lives on the composer, beside the clip and the ticks.');
  });
}

/// What a screenful of notes costs to compose, when it has to compose at all.
void _aNoteComposesNothing() {
  test('a thread of notes composes few masks, not one a note', () {
    // Handwriting is drawn through a ShaderMask — the pen's coverage plate multiplied into the
    // letters — and a ShaderMask is a compositing layer, so a piece with writing on it cannot have
    // its tear drawn straight into the canvas: it falls back to composing the mask as an image.
    // That is what 189 of 789 frames of a scroll over 400 ms to build are. What is under this
    // builder's control is how often it has to: the composed mask is keyed by tear and height, and
    // every note is a different height, so the key used to change for every note that came into
    // view. Rounded to sixty-four device pixels, four notes out of five find one already made —
    // and what stretches to make up the difference is the solid middle of the tear.
    final src = File('lib/material/paper.dart').readAsStringSync();
    final at = src.indexOf('final h = ((size.height * dpr /');
    expect(at, greaterThan(0), reason: 'the composed mask is keyed some other way now');
    final line = src.substring(at, src.indexOf(';', at));
    final bucket = int.parse(RegExp(r'dpr / (\d+)').firstMatch(line)!.group(1)!);
    expect(bucket, greaterThanOrEqualTo(64),
        reason: 'the composed mask is keyed to $bucket device pixels of height, so a scroll '
            'composes one for nearly every note it passes');
    expect(src, contains('static const _keep = 128;'),
        reason: 'the cache holds fewer masks than a screenful of notes needs, so it thrashes');
  });
}
