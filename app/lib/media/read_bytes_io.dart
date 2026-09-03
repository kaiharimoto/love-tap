import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<Uint8List?> readBytesAt(String pathOrUrl) async {
  final f = File(pathOrUrl);
  if (!await f.exists()) return null;
  final bytes = await f.readAsBytes();
  try {
    await f.delete();
  } catch (_) {}
  return bytes;
}

Future<String> recordingPath() async {
  final dir = await getTemporaryDirectory();
  return p.join(dir.path, 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a');
}
