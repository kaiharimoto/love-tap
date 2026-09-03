// The persistence boundary. This directory is the only place in the app that touches a storage
// driver (sqlite3 on Android, IndexedDB on the web). Everything above it sees only SpineStore.
import 'dart:typed_data';

import '../event.dart';

import 'store_stub.dart'
    if (dart.library.io) 'store_native.dart'
    if (dart.library.js_interop) 'store_web.dart' as impl;

/// A stored blob: bytes addressed by their sha256.
class StoredBlob {
  const StoredBlob({required this.hash, required this.mime, required this.length, required this.bytes});
  final String hash;
  final String mime;
  final int length;
  final Uint8List bytes;
}

abstract class SpineStore {
  /// Opens (or creates) the store for one device profile. `profile` separates two instances on one
  /// machine (the two-container proof) and the seeded build from the empty one.
  static Future<SpineStore> open(String profile) => impl.openStore(profile);

  /// In-memory store for tests and for the seed loader's dry run.
  static SpineStore memory() => MemoryStore();

  /// Every event, in seq order, pending (seq == null) last in insertion order.
  Future<List<Event>> loadAll();

  /// Inserts or replaces events by id. Replacing is how a pending event gains its seq.
  Future<void> upsertAll(Iterable<Event> events);

  Future<String?> getMeta(String key);
  Future<void> setMeta(String key, String? value);

  Future<void> putBlob(String hash, String mime, Uint8List bytes);
  Future<StoredBlob?> getBlob(String hash);
  Future<bool> hasBlob(String hash);
  Future<List<String>> blobHashes();

  /// Removes everything. Used by "start again" in Settings and by tests.
  Future<void> wipe();

  Future<void> close();
}

/// Test store. Keeps everything in maps; nothing survives the process.
class MemoryStore implements SpineStore {
  final Map<String, Event> _events = {};
  final List<String> _order = [];
  final Map<String, String> _meta = {};
  final Map<String, StoredBlob> _blobs = {};

  @override
  Future<List<Event>> loadAll() async => sortStored(_order.map((id) => _events[id]!));

  @override
  Future<void> upsertAll(Iterable<Event> events) async {
    for (final e in events) {
      if (!_events.containsKey(e.id)) _order.add(e.id);
      _events[e.id] = e;
    }
  }

  @override
  Future<String?> getMeta(String key) async => _meta[key];

  @override
  Future<void> setMeta(String key, String? value) async {
    if (value == null) {
      _meta.remove(key);
    } else {
      _meta[key] = value;
    }
  }

  @override
  Future<void> putBlob(String hash, String mime, Uint8List bytes) async {
    _blobs[hash] = StoredBlob(hash: hash, mime: mime, length: bytes.length, bytes: bytes);
  }

  @override
  Future<StoredBlob?> getBlob(String hash) async => _blobs[hash];

  @override
  Future<bool> hasBlob(String hash) async => _blobs.containsKey(hash);

  @override
  Future<List<String>> blobHashes() async => _blobs.keys.toList();

  @override
  Future<void> wipe() async {
    _events.clear();
    _order.clear();
    _meta.clear();
    _blobs.clear();
  }

  @override
  Future<void> close() async {}
}

/// Seq order first, then pending events in the order they were stored.
List<Event> sortStored(Iterable<Event> events) {
  final withSeq = <Event>[];
  final pending = <Event>[];
  for (final e in events) {
    (e.seq == null ? pending : withSeq).add(e);
  }
  withSeq.sort((a, b) => a.seq!.compareTo(b.seq!));
  return [...withSeq, ...pending];
}
