// Loads the seeded year (seed/year/*.jsonl, copied into the bundle by run.sh only for a
// --seed=year build) into an empty spine, deterministically: the same file gives the same ids
// and the same seqs on both devices, so the two logs are identical before the first sync.
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' show AssetBundle;

import 'spine.dart';
import 'ulid.dart';

class SeedReport {
  SeedReport({required this.events, required this.blobs, required this.skipped, required this.anchors});
  final int events;
  final int blobs;
  final List<String> skipped;
  final Map<String, String> anchors; // anchor id -> event id
}

class SeedLoader {
  SeedLoader(this.bundle, {this.prefix = 'assets/seed'});

  final AssetBundle bundle;
  final String prefix;

  static const metaKey = 'seed.loaded';

  Future<bool> alreadyLoaded(Spine spine) async => (await spine.meta(metaKey)) != null;

  /// Loads every month listed in assets/seed/index.json. Idempotent: does nothing when loaded.
  Future<SeedReport?> load(Spine spine) async {
    if (await alreadyLoaded(spine)) return null;
    final index = jsonDecode(await bundle.loadString('$prefix/index.json')) as Map<String, dynamic>;
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
    final out = <Event>[];
    final skipped = <String>[];
    final anchors = <String, String>{};
    var blobs = 0;
    var seq = 0;
    for (final month in months) {
      final text = await bundle.loadString('$prefix/year/$month.jsonl');
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

  Future<Uint8List> _bytes(String path) async => (await bundle.load(path)).buffer.asUint8List();

  Future<dynamic> _optionalJson(String path) async {
    try {
      return jsonDecode(await bundle.loadString(path));
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
