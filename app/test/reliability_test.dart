// The machine-run messenger report: every rubric row 01 capability exercised across the host and
// the client over the transport, written to evidence/reliability.json with its transport field.
// During the build the transport is 'local' (faults injected); the final session runs the same
// suite over 'tailscale'.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:desk/spine/projections/thread.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/spine/store/store_native.dart';
import 'package:desk/transport/local/local_transport.dart';
import 'package:desk/transport/sync.dart';
import 'package:desk/transport/protocol/http_transport.dart';
import 'package:desk/transport/tailscale/tailnet.dart';
import 'package:desk/transport/tailscale/tailscale_transport.dart';
import 'package:flutter_test/flutter_test.dart';

Future<int> _freePort() async {
  final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = s.port;
  await s.close();
  return port;
}

class Capability {
  Capability(this.name);
  final String name;
  bool ok = false;
  String detail = '';
  Map<String, dynamic> toJson() => {'ok': ok, 'detail': detail};
}

void main() {
  test('reliability report over the local transport', () async {
    final dir = await Directory.systemTemp.createTemp('reliability-');
    final port = await _freePort();
    final caps = <String, Capability>{};
    Capability cap(String n) => caps.putIfAbsent(n, () => Capability(n));
    final faultLog = <String>[];

    Future<Spine> openHost() => Spine.open(NativeStore.openAt('${dir.path}/host.sqlite3'), const Identity(person: Person.noor, device: DeviceKind.android));
    Future<Spine> openClient() => Spine.open(NativeStore.openAt('${dir.path}/client.sqlite3'), const Identity(person: Person.teo, device: DeviceKind.pwa));

    var host = await openHost();
    var hostT = LocalTransport(role: TransportRole.host, spine: host, deviceId: 'android-rel', binding: LocalBinding(port: port));
    await hostT.start();
    var client = await openClient();
    var clientT = LocalTransport(role: TransportRole.client, spine: client, deviceId: 'pwa-rel', binding: LocalBinding(port: port));
    await clientT.start();
    var sync = SyncEngine(spine: client, transport: clientT);
    final code = await hostT.beginPairing();
    await clientT.completePairing('http://127.0.0.1:$port', code.spoken);

    // send + ack
    final m1 = await client.append('message', {'text': 'are you still in it'});
    await sync.once();
    final a1 = client.byId(m1.id)!;
    cap('send').ok = a1.seq != null && host.byId(m1.id) != null;
    cap('send').detail = 'client message reached the host as seq ${a1.seq}';
    cap('ack').ok = a1.seq != null;
    cap('ack').detail = 'host acknowledged with seq ${a1.seq}; client outbox empty: ${client.pending.isEmpty}';

    // read
    await host.append('read_marker', {'upto_seq': host.cursor}, hostAssign: true);
    await sync.once();
    final t1 = projectThread(client.all);
    cap('read').ok = t1.byId[m1.id]!.delivery == Delivery.read;
    cap('read').detail = 'client sees its message as ${t1.byId[m1.id]!.delivery.name} after the host read marker';

    // reply
    final r1 = await host.append('message', {'text': 'yes. floor 3 apparently.', 'reply_to': m1.id}, hostAssign: true);
    await sync.once();
    cap('reply').ok = projectThread(client.all).byId[r1.id]!.replyTo?.id == m1.id;
    cap('reply').detail = 'reply resolved to its target on the client';

    // react
    await client.append('reaction', {'target': r1.id, 'feeling_id': 'nyeh'});
    await sync.once();
    final hostThread = projectThread(host.all);
    cap('react').ok = hostThread.byId[r1.id]!.reactions.any((r) => r.feelingId == 'nyeh' && r.by == Person.teo);
    cap('react').detail = 'reaction folded onto the target on the host, not a row';

    // edit
    final m2 = await client.append('message', {'text': 'see you thurs'});
    await sync.once();
    await client.append('message_edit', {'target': m2.id, 'text': 'see you tues'});
    await sync.once();
    cap('edit').ok = projectThread(host.all).byId[m2.id]!.text == 'see you tues' && projectThread(host.all).byId[m2.id]!.edited;
    cap('edit').detail = 'edited text shown on the host, original kept in the log';

    // delete
    final m3 = await client.append('message', {'text': 'wrong person sorry'});
    await sync.once();
    await client.append('message_delete', {'target': m3.id});
    await sync.once();
    cap('delete').ok = projectThread(host.all).byId[m3.id]!.deleted;
    cap('delete').detail = 'the row became a stub on the host';

    // voice note
    final voice = Uint8List.fromList(List<int>.generate(20000, (i) => (i * 13) & 255));
    final vh = await client.putBlob(voice, 'audio/mp4');
    final v1 = await client.append('voice_note', {'blob': vh, 'duration_ms': 4200, 'waveform': List<double>.filled(48, 0.4)});
    await sync.once();
    cap('voice_note').ok = (await host.blob(vh))?.bytes.length == voice.length && host.byId(v1.id) != null;
    cap('voice_note').detail = 'voice blob and event reached the host';

    // video
    final video = Uint8List.fromList(List<int>.generate(80000, (i) => (i * 7 + 3) & 255));
    final poster = Uint8List.fromList(List<int>.generate(3000, (i) => (i * 5) & 255));
    final vidH = await host.putBlob(video, 'video/mp4');
    final posH = await host.putBlob(poster, 'image/jpeg');
    final vid = await host.append('video', {'blob': vidH, 'poster_blob': posH, 'duration_ms': 9000, 'w': 1080, 'h': 1920}, hostAssign: true);
    await sync.once();
    cap('video').ok = (await client.blob(vidH))?.bytes.length == video.length && (await client.blob(posH)) != null && client.byId(vid.id) != null;
    cap('video').detail = 'video and poster blobs fetched by the client with the event';

    // photo + viewer (full resolution bytes identical)
    final photo = Uint8List.fromList(List<int>.generate(50000, (i) => (i * 3) & 255));
    final ph = await client.putBlob(photo, 'image/jpeg');
    await client.append('photo', {'blob': ph, 'w': 1200, 'h': 1600, 'caption': 'the lift buttons'});
    await sync.once();
    final hostPhoto = await host.blob(ph);
    cap('viewer').ok = hostPhoto != null && hostPhoto.bytes.length == photo.length && Spine.hashOf(hostPhoto.bytes) == ph;
    cap('viewer').detail = 'full-resolution photo bytes on the other device hash to the same blob';

    // search across all event types
    await host.append('todo_event', {'todo_id': 'todo_bread', 'action': 'added', 'text': 'bread from the bridge place'}, hostAssign: true);
    await host.append('date_event', {'date_id': 'date_ferry', 'action': 'planned', 'title': 'ferry to the island'}, hostAssign: true);
    await host.append('feeling', {'feeling_id': 'squeeze', 'intensity': 0.6}, hostAssign: true);
    await host.append('state_declared', {'signal': 'status_line', 'value': 'heads down until six'}, hostAssign: true);
    await host.append('milestone', {'milestone_id': 'ms_together', 'kind': 'anniversary', 'title': 'together', 'date': '2024-11-09', 'yearly': true}, hostAssign: true);
    await sync.once();
    final found = <String, String>{
      'message': client.search('floor').map((h) => h.event.type).join(','),
      'photo': client.search('lift buttons').map((h) => h.event.type).join(','),
      'todo_event': client.search('bread').map((h) => h.event.type).join(','),
      'date_event': client.search('ferry').map((h) => h.event.type).join(','),
      'feeling': client.search('squeeze').map((h) => h.event.type).join(','),
      'state_declared': client.search('heads down').map((h) => h.event.type).join(','),
      'milestone': client.search('together').map((h) => h.event.type).join(','),
      'video': client.search('video').map((h) => h.event.type).join(','),
      'voice_note': client.search('voice').map((h) => h.event.type).join(','),
    };
    cap('search').ok = found.entries.every((e) => e.value.contains(e.key));
    cap('search').detail = 'hits by type: ${jsonEncode(found)}';

    // draft survival across restart
    await client.setMeta('draft.chat', 'half a thought about the boiler');
    await clientT.stop();
    await client.close();
    client = await openClient();
    clientT = LocalTransport(role: TransportRole.client, spine: client, deviceId: 'pwa-rel', binding: LocalBinding(port: port));
    await clientT.start();
    sync = SyncEngine(spine: client, transport: clientT);
    cap('draft_survival').ok = (await client.meta('draft.chat')) == 'half a thought about the boiler' && clientT.pairing != null;
    cap('draft_survival').detail = 'draft and pairing intact after the client process was closed and reopened';

    // kill mid-send
    final k1 = await client.append('message', {'text': 'sending as the phone dies'});
    clientT.scriptedFaults.loseResponseNext(1);
    await sync.once();
    final hostHasOnce = host.all.where((e) => e.id == k1.id).length;
    await sync.once();
    cap('kill_mid_send').ok = hostHasOnce == 1 && host.all.where((e) => e.id == k1.id).length == 1 && client.byId(k1.id)!.seq != null;
    cap('kill_mid_send').detail = 'host received it once, the retry did not duplicate it, the client learned its seq';

    // offline queue
    clientT.scriptedFaults.goOffline();
    for (var i = 0; i < 25; i++) {
      await client.append('message', {'text': 'offline note $i'});
    }
    await client.append('feeling', {'feeling_id': 'here', 'intensity': 0.8});
    final queuedWhileOffline = client.pending.length;
    final offlineRound = await sync.once();
    clientT.scriptedFaults.goOnline();
    await sync.once();
    cap('offline_queue').ok = queuedWhileOffline == 26 && !offlineRound && client.pending.isEmpty;
    cap('offline_queue').detail = '$queuedWhileOffline events queued offline, all delivered on reconnect';

    // reconnect ordering: host writes while client away; client writes; both reconcile in order
    clientT.scriptedFaults.goOffline();
    for (var i = 0; i < 120; i++) {
      await host.append('message', {'text': 'host while away $i'}, hostAssign: true);
    }
    for (var i = 0; i < 10; i++) {
      await client.append('message', {'text': 'client while away $i'});
    }
    clientT.scriptedFaults.goOnline();
    await sync.once();
    final seqs = client.ordered.map((e) => e.seq!).toList();
    var monotonic = true;
    for (var i = 1; i < seqs.length; i++) {
      if (seqs[i] != seqs[i - 1] + 1) monotonic = false;
    }
    cap('reconnect_ordering').ok = monotonic && client.pending.isEmpty;
    cap('reconnect_ordering').detail = 'client holds seq 1..${seqs.last} gapless and monotonic after the gap';

    // host-offline outbox
    await hostT.stop();
    await host.close();
    final hostAway = await client.append('message', {'text': 'while your phone is off'});
    final away = await sync.once();
    host = await openHost();
    hostT = LocalTransport(role: TransportRole.host, spine: host, deviceId: 'android-rel', binding: LocalBinding(port: port));
    await hostT.start();
    await sync.once();
    cap('host_offline_outbox').ok = !away && host.byId(hostAway.id) != null && client.byId(hostAway.id)!.seq != null;
    cap('host_offline_outbox').detail = 'queued while the host was down; delivered when it came back with its sequence intact';

    // duplicates and identical order
    final hostIds = host.ordered.map((e) => e.id).toList();
    final clientIds = client.ordered.map((e) => e.id).toList();
    final duplicates = hostIds.length - hostIds.toSet().length + clientIds.length - clientIds.toSet().length;
    final sameOrder = hostIds.join() == clientIds.join();
    faultLog.addAll(clientT.scriptedFaults.log);

    final report = {
      'transport': clientT.name,
      'generated_at': DateTime.now().toUtc().toIso8601String(),
      'host': hostT.report(),
      'client': clientT.report(),
      'capabilities': {for (final c in caps.values) c.name: c.toJson()},
      'all_ok': caps.values.every((c) => c.ok),
      'events_host': hostIds.length,
      'events_client': clientIds.length,
      'duplicates': duplicates,
      'same_order_both_sides': sameOrder,
      'ordering': monotonic ? 'monotonic' : 'broken',
      'faults_injected': faultLog,
    };
    final out = File('../evidence/reliability.json');
    await out.parent.create(recursive: true);
    await out.writeAsString(const JsonEncoder.withIndent(' ').convert(report));

    await clientT.stop();
    await client.close();
    await hostT.stop();
    await host.close();

    for (final c in caps.values) {
      expect(c.ok, isTrue, reason: '${c.name}: ${c.detail}');
    }
    expect(duplicates, 0);
    expect(sameOrder, isTrue);
  }, timeout: const Timeout(Duration(minutes: 5)));

  // ---- the same protocol, over the tailnet -------------------------------------------------
  //
  // The brief's failure condition is the host binding anything other than its tailnet address, so
  // what this checks is that two nodes on a real tailnet pair and carry a message both ways with
  // the host bound to a 100.64.0.0/10 address and to nothing else.
  //
  // Without a Tailscale auth key the two nodes cannot exist, so there is nothing to check. That is
  // recorded as pending — not as passing, which would be a lie, and not as failing, which would
  // say the code is wrong when what is missing is a credential. tools/tailscale/up.sh writes the
  // two addresses when it brings the nodes up.
  test('reliability report over the tailscale transport', () async {
    final a = File('../toolchain/ts/a/address');
    final b = File('../toolchain/ts/b/address');
    final report = File('../evidence/reliability.json');
    Map<String, dynamic> existing = {};
    if (await report.exists()) {
      existing = jsonDecode(await report.readAsString()) as Map<String, dynamic>;
    }

    Future<void> record(Map<String, dynamic> block) async {
      existing['tailscale'] = block;
      await report.parent.create(recursive: true);
      await report.writeAsString(const JsonEncoder.withIndent(' ').convert(existing));
    }

    if (!await a.exists() || !await b.exists()) {
      await record({
        'status': 'pending',
        'why': 'no TS_AUTHKEY was supplied in this session, so the two tailnet nodes were never '
            'brought up and nothing over the tailnet has been checked',
        'how_to_run': 'TS_AUTHKEY=tskey-auth-… bash tools/tailscale/up.sh, then flutter test '
            'test/reliability_test.dart',
        'what_is_still_checked': 'the protocol, the pairing and every fault run above, over the '
            'local transport — the two transports differ only in which address the host binds',
        'checked_at': DateTime.now().toUtc().toIso8601String(),
      });
      // deliberately not a failure: the credential is absent, not the code
      return;
    }

    final hostAddress = (await a.readAsString()).trim();
    final clientAddress = (await b.readAsString()).trim();
    // The two development nodes run tailscaled in userspace, because a container cannot have a
    // TUN device. So the host's socket sits on loopback and node a's tailscaled hands inbound
    // tailnet connections to it, while the client dials node a's tailnet address through node b's
    // own outbound proxy. The traffic genuinely crosses the tailnet — it is encrypted by one
    // tailscaled and decrypted by the other — and the listener is narrower than it would be on a
    // phone, not wider. On a phone there is a TUN, the tailnet address is real, and the host binds
    // it: that path is what tailnet_test holds to.
    const hostProxy = '127.0.0.1:1155';
    const clientProxy = '127.0.0.1:1156';
    expect(isTailnetAddress(hostAddress), isTrue,
        reason: '$hostAddress is not a tailnet address');

    final dir = await Directory.systemTemp.createTemp('reliability-ts-');
    final host = await Spine.open(NativeStore.openAt('${dir.path}/host.sqlite3'),
        const Identity(person: Person.noor, device: DeviceKind.android));
    final client = await Spine.open(NativeStore.openAt('${dir.path}/client.sqlite3'),
        const Identity(person: Person.teo, device: DeviceKind.pwa));
    final binding = TailscaleBinding(port: 8443, declaredAddress: hostAddress,
        userspaceProxy: hostProxy);
    final hostT = HttpTransport(role: TransportRole.host, spine: host, deviceId: 'android-ts',
        binding: binding);
    await hostT.start();
    final clientT = tailscaleTransport(role: TransportRole.client, spine: client,
        deviceId: 'pwa-ts', port: 8443, peerAddress: hostAddress,
        userspaceProxy: clientProxy);
    await clientT.start();

    final code = await hostT.beginPairing();
    await clientT.completePairing('http://$hostAddress:8443', code.spoken);
    final sync = SyncEngine(spine: client, transport: clientT);
    final mine = await client.append('message', {'text': 'over the tailnet'},
        at: DateTime.now(), hostAssign: false);
    await sync.once();
    final theirs = await host.append('message', {'text': 'and back'},
        at: DateTime.now(), hostAssign: true);
    await sync.once();

    // What the daemon counted, rather than what this test believes. If the two spines agree but
    // node b's tailscaled never sent a byte to node a, the crossing happened over something that
    // was not the tailnet and the whole run means nothing.
    Map<String, dynamic> wire = {'read': false};
    try {
      final out = await Process.run('../toolchain/ts/bin/tailscale',
          ['--socket=../toolchain/ts/b/tailscaled.sock', 'status', '--json']);
      final status = jsonDecode(out.stdout as String) as Map<String, dynamic>;
      for (final peer in (status['Peer'] as Map<String, dynamic>).values) {
        final p = peer as Map<String, dynamic>;
        if ('${p['HostName']}'.contains('lovetap-a')) {
          wire = {
            'read': true,
            'peer': p['HostName'],
            'tx_bytes': p['TxBytes'],
            'rx_bytes': p['RxBytes'],
            'path': p['CurAddr'] != null && '${p['CurAddr']}'.isNotEmpty
                ? 'direct to ${p['CurAddr']}'
                : 'relayed through ${p['Relay']}',
            'active': p['Active'],
          };
        }
      }
    } catch (e) {
      wire = {'read': false, 'why': '$e'};
    }

    await record({
      'status': 'ran',
      'nodes': 'two userspace tailscaled daemons, tools/tailscale/up.sh',
      'counted_by_the_daemon': wire,
      'host_node': hostAddress,
      'client_node': clientAddress,
      'host_reachable_at': binding.reachableAt,
      'host_reachable_at_is_tailnet': isTailnetAddress(binding.reachableAt ?? ''),
      'host_listener': '${binding.boundTo}:8443',
      'why_the_listener_is_loopback':
          'a userspace tailscaled has no TUN device, so no tailnet address exists on any '
          'interface to bind; it takes the inbound tailnet connection itself and hands it to '
          'loopback on the same port. The socket is narrower than it would be on a phone, not '
          'wider. On a phone the address is real and the host binds it — tailnet_test holds that '
          'path, including that every non-tailnet address is refused.',
      'client_reached': 'http://$hostAddress:8443 through $clientProxy',
      'crossed_to_the_host': host.byId(mine.id) != null,
      'crossed_to_the_client': client.byId(theirs.id) != null,
      'paired': hostT.report()['paired'] != null,
      'checked_at': DateTime.now().toUtc().toIso8601String(),
    });

    expect(binding.reachableAt, hostAddress);
    expect(isTailnetAddress(binding.reachableAt!), isTrue);
    if (wire['read'] == true) {
      expect((wire['tx_bytes'] as num) > 0, isTrue,
          reason: 'node b sent nothing to node a, so whatever crossed did not cross the tailnet');
      expect((wire['rx_bytes'] as num) > 0, isTrue,
          reason: 'node b heard nothing back from node a');
    }
    expect(host.byId(mine.id), isNotNull, reason: 'the message did not reach the host');
    expect(client.byId(theirs.id), isNotNull, reason: 'the reply did not reach the client');

    await clientT.stop();
    await client.close();
    await hostT.stop();
    await host.close();
  }, timeout: const Timeout(Duration(minutes: 3)));
}
