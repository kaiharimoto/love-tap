// A feeling arriving as a sensation.
//
// On Android the haptic sequence in docs/FEELINGS.md is played on the vibrator, exactly as
// written. iOS Safari has no vibration API at all, so the PWA does not go quiet: the same
// sequence drives the page — the sheet under your thumb lifts and settles on every `on`, and the
// feeling's paper sound plays with the same envelope. Same data, different body. Nothing here is
// a fallback that reads as an absence: the rhythm is the feeling, and it is delivered either way.
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

import '../material/library.dart';
import 'builtins.dart';

/// What the receiving device did with a feeling, for the evidence clips and for Settings.
class SensationReport {
  const SensationReport({
    required this.feelingId,
    required this.channel,
    required this.segments,
    required this.totalMs,
    required this.startedAt,
  });

  final String feelingId;

  /// 'vibration' on Android, 'page' on the PWA (the sheet moves and the sound carries the rhythm).
  final String channel;
  final List<HapticSegment> segments;
  final int totalMs;
  final DateTime startedAt;

  Map<String, dynamic> toJson() => {
        'feeling': feelingId,
        'channel': channel,
        'total_ms': totalMs,
        'started_at': startedAt.toIso8601String(),
        'pattern': [
          for (final s in segments) {'ms': s.ms, 'amp': s.amp},
        ],
      };
}

class Sensation {
  Sensation({AudioPlayer? player}) : _player = player ?? AudioPlayer(playerId: 'feelings');

  static const _channel = MethodChannel('lovetap/haptics');
  final AudioPlayer _player;

  /// The last thing played, for the capture log and the haptic annotation on the clips.
  SensationReport? last;

  /// Emits the amplitude the page should move at, 0..1, while a feeling plays. On Android this
  /// still runs (the paper moves too), but there the vibrator carries the pattern.
  final StreamController<double> _pulse = StreamController<double>.broadcast();
  Stream<double> get pulse => _pulse.stream;

  Timer? _timer;

  /// Plays a feeling at [intensity] (0..1). Returns when the pattern has finished.
  Future<SensationReport> play(Feeling feeling, {double intensity = 0.7, bool sound = true}) async {
    final segments = feeling.segments;
    final scaled = [
      for (final s in segments) HapticSegment(s.ms, (s.amp * (0.45 + 0.55 * intensity.clamp(0.0, 1.0))).round()),
    ];
    final total = scaled.fold<int>(0, (n, s) => n + s.ms);
    final channel = kIsWeb ? 'page' : 'vibration';
    final report = SensationReport(
      feelingId: feeling.id,
      channel: channel,
      segments: scaled,
      totalMs: total,
      startedAt: DateTime.now().toUtc(),
    );
    last = report;
    if (sound) {
      unawaited(_playSound(feeling, intensity));
    }
    if (!kIsWeb) {
      unawaited(_vibrate(scaled));
    }
    await _movePaper(scaled);
    return report;
  }

  Future<void> _vibrate(List<HapticSegment> segments) async {
    try {
      await _channel.invokeMethod<void>('waveform', {
        'timings': [for (final s in segments) s.ms],
        'amplitudes': [for (final s in segments) s.amp],
      });
    } on MissingPluginException {
      // the plugin is only registered on Android; elsewhere the page rhythm is the sensation
    } catch (_) {}
  }

  Future<void> _playSound(Feeling feeling, double intensity) async {
    try {
      await _player.setVolume((0.35 + 0.65 * intensity).clamp(0.0, 1.0));
      await _player.play(AssetSource(soundAsset(feeling.sound).replaceFirst('assets/', '')));
    } catch (_) {}
  }

  /// Drives the page rhythm: the sheet lifts on each `on` and settles on each `off`, so the
  /// pattern is felt through the paper when there is no vibrator to feel it through.
  Future<void> _movePaper(List<HapticSegment> segments) async {
    _timer?.cancel();
    final done = Completer<void>();
    var index = 0;
    void step() {
      if (index >= segments.length) {
        _pulse.add(0);
        if (!done.isCompleted) done.complete();
        return;
      }
      final s = segments[index++];
      _pulse.add(s.amp / 255.0);
      _timer = Timer(Duration(milliseconds: s.ms), step);
    }

    step();
    await done.future;
  }

  void dispose() {
    _timer?.cancel();
    _pulse.close();
    _player.dispose();
  }
}
