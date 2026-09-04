// evidence/coldstart.json — the whole premise, from nothing, over the tailnet.
//
// Two nodes with two distinct node keys and two distinct addresses in 100.64.0.0/10; two empty
// spines; the six words spoken between them; then one message and one feeling in each direction.
// The file records what both daemons say about themselves, the four event ids, when each arrived
// on the far side, and the ordered id list from both spines — because the claim is not only that
// four events crossed but that the two devices agree about their order, and the only way to show
// that is to print both lists and let anyone compare them.
//
// This is deliberately not the reliability suite. That one exercises every capability against
// injected faults; this one is the cold start: nothing on either side, one tailnet, four events.
import 'dart:convert';
import 'dart:io';

import 'package:desk/feelings/builtins.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/spine/store/store_native.dart';
import 'package:desk/transport/protocol/http_transport.dart';
import 'package:desk/transport/sync.dart';
import 'package:desk/transport/transport.dart';
import 'package:desk/transport/tailscale/tailnet.dart';
import 'package:desk/transport/tailscale/tailscale_transport.dart';
import 'package:flutter_test/flutter_test.dart';

const _tsBin = '../toolchain/ts/bin/tailscale';
const _out = '../evidence/coldstart.json';

Future<Map<String, dynamic>?> _status(String node) async {
  try {
    final r = await Process.run(_tsBin, ['--socket=../toolchain/ts/$node/tailscaled.sock',
      'status', '--json']);
    if (r.exitCode != 0) return null;
    return jsonDecode(r.stdout as String) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

/// What a node says about itself: its key, its addresses, its name. Never the auth key — that is
/// not in tailscaled's status output and must never be in a committed file.
Map<String, dynamic> _self(Map<String, dynamic> status) {
  final s = (status['Self'] as Map<String, dynamic>?) ?? const {};
  return {
    'hostname': s['HostName'],
    'node_key': s['PublicKey'],
    'addresses': s['TailscaleIPs'],
    'os': s['OS'],
    'online': s['Online'],
  };
}

void main() {
  test('cold start over the tailnet: four events, both directions, both spines agreeing', () async {
    final aFile = File('../toolchain/ts/a/address');
    final bFile = File('../toolchain/ts/b/address');
    if (!await aFile.exists() || !await bFile.exists()) {
      await File(_out).writeAsString(const JsonEncoder.withIndent(' ').convert({
        'transport': 'tailscale',
        'status': 'pending',
        'why': 'the two tailnet nodes were not up in this session, so there was nothing to start '
            'cold against. tools/tailscale/up.sh brings them up.',
      }));
      return;
    }

    final hostAddress = (await aFile.readAsString()).trim();
    final clientAddress = (await bFile.readAsString()).trim();
    final aStatus = await _status('a');
    final bStatus = await _status('b');
    expect(aStatus, isNotNull, reason: 'node a would not report its status');
    expect(bStatus, isNotNull, reason: 'node b would not report its status');

    // two nodes, not one node twice
    final aSelf = _self(aStatus!);
    final bSelf = _self(bStatus!);
    expect(aSelf['node_key'], isNot(equals(bSelf['node_key'])));
    expect(isTailnetAddress(hostAddress), isTrue);
    expect(isTailnetAddress(clientAddress), isTrue);
    expect(hostAddress, isNot(equals(clientAddress)));

    // nothing on either side to begin with
    final dir = await Directory.systemTemp.createTemp('coldstart-');
    final host = await Spine.open(NativeStore.openAt('${dir.path}/host.sqlite3'),
        const Identity(person: Person.noor, device: DeviceKind.android));
    final client = await Spine.open(NativeStore.openAt('${dir.path}/client.sqlite3'),
        const Identity(person: Person.teo, device: DeviceKind.pwa));
    expect(host.length, 0);
    expect(client.length, 0);

    final binding = TailscaleBinding(port: 8443, declaredAddress: hostAddress,
        userspaceProxy: '127.0.0.1:1155');
    final hostT = HttpTransport(role: TransportRole.host, spine: host, deviceId: 'android-cold',
        binding: binding);
    await hostT.start();
    final clientT = tailscaleTransport(role: TransportRole.client, spine: client,
        deviceId: 'pwa-cold', port: 8443, peerAddress: hostAddress,
        userspaceProxy: '127.0.0.1:1156');
    await clientT.start();

    // the six words, said out loud in the same room
    final code = await hostT.beginPairing();
    await clientT.completePairing('http://$hostAddress:8443', code.spoken);
    final sync = SyncEngine(spine: client, transport: clientT);

    final feeling = kBuiltInFeelings.firstWhere((f) => f.id == 'hold');
    final events = <String, Map<String, dynamic>>{};
    Future<void> note(String label, Event e, Spine far) async {
      events[label] = {
        'id': e.id,
        'type': e.type,
        'from': e.author.name,
        'written_at': DateTime.fromMillisecondsSinceEpoch(e.ts).toUtc().toIso8601String(),
      };
    }

    // client → host
    final m1 = await client.append('message', {'text': 'first one over the wire'},
        at: DateTime.now(), hostAssign: false);
    final f1 = await client.append('feeling', {'feeling_id': feeling.id, 'intensity': 0.85},
        at: DateTime.now(), hostAssign: false);
    await sync.once();
    await note('message_client_to_host', m1, host);
    await note('feeling_client_to_host', f1, host);
    for (final e in [m1, f1]) {
      final there = host.byId(e.id);
      expect(there, isNotNull, reason: '${e.type} did not reach the host');
      events[e == m1 ? 'message_client_to_host' : 'feeling_client_to_host']!['arrived_seq'] =
          there!.seq;
    }

    // host → client
    final m2 = await host.append('message', {'text': 'and one coming back'},
        at: DateTime.now(), hostAssign: true);
    final f2 = await host.append('feeling', {'feeling_id': feeling.id, 'intensity': 0.6},
        at: DateTime.now(), hostAssign: true);
    await sync.once();
    await note('message_host_to_client', m2, client);
    await note('feeling_host_to_client', f2, client);
    for (final e in [m2, f2]) {
      final there = client.byId(e.id);
      expect(there, isNotNull, reason: '${e.type} did not reach the client');
      events[e == m2 ? 'message_host_to_client' : 'feeling_host_to_client']!['arrived_seq'] =
          there!.seq;
    }

    final hostOrder = host.ordered.map((e) => e.id).toList();
    final clientOrder = client.ordered.map((e) => e.id).toList();
    final four = [m1.id, f1.id, m2.id, f2.id];
    final inHost = [for (final id in four) hostOrder.indexOf(id)];
    final inClient = [for (final id in four) clientOrder.indexOf(id)];

    // what node b's daemon counted, so the wire is evidenced rather than assumed
    final peerB = ((await _status('b'))?['Peer'] as Map<String, dynamic>?)?.values
        .cast<Map<String, dynamic>>()
        .where((p) => '${p['HostName']}'.contains('lovetap-a'))
        .firstOrNull;

    await File(_out).writeAsString(const JsonEncoder.withIndent(' ').convert({
      'transport': 'tailscale',
      'status': 'ran',
      'nodes': {'host': aSelf, 'client': bSelf},
      'distinct_node_keys': aSelf['node_key'] != bSelf['node_key'],
      'distinct_addresses': [hostAddress, clientAddress],
      'host_listener': '${binding.boundTo}:8443',
      'host_reachable_at': binding.reachableAt,
      'paired_with': 'six spoken words, HKDF-SHA256; every request signed thereafter',
      'events': events,
      'spine_host_order': hostOrder,
      'spine_client_order': clientOrder,
      'four_events_at': {'host': inHost, 'client': inClient},
      'same_order_both_sides': inHost.toString() == inClient.toString(),
      'counted_by_node_b': peerB == null ? null : {
        'tx_bytes': peerB['TxBytes'], 'rx_bytes': peerB['RxBytes'],
        'path': peerB['CurAddr'] != null && '${peerB['CurAddr']}'.isNotEmpty
            ? 'direct to ${peerB['CurAddr']}' : 'relayed through ${peerB['Relay']}',
      },
      'written_at': DateTime.now().toUtc().toIso8601String(),
    }));

    expect(inHost.every((i) => i >= 0), isTrue, reason: 'an event is missing from the host spine');
    expect(inClient.every((i) => i >= 0), isTrue, reason: 'an event is missing from the client spine');
    expect(inHost, inClient, reason: 'the two devices disagree about the order of the four events');

    await clientT.stop();
    await client.close();
    await hostT.stop();
    await host.close();
  }, timeout: const Timeout(Duration(minutes: 4)));
}
