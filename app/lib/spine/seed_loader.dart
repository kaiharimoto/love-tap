// Loads the seeded year (seed/year/*.jsonl, copied into the bundle by run.sh only for a
// --seed=year build) into an empty spine, deterministically: the same file gives the same ids
// and the same seqs on both devices, so the two logs are identical before the first sync.
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../boot.dart';
import 'spine.dart';

/// Where the seed's files come from. The app reads them out of its asset bundle; the headless far
/// phone (app/tool/host_daemon.dart) reads the same files off disk, so the two phones in a
/// capture carry the same year — same ids, same seqs — before either has spoken to the other.
/// Kept free of Flutter so a plain Dart program can hold one.
abstract class SeedSource {
  Future<String> loadString(String path);
  Future<Uint8List> loadBytes(String path);
}

class SeedReport {
  SeedReport({required this.events, required this.blobs, required this.skipped, required this.anchors});
  final int events;
  final int blobs;
  final List<String> skipped;
  final Map<String, String> anchors; // anchor id -> event id
}

class SeedLoader {
  SeedLoader(this.source, {this.prefix = 'assets/seed'});

  final SeedSource source;
  final String prefix;

  static const metaKey = 'seed.loaded';

  Future<bool> alreadyLoaded(Spine spine) async => (await spine.meta(metaKey)) != null;

  /// Loads every month listed in assets/seed/index.json. Idempotent: does nothing when loaded.
  Future<SeedReport?> load(Spine spine) async {
    if (await alreadyLoaded(spine)) return null;
    final index = jsonDecode(await source.loadString('$prefix/index.json')) as Map<String, dynamic>;
    final months = (index['months'] as List).cast<String>();
    final voiceIndex = await _optionalJson('$prefix/voice/index.json');
    final waveforms = <String, List<double>>{};
    if (voiceIndex is Map) {
      for (final e in voiceIndex.entries) {
        final w = (e.value as Map)['waveform'];
        if (w is List) waveforms[e.key as String] = w.map((x) => (x as num).toDouble()).toList();
      }
    } else if (voiceIndex is List) {
      for (final e in voiceIndex) {
        final w = (e as Map)['waveform'];
        if (w is List) waveforms[e['id'] as String] = w.map((x) => (x as num).toDouble()).toList();
      }
    }
    final keyToId = <String, String>{};
    // a read marker points at a place in the log, and the seed cannot know the seq it will get
    // until the log has been laid down, so the seed names the line and this resolves it
    final keyToSeq = <String, int>{};
    final out = <Event>[];
    final skipped = <String>[];
    final anchors = <String, String>{};
    var blobs = 0;
    var seq = 0;
    var monthsIn = 0;
    bootProgress(0, months.length);
    for (final month in months) {
      final text = await source.loadString('$prefix/year/$month.jsonl');
      for (final raw in const LineSplitter().convert(text)) {
        if (raw.trim().isEmpty) continue;
        final j = jsonDecode(raw) as Map<String, dynamic>;
        final key = j['key'] as String;
        final ts = DateTime.parse(j['ts'] as String).toUtc();
        final author = Person.parse(j['author'] as String);
        final type = j['type'] as String;
        final spec = kEventTypeById[type];
        if (spec == null) {
          skipped.add('$key: unknown type $type');
          continue;
        }
        final src = (j['payload'] as Map).cast<String, dynamic>();
        final payload = <String, dynamic>{};
        var bad = false;
        for (final entry in src.entries) {
          var v = entry.value;
          if (v is String && v.startsWith('k:')) {
            final id = keyToId[v.substring(2)];
            if (id == null) {
              skipped.add('$key: unresolved ref $v');
              bad = true;
              break;
            }
            v = id;
          }
          payload[entry.key] = v;
        }
        if (bad) continue;
        if (type == 'read_marker') {
          final upto = payload.remove('upto_key');
          if (upto is String) {
            final at = keyToSeq[upto];
            if (at == null) {
              skipped.add('$key: unresolved read marker $upto');
              continue;
            }
            payload['upto_seq'] = at;
          }
        }
        // media: replace ids with blobs
        try {
          if (type == 'photo') {
            final id = payload.remove('photo') as String;
            final bytes = await _bytes('$prefix/photos/$id.jpg');
            final dims = _jpegSize(bytes) ?? (1200, 1600);
            payload['blob'] = await spine.putBlob(bytes, 'image/jpeg');
            payload['w'] = dims.$1;
            payload['h'] = dims.$2;
            blobs++;
          } else if (type == 'video') {
            final id = payload.remove('video') as String;
            final bytes = await _bytes('$prefix/videos/$id.mp4');
            final poster = await _bytes('$prefix/videos/$id.poster.jpg');
            final dims = _jpegSize(poster) ?? (1200, 1600);
            payload['blob'] = await spine.putBlob(bytes, 'video/mp4');
            payload['poster_blob'] = await spine.putBlob(poster, 'image/jpeg');
            payload['w'] = dims.$1;
            payload['h'] = dims.$2;
            blobs += 2;
          } else if (type == 'voice_note') {
            final id = payload.remove('voice') as String;
            final bytes = await _bytes('$prefix/voice/$id.ogg');
            payload['blob'] = await spine.putBlob(bytes, 'audio/ogg');
            payload['waveform'] = waveforms[id] ?? _flatWave();
            blobs++;
          }
        } catch (e) {
          skipped.add('$key: media missing ($e)');
          continue;
        }
        final problem = spec.validate(payload);
        if (problem != null) {
          skipped.add('$key: $problem');
          continue;
        }
        final refs = <String>[];
        for (final k in spec.refKeys) {
          final v = payload[k];
          if (v is String) refs.add(v);
        }
        final blobRefs = <String>[];
        for (final k in spec.blobKeys) {
          final v = payload[k];
          if (v is String) blobRefs.add(v);
        }
        final id = _ulidFor(key, ts);
        keyToId[key] = id;
        seq++;
        keyToSeq[key] = seq;
        final e = Event(
          id: id,
          seq: seq,
          author: author,
          device: author == Person.noor ? DeviceKind.android : DeviceKind.pwa,
          ts: ts.millisecondsSinceEpoch,
          type: type,
          payload: payload,
          refs: refs,
          blobs: blobRefs,
        );
        out.add(e);
        final anchor = j['anchor'];
        if (anchor is String) anchors[anchor] = id;
      }
      // The page put the desk out before any of this started and it is still what is on the
      // screen; this is how far in the reading has got. It is a count and not a bar: a number
      // that has not moved for four seconds is information, and a bar that has not moved is a
      // lie about how long is left.
      bootProgress(++monthsIn, months.length);
    }
    await spine.importSeed(out);
    await spine.setMeta(metaKey, 'year');
    await spine.setMeta('seed.anchors', jsonEncode(anchors));
    return SeedReport(events: out.length, blobs: blobs, skipped: skipped, anchors: anchors);
  }

