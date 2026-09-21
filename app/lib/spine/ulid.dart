// ULID: 26 Crockford base32 characters, 48-bit millisecond time + 80-bit randomness.
// Monotonic within one process so events minted in the same millisecond keep their order.
import 'dart:math';

const String _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

class UlidFactory {
  UlidFactory({Random? random}) : _random = random ?? Random.secure();

  /// A factory whose eighty bits of randomness are the same on every run.
  ///
  /// `Flags.capture`'s own docstring has promised "driven clock, fixed RNG seed" since it was
  /// written, and `Flags.captureSeed` has existed for as long, and every capture report prints
  /// `seed: 20260903`. Nothing applied it here, so every event a capture minted carried eighty
  /// bits out of `Random.secure()` — and an event id picks the paper it is written on, through
  /// `hashOf(id)` in material/slip.dart.
  ///
  /// The cost was a ruler nobody could read twice. `13_messenger_states` stages four messages on
  /// every run, and firing 28 found their ids differ between two captures of the same commit
  /// (`0001MCJ1M0H9H62TRFZBB1MNXS` against `0001MCJ1M0HZ2R94F1XFBSH9JW`) while the three seeded
  /// notes above them keep theirs. So four of the seven notes on that screen were torn from a
  /// different stock each time, and rank 1's last open clause — a 300x120 sample at (200,1350) —
  /// read 23.673, then 28.019, then 26.962 on three captures, moving by more than a point with
  /// nothing about the paper changing. The clock was frozen so the artifact would be the same
  /// picture twice; this is the other half of that.
  ///
  /// Only under capture. A real build keeps `Random.secure()`, which is what an id that has to be
  /// unique across two phones that have never met needs to be.
  factory UlidFactory.seeded(int seed) => UlidFactory(random: Random(seed));

  final Random _random;
  int _lastMs = -1;
  final List<int> _lastRand = List<int>.filled(16, 0);

  String next([DateTime? at]) {
    final ms = (at ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
    if (ms == _lastMs) {
      // increment the 80-bit random part
      for (var i = 15; i >= 0; i--) {
        _lastRand[i] = (_lastRand[i] + 1) & 31;
        if (_lastRand[i] != 0) break;
      }
    } else {
      _lastMs = ms;
      for (var i = 0; i < 16; i++) {
        _lastRand[i] = _random.nextInt(32);
      }
    }
    final sb = StringBuffer();
    var t = ms;
    final timeChars = List<int>.filled(10, 0);
    for (var i = 9; i >= 0; i--) {
      // Divide, do not shift. A web `int` is a double and `&` and `>>` are 32-bit operations on
      // it, so `ms & 31` on a real millisecond count reads the low half of the number and throws
      // the rest away. `%` and `~/` are exact on both platforms for anything inside 2^53, and a
      // 48-bit millisecond time is inside it by five orders of magnitude.
      timeChars[i] = t % 32;
      t = t ~/ 32;
    }
    for (final c in timeChars) {
      sb.write(_alphabet[c]);
    }
    for (final c in _lastRand) {
      sb.write(_alphabet[c]);
    }
    return sb.toString();
  }

  static bool isValid(String s) {
    if (s.length != 26) return false;
    for (final c in s.codeUnits) {
      if (!_alphabet.contains(String.fromCharCode(c))) return false;
    }
    return true;
  }

  static int timeOf(String ulid) {
    var t = 0;
    for (var i = 0; i < 10; i++) {
      // Multiply, do not shift, for the same reason [next] divides: ten base32 characters are
      // fifty bits and `<<` gives up at thirty-two of them in a browser.
      t = t * 32 + _alphabet.indexOf(ulid[i]);
    }
    return t;
  }
}
