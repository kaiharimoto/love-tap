// On a phone with no vibrator, the feeling arriving must move the desk like a knock.
//
// An emotional critic measured the whole-page translation in every frame of 07 and found the
// horizontal component exactly 0 device pixels in all 421 of them. The substitute existed and it
// was one axis: the page went up and came down. A phone buzzing in a hand is pushed, and it is
// pushed in whatever direction the motor happens to throw it.
//
// So the knock has a direction of the feeling's own and a tilt to go with it. Two feelings with
// the same envelope do not move the desk the same way, which matters because the row asks that a
// feeling be identifiable by its pattern alone and this is the whole of that pattern's body here.
import 'package:desk/feelings/builtins.dart';
import 'package:desk/feelings/landing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the desk is knocked sideways as well as up', () {
    for (final f in kBuiltInFeelings) {
      final d = knockDirection(f.id);
      expect(d.dy, lessThan(0), reason: '${f.id} does not lift the desk at all');
      expect(d.dx.abs(), greaterThan(0.0),
          reason: '${f.id} moves the page on one axis, which is a bounce and not a knock');
      // and never further sideways than up: a page that slides as far as it lifts is a swipe
      expect(d.dx.abs(), lessThan(d.dy.abs()),
          reason: '${f.id} slides further than it lifts');
    }
  });

  test('and no two feelings are knocked the same way', () {
    // Distinct, and spread rather than bunched. Not "far apart in angle": the lift dominates by
    // design, so every direction lies in a two-radian arc and a threshold on the angle would only
    // measure that arc. What matters is that the vector is the feeling's own.
    final knocks = {
      for (final f in kBuiltInFeelings)
        f.id: '${knockDirection(f.id).dx.toStringAsFixed(4)},'
            '${knockDirection(f.id).dy.toStringAsFixed(4)}',
    };
    expect(knocks.values.toSet().length, kBuiltInFeelings.length,
        reason: 'two feelings knock the desk in exactly the same direction');
    // and they are not all on one side of it
    final left = kBuiltInFeelings.where((f) => knockDirection(f.id).dx < 0).length;
    expect(left, greaterThan(kBuiltInFeelings.length ~/ 4));
    expect(left, lessThan(kBuiltInFeelings.length * 3 ~/ 4));
  });

  test('the tilt is small enough to be a board and not a spin', () {
    for (final f in kBuiltInFeelings) {
      // a quarter of a degree at full amplitude
      expect(knockTilt(f.id).abs(), lessThan(0.0045), reason: '${f.id} turns the whole page');
    }
    // and it is not always the same way round
    final signs = kBuiltInFeelings.map((f) => knockTilt(f.id) > 0).toSet();
    expect(signs.length, 2, reason: 'every feeling tilts the desk the same way');
  });

  test('and the whole of it goes when the pattern does', () {
    final f = kBuiltInFeelings.first;
    // and it lets go over about a tenth of a second rather than in one frame. An emotional critic
    // tracked the board through 07 against each run's own rest frame: hold at dy -12 on frame 118
    // and dy 0 on frame 119, squeeze -17 then 0, soup -13 then 0 — full deflection to rest in one
    // sixteen-millisecond step, three times out of three, and then 0.000 grey levels of change for
    // thirty frames. An arrival and a sustain with no release.
    final end = f.hapticLengthMs;
    final atEnd = pageLiftAt(f.segments, end);
    if (atEnd > 0.05) {
      expect(pageLiftAt(f.segments, end + 16), greaterThan(atEnd * 0.5),
          reason: '${f.id} is at rest one frame after its pattern ends');
      expect(pageLiftAt(f.segments, end + 96), lessThan(atEnd * 0.5),
          reason: '${f.id} is still deflected a tenth of a second after its pattern ends');
    }
    expect(pageLiftAt(f.segments, f.hapticLengthMs + 400), lessThan(0.02),
        reason: 'the desk is still moving after the pattern has finished');
  });
}
