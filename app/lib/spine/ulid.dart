// ULID: 26 Crockford base32 characters, 48-bit millisecond time + 80-bit randomness.
// Monotonic within one process so events minted in the same millisecond keep their order.
import 'dart:math';

const String _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

class UlidFactory {
  UlidFactory({Random? random}) : _random = random ?? Random.secure();

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
      timeChars[i] = t & 31;
      t >>= 5;
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
      t = (t << 5) | _alphabet.indexOf(ulid[i]);
    }
    return t;
  }
}
