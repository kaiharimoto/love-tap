// The interrupt matrix has to be somewhere a capture can see it.
//
// `what may interrupt` is fourteen event types wide and three choices deep -- `wake me`,
// `quietly`, `not at all` -- and every one of those 42 words is a word a person chooses between.
// Firing 21 moved the table to the bottom of the settings page on purpose: it is the one thing on
// that screen you set once and never look at again, and with it in the middle the artifact carried
// thirteen rows of it and none of the feeling-authoring tools the row asks for.
//
// The cost was not noticed for two firings. `05_settings.text.json` held 14 runs each of the three
// labels at firing 16 and zero of all three at firing 23, at the same frame size, with offscreen 0
// and clipped 0 -- so the runs did not fail the legibility floor, they left the picture. 35 of the
// 39 legibility failures that `went` between those two captures are those runs going off-screen,
// which is exactly the outcome rank 11's measurement was worded to refuse, and a real surface went
// dark to the critics at the same time.
//
// The page is taller than one screenful and a person reaches the matrix with a thumb. Until now a
// scene had no thumb: `CaptureBus.scrollBy` belongs to the thread, and nothing scrolled settings.
// So this holds the two halves of the fix together -- the handle exists, and once it has been
// used every one of the 42 runs is declared.
//
// Re-break: drop `CaptureBus.settingsScrollBy = _scrollBy` from SettingsRegion.initState and the
// first test fails; drop the `controller: _scroll` from its ListView and the second one finds the
// same zero runs the sidecar has been reporting.
import 'package:desk/capture/bus.dart';
import 'package:desk/capture/hooks.dart';
import 'package:desk/material/library.dart';
import 'package:desk/regions/settings/settings_region.dart';
import 'package:desk/scope.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/transport/local/local_transport.dart';
import 'package:desk/transport/sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const Size _frame = Size(1440, 3120);
const double _dpr = 3.0;
const _labels = ['wake me', 'quietly', 'not at all'];

void main() {
  late AppScope scope;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await MaterialLibrary.load();
    final spine = await Spine.open(
      SpineStore.memory(),
      const Identity(person: Person.teo, device: DeviceKind.pwa),
    );
    final transport = LocalTransport(role: TransportRole.client, spine: spine, deviceId: 'test');
    scope = AppScope(
      spine: spine,
      transport: transport,
      sync: SyncEngine(spine: spine, transport: transport),
      clock: Clock(frozenAt: DateTime.utc(2026, 9, 3, 19, 40)),
    );
    addTearDown(scope.dispose);
  });

  Future<void> draw(WidgetTester tester) async {
    tester.view.physicalSize = _frame;
    tester.view.devicePixelRatio = _dpr;
    addTearDown(tester.view.reset);
    CaptureBus.wanted = true;
    addTearDown(() {
      CaptureBus.wanted = false;
      CaptureBus.clear();
    });
    await tester.pumpWidget(AppScope.provide(
      scope: scope,
      child: const MaterialApp(home: Scaffold(body: SettingsRegion())),
    ));
    await tester.pump();
    // the prefs are loaded in a post-frame callback, and the matrix does not exist until they are
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  }

  /// How many of the three labels the capture sidecar declares, by label.
  Map<String, int> declared() {
    final counts = {for (final l in _labels) l: 0};
    for (final r in CaptureHooks.textRuns()) {
      final text = (r['text'] as String?)?.trim();
      if (counts.containsKey(text)) counts[text!] = counts[text]! + 1;
    }
    return counts;
  }

  testWidgets('the capture harness has a thumb for the settings page', (tester) async {
    await draw(tester);
    expect(CaptureBus.settingsScrollBy, isNotNull,
        reason: 'nothing can scroll the settings page, so `what may interrupt` can only ever be '
            'captured if it happens to fit above the fold -- which it does not');
  });

  testWidgets('every row of the interrupt matrix is declared once it is scrolled to',
      (tester) async {
    await draw(tester);
    final rows = kEventTypes.where((t) => t.notify != Notify.none).length;
    expect(rows, greaterThanOrEqualTo(10),
        reason: 'the matrix this test is about is the fourteen interruptible event types');

    final before = declared();
    CaptureBus.settingsScrollBy!(99999);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    final after = declared();

    for (final l in _labels) {
      expect(after[l], rows,
          reason: 'the settings page was scrolled to the bottom and `$l` is declared ${after[l]} '
              'times, not once per interruptible type ($rows). Before the scroll it was '
              '${before[l]}. A run that is not declared is a run no ruler in this build can '
              'read, and 05_settings.text.json has been reporting zero of these since firing 21.');
    }
  });
}
