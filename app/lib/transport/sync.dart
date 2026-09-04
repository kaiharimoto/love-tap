// The sync engine: drains the outbox, pulls by cursor, fetches missing blobs, backs off when the
// host is away, and never duplicates. The client runs it against the host; the host runs a thin
// variant that only keeps its status and fetches nothing (the server serves its spine directly).
import 'dart:async';
import 'dart:math';

import '../spine/spine.dart';
import 'transport.dart';

class SyncEngine {
  SyncEngine({required this.spine, required this.transport, this.onLog});

  final Spine spine;
  final Transport transport;
  final void Function(String line)? onLog;

  bool _running = false;
  Completer<void> _kick = Completer<void>();
  Duration _backoff = const Duration(milliseconds: 500);
  int _rounds = 0;
  int _pushed = 0;
  int _refused = 0;
  int _pulled = 0;
  int _blobsFetched = 0;
  StreamSubscription<SpineChange>? _sub;
  Future<void>? _loop;

  bool get running => _running;
  int get rounds => _rounds;
  int get pushed => _pushed;
  int get refused => _refused;
  int get pulled => _pulled;

  void _log(String s) => onLog?.call('[sync ${transport.name} ${transport.role.name}] $s');

  Future<void> start() async {
    if (_running) return;
    _running = true;
    if (transport.role == TransportRole.client) {
      _sub = spine.changes.listen((c) {
        if (c.added.any((e) => e.isPending)) kick();
      });
      _loop = _run();
    }
  }

  /// Wake the loop now (a new local event, the app came to the foreground, faults went away).
  void kick() {
    if (!_kick.isCompleted) _kick.complete();
  }

  Future<void> stop() async {
    _running = false;
    kick();
    await _sub?.cancel();
    await _loop;
  }

  /// One full exchange: push everything pending, then pull everything new. Returns true when
  /// the host answered. Safe to call by hand (tests, run.sh).
  Future<bool> once({Duration wait = Duration.zero}) async {
    if (transport.pairing == null) return false;
    try {
      await _drainOutbox();
      final res = await transport.pull(spine.cursor, wait: wait);
      if (res.events.isNotEmpty) {
        await spine.applyFromHost(res.events);
        _pulled += res.events.length;
      }
      await _fetchMissingBlobs();
      _backoff = const Duration(milliseconds: 500);
      _rounds++;
      return true;
    } on TransportException catch (e) {
      _log('${e.offline ? 'offline' : 'error'}: ${e.message}');
      return false;
    }
  }

  Future<void> _drainOutbox() async {
    while (spine.pending.isNotEmpty) {
      final batch = spine.pending.take(100).toList();
      // blobs first, so the host never sees an event whose media it cannot serve
      for (final e in batch) {
        for (final h in e.blobs) {
          if (!await transport.hasBlob(h)) {
            final b = await spine.blob(h);
            if (b != null) await transport.putBlob(h, b.mime, b.bytes);
          }
        }
      }
      spine.markInFlight([for (final e in batch) e.id]);
      final List<Accepted> accepted;
      try {
        accepted = await transport.push(batch);
      } finally {
        spine.markInFlight([for (final e in batch) e.id], on: false);
      }
      final byId = {for (final e in batch) e.id: e};
      final assigned = <Event>[];
      for (final a in accepted) {
        final e = byId[a.id];
        if (e == null) continue;
        if (a.accepted) {
          assigned.add(e.withSeq(a.seq));
        } else {
          // The host will not take this one. It stays in the outbox, marked, where the person
          // who wrote it can see that it did not go — rather than sitting there looking sent.
          spine.markRefused(a.id, a.refused!);
          _refused++;
        }
      }
      if (assigned.isEmpty) break;
      await spine.applyFromHost(assigned);
      _pushed += assigned.length;
    }
  }

  Future<void> _fetchMissingBlobs() async {
    for (final h in await spine.missingBlobs()) {
      final b = await transport.getBlob(h);
      if (b != null) {
        await spine.putBlobWithHash(h, b.bytes, b.mime);
        _blobsFetched++;
      }
    }
  }

  Future<void> _run() async {
    while (_running) {
      final ok = await once(wait: const Duration(seconds: 20));
      if (!_running) break;
      if (ok) {
        // long-poll returned; go straight round again unless nothing is paired
        if (transport.pairing == null) await _sleep(const Duration(seconds: 2));
        continue;
      }
      await _sleep(_backoff);
      _backoff = Duration(milliseconds: min(_backoff.inMilliseconds * 2, 30000));
    }
  }

  Future<void> _sleep(Duration d) async {
    _kick = Completer<void>();
    await _kick.future.timeout(d, onTimeout: () {});
  }

  Map<String, dynamic> report() => {
        'transport': transport.name,
        'role': transport.role.name,
        'rounds': _rounds,
        'pushed': _pushed,
        'refused': _refused,
        'pulled': _pulled,
        'blobs_fetched': _blobsFetched,
        'pending': spine.pending.length,
        'cursor': spine.cursor,
        'link': transport.current.toJson(),
      };
}
