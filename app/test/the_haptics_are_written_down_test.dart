// `evidence/haptics.json` says what every feeling does to the phone, and this is what makes it
// evidence rather than a second opinion.
//
// A haptic cannot be screenshotted, so the only record of it is a table — and a table is written by
// `tools/check/haptics.py`, which parses the notation in `app/lib/feelings/builtins.dart` in Python.
// That is a second parser for a notation that already has one, and two parsers for one grammar
// drift. When they drift, the evidence stops describing the app and nothing says so: the file still
// looks like a measurement.
//
// So this holds them together. It reads the committed evidence and checks every number in it
// against what `parseHaptic` — the parser the app actually plays — produces from the same string.
// If Python and Dart ever disagree about what `(25@255 off25) ×5` means, this fails, and the file
// is regenerated rather than quietly believed.
import 'dart:convert';
import 'dart:io';

import 'package:desk/feelings/builtins.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the recorded haptics are the haptics the app plays', () {
    // `flutter test` runs from app/, and the evidence lives beside it.
    final file = File('../evidence/haptics.json');
    expect(file.existsSync(), isTrue,
        reason: 'evidence/haptics.json is missing. Write it with '
            '`python3 tools/check/haptics.py --out evidence/haptics.json`.');
    final report = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final rows = (report['rows'] as List).cast<Map<String, dynamic>>();

    expect(rows.length, kBuiltInFeelings.length,
        reason: 'the evidence records ${rows.length} feelings and the app has '
            '${kBuiltInFeelings.length}; regenerate it');
    expect(report['problems'], isEmpty,
        reason: 'docs/FEELINGS.md says no two feelings share a haptic or an object: '
            '${report['problems']}');

    for (final row in rows) {
      final id = row['id'] as String;
      final feeling = kBuiltInById[id];
      expect(feeling, isNotNull, reason: 'the evidence records a feeling the app does not have: $id');

      // the same string on both sides, so a difference below is the parsers and nothing else
      expect(feeling!.haptic, row['haptic'], reason: '$id: the recorded notation is not the app\'s');

      final segments = feeling.segments;
      final envelope = (row['envelope'] as List).cast<Map<String, dynamic>>();
      expect(segments.length, envelope.length,
          reason: '$id: Dart reads ${segments.length} segments where Python read '
              '${envelope.length} from "${feeling.haptic}"');
      for (var i = 0; i < segments.length; i++) {
        expect(segments[i].ms, envelope[i]['ms'], reason: '$id: segment $i duration');
        expect(segments[i].amp, envelope[i]['amp'], reason: '$id: segment $i amplitude');
      }
      expect(feeling.hapticLengthMs, row['duration_ms'], reason: '$id: total duration');
      expect(segments.where((s) => s.on).length, row['pulses'], reason: '$id: pulse count');
      expect(segments.fold<int>(0, (n, s) => s.amp > n ? s.amp : n), row['peak_amp'],
          reason: '$id: peak amplitude');
    }
  });

  test('every feeling actually does something to the phone', () {
    // A feeling with a silent or empty haptic is a row in a table, not a thing you can feel in
    // your pocket, and emotional_transmission is the row this build scores worst on.
    for (final f in kBuiltInFeelings) {
      expect(f.segments, isNotEmpty, reason: '${f.id} has no haptic at all');
      expect(f.segments.any((s) => s.on), isTrue,
          reason: '${f.id} never turns the motor on: "${f.haptic}"');
      expect(f.hapticLengthMs, greaterThan(0), reason: '${f.id} is zero milliseconds long');
    }
  });
}
