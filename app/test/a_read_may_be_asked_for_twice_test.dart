// The long poll may be asked for twice; the push may not.
//
// A messenger critic found `401 GET /v1/events?after=14075&wait=20` in two of fifteen scene logs,
// on the two longest clips, with the client's own sync recording `faults: 0` in the same file. The
// twenty-second long poll is the only request in this protocol held open long enough for the
// network under it to retry, and a browser retries an idempotent GET when the connection closes
// before the first response byte — with the same signed header, because the header is already on
// the wire. The nonce cache saw the same nonce twice and refused the second one, and from the
// client's side nothing had failed, because it was still waiting on the first.
//
// So the nonce is spent on writes, where a replay appends to the log twice, and a read is left to
// the signature and the five-minute window. This is that rule, end to end over a real socket.
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:desk/spine/spine.dart';
import 'package:desk/spine/store/store.dart';
import 'package:desk/transport/protocol/http_transport.dart';
import 'package:desk/transport/protocol/server_io.dart';
import 'package:desk/transport/protocol/wire.dart';
import 'package:desk/transport/transport.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Spine spine;
  late HostServer host;
  late Uint8List key;
  const clientId = 'the-other-phone';

  setUp(() async {
    spine = await Spine.open(
      SpineStore.memory(),
      const Identity(person: Person.noor, device: DeviceKind.android),
    );
    key = Uint8List.fromList(List<int>.generate(32, (i) => i * 7 % 251));
    final pairing = Pairing(
      hostId: 'this-phone',
      clientId: clientId,
      hostPerson: Person.noor,
      clientPerson: Person.teo,
      pairedAt: DateTime.utc(2026, 9, 3),
    );
    host = HostServer(
      spine: spine,
      deviceId: 'this-phone',
      transportName: 'test',
      pairingFor: () => pairing,
      keyFor: () => key,
      openPairing: () => null,
      onPaired: (_, __) async {},
      onEphemeral: (_) {},
      onPeerContact: (_) {},
    );
    await host.listen(const HostBind(address: '127.0.0.1', port: 0));
  });

  tearDown(() async => host.close());

  /// One request, sent twice, with the header signed once — which is what a transparent retry is.
  Future<List<int>> twice(String method, String path, {Object? body}) async {
    final bytes = body == null ? const <int>[] : utf8.encode(jsonEncode(body));
    final auth = AuthHeader.make(key, clientId, method, path, bytes);
    final codes = <int>[];
    for (var i = 0; i < 2; i++) {
      final client = HttpClient();
      final req = await client.openUrl(
          method, Uri.parse('http://127.0.0.1:${host.port}$path'));
      req.headers.set('authorization', auth.value);
      if (bytes.isNotEmpty) {
        req.headers.contentType = ContentType.json;
        req.add(bytes);
      }
      final res = await req.close();
      await res.drain<void>();
      codes.add(res.statusCode);
      client.close(force: true);
    }
    return codes;
  }

  test('the same poll arriving twice is answered twice', () async {
    // wait=0 so the poll returns at once rather than holding the test open for twenty seconds.
    expect(await twice('GET', '/v1/events?after=0&wait=0'), [200, 200]);
  });

  test('the same push arriving twice is refused the second time', () async {
    final one = {
      'id': '0001M2ZNX8AF4811Y2F7FNAGMG',
      'seq': 0,
      'ts': 1757000000000,
      'author': 'teo',
      'device': 'pwa',
      'type': 'message',
      'payload': {'text': 'left the key under the pot'},
    };
    final codes = await twice('POST', '/v1/events', body: {'events': [one]});
    expect(codes.first, 200);
    expect(codes.last, 401, reason: 'a replayed push would append the same message twice');
  });

  test('and the refusal says which phone it refused', () async {
    final client = HttpClient();
    final path = '/v1/events?after=0&wait=0';
    final auth = AuthHeader.make(key, 'a-phone-nobody-paired-with', 'GET', path, const []);
    final req = await client.openUrl('GET', Uri.parse('http://127.0.0.1:${host.port}$path'));
    req.headers.set('authorization', auth.value);
    final res = await req.close();
    await res.drain<void>();
    client.close(force: true);
    expect(res.statusCode, 401);
    expect(res.headers.value('x-desk-refused'), 'a device this pairing does not cover');
    expect(host.refusals.last, contains('a-phone-nobody-paired-with'));
    expect(host.refusals.last, contains('pairing covers the-other-phone'));
  });
}
