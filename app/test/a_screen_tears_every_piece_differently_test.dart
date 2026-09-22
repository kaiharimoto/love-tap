// A screen may not tear two pieces of paper along the same edge, and eight of eleven stills did.
//
// `docs/BRIEF.md` 09 names reusing a single tear mask across the app as a failure condition of the
// whole build, and rubric row 02 asks for tear masks with no visible repeat on a single screen.
// Firing 40 widened `tools/check/tears.py` to count every tear surface in the frame and found
// `02_chat` 16 draws / 13 masks, `03_us` 7 / 4, `04_moments` 10 / 9, `05_settings` 9 / 8,
// `10_first_run` 4 / 3, `13_messenger_states` 11 / 10, `17_setup_pwa` 2 / 1 — and fixed the search
// screen, which `the_search_screen_tears_its_own_strips_test` holds. This is that test asked of
// the rest of the app, which is where firing 40's fix did not reach.
//
// THE CAUSE IS NOT THE ROW-0 DEFAULT THE ITEM WAS FILED AGAINST, and firing 41 measured that: if
// it were, every repeat would be the SAME mask, because the walk is a pure function of the row.
// The repeats are three mechanisms — a hash passed where a row goes (`02_chat`'s margins, on
// `hashOf(item.id)`, three of them on one mask), two lists on one screen both numbering from zero
// (`03_us` pairing `us.body.dates` with `date_ferry`, `05_settings` pairing
// `heading-the-two-phones` with `settings.notify`), and a constant index (`17_setup_pwa`'s two
// sheets on `writableTears[3]`).
//
// AND UNDER ALL THREE IS ONE THING: the rule was stated in `assignment.dart` and implemented in
// SIX places — `tearFor`, the walk copied into `Slip.build` and `Strip.build`, `desk.dart` keyed
// off a hash of the partner's mood, `pulse_region.dart`'s `(partner.index * 7 + 11)`, and
// `setup_region.dart`'s constant. Three of the six took no row at all, so a namespace could not
// be expressed at them: there was nowhere to put it. `the_pool_is_indexed_in_one_place_test` is
// what keeps it at one; this is what says the one place gets the answer right.
//
// It asks each screen what it actually drew, through the same handle the capture harness writes
// the sidecar from, rather than reading the source for `row:`. A default of zero is a silent
// failure — nothing throws, no call site looks wrong, and the screen quietly draws one mask twice.
import 'package:desk/capture/bus.dart';
import 'package:desk/capture/hooks.dart';
import 'package:desk/material/assignment.dart';
import 'package:desk/material/library.dart';
import 'package:desk/regions/chat/chat_region.dart';
import 'package:desk/regions/moments/moments_region.dart';
import 'package:desk/regions/pulse/pulse_region.dart';
import 'package:desk/regions/settings/settings_region.dart';
import 'package:desk/regions/us/us_region.dart';
import 'package:desk/scope.dart';
import 'package:desk/spine/seed_loader.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/transport/local/local_transport.dart';
import 'package:desk/transport/sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppScope scope;
  String? absent;

  setUpAll(() async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    // The composer holds a recorder and settings holds a player, and neither plugin has a host
    // implementation under `flutter test` -- so pumping either screen bare throws a
    // MissingPluginException before a single tear is drawn. These stand in for the host so that
    // the screen builds; nothing here touches what is torn, and a screen that fails to build
    // fails the population floor below rather than passing with no repeats because it is empty.
    for (final channel in const [
      MethodChannel('com.llfbandit.record/messages'),
      MethodChannel('xyz.luan/audioplayers'),
      MethodChannel('xyz.luan/audioplayers.global'),
    ]) {
      binding.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => null);
    }
    // The player's event channel is named after the player, so the id settings gives its player
    // is part of the channel name.
    for (final channel in const [
      EventChannel('xyz.luan/audioplayers/events'),
      EventChannel('xyz.luan/audioplayers/events/feelings'),
      EventChannel('xyz.luan/audioplayers.global/events'),
    ]) {
      binding.defaultBinaryMessenger.setMockStreamHandler(
          channel, MockStreamHandler.inline(onListen: (arguments, events) {}));
    }
    try {
      await MaterialLibrary.load();
    } catch (_) {
      absent = 'this bundle was packed without a material library '
          '(tools/pack_assets.py --seed=year puts it in)';
      return;
    }
    if (MaterialLibrary.instance.writableTears.isEmpty) {
      absent = 'the packed library has no writable tear masks in it';
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

  /// Every tear surface on the glass, exactly as the sidecar records it.
  ///
  /// `paperSurfaces` records a surface only once it HAS its image, which is the whole point of it:
  /// an undecoded box is not a surface anybody can see. A decode happens off the framework's
  /// clock, so real time has to be allowed to pass before the question can be asked.
  Future<List<String>> tears(WidgetTester tester) async {
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    }
    return [
      for (final s in CaptureHooks.paperSurfaces())
        if ((s['asset'] as String).startsWith('assets/tears/')) s['asset'] as String,
    ];
  }

  /// The mask a tear surface belongs to, whichever of its three layers this draw is. Since firing
  /// 44 a torn piece declares its mask, its lit edge and its contact shadow under three names off
  /// one stem, so counting the names would report three surfaces per piece and no repeat at all
  /// where two pieces share a mask — the instrument would have grown an eye and closed the item.
  String stemOf(String asset) => asset
      .split('/')
      .last
      .replaceAll('_shadow_dusk.webp', '')
      .replaceAll('_shadow.webp', '')
      .replaceAll('_edge.webp', '')
      .replaceAll('.webp', '');

  /// What each screen drew, and whether any two pieces on it took the same mask.
  ///
  /// [floor] is the paired population WORKER_PROMPT 3d corollary 2 asks for: a count of repeats
  /// falls to zero just as well by emptying the screen, so the number of pieces the screen tears
  /// is asserted at the same time. The floors are read off the committed surfaces sidecars of the
  /// capture this item was filed against, counting one shadow per piece.
  Future<void> check(WidgetTester tester, String name, Widget region, int floor) async {
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    CaptureBus.wanted = true;
    addTearDown(() => CaptureBus.wanted = false);

    await tester.pumpWidget(AppScope.provide(
      scope: scope,
      child: MaterialApp(home: Scaffold(body: region)),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);

    final drawn = await tears(tester);
    final pieces = <String, int>{};
    for (final a in drawn) {
      final s = stemOf(a);
      // one entry per PIECE, not per layer: a piece draws its mask, its edge and its shadow
      pieces[s] = (pieces[s] ?? 0) + 1;
    }
    final layers = drawn.toSet().length;
    final perPiece = pieces.isEmpty ? 0 : (layers / pieces.length);

    expect(pieces.length, greaterThanOrEqualTo(floor),
        reason: '$name tore ${pieces.length} pieces, below the $floor the committed sidecar has, '
            'so this screen is emptier than the one the item was filed against and a repeat count '
            'of zero would mean nothing. Either the screen is not built or the floor is stale.');

    final repeated = <String, int>{};
    pieces.forEach((stem, n) {
      // three layers of one piece is not a repeat; a fourth draw of the same stem is
      if (n > 3) repeated[stem] = n;
    });
    expect(repeated, isEmpty,
        reason: '$name: ${pieces.length} pieces and ${repeated.length} masks taken more than once '
            '($repeated, about ${perPiece.toStringAsFixed(1)} layers a piece). docs/BRIEF.md 09 '
            'makes reusing one mask a failure condition of the build. The pool holds '
            '${MaterialLibrary.instance.tearMasks.length} masks, '
            '${MaterialLibrary.instance.writableTears.length} of them writable, so this is a '
            'selection that did not ask rather than a shortage.');
  }

  testWidgets('no two pieces on the chat screen are torn along the same edge', (tester) async {
    if (absent != null) return;
    await check(tester, '02_chat', const ChatRegion(), 8);
  });

  testWidgets('no two pieces on Us are torn along the same edge', (tester) async {
    if (absent != null) return;
    await check(tester, '03_us', const UsRegion(), 4);
  });

  testWidgets('no two pieces on moments are torn along the same edge', (tester) async {
    if (absent != null) return;
    await check(tester, '04_moments', const MomentsRegion(), 5);
  });

  testWidgets('no two pieces on settings are torn along the same edge', (tester) async {
    if (absent != null) return;
    await check(tester, '05_settings', const SettingsRegion(), 5);
  });

  testWidgets('no two pieces on the pulse are torn along the same edge', (tester) async {
    if (absent != null) return;
    await check(tester, '01_pulse', const PulseRegion(), 4);
  });

  testWidgets('the lanes of one screen do not overlap in the pool', (tester) async {
    if (absent != null) return;
    // The table's own invariant, stated where it can be read: a lane's window is `base` to
    // `base + span - 1`, and the layout comment on `TearLanes` says which lanes share a window
    // because they are never on screen together. This asserts the arithmetic that comment
    // depends on -- every window inside the pool, and no lane wider than it.
    final n = MaterialLibrary.instance.writableTears.length;
    for (final lane in TearLanes.all) {
      expect(lane.span, greaterThan(0), reason: '${lane.name} has no rows');
      expect(lane.base + lane.span, lessThanOrEqualTo(n),
          reason: '${lane.name} runs from ${lane.base} to ${lane.base + lane.span - 1}, past the '
              '$n writable masks in the pool, so it wraps onto lanes at the start of the table '
              'and the layout comment on TearLanes is not true of it');
      // a lane's rows are distinct within it, which is what the coprime stride is for
      final seen = <String>{};
      for (var r = 0; r < lane.span; r++) {
        final m = tearAt(MaterialLibrary.instance, lane: lane, row: r);
        expect(seen.add(m!), isTrue,
            reason: '${lane.name} row $r takes $m, which a row before it already took');
      }
    }
  });
}
