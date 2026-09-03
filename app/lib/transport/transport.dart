// The transport interface. Fixed here: host and client roles, cursor sync, the outbox, pairing
// authentication, blob transfer, ephemeral frames, and fault injection. The local transport
// (transport/local/) and the Tailscale transport (transport/tailscale/) implement the same
// interface; nothing above this file knows which one is in use except by its `name`, which
// every report must carry.
import 'dart:async';
import 'dart:typed_data';

import '../spine/spine.dart';
import 'faults.dart';

export 'faults.dart';

/// Host: the Android phone, binding a listener and assigning sequence numbers.
/// Client: the PWA, holding an outbox and pulling by cursor.
enum TransportRole { host, client }

enum LinkState {
  stopped,
  starting,

  /// Host only: bound and accepting connections.
  listening,

  /// Client only: trying to reach the host.
  connecting,

  /// Client: the last exchange with the host succeeded. Host: the client pulled recently.
  connected,

  /// Client: the host cannot be reached; the outbox is kept until it can.
  offline,
  error,
}

class TransportStatus {
  const TransportStatus({
    required this.name,
    required this.role,
    required this.state,
    this.address,
    this.peerCursor,
    this.ourCursor,
    this.lastError,
    this.since,
    this.lastContact,
  });

  /// 'local' or 'tailscale'. Appears in every report.
  final String name;
  final TransportRole role;
  final LinkState state;

  /// Host: the bound address. Client: the host address in use.
  final String? address;

  /// Host: the highest seq the client has acknowledged pulling (its cursor).
  final int? peerCursor;

  /// This device's cursor (highest seq held).
  final int? ourCursor;
  final String? lastError;
  final DateTime? since;
  final DateTime? lastContact;

  TransportStatus copyWith({
    LinkState? state,
    String? address,
    int? peerCursor,
    int? ourCursor,
    String? lastError,
    DateTime? since,
    DateTime? lastContact,
    bool clearError = false,
  }) =>
      TransportStatus(
        name: name,
        role: role,
        state: state ?? this.state,
        address: address ?? this.address,
        peerCursor: peerCursor ?? this.peerCursor,
        ourCursor: ourCursor ?? this.ourCursor,
        lastError: clearError ? null : (lastError ?? this.lastError),
        since: since ?? this.since,
        lastContact: lastContact ?? this.lastContact,
      );

  Map<String, dynamic> toJson() => {
        'transport': name,
        'role': role.name,
        'state': state.name,
        'address': address,
        'peer_cursor': peerCursor,
        'our_cursor': ourCursor,
        'last_error': lastError,
        'since': since?.toIso8601String(),
        'last_contact': lastContact?.toIso8601String(),
      };
}

/// What the host says about each pushed event.
class Accepted {
  const Accepted({required this.id, required this.seq});
  final String id;
  final int seq;
}

class PullResponse {
  const PullResponse({required this.events, required this.cursor, required this.ephemeral});

  /// Events with seq greater than the requested cursor, in order.
  final List<Event> events;

  /// The host's highest seq at the time of the response.
  final int cursor;

  /// Typing, presence and cursor frames queued for this client. Never stored.
  final List<Ephemeral> ephemeral;
}

/// A frame that is not an event: typing indication, presence, cursor acknowledgement.
class Ephemeral {
  const Ephemeral({required this.kind, required this.from, required this.at, this.data = const {}});
  final String kind;
  final Person from;
  final int at;
  final Map<String, dynamic> data;

  Map<String, dynamic> toJson() => {'kind': kind, 'from': from.name, 'at': at, 'data': data};

  static Ephemeral fromJson(Map<String, dynamic> j) => Ephemeral(
        kind: j['kind'] as String,
        from: Person.parse(j['from'] as String),
        at: j['at'] as int,
        data: (j['data'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
}

/// The six words the host shows and the client types. The pairing key is derived from them.
class PairingCode {
  const PairingCode(this.words, {required this.hostId, required this.expiresAt});
  final List<String> words;
  final String hostId;
  final DateTime expiresAt;

  String get spoken => words.join(' ');
}

/// The peer this device is paired with.
class Pairing {
  const Pairing({
    required this.hostId,
    required this.clientId,
    required this.hostPerson,
    required this.clientPerson,
    required this.pairedAt,
  });
  final String hostId;
  final String clientId;
  final Person hostPerson;
  final Person clientPerson;
  final DateTime pairedAt;

  Map<String, dynamic> toJson() => {
        'host_id': hostId,
        'client_id': clientId,
        'host_person': hostPerson.name,
        'client_person': clientPerson.name,
        'paired_at': pairedAt.toIso8601String(),
      };

  static Pairing fromJson(Map<String, dynamic> j) => Pairing(
        hostId: j['host_id'] as String,
        clientId: j['client_id'] as String,
        hostPerson: Person.parse(j['host_person'] as String),
        clientPerson: Person.parse(j['client_person'] as String),
        pairedAt: DateTime.parse(j['paired_at'] as String),
      );
}

class TransportException implements Exception {
  TransportException(this.message, {this.status, this.offline = false});
  final String message;
  final int? status;

  /// True when the host could not be reached at all (keep the outbox, back off).
  final bool offline;

  @override
  String toString() => 'TransportException($message${status != null ? ' $status' : ''})';
}

/// Everything a device does on the wire, in either role.
abstract class Transport {
  /// 'local' during the build, 'tailscale' in the final phase. Every report carries it.
  String get name;
  TransportRole get role;

  TransportStatus get current;
  Stream<TransportStatus> get status;

  /// The device identifier this transport authenticates as.
  String get deviceId;

  /// Host: bind and listen (on the loopback for local, only on the tailnet address for
  /// tailscale). Client: load the pairing and be ready to sync.
  Future<void> start();
  Future<void> stop();

  // ---- cursor sync -----------------------------------------------------------------------
  /// Client → host: events with seq > [after]; the host holds the request up to [wait].
  Future<PullResponse> pull(int after, {Duration wait = const Duration(seconds: 20)});

  /// Client → host: the outbox. Idempotent by event id; the host returns the seq of each.
  Future<List<Accepted>> push(List<Event> outbox);

  // ---- ephemeral -------------------------------------------------------------------------
  Future<void> sendEphemeral(Ephemeral frame);

  /// Frames received from the peer (host: from the client; client: from the host via pull).
  Stream<Ephemeral> get ephemeral;

  // ---- blobs -----------------------------------------------------------------------------
  Future<void> putBlob(String hash, String mime, Uint8List bytes);
  Future<StoredBlob?> getBlob(String hash);
  Future<bool> hasBlob(String hash);

  // ---- pairing ---------------------------------------------------------------------------
  /// Host: mint the six words and open a pairing window. Replaces any existing pairing when
  /// the client completes, which is also how a replaced device is re-paired.
  Future<PairingCode> beginPairing();

  /// Client: prove the six words to the host at [hostAddress]. On success the pairing is stored
  /// and every later request is authenticated with the derived key.
  Future<Pairing> completePairing(String hostAddress, String sixWords);

  /// The stored pairing, if any.
  Pairing? get pairing;

  /// Forget the pairing (Settings → replace a device).
  Future<void> unpair();

  // ---- faults ----------------------------------------------------------------------------
  /// Injectable faults. The local transport wires these; the Tailscale transport uses NoFaults.
  FaultInjector get faults;

  /// A report line for reliability.json and coldstart.json.
  Map<String, dynamic> report();
}
