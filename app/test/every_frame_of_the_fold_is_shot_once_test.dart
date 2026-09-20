// A clip of the note opening shows every frame of the sequence, once.
//
// docs/BRIEF.md disqualifies two things at once here: "a fold or crumple sequence playing fewer
// than 30 unique frames per second", and "an evidence clip in which any frame is pixel-identical
// to its predecessor". Both were being breached by the same arithmetic, and neither was breached
// by anything in the renders — all 240 frames of unfold_thirds are on disk and distinct.
//
// What broke it is that the clip's frame rate was written down twice and the two copies did not
// agree. ffmpeg assembles at 60 frames a second, which is 16667 microseconds a frame; the capture
// harness stepped the driven clock by a whole 16 milliseconds between shots. The sequence fell one
// frame behind every 400 ms, so one shot in every twenty-five caught the frame before it again —
// at recorded frames 44, 94, 144, 169, 244 and 269 of the firing 23 capture, a cadence of exactly
// twenty-five, which is what 4 percent of 60 is. 240 rendered frames became 250 recorded ones and
// the sequence played 57.6 unique frames a second.
//
// The second half of it was `Duration.inMilliseconds` inside the widget, which truncates: a run of
// exact 16667 us steps reads 16, 33, 50, 66, 83 ms and indexes 0, 1, 3, 3, 4. That one skips a
// frame as well as repeating one, and it does it whatever the harness steps by.
//
// So this walks the clock the way the harness does — one clip frame at a time, accumulated, never
// rounded to a millisecond — and requires the frame the app would paint to advance by exactly one
// each time, for the whole of the longest sequence in the library.

import 'package:flutter_test/flutter_test.dart';
import 'package:desk/capture/hooks.dart';
import 'package:desk/material/fold.dart';
import 'package:desk/material/motion.dart';

void main() {
  // The clock's own advance is `_now += by`, so accumulating the period here is the same walk the
  // harness takes; what is under test is the arithmetic that turns it into a frame number.
  const length = 240;
  final period = DrivenClock.period(FoldFrames.frameRate.toDouble());

  test('one step of the clip clock is exactly one frame of the sequence', () {
    expect(period, const Duration(microseconds: 16667));
    expect(period.inMilliseconds, 16, reason: 'and 16 is what the harness used to step by');
  });

  test('every frame of the sequence is shot once, and none is shot twice', () {
    final shown = <int>[];
    var now = Duration.zero;
    for (var shot = 0; shot < length; shot++) {
      expect(FoldFrames.finished(now, length), isFalse,
          reason: 'the sequence ended at shot $shot, before its last frame was shot');
      shown.add(FoldFrames.frameAt(now, length));
      now += period;
    }
    expect(shown.first, 0);
    expect(shown.last, length - 1);
    expect(shown.toSet().length, length, reason: 'a frame was shot twice or never shot');
    for (var i = 1; i < shown.length; i++) {
      expect(shown[i] - shown[i - 1], 1,
          reason: 'shot $i jumped from frame ${shown[i - 1]} to ${shown[i]}');
    }
    // and the sequence is over on the very next shot, not several later
    expect(FoldFrames.finished(now, length), isTrue);
  });

  test('a whole-millisecond step repeats a frame every twenty-five shots', () {
    // the re-break, kept as a test rather than as a claim: this is the shipped behaviour, and it
    // has to still be wrong for the test above to be worth anything
    const wrong = Duration(milliseconds: 16);
    final repeats = <int>[];
    var now = Duration.zero;
    var last = -1;
    for (var shot = 0; shot < length; shot++) {
      final i = FoldFrames.frameAt(now, length);
      if (i == last) repeats.add(shot);
      last = i;
      now += wrong;
    }
    expect(repeats, isNotEmpty);
    for (var i = 1; i < repeats.length; i++) {
      expect(repeats[i] - repeats[i - 1], 25);
    }
  });

  test('truncating to milliseconds skips a frame as well as repeating one', () {
    // what the widget did before: `after.inMilliseconds * 60 ~/ 1000` off an exact clock
    int truncated(Duration since) => (since.inMilliseconds * FoldFrames.frameRate ~/ 1000);
    var now = Duration.zero;
    final shown = <int>[];
    for (var shot = 0; shot < 6; shot++) {
      shown.add(truncated(now));
      now += period;
    }
    expect(shown, [0, 0, 1, 3, 3, 4]);
    // and what it does now, on the same clock
    now = Duration.zero;
    final fixed = <int>[];
    for (var shot = 0; shot < 6; shot++) {
      fixed.add(FoldFrames.frameAt(now, length));
      now += period;
    }
    expect(fixed, [0, 1, 2, 3, 4, 5]);
  });

  test('the open knows how long it is, so a take of it can be exactly that long', () {
    Folds.reset();
    expect(Folds.microsecondsLeftInTheOpen, 0, reason: 'nothing is opening');

    Folds.openFrom(Duration.zero, length);
    // the sequence, and then the settle that puts the written note over its last frame
    final whole = Duration(microseconds: length * 1000000 ~/ FoldFrames.frameRate) + Motion.settle;
    expect(Folds.openEndsAt, whole);
    // a take stepping the clip clock reaches the end of the open in this many shots and no fewer
    final shots = (whole.inMicroseconds / period.inMicroseconds).ceil();
    expect(shots, greaterThan(length), reason: 'the settle is part of the open');
    expect(shots, lessThan(length + Motion.settle.inMilliseconds),
        reason: 'and it is only the settle: 44 spare frames were 06_unfolding.mp4s held tail');
    Folds.reset();
    expect(Folds.openEndsAt, isNull);
  });

  _register();
}

