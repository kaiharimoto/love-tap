// Nothing in this app adds up how much two people have done.
//
// The brief forbids engagement machinery, and an anti-goal critic found the one place it had got
// in: the Rituals card on the Us desk read '3 kept · 53 times · the last yesterday'. The middle
// number is every keeping of every ritual added together. A tally beside one ritual is the marks a
// person makes in a margin; a sum of all of them on a card is a scoreboard, and the difference is
// whether there is a number that only ever goes up.
//
// This is checked on the glances themselves, against a year of real events, because the fault was
// not in a string literal — it was in arithmetic.
import 'dart:convert';
import 'dart:io';

import 'package:desk/modules/registry.dart';
import 'package:desk/spine/event.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/spine/store/store.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<Event>> _theYear() async {
  final types = {for (final m in kModules) ...m.eventTypes};
  final dir = Directory('${Directory.current.parent.path}/seed/year');
  final spine = await Spine.open(
      SpineStore.memory(), const Identity(person: Person.teo, device: DeviceKind.pwa));
  final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.jsonl')).toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final f in files) {
    for (final line in const LineSplitter().convert(f.readAsStringSync())) {
      if (line.trim().isEmpty) continue;
      final e = jsonDecode(line) as Map<String, dynamic>;
      if (!types.contains(e['type'])) continue;
      await spine.append(e['type'] as String, Map<String, dynamic>.from(e['payload'] as Map),
          at: DateTime.parse(e['ts'] as String), hostAssign: true);
    }
  }
  return spine.all;
}

void main() {
  test('no module glance adds up everything that ever happened', () async {
    final events = await _theYear();
    final now = DateTime.utc(2026, 9, 3, 19, 40);
    final offenders = <String>[];
    for (final m in kModules) {
      final line = m.glance(events, now);
      final numbers = RegExp(r'\d+').allMatches(line).map((x) => int.parse(x[0]!)).toSet();
      final mine = events.where((e) => m.eventTypes.contains(e.type)).length;
      if (mine > 3 && numbers.contains(mine)) {
        offenders.add('${m.id}: "$line" says $mine, which is every one of its events counted');
      }
    }
    expect(offenders, isEmpty,
        reason: 'a module glance is keeping a score:\n  ${offenders.join('\n  ')}');
  });

  test('and a glance still says something true', () async {
    final events = await _theYear();
    final now = DateTime.utc(2026, 9, 3, 19, 40);
    for (final m in kModules) {
      final line = m.glance(events, now);
      expect(line.trim(), isNotEmpty, reason: '${m.id} says nothing at all');
      expect(line.length, lessThan(60), reason: '${m.id} says too much for a glance: "$line"');
    }
  });
}
