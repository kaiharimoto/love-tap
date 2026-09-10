// The haptic channel is wired; this machine has nothing on the other end.
//
// An emotional critic wrote: "Nothing in the evidence ever vibrated. All 36 waveforms exist only as
// specified strings; the single channel actually exercised is visual." The first half is true and
// cannot be otherwise — there is no phone in this environment and no motor in a browser. The
// second half conflates two things: a channel that is not wired, and a channel that is wired to a
// machine with nothing on the other end. This is the difference, asserted.
import 'package:desk/feelings/builtins.dart';
import 'package:desk/feelings/sensation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(Sensation.asks.clear);

  test('sending a feeling asks a motor for its waveform', () async {
    final s = Sensation();
    addTearDown(s.dispose);
    final f = kBuiltInFeelings.firstWhere((f) => f.id == 'stuck_with_me');
    await s.play(f, intensity: 0.8, sound: false);

    expect(Sensation.asks, isNotEmpty,
        reason: 'the app never asked for a vibration, so the channel is not wired at all');
    final ask = Sensation.asks.last;
    final timings = (ask['timings'] as List).cast<int>();
    final amps = (ask['amplitudes'] as List).cast<int>();
    expect(timings.length, amps.length);
    expect(timings.length, greaterThan(1),
        reason: 'a waveform with one segment is a buzz, not a pattern');
    expect(timings.reduce((a, b) => a + b), greaterThan(100),
        reason: 'the pattern is ${timings.reduce((a, b) => a + b)} ms long');
    expect(amps.any((a) => a > 0), isTrue, reason: 'every segment is silent');
    // and it says what answered, which on any machine in this repository is nothing
    expect(ask['answered_by'], isNotNull);
    expect(ask['answered_by'].toString(), isNot('nothing yet'),
        reason: 'the ask was recorded but never resolved');
  });

  test('the intensity reaches the motor rather than only the page', () async {
    final s = Sensation();
    addTearDown(s.dispose);
    final f = kBuiltInFeelings.firstWhere((f) => f.id == 'stuck_with_me');
    await s.play(f, intensity: 0.3, sound: false);
    final soft = (Sensation.asks.last['amplitudes'] as List).cast<int>();
    Sensation.asks.clear();
    await s.play(f, intensity: 1.0, sound: false);
    final hard = (Sensation.asks.last['amplitudes'] as List).cast<int>();
    expect(hard.reduce((a, b) => a > b ? a : b),
        greaterThan(soft.reduce((a, b) => a > b ? a : b)),
        reason: 'a hard hold and a soft one ask for the same thing: $soft against $hard');
  });

  test('and a platform that has no motor says so rather than failing quietly', () async {
    // the test binding registers no lovetap/haptics channel, which is exactly the PWA's situation
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('lovetap/haptics'), null);
    final s = Sensation();
    addTearDown(s.dispose);
    await s.play(kBuiltInFeelings.first, intensity: 0.7, sound: false);
    expect(Sensation.asks.last['answered_by'].toString().toLowerCase(), contains('no motor'));
  });
}
