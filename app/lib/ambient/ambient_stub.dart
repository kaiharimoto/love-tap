import 'package:flutter/services.dart';

import '../feelings/builtins.dart';

import '../spine/event.dart';
import 'ambient.dart';

/// Android. The three surfaces are the phone's own: an ongoing notification, the vibrator, and
/// the same notification channel woken by a push. All of it is on the other side of one method
/// channel, in app/android/.../Ambient.kt, so nothing here needs a package from the internet.
class _AndroidAmbient implements Ambient {
  static const _channel = MethodChannel('io.lovetap/ambient');
  bool _allowed = false;

  @override
  bool get allowed => _allowed;

  @override
  Future<void> start() async {
    try {
      _allowed = await _channel.invokeMethod<bool>('allowed') ?? false;
    } on PlatformException {
      _allowed = false;
    } on MissingPluginException {
      _allowed = false;
    }
  }

  @override
  Future<bool> ask() async {
    try {
      _allowed = await _channel.invokeMethod<bool>('ask') ?? false;
    } catch (_) {
      _allowed = false;
    }
    return _allowed;
  }

  @override
  Future<void> standing(Person who, String line) async {
    try {
      await _channel.invokeMethod<void>('standing', {'who': who.name, 'line': line});
    } catch (_) {}
  }

  @override
  Future<void> pocket(Feeling feeling, double intensity) async {
    // the same notation the app plays through the vibrator when it is open (docs/FEELINGS.md),
    // handed to the platform so it can be felt when it is not
    final scale = 0.45 + 0.55 * intensity.clamp(0.0, 1.0);
    final segments = feeling.segments;
    try {
      await _channel.invokeMethod<void>('pocket', {
        'timings': [for (final s in segments) s.ms],
        'amplitudes': [for (final s in segments) (s.amp * scale).round()],
        'sound': feeling.sound,
        'name': feeling.name,
      });
    } catch (_) {}
  }

  @override
  Future<PushSubscription?> subscribe(String vapidPublicKey) async => null;

  @override
  Future<void> clear() async {
    try {
      await _channel.invokeMethod<void>('clear');
    } catch (_) {}
  }

  @override
  Future<Map<String, Object?>> whatThePhoneCanHold() async {
    // Asked of the phone rather than assumed. `received()` returning nothing is two different
    // facts wearing one face — a phone holding nothing because nothing was sent, and a phone that
    // was never allowed to hold anything — and an emotional critic could only read the second out
    // of an empty list in nineteen reports.
    var allowed = _allowed;
    try {
      allowed = await _channel.invokeMethod<bool>('allowed') ?? _allowed;
    } catch (_) {
      // the channel is not there, which is itself the answer
    }
    return {
      'platform': 'android',
      'a_secure_origin': true,     // the app is the app; there is no origin to be insecure about
      'the_person_has_allowed_it': allowed ? 'granted' : 'not granted',
      'a_notification_channel': true,
      'a_vibration_motor': true,
    };
  }

  @override
  @override
  String? get whyTheHeldListIsEmpty =>
      'this platform holds a notification in its own shade; the app cannot read it back';

  Future<List<Map<String, Object?>>> received() async {
    // Android's own record of what is in the shade, once there is a device to read it off. There
    // is not one here (docs/PHONES.md), so this returns nothing rather than something invented.
    try {
      final held = await _channel.invokeListMethod<Object?>('received');
      return [
        for (final e in held ?? const <Object?>[])
          if (e is Map) e.map((k, v) => MapEntry('$k', v)),
      ];
    } catch (_) {
      return const [];
    }
  }
}

Ambient ambient() => _AndroidAmbient();
