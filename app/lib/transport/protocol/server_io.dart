// The host: a dart:io HttpServer bound where the Binding says (loopback for local, the tailnet
// address only for Tailscale). Every request except the two pairing calls must carry a valid
// pairing signature; anything else is 401 with no data.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../spine/spine.dart';
import '../transport.dart';
import 'http_transport.dart';
import 'wire.dart';

class HostServer {
  HostServer({
    required this.spine,
    required this.deviceId,
    required this.transportName,
    required this.pairingFor,
    required this.keyFor,
    required this.openPairing,
    required this.onPaired,
    required this.onEphemeral,
    required this.onPeerContact,
    this.pwaRoot,
  });

  final Spine spine;
  final String deviceId;
  final String transportName;
  final Pairing? Function() pairingFor;
  final Uint8List? Function() keyFor;
  final (PairingCode, Uint8List)? Function() openPairing;
  final Future<void> Function(Pairing, Uint8List) onPaired;
  final void Function(Ephemeral) onEphemeral;
  final void Function(int cursor) onPeerContact;
  final String? pwaRoot;

  HttpServer? _server;
  final NonceCache _nonces = NonceCache();
  final List<Ephemeral> _forClient = [];
  final Set<String> _pairNonces = {};
  Completer<void> _wake = Completer<void>();
  StreamSubscription<SpineChange>? _sub;

  Future<void> listen(HostBind bind) async {
    final ctx = bind.securityContext;
    final addr = InternetAddress(bind.address);
    _server = ctx == null
        ? await HttpServer.bind(addr, bind.port, shared: false)
        : await HttpServer.bindSecure(addr, bind.port, ctx as SecurityContext, shared: false);
    _sub = spine.changes.listen((_) => _wakeWaiters());
    _server!.listen(_handle, onError: (_) {});
  }

  int get port => _server?.port ?? 0;

  Future<void> close() async {
    await _sub?.cancel();
    await _server?.close(force: true);
    _server = null;
  }

  void queueForClient(Ephemeral frame) {
    _forClient.add(frame);
    if (_forClient.length > 64) _forClient.removeAt(0);
    _wakeWaiters();
  }

  void _wakeWaiters() {
    if (!_wake.isCompleted) _wake.complete();
    _wake = Completer<void>();
  }

  Future<void> _handle(HttpRequest req) async {
    try {
      final path = req.uri.path;
      if (!path.startsWith(kApiPrefix)) {
        await _serveStatic(req);
        return;
      }
      final sub = path.substring(kApiPrefix.length);
      if (sub == '/pair/nonce' && req.method == 'GET') { await _pairNonce(req); return; }
      if (sub == '/pair' && req.method == 'POST') { await _pair(req); return; }
      final body = await _readBody(req);
      final auth = AuthHeader.parse(req.headers.value('authorization'));
      if (!_authenticated(auth, req.method, req.uri, body)) {
        req.response.statusCode = HttpStatus.unauthorized;
        await req.response.close();
        return;
      }
      if (sub == '/events' && req.method == 'GET') { await _pull(req); return; }
      if (sub == '/events' && req.method == 'POST') { await _push(req, body); return; }
      if (sub == '/ephemeral' && req.method == 'POST') { await _ephemeral(req, body); return; }
      if (sub == '/hello' && req.method == 'GET') { await _hello(req); return; }
      if (sub == '/status' && req.method == 'GET') { await _hello(req); return; }
      if (sub.startsWith('/blobs/')) { await _blob(req, sub.substring('/blobs/'.length), body); return; }
      req.response.statusCode = HttpStatus.notFound;
      await req.response.close();
    } catch (e) {
      try {
        req.response.statusCode = HttpStatus.internalServerError;
        req.response.write(e.toString());
        await req.response.close();
      } catch (_) {}
    }
  }

  Future<List<int>> _readBody(HttpRequest req) async {
    final chunks = <int>[];
    await for (final c in req) {
      chunks.addAll(c);
    }
    return chunks;
  }

