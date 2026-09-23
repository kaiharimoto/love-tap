// The lit edge is packed at half the size of the mask it lights, and still lands where it did.
//
// Until firing 54 `12_search` held 158 MB decoded for its tears while it was on the glass, and
// 78.0 MB of that was lit edges: a soft band of light along the break, packed at the mask's 1024.
// `tools/check/edge_residency.py` drew every edge that still declares, at its declared geometry,
// from a 1x and from a 2x-smaller copy: the band moved by at most 1.1/255, and at 3x by 2.1. So the
// pack writes the edges at half and [NinePainter] lays them out at the mask's geometry.
//
// Three things can break that and each is held here: the pack drifting from the app's constant,
// the residency creeping back, and the painter forgetting to scale -- which would draw every
// slice at half its size wherever a sheet is taller than its two slices, silently, because the
// band is only light.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:desk/material/library.dart';
import 'package:desk/material/paper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, List<int>> _packed() {
  final index = jsonDecode(File('assets/INDEX.json').readAsStringSync()) as Map<String, dynamic>;
  return {
    for (final r in (index['tears'] as List).cast<Map<String, dynamic>>())
      r['id'] as String: [r['w'] as int, r['h'] as int],
  };
}

const _paper = Color(0xFFECE5D6);

Future<Uint8List> _draw(WidgetTester tester, NinePainter p, Size size) async {
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  canvas.drawRect(Offset.zero & size, Paint()..color = _paper);
  p.paint(canvas, size);
  final img = rec.endRecording().toImageSync(size.width.toInt(), size.height.toInt());
  late ByteData? data;
  await tester.runAsync(() async {
    data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  });
  img.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  test('every lit edge is packed kEdgeDownsample times smaller than its mask', () {
    final packed = _packed();
    final edges = packed.keys.where((id) => id.endsWith('_edge')).toList();
    expect(edges.length, greaterThanOrEqualTo(40), reason: 'the pack has no tears in it');
    for (final e in edges) {
      final mask = packed[e.substring(0, e.length - 5)]!, edge = packed[e]!;
      for (final axis in [0, 1]) {
        // within a per cent: the edge render and the mask render are different sizes, so one
        // crop box rounds differently in each
        expect(edge[axis] * kEdgeDownsample, closeTo(mask[axis], mask[axis] * 0.01 + 1),
            reason: '$e is ${edge.join('x')} against its mask ${mask.join('x')}: the pack and '
                'kEdgeDownsample ($kEdgeDownsample) disagree, and every slice of it is drawn at '
                'the wrong size. Re-pack with tools/pack_assets.py --seed=year.');
      }
    }
  });

  test('12_search holds a quarter of the edge bytes it did', () {
    // Firing 51's arithmetic, off what the still declared: every mask it draws and the edge that
    // lights it, at the size the pack wrote, four bytes a pixel.
    final packed = _packed();
    final surfaces = (jsonDecode(File('../evidence/12_search.surfaces.json').readAsStringSync())
            as List)
        .cast<Map<String, dynamic>>();
    final masks = <String>{};
    final composed = <String>{};
    for (final s in surfaces.where((s) => s['fit'] == 'mask')) {
      final id = (s['asset'] as String).split('/').last.replaceAll('.webp', '');
      masks.add(id);
      final c = s['composed'] as List?;
      if (c != null) composed.add('$id ${c.join('x')}');
    }
    // the population: the same 27 masked pieces the item was measured on
    expect(masks.length, 27);
    int bytes(String id) => packed[id]![0] * packed[id]![1] * 4;
    final maskBytes = masks.fold<int>(0, (t, id) => t + bytes(id));
    final edgeBytes = masks.fold<int>(0, (t, id) => t + bytes('${id}_edge'));
    final composedBytes = composed.fold<int>(0, (t, k) {
      final wh = k.split(' ').last.split('x').map(int.parse).toList();
      return t + wh[0] * wh[1] * 4;
    });
    final total = maskBytes + edgeBytes + composedBytes;
    // ignore: avoid_print
    print('12_search: masks ${(maskBytes / (1 << 20)).toStringAsFixed(2)} MB, edges '
        '${(edgeBytes / (1 << 20)).toStringAsFixed(2)} MB, composed '
        '${(composedBytes / (1 << 20)).toStringAsFixed(2)} MB, total '
        '${(total / (1 << 20)).toStringAsFixed(2)} MB');
    expect(edgeBytes, lessThan(21 << 20),
        reason: 'the edges were 78.0 MB at 1x; half on each axis is a quarter');
    expect(total, lessThan(125 << 20), reason: 'the screen held 181 MB before firing 54');
  });

  testWidgets('a half-size edge lands where the full-size one does', (tester) async {
    late ui.Image full, half;
    await tester.runAsync(() async {
      full = await MaskCache.load(tearAsset('tear_049_edge'));
    });
    // a half-size copy made here, so the pair differs only by the downsample and the test does
    // not depend on the pack
    final rec = ui.PictureRecorder();
    Canvas(rec)
      ..scale(0.5)
      ..drawImage(full, Offset.zero, Paint()..filterQuality = FilterQuality.medium);
    half = rec.endRecording().toImageSync(full.width ~/ 2, full.height ~/ 2);

    // Two boxes: one taller and wider than the two slices together, where the middle stretches
    // and a painter that forgot to scale draws each slice at half its size; and one narrower,
    // where the whole lattice shrinks to fit and the two agree whatever the painter does.
    final w = full.width.toDouble(), h = full.height.toDouble();
    for (final size in [Size(w * 1.4, h * 2.2), Size(w * 0.5, h * 0.4)]) {
      final a = await _draw(tester, NinePainter('full', full, 0.4, 1.0), size);
      final b = await _draw(tester, NinePainter('half', half, 0.4, 1.0, 2), size);
      var sum = 0, n = 0, bandSum = 0, bandN = 0;
      const p = [0xEC, 0xE5, 0xD6];
      for (var i = 0; i < a.length; i += 4) {
        var d = 0, lit = 0;
        for (var c = 0; c < 3; c++) {
          d += (a[i + c] - b[i + c]).abs();
          lit += (a[i + c] - p[c]).abs();
        }
        sum += d;
        n += 3;
        if (lit > 6) {
          bandSum += d;
          bandN += 3;
        }
      }
      final mean = sum / n, band = bandN == 0 ? 0.0 : bandSum / bandN;
      // ignore: avoid_print
      print('box ${size.width.toInt()}x${size.height.toInt()}: mean ${mean.toStringAsFixed(3)}/255, '
          'band ${band.toStringAsFixed(3)}/255 over ${bandN ~/ 3} lit px');
      expect(bandN, greaterThan(0), reason: 'the full-size edge drew nothing to compare');
      expect(band, lessThanOrEqualTo(2.0),
          reason: 'the half-size edge does not land where the full-size one does in a '
              '${size.width.toInt()}x${size.height.toInt()} box');
    }
    half.dispose();
  });
}
