// The app says what paper it drew, and how much bigger than its render it drew it.
//
// This exists because a screenshot cannot answer that question and three review cycles tried.
// `10_first_run.png` measures as one RGB value over 59.5% of its frame, which is the named
// failure of the whole visual concept, and from the pixels alone it was diagnosed first as a
// missing asset and then as the `ColoredBox` fallback in `material/paper.dart` showing through.
// It was neither: the render was there and over the fallback the entire time. What was wrong was
// which render it was and how far it had been stretched — 702x1500 of till roll at 1.94x — and
// neither of those two numbers is in a PNG.
//
// So the app declares them, the way it already declares where its words are. A declaration is a
// number a tool or a person can check; a squint at a still is not.
import 'package:desk/capture/hooks.dart';
import 'package:desk/material/desk.dart';
import 'package:desk/material/library.dart';
import 'package:desk/material/slip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('every surface on the glass is declared with its render and its magnification',
      (tester) async {
    if (!MaterialLibrary.loaded) await MaterialLibrary.load();
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Desk(child: Stack(children: [RegionPad(id: 'pulse')])),
      ),
    ));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    }
    expect(tester.takeException(), isNull);

    final surfaces = CaptureHooks.paperSurfaces();
    expect(surfaces, isNotEmpty,
        reason: 'the app drew a desk and a pad and declared no surface at all');

    for (final s in surfaces) {
      expect(s['src'], isA<List<Object?>>());
      expect(s['drawn'], isA<List<Object?>>());
      expect(s['scale'], isA<num>());
      expect((s['src'] as List)[0], isPositive, reason: 'a surface with no render behind it');
      expect((s['drawn'] as List)[0], isPositive, reason: 'a surface drawn at no size');
    }

    // Every surface names the asset it came from. This is the half that failed first: an
    // `Image`'s element carries the provider and its `renderObject` is the `Semantics` wrapper,
    // not the `RenderImage`, so the names were landing on a key nothing looked up and every
    // surface was declared with an empty asset — a declaration that says nothing.
    for (final s in surfaces) {
      expect(s['asset'], isNotEmpty,
          reason: 'a surface was declared with no asset name, so the declaration cannot say '
              'which paper it was: $s');
    }

    // The desk is a surface too, and it is also full-height, so the pad is found by its asset
    // rather than by its size. It is the sheet this whole file is about: the only piece of paper
    // that is the whole screen.
    final pad = surfaces.firstWhere(
      (s) => (s['asset'] as String).startsWith('assets/paper/'),
      orElse: () => <String, dynamic>{},
    );
    expect(pad, isNotEmpty,
        reason: 'no paper was declared at all, so the one surface that has cost this build three '
            'cycles is the one the declaration cannot see');
    expect((pad['drawn'] as List)[1] as int, greaterThan(2000),
        reason: 'the pad was declared ${(pad['drawn'] as List)[1]} device px tall, which is not '
            'the whole screen, so this is not the pad');

    // And the desk, which is the other full-height surface and must not be mistaken for it.
    expect(surfaces.any((s) => (s['asset'] as String).startsWith('assets/shell/')), isTrue,
        reason: 'the desk under everything was not declared');
    final src = (pad['src'] as List).cast<int>();
    final drawn = (pad['drawn'] as List).cast<int>();
    final scale = (pad['scale'] as num).toDouble();
    final byHand = [drawn[0] / src[0], drawn[1] / src[1]].reduce((a, b) => a > b ? a : b);
    expect(scale, closeTo(byHand, 0.01),
        reason: 'the declared magnification ${scale.toStringAsFixed(3)} is not the drawn size '
            'over the render size (${byHand.toStringAsFixed(3)}), so it is decorative');

    // ignore: avoid_print
    print('pad: ${src[0]}x${src[1]} drawn ${drawn[0]}x${drawn[1]} at '
        '${scale.toStringAsFixed(2)}x  (${surfaces.length} surfaces declared)');
  });

  testWidgets('a pad is never torn from a stock that is not a sheet of paper', (tester) async {
    // The rule the declaration exists to make checkable, asserted where it is cheapest: the pad's
    // render has to be portrait and full-page, because the pad is a phone screen. `receipt_01` is
    // 702x1500 and `index_02` is 1500x933, and either one drawn as a whole screen is a stretch
    // rather than a sheet.
    if (!MaterialLibrary.loaded) await MaterialLibrary.load();
    final lib = MaterialLibrary.instance;
    for (final stock in RegionPad.stocks) {
      final variants = lib.stockVariants(stock);
      expect(variants, isNotEmpty, reason: '$stock is on the pad\'s list and not in the library');
      for (final v in variants) {
        final entry = lib.paper.firstWhere((e) => e.id == v);
        expect(entry.h, greaterThan(entry.w),
            reason: '$v is ${entry.w}x${entry.h} — a pad torn from it is a landscape render '
                'covering a portrait screen, which magnifies it far past its own resolution');
        expect(entry.w / entry.h, closeTo(1073 / 1500, 0.08),
            reason: '$v is ${entry.w}x${entry.h}, which is not the shape of a page');
      }
    }
  });
}
