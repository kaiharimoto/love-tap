// Nothing the two phones both draw is chosen by `hashCode`.
//
// `DIRECTION.md` says it twice and `the_same_paper_on_both_phones_test.dart` is named for it: the
// same thing is the same piece of paper on both phones. That law has now been broken three times
// by three different mechanisms, and all three are one sentence — **an arithmetic that is not the
// same arithmetic in a browser as it is on a phone**.
//
//   * `hashOf` multiplied past 2^53 and the product rounded. Repaired before firing 36.
//   * `UlidFactory.next` peeled a 48-bit time with `& 31` and `>>= 5`, and a web `int` is a double
//     on which those are 32-bit operations. Repaired at firing 38; it had given every one of the
//     14,061 seeded events a different id in the PWA than on the phone.
//   * And this one: fourteen places took a `String.hashCode` or an `int.hashCode` and used it to
//     choose something a person looks at. Measured at firing 38 rather than assumed —
//
//       'pad.pulse'                  VM 762877079   web 151588280
//       'f.tender'                   VM 218915526   web 229765906
//       '01KPV0SDX06FA58CJ9JXH23W7R' VM 965547515   web 500903478
//       'calm'                       VM 151166986   web 172139146
//
//     Every string, a different number. A Dart hash code is not a promise about a value, it is a
//     promise about a run; the language says so and this app was reading it as the former. What it
//     picked: the stock and the variant a feeling's scrap is torn from, the tear on the desk, the
//     patch of sheet that shows, the tilt of a note in the viewer and of a reply in the thread,
//     the seed of the hand that draws a tick, a delivery mark and a refusal mark, and the row a
//     margin strip tears along. All of it different on the two phones, all of it silent.
//
// `hashOf` is the app's own hash and is already proven to cross — `the_same_paper_on_both_phones_test`
// checks it against BigInt, and `tools/check/both_phones.sh` runs that check in a real browser. So
// the rule is simply that `hashCode` does not appear where a drawing decision is made, and the
// cheapest way to keep a rule like that is to read the source and say so.
//
// Re-break by putting any one of the fourteen back and watching this fail with its file and line.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `.hashCode` used as a value, rather than the `int get hashCode` an `==` override must declare.
final _usesHashCode = RegExp(r'\.hashCode\b');
final _declaresHashCode = RegExp(r'\bint\s+get\s+hashCode\b');

/// Everything a person looks at. The transport and the spine may hash how they like — a hash used
/// to bucket a map inside one process is exactly what `hashCode` is for.
final _drawn = RegExp(r'lib/(material|feelings|regions)/');

List<File> _sources() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList()
  ..sort((a, b) => a.path.compareTo(b.path));

void main() {
  test('nothing a phone draws is picked by a hash the other phone computes differently', () {
    final offenders = <String>[];
    for (final f in _sources()) {
      if (!_drawn.hasMatch(f.path)) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final t = line.trimLeft();
        if (t.startsWith('//') || t.startsWith('///')) continue;
        if (_declaresHashCode.hasMatch(line)) continue; // an == override, which is required to
        if (_usesHashCode.hasMatch(line)) offenders.add('${f.path}:${i + 1}  ${t.trim()}');
      }
    }
    expect(offenders, isEmpty,
        reason: 'these choose something a person looks at with a hash that is a different number '
            'in the PWA than on the Android build, so the two phones draw different things for the '
            'same note. Use `hashOf` from material/assignment.dart, which is checked against '
            'BigInt and run in a real browser by tools/check/both_phones.sh:\n'
            '${offenders.join('\n')}');
  });

  test('and the file that does the hashing is still reachable from where the drawing happens', () {
    // A guard on the guard. If `hashOf` ever stops being exported from where these files import
    // it, the repair above would be undone by a compile error rather than by this test, and the
    // obvious fix under time pressure is to reach for `hashCode` again.
    final assignment = File('lib/material/assignment.dart');
    expect(assignment.existsSync(), isTrue);
    expect(assignment.readAsStringSync(), contains('int hashOf(String s)'));
  });
}
