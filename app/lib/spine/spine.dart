// The single event spine. Every region reads from here; every module writes here. There is no
// other store. Host order (seq) is the thread order; the author's clock rides along.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'event.dart';
import 'search.dart';
import 'store/store.dart';
import 'types.dart';
import 'ulid.dart';

export 'event.dart';
export 'ulid.dart';
export 'search.dart' show SearchHit;
export 'store/store.dart' show SpineStore, StoredBlob;
export 'types.dart';

/// Identity of this device: who is holding it and which kind it is.
class Identity {
  const Identity({required this.person, required this.device});
  final Person person;
  final DeviceKind device;
}

class SpineChange {
  const SpineChange({required this.added, required this.assigned});

  /// Events new to this device (local or remote).
  final List<Event> added;

  /// Pending events that just received their seq.
  final List<Event> assigned;
}

class Spine {
  Spine._(this._store, this.identity, {UlidFactory? ulids}) : _ulids = ulids ?? UlidFactory();

  final SpineStore _store;
  final Identity identity;
  final UlidFactory _ulids;
  final List<Event> _ordered = []; // seq order
  final List<Event> _pending = []; // outbox: minted here, no seq yet

  /// Ids the host would not take, and why. Nothing is deleted from the outbox when it is
  /// refused: it stays where its author can see it, marked, until they deal with it.
  final Map<String, String> _refused = {};

  /// Ids the sync engine has a push in flight for. Whether something is on its way or still
  /// waiting for its turn is a fact about the event, not about the link — two messages written a
  /// second apart can be in different states, and the thread should say so.
  final Set<String> _inFlight = {};
  final Map<String, Event> _byId = {};
  final SearchIndex _search = SearchIndex();
  final StreamController<SpineChange> _changes = StreamController.broadcast();
  final Set<int> _seqs = {};
  int _maxSeq = 0; // highest seq held
  int _cursor = 0; // highest seq such that every seq up to it is held (never skips a gap)

  /// Opens the spine for a device profile and replays the stored log into memory.
  static Future<Spine> open(SpineStore store, Identity identity, {UlidFactory? ulids}) async {
    final s = Spine._(store, identity, ulids: ulids);
    await s._replay();
    return s;
  }

  Future<void> _replay() async {
    final all = await _store.loadAll();
    _ordered.clear();
    _pending.clear();
    _byId.clear();
    _search.clear();
    _seqs.clear();
    _maxSeq = 0;
    _cursor = 0;
    for (final e in all) {
      _byId[e.id] = e;
      if (e.seq == null) {
        _pending.add(e);
      } else {
        _ordered.add(e);
        _noteSeq(e.seq!);
      }
    }
    for (final e in _ordered) {
      _search.add(e);
    }
    for (final e in _pending) {
      _search.add(e);
    }
  }

  Stream<SpineChange> get changes => _changes.stream;

  /// Every accepted event in host order.
  List<Event> get ordered => List.unmodifiable(_ordered);

  /// How many events of one type there are. Cheap enough to ask on every change, and the way
  /// the scope knows whether anything that would change the feeling registry has happened.
  int countOf(String type) {
    var n = 0;
    for (final e in _ordered) {
      if (e.type == type) n++;
    }
    for (final e in _pending) {
      if (e.type == type) n++;
    }
    return n;
  }

  /// Ids the host refused, with the reason. Read by the thread to mark the row.
  Map<String, String> get refused => Map.unmodifiable(_refused);

  Set<String> get inFlight => Set.unmodifiable(_inFlight);

  /// The sync engine says which of the outbox it is pushing right now.
  void markInFlight(Iterable<String> ids, {bool on = true}) {
    if (on) {
      _inFlight.addAll(ids);
    } else {
      _inFlight.removeAll(ids);
    }
    _changes.add(const SpineChange(added: [], assigned: []));
  }

