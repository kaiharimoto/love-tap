// A day, said the way a person says it, from whatever the thing keeps its time in.
//
// dayLabel took only an ISO string, and Moments passed it an event's own `ts`, which is an
// integer: every voice note on that screen read `teo · ` — author, separator, nothing after it.
import 'package:desk/thread/note_body.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a length of time is said one way', () {
    // One clip had three lengths in one evidence set: the viewer rounded 2500 ms to 0:03, the
    // gallery truncated it to 2s and the thread row wrote 0:02.
    expect(clockOf(2500, total: true), '0:03', reason: 'a two-and-a-half-second clip is not over at 0:02');
    expect(clockOf(2500), '0:02', reason: 'two and a half seconds in is still 0:02 until it is three');
    expect(clockOf(0), '0:00');
    expect(clockOf(-5), '0:00');
    expect(clockOf(41000, total: true), '0:41');
    expect(clockOf(154000, total: true), '2:34');
    expect(clockOf(60000, total: true), '1:00', reason: 'a whole minute is not 1:01');
  });

  test('a day is said the same way whatever it is kept in', () {
    final when = DateTime.utc(2026, 8, 4, 7, 24);
    final iso = dayLabel(when.toIso8601String());
    expect(iso, isNotEmpty);
    expect(dayLabel(when.millisecondsSinceEpoch), iso,
        reason: 'milliseconds off an event say nothing, so the row reads "teo · " with the '
            'separator drawn and no date after it');
    expect(dayLabel(when), iso);
    expect(dayLabel(null), isEmpty);
    expect(dayLabel('not a date'), isEmpty);
  });
}
