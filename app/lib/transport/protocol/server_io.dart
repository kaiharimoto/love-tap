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

/// The file inside [root] that a request for [urlPath] may have, or null if it may have none.
///
/// The bundle is served without authentication on purpose: it is how the other phone gets the app
/// at all, and a phone that had to be paired before it could fetch the thing that does the pairing
/// could never be paired. What must not happen is that it serves anything else, and it did.
/// `p.join(root, rel)` returns `rel` whole when `rel` is absolute, and `req.uri.path.substring(1)`
/// leaves a leading slash on `//etc/passwd`, which normalize keeps — so that request walked out of
/// the bundle and read the machine. Everything here is decided on the resolved path rather than on
/// the one that was asked for.
String? insideTheBundle(String root, String urlPath) {
  // [urlPath] is req.uri.path, which Dart has already percent-decoded. Decoding again
  // here would turn `%252e%252e` into `..` and open the hole this closes.
  var rel = p.normalize(urlPath).replaceAll('\\', '/');
  while (rel.startsWith('/')) {
    rel = rel.substring(1);
  }
  if (rel.isEmpty) rel = 'index.html';
  if (rel.startsWith('..')) return null;
  final within = p.normalize(p.absolute(root));
  final asked = p.normalize(p.join(within, rel));
  if (asked != within && !p.isWithin(within, asked)) return null;
  return asked;
}

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
    this.refuses,
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

  /// Why this host will not take an event, or null if it will.
  ///
  /// A host refusing something is a real thing and it is one of the five states a message can be
  /// in, and until now it was the only one unreachable over the wire — the two rules below (an
  /// author the pairing does not cover, a kind this build has never heard of) are the ones any
  /// host has, and neither can be produced from the other phone's own composer. This is where a
  /// host puts a rule of its own; the far phone in the capture uses it to refuse one message on
  /// request, so the artifact named for the messenger's states can show the state.
  final String? Function(Event e)? refuses;

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
      final why = _refuseReason(auth, req.method, req.uri, body);
      if (why != null) {
        // With the device, because two of the five reasons are about *which* phone asked, and a
        // refusal line that does not say who was refused cannot tell a stale client from a wrong
        // key.
        refusals.add('${req.method} ${req.uri.path}: $why '
            '(${auth?.deviceId ?? 'unsigned'}, pairing covers ${pairingFor()?.clientId ?? 'nobody'})');
        if (refusals.length > 20) refusals.removeAt(0);
        req.response.statusCode = HttpStatus.unauthorized;
        req.response.headers.set('x-desk-refused', why);
        req.response.write(why);
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

  /// Why a request was refused, or null if it was not.
  ///
  /// It used to answer yes or no, and a 401 with no reason is a fault nobody can fix: a messenger
  /// critic found `401 GET /v1/events?after=14079&wait=20` in two of fifteen scene logs and there
  /// was nothing anywhere saying which of the five checks it failed. The five are a stale
  /// timestamp, an unknown device, a bad signature, a replayed nonce, and no pairing at all, and
  /// they have completely different causes.
  ///
  /// This says which, in the response and in the log. On a link between two phones that already
  /// share a key, telling the caller which check it failed tells an attacker nothing they could
  /// not learn by trying — and it is the difference between a bug that can be found and one that
  /// cannot.
  String? _refuseReason(AuthHeader? auth, String method, Uri uri, List<int> body) {
    final pairing = pairingFor();
    final key = keyFor();
    if (auth == null) return 'no authorization header';
    if (pairing == null || key == null) return 'this phone is not paired with anybody';
    if (auth.deviceId != pairing.clientId) return 'a device this pairing does not cover';
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final skew = now - auth.ts;
    if (skew.abs() > kAuthSkew.inMilliseconds) {
      return 'signed ${(skew / 1000).round()} seconds from now, and the window is '
          '${kAuthSkew.inSeconds}';
    }
    final signedPath = uri.path + (uri.hasQuery ? '?${uri.query}' : '');
    final expected = sign(key, method, signedPath, auth.ts, auth.nonce, body);
    if (!constantTimeEquals(expected, auth.mac)) return 'the signature does not match';
    // The replay window guards writes. A read is not replay-protected, and this is why.
    //
    // The refusal a critic found was on `GET /v1/events?after=14075&wait=20` — the twenty-second
    // long poll, and the only request in this protocol that is held open long enough for the
    // network under it to do anything interesting. A browser transparently retries an idempotent
    // GET when the connection is closed before the first response byte arrives, and the retry
    // carries the same signed header, because the header is what was already written to the
    // socket. The nonce cache sees the same nonce twice and refuses the second one. That matches
    // what the evidence shows and nothing else in the evidence does: it happened on two of
    // fifteen scenes and both are the long clips, where the poll cycles for minutes; the client's
    // own sync recorded `faults: 0`, because from the client's side the retry is the same request
    // it is still waiting on.
    //
    // Replaying a GET reveals nothing the original did not: it re-reads events the caller has
    // already been given, at a cursor it already holds, with a signature only the paired key can
    // make and a timestamp that must be inside `kAuthSkew`. Replaying a POST appends to the log
    // twice, which is a different thing entirely, so that is what the nonce is spent on.
    if (method != 'GET' && !_nonces.checkAndAdd(auth.nonce, auth.ts)) {
      return 'this request has already been made';
    }
    return null;
  }

  /// The last few refusals, newest last, for the capture record and for a person debugging a link.
  final List<String> refusals = [];

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
    // The host answers about every event it was sent, rather than dropping the ones it will not
    // take. Silently discarding them left the other phone re-pushing them for ever with the row
    // on its screen looking as if it had gone, and left the refusal path — one of the five states
    // a message can be in — unreachable over the wire, so no artifact could ever show it.
    final refused = <String, String>{};
    final allowed = <Event>[];
    for (final e in incoming) {
      // the client may only author as the person it paired as
      if (e.author != pairing?.clientPerson) {
        refused[e.id] = 'this phone is paired with ${pairing?.clientPerson.name ?? 'nobody'}, '
            'so it cannot take something written as ${e.author.name}';
        continue;
      }
      // and it can only take a kind of thing it knows about: a phone on an older version does not
      // have the newer one's event types in its registry, and guessing at one would corrupt the
      // log both of them share
      if (!kEventTypeById.containsKey(e.type)) {
        refused[e.id] = 'this phone does not know what a ${e.type} is; it is on an older version';
        continue;
      }
      final why = refuses?.call(e);
      if (why != null) {
        refused[e.id] = why;
        continue;
      }
      allowed.add(e);
    }
    final accepted = await spine.accept(allowed);
    await _json(req, {
      'accepted': accepted.map((e) => {'id': e.id, 'seq': e.seq}).toList(),
      'refused': [for (final e in refused.entries) {'id': e.key, 'why': e.value}],
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
    final asked = insideTheBundle(root, req.uri.path);
    if (asked == null) {
      req.response.statusCode = HttpStatus.forbidden;
      await req.response.close();
      return;
    }
    var file = File(asked);
    if (!await file.exists()) file = File(p.join(p.normalize(p.absolute(root)), 'index.html'));
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
