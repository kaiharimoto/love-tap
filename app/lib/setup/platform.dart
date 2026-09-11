// The two facts about the phone itself that the setup list watches for.
//
// Both are asked of the platform each time the list is drawn, never stored: a step that stayed
// ticked after its permission was taken away would be a lie on the only screen whose whole job is
// to be true.
import 'platform_stub.dart' if (dart.library.js_interop) 'platform_web.dart' as impl;

class PhoneFacts {
  const PhoneFacts({
    required this.notificationsAllowed,
    required this.installedToHome,
    this.secureOrigin = false,
  });
  final bool notificationsAllowed;

  /// PWA only: `window.isSecureContext`. Safari will not hand the page the certificate it
  /// validated, so this is the one thing the browser will say about its own origin — and it is
  /// the thing that matters, because it is exactly what gates `navigator.serviceWorker`. Without
  /// it the iPhone cannot register the worker that receives a push and the third ambient surface
  /// does not exist. On Android this stays false and the certificate itself is read instead.
  final bool secureOrigin;

  /// PWA only: running from the Home Screen rather than in a browser tab. Always true on Android,
  /// where the app is the app.
  final bool installedToHome;

  static Future<PhoneFacts> read() => impl.read();
}
