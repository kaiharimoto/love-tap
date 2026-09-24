// A phone that has not been paired draws nobody at the top of it, and the setup list lights no tab.
//
// The cycle 3 coherence critic read 17_setup_pwa as a shell for a relationship that did not exist
// yet: NEED and ENERGY dials for a partner nobody had paired, over a setup list, under a lit CHAT
// card. 10_first_run had the same dials. Both scenes start on an empty log. So the partner strip is
// drawn only once something the other person wrote is in the log, and while the setup list is up no
// card is lit -- though every card is still there, because tapping one is the only way out of it.
//
// Anchored to what the app declares: the PartnerStrip widget and its NEED/ENERGY stamps, the author
// of an event in the log, and the size each tab card's label is stamped at. Not to a coordinate.
//
// Re-break: draw PartnerStrip unconditionally in app.dart and `a fresh install draws nobody` fails;
// pass `_index` rather than `-1` to _Tabs while setup is up and `the setup list lights no tab` fails;
// drop the desk's own clover from app.dart and the same case fails on the clover (firing 61: without
// it 10_first_run and 17_setup_pwa read 0.1% and 0.0 accent against section 7's 1%).
// `partner_state_says_how_old_it_is_test.dart` holds the other side: on the seeded year, with the
// same setup list up, the strip is still drawn and still says when they were last heard from.
import 'package:desk/app.dart';
import 'package:desk/material/desk.dart';
import 'package:desk/material/hands.dart';
import 'package:desk/material/library.dart';
import 'package:desk/material/objects.dart';
import 'package:desk/scope.dart';
import 'package:desk/setup/checklist.dart';
import 'package:desk/setup/setup_region.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/transport/local/local_transport.dart';
import 'package:desk/transport/sync.dart';
import 'package:desk/voice/strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String? absent;
  final now = DateTime.utc(2026, 9, 3, 19, 40);
  const labels = [S.pulse, S.chat, S.us, S.moments, S.settings];

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
    } catch (_) {
      absent = 'this bundle was packed without a material library '
          '(tools/pack_assets.py --seed=year puts it in)';
    }
  });

  /// A phone that has just been installed: teo's iPhone, and an empty log, which is what both
  /// 10_first_run and 17_setup_pwa start from (their reports say `events: 0`).
  Future<AppScope> fresh({List<Event> already = const []}) async {
    final spine = await Spine.open(
        SpineStore.memory(), const Identity(person: Person.teo, device: DeviceKind.pwa));
    if (already.isNotEmpty) await spine.importSeed(already);
    final t = LocalTransport(role: TransportRole.client, spine: spine, deviceId: 'test');
    return AppScope(
      spine: spine,
      transport: t,
      sync: SyncEngine(spine: spine, transport: t),
      clock: Clock(frozenAt: now),
    );
  }

  Future<void> pump(WidgetTester tester, AppScope scope) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(AppScope.provide(scope: scope, child: const MaterialApp(home: Shell())));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// The five tab cards, by the label each is stamped with, and whether each one is lit. The lit
  /// card's label is stamped larger than the rest (its ink is the same since `Pen.margin` was
  /// darkened to `Pen.stamp`'s), so lit is "larger than the smallest of the five".
  Map<String, bool> tabs(WidgetTester tester) {
    final cards = [
      for (final w in tester.widgetList<Stamped>(find.byType(Stamped)))
        if (labels.contains(w.text)) w,
    ];
    if (cards.isEmpty) return const {};
    final least = cards.map((w) => w.size).reduce((a, b) => a < b ? a : b);
    return {for (final w in cards) w.text: w.size > least};
  }

  testWidgets('a fresh install draws nobody at the top, and the setup list lights no tab',
      (tester) async {
    if (absent != null) return markTestSkipped(absent!);
    final scope = await fresh();
    expect(scope.partnerHeardFrom, isFalse);
    await pump(tester, scope);

    // POPULATION: the setup list is up and its steps are on it.
    expect(find.byType(SetupSheet), findsOneWidget, reason: 'the scenario is the setup list');
    expect(find.text(kPwaSetup.first.title), findsWidgets);

    expect(find.byType(PartnerStrip), findsNothing,
        reason: 'nobody has been heard from, and the strip drew dials for them anyway');
    expect(find.text('NEED'), findsNothing);
    expect(find.text('ENERGY'), findsNothing);

    // The clover rode on the strip and is the one coloured thing on the screen (COLOR.md section 7
    // item 5). With no strip it lies on the desk, once, and not over a word.
    expect(find.byType(PressedClover), findsOneWidget,
        reason: 'taking the strip away took the only coloured thing on the screen with it');
    final leaf = tester.getRect(find.byType(PressedClover));
    for (final e in find.byType(Text).evaluate()) {
      final w = e.widget as Text;
      if ((w.data ?? '').trim().isEmpty) continue;
      final r = tester.getRect(find.byWidget(w).first);
      expect(leaf.overlaps(r), isFalse, reason: 'the clover at $leaf lies over "${w.data}" at $r');
    }

    final lit = tabs(tester);
    expect(lit.keys.toSet(), labels.toSet(), reason: 'every card is still there to leave by');
    expect(lit.values.where((l) => l), isEmpty,
        reason: 'the setup list is none of the five, and ${lit.entries.where((e) => e.value).map((e) => e.key)} was lit under it');
  });

  testWidgets('leaving the list by a card lights that card, and still draws nobody',
      (tester) async {
    if (absent != null) return markTestSkipped(absent!);
    final scope = await fresh();
    await pump(tester, scope);
    await tester.tap(find.byWidgetPredicate((w) => w is Stamped && w.text == S.chat));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(SetupSheet), findsNothing, reason: 'a card is the way out of the list');
    final lit = tabs(tester);
    expect(lit[S.chat], isTrue, reason: 'on chat, the chat card says where you are');
    expect(lit.values.where((l) => l).length, 1);
    expect(find.byType(PartnerStrip), findsNothing,
        reason: 'this is 10_first_run: chat on an empty log, and still nobody to draw');
    // and the clover is on this screen too, clear of `search`, which is written top right
    expect(find.byType(PressedClover), findsOneWidget);
    final leaf = tester.getRect(find.byType(PressedClover));
    for (final e in find.byType(Text).evaluate()) {
      final w = e.widget as Text;
      if ((w.data ?? '').trim().isEmpty) continue;
      final r = tester.getRect(find.byWidget(w).first);
      expect(leaf.overlaps(r), isFalse, reason: 'the clover at $leaf lies over "${w.data}" at $r');
    }
  });

  testWidgets('the strip arrives with the first thing they wrote', (tester) async {
    if (absent != null) return markTestSkipped(absent!);
    final theirs = Event(
      id: UlidFactory().next(now),
      seq: 1,
      author: Person.noor,
      device: DeviceKind.android,
      ts: now.millisecondsSinceEpoch,
      type: 'message',
      payload: const {'text': 'hello from the other phone'},
    );
    final scope = await fresh(already: [theirs]);
    expect(scope.partnerHeardFrom, isTrue);
    await pump(tester, scope);
    expect(find.byType(PartnerStrip), findsOneWidget);
    expect(find.text('NEED'), findsOneWidget);
    expect(find.text('ENERGY'), findsOneWidget);
    expect(find.byType(PressedClover), findsOneWidget, reason: 'one clover, the strip\'s');
  });
}
