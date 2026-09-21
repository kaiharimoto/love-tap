// `02_chat.png` is the most-measured artifact in the build, and the brief asks one thing of it
// four times over: *the capture log ... lists the tear-mask ids on screen in 02_chat.png with no
// id repeated and at least eight notes visible*. It has shipped with seven since firing 21.
//
// Firing 21 added a 40-logical strip of bare desk above the thread for the search affordance, the
// count fell from eight to seven, and nine firings read that as cause and effect: give the thread
// back the forty and the eighth note comes back. **That is not what the height does.** Measured
// here, at the old anchor, the chat region can be handed 40, 60 or 100 more logical pixels and
// the visible span does not move by one note in either direction -- 5195..5203, unchanged --
// because the next note down costs between 65 and 104 of them. The strip is not a note's worth of
// anything. The screen was landing on a run of long notes.
//
// So the shot is framed rather than the screen re-cut, which is the second of the two routes the
// queue item names, and it carries the item's own condition: the anchor has to be RECORDED, so
// the eight are reproducible rather than lucky. This test drives the app to whatever
// `evidence/scenes/02_chat.json` says and reads what the app then declares.
//
// AND THE ANCHOR IS A FRACTION, WHICH FIRING 37 GOT WRONG ONCE BEFORE GETTING IT RIGHT. It moved
// the scene to a seeded event id first, on the reasoning that an id is the same note in every
// capture while a fraction is an index into a thread whose length changes. The capture refuted
// it. A seeded id is `SeedLoader._ulidFor(key, ts)`: eighty bits of randomness derived from the
// key and forty-eight bits of time from the timestamp. The randomness is identical on the two
// rigs and the time is not -- index 5199 is `01KPV0SDX06FA58CJ9JXH23W7R` here and
// `0002V0SDX06FA58CJ9JXH23W7R` in the captured PWA, the same twenty-two-character tail under a
// different four-character head. An id read off this rig therefore names nothing over there:
// `indexWhere` returns -1, `_scrollToAnchor` returns without scrolling, and the shot is taken
// wherever the thread was standing, which is the end of it and six notes. An INDEX crosses
// cleanly -- both rigs read 8387 items and 0.622 is item 5216 in each -- so the scene names a
// fraction and this test resolves it the same way the app does.
//
// ON THE FLOOR OF ELEVEN, WHICH IS NOT THE BRIEF'S EIGHT. This rig is not the rig the artifact
// comes out of: `flutter test` lays the writing out with Skia and the capture with WebKit, and
// the two do not fit the same number of notes in 1040 logical pixels. At the old anchor this rig
// declares nine and the committed WebKit capture declared seven. Three is that measured gap
// rounded away from the floor, so eleven here is eight there. The number that closes the queue
// item is the one `evidence/logs/02_chat.report.json` carries after ./capture.sh, not this one;
// what this guards is the anchor drifting off a stretch that fits them.
//
// Re-break: put `0.62` back in the scene file and this reads nine against a floor of eleven.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:desk/capture/bus.dart';
import 'package:desk/capture/hooks.dart';
import 'package:desk/material/library.dart';
import 'package:desk/regions/chat/chat_region.dart';
import 'package:desk/scope.dart';
import 'package:desk/spine/seed_loader.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/transport/local/local_transport.dart';
import 'package:desk/transport/sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';

const Size _frame = Size(1440, 3120);
const double _dpr = 3.0;

/// The chat region's own viewport inside the shell, which is what `02_chat.png` is a picture of.
const double _region = 986;

/// What this rig fits over what WebKit fits, measured at the old anchor: nine here, seven in the
/// committed capture. The brief's floor is eight notes in the artifact.
const int _rigHeadroom = 3;

