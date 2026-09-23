// A photograph is stuck to its note with a strip of tape, not with whatever bit the hash lands on.
//
// THE DEFECT THIS IS THE RULER FOR. `Print` took `bits[hashOf(item.id) % bits.length]` over the whole
// bit family. That is 44 files: 11 bodies of five kinds, 11 dusk twins and 22 shadows. So a
// photograph was taped down with a pin, a smear of glue or a shadow file three times in four. On
// firing 51's capture, 14_media_viewer declares `pin_01.webp` and `tape_04_shadow.webp` and 02_chat
// declares `pin_01_dusk_shadow.webp`, all drawn where a tape goes. Every bit rendered empty until
// firing 51, so none of it could be seen until the fix that made the bits visible.
//
// RE-BREAK: put `bits[hashOf(item.id) % bits.length].id` back in blob_widgets.dart. The source
// clause below fails on it, and so would a capture.

import 'dart:io';

import 'package:desk/material/library.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await MaterialLibrary.load();
  });

  test('the tapes are the four tape bodies and nothing else in the family', () {
    final lib = MaterialLibrary.instance;
    expect(lib.bits.length, 44, reason: 'the family the tapes are chosen out of moved');
    expect(lib.tapeIds, ['tape_01', 'tape_02', 'tape_03', 'tape_04']);
  });

  test('under the lamp a tape is its dusk render, and by day its day one', () {
    final lib = MaterialLibrary.instance;
    for (final t in lib.tapeIds) {
      expect(lib.bitUnder(t, dusk: true), '${t}_dusk');
      expect(lib.bitUnder(t, dusk: false), t);
    }
  });

  test('nothing in the app indexes the whole bit family', () {
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      if (RegExp(r'bits\s*\[').hasMatch(src)) offenders.add(f.path);
    }
    expect(offenders, isEmpty,
        reason: 'a bit picked by index out of all 44 files is a shadow or a dusk twin half the time');
  });
}
