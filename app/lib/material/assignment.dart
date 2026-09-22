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
/// 47 writable masks and eight notes on screen, two ids collide about a third of the time. So the
/// pool is walked down the thread with a stride that is coprime with its size. Any run of [n]
/// consecutive notes then holds [n] different masks, which makes a repeat within one screen
/// impossible rather than unlikely, and the two phones agree because they agree about the order of
/// the thread.
///
/// The variation an id would have given is carried by the stock, the lift and the tilt instead.
///
/// [lane] is which list the row is a row of; see [TearLane].
String? tearFor(Event e, MaterialLibrary lib,
        {bool writable = true, int row = 0, TearLane lane = TearLanes.thread}) =>
    tearAt(lib, lane: lane, row: row, writable: writable);

/// Where a list starts its walk of the mask pool.
///
/// **A row is a position in one list, and a screen holds several.** `tearAt` indexes the pool by
/// the row alone, so row 1 of the dates and row 1 of the todos were the same mask — and firing 41
/// measured that this, and not the row-0 default the item was filed against, is the bulk of the
/// repeats: `03_us` paired `us.body.dates` with `date_ferry` on one mask and three more pieces on
/// another, `05_settings` paired `heading-the-two-phones` with `settings.notify`, `10_first_run`
/// paired `search-affordance` with `empty.chat`. Each screen's several lists all number from zero
/// and collide pairwise down their length.
///
/// A lane is the namespace that fixes it: the list says which lane it is, and the walk starts at
/// that lane's [base]. [span] is how many rows the lane may show before it would reach the next
/// one, and a list longer than its span wraps inside its own window rather than walking into its
/// neighbour's — a repeat far down one list, which is not what the brief forbids, instead of two
/// adjacent pieces sharing an edge, which is.
///
/// **Lanes that can be on screen together must not overlap, and the comment on each says where it
/// appears.** The invariant is not held by this table, which cannot see a screen: it is held by
/// `a_screen_tears_every_piece_differently_test`, which pumps each screen and reads the tears it
/// actually drew. Lanes that are never co-visible reuse the same window on purpose — the pool is
/// 47 masks and `12_search` draws 41 pieces into one frame, so there is not room to give every
/// lane in the app a window of its own.
class TearLane {
  const TearLane(this.name, this.base, this.span);

  final String name;

  /// Where this lane starts in the walk.
  final int base;

  /// How many rows it may show before it would reach the next lane.
  final int span;

  int rowAt(int row) => base + (row.abs() % span);

  @override
  String toString() => 'TearLane($name @$base+$span)';
}

/// Every lane in the app, in one place, because a base that is chosen next to its call site is a
/// base nobody can check against the others. Firing 40's `_chromeRow = 23` / `_tabRowOffset = 24`
/// on the search page was this table hand-rolled for one screen, which is why it worked there and
/// why nothing else got it.
///
/// **The layout, over the 47 writable masks.** Lanes on one line are never on screen together and
/// share their window on purpose; the pool is not big enough to give all sixteen a window of their
/// own, because `12_search` draws 41 pieces into one frame.
///
///     0-13   thread | hits                 the long list of whichever page is open
///     0-27   moments                       the moments list, which is neither
///     0-2    setup                         the setup sheets, on a screen with nothing else
///     0-4    dates      5-9  todos         Us: five modules on one scroller, so five windows
///     10-13  shelf      14-17 rituals      (rituals and calendar sit under `margins`, which is
///     18-21  calendar                       never on Us)
///     14-27  margins                       chat, search and the viewer
///     22-27  sections                      Us's section sheets; `margins` is never on Us
///     28-40  tabs                          search's facets and moments' views; not with headings
///     28-33  headings                      every screen with sections; not search, not moments
///     41-44  chrome                        the fixed furniture of a region, everywhere
///     45     composer      46  pads        one each, everywhere
///     0-9    panels                        settings' sheets, on a screen with no long list
class TearLanes {
  /// The chat thread's notes.
  static const thread = TearLane('thread', 0, 14);

  /// The search results. Never on screen with the thread — the search page is its own page.
  static const hits = TearLane('hits', 0, 14);

