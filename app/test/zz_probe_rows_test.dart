import 'dart:convert';
import 'dart:io';
import 'package:desk/material/library.dart';
import 'package:desk/modules/module.dart';
import 'package:desk/modules/registry.dart';
import 'package:desk/scope.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/spine/store/store.dart';
import 'package:desk/transport/local/local_transport.dart';
import 'package:desk/transport/sync.dart';
import 'package:desk/transport/transport.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async { await MaterialLibrary.load(); });
  testWidgets('how tall is one desk row', (tester) async {
    final types = {for (final m in kModules) ...m.eventTypes};
    final dir = Directory('${Directory.current.parent.path}/seed/year');
    final seeded = <Map<String, dynamic>>[];
    final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.jsonl')).toList()..sort((a,b)=>a.path.compareTo(b.path));
    for (final f in files) {
      for (final line in const LineSplitter().convert(f.readAsStringSync())) {
        if (line.trim().isEmpty) continue;
        final e = jsonDecode(line) as Map<String, dynamic>;
        if (types.contains(e['type'])) seeded.add(e);
      }
    }
    final spine = await Spine.open(SpineStore.memory(), const Identity(person: Person.teo, device: DeviceKind.pwa));
    for (final e in seeded) {
      await spine.append(e['type'] as String, Map<String, dynamic>.from(e['payload'] as Map),
          at: DateTime.parse(e['ts'] as String), hostAssign: true);
    }
    final transport = LocalTransport(role: TransportRole.client, spine: spine, deviceId: 't');
    final scope = AppScope(spine: spine, transport: transport,
        sync: SyncEngine(spine: spine, transport: transport),
        clock: Clock(frozenAt: DateTime.utc(2026, 9, 3, 19, 40)));
    addTearDown(scope.dispose);
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    for (final m in kModules) {
      final ctx = ModuleContext(events: spine.all, me: scope.me, partner: scope.partner,
          now: scope.clock.now().toLocal(), emit: scope.emit, limit: 6, room: 100000);
      await tester.pumpWidget(AppScope.provide(scope: scope, child: MaterialApp(home: Scaffold(
        body: SizedBox(width: 480, child: SingleChildScrollView(child: Builder(builder: (c) => m.build(c, ctx)))),
      ))));
      await tester.pump(const Duration(milliseconds: 300));
      final fit = find.byWidgetPredicate((w) => w.runtimeType.toString() == 'FitRows');
      if (fit.evaluate().isEmpty) { debugPrint('MODULE ${m.id}: no FitRows'); continue; }
      final el = fit.evaluate().first as dynamic;
      final ro = el.renderObject;
      var child = ro.firstChild;
      final hs = <double>[];
      while (child != null) { hs.add(child.size.height); child = ro.childAfter(child); }
      debugPrint('MODULE ${m.id}: declared ${m.rowHeight}  actual rows ${hs.map((h) => h.round()).toList()}  total ${hs.fold<double>(0,(a,b)=>a+b).round()}');
    }
  });
}
