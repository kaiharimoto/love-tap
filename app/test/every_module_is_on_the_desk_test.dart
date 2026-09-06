// All five modules, on one desk, at once.
//
// The brief's test of the architecture is that a fifth shared-life module is a directory and one
// line in a registry. The artifact has to show that it arrived: a coherence critic counted
// 03_us.report.json listing all five modules with their event counts while 03_us.png showed two,
// because two rows each ran the last three off the bottom of the screen.
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

void main() {
  setUpAll(() async {
    await MaterialLibrary.load();
  });

  testWidgets('every module label is on the desk at once', (tester) async {
    final spine = await Spine.open(
      SpineStore.memory(),
      const Identity(person: Person.teo, device: DeviceKind.pwa),
    );
    // one of each module's own kind of event, so no section is empty
    await spine.append('date_event', {'date_id': 'd1', 'action': 'planned', 'title': 'the bridge'},
        hostAssign: true);
    await spine.append('todo_event', {'todo_id': 't1', 'action': 'added', 'text': 'bulbs'},
        hostAssign: true);
    await spine.append('milestone', {
      'milestone_id': 'm1', 'kind': 'anniversary', 'title': 'a year',
      'date': '2026-10-01', 'yearly': true,
    }, hostAssign: true);
    await spine.append('ritual_kept', {
      'ritual_id': 'r1', 'title': 'soup', 'kept_at': '2026-09-02T19:00:00Z',
    }, hostAssign: true);
    await spine.append('passed_on', {
      'item_id': 'p1', 'action': 'lent', 'title': 'the blue mug', 'kind': 'thing',
    }, hostAssign: true);
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
      child: const MaterialApp(home: Scaffold(body: UsRegion())),
    ));
    await tester.pump(const Duration(milliseconds: 400));

    final screen = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final missing = <String>[];
    for (final module in kModules) {
      final finder = find.byWidgetPredicate(
          (w) => w is Stamped && w.text == module.label,
          skipOffstage: false);
      if (finder.evaluate().isEmpty) {
        missing.add('${module.label}: not built at all');
        continue;
      }
      final top = tester.getTopLeft(finder.first).dy;
      if (top > screen) missing.add('${module.label}: ${top.round()} pt down a $screen pt screen');
    }
    expect(missing, isEmpty,
        reason: 'a module the report counts and the picture does not show:\n${missing.join('\n')}');
  });
}
