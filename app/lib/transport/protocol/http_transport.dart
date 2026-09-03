// The HTTP protocol shared by both transports. A Binding says where the host listens and where
// the client connects; everything else (auth, cursor sync, outbox, pairing, blobs, ephemeral)
// is here and identical for local and Tailscale.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../spine/spine.dart';
import '../transport.dart';
import 'server_stub.dart' if (dart.library.io) 'server_io.dart' as srv;
import 'wire.dart';

/// Where a transport binds (host) or connects (client). The only thing local and Tailscale differ in.
abstract class Binding {
  String get name;

  /// Host: the address to bind. For Tailscale this MUST be the tailnet address and nothing else.
  Future<HostBind> hostBind();

  /// Client: the base URL of the host, e.g. http://127.0.0.1:8480 or https://noor-phone.tailnet:8443.
  Future<Uri> clientBase(String? storedAddress);

  /// An HTTP client for the client role (may carry a TLS context or a SOCKS proxy).
  http.Client makeClient();

  FaultInjector get faults;
}

class HostBind {
  const HostBind({required this.address, required this.port, this.securityContext});
  final String address;
  final int port;
  final Object? securityContext; // dart:io SecurityContext on the host; null for plain HTTP
}

class HttpTransport implements Transport {
  HttpTransport({
    required this.role,
    required this.spine,
    required this.binding,
    required this.deviceId,
    this.pwaRoot,
  }) : _status = TransportStatus(name: binding.name, role: role, state: LinkState.stopped);

  @override
  final TransportRole role;
  final Spine spine;
  final Binding binding;
  @override
  final String deviceId;

  /// Host: directory of the built PWA to serve at /. Null until the web build is bundled.
  final String? pwaRoot;

  TransportStatus _status;
  final StreamController<TransportStatus> _statusCtl = StreamController.broadcast();
  final StreamController<Ephemeral> _ephemeralCtl = StreamController.broadcast();
  srv.HostServer? _server;
  http.Client? _client;
  Uri? _base;
  Uint8List? _key;
  Pairing? _pairing;
  PairingCode? _openCode;
  Uint8List? _openKey;

  @override
  String get name => binding.name;

  @override
  TransportStatus get current => _status;

  @override
  Stream<TransportStatus> get status => _statusCtl.stream;

  @override
  Stream<Ephemeral> get ephemeral => _ephemeralCtl.stream;

  @override
  FaultInjector get faults => binding.faults;

  @override
  Pairing? get pairing => _pairing;

  void _set(TransportStatus s) {
    _status = s;
    if (!_statusCtl.isClosed) _statusCtl.add(s);
  }

  // ---- lifecycle --------------------------------------------------------------------------
  @override
  Future<void> start() async {
    _set(_status.copyWith(state: LinkState.starting, since: DateTime.now().toUtc(), clearError: true));
    await _loadPairing();
    if (role == TransportRole.host) {
      final bind = await binding.hostBind();
      _server = srv.HostServer(
        spine: spine,
        deviceId: deviceId,
        transportName: name,
        pairingFor: () => _pairing,
        keyFor: () => _key,
        openPairing: () => _openCode == null || _openKey == null ? null : (_openCode!, _openKey!),
        onPaired: _storePairingFromHost,
        onEphemeral: (e) => _ephemeralCtl.add(e),
        onPeerContact: (cursor) => _set(_status.copyWith(
            state: LinkState.connected, peerCursor: cursor, ourCursor: spine.cursor, lastContact: DateTime.now().toUtc())),
        pwaRoot: pwaRoot,
      );
      await _server!.listen(bind);
      _set(_status.copyWith(state: LinkState.listening, address: '${bind.address}:${bind.port}', ourCursor: spine.cursor));
    } else {
      _client = binding.makeClient();
      _base = await binding.clientBase(await spine.meta('transport.host_address'));
      _set(_status.copyWith(state: _pairing == null ? LinkState.connecting : LinkState.connecting, address: _base.toString(), ourCursor: spine.cursor));
    }
  }

  @override
  Future<void> stop() async {
    await _server?.close();
    _server = null;
    _client?.close();
    _client = null;
    _set(_status.copyWith(state: LinkState.stopped));
  }

