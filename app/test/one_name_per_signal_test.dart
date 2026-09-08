// Two fields, two names. Not three.
//
// "One pair of fields carries three names on one screen: the header strip labels the partner's two
// scalars NEED and ENERGY, the partner card 460 px below labels the same two NEEDS and HAS LEFT,
// and the YOURS picker 1,000 px below that goes back to NEED and ENERGY." A reader counting the
// fields on that screen finds three and there are two.
//
// Sentences about a signal still conjugate — "noor needs a lot" is a sentence, not a label — but
// wherever a signal is *labelled* the label comes from one table.
import 'dart:io';

import 'package:desk/spine/projections/state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every signal has exactly one label, and it comes from the table', () {
    for (final id in kDeclaredSignals) {
      expect(kSignalLabels.containsKey(id), isTrue, reason: '$id has no label of its own');
    }
    expect(kSignalLabels.values.toSet().length, kSignalLabels.length,
        reason: 'two signals share a label, which is one field wearing another one\'s name');
  });

  test('nothing labels a dial or a fact with a word of its own', () {
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      for (final m in RegExp(r"_(?:Dial|Fact|Row)\(\s*(?:label:\s*)?'([^']+)'").allMatches(src)) {
        final word = m.group(1)!;
        // a label that is one of the signals', or a near-miss of one, has to come from the table
        final near = kSignalLabels.values.any((l) => word == l || word == '${l}s') ||
            kDeclaredSignals.any((s) => word.startsWith(s));
        if (near || word == 'has left') {
          offenders.add('${f.path}: "$word"');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'a signal labelled with a word written at the call site:\n${offenders.join('\n')}');
  });
}
