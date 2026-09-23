// Every screen with the partner's strip on it carries one coloured thing: a pressed clover.
//
// docs/COLOR.md §7 item 5 asks every room still for 1% of its pixels at OKLab chroma >= 0.09, and
// item 6 for that area to be an object outside family A. Firing 49 measured that the only object in
// the library that can be one is the clover (family D, 120-165 degrees), and firing 53 refuted the
// blocker that parked it. The strip is at the top of eight of the nine room stills, so the clover
// lies across its right end.
//
// What is measured here is the rendered strip, at the capture's 480x1040 at 3x, over the desk:
// the pixels over the floor, their hue, and where they are. The still's own reading is
// `tools/check/palette.py` on the next capture; this is the prediction it will be held to, and the
// guard that the clover does not shrink, go out, or turn up under the status line.
//
// RE-BREAK: set `PartnerStrip.cloverSize` to 60, or take the clover out of the strip.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:desk/material/desk.dart';
import 'package:desk/material/library.dart';
import 'package:desk/spine/projections/state.dart';
import 'package:desk/spine/spine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// OKLab chroma and hue of one sRGB pixel, as `tools/check/palette.py` computes them.
(double, double) chromaHue(int r8, int g8, int b8) {
  double lin(int c) {
    final v = c / 255.0;
    return v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  }

  final r = lin(r8), g = lin(g8), b = lin(b8);
  final l = math.pow(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b, 1 / 3);
  final m = math.pow(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b, 1 / 3);
  final s = math.pow(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b, 1 / 3);
  final a = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s;
  final bb = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s;
  final h = (math.atan2(bb, a) * 180 / math.pi + 360) % 360;
  return (math.sqrt(a * a + bb * bb), h);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await MaterialLibrary.load();
  });

  testWidgets('the strip carries 1% of the screen in family D, and not under the words',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final state = PersonState(Person.teo, {
      for (final (k, v) in [
        ('status_line', 'week one, and the room smells right again'),
        ('mood', 'bright'),
        ('place', 'travelling'),
        ('need', 1),
        ('energy', 2),
        ('battery', 72),
      ])
        k: SignalValue(signal: k, value: v, at: 0, declared: true),
    });
    Widget screen() => RepaintBoundary(
          key: const ValueKey('shot'),
          child: Desk(
            child: Column(children: [
              PartnerStrip(partner: Person.teo, state: state, nowMs: 0),
              const Spacer(),
            ]),
          ),
        );
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: screen())));
    // decode every picture outside the fake-async zone, where an image future never completes
    await tester.runAsync(() async {
      for (final e in find.byType(Image).evaluate().toList()) {
        await precacheImage((e.widget as Image).image, e);
      }
    });
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: screen())));
    await tester.pump();

    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
    final shot = boundary.toImageSync(pixelRatio: 3.0);
    late ByteData? data;
    await tester.runAsync(() async {
      data = await shot.toByteData(format: ui.ImageByteFormat.rawRgba);
      final png = await shot.toByteData(format: ui.ImageByteFormat.png);
      final out = Platform.environment['CLOVER_PNG'];
      if (out != null) File(out).writeAsBytesSync(png!.buffer.asUint8List());
    });
    final px = data!.buffer.asUint8List();
    final w = shot.width, h = shot.height;

    // the status line's own box, in device pixels, which the clover must stay out of
    final status = tester.getRect(find.textContaining('week one'));
    final words = Rect.fromLTRB(status.left * 3, status.top * 3, status.right * 3, status.bottom * 3);
    final painted = tester.renderObject<RenderParagraph>(find.textContaining('week one'));
    final inkWidth = painted.getMaxIntrinsicWidth(double.infinity) * 3;

    var accent = 0, green = 0, underWords = 0, ruleUnderWords = 0;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = (y * w + x) * 4;
        final (c, hue) = chromaHue(px[i], px[i + 1], px[i + 2]);
        if (c < 0.09) continue;
        accent++;
        if (hue < 120 || hue > 165) {
          // the strip stock's printed red margin rule, which the status line used to be written
          // across (a_word_is_written_beside_the_margin_test.dart)
          if (words.contains(Offset(x.toDouble(), y.toDouble()))) ruleUnderWords++;
          continue;
        }
        green++;
        if (words.contains(Offset(x.toDouble(), y.toDouble())) && x < words.left + inkWidth) {
          underWords++;
        }
      }
    }
    final frame = 1440 * 3120;
    // ignore: avoid_print
    print('accent ${accent}px = ${(accent / frame).toStringAsFixed(5)} of the still; family D '
        '${(green / math.max(1, accent)).toStringAsFixed(3)} of it; under the status line: $underWords clover, $ruleUnderWords rule');
    expect(w, 1440);
    expect(accent / frame, greaterThanOrEqualTo(0.0105),
        reason: 'the clover no longer carries 1% of the screen, with the 2% palette.py\'s '
            '700-pixel sampling takes off an edge');
    expect(green / accent, greaterThan(0.9), reason: 'the accent area is not the clover');
    expect(underWords, 0, reason: 'the clover is over the partner\'s words');
    expect(ruleUnderWords, 0, reason: 'the partner\'s words are written across the margin rule');
  });
}
