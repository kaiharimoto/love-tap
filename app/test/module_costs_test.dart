// What a fifth module actually costs, counted rather than claimed.
//
// modules/module.dart has said since the fourth module that adding one is "a directory under
// modules/ and one line in registry.dart". A coherence critic counted the fifth module's own diff
// and found five shared files, so the claim came down and the files went one by one: the paper
// (the module declares its `stocks`), the share of the desk (`rowHeight`), the search facets, and
// then the two this test guards — the row the module draws in the thread and the sentence it
// reads as away from it, both of which used to be written for it in the chat region.
//
// What is left is the spine registry, and that one is a principle and not a cost: the spine
// validates every payload against one list before it writes it and before it takes one off the
// wire, so a module inventing its own schema is exactly what a single spine forbids.
//
// This test is the counting. It reads the source, because the claim is about the source.
import 'dart:io';

import 'package:desk/modules/registry.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/thread/renderers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final dart = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('nothing outside a module names that module\'s event types, except the spine registry', () {
    final offenders = <String>[];
    for (final m in kModules) {
      expect(Directory('lib/modules/${m.id}').existsSync(), isTrue,
          reason: 'a module is a directory under modules/, and ${m.id} has not got one');
      // Everything a shared file could key a per-module table off: the event type, the renderer id
      // the registry names for it, and the module's own id, which is also its search facet. The
      // first version of this forbade only the type id, and a set of renderer ids dropped back
      // into the Moments lens reproduced the exact bug it was written against with the suite
      // green.
      final handles = <String>{
        m.id,
        for (final type in m.eventTypes) ...[type, kEventTypeById[type]!.renderer],
      };
      for (final handle in handles) {
        final homes = [
          for (final other in kModules)
            if (other.eventTypes.contains(handle) ||
                other.eventTypes.any((t) => kEventTypeById[t]!.renderer == handle) ||
                other.id == handle)
              'lib/modules/${other.id}/',
        ];
        for (final f in dart) {
          final path = f.path.replaceAll('\\', '/');
          if (path == 'lib/spine/types.dart') continue;
          if (homes.any(path.startsWith)) continue;
          final src = f.readAsStringSync();
          if (src.contains("'$handle'") || src.contains('"$handle"')) {
            offenders.add('$path names ${m.id}\'s "$handle"');
          }
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'a module has to be added to these files as well as to its own directory:\n'
          '${offenders.join('\n')}',
    );
  });

  test('every module draws its own rows in the thread', () {
    for (final m in kModules) {
      for (final type in m.eventTypes) {
        final spec = kEventTypeById[type]!;
        expect(
          m.bodies[spec.renderer],
          isNotNull,
          reason:
              '${m.id} writes $type, whose renderer is "${spec.renderer}", and does not '
              'declare a body for it: something else is drawing this module\'s rows',
        );
        expect(
          identical(kThreadRenderers[spec.renderer], m.bodies[spec.renderer]),
          isTrue,
          reason:
              'the thread draws "${spec.renderer}" with something other than the body '
              '${m.id} declares',
        );
      }
    }
  });

  test('every module writes its own sentence, and it is not the registry id', () {
    for (final m in kModules) {
      for (final type in m.eventTypes) {
        final spec = kEventTypeById[type]!;
        final e = Event(
          id: '01J0',
          seq: 1,
          author: Person.noor,
          device: DeviceKind.android,
          ts: DateTime.utc(2026, 4, 22, 16, 30).millisecondsSinceEpoch,
          type: type,
          payload: {for (final k in spec.required) k: _value(k)},
        );
        final own = m.sentence(e, 'noor');
        expect(own, isNotNull, reason: '${m.id} has no sentence for $type');
        expect(
          own,
          isNot(contains('_')),
          reason: '${m.id} shows a stored key rather than words for $type: "$own"',
        );
        // and the one place everything else reads through says the same thing
        expect(
          summaryOf(e, me: Person.teo),
          equals(own),
          reason: 'summaryOf disagrees with ${m.id}\'s own sentence for $type',
        );
      }
    }
  });

  test('a type nobody claims still reads as words', () {
    // The fallback matters as much as the modules: this is what a type added to the registry and
    // to nothing else shows a person, and for most of the build it was the registry id.
    for (final spec in kEventTypes) {
      expect(spec.noun.trim(), isNotEmpty, reason: '${spec.id} has no noun');
      expect(spec.announced.trim(), isNotEmpty, reason: '${spec.id} has no arrival line');
      expect(spec.noun, isNot(contains('_')), reason: '${spec.id}: "${spec.noun}" is a key');
      expect(
        spec.announced,
        isNot(contains('_')),
        reason: '${spec.id}: "${spec.announced}" is a key',
      );
    }
  });
}

Object _value(String key) => switch (key) {
  'intensity' => 0.7,
  'yearly' => true,
  'duration_ms' => 62000,
  'w' || 'h' => 1200,
  'upto_seq' => 12,
  'waveform' => const [0.2, 0.4],
  'date' || 'kept_at' || 'when' || 'fires_at' => '2026-04-23T16:00:00Z',
  'retired' => false,
  'action' => 'planned',
  _ => 'the canal',
};