  /// Records a refusal. The event stays in the outbox.
  void markRefused(String id, String why) {
    _refused[id] = why;
    _changes.add(const SpineChange(added: [], assigned: []));
  }

  /// Events minted here that the host has not accepted yet (the outbox).
  List<Event> get pending => List.unmodifiable(_pending);

  /// Accepted events followed by pending ones: what the thread shows.
  List<Event> get all => [..._ordered, ..._pending];

  int get length => _ordered.length + _pending.length;

  /// The cursor for pulling from the host: the highest seq such that every seq up to it is held.
  /// A pushed event that comes back with a later seq never moves this past a gap, so nothing the
  /// host wrote in between is ever skipped.
  int get cursor => _cursor;

  /// Highest seq held (the host's next assignment is one more than this).
  int get maxSeq => _maxSeq;

  void _noteSeq(int seq) {
    _seqs.add(seq);
    if (seq > _maxSeq) _maxSeq = seq;
    while (_seqs.contains(_cursor + 1)) {
      _cursor++;
    }
  }

  Event? byId(String id) => _byId[id];

  /// Events with seq strictly greater than [after], in order, at most [limit].
  List<Event> after(int after, {int limit = 500}) {
    final out = <Event>[];
    // binary search the first seq > after
    var lo = 0, hi = _ordered.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_ordered[mid].seq! <= after) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    for (var i = lo; i < _ordered.length && out.length < limit; i++) {
      out.add(_ordered[i]);
    }
    return out;
  }

  /// Mints an event here. It is persisted before anything else happens (it survives a restart),
  /// and sits in the outbox until the host assigns its seq. A host device assigns immediately.
  Future<Event> append(String type, Map<String, dynamic> payload, {DateTime? at, bool hostAssign = false}) async {
    final spec = specOf(type);
    final problem = spec.validate(payload);
    if (problem != null) throw ArgumentError(problem);
    final refs = <String>[];
    for (final k in spec.refKeys) {
      final v = payload[k];
      if (v is String) refs.add(v);
    }
    final blobs = <String>[];
    for (final k in spec.blobKeys) {
      final v = payload[k];
      if (v is String) blobs.add(v);
    }
    final now = at ?? DateTime.now().toUtc();
    var e = Event(
      id: _ulids.next(now),
      seq: hostAssign ? _maxSeq + 1 : null,
      author: identity.person,
      device: identity.device,
      ts: now.millisecondsSinceEpoch,
      type: type,
      payload: payload,
      refs: refs,
      blobs: blobs,
    );
    await _store.upsertAll([e]);
    _byId[e.id] = e;
    if (e.seq != null) {
      _ordered.add(e);
      _noteSeq(e.seq!);
    } else {
      _pending.add(e);
    }
    _search.add(e);
    _changes.add(SpineChange(added: [e], assigned: const []));
    return e;
  }

  /// Host side: accepts events from the client, assigning the next seq to each new one.
  /// Duplicates (already known ids) are returned with their existing seq and not re-added.
  Future<List<Event>> accept(Iterable<Event> incoming) async {
    final out = <Event>[];
    final added = <Event>[];
    for (final e in incoming) {
      final known = _byId[e.id];
      if (known != null) {
        out.add(known);
        continue;
      }
      final problem = specOf(e.type).validate(e.payload);
      if (problem != null) continue; // the host never stores an invalid event
      final assigned = e.withSeq(_maxSeq + 1);
      _ordered.add(assigned);
      _noteSeq(assigned.seq!);
      _byId[assigned.id] = assigned;
      _search.add(assigned);
      added.add(assigned);
      out.add(assigned);
    }
    if (added.isNotEmpty) {
      await _store.upsertAll(added);
      _changes.add(SpineChange(added: added, assigned: const []));
    }
    return out;
  }

  /// Client side: applies events pulled from the host (in seq order). Pending events that come
  /// back with a seq leave the outbox; unknown events are added; the cursor advances.
  Future<void> applyFromHost(Iterable<Event> incoming) async {
    final added = <Event>[];
    final assigned = <Event>[];
    for (final e in incoming) {
      if (e.seq == null) continue;
      final known = _byId[e.id];
      if (known != null) {
        if (known.seq == null) {
          _pending.removeWhere((p) => p.id == e.id);
          _insertOrdered(e);
          _byId[e.id] = e;
          assigned.add(e);
        }
        continue;
      }
      _insertOrdered(e);
      _byId[e.id] = e;
      _search.add(e);
      added.add(e);
    }
    if (added.isNotEmpty || assigned.isNotEmpty) {
      await _store.upsertAll([...added, ...assigned]);
      _changes.add(SpineChange(added: added, assigned: assigned));
    }
  }

  void _insertOrdered(Event e) {
    if (_ordered.isEmpty || _ordered.last.seq! < e.seq!) {
      _ordered.add(e);
    } else {
      var lo = 0, hi = _ordered.length;
      while (lo < hi) {
        final mid = (lo + hi) >> 1;
        if (_ordered[mid].seq! < e.seq!) {
          lo = mid + 1;
        } else {
          hi = mid;
        }
      }
      _ordered.insert(lo, e);
    }
    _noteSeq(e.seq!);
  }

  /// Seed import: events already carrying ids and seqs, identical on both devices. Only valid on
  /// an empty spine; the seed loader guards with a meta key.
  Future<void> importSeed(List<Event> events) async {
    if (_ordered.isNotEmpty) throw StateError('seed import needs an empty spine');
    await _store.upsertAll(events);
    for (final e in events) {
      _byId[e.id] = e;
      _ordered.add(e);
      _noteSeq(e.seq!);
      _search.add(e);
    }
    _changes.add(SpineChange(added: events, assigned: const []));
  }

  // ---- search ----------------------------------------------------------------------------
  List<SearchHit> search(String query, {Set<String>? types, Person? author, int? fromTs, int? toTs, int limit = 200}) =>
      _search.search(query, types: types, author: author, fromTs: fromTs, toTs: toTs, limit: limit);

  // ---- blobs -----------------------------------------------------------------------------
  static String hashOf(Uint8List bytes) => sha256.convert(bytes).toString();

  Future<String> putBlob(Uint8List bytes, String mime) async {
    final h = hashOf(bytes);
    if (!await _store.hasBlob(h)) await _store.putBlob(h, mime, bytes);
    return h;
  }

  Future<void> putBlobWithHash(String hash, Uint8List bytes, String mime) async {
    if (hashOf(bytes) != hash) throw ArgumentError('blob hash mismatch');
    if (!await _store.hasBlob(hash)) await _store.putBlob(hash, mime, bytes);
  }

  Future<StoredBlob?> blob(String hash) => _store.getBlob(hash);
  Future<bool> hasBlob(String hash) => _store.hasBlob(hash);
  Future<List<String>> blobHashes() => _store.blobHashes();

  /// Blob hashes referenced by events that this device does not hold yet.
  Future<List<String>> missingBlobs() async {
    final have = (await _store.blobHashes()).toSet();
    final missing = <String>{};
    for (final e in all) {
      for (final b in e.blobs) {
        if (!have.contains(b)) missing.add(b);
      }
    }
    return missing.toList();
  }

  // ---- meta ------------------------------------------------------------------------------
  Future<String?> meta(String key) => _store.getMeta(key);
  Future<void> setMeta(String key, String? value) => _store.setMeta(key, value);

  /// A dump of the whole log for the cold-start proof: ids in order.
  String dumpIds() => jsonEncode(all.map((e) => {'id': e.id, 'seq': e.seq, 'type': e.type}).toList());

  Future<void> wipe() async {
    await _store.wipe();
    await _replay();
  }

  Future<void> close() async {
    await _changes.close();
    await _store.close();
  }
}
