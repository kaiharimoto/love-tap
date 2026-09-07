// All five modules, on one desk, at once — measured on what was photographed.
//
// The brief's test of the architecture is that a fifth shared-life module is a directory and one
// line in a registry. The artifact has to show that it arrived: a coherence critic counted
// 03_us.report.json listing all five modules with their event counts while 03_us.png showed two.
//
// The guard that was supposed to catch that did not, because it measured the wrong thing twice: it
// mounted the region bare in a full-screen Scaffold, so it had ~380 pt of desk the shell does not
// leave, and it fed it five one-field synthetic events, so the dates section cost a fifth of what
// the seeded year makes it cost. This test uses the year's own module events and the shell's own
// slot, and compares every heading against the slot rather than against the screen.
import 'dart:convert';
import 'dart:io';

import 'package:desk/app.dart' show kTabStrip;
import 'package:desk/material/desk.dart' show kPartnerStrip;
import 'package:desk/material/hands.dart';
import 'package:desk/material/library.dart';
import 'package:desk/modules/registry.dart';
import 'package:desk/regions/us/us_region.dart';
import 'package:desk/scope.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/spine/store/store.dart';
import 'package:desk/transport/local/local_transport.dart';
import 'package:desk/transport/sync.dart';
import 'package:desk/transport/transport.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every module event in the seeded year, in order. Not SeedLoader: this needs the 351 lines the
/// modules read, not the 14,062 events and their blobs.
List<Map<String, dynamic>> _seededModuleEvents() {
  final types = {for (final m in kModules) ...m.eventTypes};
  final dir = Directory('${Directory.current.parent.path}/seed/year');
  final out = <Map<String, dynamic>>[];
  final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.jsonl')).toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final f in files) {
    for (final line in const LineSplitter().convert(f.readAsStringSync())) {
      if (line.trim().isEmpty) continue;
      final e = jsonDecode(line) as Map<String, dynamic>;
      if (types.contains(e['type'])) out.add(e);
    }
  }
  return out;
}

void main() {
  setUpAll(() async {
    await MaterialLibrary.load();
  });

  testWidgets('every module label is on the desk at once', (tester) async {
    final seeded = _seededModuleEvents();
    expect(seeded.length, greaterThan(200),
        reason: 'the seeded year should carry a few hundred module events');

    final spine = await Spine.open(
      SpineStore.memory(),
      const Identity(person: Person.teo, device: DeviceKind.pwa),
    );
    for (final e in seeded) {
      await spine.append(
        e['type'] as String,
        Map<String, dynamic>.from(e['payload'] as Map),
        at: DateTime.parse(e['ts'] as String),
        hostAssign: true,
      );
    }
    final transport = LocalTransport(role: TransportRole.client, spine: spine, deviceId: 'test');
    final scope = AppScope(
      spine: spine,
      transport: transport,
      sync: SyncEngine(spine: spine, transport: transport),
      clock: Clock(frozenAt: DateTime.utc(2026, 9, 3, 19, 40)),
    );
    addTearDown(scope.dispose);
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    // the slot the shell actually leaves Us: the partner's strip above, the tab strip below
    await tester.pumpWidget(AppScope.provide(
      scope: scope,
      child: const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SizedBox(height: kPartnerStrip),
              Expanded(child: UsRegion()),
              SizedBox(height: kTabStrip),
            ],
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 400));

    final slotTop = tester.getTopLeft(find.byType(UsRegion)).dy;
    final slot = tester.getSize(find.byType(UsRegion)).height;
    final missing = <String>[];
    for (final module in kModules) {
      final heading = find.byWidgetPredicate(
          (w) => w is Stamped && w.text == module.label,
          skipOffstage: false);
      if (heading.evaluate().isEmpty) {
        missing.add('${module.label}: not built at all');
        continue;
      }
      final bottom = tester.getBottomLeft(heading.first).dy - slotTop;
      if (bottom > slot) {
        missing.add('${module.label}: ends ${bottom.round()} pt into a ${slot.round()} pt slot');
      }
    }
    expect(missing, isEmpty,
        reason: 'a module the report counts and the picture does not show:\n${missing.join('\n')}');
  });

  testWidgets('every module has something under its heading', (tester) async {
    // A heading on the glass with nothing under it is not the module being on the desk. Each
    // section is the heading plus whatever FitRows kept, so a section no taller than its own
    // heading is a module that was given a share too small to hold one of its rows.
    final seeded = _seededModuleEvents();
    final spine = await Spine.open(
      SpineStore.memory(),
      const Identity(person: Person.teo, device: DeviceKind.pwa),
    );
    for (final e in seeded) {
      await spine.append(e['type'] as String, Map<String, dynamic>.from(e['payload'] as Map),
          at: DateTime.parse(e['ts'] as String), hostAssign: true);
    }
    final transport = LocalTransport(role: TransportRole.client, spine: spine, deviceId: 'test');
    final scope = AppScope(
      spine: spine,
      transport: transport,
      sync: SyncEngine(spine: spine, transport: transport),
      clock: Clock(frozenAt: DateTime.utc(2026, 9, 3, 19, 40)),
    );
    addTearDown(scope.dispose);
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(AppScope.provide(
      scope: scope,
      child: const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SizedBox(height: kPartnerStrip),
              Expanded(child: UsRegion()),
              SizedBox(height: kTabStrip),
            ],
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 400));

    final bare = <String>[];
    for (final module in kModules) {
      final content = find.byWidgetPredicate((w) => w.runtimeType.toString() == 'FitRows',
          skipOffstage: false);
      expect(content, findsWidgets, reason: 'the desk lays its modules out with FitRows');
      final section = find.ancestor(
        of: find.byWidgetPredicate((w) => w is Stamped && w.text == module.label,
            skipOffstage: false),
        matching: find.byType(Column),
      );
      if (section.evaluate().isEmpty) continue;
      final h = tester.getSize(section.last).height;
      if (h <= kUsHeading + 1) bare.add('${module.label}: ${h.round()} pt, heading and nothing');
    }
    expect(bare, isEmpty, reason: 'a module on the desk with nothing under it:\n${bare.join('\n')}');
  });
}
