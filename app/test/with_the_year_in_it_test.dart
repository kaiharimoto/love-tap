// The regions, with the year in them, are not empty.
//
// Moments came back blank in the first evidence pass: it opens on whichever view has something in
// it, and the media view had nothing because the loader had dropped every photograph. There was no
// test between "the screen builds" and "the screen is worth looking at", so this is it — the year
// is loaded the way the app loads it, and each region has to put something on the desk.
import 'dart:convert';

import 'package:desk/feelings/registry.dart';
import 'package:desk/material/library.dart';
import 'package:desk/material/paper.dart';
import 'package:desk/material/slip.dart';
import 'package:desk/regions/chat/chat_region.dart';
import 'package:desk/regions/moments/moments_region.dart';
import 'package:desk/regions/pulse/pulse_region.dart';
import 'package:desk/regions/us/us_region.dart';
import 'package:desk/scope.dart';
import 'package:desk/spine/seed_loader.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/spine/store/store.dart';
import 'package:desk/transport/local/local_transport.dart';
import 'package:desk/transport/sync.dart';
import 'package:desk/transport/transport.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

void main() {
  String? absent;
  late AppScope scope;
  late SeedReport report;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await MaterialLibrary.load();
    try {
      final index = jsonDecode(await rootBundle.loadString('assets/seed/index.json'))
          as Map<String, dynamic>;
      if (((index['months'] as List?) ?? const []).isEmpty) {
        absent = 'the bundle has a seed directory with no months in it';
        return;
      }
    } catch (_) {
      absent = 'this bundle was packed without the seeded year '
          '(tools/pack_assets.py --seed=year puts it in)';
      return;
    }
    final spine = await Spine.open(
      SpineStore.memory(),
      const Identity(person: Person.teo, device: DeviceKind.pwa),
    );
    report = (await SeedLoader(rootBundle).load(spine))!;
    final transport = LocalTransport(role: TransportRole.client, spine: spine, deviceId: 'test');
    scope = AppScope(
      spine: spine,
      transport: transport,
      sync: SyncEngine(spine: spine, transport: transport),
      clock: Clock(frozenAt: DateTime.utc(2026, 8, 30, 9, 14)),
    );
  });

  Future<void> draw(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(AppScope.provide(
      scope: scope,
      child: MaterialApp(home: Scaffold(body: screen)),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  }

  testWidgets('a year of it went into the log', (tester) async {
    if (absent != null) return markTestSkipped(absent!);
    expect(report.events, greaterThan(10000));
    expect(scope.thread.items, isNotEmpty);
  });

  testWidgets('the thread has the year in it', (tester) async {
    if (absent != null) return markTestSkipped(absent!);
    await draw(tester, const ChatRegion());
    expect(find.byType(Slip).evaluate().length + find.byType(PaperPiece).evaluate().length,
        greaterThan(2),
        reason: 'a thread of ${scope.thread.items.length} rows drew almost no paper');
  });

  testWidgets('moments opens on something rather than on nothing', (tester) async {
    if (absent != null) return markTestSkipped(absent!);
    await draw(tester, const MomentsRegion());
    // EmptySurface is the one allowed empty state, and a year of shared life is not it
    expect(find.byType(EmptySurface), findsNothing,
        reason: 'Moments opened on an empty view with a year of events behind it');
  });

  testWidgets('the pulse and the modules have something to say', (tester) async {
    if (absent != null) return markTestSkipped(absent!);
    await draw(tester, const PulseRegion());
    await draw(tester, const UsRegion());
  });

  testWidgets('every feeling the year refers to is in the vocabulary', (tester) async {
    if (absent != null) return markTestSkipped(absent!);
    final registry = FeelingRegistry(scope.spine.all);
    final unknown = <String>{};
    for (final e in scope.spine.all) {
      if (e.type != 'feeling' && e.type != 'reaction') continue;
      final id = e.payload['feeling_id'];
      if (id is String && registry.byId(id) == null) unknown.add(id);
    }
    expect(unknown, isEmpty,
        reason: 'the year sends feelings the app has never heard of: ${unknown.join(', ')}');
  });
}
