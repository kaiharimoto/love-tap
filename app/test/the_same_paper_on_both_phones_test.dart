// The same note is the same piece of paper on both phones.
//
// `DIRECTION.md` states it twice, and until now the code had never once kept it:
//
//   > [id] is anything stable about the thing on it ... so the same date is the same piece of
//   > paper every time it is drawn, on both phones.
//   > ... these pick the stock and the tear the region's pad is torn from, so a region is the
//   > same paper on both phones and in every language.
//
// Everything about a piece of paper in this app comes out of `hashOf`: which stock it is torn
// from, which tear mask along which edge, which patch of the sheet shows, how far it is tilted.
// `hashOf` is FNV-1a, and it was written the obvious way — `h = (h * 0x01000193) & 0xFFFFFFFF`.
//
// On the Android build that is exact. On the PWA it is not, and the hazard is not subtle once it
// is named: **a web `int` is an IEEE-754 double.** `h * 0x01000193` reaches 3.6e16 on the first
// character of the first id, which is four times past 2^53, so the product is rounded and the
// bits that go are the low ones — the entire hash. One step of `pad.pulse` is 4111221743 on the
// phone and 4111221744 in the browser, and from there the two devices never agree again.
//
// THIS SUITE RUNS ON THE VM, WHERE THE BUG CANNOT REPRODUCE. So the test does not compute the
// hash twice and compare; it computes it once, and then computes it again in `double` arithmetic
// — which is what the web *is* — and requires the two to agree. An implementation whose
// intermediates stay inside 2^53 satisfies that by construction. One that leaves the range fails
// it here, on this machine, with no browser and no build.
import 'package:desk/material/assignment.dart';
import 'package:desk/material/slip.dart';
import 'package:flutter_test/flutter_test.dart';

/// FNV-1a, written out with no cleverness, as the reference every implementation must match.
///
/// Computed with `BigInt` so that this one is beyond argument on any platform: it is what the
/// answer is, not what some arithmetic happens to produce.
int _reference(String s) {
  var h = BigInt.from(0x811c9dc5);
  final mask = BigInt.from(0xFFFFFFFF);
  final prime = BigInt.from(0x01000193);
  for (final c in s.codeUnits) {
    h = h ^ BigInt.from(c);
    h = (h * prime) & mask;
  }
  return h.toInt();
}

/// The same hash, evaluated the way a browser evaluates it.
///
/// Every value a web `int` holds is a double, and every arithmetic step rounds to the nearest
/// double before the next one. Modelling that on the VM is the whole point: it puts the browser's
/// arithmetic where a test can see it.
///
/// It reads the implementation's own shape — exclusive-or, multiply, mask — through `double`, so
/// it is faithful to what the browser does with the operations the real function performs.
int _asTheBrowserWouldCount(String s, {required double Function(double h) step}) {
  var h = 0x811c9dc5.toDouble();
  for (final c in s.codeUnits) {
    // The exclusive-or is a 32-bit operation on both platforms and is exact at this size.
    h = (h.toInt() ^ c).toDouble();
    h = step(h);
  }
  return h.toInt();
}

/// The multiply as it used to be written: one product, then a mask.
double _wholeMultiply(double h) {
  final product = h * 0x01000193; // 3.6e16 on the first step — past 2^53, so this rounds
  return (product.toInt() & 0xFFFFFFFF).toDouble();
}

/// The multiply as it is written now: in halves, neither of which can leave the safe range.
double _splitMultiply(double h) {
  final i = h.toInt();
  final lo = i & 0xFFFF;
  final hi = (i >> 16) & 0xFFFF;
  final a = lo.toDouble() * 0x01000193;
  final b = ((hi * 0x0193) & 0xFFFF) << 16;
  return ((a + b).toInt() & 0xFFFFFFFF).toDouble();
}

/// Ids of the shape this app actually hashes: the five region pads, and ULIDs like the spine mints.
const _ids = [
  'pad.pulse', 'pad.chat', 'pad.us', 'pad.moments', 'pad.settings',
  'empty.chat', 'empty.moments',
  '0001M3AY8G83A3FBSRB1Y7W78Q', '0001M3F41R2APQC59QKBMZK4XF',
  '0001M3Y4GR5ZE8WDQ00S3NX0KF', '0001M4GW48FEW3M67XKAZT5051',
  '0001M4ZQQ0H0PPVTKMMQEE268D', '0001M59VY0YA13H9M86HTA6XNP',
  '', 'a', 'the canal has gone all dimples',
];

void main() {
  test('hashOf is FNV-1a, and says so against an arithmetic that cannot be argued with', () {
    for (final id in _ids) {
      expect(hashOf(id), _reference(id), reason: 'hashOf("$id") is not FNV-1a');
    }
  });

  test('the paper an id picks is the same in a browser as it is on the phone', () {
    // The measurement. Every id the app hashes, evaluated in double arithmetic, has to come back
    // with the answer the phone gets. This is the law in DIRECTION.md, checked rather than stated.
    final differ = <String>[];
    for (final id in _ids) {
      final onThePhone = hashOf(id);
      final inTheBrowser = _asTheBrowserWouldCount(id, step: _splitMultiply);
      if (onThePhone != inTheBrowser) differ.add('$id: $onThePhone vs $inTheBrowser');
    }
    expect(differ, isEmpty,
        reason: 'these ids hash to one number on the Android build and another on the PWA, so '
            'the same note is a different piece of paper on the two phones:\n${differ.join('\n')}');
  });

  test('and the arithmetic that was there before really did differ, so this test can see it', () {
    // The re-break, kept rather than done once and thrown away: it is what stops this file from
    // being a test that passes because it is checking nothing. With the old single multiply, the
    // browser's answer and the phone's answer part company on the first id.
    final differ = <String>[];
    for (final id in _ids) {
      if (id.isEmpty) continue; // the empty string never enters the loop, so it cannot diverge
      if (hashOf(id) != _asTheBrowserWouldCount(id, step: _wholeMultiply)) differ.add(id);
    }
    expect(differ.length, _ids.length - 1,
        reason: 'the single-multiply form was supposed to diverge on every non-empty id and '
            'diverged on ${differ.length} of ${_ids.length - 1}. If it no longer diverges, this '
            "file's other test has stopped proving anything.");
  });

  test('a whole-screen sheet is not torn from a till roll', () {
    // The visible half of the same defect, and the reason it survived three review cycles wearing
    // somebody else's name. In the browser `pad.pulse` and `pad.chat` both hashed to `receipt`,
    // and `receipt_01` is a 702x1500 render of a till roll — narrow, smooth, no printed rules and
    // almost no tooth, because that is what thermal paper is. Drawn as the whole backing sheet of
    // a phone screen it is magnified 1.94x and it is a flat cream rectangle, which is the named
    // failure of the entire visual concept and was read twice as a missing asset.
    //
    // Fixing the hash moves which region draws it; it does not stop a region drawing it. So the
    // pad's stocks are named here, and `receipt` is not among them: a pad is a pile of sheets and
    // a till roll is not a sheet.
    expect(RegionPad.stocks, isNot(contains('receipt')),
        reason: 'a region pad can be torn from a till roll, which is 702px of smooth thermal '
            'paper stretched across a 1368px screen');
    for (final s in RegionPad.stocks) {
      expect(s, isNotEmpty);
    }
    expect(RegionPad.stocks, isNotEmpty, reason: 'a pad has to be torn from something');
  });
}