  bool _authenticated(AuthHeader? auth, String method, Uri uri, List<int> body) {
    final pairing = pairingFor();
    final key = keyFor();
    if (auth == null || pairing == null || key == null) return false;
    if (auth.deviceId != pairing.clientId) return false;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    if ((now - auth.ts).abs() > kAuthSkew.inMilliseconds) return false;
    final signedPath = uri.path + (uri.hasQuery ? '?${uri.query}' : '');
    final expected = sign(key, method, signedPath, auth.ts, auth.nonce, body);
    if (!constantTimeEquals(expected, auth.mac)) return false;
    return _nonces.checkAndAdd(auth.nonce, auth.ts);
  }

  Future<void> _json(HttpRequest req, Object body, {int status = 200}) async {
    req.response.statusCode = status;
    req.response.headers.contentType = ContentType.json;
    req.response.write(jsonEncode(body));
    await req.response.close();
  }

  Future<void> _pairNonce(HttpRequest req) async {
    final open = openPairing();
    if (open == null || open.$1.expiresAt.isBefore(DateTime.now().toUtc())) {
      req.response.statusCode = HttpStatus.forbidden;
      await req.response.close();
      return;
    }
    final nonce = randomHex(16);
    _pairNonces.add(nonce);
    await _json(req, {'host_id': deviceId, 'nonce': nonce});
  }

  Future<void> _pair(HttpRequest req) async {
    final open = openPairing();
    final body = await _readBody(req);
    if (open == null || open.$1.expiresAt.isBefore(DateTime.now().toUtc())) {
      req.response.statusCode = HttpStatus.forbidden;
      await req.response.close();
      return;
    }
    final j = jsonDecode(utf8.decode(body)) as Map<String, dynamic>;
    final nonce = j['nonce'] as String? ?? '';
    final clientId = j['device_id'] as String? ?? '';
    final proof = j['proof'] as String? ?? '';
    if (!_pairNonces.remove(nonce) || !constantTimeEquals(pairingProof(open.$2, clientId, nonce), proof)) {
      req.response.statusCode = HttpStatus.forbidden;
      await req.response.close();
      return;
    }
    final person = Person.parse(j['person'] as String);
    final pairing = Pairing(
      hostId: deviceId,
      clientId: clientId,
      hostPerson: spine.identity.person,
      clientPerson: person,
      pairedAt: DateTime.now().toUtc(),
    );
    await onPaired(pairing, open.$2);
    await _json(req, {'host_id': deviceId, 'host_person': spine.identity.person.name, 'paired': true});
  }

  Future<void> _hello(HttpRequest req) => _json(req, {
        'host_id': deviceId,
        'person': spine.identity.person.name,
        'transport': transportName,
        'version': kProtocolVersion,
        'cursor': spine.cursor,
      });

  Future<void> _pull(HttpRequest req) async {
    final after = int.tryParse(req.uri.queryParameters['after'] ?? '0') ?? 0;
    var wait = int.tryParse(req.uri.queryParameters['wait'] ?? '0') ?? 0;
    if (wait > 25) wait = 25;
    onPeerContact(after);
    var events = spine.after(after, limit: kMaxPullBatch);
    final deadline = DateTime.now().add(Duration(seconds: wait));
    while (events.isEmpty && _forClient.isEmpty && DateTime.now().isBefore(deadline)) {
      final remaining = deadline.difference(DateTime.now());
      await _wake.future.timeout(remaining, onTimeout: () {});
      events = spine.after(after, limit: kMaxPullBatch);
    }
    final eph = List<Ephemeral>.from(_forClient);
    _forClient.clear();
    await _json(req, {
      'events': events.map((e) => e.toJson()).toList(),
      'cursor': spine.cursor,
      'ephemeral': eph.map((e) => e.toJson()).toList(),
    });
  }

