// The same seeded note is the same id on both phones — and until this test it was not.
//
// `app/test/the_same_paper_on_both_phones_test.dart` proves that `hashOf` returns the same number
// in a browser as on the phone. That is half the sentence. `hashOf` is fed an *id*, and if the two
// devices mint a different id for the same note then a hash that agrees about its input changes
// nothing: the paper still differs, and it differs for every note in the thread.
//
// FIRING 37 PAID A 45-MINUTE CAPTURE TO FIND THIS AND MISREAD THE CAUSE. It set a scene anchor to
// a seeded event id, the id named nothing in the PWA, `_scrollToAnchor` returned silently and the
// shutter caught six notes instead of twelve. It recorded the cause as the clock: "same 80-bit tail
// from the key, different 48-bit head from the clock". The clock is not involved. Both rigs were
// handed the identical `ts` out of the identical `seed/year/*.jsonl` line, and one of them threw
// half of it away.
//
//   key `2026-04-22-0012`, ts 2026-04-22T16:36:20Z = 1776875780000 ms
//     under `flutter test`   01KPV0SDX06FA58CJ9JXH23W7R
//     in the captured PWA    0002V0SDX06FA58CJ9JXH23W7R
//
// 1776875780000 mod 2^32 is 3054286752, and 3054286752 is exactly what `0002V0SDX0` decodes to.
// Not a clock: a width. `UlidFactory.next` peeled the ten time characters off with `t & 31` and
// `t >>= 5`, and **a web `int` is an IEEE-754 double on which `&` and `>>` are 32-bit operations**.
// A millisecond count has been past 2^32 since the 19th of February 1970, so the browser read the
// low 32 bits of every timestamp this app has ever minted an id from. All 14,061 events in the
// seeded year are past it; there is no subset that escapes.
//
// It is the same defect `hashOf` was repaired for, one file away, and the repair there did not
// look for the other instance.
//
// RUN IT ON BOTH RIGS. `flutter test` runs it on the VM, where the bug cannot reproduce, so here
// it works exactly as the paper test does: it does not mint the id twice and compare, it mints it
// once and then peels the time again under the arithmetic a browser performs, and requires the two
// to agree.
//
// THAT IS NOT SUFFICIENT ON ITS OWN, and firing 38 checked rather than assuming. Put the mask and
// the shift back into `UlidFactory.next` and the whole of this file still passes on the VM — the
// browser model is hand-written and never touches the real function, so it cannot see the real
// function change. `the_same_paper_on_both_phones_test.dart` has the same hole for the same
// reason. `tools/check/both_phones.sh` closes it: it runs this file on chrome, where the id is
// minted by the compiled code on the arithmetic that is actually in question. With the bug put
// back, all five tests below fail there. That is the re-break, and it is the reason to believe
// any of this.
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:desk/material/assignment.dart';
import 'package:desk/spine/event.dart';
import 'package:desk/spine/ulid.dart';
import 'package:flutter_test/flutter_test.dart';

const String _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

/// The ten time characters of a ULID, computed with `BigInt` so this one is beyond argument:
/// it is what the answer is, not what some arithmetic happens to produce.
String _referenceHead(int ms) {
  var t = BigInt.from(ms);
  final thirtyTwo = BigInt.from(32);
  final out = List<String>.filled(10, '0');
  for (var i = 9; i >= 0; i--) {
    out[i] = _alphabet[(t % thirtyTwo).toInt()];
    t = t ~/ thirtyTwo;
  }
  return out.join();
}

/// The peel as it was written until this firing: mask and shift.
///
/// dart2js coerces both operands of `&` and `>>` to unsigned 32 bits before it evaluates them, so
/// the model is the mask, applied at every step exactly where the browser applies it. After the
/// first step `t` is small enough that it no longer matters, which is why only the leading
/// characters move and the tail of the head survives intact.
String _peeledWithShifts(int ms) {
  final out = List<String>.filled(10, '0');
  var t = ms;
  for (var i = 9; i >= 0; i--) {
    final t32 = t & 0xFFFFFFFF; // what dart2js hands the operator
    out[i] = _alphabet[t32 & 31];
    t = t32 >> 5;
  }
  return out.join();
}

/// The peel as it is written now: remainder and truncating division, in `double` — which is what
/// a web `int` *is*. Both are exact for every value inside 2^53, and a 48-bit millisecond time is
/// inside it by five orders of magnitude, so this model has nowhere to lose anything.
String _peeledWithDivision(int ms) {
  final out = List<String>.filled(10, '0');
  var t = ms.toDouble();
  for (var i = 9; i >= 0; i--) {
    out[i] = _alphabet[(t % 32).toInt()];
    t = (t / 32).floorToDouble(); // dart2js lowers `~/` on a value past int32 to Math.floor
  }
  return out.join();
}

