// The rule was stated in one file and implemented in six.
//
// `material/assignment.dart` opens with the rule the brief sets: *no two tears visible at once may
// be the same ... the pool is walked by a stride derived from each event's id so that consecutive
// events never land on the same mask*. That is true of `tearFor`. It was not true of the app,
// because five other places reached into the pool themselves:
//
//   * `Slip.build` and `Strip.build` each carried their own copy of `masks[((row % n) * stride) % n]`,
//     with `Strip` calling `Slip._stride` to share half of it;
//   * `material/desk.dart` took `tears[hashOf(state.mood!) % tears.length]` — so the partner strip
//     changed its torn edge when the partner's mood changed, which is a piece of paper becoming a
//     different piece of paper because somebody felt differently;
//   * `regions/pulse/pulse_region.dart` took `masks[(partner.index * 7 + 11) % masks.length]` and
//     `masks[masks.length - 3]`;
//   * `setup/setup_region.dart` took `writableTears[3]`, a constant — which is why
//     `17_setup_pwa.surfaces.json` has two pieces and one mask between them.
//
// **Three of the six took no row at all.** That is what made
// `a-slip-with-no-row-takes-the-same-tear-as-every-other-slip-with-no-row` unfixable as filed: the
// repair is to give each list its own window in the pool, and a call site that has nowhere to put
// a row has nowhere to put a lane either. Firing 41 measured the repeats and found three
// mechanisms; this is the thing under all three.
//
// So this test reads the source. That is unusual here and it is the right instrument for this one
// claim: the defect is not a value any screen declares, it is a call that exists at all, and a
// widget test cannot see a call site that today happens to agree with the walk. WORKER_PROMPT 3d
// allows the source as an anchor, via a test, for exactly a registry or a token.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nothing outside assignment.dart indexes the mask pool', () {
    final offenders = <String>[];
    // `[` after the getter is the whole of it: reading `.length`, `.isEmpty` or the list itself is
    // fine and happens in the capture hooks and in the tests. Taking an element by a computed
    // index is the thing that cannot be namespaced.
    final index = RegExp(r'(writableTears|tearMasks|scrapTears)\s*\[');
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      if (f.path.endsWith('material/assignment.dart')) continue;
      final src = f.readAsStringSync();
      for (final (i, line) in src.split('\n').indexed) {
        if (line.trimLeft().startsWith('//') || line.trimLeft().startsWith('///')) continue;
        if (index.hasMatch(line)) offenders.add('${f.path}:${i + 1}: ${line.trim()}');
      }
    }
    expect(offenders, isEmpty,
        reason: 'the mask pool is indexed outside material/assignment.dart, so the walk the file '
            'documents is not the walk the app performs and a lane cannot be given to these call '
            'sites:\n${offenders.join('\n')}\nUse tearAt(lib, lane: ..., row: ...).');
  });
}
