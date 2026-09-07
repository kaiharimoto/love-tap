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
