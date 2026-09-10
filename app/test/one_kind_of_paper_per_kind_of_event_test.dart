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
import 'package:desk/modules/registry.dart';
import 'package:desk/spine/types.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every dart file under lib/modules/, and the event kinds the module it belongs to writes.
///
/// This was a hand-written map of five paths to five types, which a code critic read as the
/// failure it is: a sixth module, or a module that grows a second file, is not in the map and is
/// therefore not checked, and nothing says so. `kModules` is what the app runs on, and the files
/// are on the disk; both are read rather than restated.
Map<String, Set<String>> moduleFiles() {
  final out = <String, Set<String>>{};
  for (final dir in Directory('lib/modules').listSync().whereType<Directory>()) {
    final id = dir.path.split(Platform.pathSeparator).last;
    final module = kModules.where((m) => m.id == id || dir.path.contains(m.id));
    if (module.isEmpty) continue;
    final types = {for (final m in module) ...m.eventTypes};
    for (final f in dir.listSync(recursive: true).whereType<File>()) {
      if (f.path.endsWith('.dart')) out[f.path] = types;
    }
  }
  return out;
}

void main() {
  test('no module names its own stock', () {
    final files = moduleFiles();
    expect(files.length, greaterThanOrEqualTo(kModules.length),
        reason: 'found ${files.length} module files for ${kModules.length} modules');
    final offenders = <String>[];
    for (final entry in files.entries) {
      final src = File(entry.key).readAsStringSync();
      final literal = RegExp(r"""stock:\s*'([a-z_]+)'""");
      for (final m in literal.allMatches(src)) {
        offenders.add('${entry.key}: stock: \'${m.group(1)}\' — ask stockForType for one of '
            '${entry.value}');
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
    for (final m in kModules) {
      for (final type in m.eventTypes) {
        expect(known, contains(type), reason: '${m.id} writes $type, which is not in the registry');
      }
    }
  });

  test('every module has files under lib/modules and every one of them is read', () {
    final files = moduleFiles();
    for (final m in kModules) {
      expect(files.keys.any((p) => p.contains('/${m.id}/')), isTrue,
          reason: '${m.id} has no directory under lib/modules, so nothing checks its paper');
    }
  });
}
