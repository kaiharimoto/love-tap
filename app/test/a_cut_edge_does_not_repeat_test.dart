// A cut edge wanders; it does not ripple.
//
// The outline every whole card is clipped to used to be two sines along each edge, and two sines
// are two periods however they are weighted. A material critic measured the 'let it interrupt you'
// bar in 05_settings at an rms deviation of 0.34 px and a peak-to-peak of 2.7 over 1,300 px on its
// top edge, 0.19 and 1.4 on its bottom — dead straight with a ripple in it — and autocorrelated the
// same shape on the rig's torn edges at 0.50 at one period and 0.49 at two.
//
// Measured the way the critic measures a silhouette, and past the central lobe: any continuous
// outline correlates with itself at small lags, which is what continuous means. A period is what
// brings the correlation back after it has fallen through zero.
import 'dart:math' as math;

import 'package:desk/material/paper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The top edge's deviation from the straight line between its ends, one sample per pixel.
List<double> _topEdge(Size size, int seed) {
  final pts = cutOutline(size, seed);
  // the first run is the top edge: steps + 1 points from left to right
  final top = <Offset>[];
  for (final p in pts) {
    if (top.isNotEmpty && p.dx < top.last.dx) break;
    top.add(p);
  }
  final out = <double>[];
  for (var x = top.first.dx; x < top.last.dx; x += 1.0) {
    var i = 0;
    while (i < top.length - 2 && top[i + 1].dx < x) {
      i++;
    }
    final a = top[i], b = top[i + 1];
    final f = (b.dx - a.dx).abs() < 1e-9 ? 0.0 : (x - a.dx) / (b.dx - a.dx);
    out.add(a.dy + (b.dy - a.dy) * f);
  }
  return out;
}

({double rms, double span, double worstCorrelation, int atLag}) _measure(List<double> v) {
  const k = 31;
  final hp = <double>[];
  for (var i = 0; i < v.length; i++) {
    var sum = 0.0;
    for (var j = -k ~/ 2; j <= k ~/ 2; j++) {
      sum += v[(i + j).clamp(0, v.length - 1)];
    }
    hp.add(v[i] - sum / k);
  }
  final mean = hp.reduce((a, b) => a + b) / hp.length;
  for (var i = 0; i < hp.length; i++) {
    hp[i] -= mean;
  }
  final zero = hp.map((e) => e * e).reduce((a, b) => a + b);
  double ac(int lag) {
    var s = 0.0;
    for (var i = 0; i + lag < hp.length; i++) {
      s += hp[i] * hp[i + lag];
    }
    return s / zero;
  }

  var lobe = 1;
  while (lobe < hp.length ~/ 3 && ac(lobe) >= 0) {
    lobe++;
  }
  var worst = -1.0;
  var at = lobe;
  for (var l = lobe; l < hp.length ~/ 3; l++) {
    final c = ac(l);
    if (c > worst) {
      worst = c;
      at = l;
    }
  }
  final rms = math.sqrt(hp.map((e) => e * e).reduce((a, b) => a + b) / hp.length);
  return (rms: rms, span: v.reduce(math.max) - v.reduce(math.min),
      worstCorrelation: worst, atLag: at);
}

void main() {
  test('a long cut edge wanders without repeating', () {
    // A long edge, because an autocorrelation is only as good as the samples under it: on a
    // 448-point card a lag of a hundred has three hundred products behind it and the estimate
    // wanders by a tenth on its own. This is the same outline code, asked for a longer piece.
    const long = Size(1343, 139);
    for (final seed in [1, 77, 4242, 99991]) {
      final m = _measure(_topEdge(long, seed));
      // ignore: avoid_print
      print('long edge, seed $seed: worst self-correlation past the central lobe '
          '${m.worstCorrelation.toStringAsFixed(2)} at lag ${m.atLag}');
      expect(m.worstCorrelation, lessThan(0.45),
          reason: 'seed $seed repeats: ${m.worstCorrelation} at lag ${m.atLag}');
    }
  });

  test('a cut edge is straight but not drawn with a ruler', () {
    // the bar a material critic measured: x 48-1391 of a 1440 px still at three device pixels a
    // logical point, so 448 logical points across and 46 tall. They read an rms of 0.34 device px
    // on its top edge and 0.19 on its bottom and called it dead straight. A guillotine-cut card
    // *is* straight — that decline stands — but a straight edge still has fibre in it, and this
    // asks for enough of it to be there at 300 per cent.
    const bar = Size(448, 46);
    for (final seed in [1, 77, 4242, 99991]) {
      final m = _measure(_topEdge(bar, seed));
      // ignore: avoid_print
      print('the bar, seed $seed: rms ${(m.rms * 3).toStringAsFixed(2)} device px, span '
          '${(m.span * 3).toStringAsFixed(2)} device px');
      expect(m.rms * 3, greaterThan(0.45),
          reason: 'seed $seed draws a straight line: rms ${m.rms * 3} device px');
      expect(m.span * 3, lessThan(12.0),
          reason: 'seed $seed tore the card instead of cutting it: ${m.span * 3} device px');
    }
  });

  test('the same seed cuts the same card every time', () {
    final a = cutOutline(const Size(400, 220), 12345);
    final b = cutOutline(const Size(400, 220), 12345);
    expect(a.length, b.length);
    for (var i = 0; i < a.length; i++) {
      expect(a[i], b[i]);
    }
    expect(cutOutline(const Size(400, 220), 12346), isNot(equals(a)));
  });
}
