// STEP 01: the wire works. A payload travels from one device to the other and survives an app
// restart, going offline mid-send, a killed send, a long gap, and the host being away.
import 'dart:io';
import 'dart:typed_data';

import 'package:desk/spine/spine.dart';
import 'package:desk/spine/store/store_native.dart';
import 'package:desk/transport/local/local_transport.dart';
import 'package:desk/transport/sync.dart';
import 'package:flutter_test/flutter_test.dart';

Future<int> _freePort() async {
  final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = s.port;
  await s.close();
  return port;
}

class Rig {
  Rig(this.dir, this.port);
  final Directory dir;
  final int port;
  late Spine host;
  late Spine client;
  late LocalTransport hostT;
  late LocalTransport clientT;
  late SyncEngine sync;

  static Future<Rig> up({Directory? dir, int? port}) async {
    final r = Rig(dir ?? await Directory.systemTemp.createTemp('lovetap-'), port ?? await _freePort());
    await r.openHost();
    await r.openClient();
    return r;
  }

  Future<void> openHost() async {
    host = await Spine.open(NativeStore.openAt('${dir.path}/host.sqlite3'),
        const Identity(person: Person.noor, device: DeviceKind.android));
    hostT = LocalTransport(role: TransportRole.host, spine: host, deviceId: 'android-test',
        binding: LocalBinding(port: port));
    await hostT.start();
  }

  Future<void> openClient() async {
    client = await Spine.open(NativeStore.openAt('${dir.path}/client.sqlite3'),
        const Identity(person: Person.teo, device: DeviceKind.pwa));
    clientT = LocalTransport(role: TransportRole.client, spine: client, deviceId: 'pwa-test',
        binding: LocalBinding(port: port));
    await clientT.start();
    sync = SyncEngine(spine: client, transport: clientT);
  }

  Future<void> pair() async {
    final code = await hostT.beginPairing();
    await clientT.completePairing('http://127.0.0.1:$port', code.spoken);
  }

  Future<void> closeHost() async {
    await hostT.stop();
    await host.close();
  }

  Future<void> closeClient() async {
    await clientT.stop();
    await client.close();
  }
}

