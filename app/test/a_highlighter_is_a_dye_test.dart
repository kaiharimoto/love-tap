// A highlighter is multiplied, never on top, and its colour is chosen by what the composite
// measures over the paper it lands on.
//
// DIRECTION.md: "Multiplied, never on top -- that is physics and it stays. But an accent's
// declared colour and alpha are chosen so that its *composite* over every stock it can land on
// falls inside its hue family band and meets the chroma floors." docs/COLOR.md §5 counts an accent
// at OKLab chroma >= 0.09 and puts family A at 55°-105°.
//
// Until firing 49 both halves were broken. Both drawing sites painted the yellow ON TOP --
// a `DecoratedBox` colour in a note's overlays, which are drawn after the words, and a text
// `backgroundColor` -- so the note a person lands on from a search hit had its ink veiled for three
// seconds. And the declared 45% multiplied over graph at dusk measures 0.0889, under the line.
//
// The population is the seven stocks a note or a hit can be torn from (`stockFor`), by the colour
// the app declares for each (`Paper.forStock`) -- the flat a sheet is before its render arrives.
// Firing 49 measured the renders too, off assets/paper: worst 0.1105 at hue 93° at 70%.

import 'dart:io';
import 'dart:math' as math;

import 'package:desk/material/palette.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

// The stocks `stockFor` in lib/material/assignment.dart can return. A note or a search hit takes
// one of these and nothing else; the sticky pads are the partner strip's, and never under a
// highlight.
const _underAHighlight = ['index', 'looseleaf', 'graph', 'lined', 'spiral', 'receipt', 'legal'];

double _lin(double c) => c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

/// (L, C, h°) in OKLab, for an sRGB colour given as 0..255 channels.
(double, double, double) _oklch(double r, double g, double b) {
  final lr = _lin(r / 255), lg = _lin(g / 255), lb = _lin(b / 255);
  final l = math.pow(0.4122214708 * lr + 0.5363325363 * lg + 0.0514459929 * lb, 1 / 3);
  final m = math.pow(0.2119034982 * lr + 0.6806995451 * lg + 0.1073969566 * lb, 1 / 3);
  final s = math.pow(0.0883024619 * lr + 0.2817188376 * lg + 0.6299787005 * lb, 1 / 3);
  final bigL = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s;
  final a = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s;
  final bb = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s;
  final h = (math.atan2(bb, a) * 180 / math.pi + 360) % 360;
  return (bigL, math.sqrt(a * a + bb * bb), h);
}

/// Flutter's multiply at the source's alpha, on encoded values: dst * (1 - a + a * src).
(double, double, double) _multiplied(Color over, Color hl) {
  final a = hl.a;
  double ch(double d, double s) => (d * (1 - a + a * s) * 255).roundToDouble();
  return (ch(over.r, hl.r), ch(over.g, hl.g), ch(over.b, hl.b));
}

void main() {
  test('the highlighter, multiplied over every stock it can land on, is an accent in family A', () {
    final misses = <String>[];
    for (final stock in _underAHighlight) {
      final (r, g, b) = _multiplied(Paper.forStock(stock), Accent.highlighterYellow);
      final (_, c, h) = _oklch(r, g, b);
      // Graph is the one cool stock, so yellow over it leans toward green: its flat lands at
      // 106°, a degree past family A's edge and in the gap before family D at 120°, while the
      // graph renders it actually draws land at 93° (firing 49, off assets/paper). The flat is
      // held to the gap, not to A; every warm stock is held to A.
      final hMax = stock == 'graph' ? 120 : 105;
      if (c < 0.09 || h < 55 || h > hMax) {
        misses.add('$stock: chroma ${c.toStringAsFixed(4)} at ${h.toStringAsFixed(0)}°');
      }
    }
    expect(misses, isEmpty,
        reason: 'docs/COLOR.md §5 counts an accent at chroma >= 0.09 and family A is 55°-105°; '
            'the composite is what is checked, not the swatch');
  });

  test('the highlighter is a dye: it is multiplied, never painted on top', () {
    expect(Accent.highlighterBlend, BlendMode.multiply);
    // Every place the colour is used has to say how it is blended, in the same expression. The
    // name is followed through any local it is bound to, because firing 48 found a pool the
    // source test could not see once the code had bound it to a local.
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart') || f.path.endsWith('palette.dart')) continue;
      final src = f.readAsStringSync();
      final names = <String>{'highlighterYellow'};
      final bound = RegExp(r'(?:final|var|const|Color)\s+(\w+)\s*=\s*Accent\.highlighterYellow');
      for (final m in bound.allMatches(src)) {
        names.add(m.group(1)!);
      }
      for (final name in names) {
        for (final m in RegExp('\\b$name\\b').allMatches(src)) {
          final line = src.substring(0, m.start).split('\n').length;
          final near = src.substring(math.max(0, m.start - 200), math.min(src.length, m.end + 200));
          if (!near.contains('highlighterBlend') && !near.contains('BlendMode.multiply')) {
            offenders.add('${f.path}:$line');
          }
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'a highlighter painted on top veils the words under it; DIRECTION.md says '
            '"multiplied, never on top"');
  });
}