  Future<void> _loadPairing() async {
    final json = await spine.meta('transport.pairing');
    final keyHex = await spine.meta('transport.key');
    if (json != null && keyHex != null) {
      _pairing = Pairing.fromJson(jsonDecode(json) as Map<String, dynamic>);
      _key = Uint8List.fromList(List<int>.generate(keyHex.length ~/ 2, (i) => int.parse(keyHex.substring(i * 2, i * 2 + 2), radix: 16)));
    }
  }

  Future<void> _storePairing(Pairing p, Uint8List key) async {
    _pairing = p;
    _key = key;
    await spine.setMeta('transport.pairing', jsonEncode(p.toJson()));
    await spine.setMeta('transport.key', hex(key));
  }

  Future<void> _storePairingFromHost(Pairing p, Uint8List key) async {
    await _storePairing(p, key);
    _openCode = null;
    _openKey = null;
  }

  // ---- client requests ---------------------------------------------------------------------
  Future<http.Response> _send(String method, String path, {List<int>? body, String? contentType, Map<String, String>? query}) async {
    final base = _base;
    final client = _client;
    if (base == null || client == null) throw TransportException('client not started', offline: true);
    final key = _key;
    if (key == null) throw TransportException('not paired', status: 401);
    final bytes = body ?? const <int>[];
    final uri = base.replace(path: '$kApiPrefix$path', queryParameters: query);
    final signedPath = uri.path + (uri.hasQuery ? '?${uri.query}' : '');
    try {
      await faults.beforeRequest('$method $path');
    } on InjectedFault catch (f) {
      throw TransportException(f.what, offline: true);
    }
    final headers = <String, String>{
      'authorization': AuthHeader.make(key, deviceId, method, signedPath, bytes).value,
      ...?(contentType == null ? null : {'content-type': contentType}),
    };
    final req = http.Request(method, uri)
      ..headers.addAll(headers)
      ..bodyBytes = Uint8List.fromList(bytes);
    http.Response res;
    try {
      res = await http.Response.fromStream(await client.send(req).timeout(const Duration(seconds: 40)));
    } on TransportException {
      rethrow;
    } catch (e) {
      _set(_status.copyWith(state: LinkState.offline, lastError: e.toString()));
      throw TransportException(e.toString(), offline: true);
    }
    try {
      await faults.beforeResponse('$method $path');
    } on InjectedFault catch (f) {
      _set(_status.copyWith(state: LinkState.offline, lastError: f.what));
      throw TransportException(f.what, offline: true);
    }
    if (res.statusCode >= 400) {
      _set(_status.copyWith(state: res.statusCode == 401 ? LinkState.error : _status.state, lastError: 'HTTP ${res.statusCode}'));
      throw TransportException(res.body, status: res.statusCode);
    }
    _set(_status.copyWith(state: LinkState.connected, lastContact: DateTime.now().toUtc(), ourCursor: spine.cursor, clearError: true));
    return res;
  }

  @override
  Future<PullResponse> pull(int after, {Duration wait = const Duration(seconds: 20)}) async {
    final res = await _send('GET', '/events', query: {'after': '$after', 'wait': '${wait.inSeconds}'});
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final events = (j['events'] as List).map((e) => Event.fromJson((e as Map).cast<String, dynamic>())).toList();
    final eph = (j['ephemeral'] as List? ?? const []).map((e) => Ephemeral.fromJson((e as Map).cast<String, dynamic>())).toList();
    for (final e in eph) {
      _ephemeralCtl.add(e);
    }
    _set(_status.copyWith(peerCursor: j['cursor'] as int));
    return PullResponse(events: events, cursor: j['cursor'] as int, ephemeral: eph);
  }

  @override
  Future<List<Accepted>> push(List<Event> outbox) async {
    if (outbox.isEmpty) return const [];
    final body = utf8.encode(jsonEncode({'events': outbox.map((e) => e.toJson()).toList()}));
    final res = await _send('POST', '/events', body: body, contentType: 'application/json');
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    return (j['accepted'] as List)
        .map((a) => Accepted(id: (a as Map)['id'] as String, seq: a['seq'] as int))
        .toList();
  }

