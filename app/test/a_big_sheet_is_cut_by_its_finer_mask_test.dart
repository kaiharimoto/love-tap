// A sheet too big for its packed mask is cut by the mask it was rendered as, not by a stretched copy.
//
// Firing 51 thinned the slice on big sheets and got the setup sheet's torn sides from 19.5x to
// 8.6x; the rest of the way needed more source pixels than the packer delivered. Firing 53 named
// five masks to deliver at full size. Firing 54 read today's sidecars first and none of the pieces
// over the floor draws any of the five: the seeded-id repair re-rolled them onto tear_001, 018, 032
// and 005. Which mask a big sheet gets is a hash, so the finer copy exists for every mask and size
// decides who decodes it (`FinerMask`, `SlicedMasks.wantsFiner`).
//
// RE-BREAK: have `SlicedMasks.wantsFiner` return false. The big piece below is then cut by its
// 1024 copy, `drawnWith` names the coarse asset, and the arithmetic's `after` equals `before`.
import 'dart:convert';
import 'dart:io';

import 'package:desk/material/library.dart';
import 'package:desk/material/paper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The sidecar's vertical `centre`, as `CaptureHooks` derives it for a mask [mh] tall on a piece
/// [drawn] device pixels tall: composition clamped to 4x the mask, sliced by `sliceFor`, then the
/// shader's stretch over the piece. The same function as a_big_sheet_is_not_torn_..._test.dart.
double centreY(double mh, double drawn) {
  final composed = drawn.clamp(1, mh * 4).toDouble();
  final slice = SlicedMasks.sliceFor(mh, composed);
  final fixed = mh * 2 * slice;
  final middleSrc = mh * (1 - 2 * slice);
  final middleDst = composed - fixed * (composed < fixed ? composed / fixed : 1.0);
  if (middleSrc <= 0 || middleDst <= 0) return 0;
  return middleDst / middleSrc * (drawn / composed);
}

Map<String, List<int>> _family(String key) {
  final index = jsonDecode(File('assets/INDEX.json').readAsStringSync()) as Map<String, dynamic>;
  return {
    for (final r in ((index[key] as List?) ?? const []).cast<Map<String, dynamic>>())
      r['id'] as String: [r['w'] as int, r['h'] as int],
  };
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await MaterialLibrary.load();
  });

  test('every mask has a finer copy, and it is finer', () {
    final packed = _family('tears'), finer = _family('tears_hi');
    final masks = packed.keys.where((id) => !id.contains('_edge') && !id.contains('_shadow'));
    expect(masks.length, 56);
    for (final id in masks) {
      expect(finer[id], isNotNull, reason: '$id has no finer copy in assets/tears/hi');
      // at least as big: a small tear's paper crops to under 1024 of its 2048 render and has
      // nothing finer to give, and most are 1.6-2x
      expect(finer[id]![0], greaterThanOrEqualTo(packed[id]![0]),
          reason: '$id\'s finer copy is ${finer[id]!.join('x')} against ${packed[id]!.join('x')}');
      // the same crop, so the same shape
      expect(finer[id]![0] / finer[id]![1], closeTo(packed[id]![0] / packed[id]![1], 0.01));
    }
  });

  test('the big sheets in the committed stills are drawn finer, and only they', () {
    final packed = _family('tears'), finer = _family('tears_hi');
    var big = 0, overBefore = 0, overAfter = 0, small = 0;
    for (final f in Directory('../evidence').listSync().whereType<File>()) {
      if (!f.path.endsWith('.surfaces.json')) continue;
      final still = f.uri.pathSegments.last.replaceAll('.surfaces.json', '');
      for (final s in (jsonDecode(f.readAsStringSync()) as List).cast<Map<String, dynamic>>()) {
        if (s['fit'] != 'mask') continue;
        final id = (s['asset'] as String).split('/').last.replaceAll('.webp', '');
        final drawn = (s['drawn'] as List).cast<int>();
        final m = packed[id]!;
        final wants = SlicedMasks.sliceFor(m[0].toDouble(), drawn[0].toDouble()) < SlicedMasks.edge ||
            SlicedMasks.sliceFor(m[1].toDouble(), drawn[1].toDouble()) < SlicedMasks.edge;
        if (!wants) {
          small++;
          continue;
        }
        big++;
        final before = centreY(m[1].toDouble(), drawn[1].toDouble());
        final after = centreY(finer[id]![1].toDouble(), drawn[1].toDouble());
        if (before > SlicedMasks.cap + 1e-6) overBefore++;
        if (after > SlicedMasks.cap + 1e-6) overAfter++;
        // ignore: avoid_print
        print('$still ${s['piece'] ?? ''} $id ${drawn.join('x')}: vertical centre '
            '${before.toStringAsFixed(2)}x -> ${after.toStringAsFixed(2)}x');
        expect(after, lessThanOrEqualTo(before + 1e-9));
        if (before > SlicedMasks.cap) {
          expect(after, lessThan(before * 0.8),
              reason: '$still/$id is drawn finer and its torn sides are barely less stretched');
        }
      }
    }
    // ignore: avoid_print
    print('$big big pieces, $small small; over the ${SlicedMasks.cap}x floor: $overBefore -> $overAfter');
    // the population: the big pieces firing 54 read off the committed sidecars, and the small
    // ones, which draw exactly what they drew
    expect(big, 8);
    expect(small, greaterThanOrEqualTo(100));
    expect(overAfter, lessThan(overBefore));
  });

  Widget piece(String tear, double height) => Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: PaperPiece(
            stockId: MaterialLibrary.instance.stocks.first,
            tearId: tear,
            width: 380,
            padding: EdgeInsets.zero,
            safe: const [0, 0, 0, 0],
            child: SizedBox(height: height),
          ),
        ),
      );

  testWidgets('a big sheet asks for the finer mask and a note does not', (tester) async {
    tester.view.physicalSize = const Size(1200, 4800);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    const tear = 'tear_001';
    await tester.runAsync(() async {
      await MaskCache.load(tearAsset(tear));
      await MaskCache.load(tearAsset('${tear}_edge'));
      await MaskCache.load(finerTearAsset(tear));
    });

    // 1500 logical at 3x is 4500 device px against a 578-px mask: the setup sheet's shape
    await tester.pumpWidget(piece(tear, 1500));
    await tester.pump();
    final bigKey = SlicedMasks.drawnWith.keys.firstWhere((k) => k.endsWith('x1500'),
        orElse: () => fail('the big piece composed no mask: ${SlicedMasks.drawnWith}'));
    expect(SlicedMasks.drawnWith[bigKey], finerTearAsset(tear),
        reason: 'a sheet 7.8x its packed mask was cut by the packed mask');
    expect(MaskCache.peek(finerTearAsset(tear)), isNotNull);

    // a note: the packed mask, as before
    SlicedMasks.drawnWith.clear();
    await tester.pumpWidget(piece(tear, 120));
    await tester.pump();
    final smallKey = SlicedMasks.drawnWith.keys.single;
    expect(SlicedMasks.drawnWith[smallKey], tearAsset(tear),
        reason: 'a note drew the finer mask, which spends residency on every note on the screen');

    // and the big sheet let go of the finer copy when it went: nobody holds it now
    await tester.pumpWidget(const SizedBox());
    expect(MaskCache.heldBytes, lessThan(4 << 20));
  });
}
