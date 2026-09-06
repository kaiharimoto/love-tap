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

/// The stock a kind of event is always on, wherever it is drawn — null for the kinds that take
/// their paper from whoever wrote them.
///
/// The modules used to each pick their own: a date was a receipt in Us and an index card in the
/// thread, so the same evening was two different pieces of paper depending on which way you had
/// come to it. One list, read by both.
String? stockForType(String type) => switch (type) {
      'ping' => 'index',
      'milestone' => 'index',
      'date_event' => 'index',
      'passed_on' => 'index',
      'todo_event' => 'looseleaf',
      'ritual_kept' => 'graph',
      _ => null,
    };

/// The stock a note is torn from, by author and type.
String stockFor(Event e) {
  final h = hashOf(e.id);
  final byType = stockForType(e.type);
  if (byType != null) return byType;
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
/// The torn edge a note has. A property of the note, like its lift and its tilt — not of the row
/// it happens to be sitting in.
///
/// It was the row index alone, which is wrong in both directions at once. A surface that draws
/// every row at the same index gave every piece the same edge: a completeness pass found one mask
/// repeated twelve times down the search results, which is the tiled-texture failure the anti-goal
/// forbids. And the same event torn one way in search and another way in the thread said the two
/// surfaces were looking at two different pieces of paper. So the row does not come into it at
/// all: the same note is the same piece of paper wherever you meet it, and two notes that happen
/// to hash together is what happens when fifty edges are shared among fourteen thousand notes.
String? tearFor(Event e, MaterialLibrary lib, {bool writable = true, int row = 0}) {
  final masks = writable ? lib.writableTears : lib.tearMasks;
  if (masks.isEmpty) return null;
  final n = masks.length;
  final stride = _coprimeStride(n);
  // The event's own sequence number, which is the same on both phones and on every surface that
  // draws it. Hashing the id instead is just as stable and collides: fifty masks among eight
  // notes on a screen is a coin flip, and the chat hero's standard is that no edge appears twice.
  // Consecutive events cannot collide on a sequence number, and notes on a screen are nearly
  // consecutive. A pending event has no sequence yet, so it falls back to its id.
  final at = e.seq ?? hashOf(e.id);
  return masks[((at % n) * stride) % n];
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
