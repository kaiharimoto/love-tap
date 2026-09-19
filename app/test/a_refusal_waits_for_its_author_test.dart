// A refusal is the one delivery state a person has to be able to act on, and it was a dead end
// in three separate places at once.
//
//   * The host dropped what it would not take without saying so. `_push` answered only with the
//     events it had kept; anything filtered by the author check, or rejected by the spec
//     validator, simply fell out of the reply. `Accepted.refused` has been on the wire type since
//     the protocol was written and nothing ever put a value in it.
//   * The sync engine drained `spine.pending`, and a refused event is still pending. So it was
//     re-offered to the host on every round for the life of the pairing, behind the person's
//     back, having already been told no.
//   * The row said `it would not go` and nothing else. Not why, and not what to do about it.
//
// The first two are here; the third is in the widget test beside this one. Re-break either half
// and this fails: put `spine.pending` back in `_drainOutbox` and `a refused event is not offered
// again on its own` finds it on the host; drop the refusal out of the server's reply and
// `the host says which ones it would not take, and why` gets an empty verdict list.
import 'dart:io';

import 'package:desk/spine/projections/thread.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/transport/local/local_transport.dart';
import 'package:desk/transport/sync.dart';
import 'package:desk/transport/transport.dart';
import 'package:desk/voice/strings.dart';
import 'package:flutter_test/flutter_test.dart';

Future<int> _freePort() async {
  final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = s.port;
  await s.close();
  return port;
}

