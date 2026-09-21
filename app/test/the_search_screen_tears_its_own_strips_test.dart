// A screen may not tear two pieces of paper along the same edge, and the search screen tore
// thirteen.
//
// `docs/BRIEF.md` 09 names "reusing a single tear mask across the app because generating dozens of
// them was slow" as a failure condition of the whole build, and rubric row 02 asks for tear masks
// with no visible repeat on a single screen. `evidence/12_search.surfaces.json` from firing 39 has
// 28 tear draws on screen and 13 distinct masks, because `assets/tears/tear_001_shadow.webp` is
// drawn FOURTEEN times — twelve of them at byte-identical source geometry (src [1024,578], fit
// fill, height 123). It is the filter strip, and it reads as a ladder of clones.
//
// It was never a shortage: the pool holds 56 masks and the scene report says 47 are writable. And
// it was never the assignment, which walks the pool with a stride coprime to its size precisely so
// that consecutive rows cannot collide. It was that every tab was a `Slip` with no `row`, and
// `Slip.row` defaults to 0 — so all thirteen asked for `writableTears[0]` and got it.
//
// A default of zero is a silent failure: nothing is wrong at any call site, nothing throws, and
// the screen quietly draws one mask thirteen times. So this test asks the page what it actually
// drew, through the same handle the capture harness uses, rather than reading the source for
// `row:`.
//
// AND IT ASKS THE WHOLE SCREEN, NOT THE NOTES. `tools/check/tears.py` counted only the tears the
// scene report listed against event ids, so 02_chat could report `distinct_tears 7, repeats {}`
// while the same frame repeated a mask in its chrome. A gate narrower than the clause it enforces
// is the shape of defect this build keeps finding; here the question is asked of every tear
// surface in the frame.
import 'dart:convert';

import 'package:desk/capture/bus.dart';
import 'package:desk/capture/hooks.dart';
import 'package:desk/material/library.dart';
import 'package:desk/regions/chat/search_page.dart';
import 'package:desk/scope.dart';
import 'package:desk/spine/seed_loader.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/transport/local/local_transport.dart';
import 'package:desk/transport/sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

void main() {
  String? absent;
  late AppScope scope;

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
    await SeedLoader(rootBundle).load(spine);
    final transport = LocalTransport(role: TransportRole.client, spine: spine, deviceId: 'test');
    scope = AppScope(
      spine: spine,
      transport: transport,
      sync: SyncEngine(spine: spine, transport: transport),
      clock: Clock(frozenAt: DateTime.utc(2026, 9, 3, 19, 40)),
    );
  });

  /// Every tear surface on the glass, in paint order, exactly as the sidecar records it.
  ///
  /// `paperSurfaces` records a `RenderImage` only once it HAS its image, which is the whole point
  /// of it — an undecoded box is not a surface anybody can see. A decode happens off the
  /// framework's clock, so real time has to be allowed to pass before the question can be asked.
  Future<List<Map<String, dynamic>>> tears(WidgetTester tester) async {
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    }
    return [
      for (final s in CaptureHooks.paperSurfaces())
        if ((s['asset'] as String).startsWith('assets/tears/')) s,
    ];
  }

  testWidgets('no two strips on the search screen are torn along the same edge', (tester) async {
    if (absent != null) {
      // ignore: avoid_print
      print('skipped: $absent');
      return;
    }
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    CaptureBus.wanted = true;
    addTearDown(() => CaptureBus.wanted = false);

    await tester.pumpWidget(AppScope.provide(
      scope: scope,
      child: const MaterialApp(home: Scaffold(body: SearchPage())),
    ));
    await tester.pump();
    // the query the capture's own scene puts in, so this is the screen 12_search is of
    await tester.enterText(find.byType(TextField).first, 'rain');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);

    final drawn = await tears(tester);
    expect(drawn.length, greaterThanOrEqualTo(10),
        reason: 'the search screen drew ${drawn.length} tears, so either the strip is not on '
            'screen or this test is measuring the wrong page');

    final counts = <String, int>{};
    for (final t in drawn) {
      final a = t['asset'] as String;
      counts[a] = (counts[a] ?? 0) + 1;
    }
    final repeated = {
      for (final e in counts.entries)
        if (e.value > 1) e.key: e.value,
    };
    expect(repeated, isEmpty,
        reason: '${drawn.length} tears on screen and only ${counts.length} masks between them: '
            '$repeated. docs/BRIEF.md 09 makes reusing one mask a failure condition of the build '
            'and rubric row 02 asks for no visible repeat on a single screen. The pool holds '
            '${MaterialLibrary.instance.tearMasks.length} masks, '
            '${MaterialLibrary.instance.writableTears.length} of them writable, so this is a '
            'selection that did not ask rather than a shortage.');
  });

  testWidgets('the strip asks for its row, so a thirteenth tab cannot quietly clone the first',
      (tester) async {
    // The property rather than the instance. A test that only counts what is on screen today
    // passes the day somebody adds a fourteenth filter with no row, because the repeat it makes
    // may be with a tab that has scrolled off. So: the masks the strip uses must be as many as
    // the strip has tabs, and they must move with the tab's position rather than with its label.
    if (absent != null) return;
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    CaptureBus.wanted = true;
    addTearDown(() => CaptureBus.wanted = false);

    await tester.pumpWidget(AppScope.provide(
      scope: scope,
      child: const MaterialApp(home: Scaffold(body: SearchPage())),
    ));
    await tester.pump(const Duration(milliseconds: 400));

    // With nothing typed there are no results, so every tear on screen belongs to the chrome:
    // the query slip, the empty surface and the strip. That is the cleanest read of the strip
    // there is.
    final chrome = await tears(tester);
    final masks = chrome.map((t) => t['asset'] as String).toSet();
    expect(masks.length, chrome.length,
        reason: 'with no results on screen the page still draws ${chrome.length} tears with only '
            '${masks.length} masks, so the repeat is in the chrome and not in the list');
    expect(chrome.length, greaterThanOrEqualTo(13),
        reason: 'the filter strip has thirteen tabs and the page drew only ${chrome.length} '
            'tears, so the strip is not being measured');
  });
}
