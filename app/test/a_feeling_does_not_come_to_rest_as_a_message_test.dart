// The row's own named failure mode, in the highest-resolution artifact in the set.
//
// In 13_messenger_states.png the feeling `empty chair` comes to rest under its drawn object as
//
//     empty chair
//     Thu 3 Sep · 17:19 read ✓✓
//
// which is, line for line, the furniture of the text message fourteen hundred pixels below it:
//
//     left the key under the pot
//     Thu 3 Sep · 19:40 read ✓✓
//
// The row is about a gesture arriving as a sensation rather than as a message in a different
// colour. Cycle 3 earned its points there by fixing the ARRIVAL and never touched the resting
// state, which is what both blocking findings are about.
//
// A feeling that has landed has no pencil line under it now: no time, no tick, no receipt. It
// keeps one while it is still in the outbox, because a feeling that has not gone has something to
// say and a `try again` to offer, and that is on the same line.
//
// Re-break by making `_marginBelongs` return true for everything and watching the read receipt
// come back under the object.

import 'package:desk/capture/bus.dart';
import 'package:desk/capture/hooks.dart';
import 'package:desk/material/library.dart';
import 'package:desk/regions/chat/chat_region.dart';
import 'package:desk/scope.dart';
import 'package:desk/spine/projections/thread.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/transport/local/local_transport.dart';
import 'package:desk/transport/sync.dart';
import 'package:desk/voice/strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await MaterialLibrary.load();
  });

  /// One thread: a message of mine they have read, and a feeling of mine they have read.
  Future<AppScope> desk({required bool feelingDelivered}) async {
    final spine = await Spine.open(
        SpineStore.memory(), const Identity(person: Person.teo, device: DeviceKind.pwa));
    final at = DateTime.utc(2026, 9, 3, 19, 40);
    await spine.append('message', {'text': 'left the key under the pot'},
        at: at, hostAssign: true);
    if (feelingDelivered) {
      await spine.append('feeling', {'feeling_id': 'nyeh', 'intensity': 0.8},
          at: at.add(const Duration(minutes: 1)), hostAssign: true);
    } else {
      await spine.append('feeling', {'feeling_id': 'nyeh', 'intensity': 0.8},
          at: at.add(const Duration(minutes: 1)));
    }
    // their read marker, over everything with a seq
    await spine.applyFromHost([
      Event(
        id: UlidFactory().next(at.add(const Duration(minutes: 2))),
        seq: spine.maxSeq + 1,
        author: Person.noor,
        device: DeviceKind.android,
        ts: at.add(const Duration(minutes: 2)).millisecondsSinceEpoch,
        type: 'read_marker',
        payload: {'upto_seq': spine.maxSeq},
      ),
    ]);
    final t = LocalTransport(role: TransportRole.client, spine: spine, deviceId: 'x');
    return AppScope(
      spine: spine,
      transport: t,
      sync: SyncEngine(spine: spine, transport: t),
      clock: Clock(frozenAt: at.add(const Duration(hours: 1))),
    );
  }

  Future<List<Map<String, dynamic>>> draw(WidgetTester tester, AppScope scope) async {
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    CaptureBus.wanted = true;
    addTearDown(() => CaptureBus.wanted = false);
    await tester.pumpWidget(AppScope.provide(
      scope: scope,
      child: const MaterialApp(home: Scaffold(body: ChatRegion())),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    return CaptureHooks.textRuns();
  }

  testWidgets('a feeling at rest carries no time, no tick and no read receipt', (tester) async {
    final scope = await desk(feelingDelivered: true);
    addTearDown(() async {
      scope.dispose();
      await scope.spine.close();
    });
    final feeling = scope.thread.items.firstWhere((i) => i.type == 'feeling');
    expect(feeling.delivery, Delivery.read, reason: 'the row this is about is one they have read');

    final texts = [for (final r in await draw(tester, scope)) r['text'] as String];
    expect(texts, contains('nyeh'), reason: 'the feeling is not on the desk at all');
    expect(texts, contains('left the key under the pot'));

    // The message keeps its line. Exactly one of them, so a receipt that came back would show.
    expect(texts.where((t) => t.contains(S.read)).length, 1,
        reason: 'a read receipt is drawn under something other than the message: $texts');
    final stamped = texts.where((t) => t.contains('Sep')).toList();
    expect(stamped, hasLength(1),
        reason: 'a feeling came to rest with a timestamp under it, which is the furniture of a '
            'message: $stamped');
  });

  testWidgets('a feeling that has not gone still says so', (tester) async {
    final scope = await desk(feelingDelivered: false);
    addTearDown(() async {
      scope.dispose();
      await scope.spine.close();
    });
    final feeling = scope.thread.items.firstWhere((i) => i.type == 'feeling');
    scope.spine.markRefused(feeling.id, S.refusedUnreadable);
    final texts = [for (final r in await draw(tester, scope)) r['text'] as String];
    expect(texts, contains(S.refused),
        reason: 'a feeling stuck in the outbox is silent, which is the hole the item above this '
            'one closed for messages');
    expect(texts, contains(S.tryAgain));
  });

  test('a read marker is never a row in the thread', () async {
    // The standing failure condition, and it is settled in the registry rather than by a filter
    // somewhere downstream, so there is one place it can go wrong.
    expect(kEventTypeById['read_marker']!.rowInThread, isFalse);
    final spine = await Spine.open(
        SpineStore.memory(), const Identity(person: Person.teo, device: DeviceKind.pwa));
    final at = DateTime.utc(2026, 9, 3, 19, 40);
    await spine.append('message', {'text': 'left the key under the pot'},
        at: at, hostAssign: true);
    await spine.applyFromHost([
      Event(
        id: UlidFactory().next(at),
        seq: spine.maxSeq + 1,
        author: Person.noor,
        device: DeviceKind.android,
        ts: at.millisecondsSinceEpoch,
        type: 'read_marker',
        payload: {'upto_seq': spine.maxSeq},
      ),
    ]);
    final thread = projectThread(spine.all, me: Person.teo);
    expect(thread.items.map((i) => i.type), isNot(contains('read_marker')));
    expect(thread.items, hasLength(1));
    await spine.close();
  });

  test('the registry is the one place a type says whether it is a row', () async {
    // A type added
    // later cannot quietly become a row in the thread without this saying so.
    final notRows = [for (final t in kEventTypes) if (!t.rowInThread) t.id];
    expect(notRows, containsAll(<String>['read_marker', 'reaction', 'message_edit']));
  });
}

