// A paragraph that a clip cuts short says so, so a ruler does not read the cut as faint ink.
//
// THE DEFECT THIS IS THE RULER FOR. Firing 49 recorded 12_search's last hit, `monday. the bus has
// that smell...`, as a new legibility failure. Its second line was declared 34 px tall against a
// 68 px line pitch, ending on the frame's last row, in a sidecar saying `clipped: 0`. The list had
// scrolled past the viewport, which is ordinary. But nothing could tell the ruler, because
// `CaptureHooks._paragraph` cuts every rect to its clips before `scene.js` sees it. scene.js's
// test for a clamped rect was comparing a rect with itself (firing 51).
//
// WHAT IS MEASURED HERE. One list whose last paragraph is laid out past the end of its viewport.
// The cut paragraph must declare `clipped: true`, the whole ones must not, and every paragraph on
// screen must still be declared. That last part is the population clause: a fix that dropped the
// cut run would also make it stop failing.
//
// RE-BREAK: remove the `if (cut) 'clipped': true` entry from `_paragraph`. The first expectation
// then fails with the last paragraph declared as whole.

import 'package:desk/capture/hooks.dart';
import 'package:desk/material/hands.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a paragraph a viewport cuts short declares that it was cut', (tester) async {
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    const texts = ['the first hit', 'the second hit', 'the third hit, which the frame cuts'];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            // the viewport ends 40 logical px into the third paragraph's 120
            SizedBox(
              height: 280,
              child: ListView(
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final t in texts)
                    SizedBox(height: 120, child: Text(t, style: Hands.noor().copyWith(fontSize: 40, height: 2.5))),
                ],
              ),
            ),
          ],
        ),
      ),
    ));
    await tester.pump();

    final runs = {for (final r in CaptureHooks.textRuns()) r['text'] as String: r};
    expect(runs.keys, containsAll(texts), reason: 'a cut run must still be declared: $runs');
    expect(runs[texts[2]]!['clipped'], isTrue,
        reason: 'the third paragraph is cut 40 px into its 120 and declared ${runs[texts[2]]}');
    expect(runs[texts[0]]!.containsKey('clipped'), isFalse);
    expect(runs[texts[1]]!.containsKey('clipped'), isFalse);
  });
}