// ---------------------------------------------------------------------------------------------
// And a clip of the fold has to be told apart from a clip of its aftermath, which is what firing
// 31 could not do.
//
// `06_unfolding.report.json` is written by the scene's `report` step, which runs AFTER the frames
// step. So its `fold.playhead` is the sequence as it stands at the END of the take -- 239 of 240,
// every single time, whatever the clip in front of it contains. Firing 31 read that end-of-clip
// 239 as though it were the reading at frame zero and concluded the sequence had already finished
// before the recorder started, which filed the defect as a capture-ordering bug.
//
// It was not one, and the driven clock says so to the millisecond. `driven_ms` at the report was
// 4394 and the frames step stepped 255 frames of 1000/60 ms, which is 4250.0 exactly; the
// difference is 144 ms, and 144 ms is precisely the three `_settle()` calls that `goTo`,
// `scrollTo` and `unfold` make on their way past, at 3 x 16 ms each. Nothing else advanced the
// clock, because `wait` is `page.waitForTimeout` and moves wall time only. A 240-frame sequence at
// 60 fps is 4000 ms, so at the first shot it can have advanced at most 144 ms of it -- under nine
// frames, and in fact under three, since only `unfold`'s own settle falls after the fold begins.
//
// The lesson generalises past this clip, and it is WORKER_PROMPT 3d: a reading taken after the
// fact is not a reading of the first frame. So the harness now asks at the first frame, and this
// is the arithmetic that says what it should find there.

const _drivenMsAtReport = 4394;
const _framesShot = 255;
const _settlesBeforeTheTake = 3;      // goTo, scrollTo, unfold
const _stepsPerSettle = 3;            // CaptureHooks._settle loops three times
const _settleStepMs = 16;

void _register() {
  test('the recorder started 144 ms into a 4000 ms fold, not after it', () {
    const length = 240;
    final period = DrivenClock.period(FoldFrames.frameRate.toDouble());

    // what the frames step itself stepped, in microseconds
    final takeUs = _framesShot * period.inMicroseconds;
    final beforeTheTakeUs = _drivenMsAtReport * 1000 - takeUs;

    // 143915 us against the three settles' nominal 144000. The 85 us is the clock's own period
    // being a whole number of microseconds -- 1000000/60 rounds to 16667, so 255 of them are
    // 4250.085 ms and not the 4250.0 the frame rate suggests -- plus up to a millisecond of
    // quantisation in `driven_ms`, which the report writes as a whole number. So this is an
    // equality within the rounding the two figures actually carry, not an approximation chosen
    // to make the test pass: the slack is one clock period and it is named.
    expect(beforeTheTakeUs,
        closeTo(_settlesBeforeTheTake * _stepsPerSettle * _settleStepMs * 1000,
            period.inMicroseconds),
        reason: 'the only driven time before the take is three _settle() calls; if this stops '
            'matching, something else started stepping the clock and the reasoning below is void');

    // so the playhead at the first shot is far below the end of the sequence
    final frameAtFirstShot = FoldFrames.frameAt(Duration(microseconds: beforeTheTakeUs), length);
    expect(frameAtFirstShot, lessThan(20),
        reason: 'clause (c) of rank 1: the clip has to contain the fold, not its aftermath');

    // and the take is long enough to carry the sequence past the far end
    final frameAtLastShot =
        FoldFrames.frameAt(Duration(microseconds: beforeTheTakeUs + takeUs), length);
    expect(frameAtLastShot, greaterThan(220),
        reason: 'the take ran 4250 ms against a 4000 ms sequence, so it finishes inside the clip');
  });
}
