// Settings says how many feelings were made on this phone, and it counts this phone's.
//
// 05_settings read `feelings: 36 to send, 2 made here` above its own list of `pigeon by noor` and
// `tuesday soup by teo`: the count was every feeling_authored in the shared log, both of theirs.
// Anchored to the author of each event, and asked from both phones over the same log.
//
// And a feeling stays its maker's when the other one puts it away. A later feeling_authored
// renames, recolours or retires it; the registry used to take that later event's author as the
// feeling's, so noor retiring teo's pigeon made it `by noor` and moved it between the two counts.
//
// Re-break: count `authored.length` in settings_region.dart and `each phone counts its own` fails;
// take the latest event's author in registry.dart and `putting it away` fails.
import 'package:desk/feelings/registry.dart';
import 'package:desk/material/library.dart';
import 'package:desk/regions/settings/settings_region.dart';
import 'package:desk/scope.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/transport/local/local_transport.dart';
import 'package:desk/transport/sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 3, 19, 40);
  final ulids = UlidFactory();
  var seq = 0;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await MaterialLibrary.load();
  });

  Event authored(Person by, String id, {bool retired = false}) => Event(
        id: ulids.next(now),
        seq: ++seq,
        author: by,
        device: by == Person.noor ? DeviceKind.android : DeviceKind.pwa,
        ts: now.millisecondsSinceEpoch + seq,
        type: 'feeling_authored',
        payload: {
          'feeling_id': id,
          'name': id.replaceAll('_', ' '),
          'family': 'Mischief',
          'colour': '#3a3a3c',
          'object_asset': 'obj_user_$id',
          'haptic': '30@200 off80 30@200',
          'sound': 'snd_user_$id',
          'retired': retired,
        },
      );

  Future<AppScope> phoneOf(Person who, List<Event> log) async {
    final spine = await Spine.open(
        SpineStore.memory(), Identity(person: who, device: DeviceKind.pwa));
    await spine.importSeed(log);
    final t = LocalTransport(role: TransportRole.client, spine: spine, deviceId: 'test');
    return AppScope(
      spine: spine,
      transport: t,
      sync: SyncEngine(spine: spine, transport: t),
      clock: Clock(frozenAt: now),
    );
  }

  /// What the `feelings` line in Settings says, read off the widget the app drew.
  Future<String> feelingsLine(WidgetTester tester, AppScope scope) async {
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(AppScope.provide(
      scope: scope,
      child: const MaterialApp(home: Scaffold(body: SettingsRegion())),
    ));
    await tester.pump();
    final lines = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .where((s) => s.contains('made here'))
        .toList();
    expect(lines, hasLength(1), reason: 'the feelings line is on the page, once');
    return lines.single;
  }

  final log = [authored(Person.noor, 'pigeon'), authored(Person.teo, 'tuesday_soup')];

  testWidgets('each phone counts its own', (tester) async {
    for (final who in Person.values) {
      final scope = await phoneOf(who, log);
      expect(await feelingsLine(tester, scope), endsWith(', 1 made here'),
          reason: 'one of the two was made on ${who.name}\'s phone');
      scope.dispose();
    }
  });

  testWidgets('putting it away does not make it theirs', (tester) async {
    final retiredByNoor = [...log, authored(Person.noor, 'tuesday_soup', retired: true)];
    final registry = FeelingRegistry(retiredByNoor);
    expect(registry.byId('tuesday_soup')!.authoredBy, 'teo');
    expect(registry.byId('tuesday_soup')!.retired, isTrue, reason: 'the later event still applies');
    final teo = await phoneOf(Person.teo, retiredByNoor);
    expect(await feelingsLine(tester, teo), endsWith(', 1 made here'));
    teo.dispose();
  });
}
