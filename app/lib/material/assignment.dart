// Which piece of paper an event is written on.
//
// Two rules the brief cares about: the stock carries meaning (the partner's mood picks the strip's
// stock), and no two tears visible at once may be the same. The second is not luck — the pool is
// walked by a stride derived from each event's id so that consecutive events never land on the
// same mask, and a screenful is checked by tools/check/tear_repeat.py against the capture log.
import '../spine/event.dart';
import 'library.dart';

/// A deterministic 32-bit hash of an event id (FNV-1a): the same note gets the same paper on both
/// devices and in every capture.
///
/// **The multiply is split, and it has to be.** The obvious form is
/// `h = (h * 0x01000193) & 0xFFFFFFFF`, and that is what this was. On the Android build it is
/// exact. On the PWA it is not: a web `int` is an IEEE-754 double, and `h * 0x01000193` reaches
/// 3.6e16 on the very first character of the very first id — four times past 2^53, where a double
/// stops being able to count. The product is rounded, and the bits that are rounded away are the
/// low ones, which is the entire hash. One step of `pad.pulse` comes out 4111221743 on the phone
/// and 4111221744 in the browser.
///
/// So every piece of paper in this app was a different piece of paper on the two devices: which
/// stock a note is torn from, which tear mask, which patch of the sheet, which way it is tilted.
/// `DIRECTION.md` states the opposite twice -- *the same date is the same piece of paper every
/// time it is drawn, on both phones*, and *a region is the same paper on both phones and in every
/// language* -- so this was a law the code had never once kept.
///
/// It was visible the whole time and read as something else. `pad.pulse` and `pad.chat` both hash
/// to `receipt` in the browser, and `receipt_01` is a 702x1500 render of a till roll: narrow,
/// smooth, no rules and almost no tooth, because that is what thermal paper is. Stretched across
/// a whole phone screen at 1.94x it is a flat cream rectangle -- the one `10_first_run.png`,
/// `17_setup_pwa.png` and the bare part of `01_pulse.png` are measured at 59.5%, 48.0% and 10.9%
/// of their frames, which three cycles of review called a missing asset and then a `ColoredBox`
/// showing through. It was neither. It was the right widget drawing the wrong paper.
///
/// The split keeps every intermediate inside 2^53 and computes the identical 32-bit result, so
/// the Android build's assignments do not move and the PWA's come to meet them:
/// `h * M mod 2^32` is `(h_lo * M) + ((h_hi * (M & 0xFFFF)) << 16) mod 2^32`, and the largest
/// value formed is `0xFFFF * 0x01000193`, about 1.1e12.
int hashOf(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h ^= c;
    final lo = h & 0xFFFF;
    final hi = (h >> 16) & 0xFFFF;
    h = ((lo * 0x01000193) + (((hi * 0x0193) & 0xFFFF) << 16)) & 0xFFFFFFFF;
  }
  return h;
}

/// The stock a note is torn from, by author and type.
String stockFor(Event e) {
  final h = hashOf(e.id);
  if (e.type == 'ping') return 'index';
  if (e.type == 'milestone') return 'index';
  if (e.type == 'date_event') return 'index';
  if (e.type == 'todo_event') return 'looseleaf';
  if (e.type == 'ritual_kept') return 'graph';
  if (e.author == Person.noor) {
    // Noor tears strips off whatever is nearest
    const pool = ['lined', 'graph', 'spiral', 'receipt'];
    return pool[h % pool.length];
  }
  // Teo folds things: heavier stock, fewer surprises
  const pool = ['looseleaf', 'lined', 'legal'];
  return pool[h % pool.length];
}

/// A mood picks the paper the partner strip is torn from (docs/SIGNALS.md).
String stockForMood(String? mood) => switch (mood) {
      'bright' => 'legal',
      'calm' => 'lined',
      'tender' => 'index',
      'restless' => 'sticky_yellow',
      'low' => 'graph',
      'flat' => 'looseleaf',
      _ => 'lined',
    };

/// The stock variant id, e.g. lined_03, for this event under the current light.
String stockVariantFor(Event e, MaterialLibrary lib, {bool dusk = false, String? stock}) {
  final want = stock ?? stockFor(e);
  var variants = lib.stockVariants(want, dusk: dusk);
  if (variants.isEmpty) variants = lib.stockVariants('lined', dusk: dusk);
  if (variants.isEmpty) variants = lib.paper.map((p) => p.id).toList();
  if (variants.isEmpty) return '';
  return variants[(hashOf(e.id) >> 8) % variants.length];
}

/// The tear mask for a note, by where it sits in the thread.
///
/// This is the one assignment that is not free to be random. The rule the brief sets is that no
/// two tears visible at once may be the same, and a hash of the event id cannot promise that: with
/// 56 masks and eight notes on screen, two ids collide about a third of the time. So the pool is
/// walked down the thread with a stride that is coprime with its size. Any run of [n] consecutive
/// notes then holds [n] different masks, which makes a repeat within one screen impossible rather
/// than unlikely, and the two phones agree because they agree about the order of the thread.
///
/// The variation an id would have given is carried by the stock, the lift and the tilt instead.
String? tearFor(Event e, MaterialLibrary lib, {bool writable = true, int row = 0}) {
  final masks = writable ? lib.writableTears : lib.tearMasks;
  if (masks.isEmpty) return null;
  final n = masks.length;
  final stride = _coprimeStride(n);
  return masks[((row % n) * stride) % n];
}

int _coprimeStride(int n) {
  for (var s = (n * 0.37).round(); s < n; s++) {
    if (_gcd(s, n) == 1) return s;
  }
  return 1;
}

int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);

/// How far a note lifts off the desk, in millimetres: enough variation that shadows differ.
double liftFor(Event e) => 0.4 + (hashOf(e.id) % 7) * 0.22;

/// A note is never perfectly square to the desk.
double tiltFor(Event e) => ((hashOf(e.id) >> 16) % 100 - 50) / 100.0 * 0.028; // ±1.6°
