import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// On the web the recorder returns a blob: URL.
Future<Uint8List?> readBytesAt(String pathOrUrl) async {
  try {
    final res = await http.get(Uri.parse(pathOrUrl));
    return res.bodyBytes;
  } catch (_) {
    return null;
  }
}

Future<String> recordingPath() async => '';
