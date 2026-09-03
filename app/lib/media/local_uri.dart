// A playable URI for blob bytes: a temp file on Android, an object URL on the web.
import 'dart:typed_data';

import 'local_uri_stub.dart' if (dart.library.io) 'local_uri_io.dart' if (dart.library.js_interop) 'local_uri_web.dart' as impl;

/// Returns a URI a player can open, caching by hash for the life of the process.
Future<Uri> localUriFor(String hash, Uint8List bytes, String mime) => impl.localUriFor(hash, bytes, mime);

bool get isWebPlatform => impl.isWeb;
