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
    final at = src.indexOf('_bakedShadow(context, suffix) else _cutShadow(dusk)');
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
      'lib/material/paper.dart': 'Widget _bakedShadow(',
      'lib/material/objects.dart': 'class _Shadow extends StatelessWidget',
    };
    draws.forEach((f, anchor) {
      final src = File(f).readAsStringSync();
      final at = src.indexOf(anchor);
      expect(at, greaterThan(0), reason: '$f no longer draws a baked shadow where this looks');
      final block = src.substring(at, (at + 2600).clamp(0, src.length));
      expect(block, contains('ColorFilter.mode(Shadow.warm, BlendMode.srcIn)'),
          reason: '$f draws its baked shadow in the colour it was rendered in, which is black');
    });
  });

  test('a sheet casts a shadow at all, and it is not nine-sliced', () {
    // The other half, and the more expensive lesson. Nine-slicing the shadow was half of a fix for
    // black leaking past the paper, and it cost the contact shadow altogether: drawImageNine draws
    // the four corners at their *source* pixel size, and the outer four tenths of a 451 by 799
    // render is 180 by 320 pixels dropped into a piece often 420 by 160, so they overlap, overflow
    // and are squeezed, and what is left outside the paper is nothing. Measured on the hero: the
    // desk 4 to 14 pixels under a sheet read 88.32 against 87.88 further down, half a level the
    // wrong way, against 14.42 the right way on the capture before it. A material critic found it
    // by walking outward from an edge, and holes.py gates on it now.
    //
    // The leak was never the geometry. It was the colour: those renders are black at alpha 255
    // over a third of their area, because that third is under the paper.
    final src = File('lib/material/paper.dart').readAsStringSync();
    final at = src.indexOf("tearAsset('\${tearId!}_shadow");
    // Wide enough to hold the comment that explains it: this block earns its length.
    final block = src.substring((at - 1400).clamp(0, src.length), (at + 2400).clamp(0, src.length));
    expect(block, contains('BoxFit.fill'),
        reason: 'the shadow is framed some other way than the one that casts one');
    expect(block, isNot(contains('NineSliced')),
        reason: 'a nine-sliced shadow has no penumbra outside the paper');
    expect(block, contains('ColorFilter.mode(Shadow.warm'),
        reason: 'an untinted shadow render is black, and black on the wood is a hole');
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
