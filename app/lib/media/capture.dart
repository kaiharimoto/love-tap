// Picking photos and videos and recording voice notes, on both platforms.
import 'dart:async';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';

class PickedMedia {
  const PickedMedia({required this.bytes, required this.mime, required this.w, required this.h, this.durationMs});
  final Uint8List bytes;
  final String mime;
  final int w;
  final int h;
  final int? durationMs;
}

class MediaCapture {
  final ImagePicker _picker = ImagePicker();

  Future<PickedMedia?> pickPhoto({bool camera = false}) async {
    final x = await _picker.pickImage(source: camera ? ImageSource.camera : ImageSource.gallery, maxWidth: 2400, imageQuality: 88);
    if (x == null) return null;
    final bytes = await x.readAsBytes();
    final dims = imageSize(bytes) ?? (1200, 1600);
    return PickedMedia(bytes: bytes, mime: x.mimeType ?? 'image/jpeg', w: dims.$1, h: dims.$2);
  }

  Future<PickedMedia?> pickVideo({bool camera = false}) async {
    final x = await _picker.pickVideo(source: camera ? ImageSource.camera : ImageSource.gallery, maxDuration: const Duration(minutes: 3));
    if (x == null) return null;
    final bytes = await x.readAsBytes();
    return PickedMedia(bytes: bytes, mime: x.mimeType ?? 'video/mp4', w: 1080, h: 1920);
  }

  /// Width and height from JPEG or PNG headers.
  static (int, int)? imageSize(Uint8List b) {
    if (b.length > 24 && b[0] == 0x89 && b[1] == 0x50) {
      final w = (b[16] << 24) | (b[17] << 16) | (b[18] << 8) | b[19];
      final h = (b[20] << 24) | (b[21] << 16) | (b[22] << 8) | b[23];
      return (w, h);
    }
    if (b.length < 4 || b[0] != 0xFF || b[1] != 0xD8) return null;
    var i = 2;
    while (i + 9 < b.length) {
      if (b[i] != 0xFF) {
        i++;
        continue;
      }
      final marker = b[i + 1];
      if (marker >= 0xC0 && marker <= 0xCF && marker != 0xC4 && marker != 0xC8 && marker != 0xCC) {
        return ((b[i + 7] << 8) | b[i + 8], (b[i + 5] << 8) | b[i + 6]);
      }
      i += 2 + ((b[i + 2] << 8) | b[i + 3]);
    }
    return null;
  }
}

/// A voice note being recorded: amplitude samples become the waveform drawn in the thread.
class VoiceRecorder {
  final AudioRecorder _rec = AudioRecorder();
  final List<double> _amps = [];
  Timer? _timer;
  DateTime? _started;
  String? _path;

  bool get recording => _started != null;

  Future<bool> start(String tmpPath) async {
    if (!await _rec.hasPermission()) return false;
    _amps.clear();
    _path = tmpPath;
    await _rec.start(const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 44100, numChannels: 1), path: tmpPath);
    _started = DateTime.now();
    _timer = Timer.periodic(const Duration(milliseconds: 120), (_) async {
      final a = await _rec.getAmplitude();
      // dBFS → 0..1
      final v = ((a.current + 50) / 50).clamp(0.0, 1.0);
      _amps.add(v);
    });
    return true;
  }

  /// Stops and returns bytes, mime, duration, and a 48-bucket waveform.
  Future<(Uint8List, String, int, List<double>)?> stop(Future<Uint8List?> Function(String path) read) async {
    _timer?.cancel();
    final started = _started;
    _started = null;
    if (started == null) return null;
    final out = await _rec.stop();
    final path = out ?? _path;
    if (path == null) return null;
    final bytes = await read(path);
    if (bytes == null) return null;
    final ms = DateTime.now().difference(started).inMilliseconds;
    return (bytes, 'audio/mp4', ms, resample(_amps, 48));
  }

  Future<void> cancel() async {
    _timer?.cancel();
    _started = null;
    if (await _rec.isRecording()) await _rec.stop();
  }

  static List<double> resample(List<double> xs, int n) {
    if (xs.isEmpty) return List<double>.filled(n, 0.2);
    return List<double>.generate(n, (i) {
      final a = (i * xs.length / n).floor();
      final b = ((i + 1) * xs.length / n).ceil().clamp(a + 1, xs.length);
      var m = 0.0;
      for (var k = a; k < b; k++) {
        if (xs[k] > m) m = xs[k];
      }
      return m;
    });
  }

  void dispose() {
    _timer?.cancel();
    _rec.dispose();
  }
}