  Future<void> _push(HttpRequest req, List<int> body) async {
    final j = jsonDecode(utf8.decode(body)) as Map<String, dynamic>;
    final incoming = (j['events'] as List).map((e) => Event.fromJson((e as Map).cast<String, dynamic>())).toList();
    if (incoming.length > kMaxPushBatch) {
      req.response.statusCode = HttpStatus.requestEntityTooLarge;
      await req.response.close();
      return;
    }
    final pairing = pairingFor();
    // the client may only author as the person it paired as
    final allowed = incoming.where((e) => e.author == pairing?.clientPerson).toList();
    final accepted = await spine.accept(allowed);
    await _json(req, {
      'accepted': accepted.map((e) => {'id': e.id, 'seq': e.seq}).toList(),
      'cursor': spine.cursor,
    });
  }

  Future<void> _ephemeral(HttpRequest req, List<int> body) async {
    final frame = Ephemeral.fromJson(jsonDecode(utf8.decode(body)) as Map<String, dynamic>);
    onEphemeral(frame);
    req.response.statusCode = HttpStatus.noContent;
    await req.response.close();
  }

  Future<void> _blob(HttpRequest req, String hash, List<int> body) async {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(hash)) {
      req.response.statusCode = HttpStatus.badRequest;
      await req.response.close();
      return;
    }
    if (req.method == 'PUT') {
      final mime = req.headers.contentType?.mimeType ?? 'application/octet-stream';
      final bytes = Uint8List.fromList(body);
      if (Spine.hashOf(bytes) != hash) {
        req.response.statusCode = HttpStatus.badRequest;
        await req.response.close();
        return;
      }
      final existed = await spine.hasBlob(hash);
      if (!existed) await spine.putBlobWithHash(hash, bytes, mime);
      req.response.statusCode = existed ? HttpStatus.ok : HttpStatus.created;
      await req.response.close();
      return;
    }
    final blob = await spine.blob(hash);
    if (blob == null) {
      req.response.statusCode = HttpStatus.notFound;
      await req.response.close();
      return;
    }
    req.response.statusCode = HttpStatus.ok;
    req.response.headers.contentType = ContentType.parse(blob.mime);
    req.response.headers.contentLength = blob.length;
    if (req.method != 'HEAD') req.response.add(blob.bytes);
    await req.response.close();
  }

  Future<void> _serveStatic(HttpRequest req) async {
    final root = pwaRoot;
    if (root == null || req.method != 'GET') {
      req.response.statusCode = HttpStatus.notFound;
      await req.response.close();
      return;
    }
    var rel = req.uri.path == '/' ? 'index.html' : req.uri.path.substring(1);
    rel = p.normalize(rel);
    if (rel.startsWith('..')) {
      req.response.statusCode = HttpStatus.forbidden;
      await req.response.close();
      return;
    }
    var file = File(p.join(root, rel));
    if (!await file.exists()) file = File(p.join(root, 'index.html'));
    if (!await file.exists()) {
      req.response.statusCode = HttpStatus.notFound;
      await req.response.close();
      return;
    }
    req.response.headers.contentType = _mimeFor(file.path);
    req.response.headers.set('cache-control', 'no-cache');
    await req.response.addStream(file.openRead());
    await req.response.close();
  }

  static ContentType _mimeFor(String path) {
    switch (p.extension(path)) {
      case '.html':
        return ContentType.html;
      case '.js':
        return ContentType('text', 'javascript', charset: 'utf-8');
      case '.json':
        return ContentType.json;
      case '.css':
        return ContentType('text', 'css', charset: 'utf-8');
      case '.png':
        return ContentType('image', 'png');
      case '.webp':
        return ContentType('image', 'webp');
      case '.wasm':
        return ContentType('application', 'wasm');
      case '.ttf':
        return ContentType('font', 'ttf');
      case '.ogg':
        return ContentType('audio', 'ogg');
      case '.mp4':
        return ContentType('video', 'mp4');
      case '.webmanifest':
        return ContentType('application', 'manifest+json');
      case '.svg':
        return ContentType('image', 'svg+xml');
      default:
        return ContentType.binary;
    }
  }
}
