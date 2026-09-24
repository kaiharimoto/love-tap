// A torn piece's writing is inset by the depth of its break, not by a share of its height.
//
// `safe` is measured as fractions of the MASK and was applied as fractions of the PIECE. The mask
// is nine-sliced: its torn bands keep the scale they were rendered at and only the middle
// stretches, so on a piece taller than its mask the break sits a fixed depth in, while a quarter
// of the piece's height grows with the piece. Solved with the writing, a slip was C/(1-fT-fB) tall,
// up to 2.9 times its writing. Us at firing 60 carried one module stamp over ~1200 px of blank
// paper, and the setup sheet opens on ~40% of empty paper above its first line.
//
// Anchored to what the app declares: a module's stamped label and the first row on its body slip
// (`us.body.<id>`), against 03_us's own frame (480x1040 at 3x) less the tab strip; and the insets
// against the library's own mask sizes and safe fractions.
//
// Measured at firing 61, the seeded year in 03_us's frame: us.body.dates 900 -> 742 points tall,
// the stubs 253 -> 225 and 329 -> 297, and the TO DO stamp arrives on the screen at y934-946 of
// 978 open (before: not built, being past the fold); its first row, at y1102, does not yet. CALENDAR and RITUALS are still below it -- the item
// `three-of-the-four-modules-are-below-the-fold...` stays open for the rest, which is the masks'
// transparent borders around the paper and a torn stub nested in a torn body, not the insets.
//
// Re-break: have `_RenderWithinTear.performLayout` skip `_layoutBySlice` and the widget test fails;
// have `SlicedMasks.safeInsets` return the plain shares and the arithmetic test fails.
import 'package:desk/app.dart';
import 'package:desk/material/hands.dart';
import 'package:desk/material/library.dart';
import 'package:desk/material/paper.dart';
import 'package:desk/material/slip.dart';
import 'package:desk/modules/registry.dart';
import 'package:desk/scope.dart';
import 'package:desk/spine/seed_loader.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/transport/local/local_transport.dart';
import 'package:desk/transport/sync.dart';
import 'package:desk/voice/strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String? absent;
  late AppScope scope;
  const frame = Size(480, 1040);

  setUpAll(() async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    for (final channel in const [
      MethodChannel('com.llfbandit.record/messages'),
      MethodChannel('xyz.luan/audioplayers'),
      MethodChannel('xyz.luan/audioplayers.global'),
    ]) {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async => null);
    }
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
      await rootBundle.loadString('assets/seed/index.json');
    } catch (_) {
      absent = 'this bundle was packed without the year (tools/pack_assets.py --seed=year)';
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
      clock: Clock(frozenAt: DateTime.utc(2026, 9, 3, 19, 40)),
    );
  });

  testWidgets('the dates, with a row, and the list\'s stamp are on one screen', (tester) async {
    if (absent != null) return markTestSkipped(absent!);
    tester.view.physicalSize = frame * 3.0;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(AppScope.provide(scope: scope, child: const MaterialApp(home: Shell())));
    await tester.pump();
    await tester.tap(find.byWidgetPredicate((w) => w is Stamped && w.text == S.us));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    // What the tab strip does not cover.
    final open = frame.height - kTabStrip;
    final seen = <String, String>{};
    final below = <String>[];
    // The two anyone reads standing up. All four is the open item's, and not yet reached.
    for (final m in kModules.take(2)) {
      final stamp = find.byWidgetPredicate((w) => w is Stamped && w.text == m.label);
      final body = find.byWidgetPredicate((w) => w is Slip && w.id == 'us.body.${m.id}');
      // A list builds only what is near the screen, so a module past the fold is not built at all.
      if (stamp.evaluate().isEmpty || body.evaluate().isEmpty) {
        seen[m.id] = 'not built';
        below.add(m.id);
        continue;
      }
      final label = tester.getRect(stamp.first);
      // POPULATION: the body has writing on it, read off the widgets the module built.
      final rows = find.descendant(of: body, matching: find.byType(Text));
      expect(rows, findsWidgets, reason: '${m.id} is on the screen and empty');
      final first = tester.getRect(rows.first);
      seen[m.id] = 'stamp ${label.top.round()}-${label.bottom.round()}, '
          'first row ${first.top.round()}-${first.bottom.round()}';
      // the dates with a row under them; the list's stamp, and its rows are the open item's
      if (label.bottom > open || (m.id == 'dates' && first.bottom > open)) below.add(m.id);
    }
    // ignore: avoid_print
    print('open to y=$open: $seen');
    expect(below, isEmpty, reason: '$below below the fold: $seen, and the screen is open to $open');
  });

  test('a torn piece is inset by the depth of its break, not by a share of its height', () {
    if (absent != null) return markTestSkipped(absent!);
    final lib = MaterialLibrary.instance;
    final tear = lib.tears.firstWhere((e) => (e.safe?[1] ?? 0) > 0.2).id;
    final safe = lib.safeOf(tear);
    final short = SlicedMasks.safeInsets(tear, safe, const Size(330, 120), 3.0);
    final tall = SlicedMasks.safeInsets(tear, safe, const Size(330, 700), 3.0);
    // at a size under the mask's own, it is the share it always was
    expect(short[1], closeTo(safe[1] * 120, 0.5));
    // at seven hundred points tall the piece is cut by the finer copy of its mask, drawn at that
    // copy's own scale, and the inset is the break's depth there -- not a share of 700 points
    final hi = lib.entry(lib.tearsHi, tear)!;
    expect(tall[1], closeTo(safe[1] * hi.h / 3.0, 0.5),
        reason: '$tear: top inset ${tall[1]} on a 700-point piece, the share was ${safe[1] * 700}');
    expect(tall[1], lessThan(safe[1] * 700));
  });
}
