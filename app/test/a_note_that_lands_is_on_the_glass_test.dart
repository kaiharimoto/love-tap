// A sheet that is landing is drawn on the frame it arrives on, with the clock stopped.
//
// The thread draws a row that was not there when it was opened as a landing: the sheet comes down
// from a little above and a little large, the way the folded letters from the other phone have
// since the fold player was written. It did it with an opacity ramp, and an opacity ramp starts at
// nothing.
//
// Nothing is wrong with that while a clock is running. A still is taken with the app's clock
// stopped — the harness steps it only inside a `frames` take — so every row that arrived after the
// thread was opened stayed at zero opacity for as long as the shutter was open. Four of
// 13_messenger_states' seven rows took their room and painted nothing: 1,503 image rows of bare
// desk, 48.17 per cent of the frame, with the set's only delivered reply and its only refusal
// among them. Two critics and a completeness pass measured it separately and agreed to the digit.
//
// The same eight lines existed twice, once in the thread and once in the fold player, and the
// second copy carried the fault of the first. There is one Landing now, and this is what it has to
// do: draw the sheet on the first frame, whatever else it is doing to it.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:desk/material/desk.dart';
import 'package:desk/material/library.dart';
import 'package:desk/material/motion.dart';
import 'package:desk/material/paper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// How much of the grab is paper: the desk is dark wood and a sheet is not.
double _paperShare(Uint8List rgba) {
  var bright = 0;
  for (var i = 0; i < rgba.length; i += 4) {
    final l = 0.299 * rgba[i] + 0.587 * rgba[i + 1] + 0.114 * rgba[i + 2];
    if (l > 150) bright += 1;
  }
  return bright / (rgba.length ~/ 4);
}

Future<double> _grab(WidgetTester tester, GlobalKey key) async {
  late double share;
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final rgba = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
    share = _paperShare(rgba);
    image.dispose();
  });
  return share;
}

Future<double> _sheet(WidgetTester tester, {required bool landing}) async {
  final key = GlobalKey();
  tester.view.physicalSize = const Size(900, 900);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  const piece = PaperPiece(
    stockId: 'lined_01',
    tearId: 'tear_004',
    width: 220,
    child: SizedBox(height: 90),
  );
  await tester.pumpWidget(MaterialApp(
    home: RepaintBoundary(
      key: key,
      child: const Desk(
        child: Center(child: SizedBox(width: 260, height: 200, child: _Maybe(piece))),
      ),
    ),
  ));
  // the stock and the tear have to have arrived, or this measures a different fault
  for (var i = 0; i < 30; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump();
  }
  return _grab(tester, key);
}

/// The piece, with or without a landing around it, chosen by the flag the test sets.
class _Maybe extends StatelessWidget {
  const _Maybe(this.child);
  final Widget child;
  static bool landing = false;

  @override
  Widget build(BuildContext context) => landing ? Landing(child: child) : child;
}

void main() {
  testWidgets('a sheet that is landing is drawn on the frame it arrives on', (tester) async {
    await MaterialLibrary.load();

    _Maybe.landing = false;
    final lying = await _sheet(tester, landing: false);
    expect(lying, greaterThan(0.02),
        reason: 'the sheet drew no paper even lying still: $lying');

    _Maybe.landing = true;
    final arriving = await _sheet(tester, landing: true);

    // A landing moves the sheet and changes its size. It must not make it disappear: at worst the
    // six per cent it is drawn larger by, and the eighteen points it is drawn above, move a little
    // of it out of the box.
    expect(arriving, greaterThan(lying * 0.75),
        reason: 'a sheet in mid-landing drew ${(arriving * 100).toStringAsFixed(2)} per cent paper '
            'against ${(lying * 100).toStringAsFixed(2)} for the same sheet lying still, on a frame '
            'with the clock stopped — which is what a still is, and what a landing that fades up '
            'from zero opacity gives it');
  });
}
