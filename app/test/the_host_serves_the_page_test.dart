// The page an iPhone can reach before it has anything.
//
// Step 4 of docs/PHONES.md is "open the host's address in Safari, share, add to home screen". The
// host answered 404 to every GET, because the only thing that ever passed a bundle to `_serveStatic`
// was the capture's far phone under `dart run` — the app itself passed nothing and said nothing.
// Nothing failed; there was simply nothing at the other end of the instruction.
//
// This is the server side of that, over a real socket: unauthenticated, because the iPhone cannot
// sign anything until it has the page that lets it pair.
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:desk/spine/spine.dart';
import 'package:desk/spine/store/store.dart';
import 'package:desk/transport/protocol/http_transport.dart';
import 'package:desk/transport/protocol/server_io.dart';
import 'package:desk/transport/transport.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Spine spine;
  late HostServer host;
  final asked = <String>[];

  /// Stands in for the two halves a phone reads: Android's own assets and this build's
  /// flutter_assets. What matters here is that the server asks for the right thing and hands back
  /// exactly what it was given.
  final bundle = <String, String>{
    'index.html': '<!doctype html><title>the desk</title>',
    'main.dart.js': 'console.log("the engine")',
    'canvaskit/canvaskit.wasm': 'not really wasm',
    'assets/assets/paper/index_02.webp': 'not really a photograph',
  };

  Future<HttpClientResponse> get(String path, {String method = 'GET'}) async {
    final client = HttpClient();
    final req = await client.openUrl(
        method, Uri.parse('http://127.0.0.1:${host.port}$path'));
    return req.close();
  }

  setUp(() async {
    asked.clear();
    spine = await Spine.open(
      SpineStore.memory(),
      const Identity(person: Person.noor, device: DeviceKind.android),
    );
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
      pwaFile: (path) async {
        asked.add(path);
        final tidy = path.startsWith('/') ? path.substring(1) : path;
        final body = bundle[tidy.isEmpty ? 'index.html' : tidy];
        return body == null ? null : Uint8List.fromList(utf8.encode(body));
      },
    );
    await host.listen(const HostBind(address: '127.0.0.1', port: 0));
  });

  tearDown(() async => host.close());

  test('the address itself is the page, and nobody had to sign for it', () async {
    final res = await get('/');
    expect(res.statusCode, 200);
    expect(res.headers.contentType?.mimeType, 'text/html');
    expect(await res.transform(utf8.decoder).join(), contains('the desk'));
    expect(asked, ['/']);
  });

  test('the engine and the material come through the same door', () async {
    final js = await get('/main.dart.js');
    expect(js.statusCode, 200);
    expect(js.headers.contentType?.mimeType, 'text/javascript');
    await js.drain<void>();

    final wasm = await get('/canvaskit/canvaskit.wasm');
    expect(wasm.statusCode, 200);
    expect(wasm.headers.contentType?.mimeType, 'application/wasm');
    await wasm.drain<void>();

    // The eighty-three megabytes the phone does not pack twice: this path is answered out of the
    // app's own flutter_assets. The server does not know that and should not.
    final webp = await get('/assets/assets/paper/index_02.webp');
    expect(webp.statusCode, 200);
    expect(webp.headers.contentType?.mimeType, 'image/webp');
    await webp.drain<void>();
  });

  test('a file this build does not carry is a 404, not a crash', () async {
    final res = await get('/canvaskit/nothing.wasm');
    expect(res.statusCode, 404);
    await res.drain<void>();
  });

  test('a HEAD is answered with the length and no body', () async {
    final res = await get('/index.html', method: 'HEAD');
    expect(res.statusCode, 200);
    expect(res.headers.contentLength, bundle['index.html']!.length);
    expect(await res.transform(utf8.decoder).join(), isEmpty);
  });

  test('a POST at a static path is not a way to write anything', () async {
    final res = await get('/index.html', method: 'POST');
    expect(res.statusCode, 404);
    expect(asked, isEmpty);
    await res.drain<void>();
  });

  test('the api is still the api', () async {
    // Unsigned, so refused — and refused rather than served as a file, which is the thing a static
    // handler placed in front of the routes would get wrong.
    final res = await get('/v1/hello');
    expect(res.statusCode, 401);
    expect(asked, isEmpty);
    await res.drain<void>();
  });
}
