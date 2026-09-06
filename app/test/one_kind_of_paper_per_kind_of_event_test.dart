// The same thing is the same piece of paper wherever you meet it.
//
// A date planned in Us was a receipt there and an index card in the thread, so the same evening
// was two different objects depending on which way you had come to it. That is the coherence row
// of the rubric, and it is the kind of thing nothing fails on: both surfaces looked fine alone.
//
// So the stock a kind of event is on lives in one place — stockForType in material/assignment.dart
// — and this reads the modules' source to check that none of them has quietly gone back to
// naming its own.
import 'dart:io';

import 'package:desk/material/assignment.dart';
import 'package:desk/spine/types.dart';
import 'package:flutter_test/flutter_test.dart';

/// The event kind each module writes and draws.
const _moduleTypes = {
  'lib/modules/dates/date_list.dart': 'date_event',
  'lib/modules/todos/todos_module.dart': 'todo_event',
  'lib/modules/calendar/calendar_module.dart': 'milestone',
  'lib/modules/rituals/rituals_module.dart': 'ritual_kept',
  'lib/modules/shelf/shelf_module.dart': 'passed_on',
};

void main() {
  test('no module names its own stock', () {
    final offenders = <String>[];
    for (final entry in _moduleTypes.entries) {
      final src = File(entry.key).readAsStringSync();
      final literal = RegExp(r"""stock:\s*'([a-z_]+)'""");
      for (final m in literal.allMatches(src)) {
        offenders.add('${entry.key}: stock: \'${m.group(1)}\' — ask stockForType(\'${entry.value}\')');
      }
    }
    expect(offenders, isEmpty,
        reason: 'a module that picks its own paper disagrees with the thread about what the '
            'event is:\n${offenders.join('\n')}');
  });

  test('every type that has a stock of its own keeps it', () {
    // the kinds that are the same paper for everybody: the modules, and the two kinds of card
    for (final type in ['date_event', 'todo_event', 'milestone', 'ritual_kept', 'passed_on', 'ping']) {
      expect(stockForType(type), isNotNull,
          reason: '$type is drawn on two surfaces and has no agreed stock');
    }
    // and a message is not one of them: it takes its paper from whoever tore it off
    expect(stockForType('message'), isNull);
  });

  test('a module type is a real registry type', () {
    final known = {for (final s in kEventTypes) s.id};
    for (final type in _moduleTypes.values) {
      expect(known, contains(type), reason: '$type is not in the registry');
    }
  });
}
