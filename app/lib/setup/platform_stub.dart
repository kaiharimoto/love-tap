import 'platform.dart';

/// Android. Being installed is not a question here — the app is the app. Whether notifications are
/// allowed is answered by the notification layer once it exists; until then the step stays untick
/// and says what it is waiting for, which is the truth.
Future<PhoneFacts> read() async =>
    const PhoneFacts(notificationsAllowed: false, installedToHome: true);
