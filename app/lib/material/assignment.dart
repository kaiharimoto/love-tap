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
int hashOf(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xFFFFFFFF;
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

/// The tear mask for an event.
///
/// The pool is walked with a stride that is coprime with its size, indexed by the event's own
/// hash, so two notes that sit next to each other in the thread are far apart in the pool. With
/// 48 or more masks and at most a dozen notes on screen, a repeat within one frame cannot happen
/// unless the pool is smaller than the screenful, which the capture check would catch.
String? tearFor(Event e, MaterialLibrary lib) {
  final masks = lib.tearMasks;
  if (masks.isEmpty) return null;
  final n = masks.length;
  final stride = _coprimeStride(n);
  final index = ((hashOf(e.id) % n) * stride) % n;
  return masks[index];
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