/// `SeedLoader._ulidFor`, which is private, reproduced here through the same public pieces it
/// uses. The assertion below that it reproduces the id firing 37 actually observed is what makes
/// this reproduction trustworthy rather than merely plausible.
String _seededIdFor(String key, int ms) {
  final digest = sha256.convert(utf8.encode('seed:$key')).bytes;
  var x = 0;
  for (var i = 0; i < 4; i++) {
    x = (x << 8) | digest[i];
  }
  return UlidFactory(random: Random(x)).next(DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true));
}

Event _noteWith(String id) => Event(
      id: id,
      seq: 1,
      author: Person.noor,
      device: DeviceKind.android,
      ts: 1776875780000,
      type: 'note',
      payload: const {'text': 'the canal has gone all dimples'},
    );

/// Real lines out of `seed/year/*.jsonl`: the key the app hashes for its randomness and the `ts`
/// the app parses for its time. No coordinate, no frame ordinal, no wall clock — the anchor is the
/// seed file and the output is the id the app itself mints.
const _seeded = <(String, int)>[
  ('2026-04-22-0012', 1776875780000), // the one the capture hit
  ('2025-09-01-9501', 1756706732000), // the first event of the year
  ('2026-09-03-0033', 1788456792000), // the last
];

void main() {
  test('the id the app mints for a seeded note is the id the capture saw', () {
    // The tie to the evidence. If this ever stops holding, the reproduction above has drifted from
    // `SeedLoader._ulidFor` and every measurement below is measuring the wrong function.
    expect(_seededIdFor('2026-04-22-0012', 1776875780000), '01KPV0SDX06FA58CJ9JXH23W7R');
  });

  test('a ULID head is the time it was given, and says so against BigInt', () {
    for (final (key, ms) in _seeded) {
      final id = _seededIdFor(key, ms);
      expect(id.substring(0, 10), _referenceHead(ms), reason: 'the head of $key is not its time');
      expect(UlidFactory.timeOf(id), ms, reason: 'timeOf could not read $key back');
    }
  });

  test('the id a seeded note gets is the same string in a browser as it is on the phone', () {
    // The measurement. Every seeded timestamp, peeled the way the browser peels it, has to come
    // back with the head the phone gets. This is the first half of the sentence DIRECTION.md
    // states and `the_same_paper_on_both_phones_test.dart` is named for.
    final differ = <String>[];
    for (final (key, ms) in _seeded) {
      final onThePhone = _seededIdFor(key, ms).substring(0, 10);
      final inTheBrowser = _peeledWithDivision(ms);
      if (onThePhone != inTheBrowser) differ.add('$key: $onThePhone vs $inTheBrowser');
    }
    expect(differ, isEmpty,
        reason: 'these seeded notes are minted under one id on the Android build and another in '
            'the PWA, so the two devices never agree about the thread at all:\n${differ.join('\n')}');
  });

  test('and the arithmetic that was there before really did differ, so this test can see it', () {
    // The re-break, kept rather than done once and thrown away. With the old mask-and-shift, the
    // browser's head and the phone's head part company on every seeded note in the year, and on
    // the one the capture hit they part company in exactly the way the capture recorded.
    expect(_peeledWithShifts(1776875780000), '0002V0SDX0',
        reason: 'the old peel was supposed to reproduce the head the PWA actually wrote');
    final differ = <String>[];
    for (final (key, ms) in _seeded) {
      if (_seededIdFor(key, ms).substring(0, 10) != _peeledWithShifts(ms)) differ.add(key);
    }
    expect(differ.length, _seeded.length,
        reason: 'the mask-and-shift form was supposed to diverge on every seeded note and diverged '
            'on ${differ.length} of ${_seeded.length}. If it no longer diverges, the test above '
            'has stopped proving anything.');
  });

  test('and the paper really did differ, which is what the divergence costs', () {
    // The visible half, and the reason this is a material_truth defect and not a harness one.
    // `hashOf(id)` picks the stock a note is torn from, the variant of that stock, how far it
    // lifts off the desk and how far it tilts. Feed it two different ids for one note and all four
    // move — so the same note in the same thread is a different object on the two phones.
    final moved = <String>[];
    for (final (key, ms) in _seeded) {
      final phone = _seededIdFor(key, ms);
      final browser = _peeledWithShifts(ms) + phone.substring(10);
      final a = _noteWith(phone);
      final b = _noteWith(browser);
      if (stockFor(a) != stockFor(b) || liftFor(a) != liftFor(b) || tiltFor(a) != tiltFor(b)) {
        moved.add('$key: ${stockFor(a)}/${liftFor(a).toStringAsFixed(2)} vs '
            '${stockFor(b)}/${liftFor(b).toStringAsFixed(2)}');
      }
    }
    expect(moved, isNotEmpty,
        reason: 'the old ids were supposed to pick different paper on the two phones; if they no '
            'longer do, this file is not measuring the defect it was written for');

    // And with the peel repaired there is one id, so there is one piece of paper.
    for (final (key, ms) in _seeded) {
      final phone = _seededIdFor(key, ms);
      final browser = _peeledWithDivision(ms) + phone.substring(10);
      expect(browser, phone, reason: '$key is still two different notes');
      expect(stockFor(_noteWith(browser)), stockFor(_noteWith(phone)));
    }
  });
}
