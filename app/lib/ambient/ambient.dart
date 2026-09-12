// The three surfaces the other person reaches without either of them opening anything.
//
// This is the part of the app that works while the app is shut, and it is the part that decides
// whether their state is something you live alongside or something you go and check. There are
// three surfaces and they are the same three on both phones, with one difference that is designed
// rather than missing:
//
//   1. the standing line   their state, always there in the shade, never a count and never a
//                          badge — it says what they are, not how much you owe them
//   2. the pocket          a feeling arriving as something felt rather than read. On Android that
//                          is the feeling's own haptic rhythm. An iPhone will not let a PWA
//                          vibrate, so there the same rhythm is carried by the feeling's sound and
//                          by the page itself moving on it when the app is open (feelings/
//                          sensation.dart) — the substitute is the rhythm in another medium, not
//                          a missing feature
//   3. background delivery what makes the first two happen while the phone is in a pocket: Web
//                          Push on the PWA, the same path on Android. A push carries the event
//                          kind and who sent it and nothing else, ever; the note is fetched over
//                          the tailnet by the app when it opens.
import '../feelings/builtins.dart';
import '../spine/event.dart';
import '../spine/projections/state.dart';
import 'ambient_stub.dart' if (dart.library.js_interop) 'ambient_web.dart' as impl;

/// What the push service is told to send here, and the only thing it is ever given.
class PushSubscription {
  const PushSubscription({required this.endpoint, required this.p256dh, required this.auth});
  final String endpoint;
  final String p256dh;
  final String auth;

  Map<String, dynamic> toJson() => {
        'endpoint': endpoint,
        'keys': {'p256dh': p256dh, 'auth': auth},
      };
}

abstract class Ambient {
  static Ambient of() => impl.ambient();

  /// Whether this phone has been allowed to interrupt at all. The setup list watches this.
  bool get allowed;

  Future<void> start();

  /// Ask once. Both platforms will only ask from a gesture, so this is called from a tap.
  Future<bool> ask();

  /// Surface one. [line] is a sentence about them, already written by [standingLine].
  Future<void> standing(Person who, String line);

  /// Surface two.
  Future<void> pocket(Feeling feeling, double intensity);

  /// Surface three. Returns what the other phone needs in order to reach this one.
  Future<PushSubscription?> subscribe(String vapidPublicKey);

  Future<void> clear();

  /// What the phone is actually holding, read back from the platform rather than from what this
  /// app asked for. A record of an intention is not evidence that anything arrived.
  Future<List<Map<String, Object?>>> received();

  /// Why [received] came back empty, when it was not simply empty.
  ///
  /// Three facts used to arrive as one empty list: the phone is holding nothing, there is no worker
  /// to ask, and asking threw. An emotional critic read that list in nineteen reports and concluded
  /// that no artifact anywhere shows the pocket surface — while the reception check said in the
  /// same run that the browser was still holding one.
  String? get whyTheHeldListIsEmpty;

  /// What this platform will let the app hold at all, asked of the platform.
  ///
  /// `received()` returning nothing is two different facts wearing one face: a phone that is
  /// holding nothing because nothing was sent, and a page that could not register a worker in the
  /// first place. An emotional critic read `held_by_the_phone: []` in all nineteen reports and
  /// could only conclude that no artifact anywhere shows the pocket surface — which is true, and
  /// says nothing about why. This is why.
  Future<Map<String, Object?>> whatThePhoneCanHold();
}

/// What the standing line says. One sentence, in the couple's voice, made only of things that are
/// true right now — never a count of anything unanswered, because that is a debt and this is not.
String standingLine(Person who, PersonState state, int nowMs) {
  final bits = <String>[];
  final mood = state.mood;
  if (mood != null) bits.add(mood);
  final status = state.statusLine;
  if (status != null && status.isNotEmpty) bits.add(status);
  final place = state.place;
  if (place != null && place != 'unknown') bits.add(place);
  final minutes = state.lastActiveMinutesAt(nowMs);
  if (minutes != null) {
    if (minutes < 3) {
      bits.add('there now');
    } else if (minutes < 90) {
      bits.add('$minutes minutes ago');
    } else if (minutes < 60 * 20) {
      bits.add('${minutes ~/ 60} hours ago');
    }
  }
  final battery = state.battery;
  if (battery != null && battery <= 12 && !state.charging) bits.add('nearly out of battery');
  if (bits.isEmpty) return 'nothing from them since you last looked';
  return bits.join(' · ');
}
