// A search that finds ten shows more than one of them.
//
// "Search chrome fills 67.1 per cent of the screen (2095 of 3120 px). The first result starts at
// y=2518, 80.7 per cent of the way down, so of the ten hits the report records for the query
// 'rain', one is readable and the second is cut in half by the tab bar. No chip carries a
// selected state — EVERYTHING, WRITTEN, PHOTOGRAPHS and the other twelve are drawn in the same
// stock, the same ink and the same size whether they are on or off."
//
// Two standards, measured on the laid-out page rather than on a screenshot: what you were looking
// for is at least half the screen, and the tab that is chosen is visibly the one that is chosen.
import 'package:desk/material/library.dart';
import 'package:desk/regions/chat/search_page.dart';
import 'package:desk/scope.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/spine/store/store.dart';
import 'package:desk/transport/local/local_transport.dart';
import 'package:desk/transport/sync.dart';
import 'package:desk/transport/transport.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the results start in the top half of the page', (tester) async {
    await MaterialLibrary.load();
    final spine = await Spine.open(
      SpineStore.memory(),
      const Identity(person: Person.teo, device: DeviceKind.pwa),
    );
    for (var i = 0; i < 20; i++) {
      await spine.append('message', {'text': 'the rain came in over the hill again, number $i'},
          at: DateTime.utc(2026, 3, 1).add(Duration(hours: i)), hostAssign: true);
    }
    final transport = LocalTransport(role: TransportRole.client, spine: spine, deviceId: 't');
    final scope = AppScope(
      spine: spine,
      transport: transport,
      sync: SyncEngine(spine: spine, transport: transport),
      clock: Clock(frozenAt: DateTime.utc(2026, 9, 3, 19, 40)),
    );
    addTearDown(scope.dispose);
    // the surface 12_search is shot on
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(AppScope.provide(
      scope: scope,
      child: MaterialApp(
        home: Scaffold(body: SearchPage(initialQuery: 'rain', onDone: (_) {})),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final tab = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_Tab');
    if (tab.evaluate().isNotEmpty) {
      debugPrint('${tab.evaluate().length} tabs, one is ${tester.getSize(tab.first)}, '
          'band from ${tester.getTopLeft(tab.first).dy} to '
          '${tester.getBottomLeft(tab.last).dy}');
    }
    final hit = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_Hit');
    final hits = hit.evaluate();
    expect(hits, isNotEmpty, reason: 'the search found nothing to show');
    final screen = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final first = tester.getTopLeft(hit.first).dy;
    debugPrint('first result at ${first.round()} of ${screen.round()} logical px '
        '(${(100 * first / screen).round()}% down); ${hits.length} on the page');
    expect(first / screen, lessThan(0.5),
        reason: 'the chrome takes the top ${(100 * first / screen).round()} per cent of the page');
    expect(hits.length, greaterThanOrEqualTo(3),
        reason: 'only ${hits.length} of the hits fit under the chrome');
  });
}