  /// The moments list. Never on screen with the thread or the hits, and nothing else is on that
  /// screen below the tabs, so it takes everything up to them: at a span of 10 the gallery's
  /// eleventh print wrapped onto its first and `04_moments` drew one mask twice.
  static const moments = TearLane('moments', 0, 28);

  /// The setup sheets, which took a constant index — which is why `17_setup_pwa` drew both of its
  /// pieces on one mask, the one unambiguous instance of the row-0 default this item was filed
  /// against.
  static const setup = TearLane('setup', 0, 3);

  /// Settings' sheets. Seven of them on one screen, on rows 0, 2, 6, 6, 7, 7 and 8 chosen next to
  /// each other, so three pairs of them were torn identically before the rows were renumbered.
  static const panels = TearLane('panels', 0, 10);

  /// Us: each module numbers its own rows, and they are all on the one scroller.
  static const dates = TearLane('dates', 0, 5);
  static const todos = TearLane('todos', 5, 5);
  static const shelf = TearLane('shelf', 10, 4);
  static const rituals = TearLane('rituals', 14, 4);
  static const calendar = TearLane('calendar', 18, 4);

  /// The margin strips, on chat, on search and in the viewer. These carried `hashOf(item.id)`
  /// where a row goes, which [tearAt]'s own docstring says cannot work: with 47 masks and a dozen
  /// margins on screen two ids collide about a third of the time, and `02_chat` had nine repeats
  /// in one frame with three margins sharing one mask.
  static const margins = TearLane('margins', 14, 14);

  /// Us's section sheets: five sections on one scroller, each of them two sheets, so six rows.
  /// They took the section index straight into the pool alongside every other list on the screen.
  static const sections = TearLane('sections', 22, 6);

  /// Section headings: a strip with a word stamped on it, above a list. There are several on one
  /// screen and they took fixed rows chosen next to each other, so `05_settings` had
  /// `heading-the-two-phones` on the same mask as `settings.notify` and the dates module had its
  /// `ahead` and `been` headers on one row between them.
  static const headings = TearLane('headings', 28, 6);

  /// Tab strips: search's thirteen facets and moments' three views. Firing 40 found all thirteen
  /// search facets on `writableTears[0]` because a `Slip` with no `row` defaults to row 0, and
  /// gave them `_tabRowOffset = 24` — this lane is that offset, in the table where the other
  /// lanes can be checked against it.
  static const tabs = TearLane('tabs', 28, 13);

  /// The fixed chrome of a region. The default, so a piece that never says where it sits lands
  /// here rather than on `writableTears[0]`.
  static const chrome = TearLane('chrome', 41, 4);

  /// The composer, which is a list of one and still has a row.
  static const composer = TearLane('composer', 45, 1);

  /// The region pad — the stack of sheets the whole screen is on. One per region and never two at
  /// once, so one row is enough.
  static const pads = TearLane('pads', 46, 1);

  static const all = [
    thread, hits, moments, setup, panels, dates, todos, shelf, rituals, calendar,
    margins, sections, headings, tabs, chrome, composer, pads,
  ];
}

/// **The one place the mask pool is indexed.** It was six: `tearFor` here, the walk copied into
/// `Slip.build` and `Strip.build`, `stockForMood`'s neighbour in `desk.dart` keying off a hash of
/// the mood, `pulse_region.dart`'s `(partner.index * 7 + 11)`, and `setup_region.dart`'s constant
/// `writableTears[3]`. Three of the six took no row at all, so the rule this file states — the
/// pool is walked by row — was stated in one place and implemented in six, and a namespace could
/// not be expressed at the three that had nowhere to put it. `the_pool_is_indexed_in_one_place_test`
/// is what keeps it at one.
String? tearAt(MaterialLibrary? lib, {required TearLane lane, int row = 0, bool writable = true}) {
  if (lib == null) return null;
  final masks = writable ? lib.writableTears : lib.tearMasks;
  if (masks.isEmpty) return null;
  final n = masks.length;
  final stride = _coprimeStride(n);
  return masks[((lane.rowAt(row) % n) * stride) % n];
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
