// The vocabulary sheet holds every family, including the ones with a user-authored feeling on them.
//
// An emotional critic found the two authored feelings the only two of the thirty-six whose entry is
// cut off: `tuesday soup` is the seventh tile in Shelter and its card is cut by the tab strip at
// about y 2180 with its name drawn at 2310 — legible *behind* CHAT and US rather than below them —
// and `pigeon` is the seventh in Mischief and does the same. Six tiles fitted and the seventh did
// not, and a Column whose child is taller than its constraints paints outside them.
@TestOn('vm')
library;

import 'package:desk/feelings/builtins.dart';
import 'package:desk/feelings/registry.dart';
import 'package:desk/spine/event.dart';
import 'package:desk/feelings/corner.dart';
import 'package:desk/material/library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The tab strip's own room at the foot of every region.
const double kTheTabStrip = 66;

void main() {
  setUpAll(() async => MaterialLibrary.load());

  testWidgets('a family with a seventh feeling on it still fits above the tab strip',
      (tester) async {
    const dpr = 3.0;
    // the clip's own viewport, which is where the two were measured cut
    const size = Size(360, 780);
    tester.view.physicalSize = size * dpr;
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.reset);

    // the thirty-four built-ins plus the two the couple authored, which is what the picker holds
    // in the capture and the only two whose entries were cut off
    final registry = FeelingRegistry([
      for (final a in const [
        ('soup', 'tuesday soup', 'Shelter', 'obj_user_soup', 'teo'),
        ('pigeon', 'the pigeon', 'Mischief', 'obj_user_pigeon', 'noor'),
      ])
        Event(
          id: 'authored.${a.$1}',
          type: 'feeling_authored',
          seq: 0,
          device: DeviceKind.android,
          author: a.$5 == 'teo' ? Person.teo : Person.noor,
          ts: 0,
          payload: {
            'feeling_id': a.$1,
            'name': a.$2,
            'family': a.$3,
            'object_asset': a.$4,
            'haptic': '40,120,40',
            'colour': '#8A6A3A',
            'sound': 'soft',
          },
        ),
    ]);
    for (final family in Family.values) {
      final members = registry.family(family);
      if (members.isEmpty) continue;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FanForTest(
            registry: registry,
            family: family,
            intensity: 0.7,
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      var lowest = 0.0;
      for (final f in members) {
        final t = find.text(f.name);
        if (t.evaluate().isEmpty) continue;
        final r = tester.getRect(t.first);
        if (r.bottom > lowest) lowest = r.bottom;
      }
      expect(lowest, greaterThan(0), reason: '${family.label} drew no names at all');
      expect(lowest, lessThanOrEqualTo(size.height - kTheTabStrip),
          reason: '${family.label} has ${members.length} feelings and its last name is drawn at '
              '$lowest, which is behind the tab strip');
    }
  });
}
