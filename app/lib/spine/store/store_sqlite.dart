// The store itself: sqlite3, and the only file in the app that imports it.
//
// Deliberately separate from where the file goes. Choosing a directory on a phone means asking
// the platform, which means path_provider, which is a Flutter plugin and drags in dart:ui — so a
// plain Dart process (the headless host in tool/host_daemon.dart, which stands in for the far
// phone in the capture clips) could not open a spine at all while the two lived in one file. The
// store does not care where its file is; only the app does.
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';

import '../event.dart';
import 'store.dart';

class NativeStore implements SpineStore {
  NativeStore._(this._db);

  final Database _db;

  static NativeStore openAt(String path) {
    final db = sqlite3.open(path);
    db.execute('PRAGMA journal_mode=WAL');
    db.execute('PRAGMA synchronous=FULL');
    db.execute('''
      CREATE TABLE IF NOT EXISTS events (
        id TEXT PRIMARY KEY,
        seq INTEGER UNIQUE,
        stored_order INTEGER NOT NULL,
        json TEXT NOT NULL
      )''');
    db.execute('CREATE INDEX IF NOT EXISTS events_seq ON events(seq)');
    db.execute('CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT)');
    db.execute('''
      CREATE TABLE IF NOT EXISTS blobs (
        hash TEXT PRIMARY KEY,
        mime TEXT NOT NULL,
        length INTEGER NOT NULL,
        data BLOB NOT NULL
      )''');
    return NativeStore._(db);
  }

  @override
  Future<List<Event>> loadAll() async {
    final rows = _db.select('SELECT json FROM events ORDER BY stored_order');
    return sortStored(rows.map((r) => Event.decode(r['json'] as String)));
  }

  @override
  Future<void> upsertAll(Iterable<Event> events) async {
    final next = (_db.select('SELECT COALESCE(MAX(stored_order), 0) AS m FROM events').first['m'] as int) + 1;
    final stmt = _db.prepare('''
      INSERT INTO events (id, seq, stored_order, json) VALUES (?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET seq = excluded.seq, json = excluded.json''');
    _db.execute('BEGIN');
    try {
      var order = next;
      for (final e in events) {
        stmt.execute([e.id, e.seq, order++, e.encode()]);
      }
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    } finally {
      stmt.dispose();
    }
  }

  @override
  Future<String?> getMeta(String key) async {
    final rows = _db.select('SELECT value FROM meta WHERE key = ?', [key]);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  @override
  Future<void> setMeta(String key, String? value) async {
    if (value == null) {
      _db.execute('DELETE FROM meta WHERE key = ?', [key]);
    } else {
      _db.execute('INSERT INTO meta (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value',
          [key, value]);
    }
  }

  @override
  Future<void> putBlob(String hash, String mime, Uint8List bytes) async {
    _db.execute('INSERT OR REPLACE INTO blobs (hash, mime, length, data) VALUES (?, ?, ?, ?)',
        [hash, mime, bytes.length, bytes]);
  }

  @override
  Future<StoredBlob?> getBlob(String hash) async {
    final rows = _db.select('SELECT mime, length, data FROM blobs WHERE hash = ?', [hash]);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return StoredBlob(hash: hash, mime: r['mime'] as String, length: r['length'] as int, bytes: r['data'] as Uint8List);
  }

  @override
  Future<bool> hasBlob(String hash) async =>
      _db.select('SELECT 1 FROM blobs WHERE hash = ?', [hash]).isNotEmpty;

  @override
  Future<List<String>> blobHashes() async =>
      _db.select('SELECT hash FROM blobs').map((r) => r['hash'] as String).toList();

  @override
  Future<void> wipe() async {
    _db.execute('DELETE FROM events');
    _db.execute('DELETE FROM meta');
    _db.execute('DELETE FROM blobs');
  }

  @override
  Future<void> close() async => _db.dispose();
}
