// The web app, read out of the phone that serves it.
//
// The iPhone installs the client by opening the Android phone's address in Safari, so the Android
// phone has to have the page to give it. `pwaRoot` — a directory on disk — was only ever passed by
// the capture's far phone, which runs under `dart run` with the built bundle beside it; the app
// itself passed nothing, so `_serveStatic` answered 404 to every GET and there was nothing at
// https://100.x.y.z:8443 to add to a home screen.
//
// A phone holds the bundle in two halves, because it already has most of it:
//
//   assets/assets/**   the material library — paper, tears, objects, folds, the seeded year.
//                      Eighty-three megabytes, and the same bytes the app draws itself with, so
//                      they are served out of this build's own `rootBundle` and packed once.
//   everything else    index.html, the engine, canvaskit, the icons, the service worker. Forty
//                      megabytes, packed into Android's own assets by tools/pack_pwa.py and read
//                      back over `lovetap/pwa`.
//
// The second half is in Android's assets rather than Flutter's because `app/assets/` is bundled
// into `flutter build web` too: a copy of the web build kept there would be packed inside the next
// web build, and inside the one after that.
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart'
    show MethodChannel, MissingPluginException, PlatformException, rootBundle;

const MethodChannel _channel = MethodChannel('lovetap/pwa');

/// What the phone's own asset bundle holds under the web bundle's `assets/` prefix.
const String _sharedPrefix = 'assets/assets/';

/// Resolves one request path to bytes, or null when this build does not carry that file.
///
/// Nothing here caches. `PlatformAssetBundle.load` does not either — `CachingAssetBundle` caches
/// strings and structured data, not bytes — which is what makes serving eighty-three megabytes a
/// file at a time out of `rootBundle` safe on a phone.
Future<Uint8List?> pwaFile(String urlPath) async {
  final path = pwaPathFor(urlPath);
  if (path == null) return null;
  final bytes = await _read(path);
  if (bytes != null) return bytes;
  // A page opened at /settings is the app's own route, not a file. The bundle answers for it the
  // way any single-page app is served: with the page.
  if (path != 'index.html' && !path.contains('.')) return _read('index.html');
  return null;
}

/// Whether this build carries a web app to hand over at all.
///
/// The setup list asks before it tells anyone to open an address in Safari: a host with no bundle
/// in it is a host with nothing on the other end of that instruction, and saying so is better than
/// letting the iPhone find a 404.
Future<bool> pwaInThisBuild() async {
  if (kIsWeb) return false;
  try {
    return await _channel.invokeMethod<bool>('present') ?? false;
  } on MissingPluginException {
    return false;
  } on PlatformException {
    return false;
  }
}

Future<Uint8List?> _read(String path) async {
  final shared = sharedAssetFor(path);
  if (shared != null) {
    try {
      final data = await rootBundle.load(shared);
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } catch (_) {
      return null;
    }
  }
  if (kIsWeb) return null;
  try {
    return await _channel.invokeMethod<Uint8List>('read', {'path': path});
  } on MissingPluginException {
    return null;
  } on PlatformException {
    return null;
  }
}

/// The path this build's own `assets/` holds the file at, or null when it does not hold it.
///
/// `assets/assets/paper/x.webp` in the web bundle is `assets/paper/x.webp` in this one. Pure, and
/// tested, because it is the join between two asset layouts and a wrong answer here is a blank
/// screen on the other phone rather than an error anywhere.
String? sharedAssetFor(String path) =>
    path.startsWith(_sharedPrefix) ? path.substring('assets/'.length) : null;

/// A request path as a bundle key, or null if it is trying to leave the bundle.
String? pwaPathFor(String urlPath) {
  var path = Uri.decodeComponent(urlPath);
  while (path.startsWith('/')) {
    path = path.substring(1);
  }
  if (path.isEmpty || path.endsWith('/')) path = '${path}index.html';
  if (path.contains('\\')) return null;
  for (final part in path.split('/')) {
    if (part == '..' || part == '.' || part.isEmpty) return null;
  }
  return path;
}
