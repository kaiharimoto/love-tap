// A module's glance says the shape of the pile; the pile says the rest.
//
// A coherence critic found three of the five module blocks printing the same sentence twice inside
// one block: the DATES card read `next: the place by the bridge` directly above a row reading
// `the second one · the place by th... · in 2 months`, and the shelf card read `waiting on you:
// the one you said you stopped` above the row for the thing you said you stopped. A card that
// repeats the row under it is a card carrying no information, and it costs the room a real glance
// would have used.
import 'package:desk/modules/registry.dart';
import 'package:desk/spine/seed_bundle.dart';
import 'package:desk/spine/seed_loader.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/spine/store/store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every run of [n] words that appears in [text], lowercased.
Set<String> _runs(String text, int n) {
  final words = text
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  final out = <String>{};
  for (var i = 0; i + n <= words.length; i++) {
    out.add(words.sublist(i, i + n).join(' '));
  }
  return out;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('no module glance repeats a row it is sitting on top of', () async {
    final spine = await Spine.open(
      SpineStore.memory(),
      const Identity(person: Person.teo, device: DeviceKind.pwa),
    );
    await SeedLoader(BundleSeedSource(rootBundle)).load(spine);
    final all = spine.all;
    expect(all.length, greaterThan(1000), reason: 'the year did not load');

    for (final m in kModules) {
      final glance = m.glance(all);
      // The rows this module would draw, as the words they carry: every event of its own types,
      // with whatever title or text it holds.
      final rows = <String>[];
      for (final e in all.where((e) => m.eventTypes.contains(e.type))) {
        for (final k in const ['title', 'text', 'name', 'what']) {
          final v = e.payload[k];
          if (v is String && v.trim().length > 3) rows.add(v);
        }
      }
      final said = <String>{for (final r in rows) ..._runs(r, 3)};
      final repeated = _runs(glance, 3).intersection(said);
      expect(repeated, isEmpty,
          reason: '${m.id} glances "$glance", which repeats $repeated from a row beneath it');
    }
  });

  test('and every glance still says something', () async {
    final spine = await Spine.open(
      SpineStore.memory(),
      const Identity(person: Person.teo, device: DeviceKind.pwa),
    );
    await SeedLoader(BundleSeedSource(rootBundle)).load(spine);
    for (final m in kModules) {
      final glance = m.glance(spine.all);
      expect(glance.trim(), isNotEmpty, reason: '${m.id} glances nothing');
      expect(glance.length, lessThan(60), reason: '${m.id} glances a paragraph: "$glance"');
    }
  });
}