  @override
  Future<void> sendEphemeral(Ephemeral frame) async {
    if (role == TransportRole.host) {
      _server?.queueForClient(frame);
      return;
    }
    final body = utf8.encode(jsonEncode(frame.toJson()));
    await _send('POST', '/ephemeral', body: body, contentType: 'application/json');
  }

  @override
  Future<void> putBlob(String hash, String mime, Uint8List bytes) async {
    if (role == TransportRole.host) {
      await spine.putBlobWithHash(hash, bytes, mime);
      return;
    }
    await _send('PUT', '/blobs/$hash', body: bytes, contentType: mime);
  }

  @override
  Future<StoredBlob?> getBlob(String hash) async {
    if (role == TransportRole.host) return spine.blob(hash);
    try {
      final res = await _send('GET', '/blobs/$hash');
      final mime = res.headers['content-type'] ?? 'application/octet-stream';
      return StoredBlob(hash: hash, mime: mime, length: res.bodyBytes.length, bytes: res.bodyBytes);
    } on TransportException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  @override
  Future<bool> hasBlob(String hash) async {
    if (role == TransportRole.host) return spine.hasBlob(hash);
    try {
      await _send('HEAD', '/blobs/$hash');
      return true;
    } on TransportException catch (e) {
      if (e.status == 404) return false;
      rethrow;
    }
  }

  // ---- pairing ------------------------------------------------------------------------------
  @override
  Future<PairingCode> beginPairing() async {
    if (role != TransportRole.host) throw UnsupportedError('only the host mints a pairing code');
    final words = mintPairingWords();
    final code = PairingCode(words, hostId: deviceId, expiresAt: DateTime.now().toUtc().add(kPairingWindow));
    _openCode = code;
    _openKey = derivePairingKey(code.spoken, deviceId);
    return code;
  }

  @override
  Future<Pairing> completePairing(String hostAddress, String sixWords) async {
    if (role != TransportRole.client) throw UnsupportedError('only the client completes pairing');
    _client ??= binding.makeClient();
    _base = await binding.clientBase(hostAddress);
    await spine.setMeta('transport.host_address', hostAddress);
    final client = _client!;
    final base = _base!;
    try {
      await faults.beforeRequest('pair');
    } on InjectedFault catch (f) {
      throw TransportException(f.what, offline: true);
    }
    http.Response nonceRes;
    try {
      nonceRes = await client.get(base.replace(path: '$kApiPrefix/pair/nonce')).timeout(const Duration(seconds: 20));
    } catch (e) {
      throw TransportException(e.toString(), offline: true);
    }
    if (nonceRes.statusCode != 200) throw TransportException('no pairing open', status: nonceRes.statusCode);
    final nj = jsonDecode(nonceRes.body) as Map<String, dynamic>;
    final hostId = nj['host_id'] as String;
    final nonce = nj['nonce'] as String;
    final key = derivePairingKey(sixWords, hostId);
    final body = jsonEncode({
      'device_id': deviceId,
      'device_kind': spine.identity.device.name,
      'person': spine.identity.person.name,
      'nonce': nonce,
      'proof': pairingProof(key, deviceId, nonce),
    });
    final res = await client
        .post(base.replace(path: '$kApiPrefix/pair'), headers: {'content-type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) throw TransportException('pairing refused', status: res.statusCode);
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final p = Pairing(
      hostId: hostId,
      clientId: deviceId,
      hostPerson: Person.parse(j['host_person'] as String),
      clientPerson: spine.identity.person,
      pairedAt: DateTime.now().toUtc(),
    );
    await _storePairing(p, key);
    _set(_status.copyWith(state: LinkState.connected, address: base.toString(), lastContact: DateTime.now().toUtc(), clearError: true));
    return p;
  }

  @override
  Future<void> unpair() async {
    _pairing = null;
    _key = null;
    await spine.setMeta('transport.pairing', null);
    await spine.setMeta('transport.key', null);
  }

  @override
  Map<String, dynamic> report() => {
        ...current.toJson(),
        'device_id': deviceId,
        'paired': _pairing?.toJson(),
        ...faults.describe(),
      };
}
