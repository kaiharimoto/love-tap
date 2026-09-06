// The room a feeling's object needs does not depend on how hard it was thrown.
//
// It used to: the box was size × ink × (0.88 + 0.24 × intensity), so a landing — which animates
// intensity — re-laid-out everything under the object while it arrived. The clip of a feeling the
// couple made caught it as two brightness jumps a frame apart, and the frames show the whole of
// Settings shifting under an arriving object.
import 'package:desk/feelings/builtins.dart';
import 'package:desk/material/library.dart';
import 'package:desk/material/objects.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async => MaterialLibrary.load());

  testWidgets('an object takes the same room however hard it arrives', (tester) async {
    final feeling = kBuiltInFeelings.firstWhere((f) => f.object == 'obj_candle',
        orElse: () => kBuiltInFeelings.first);
    final sizes = <Size>[];
    for (final intensity in [0.1, 0.5, 1.0]) {
      await tester.pumpWidget(MaterialApp(
        home: Center(
          child: FeelingObject(feeling: feeling, size: 80, intensity: intensity),
        ),
      ));
      await tester.pump();
      sizes.add(tester.getSize(find.byType(FeelingObject).first));
    }
    expect(sizes[0], sizes[1], reason: 'the box moved between intensity 0.1 and 0.5: $sizes');
    expect(sizes[1], sizes[2], reason: 'the box moved between intensity 0.5 and 1.0: $sizes');
    expect(sizes[0].width, greaterThan(0));
  });
}
