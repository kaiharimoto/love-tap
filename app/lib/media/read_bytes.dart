// Reading a recording back and choosing where to record, per platform.
import 'dart:typed_data';

import 'read_bytes_stub.dart' if (dart.library.io) 'read_bytes_io.dart' if (dart.library.js_interop) 'read_bytes_web.dart' as impl;

Future<Uint8List?> readBytesAt(String pathOrUrl) => impl.readBytesAt(pathOrUrl);

Future<String> recordingPath() => impl.recordingPath();
