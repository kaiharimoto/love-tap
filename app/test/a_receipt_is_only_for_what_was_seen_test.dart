// A read receipt for a note the reader has never seen.
//
// `AppScope.markRead()` wrote a read marker over the whole thread six hundred milliseconds after
// the chat region opened, while `Note` kept a note of theirs that arrived above the reader's
// frozen arrival marker drawn FOLDED SHUT. So the app told the other person `read` for a sheet
// whose writing was never on the screen and could not have been read. The rubric's clause for
// this row is "a delivery and read marker that cannot be trusted"; a receipt that fires on a
// closed envelope is the exact thing, and it is worse than no receipt at all, because the other
// person acts on it.
//
// It is not the same defect as the folded sheet rendering as a flat slab. That one is about how a
// closed note LOOKS. This one is about the app asserting something untrue to another person, and
// fixing the render does not fix it.
//
// Re-break by restoring the blanket `markRead()` -- dropping the `notPast:` argument in
// `_scheduleRead`, or the clamp inside `markRead` -- and watching `the marker stops below a note
// that is still folded` put the marker on the unopened row.
import 'package:desk/material/fold.dart';
import 'package:desk/material/library.dart';
import 'package:desk/regions/chat/chat_region.dart';
import 'package:desk/regions/chat/note.dart';
import 'package:desk/scope.dart';
import 'package:desk/spine/projections/thread.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/transport/local/local_transport.dart';
import 'package:desk/transport/sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// One row of the thread, at a given seq, by a given person.
Event _row(int seq, Person by, String text) => Event(
      id: 'row$seq',
      seq: seq,
      author: by,
      device: by == Person.noor ? DeviceKind.android : DeviceKind.pwa,
      ts: DateTime.utc(2026, 9, 3, 19, 40 + seq).millisecondsSinceEpoch,
      type: 'message',
      payload: {'text': text},
    );

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await MaterialLibrary.load();
  });

  // The thread teo is looking at. Rows 1 and 2 were read before this session; rows 3 and 4
  // arrived while teo was away, and 3 is noor's -- so 3 lies folded and 4 sits behind it.
  List<ThreadItem> theThread() => projectThread([
        _row(1, Person.teo, 'are you still in it'),
        _row(2, Person.noor, 'yes. floor 3 apparently.'),
        _row(3, Person.noor, 'the key is under the pot'),
        _row(4, Person.teo, 'see you tues'),
      ]).items;

  test('the fold is actually available, or none of this measures anything', () {
    // Without a sequence on disk a note lies flat, nothing is ever folded, and every assertion
    // below would pass for the wrong reason. This is the guard against a green suite that has
    // stopped looking.
    expect(FoldedNote.available, isTrue,
        reason: 'assets/folds/unfold_thirds is not packed; run tools/pack_assets.py --seed=year');
  });

  test('a note above the arrival marker is folded, and one below it is not', () {
    final items = theThread();
    expect(noteLiesFolded(items[1], me: Person.teo, unreadFrom: 2), isFalse,
        reason: 'row 2 was already read when the thread was opened');
    expect(noteLiesFolded(items[2], me: Person.teo, unreadFrom: 2), isTrue,
        reason: 'row 3 is theirs and arrived above the marker, so it is lying folded');
    expect(noteLiesFolded(items[3], me: Person.teo, unreadFrom: 2), isFalse,
        reason: 'row 4 is mine; nothing of mine is ever folded');
  });

  test('the marker stops below a note that is still folded', () {
    final items = theThread();
    // The scenario has to contain the defect or the assertion below is empty: the latest row is
    // 4, and an honest marker cannot reach it, which is exactly the gap the blanket markRead()
    // used to cross.
    expect(items.last.event.seq, 4);
    expect(seenUpto(items, me: Person.teo, unreadFrom: 2, opened: const {}), 2,
        reason: 'row 3 is folded and unopened, so nothing at or above it has been seen');
  });

  test('and passes it once its writing has actually arrived', () {
    final items = theThread();
    expect(seenUpto(items, me: Person.teo, unreadFrom: 2, opened: const {3}), 4,
        reason: 'with row 3 opened, row 4 behind it is visible too and the marker may reach it');
  });

  test('the same thread read from the other side folds the other rows', () {
    // Worth keeping as its own case, because it is the check that `me` is really being used and
    // not quietly assumed. From noor's side rows 2 and 3 are hers and cannot fold, and it is
    // row 4 -- teo's, above her marker -- that is lying shut. So her honest ceiling is 3, not 4,
    // and the first draft of this test asserted 4 and was wrong about which rows were whose.
    final items = theThread();
    expect(seenUpto(items, me: Person.noor, unreadFrom: 2, opened: const {}), 3,
        reason: 'row 4 is teo\'s and above her marker, so it is the one lying folded');
    expect(seenUpto(items, me: Person.noor, unreadFrom: 2, opened: const {4}), 4,
        reason: 'and opening it lets her marker reach the end');
  });

  test('a thread whose first unread row is folded moves the marker nowhere', () {
    final items = theThread();
    expect(seenUpto(items, me: Person.teo, unreadFrom: 1, opened: const {}), 1,
        reason: 'row 2 is theirs and above the marker, so the marker cannot leave row 1');
  });

  test('markRead writes the marker at the ceiling and not at the latest row', () async {
    final spine = await Spine.open(
        SpineStore.memory(), const Identity(person: Person.teo, device: DeviceKind.pwa));
    for (final e in [
      ['teo', 'are you still in it'],
      ['noor', 'yes. floor 3 apparently.'],
      ['noor', 'the key is under the pot'],
      ['teo', 'see you tues'],
    ]) {
      await spine.append('message', {'text': e[1]}, hostAssign: true);
    }
    final t = LocalTransport(role: TransportRole.client, spine: spine, deviceId: 'x');
    final scope = AppScope(
      spine: spine,
      transport: t,
      sync: SyncEngine(spine: spine, transport: t),
      clock: Clock(frozenAt: DateTime.utc(2026, 9, 3, 19, 40)),
    );
    addTearDown(() async {
      scope.dispose();
      await spine.close();
    });

    final latest = scope.thread.latestSeq();
    expect(latest, isNotNull);
    await scope.markRead(notPast: 2);
    // `scope.thread` is rebuilt by the spine subscription, not by `emit` returning, so the
    // projection needs a turn of the event loop before it has seen the marker.
    await Future<void>.delayed(Duration.zero);
    final marked = scope.thread.readUpto[Person.teo] ?? 0;
    expect(marked, 2,
        reason: 'the ceiling is what is written, not thread.latestSeq()');
    expect(marked, lessThan(latest!),
        reason: 'and the two differ here, so the clamp is doing work');
  });

  // The unit cases above hold `markRead` to its ceiling. This one holds the CHAT REGION to
  // passing one at all -- the defect was a bare `markRead()` at the call site, and a clamp
  // nobody hands an argument to is the same bug with more code in it.
  testWidgets('the region opening does not mark a folded note read', (tester) async {
    final spine = await Spine.open(
        SpineStore.memory(), const Identity(person: Person.teo, device: DeviceKind.pwa));
    // Two of teo's own rows, read long ago, and then one of noor's that arrived while teo was
    // away. Opening the region must not write a marker over that third row.
    await spine.append('message', {'text': 'are you still in it'}, hostAssign: true);
    await spine.append('read_marker', {'upto_seq': 1}, hostAssign: true);
    await spine.applyFromHost([
      Event(
        id: '01J0AAAAAAAAAAAAAAAAAAAAAB',
        seq: 2,
        author: Person.noor,
        device: DeviceKind.android,
        ts: DateTime.utc(2026, 9, 3, 19, 41).millisecondsSinceEpoch,
        type: 'message',
        payload: const {'text': 'the key is under the pot'},
      )
    ]);
    final t = LocalTransport(role: TransportRole.client, spine: spine, deviceId: 'x');
    final scope = AppScope(
      spine: spine,
      transport: t,
      sync: SyncEngine(spine: spine, transport: t),
      clock: Clock(frozenAt: DateTime.utc(2026, 9, 3, 19, 42)),
    );
    addTearDown(() async {
      scope.dispose();
      await spine.close();
    });
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    expect(scope.thread.readUpto[Person.teo], 1,
        reason: 'the arrival marker stands at row 1, so row 2 arrives folded');

    await tester.pumpWidget(AppScope.provide(
      scope: scope,
      child: const MaterialApp(home: Scaffold(body: ChatRegion())),
    ));
    await tester.pump();
    // Well past the six hundred milliseconds `_scheduleRead` waits.
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump();

    expect(scope.thread.readUpto[Person.teo], 1,
        reason: 'opening the thread told the other person `read` for a note still folded shut');
    expect(
        spine.all.where((e) =>
            e.type == 'read_marker' && (e.payload['upto_seq'] as int? ?? 0) >= 2),
        isEmpty,
        reason: 'no read marker may cover row 2 until its writing has been on the screen');
  });

  test('a ceiling below the marker moves it nowhere, because a receipt never goes backwards',
      () async {
    final spine = await Spine.open(
        SpineStore.memory(), const Identity(person: Person.teo, device: DeviceKind.pwa));
    for (var i = 0; i < 4; i++) {
      await spine.append('message', {'text': 'row $i'}, hostAssign: true);
    }
    final t = LocalTransport(role: TransportRole.client, spine: spine, deviceId: 'x');
    final scope = AppScope(
      spine: spine,
      transport: t,
      sync: SyncEngine(spine: spine, transport: t),
      clock: Clock(frozenAt: DateTime.utc(2026, 9, 3, 19, 40)),
    );
    addTearDown(() async {
      scope.dispose();
      await spine.close();
    });
    await scope.markRead(notPast: 3);
    await Future<void>.delayed(Duration.zero);
    expect(scope.thread.readUpto[Person.teo], 3);
    await scope.markRead(notPast: 1);
    await Future<void>.delayed(Duration.zero);
    expect(scope.thread.readUpto[Person.teo], 3,
        reason: 'a read marker that can go backwards is a second way of lying about it');
  });
}
