// A piece of paper on a desk casts a shadow onto the desk.
//
// For four review cycles it did not, and the reason was one default. The baked contact shadow is
// framed a quarter wider than the piece — the visible part of a contact shadow is the part the
// paper is not covering — and it is drawn inside a Stack, which clips to its own bounds unless
// told otherwise. So every visible part of every shadow in the app was cut off, leaving only the
// part underneath the paper, which the paper then covers. Two critics and a completeness pass
// measured the same null: with the tear ink excluded, the desk beside a note has the same median
// luminance in every direction at every distance.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the stack a piece is composed in does not clip its shadow', () {
    final src = File('lib/material/paper.dart').readAsStringSync();
    final at = src.indexOf('_tornShadow(context, suffix) else _cutShadow(dusk)');
    expect(at, greaterThan(0), reason: 'the shadow is no longer composed where this test looks');
    // the Stack that holds it, reading backwards from the shadow to the widget that contains it
    final before = src.substring(0, at);
    final stackAt = before.lastIndexOf('Stack(');
    expect(stackAt, greaterThan(0));
    final head = src.substring(stackAt, at);
    expect(head, contains('Clip.none'),
        reason: 'the piece is composed in a Stack that clips, so the part of the contact shadow '
            'that falls on the desk — the only part anyone sees — is cut off:\n$head');
  });

  test('every baked shadow is warm, because a shadow on a wooden desk is not black', () {
    // The renders are RGB 0,0,0 through their alpha, and a large part of each one is fully
    // opaque, because that part is meant to be under the thing casting it: measured,
    // obj_dog_ear_shadow is 17.4 per cent alpha above 240 against the object's own 18.7, and 35
    // to 47 per cent of each tear shadow is above 240. Wherever the offset or the stretch puts
    // that core beside the paper instead of under it, what lands on the desk is black — luma 4.3
    // beside a chip in 12_search, and a hard black quadrilateral behind the torn card in
    // 01_pulse's object row, where the desk either side reads 84 to 103.
    //
    // A contact shadow is the desk with the light taken out of it. It is warm and it is dark and
    // it is never a hole, so both paths put the render through Shadow.warm and keep only its
    // alpha. tools/check/holes.py measures the result on the glass.
    // Anchored on the call that actually draws the render, not on the word: in objects.dart the
    // first `_shadow` is the widget being *asked* for, three hundred lines above the draw.
    final draws = {
      'lib/material/paper.dart': 'Widget _tornShadow(',
      'lib/material/objects.dart': 'class _Shadow extends StatelessWidget',
    };
    draws.forEach((f, anchor) {
      final src = File(f).readAsStringSync();
      final at = src.indexOf(anchor);
      expect(at, greaterThan(0), reason: '$f no longer draws a baked shadow where this looks');
      // Wide enough for the whole function, which is mostly the account of how it went wrong
      // twice. At 2600 the window stopped short of the draw itself once the shadow's placement
      // was written down, and this read as the colour having been taken out.
      final block = src.substring(at, (at + 4600).clamp(0, src.length));
      expect(block, anyOf(contains('ColorFilter.mode(Shadow.warm, BlendMode.srcIn)'),
              contains('tint: Shadow.warm')),
          reason: '$f draws its baked shadow in the colour it was rendered in, which is black');
    });
  });

  test('a torn sheet\'s shadow is cut by its own tear and sliced by its own bands', () {
    // The lesson this replaces, kept because it cost the most. Nine-slicing the Blender shadow was
    // half of a fix for black leaking past the paper and it cost the contact shadow altogether:
    // drawImageNine draws the four corners at their source pixel size, and the outer four tenths
    // of a 451 by 799 render is 180 by 320 pixels dropped into a piece often 420 by 160, so they
    // overlap, overflow and squeeze, and what is left outside the paper is nothing.
    //
    // The render is gone. It was never going to cast a shadow whatever it was framed by: measured
    // over all 56 packed tears, its alpha is 0.095 at the paper's own edge and gone within two per
    // cent of the piece, because in it the sheet lies nearly flat and its shadow is genuinely
    // underneath it. `tools/bake_tear_shadows.py` makes the shadow from the mask instead — the
    // silhouette that actually casts it — with `_CutShadow`'s two passes and its own numbers. That
    // *is* nine-sliced, and must be: sliced by the tear's own bands the offset and the blur keep
    // the size they were baked at however tall the sheet turns out to be, which is the same rule
    // the fibres follow and the reason a small card's shadow is not a fifth of a note's.
    final src = File('lib/material/paper.dart').readAsStringSync();
    final at = src.indexOf("tearAsset('\${tearId!}_shadow");
    expect(at, greaterThan(0), reason: 'the torn shadow is not drawn where this test looks');
    final block = src.substring((at - 1400).clamp(0, src.length), (at + 900).clamp(0, src.length));
    expect(block, contains('NineSliced'),
        reason: 'a shadow stretched to the piece is a fraction of the piece rather than of the '
            'lift, and a chip gets a fifth of a note\'s shadow for the same paper on the same desk');
    expect(block, contains('tint: Shadow.warm'),
        reason: 'an untinted shadow render is black, and black on the wood is a hole');

    // and the bands are the tear's, not the four-tenths default
    final bandAt = src.indexOf('static List<double> bandOf(');
    expect(bandAt, greaterThan(0));
    final bandBlock = src.substring(bandAt, bandAt + 900);
    expect(bandBlock, contains("_shadow"),
        reason: 'a shadow carries no band of its own in the index, so bandOf has to look up the '
            'tear it belongs to or it falls back to four tenths');
  });

  test('the baked shadow is sampled with a filter that cannot overshoot', () {
    // A shadow render is a dark shape inside a transparent border. A mipmapped or cubic sampler
    // rings at a boundary like that and lands a *bright* row just outside the dark one — which is
    // the pale straight rule that lay on the wood a few tens of pixels under every sheet, full
    // width, parallel to the paper, in nine of ten stills for five cycles. It outlived being
    // blamed on the desk asset, on the piece's bounding box, on the mask inset, on the denoiser
    // and on the rotation, because none of those is where it comes from. Bilinear cannot
    // overshoot.
    final src = File('lib/material/paper.dart').readAsStringSync();
    final at = src.indexOf("tearAsset('\${tearId!}_shadow");
    expect(at, greaterThan(0), reason: 'the baked shadow is not drawn where this test looks');
    // Backwards as well as forwards: the asset name is the argument, and the Paint that samples
    // it is set up around the call rather than only after it.
    final block = src.substring((at - 900).clamp(0, src.length), (at + 2400).clamp(0, src.length));
    expect(block, contains('FilterQuality.low'),
        reason: 'the shadow is sampled with a filter that can ring, and a ring outside a dark '
            'edge is a bright line on the desk');
  });

}
