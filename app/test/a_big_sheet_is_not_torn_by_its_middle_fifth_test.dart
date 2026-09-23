// A sheet much taller than its mask is sliced so its torn sides are not drawn at 19x.
//
// THE DEFECT THIS IS THE RULER FOR. `SlicedMasks.at` nine-sliced every mask at a fixed 0.4: the
// top and bottom four tenths of the source held their own scale and every remaining pixel of
// height went into the middle fifth. On 17_setup_pwa's sheet (mask 1024x824, drawn 1332x4026 at
// 3x) the sidecar firing 44 read said `centre [1.301, 19.545]`, so the left and right torn edges
// below the first 403 device pixels were stretched 19.5 times along their length, which is what
// made the treads firing 29 traced (39 px on the left contour, against the item's 4). That is four
// times worse than not slicing at all.
//
// WHAT IS MEASURED HERE. The centre band's magnification on the vertical axis, computed exactly
// the way `CaptureHooks.paperSurfaces` computes the sidecar's `centre`, for the seven distinct
// big-sheet geometries among the eight pieces firing 46 named (05_settings_interrupt repeats 05_settings), off their own drawn sizes and packed masks. It must be at most half what 0.4
// gave, or at the 4x cap where half would be under it, and no piece up to 1.6x its mask may be sliced differently than before, which
// is the population clause: the 156 small pieces that the fixed slice served are not touched.
//
// WHAT IT CANNOT REACH, stated so it is not mistaken for the item closing. The item's floor is 4x.
// A sheet 4.886x its PACKED mask cannot get under 4x by any slice. Only a larger source can, and
// firing 51 measured that route's cost first: `MaskCache` never evicts, and 12_search alone holds
// 27 masks and 27 edges, 181 MB decoded at today's 1024 packing. The masks alone would be 244 MB at
// their authored 2048. This test is the slice half of the route, and it does not claim the resolution half.
//
// RE-BREAK: set `SlicedMasks.fibres` to 0.4. Every piece is then sliced at 0.4 again, and the
// setup sheet's centre goes back to 19.545 and fails the halving clause below.

import 'package:flutter_test/flutter_test.dart';
import 'package:desk/material/paper.dart';

/// The sidecar's `centre` on one axis, as `CaptureHooks` derives it: the nine-slice's middle band
/// inside the composition, times the shader's stretch of the composition over the piece.
double centre(double src, double drawn, double composed, double slice) {
  final fixed = src * 2 * slice;
  final middleSrc = src * (1 - 2 * slice);
  final middleDst = composed - fixed * (composed < fixed ? composed / fixed : 1.0);
  if (middleSrc <= 0 || middleDst <= 0) return 0;
  return middleDst / middleSrc * (drawn / composed);
}

void main() {
  // name, packed mask height, drawn height in device px -- off firing 46's reading of the
  // committed sidecars and app/assets/INDEX.json.
  const sheets = <(String, double, double)>[
    ('17_setup_pwa/tear_004', 824, 4026),
    ('05_settings/tear_020', 626, 3091),
    ('03_us/tear_020', 626, 2491),
    ('14_media_viewer/tear_004', 824, 2195),
    ('14_media_viewer/tear_031', 929, 1646),
    ('02_chat/tear_036', 571, 1559),
    ('03_us/tear_043', 801, 1451),
  ];

  test('the setup sheet reproduces the sidecar at the old slice, which proves the arithmetic', () {
    const mh = 824.0, drawn = 4026.0;
    final composed = drawn.clamp(1, mh * 4).toDouble();
    expect(centre(mh, drawn, composed, 0.4), closeTo(19.545, 0.005));
  });

  test('every big sheet has its torn sides stretched half as much or less', () {
    for (final (name, mh, drawn) in sheets) {
      final composed = drawn.clamp(1, mh * 4).toDouble();
      final before = centre(mh, drawn, composed, 0.4);
      final after = centre(mh, drawn, composed, SlicedMasks.sliceFor(mh, composed));
      // ignore: avoid_print
      print('$name: vertical centre ${before.toStringAsFixed(2)}x -> ${after.toStringAsFixed(2)}x');
      if (before <= SlicedMasks.cap) continue;
      expect(after, lessThanOrEqualTo(before / 2 > SlicedMasks.cap ? before / 2 : SlicedMasks.cap + 1e-9),
          reason: '$name still draws its torn sides at ${after.toStringAsFixed(2)}x, from '
              '${before.toStringAsFixed(2)}x at the fixed slice');
    }
  });

  test('a piece up to 1.6x its mask is sliced exactly as before', () {
    for (var r = 0.1; r <= 1.6; r += 0.05) {
      expect(SlicedMasks.sliceFor(1000, 1000 * r), SlicedMasks.edge,
          reason: 'a piece ${r.toStringAsFixed(2)}x its mask is no longer sliced at 0.4');
    }
  });

  test('the fixed band never gets thinner than the fibres it holds', () {
    for (var r = 1.0; r <= 8; r += 0.25) {
      expect(SlicedMasks.sliceFor(1000, 1000 * r), greaterThanOrEqualTo(SlicedMasks.fibres));
    }
    // the deepest fibre measured on a mask that backs a big sheet
    expect(SlicedMasks.fibres, greaterThanOrEqualTo(0.227));
  });
}
