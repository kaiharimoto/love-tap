import 'dart:js_interop';

import 'platform.dart';

@JS('Notification.permission')
external JSString? get _permission;

@JS('window.matchMedia')
external JSObject? _matchMedia(JSString query);

@JS('window.isSecureContext')
external JSBoolean? get _secure;

extension type _MediaQueryList(JSObject o) implements JSObject {
  external JSBoolean get matches;
}

Future<PhoneFacts> read() async {
  var granted = false;
  try {
    granted = _permission?.toDart == 'granted';
  } catch (_) {}
  var standalone = false;
  try {
    // iOS puts a PWA in standalone display mode once it has been added to the home screen; that
    // is also the moment its storage stops being evicted, which is why the list waits for it.
    final m = _matchMedia('(display-mode: standalone)'.toJS);
    standalone = m != null && _MediaQueryList(m).matches.toDart;
  } catch (_) {}
  var secure = false;
  try {
    // What the browser will say about the origin, which is also precisely what turns on the
    // service worker. A page at http://100.x.y.z is not a secure context and Safari gives it no
    // `navigator.serviceWorker` at all, so the push surface cannot exist — the host serving over
    // TLS is what makes this true, and the list reads it rather than assuming it.
    secure = _secure?.toDart ?? false;
  } catch (_) {}
  return PhoneFacts(
      notificationsAllowed: granted, installedToHome: standalone, secureOrigin: secure);
}