  /// Deterministic ULID: time from ts, randomness from the key.
  static String _ulidFor(String key, DateTime ts) {
    final digest = sha256.convert(utf8.encode('seed:$key')).bytes;
    var x = 0;
    for (var i = 0; i < 4; i++) {
      x = (x << 8) | digest[i];
    }
    return UlidFactory(random: Random(x)).next(ts);
  }

  Future<Uint8List> _bytes(String path) => source.loadBytes(path);

  Future<dynamic> _optionalJson(String path) async {
    try {
      return jsonDecode(await source.loadString(path));
    } catch (_) {
      return null;
    }
  }

  static List<double> _flatWave() => List<double>.generate(48, (i) => 0.3 + 0.2 * ((i * 7) % 5) / 4);

  /// Width and height from JPEG SOF markers.
  static (int, int)? _jpegSize(Uint8List b) {
    if (b.length < 4 || b[0] != 0xFF || b[1] != 0xD8) return null;
    var i = 2;
    while (i + 9 < b.length) {
      if (b[i] != 0xFF) {
        i++;
        continue;
      }
      final marker = b[i + 1];
      if (marker >= 0xC0 && marker <= 0xCF && marker != 0xC4 && marker != 0xC8 && marker != 0xCC) {
        final h = (b[i + 5] << 8) | b[i + 6];
        final w = (b[i + 7] << 8) | b[i + 8];
        return (w, h);
      }
      final len = (b[i + 2] << 8) | b[i + 3];
      i += 2 + len;
    }
    return null;
  }
}
