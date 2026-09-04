// The two facts about the phone itself that the setup list watches for.
//
// Both are asked of the platform each time the list is drawn, never stored: a step that stayed
// ticked after its permission was taken away would be a lie on the only screen whose whole job is
// to be true.
import 'platform_stub.dart' if (dart.library.js_interop) 'platform_web.dart' as impl;

class PhoneFacts {
  const PhoneFacts({required this.notificationsAllowed, required this.installedToHome});
  final bool notificationsAllowed;

  /// PWA only: running from the Home Screen rather than in a browser tab. Always true on Android,
  /// where the app is the app.
  final bool installedToHome;

  static Future<PhoneFacts> read() => impl.read();
}
