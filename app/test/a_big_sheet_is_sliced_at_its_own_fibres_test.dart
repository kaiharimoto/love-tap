// A big sheet's fixed bands are as thin as that mask's own fibres, edge by edge, and no thinner.
//
// Firing 51 let the nine-slice's fixed bands give way on a big sheet, down to one floor for every
// edge of every mask: 0.25, the deepest fibre firing 51 found on five masks. Firing 54 drew the big
// sheets from their finer masks and left two over the 4x floor, both held there by that 0.25.
// settings.notify's mask is tear_032, whose bottom fibres end at 0.066 of it: the uniform floor
// was protecting fibres that edge does not have, and its torn sides were drawn at 4.89x.
// `tools/pack_assets.py` now measures every mask's four edges and `SlicedMasks.bandsFor` slices
// each at its own.
//
// WHAT IT CANNOT REACH. The setup sheet (tear_001, drawn 3.98x its finer mask) would need fixed
// bands under 0.7% of the mask in total to get under 4x, and tear_001's top and bottom fibres are
// 0.245 and 0.214. It goes 6.96 -> 6.51 and stays over, on arithmetic, not on effort.
//
// RE-BREAK: have `SlicedMasks.fibresOf` return the uniform `[fibres, fibres, fibres, fibres]`.
// settings.notify goes back to 4.89x and the count over the floor to 2.
import 'dart:convert';
import 'dart:io';

import 'package:desk/material/library.dart';
import 'package:desk/material/paper.dart';
import 'package:flutter_test/flutter_test.dart';

/// The sidecar's vertical `centre` for a mask [mh] tall on a piece [drawn] device pixels tall, as
/// `CaptureHooks` derives it: composition clamped to 4x the mask, sliced at [near] and [far], then
/// the shader's stretch over the piece.
double centreY(double mh, double drawn, double near, double far) {
  final composed = drawn.clamp(1, mh * 4).toDouble();
  final (t, b) = SlicedMasks.bandsFor(mh, composed, near, far);
  final fixed = mh * (t + b);
  final middleSrc = mh * (1 - t - b);
  final middleDst = composed - fixed * (composed < fixed ? composed / fixed : 1.0);
  if (middleSrc <= 0 || middleDst <= 0) return 0;
  return middleDst / middleSrc * (drawn / composed);
}

Map<String, Map<String, dynamic>> _family(String key) {
  final index = jsonDecode(File('assets/INDEX.json').readAsStringSync()) as Map<String, dynamic>;
  return {
    for (final r in ((index[key] as List?) ?? const []).cast<Map<String, dynamic>>())
      r['id'] as String: r,
  };
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await MaterialLibrary.load();
  });

  test('every mask says how deep its fibres reach, edge by edge', () {
    final masks = MaterialLibrary.instance.tearMasks;
    expect(masks.length, 56);
    for (final id in masks) {
      final f = MaterialLibrary.instance.entry(MaterialLibrary.instance.tears, id)!.fibres;
      expect(f, isNotNull, reason: '$id carries no fibres in assets/INDEX.json');
      expect(f!.length, 4);
      for (final d in f) {
        expect(d, inInclusiveRange(0.0, 0.46), reason: '$id: $f');
      }
      // and the app reads the same numbers, for the packed mask and its finer copy alike
      expect(SlicedMasks.fibresOf(tearAsset(id)), f);
      expect(SlicedMasks.fibresOf(finerTearAsset(id)), f);
    }
  });

  test('the bands are the old slice when the floors are the old floor', () {
    for (var r = 0.1; r <= 8; r += 0.05) {
      final (n, f) = SlicedMasks.bandsFor(1000, 1000 * r);
      expect(n, SlicedMasks.sliceFor(1000, 1000 * r));
      expect(f, n);
    }
  });

  test('neither band is ever thinner than its own edge, and they give way no further than needed',
      () {
    for (final (near, far) in [(0.066, 0.186), (0.245, 0.214), (0.02, 0.43), (0.3, 0.3)]) {
      for (var r = 0.5; r <= 8; r += 0.25) {
        final (n, f) = SlicedMasks.bandsFor(1000, 1000 * r, near, far);
        expect(n, greaterThanOrEqualTo(near < SlicedMasks.edge ? near : SlicedMasks.edge));
        expect(f, greaterThanOrEqualTo(far < SlicedMasks.edge ? far : SlicedMasks.edge));
        expect(n, lessThanOrEqualTo(SlicedMasks.edge));
        expect(f, lessThanOrEqualTo(SlicedMasks.edge));
        // up to 1.6x its mask a piece is sliced exactly as it always was
        if (r <= 1.6) expect((n, f), (SlicedMasks.edge, SlicedMasks.edge));
      }
    }
  });

  test('the big sheets in the committed stills, sliced at their own fibres', () {
    final packed = _family('tears'), finer = _family('tears_hi');
    var big = 0, overBefore = 0, overAfter = 0;
    final at = <String, double>{};
    for (final file in Directory('../evidence').listSync().whereType<File>()) {
      if (!file.path.endsWith('.surfaces.json')) continue;
      final still = file.uri.pathSegments.last.replaceAll('.surfaces.json', '');
      for (final s in (jsonDecode(file.readAsStringSync()) as List).cast<Map<String, dynamic>>()) {
        if (s['fit'] != 'mask') continue;
        final id = (s['asset'] as String).split('/').last.replaceAll('.webp', '');
        final drawn = (s['drawn'] as List).cast<int>();
        final m = packed[id]!;
        final wants = SlicedMasks.wantsFinerFor((m['w'] as int).toDouble(), (m['h'] as int).toDouble(),
            drawn[0].toDouble(), drawn[1].toDouble());
        if (!wants) continue;
        big++;
        final mh = (finer[id]!['h'] as int).toDouble();
        final f = SlicedMasks.fibresOf(tearAsset(id));
        const u = SlicedMasks.fibres;
        final before = centreY(mh, drawn[1].toDouble(), u, u);
        final after = centreY(mh, drawn[1].toDouble(), f[1], f[3]);
        // ignore: avoid_print
        print('$still ${s['piece'] ?? ''} $id ${drawn.join('x')}: vertical centre '
            '${before.toStringAsFixed(2)}x -> ${after.toStringAsFixed(2)}x (fibres $f)');
        if (before > SlicedMasks.cap + 1e-6) overBefore++;
        if (after > SlicedMasks.cap + 1e-6) overAfter++;
        at['$still/${s['piece'] ?? id}'] = after;
      }
    }
    // ignore: avoid_print
    print('$big big pieces; over the ${SlicedMasks.cap}x floor: $overBefore -> $overAfter');
    // the population firing 54 read off the same sidecars
    expect(big, 8);
    expect(overBefore, 2);
    expect(overAfter, 1);
    expect(at['05_settings_interrupt/settings.notify'], lessThanOrEqualTo(SlicedMasks.cap + 1e-6));
    expect(at['17_setup_pwa/tear_001'], closeTo(6.51, 0.01));
  });
}
