// Nothing that has to appear in a recording is animated on the framework's clock.
//
// This is the defect that has cost the most time in this build, in four different places, and it
// always looks the same: correct on a phone, absent from the evidence. Under capture the app's
// clock is driven a frame at a time and screenshots are taken between the steps, so a quarter of
// a second of wall clock passes between two frames of a clip. An implicit animation — an
// AnimatedOpacity, a TweenAnimationBuilder, an AnimationController — either has not started or is
// already finished at every single frame that gets grabbed, and never once appears.
//
// The unfolding clip is what it cost most recently: the note faded in over the last fold frame on
// the wall clock, so four and a half seconds of the clip were a sheet opening and the last half
// second was a blank cream rectangle. Which is, precisely, the anti-goal.
//
// material/motion.dart has Turning and Settling, which follow DrivenClock when it is driving and
// a plain loop when it is not. Everything that is part of a captured moment uses one of those.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The implicit animations that can hide a thing completely. Each runs on the framework's ticker
/// and there is no way to drive one: at t=0 the child is invisible, and under capture t is 0 in
/// every frame that gets grabbed.
///
/// AnimatedSize is deliberately not in this list. It degrades to a snap rather than to nothing —
/// the box is the right size in every frame, just without the ease between two of them — and a
/// snap of a note's own height under a fade that is driven is not a hole in the evidence.
final _wallClock = RegExp(
  r'\b(TweenAnimationBuilder|AnimatedOpacity|AnimatedContainer|AnimatedPositioned|'
  r'AnimatedDefaultTextStyle|AnimatedAlign|AnimatedPadding|AnimatedScale|AnimatedRotation|'
  r'AnimatedSlide|AnimatedCrossFade|AnimatedSwitcher|FadeTransition)\b',
);

/// A controller is different: its value can be set by hand, and the feeling corner does exactly
/// that — DrivenClock drives it under capture and it runs itself otherwise. So a controller is
/// allowed in a file that has heard of the driven clock, and a finding in one that has not.
final _controller = RegExp(r'\bAnimationController\b');

/// Where a moment is drawn: the material layer, the feelings, and the regions the clips are of.
/// A setting that animates while somebody is holding the phone is not evidence of anything.
final _underCapture = RegExp(r'lib/(material|feelings|regions/chat|regions/pulse)/');

List<File> _sources() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList()
  ..sort((a, b) => a.path.compareTo(b.path));

void main() {
  test('nothing in a captured moment animates on the framework clock', () {
    final offenders = <String>[];
    for (final f in _sources()) {
      if (!_underCapture.hasMatch(f.path)) continue;
      // motion.dart is where the two replacements live, and it names the things it replaces
      if (f.path.endsWith('material/motion.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//') || line.trimLeft().startsWith('///')) continue;
        if (_wallClock.hasMatch(line)) offenders.add('${f.path}:${i + 1}  ${line.trim()}');
        if (_controller.hasMatch(line) && !f.readAsStringSync().contains('DrivenClock')) {
          offenders.add('${f.path}:${i + 1}  ${line.trim()}  (never asks the driven clock)');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'these run on the wall clock, so they are invisible in the evidence. '
            'Use Turning or Settling from material/motion.dart:\n${offenders.join('\n')}');
  });
}
