// The PWA: IndexedDB through idb_shim. The only file in the app that imports an IndexedDB driver.
import 'dart:typed_data';

import 'package:idb_shim/idb_browser.dart' hide Event;

import '../event.dart';
import 'store.dart';

Future<SpineStore> openStore(String profile) async {
  final factory = idbFactoryBrowser;
  final db = await factory.open('spine_$profile', version: 1, onUpgradeNeeded: (VersionChangeEvent e) {
    final db = e.database;
    final events = db.createObjectStore('events', keyPath: 'id');
    events.createIndex('stored_order', 'stored_order', unique: true);
    db.createObjectStore('meta');
    db.createObjectStore('blobs', keyPath: 'hash');
  });
  return WebStore._(db);
}

class WebStore implements SpineStore {
  WebStore._(this._db);

  final Database _db;
  int? _nextOrder;

  @override
  Future<List<Event>> loadAll() async {
    final txn = _db.transaction('events', idbModeReadOnly);
    final rows = await txn.objectStore('events').getAll();
    await txn.completed;
    final list = rows.map((r) => (r as Map).cast<String, dynamic>()).toList()
      ..sort((a, b) => (a['stored_order'] as int).compareTo(b['stored_order'] as int));
    return sortStored(list.map((r) => Event.decode(r['json'] as String)));
  }

  /// The next stored_order. Read once, from the count and the top of the stored_order index —
  /// this used to getAll() every row inside the write transaction, fourteen thousand of them on a
  /// phone that already had the year, before it wrote the first new one.
  Future<int> _order(Transaction txn) async {
    if (_nextOrder != null) return _nextOrder!;
    final store = txn.objectStore('events');
    final count = await store.count();
    if (count == 0) {
      _nextOrder = 1;
      return 1;
    }
    var max = 0;
    await for (final c in store.index('stored_order').openCursor(direction: 'prev', autoAdvance: false)) {
      max = c.key as int;
      break;
    }
    _nextOrder = max + 1;
    return _nextOrder!;
  }

  @override
  Future<void> upsertAll(Iterable<Event> events) async {
    final txn = _db.transaction('events', idbModeReadWrite);
    final store = txn.objectStore('events');
    var order = await _order(txn);
    // Into an empty store nothing can already exist, so nothing is looked up first: the year's
    // import was one get and one put per event, and the get was half the cold start.
    final empty = order == 1;
    for (final e in events) {
      final existing = empty ? null : await store.getObject(e.id);
      final storedOrder = existing == null ? order++ : (existing as Map)['stored_order'] as int;
      await store.put({'id': e.id, 'seq': e.seq, 'stored_order': storedOrder, 'json': e.encode()});
    }
    _nextOrder = order;
    await txn.completed;
  }

  @override
  Future<String?> getMeta(String key) async {
    final txn = _db.transaction('meta', idbModeReadOnly);
    final v = await txn.objectStore('meta').getObject(key);
    await txn.completed;
    return v as String?;
  }

  @override
  Future<void> setMeta(String key, String? value) async {
    final txn = _db.transaction('meta', idbModeReadWrite);
    if (value == null) {
      await txn.objectStore('meta').delete(key);
    } else {
      await txn.objectStore('meta').put(value, key);
    }
    await txn.completed;
  }

  @override
  Future<void> putBlob(String hash, String mime, Uint8List bytes) async {
    final txn = _db.transaction('blobs', idbModeReadWrite);
    await txn.objectStore('blobs').put({'hash': hash, 'mime': mime, 'length': bytes.length, 'data': bytes});
    await txn.completed;
  }

  @override
  Future<StoredBlob?> getBlob(String hash) async {
    final txn = _db.transaction('blobs', idbModeReadOnly);
    final r = await txn.objectStore('blobs').getObject(hash);
    await txn.completed;
    if (r == null) return null;
    final m = (r as Map).cast<String, dynamic>();
    final data = m['data'];
    final bytes = data is Uint8List ? data : Uint8List.fromList((data as List).cast<int>());
    return StoredBlob(hash: hash, mime: m['mime'] as String, length: m['length'] as int, bytes: bytes);
  }

  @override
  Future<bool> hasBlob(String hash) async => (await getBlob(hash)) != null;

  @override
  Future<List<String>> blobHashes() async {
    final txn = _db.transaction('blobs', idbModeReadOnly);
    final keys = await txn.objectStore('blobs').getAllKeys();
    await txn.completed;
    return keys.cast<String>().toList();
  }

  @override
  Future<void> wipe() async {
    final txn = _db.transaction(['events', 'meta', 'blobs'], idbModeReadWrite);
    await txn.objectStore('events').clear();
    await txn.objectStore('meta').clear();
    await txn.objectStore('blobs').clear();
    await txn.completed;
    _nextOrder = 1;
  }

  @override
  Future<void> close() async => _db.close();
}
