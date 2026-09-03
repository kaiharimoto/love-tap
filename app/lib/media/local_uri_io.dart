import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

final Map<String, Uri> _cache = {};
const bool isWeb = false;

String _ext(String mime) => switch (mime) {
      'video/mp4' => 'mp4',
      'audio/ogg' => 'ogg',
      'audio/mp4' || 'audio/aac' || 'audio/m4a' => 'm4a',
      'audio/webm' => 'webm',
      'image/jpeg' => 'jpg',
      'image/png' => 'png',
      _ => 'bin',
    };

Future<Uri> localUriFor(String hash, Uint8List bytes, String mime) async {
  final cached = _cache[hash];
  if (cached != null) return cached;
  final dir = await getTemporaryDirectory();
  final f = File(p.join(dir.path, 'media', '$hash.${_ext(mime)}'));
  if (!await f.exists()) {
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes, flush: true);
  }
  return _cache[hash] = f.uri;
}
