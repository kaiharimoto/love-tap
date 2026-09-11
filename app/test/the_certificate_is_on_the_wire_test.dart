// The host's TLS, and the page that hands the certificate over, proven on real sockets.
//
// The unit test beside this one checks the pieces: a certificate gets made, a fingerprint gets
// compared, a checklist step reads a fact. None of that would catch the failure it was written
// for — the host had a `securityContext` parameter and simply never received one, and every
// individual piece was fine. So this opens actual sockets: a TLS handshake that succeeds only
// against the certificate the phone made, one that fails against any other, and the plain page
// that exists so an iPhone can be given the certificate before it is asked to trust it.
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:desk/setup/bootstrap_page.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/spine/store/store.dart';
import 'package:desk/transport/protocol/http_transport.dart';
import 'package:desk/transport/protocol/server_io.dart';
import 'package:desk/transport/tailscale/certificate.dart';
import 'package:desk/transport/tailscale/proxy_client_io.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Spine spine;
  late HostServer host;
  late HostCertificate cert;
  late Directory dir;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('wire_tls');
    spine = await Spine.open(
      SpineStore.memory(),
      const Identity(person: Person.noor, device: DeviceKind.android),
    );
    cert = await certificateIn(dir, '127.0.0.1');
    host = HostServer(
      spine: spine,
      deviceId: 'this-phone',
      transportName: 'test',
      pairingFor: () => null,
      keyFor: () => null,
      openPairing: () => null,
      onPaired: (_, __) async {},
      onEphemeral: (_) {},
      onPeerContact: (_) {},
      certificatePem: () => cert.certificatePem,
    );
    await host.listen(HostBind(
        address: '127.0.0.1', port: 0, securityContext: cert.context));
  });

  tearDown(() async {
    await host.close();
    dir.deleteSync(recursive: true);
  });

  Future<HttpClientResponse> get(Uri uri, {String? pin}) async {
    final client = HttpClient()
      ..badCertificateCallback = (c, h, p) => pin == null || fingerprintOfDer(c.der) == pin;
    try {
      final req = await client.getUrl(uri);
      return await req.close();
    } finally {
      client.close(force: true);
    }
  }

  test('the app port speaks TLS and nothing else', () async {
    final res = await get(Uri.parse('https://127.0.0.1:${host.port}/v1/hello'),
        pin: cert.fingerprint);
    await res.drain<void>();
    // 401, because nothing signed it — which is the point: the handshake got far enough for the
    // host to refuse the request rather than refuse the connection.
    expect(res.statusCode, 401);

    // And plain HTTP to the same port does not get a page, it gets nothing readable at all.
    await expectLater(
      get(Uri.parse('http://127.0.0.1:${host.port}/v1/hello')),
      throwsA(anything),
      reason: 'the app port answered in the clear',
    );
  });

  test('a client that pinned a different certificate does not get a connection', () async {
    final other = makeCertificate('127.0.0.1');
    expect(other.fingerprint, isNot(cert.fingerprint));
    final uri = Uri.parse('https://127.0.0.1:${host.port}/v1/hello');

    // The right pin first, and it has to actually connect. Without this line the test passes on a
    // host serving no TLS at all — the handshake fails there too, for the opposite reason — which
    // is how a check ends up green for a thing it was written to catch.
    final ok = await get(uri, pin: cert.fingerprint);
    await ok.drain<void>();
    expect(ok.statusCode, 401);

    await expectLater(
      get(uri, pin: other.fingerprint),
      throwsA(isA<HandshakeException>()),
    );
  });

  test('the setup page is reachable before anything is trusted', () async {
    final where = host.setupAddress;
    expect(where, isNotNull, reason: 'a certificate nobody can be given is a certificate nobody '
        'can trust');
    expect(where, startsWith('http://'), reason: 'behind the certificate, on purpose it is not');

    final res = await get(Uri.parse(where!));
    final body = await res.transform(utf8.decoder).join();
    expect(res.statusCode, 200);
    expect(res.headers.contentType?.mimeType, 'text/html');
    expect(body, contains('/setup/profile.mobileconfig'));
    expect(body, contains("Noor's phone"));
  });

  test('and the profile it hands over carries the certificate and no key', () async {
    final base = Uri.parse(host.setupAddress!);
    final res = await get(base.replace(path: '/setup/profile.mobileconfig'));
    final body = await res.transform(utf8.decoder).join();
    expect(res.statusCode, 200);
    expect(res.headers.contentType?.mimeType, 'application/x-apple-aspen-config',
        reason: 'iOS treats anything else as a download nobody can open');

    // The certificate itself, byte for byte, and nothing that is not it.
    final der = base64.encode(derOf(cert.certificatePem));
    expect(body.replaceAll(RegExp(r'\s'), ''), contains(der));
    expect(body, isNot(contains('PRIVATE KEY')));
    expect(body, isNot(contains(cert.privateKeyPem.split('\n')[1])));

    // Installing it twice replaces one profile rather than leaving a list of near-identical ones.
    final again = await get(base.replace(path: '/setup/profile.mobileconfig'));
    expect(await again.transform(utf8.decoder).join(), body);
    expect(uuidFor(cert.fingerprint, 'profile'), isNot(uuidFor(cert.fingerprint, 'payload')));
  });

  test('the plain port serves those two things and nothing else', () async {
    final base = Uri.parse(host.setupAddress!);
    for (final path in ['/', '/v1/events', '/main.dart.js', '/setup/../host.key']) {
      final res = await get(base.replace(path: path));
      await res.drain<void>();
      expect(res.statusCode, 404, reason: 'the plain port answered $path');
    }
  });
}
