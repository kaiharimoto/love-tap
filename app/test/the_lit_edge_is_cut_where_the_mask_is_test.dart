// The lit edge lands on the break the mask cut, not on a copy of it further in.
//
// A torn piece is cut by its mask and lit by its `_edge` render, two renders of one tear. Until
// firing 60 the mask was nine-sliced by its own bands at DEVICE pixels ([SlicedMasks.at]) and the
// edge at a fixed 0.4 on the LOGICAL canvas ([NinePainter]), so on a 3x screen the edge's slices
// were three times the size of the mask's: every large torn card in 03_us showed its real cut as a
// dark fibrous line and, 30-60 px inside it, a blurred stair-stepped copy of the same tear.
//
// The sidecar test (`the_three_layers_of_a_tear_each_say_so_test.dart`) holds what the painter
// DECLARES. This holds what it DRAWS: the half-size edge, painted by [NinePainter] lighting its
// mask, against the same edge at the mask's size laid out exactly as [SlicedMasks.at] lays out
// the mask -- same bands, same composed size, same stretch over the piece. Re-break by having the
// painter ignore its lattice and the tall box fails by an order of magnitude.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:desk/material/library.dart';
import 'package:desk/material/paper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _paper = Color(0xFFECE5D6);
const _dpr = 3.0;

Future<Uint8List> _pixels(WidgetTester tester, ui.Image img) async {
  late ByteData? data;
  await tester.runAsync(() async {
    data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  });
  img.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await MaterialLibrary.load();
  });

  testWidgets('the edge is sliced by the mask it lights', (tester) async {
    const tear = 'tear_049';
    late ui.Image half, mask;
    await tester.runAsync(() async {
      mask = await MaskCache.load(tearAsset(tear));
      half = await MaskCache.load(tearAsset('${tear}_edge'));
    });
    final mw = mask.width.toDouble(), mh = mask.height.toDouble();
    // the edge at the mask's own size, so the reference differs from the painter only in layout
    final rec0 = ui.PictureRecorder();
    Canvas(rec0)
      ..scale(mw / half.width, mh / half.height)
      ..drawImage(half, Offset.zero, Paint()..filterQuality = FilterQuality.medium);
    final full = rec0.endRecording().toImageSync(mask.width, mask.height);

    // One box a little narrower than the mask and more than twice as tall, where the bands give
    // way and a fixed 0.4 on the logical canvas lands furthest from the cut; and one note-sized,
    // where both lattices are closer.
    for (final size in [
      Size(mw * 0.9 / _dpr, mh * 3.1 / _dpr),
      Size(mw * 0.5 / _dpr, mh * 0.8 / _dpr),
    ]) {
      final pw = (size.width * _dpr).round(), ph = (size.height * _dpr).round();

      // what the painter draws, at device pixels
      final ra = ui.PictureRecorder();
      final ca = Canvas(ra)
        ..drawRect(Offset.zero & Size(pw.toDouble(), ph.toDouble()), Paint()..color = _paper);
      ca.scale(_dpr);
      NinePainter('edge', half, 0.4, 1.0, kEdgeDownsample, tearAsset(tear), _dpr).paint(ca, size);
      final a = await _pixels(tester, ra.endRecording().toImageSync(pw, ph));

      // what SlicedMasks.at does with the mask, done with the full-size edge instead
      final w = pw.clamp(1, mask.width).toDouble(), h = ph.clamp(1, mask.height * 4).toDouble();
      final e = SlicedMasks.slicesFor(tearAsset(tear), mw, mh, w, h);
      final rb = ui.PictureRecorder();
      final cb = Canvas(rb)
        ..drawRect(Offset.zero & Size(pw.toDouble(), ph.toDouble()), Paint()..color = _paper);
      cb.scale(pw / w, ph / h);
      cb.drawImageNine(
        full,
        Rect.fromLTRB(mw * e[0], mh * e[1], mw * (1 - e[2]), mh * (1 - e[3])),
        Rect.fromLTWH(0, 0, w, h),
        Paint()..filterQuality = FilterQuality.medium,
      );
      final b = await _pixels(tester, rb.endRecording().toImageSync(pw, ph));

      var bandSum = 0, bandN = 0;
      const p = [0xEC, 0xE5, 0xD6];
      for (var i = 0; i < a.length; i += 4) {
        var d = 0, lit = 0;
        for (var c = 0; c < 3; c++) {
          d += (a[i + c] - b[i + c]).abs();
          lit += (b[i + c] - p[c]).abs();
        }
        if (lit > 6) {
          bandSum += d;
          bandN += 3;
        }
      }
      final band = bandN == 0 ? 0.0 : bandSum / bandN;
      // ignore: avoid_print
      print(
        'box ${pw}x$ph device px, bands ${e.map((x) => x.toStringAsFixed(3)).join(',')}: '
        'band ${band.toStringAsFixed(3)}/255 over ${bandN ~/ 3} lit px',
      );
      expect(bandN, greaterThan(0), reason: 'the reference edge drew nothing to compare');
      expect(
        band,
        lessThanOrEqualTo(2.0),
        reason:
            'in a ${pw}x$ph box the lit edge is not where the mask cut the paper: the glow '
            'and the break are two copies of the tear',
      );
    }
    full.dispose();
  });
}
