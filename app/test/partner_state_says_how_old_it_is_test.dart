// With the link down, what the app shows of the other person is last-known, and it says so.
//
// The partner strip above every region and their sheet on Pulse draw the last state the log holds.
// On a build whose link said `connecting`, the cycle 3 critics read `travelling` and `needs a lot`
// as news, because nothing on the screen said they were not: last-known state drawn exactly like
// live state. On a real pair that is every time the phones lose each other. So while the link is
// not up both say when the other phone was last heard from, anchored to the last event of theirs
// in the log; while it is up they say nothing extra.
//
// And their sheet says where they are once: `place` declared `travelling` beside `at home: yes`
// sensed later is two answers to one question, and only the newer is drawn.
//
// Re-break: drop `lastHeard: scope.partnerLastHeard` from the strip in app.dart, and `the strip
// says when` fails; drop `_where()`'s disagreement branch and `says where once` fails.
import 'package:desk/app.dart';
import 'package:desk/material/library.dart';
import 'package:desk/regions/pulse/pulse_region.dart';
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
  final now = DateTime.utc(2026, 9, 3, 19, 40);

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
      clock: Clock(frozenAt: now),
    );
  });

  /// The last event of theirs in the log: what "last heard" has to be read off.
  int theirLast() => scope.spine.all.lastWhere((e) => e.author == scope.partner).ts;

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(AppScope.provide(scope: scope, child: MaterialApp(home: child)));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('the strip says when they were last heard from while the link is down',
      (tester) async {
    if (absent != null) return markTestSkipped(absent!);
    expect(scope.link.state, isNot(LinkState.connected),
        reason: 'the scenario has to be a link that is down');
    final said = S.lastHeard(now.millisecondsSinceEpoch, theirLast());
    expect(said, isNot('last heard just now'),
        reason: 'the seeded year\'s last word from them is older than the frozen clock');
    await pump(tester, const Shell());
    expect(find.text(said), findsWidgets, reason: 'the shell\'s partner strip does not say "$said"');
  });

  testWidgets('their sheet on Pulse says it too, and says nothing extra with the link up',
      (tester) async {
    if (absent != null) return markTestSkipped(absent!);
    final said = S.lastHeard(now.millisecondsSinceEpoch, theirLast());
    await pump(tester, const Scaffold(body: PulseRegion()));
    expect(find.text(said), findsOneWidget);

    final down = scope.link;
    scope.link = TransportStatus(name: down.name, role: down.role, state: LinkState.connected);
    addTearDown(() => scope.link = down);
    await pump(tester, const Scaffold(body: PulseRegion()));
    expect(find.textContaining('last heard'), findsNothing,
        reason: 'with the link up what is drawn is live, and says nothing about its age');
  });

  testWidgets('their sheet says where they are once', (tester) async {
    if (absent != null) return markTestSkipped(absent!);
    final them = scope.partnerState;
    final place = them['place'], home = them['at_home'];
    if (place == null || home == null) {
      return markTestSkipped('the seeded year has no place and at_home for them to compare');
    }
    await pump(tester, const Scaffold(body: PulseRegion()));
    final disagree = (them.place == 'home') != them.atHome;
    final placeShown = find.text(them.place!.replaceAll('_', ' ')).evaluate().isNotEmpty;
    final homeShown = find.text(them.atHome! ? 'yes' : 'no').evaluate().isNotEmpty;
    if (disagree) {
      expect(placeShown && homeShown, isFalse,
          reason: 'place "${them.place}" and at home "${them.atHome}" contradict, and both are drawn');
      expect(home.at >= place.at ? homeShown : placeShown, isTrue,
          reason: 'the newer of the two is the one that is drawn');
    } else {
      expect(placeShown && homeShown, isTrue);
    }
  });
}