void main() {
  late Spine host;
  late Spine client;
  late LocalTransport hostT;
  late LocalTransport clientT;
  late SyncEngine sync;

  /// Two phones on one loopback port, paired, with [clientStarts] already in the client's store
  /// before its spine is opened — the only way to put an event in the outbox that `append` would
  /// not mint, which is what a phone running a newer registry is from this one's point of view.
  Future<void> connect({List<Event> clientStarts = const []}) async {
    final port = await _freePort();
    host = await Spine.open(
        SpineStore.memory(), const Identity(person: Person.noor, device: DeviceKind.android));
    hostT = LocalTransport(
        role: TransportRole.host, spine: host, deviceId: 'android-r', binding: LocalBinding(port: port));
    await hostT.start();
    final clientStore = SpineStore.memory();
    if (clientStarts.isNotEmpty) await clientStore.upsertAll(clientStarts);
    client = await Spine.open(
        clientStore, const Identity(person: Person.teo, device: DeviceKind.pwa));
    clientT = LocalTransport(
        role: TransportRole.client, spine: client, deviceId: 'pwa-r', binding: LocalBinding(port: port));
    await clientT.start();
    sync = SyncEngine(spine: client, transport: clientT);
    final code = await hostT.beginPairing();
    await clientT.completePairing('http://127.0.0.1:$port', code.spoken);
    addTearDown(() async {
      await clientT.stop();
      await client.close();
      await hostT.stop();
      await host.close();
    });
  }

  test('a refused event is not offered again on its own, and goes when its author asks', () async {
    await connect();
    final m = await client.append('message', {'text': 'sending you the roster'});
    // The host said no. This is the same call the sync engine makes when a refusal comes back
    // over the wire, and the same one the capture's staged scene makes.
    client.markRefused(m.id, S.refusedUnreadable);

    expect(client.pending.map((e) => e.id), contains(m.id),
        reason: 'a refused event stays where its author can see it');
    expect(client.outbox, isEmpty, reason: 'and out of what the engine may push');

    await sync.once();
    expect(host.byId(m.id), isNull,
        reason: 'the engine re-offered an event the host had already refused');
    expect(client.byId(m.id)!.seq, isNull);

    // The person presses it.
    expect(client.retry(m.id), isTrue);
    expect(client.refused, isEmpty);
    expect(client.outbox.map((e) => e.id), contains(m.id));

    await sync.once();
    expect(host.byId(m.id), isNotNull, reason: 'the retry did not reach the host');
    expect(client.byId(m.id)!.seq, isNotNull, reason: 'the client never learned its seq');
    expect(client.pending, isEmpty);
  });

  test('retrying something that was never refused changes nothing', () async {
    await connect();
    final m = await client.append('message', {'text': 'no one refused this'});
    expect(client.retry(m.id), isFalse);
    expect(client.retry('not an id at all'), isFalse);
    expect(client.outbox.map((e) => e.id), contains(m.id));
  });

  test('the host says which ones it would not take, and why', () async {
    await connect();
    final ulids = UlidFactory();
    final now = DateTime.now().toUtc();

    // Written as the other person: this pairing is teo's, and the host may not store noor's
    // words on teo's word. It used to be filtered out of `allowed` and never mentioned again.
    final wrongName = Event(
      id: ulids.next(now),
      seq: null,
      author: Person.noor,
      device: DeviceKind.pwa,
      ts: now.millisecondsSinceEpoch,
      type: 'message',
      payload: const {'text': 'not mine to write'},
    );
    // A message with no text in it: what a phone running code this one does not have sends. The
    // spec validator rejects it, and `accept` used to drop it with a bare `continue`.
    final unreadable = Event(
      id: ulids.next(now),
      seq: null,
      author: Person.teo,
      device: DeviceKind.pwa,
      ts: now.millisecondsSinceEpoch + 1,
      type: 'message',
      payload: const {'nothing_it_knows': 1},
    );
    final fine = Event(
      id: ulids.next(now),
      seq: null,
      author: Person.teo,
      device: DeviceKind.pwa,
      ts: now.millisecondsSinceEpoch + 2,
      type: 'message',
      payload: const {'text': 'and this one is ordinary'},
    );

    final verdicts = await clientT.push([wrongName, unreadable, fine]);
    final byId = {for (final a in verdicts) a.id: a};
    expect(byId.keys.toSet(), {wrongName.id, unreadable.id, fine.id},
        reason: 'every event pushed gets a verdict, or its writer is told nothing at all');

    expect(byId[wrongName.id]!.accepted, isFalse);
    expect(byId[wrongName.id]!.refused, S.refusedWrongName);
    expect(host.byId(wrongName.id), isNull);

    expect(byId[unreadable.id]!.accepted, isFalse);
    expect(byId[unreadable.id]!.refused, S.refusedUnreadable);
    expect(host.byId(unreadable.id), isNull);

    expect(byId[fine.id]!.accepted, isTrue);
    expect(byId[fine.id]!.seq, greaterThan(0));
    expect(host.byId(fine.id), isNotNull);
  });

  test('a refusal that comes back over the wire marks the row and stops the engine', () async {
    // End to end, through the sync engine rather than by hand: the client mints something the
    // host's validator will not have. `append` validates on the way in, so the outbox is fed the
    // way a phone with a newer event registry would feed it.
    final bad = Event(
      id: UlidFactory().next(DateTime.now().toUtc()),
      seq: null,
      author: Person.teo,
      device: DeviceKind.pwa,
      ts: DateTime.now().toUtc().millisecondsSinceEpoch,
      type: 'message',
      payload: const {'from_a_later_version': true},
    );
    await connect(clientStarts: [bad]);
    expect(client.outbox.map((e) => e.id), contains(bad.id));

    await sync.once();
    expect(sync.refused, 1);
    expect(client.refused[bad.id], S.refusedUnreadable);
    expect(client.outbox, isEmpty, reason: 'the engine keeps offering a refused event');

    final t = projectThread(client.all, me: Person.teo, refused: client.refused);
    final row = t.byId[bad.id]!;
    expect(row.delivery, Delivery.refused);
    expect(row.refusedWhy, S.refusedUnreadable,
        reason: 'the row knows it would not go and not why, which is the useless half');

    // And a second round does not offer it again either.
    await sync.once();
    expect(sync.refused, 1, reason: 'the host was asked twice about something it had refused');
  });
}