void main() {
  test('pairing: unauthenticated requests are refused, wrong words are refused, right words pair', () async {
    final r = await Rig.up();
    // not paired: pull must fail with 401
    expect(() => r.clientT.pull(0), throwsA(isA<TransportException>()));
    final code = await r.hostT.beginPairing();
    expect(code.words.length, 6);
    await expectLater(r.clientT.completePairing('http://127.0.0.1:${r.port}', 'wrong words entirely here now ok'),
        throwsA(isA<TransportException>()));
    // a fresh nonce is needed after a failed attempt; the host still has the window open
    final p = await r.clientT.completePairing('http://127.0.0.1:${r.port}', code.spoken);
    expect(p.hostPerson, Person.noor);
    expect(r.hostT.pairing?.clientId, 'pwa-test');
    final pulled = await r.clientT.pull(0);
    expect(pulled.events, isEmpty);
    await r.closeClient();
    await r.closeHost();
  });

  test('a message crosses, in both directions, once', () async {
    final r = await Rig.up();
    await r.pair();
    await r.client.append('message', {'text': 'are you still in it'});
    await r.host.append('message', {'text': 'yes. floor 3 apparently.'}, hostAssign: true);
    expect(await r.sync.once(), isTrue);
    expect(r.host.ordered.map((e) => e.payload['text']), ['yes. floor 3 apparently.', 'are you still in it']);
    expect(r.client.ordered.map((e) => e.seq), [1, 2]);
    expect(r.client.pending, isEmpty);
    // a second round changes nothing
    await r.sync.once();
    expect(r.host.length, 2);
    expect(r.client.length, 2);
    expect(r.hostT.report()['transport'], 'local');
    await r.closeClient();
    await r.closeHost();
  });

  test('outbox survives an app restart', () async {
    final r = await Rig.up();
    await r.pair();
    r.clientT.scriptedFaults.goOffline();
    await r.client.append('message', {'text': 'written in the lift'});
    await r.client.append('feeling', {'feeling_id': 'here', 'intensity': 0.7});
    expect(await r.sync.once(), isFalse);
    expect(r.client.pending.length, 2);
    // "restart": close the client entirely and reopen from disk
    await r.closeClient();
    await r.openClient();
    expect(r.client.pending.length, 2);
    expect(r.clientT.pairing, isNotNull, reason: 'pairing survives restart');
    expect(await r.sync.once(), isTrue);
    expect(r.client.pending, isEmpty);
    expect(r.host.ordered.map((e) => e.type), ['message', 'feeling']);
    await r.closeClient();
    await r.closeHost();
  });

  test('killed mid-send: the host has it, the client retries, nothing is duplicated', () async {
    final r = await Rig.up();
    await r.pair();
    await r.client.append('message', {'text': 'sending this as the phone dies'});
    r.clientT.scriptedFaults.loseResponseNext(1);
    expect(await r.sync.once(), isFalse);
    expect(r.host.length, 1, reason: 'the push reached the host');
    expect(r.client.pending.length, 1, reason: 'the client never saw the answer');
    expect(await r.sync.once(), isTrue);
    expect(r.host.length, 1, reason: 'idempotent by id');
    expect(r.client.pending, isEmpty);
    expect(r.client.ordered.single.seq, 1);
    await r.closeClient();
    await r.closeHost();
  });

  test('offline mid-send, then reconnect after a long gap: ordering is monotonic, nothing is lost', () async {
    final r = await Rig.up();
    await r.pair();
    await r.client.append('message', {'text': 'first'});
    await r.sync.once();
    r.clientT.scriptedFaults.goOffline();
    for (var i = 0; i < 40; i++) {
      await r.client.append('message', {'text': 'offline $i'});
    }
    for (var i = 0; i < 300; i++) {
      await r.host.append('message', {'text': 'host while away $i'}, hostAssign: true);
    }
    expect(await r.sync.once(), isFalse);
    r.clientT.scriptedFaults.goOnline();
    expect(await r.sync.once(), isTrue);
    expect(r.client.pending, isEmpty);
    expect(r.client.length, 341);
    expect(r.host.length, 341);
    final seqs = r.client.ordered.map((e) => e.seq!).toList();
    for (var i = 1; i < seqs.length; i++) {
      expect(seqs[i], seqs[i - 1] + 1, reason: 'monotonic, gapless');
    }
    expect(r.client.ordered.map((e) => e.id).toSet().length, 341, reason: 'no duplicates');
    // the client's offline messages arrive after everything the host wrote while it was away
    final offlineSeqs = r.client.ordered.where((e) => (e.payload['text'] as String).startsWith('offline')).map((e) => e.seq!);
    expect(offlineSeqs.first, 302);
    await r.closeClient();
    await r.closeHost();
  });

  test('host offline: the outbox waits; a restarted host continues its sequence', () async {
    final r = await Rig.up();
    await r.pair();
    await r.host.append('message', {'text': 'before'}, hostAssign: true);
    await r.sync.once();
    await r.closeHost();
    await r.client.append('message', {'text': 'while the host is away'});
    expect(await r.sync.once(), isFalse);
    expect(r.client.pending.length, 1);
    await r.openHost();
    expect(r.host.cursor, 1, reason: 'the host reloaded its log');
    expect(await r.sync.once(), isTrue);
    expect(r.client.pending, isEmpty);
    expect(r.host.ordered.last.seq, 2);
    await r.closeClient();
    await r.closeHost();
  });

  test('blobs travel with their events, in both directions', () async {
    final r = await Rig.up();
    await r.pair();
    final photo = Uint8List.fromList(List<int>.generate(5000, (i) => (i * 7) & 255));
    final h = await r.client.putBlob(photo, 'image/png');
    await r.client.append('photo', {'blob': h, 'w': 10, 'h': 20});
    final hostBytes = Uint8List.fromList(List<int>.generate(3000, (i) => (i * 3) & 255));
    final hh = await r.host.putBlob(hostBytes, 'audio/ogg');
    await r.host.append('voice_note', {'blob': hh, 'duration_ms': 1200, 'waveform': [0.1, 0.5]}, hostAssign: true);
    expect(await r.sync.once(), isTrue);
    expect((await r.host.blob(h))?.bytes, photo);
    expect((await r.client.blob(hh))?.bytes, hostBytes);
    expect(await r.client.missingBlobs(), isEmpty);
    await r.closeClient();
    await r.closeHost();
  });

  test('ephemeral frames are delivered and never stored', () async {
    final r = await Rig.up();
    await r.pair();
    final gotAtHost = <Ephemeral>[];
    r.hostT.ephemeral.listen(gotAtHost.add);
    await r.clientT.sendEphemeral(Ephemeral(kind: 'typing', from: Person.teo, at: 1, data: const {'on': true}));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(gotAtHost.single.kind, 'typing');
    await r.hostT.sendEphemeral(Ephemeral(kind: 'presence', from: Person.noor, at: 2));
    final pulled = await r.clientT.pull(r.client.cursor);
    expect(pulled.ephemeral.single.kind, 'presence');
    expect(r.host.length, 0);
    expect(r.client.length, 0);
    await r.closeClient();
    await r.closeHost();
  });

  test('the local transport names itself in every report', () async {
    final r = await Rig.up();
    await r.pair();
    expect(r.hostT.report()['transport'], 'local');
    expect(r.clientT.report()['transport'], 'local');
    expect(r.sync.report()['transport'], 'local');
    await r.closeClient();
    await r.closeHost();
  });
}
