import '../ambient/ambient.dart';
import 'platform.dart';

/// Android. Being installed is not a question here — the app is the app. Whether it is allowed to
/// interrupt is asked of the phone every time the list is drawn, so the step un-ticks itself if
/// the permission is taken away again.
Future<PhoneFacts> read() async {
  final ambient = Ambient.of();
  await ambient.start();
  return PhoneFacts(notificationsAllowed: ambient.allowed, installedToHome: true);
}
