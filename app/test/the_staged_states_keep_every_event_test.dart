// 13_messenger_states staged its states on unchanged code at firings 30, 51 and 54 and lost them
// at 56. Firing 59 ran the experiment rank 2 asked for before any fix: print the ids.
//
// `CaptureBus.stageStates` minted the partner's read marker from `UlidFactory.seeded(captureSeed)`
// -- a SECOND factory seeded like the spine's own -- at the frozen instant. A seeded factory's
// first id at a given millisecond is always the same string, so that marker was always a copy of
// the first id the spine had minted at that instant. In the capture that is teo's own read marker
// (`_scheduleRead` fires 600 ms after the thread opens, long before the scene stages), `...FKG`,
// which is why the staged message is `...FKH` in every committed report. `applyFromHost` found
// `...FKG` pending and took the partner's marker for the host assigning a seq to teo's: teo's read
// marker was replaced by noor's without a word. Printed on this rig:
//
//     mine=...FKG seen=...FKH marker=...FKG  marker==mine true
//
// Re-break by putting `UlidFactory.seeded(Flags.captureSeed).next(scope.clock.now())` back as the
// marker's id in `chat_region.dart`: `staging` then throws (the collision is refused out loud now)
// and `every staged row reaches the thread` fails on the thrown error. Re-break the loudness by
// deleting the author/type check in `Spine.applyFromHost` and `a host event under a held id` fails.
import 'package:desk/capture/bus.dart';
import 'package:desk/material/library.dart';
import 'package:desk/regions/chat/chat_region.dart';
import 'package:desk/scope.dart';
import 'package:desk/spine/seed_loader.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/transport/local/local_transport.dart';
import 'package:desk/transport/sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String? absent;

  setUpAll(() async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    // the recorder and the players the thread builds, as the tear test stubs them
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

  /// The capture's spine: the seeded year, and ids off the capture seed, as main.dart builds it.
  Future<AppScope> captureScope() async {
    final spine = await Spine.open(
      SpineStore.memory(),
      const Identity(person: Person.teo, device: DeviceKind.pwa),
      ulids: UlidFactory.seeded(20260903),
    );
    await SeedLoader(rootBundle).load(spine);
    final t = LocalTransport(role: TransportRole.client, spine: spine, deviceId: 'test');
    return AppScope(
      spine: spine,
      transport: t,
      sync: SyncEngine(spine: spine, transport: t),
      clock: Clock(frozenAt: DateTime.utc(2026, 9, 3, 19, 40)),
    );
  }

  testWidgets('every staged row reaches the thread, and teo keeps his own read marker',
      (tester) async {
    if (absent != null) {
      markTestSkipped(absent!);
      return;
    }
    final scope = (await tester.runAsync(captureScope))!;
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    CaptureBus.wanted = true;
    addTearDown(() => CaptureBus.wanted = false);

    final atOpen = scope.spine.length;
    await tester.pumpWidget(AppScope.provide(
      scope: scope,
      child: const MaterialApp(home: Scaffold(body: ChatRegion())),
    ));
    // the thread's own read, 600 ms after it opens, which is what the capture has done by the
    // time it stages: the first id the spine mints at the frozen instant is teo's marker
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 2)));
    }
    final mine = scope.spine.pending.where((e) => e.type == 'read_marker').toList();
    expect(mine, hasLength(1),
        reason: 'the scenario has to contain the defect: teo\'s read marker minted first');

    Object? thrown;
    await tester.runAsync(() async {
      try {
        await CaptureBus.stageStates!();
      } catch (e) {
        thrown = e;
      }
    });
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 2)));
    }
    expect(thrown, isNull, reason: 'staging threw: $thrown');

    // teo's marker is still his, and still waiting to go
    expect(scope.spine.byId(mine.single.id)?.author, Person.teo,
        reason: 'the partner\'s staged marker replaced teo\'s own read marker');

    // every row the staging creates is in the thread, with the state it was staged in
    final texts = [for (final it in scope.thread.items) it.text];
    for (final t in const [
      'left the key under the pot',
      'ok — leaving now',
      'and the bread, if there is any',
      'sending you the roster',
    ]) {
      expect(texts, contains(t), reason: '"$t" was staged and is not in the thread');
    }
    final seen = scope.thread.items.lastWhere((it) => it.text == 'left the key under the pot');
    expect(scope.thread.readUpto[scope.partner], seen.event.seq,
        reason: 'the partner\'s read marker is what makes the staged row say read');

    // POPULATION: nothing arrived or left beyond what the staging appends -- teo's marker, the
    // accepted message, the partner's marker and three in the outbox -- plus any read teo's
    // thread re-schedules once the new rows arrive, which is his and is counted separately.
    final teoMarkers = scope.spine.all
        .where((e) => e.type == 'read_marker' && e.author == Person.teo && e.ts >= seen.ts)
        .length;
    expect(scope.spine.length - atOpen, 5 + teoMarkers);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      scope.dispose();
      await scope.spine.close();
    });
  });

  test('a host event under a held id is refused out loud, not taken as an assignment', () async {
    if (absent != null) return;
    final spine = await Spine.open(
      SpineStore.memory(),
      const Identity(person: Person.teo, device: DeviceKind.pwa),
      ulids: UlidFactory.seeded(20260903),
    );
    final at = DateTime.utc(2026, 9, 3, 19, 40);
    final mine = await spine.append('read_marker', {'upto_seq': 0}, at: at);
    await expectLater(
      spine.applyFromHost([
        Event(
          id: mine.id,
          seq: 1,
          author: Person.noor,
          device: DeviceKind.android,
          ts: mine.ts,
          type: 'read_marker',
          payload: const {'upto_seq': 0},
        ),
      ]),
      throwsStateError,
    );
    expect(spine.byId(mine.id)?.author, Person.teo);
    // and the id the spine mints for a hand-built event is new to it
    expect(spine.mintId(at), isNot(mine.id));
    await spine.close();
  });
}