void main() {
  String? absent;
  late AppScope scope;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // The real hands, not the test font. Note heights are line counts and line counts are font
    // metrics: with `--use-test-fonts` this rig fits five notes where it otherwise fits nine, so
    // a sweep run against the test font measures the test font.
    for (final f in <(String, String)>[
      ('NoorHand', 'assets/fonts/NoorHand.ttf'),
      ('TeoHand', 'assets/fonts/TeoHand.ttf'),
      ('DeskStamp', 'assets/fonts/TeoHand.ttf'),
    ]) {
      await (FontLoader(f.$1)..addFont(rootBundle.load(f.$2))).load();
    }
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
        SpineStore.memory(), const Identity(person: Person.teo, device: DeviceKind.pwa));
    await SeedLoader(rootBundle).load(spine);
    final t = LocalTransport(role: TransportRole.client, spine: spine, deviceId: 'test');
    scope = AppScope(
        spine: spine,
        transport: t,
        sync: SyncEngine(spine: spine, transport: t),
        clock: Clock(frozenAt: DateTime.utc(2026, 9, 3, 19, 40)));
  });

  testWidgets('the anchor the scene names puts eight notes and eight tears on the screen',
      (tester) async {
    if (absent != null) return;

    // The scene file is the declaration; nothing here restates the anchor.
    final scene = jsonDecode(File('../evidence/scenes/02_chat.json').readAsStringSync())
        as Map<String, dynamic>;
    final step = (scene['steps'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((s) => s['do'] == 'scrollTo');
    final anchor = step['arg'] as String;
    final items = scope.thread.items;
    // Whatever the scene names, it has to resolve to a row. `_scrollToAnchor` fails SILENTLY on
    // one that does not -- `indexWhere` gives -1 and it returns without moving the list -- so an
    // anchor that names nothing costs a whole capture to notice.
    final fraction = double.tryParse(anchor);
    final resolved = fraction != null
        ? (fraction.clamp(0.0, 1.0) * (items.length - 1)).round()
        : items.indexWhere((it) => it.id == anchor);
    expect(resolved, greaterThanOrEqualTo(0),
        reason: 'the scene anchors 02_chat on "$anchor", which is in neither the thread nor the '
            'unit interval, so `_scrollToAnchor` will return without scrolling and the capture '
            'will shoot wherever the list happened to be standing');
    if (fraction == null) {
      // An id, which the capture's own id space may not share. See the note at the top.
      expect(items[resolved].id, equals(anchor));
    }

    tester.view.physicalSize = _frame;
    tester.view.devicePixelRatio = _dpr;
    addTearDown(tester.view.reset);
    CaptureBus.wanted = true;
    addTearDown(() => CaptureBus.wanted = false);
    await tester.pumpWidget(AppScope.provide(
      scope: scope,
      child: MaterialApp(
        home: Scaffold(
          body: Column(children: [
            const SizedBox(height: _region, child: ChatRegion()),
            const Spacer(),
          ]),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Never awaited: the handle ends in a real Future.delayed, and a widget test's clock does not
    // run until something pumps it, so awaiting it here deadlocks the test rather than failing it.
    unawaited(CaptureBus.scrollTo!(anchor));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);

    // Read exactly what tools/check/tears.py reads, off the same report the capture writes.
    final report = CaptureHooks(scope).report();
    final visible = (report['visible'] as List).cast<String>();
    final tears = <String, String>{};
    (report['tears'] as Map).forEach((k, v) {
      if (v != null) tears[k as String] = v as String;
    });

    expect(visible, hasLength(greaterThanOrEqualTo(8 + _rigHeadroom)),
        reason: 'the thread at the scene\'s anchor puts ${visible.length} notes on this rig, '
            'which is ${visible.length - _rigHeadroom} in the capture, under the eight the '
            'brief asks of 02_chat.png');
    expect(tears, hasLength(visible.length),
        reason: 'the app declared ${visible.length} notes on screen and a tear for only '
            '${tears.length} of them');

    final counts = <String, int>{};
    for (final t in tears.values) {
      counts[t] = (counts[t] ?? 0) + 1;
    }
    final repeats = counts.entries.where((e) => e.value > 1).map((e) => e.key).toList();
    expect(repeats, isEmpty,
        reason: 'the same tear mask is on the screen more than once: $repeats. The brief asks '
            'for no id repeated in 02_chat.png');

    // And the eight survive the bottom of the frame being cut where WebKit cuts it.
    final trimmed = visible.take(visible.length - _rigHeadroom).toList();
    expect(trimmed.map((id) => tears[id]).toSet(), hasLength(trimmed.length),
        reason: 'the notes that survive the frame repeat a tear between them');
  });

  testWidgets('the search margin is not what is keeping the eighth note off the screen',
      (tester) async {
    if (absent != null) return;
    // The claim nine firings of this build carried, measured. `kSearchMargin` is 40 logical; at
    // the old anchor the region can be given four times that and the span does not move.
    final spans = <double, String>{};
    for (final viewport in <double>[_region, _region + kSearchMargin, _region + 100]) {
      // The view is grown with the region rather than the region grown inside a fixed view:
      // a 1086-logical box inside a 1040-logical frame overflows the `Column` and the framework
      // fails the test for it, which says nothing about the thread.
      tester.view.physicalSize = Size(_frame.width, viewport * _dpr);
      tester.view.devicePixelRatio = _dpr;
      addTearDown(tester.view.reset);
      CaptureBus.wanted = true;
      addTearDown(() => CaptureBus.wanted = false);
      await tester.pumpWidget(AppScope.provide(
        scope: scope,
        child: MaterialApp(
          home: Scaffold(
            body: Column(children: [SizedBox(height: viewport, child: const ChatRegion())]),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      unawaited(CaptureBus.scrollTo!('0.62'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      spans[viewport] = jsonEncode(CaptureHooks(scope).report()['scroll']);
    }
    expect(spans[_region], equals(spans[_region + kSearchMargin]),
        reason: 'giving the thread back the search margin changes what is on the screen, so the '
            'margin is a live suspect after all and this test is the one that is wrong: '
            '${spans[_region]} against ${spans[_region + kSearchMargin]}');
    expect(spans[_region], equals(spans[_region + 100]),
        reason: 'a hundred logical pixels moves the span: ${spans[_region]} against '
            '${spans[_region + 100]}');
  });
}
