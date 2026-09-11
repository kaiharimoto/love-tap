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
  Sensation({AudioPlayer? player}) : _player = player;  // ignore: prefer_initializing_formals

  static const _channel = MethodChannel('lovetap/haptics');

  /// Made the first time a sound is asked for, not when the scope is. Constructing an
  /// AudioPlayer registers it over a platform channel, and there is exactly one Sensation per
  /// AppScope now, so a scope built anywhere without the plugin (a widget test, a tool) would
  /// otherwise fail before it had drawn anything.
  AudioPlayer? _player;
  AudioPlayer get _audio => _player ??= AudioPlayer(playerId: 'feelings');

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
    // The ask is recorded whichever platform this is, and so is what answered it.
    //
    // It used to be recorded inside _vibrate, and _vibrate only ran off the web — so on the phone
    // the record existed and in every artifact this build can actually produce it did not, and
    // `asked_a_motor_for` appeared in none of nineteen region reports. An emotional critic read
    // that, correctly, as no artifact showing the app asking a motor for anything. A browser
    // having no motor is an answer; leaving the key out is not.
    final ask = <String, Object?>{
      'feeling': feeling.id,
      'timings': [for (final s in scaled) s.ms],
      'amplitudes': [for (final s in scaled) s.amp],
      'answered_by': kIsWeb
          ? 'no motor in a browser: the page rhythm carries it instead'
          : 'waiting on the platform',
    };
    asks.add(ask);
    if (asks.length > 64) asks.removeAt(0);
    if (!kIsWeb) {
      unawaited(_vibrate(scaled, ask));
    }
    await _movePaper(scaled);
    return report;
  }

  /// Every ask the app has made of a motor, whether or not there was one to answer.
  ///
  /// An emotional critic wrote "nothing in the evidence ever vibrated. All 36 waveforms exist only
  /// as specified strings; the single channel actually exercised is visual." The first half is
  /// true and cannot be otherwise here — there is no phone in this environment and no motor in a
  /// browser — but the second half conflates two things: a channel that is not wired, and a
  /// channel that is wired to a machine with nothing on the other end. This is the difference,
  /// written down: what was asked for, in milliseconds and amplitudes, and what answered.
  static final List<Map<String, Object?>> asks = [];

  Future<void> _vibrate(List<HapticSegment> segments, Map<String, Object?> ask) async {
    try {
      await _channel.invokeMethod<void>('waveform', {
        'timings': ask['timings'],
        'amplitudes': ask['amplitudes'],
      });
      ask['answered_by'] = 'the platform took it';
    } on MissingPluginException {
      // the plugin is only registered on Android; elsewhere the page rhythm is the sensation
      ask['answered_by'] = 'no motor on this platform: the page rhythm carries it instead';
    } catch (e) {
      ask['answered_by'] = 'the platform refused it: $e';
    }
  }

  Future<void> _playSound(Feeling feeling, double intensity) async {
    try {
      final player = _audio;
      await player.setVolume((0.35 + 0.65 * intensity).clamp(0.0, 1.0));
      await player.play(AssetSource(soundAsset(feeling.sound).replaceFirst('assets/', '')));
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
    _player?.dispose();
  }
}
