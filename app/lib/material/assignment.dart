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
  const TearLane(this.name, this.base, this.span,
      {this.wraps = true, this.phase = 0, this.spare = false});

  final String name;

  /// Where this lane starts in the walk.
  final int base;

  /// How many rows it may show before it would reach the next lane.
  final int span;

  /// Whether a row past the end of this lane may quietly come back to its start.
  ///
  /// **True for a list, false for furniture, and firing 48 is what the difference cost.** A list
  /// is as long as its content and its span is a window on it, so the fifteenth note in a
  /// fourteen-row lane wraps onto the first — a repeat far down one list, which is not what the
  /// brief forbids. A lane of fixed furniture has no length: every row in it is a named piece
  /// written down in [ChromeRows], and a row past the end is a piece nobody allocated.
  ///
  /// It wrapped silently, and `% span` then folded rows that were CHOSEN to be distinct onto each
  /// other. `chrome` had a span of 4; [PartnerStrip] asked for `4 + partner.index` and pulse's
  /// their-sheet for `partner.index`, and `(4 + i) % 4 == i % 4`, so the `+ 4` that was there to
  /// separate the two lanes was exactly annihilated by the modulus. On firing 47's capture that
  /// is `01_pulse`, `12_search` and `14_media_viewer` each drawing `tear_049` twice, and
  /// `14_media_viewer` drawing `tear_011` twice as well; `10_first_run` drew `tear_053` twice for
  /// the simpler reason that two call sites both wrote `row: 3`.
  ///
  /// Which is the lane table's own defect one level down. Its docstring says a base chosen next
  /// to its call site is a base nobody can check against the others — and then left every row
  /// INSIDE the chrome lane to be chosen next to its call site. [ChromeRows] is the other half.
  final bool wraps;

  /// Where in its window a list's row 0 falls. Zero for every lane but the thread's; see there.
  final int phase;

  /// Whether this lane walks the spare masks rather than the writable pool; see
  /// [TearLanes.spare]. Its rows are then indices into `MaterialLibrary.spareTears`, which no
  /// other lane touches, so nothing in the writable pool's row budget is spent on it.
  final bool spare;

  int rowAt(int row) {
    assert(wraps || (row >= 0 && row < span),
        'row $row is outside the $name lane (0..${span - 1}). A furniture lane has one row per '
        'named piece: give it a row in ChromeRows rather than letting the modulus fold it onto '
        'somebody else\'s.');
    return base + ((row.abs() + phase) % span);
  }

  @override
  String toString() => 'TearLane($name @$base+$span)';
}

/// Every lane in the app, in one place, because a base that is chosen next to its call site is a
/// base nobody can check against the others. Firing 40's `_chromeRow = 23` / `_tabRowOffset = 24`
/// on the search page was this table hand-rolled for one screen, which is why it worked there and
/// why nothing else got it.
///
/// **The layout, over the 47 writable masks.** Lanes on one line are never on screen together and
/// share their window on purpose; the pool is not big enough to give all fifteen a window of its
/// own. Measured in-frame off firing 47's committed sidecars, the busiest screen is `12_search`
/// at 27 torn pieces against 47 masks — firing 46's "41 pieces" counted the three layers a piece
/// has declared since firing 44, not the pieces. What IS exactly full is the row budget: 0-27 for
/// the lists, 28-40 for the tabs, 41-46 for the chrome, and nothing spare above them.
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
///     41-46  chrome                        the fixed furniture of a region, everywhere; its six
///                                           rows are named in `ChromeRows`
///     0-9    panels                        settings' sheets, on a screen with no long list
class TearLanes {
  /// The chat thread's notes -- and its margin lines, which are rows of the same list.
  ///
  /// **One window for both, twenty-eight wide, because a row is either a note or a margin and
  /// never both.** The thread had fourteen rows and the margins the fourteen after them, which
  /// held only while an unread note of theirs drew no mask: firing 59 made the folded note a torn
  /// sheet, and `02_chat` then showed fifteen torn thread rows, 8372 and 8386 fourteen apart and
  /// both on `tear_001`. Indexing both kinds by the item's own position in one window of 28 means
  /// no two rows closer than 28 apart can share a mask, whichever of the two each one is.
  ///
  /// The phase of fourteen keeps a note in an odd block of fourteen rows on the mask it had under
  /// the old table, which includes the run `02_chat` is framed on (items 5195-5203 at the scene's
  /// 0.62): the most-measured artifact in the build keeps its notes on the paper it was measured
  /// on, and `the_hero_of_the_set_fits_eight_notes_test` keeps measuring what it was written
  /// against rather than a new set of heights.
  static const thread = TearLane('thread', 0, 28, phase: 14);

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
  ///
  /// They share [thread]'s window: see there.
  static const margins = TearLane('margins', 0, 28, phase: 14);

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

  /// The fixed chrome of a region: the strips, the sheets and the labels that are not a list.
  /// The default, so a piece that never says where it sits lands here rather than on
  /// `writableTears[0]`.
  ///
  /// **Six rows, and it does not wrap.** It had four, and [ChromeRows] names six pieces that can
  /// be on one screen at once — the viewer carries all six. The two extra rows are the ones the
  /// `composer` and `pads` lanes were holding: `composer` is a piece of chrome and is a row of
  /// this lane now rather than a lane of its own, and `pads` was reserving a row for a widget
  /// that draws no mask at all, because [RegionPad] passes `torn: false`.
  static const chrome = TearLane('chrome', 41, 6, wraps: false);

  /// **Furniture torn from the masks nothing else uses, which is how the chrome lane got its
  /// seventh row without taking one from anybody.** The writable pool's row budget is exactly
  /// full (0-27, 28-40, 41-46), and `notice` and `leaf` shared chrome row 3 on a judgement that
  /// the typing line is never up while a page is pushed over chat -- which a capture taken in the
  /// second somebody typed would have broken. Nine masks were outside every pool, their renders
  /// baked and unused; `MaterialLibrary.spareTears` is the ones that are not also scraps, best
  /// writing area first, and a piece that carries one short line fits the first of them:
  /// `tear_017` leaves 92% of the width and 53% of the height inside its safe insets.
  ///
  /// One row today, named in [SpareRows], and it does not wrap.
  static const spare = TearLane('spare', 0, 1, wraps: false, spare: true);

  static const all = [
    thread, hits, moments, setup, panels, dates, todos, shelf, rituals, calendar,
    margins, sections, headings, tabs, chrome, spare,
  ];
}

/// **Every row of [TearLanes.chrome], in one place, for the same reason [TearLanes] itself
/// exists.** A base chosen next to its call site is a base nobody can check against the others;
/// so is a row. Firing 46 put the bases in a table and left the rows where they were, and firing
/// 47's capture still had four screens tearing two pieces along one edge — every one of them two
/// chrome call sites that had each picked a number they could not see each other pick.
///
/// A lane is a namespace for a LIST, where the row is a position and the content decides how many
/// there are. Chrome is not a list. Its rows are a fixed, countable set of pieces, so they are
/// named here and the call sites say which piece they are rather than which number they want.
///
/// **The layout, over the six rows, and lanes on one line are never on screen together.** The
/// invariant is not held by this table, which cannot see a screen: it is held by
/// `a_screen_tears_every_piece_differently_test`, which pumps each screen INSIDE THE SHELL — the
/// [PartnerStrip] that sits above every region is chrome too, and a test that pumps a bare region
/// cannot see the shell collide with it, which is how three of the four repeats survived firing
/// 46's test passing.
///
///     0  partner    the shell's strip, above every region — on every screen, so nobody else's
///     1  composer   chat's composer          | theirs   the pulse's their-sheet
///     2  affordance the search affordance    | mine     the pulse's my-sheet
///     3  leaf       a pushed page's own sheet: search's query, the viewer's caption
///     4  empty      the note an empty region leaves in place of its list
///     5  overlay    what comes up over a screen: a desk sheet, an ask, the way out of the viewer
///
/// **Chat's typing line is not here any more, and that was the one pairing that was a judgement
/// rather than a fact.** It shared row 3 with [leaf] on the reasoning that the line is drawn only
/// while the other person is typing, and no artifact had been taken in that second. But a pushed
/// route does not take its parent out of the tree -- `14_media_viewer.surfaces.json` carries
/// chat's composer behind the viewer -- so search opened while somebody typed would have drawn
/// the query and the typing line on one mask. It is torn from [TearLanes.spare] now, as
/// [SpareRows.notice], and every pair on a line above is impossible by construction: `Turning`
/// keeps one region in the tree, so chat's chrome and the pulse's are never both drawn.
class ChromeRows {
  /// The partner strip in the shell, above every region. It is the only piece of chrome that is
  /// on every screen, so it holds a row of its own and nothing else may take it.
  static const partner = 0;

  /// The chat composer. Never on the pulse, which is why [theirs] shares the row.
  static const composer = 1;

  /// The pulse's sheet for the other person. Never on a screen with the composer.
  static const theirs = 1;

  /// The search affordance, in the chat bar and carried into search and the viewer.
  static const affordance = 2;

  /// The pulse's sheet for you. Never on a screen with the affordance.
  static const mine = 2;

  /// The sheet a pushed page puts up on its own account: what you typed into search, the words
  /// under a photograph in the viewer. A pushed page has at most one.
  static const leaf = 3;

  /// The note a region leaves where its list would be. **It is not the [leaf]**, which is what
  /// firing 48's search case caught within a minute of being written: open search and type
  /// nothing and `search_query` and `empty.search` are both on the glass, so the one row they
  /// shared was a repeat in a state the capture never reaches because the capture types a query.
  static const empty = 4;

  /// What comes up OVER a screen and is gone again: a desk sheet, an ask, the way out of the
  /// viewer. Never two at once.
  static const overlay = 5;
}

/// The rows of [TearLanes.spare], named for the same reason [ChromeRows] are.
class SpareRows {
  /// Chat's typing line under the thread: `Noor is writing`, one line on a strip.
  static const notice = 0;
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
  if (lane.spare) {
    final spare = lib.spareTears;
    return spare.isEmpty ? null : spare[lane.rowAt(row) % spare.length];
  }
  final masks = writable ? lib.writableTears : lib.tearMasks;
  if (masks.isEmpty) return null;
  final n = masks.length;
  final stride = _coprimeStride(n);
  return masks[((lane.rowAt(row) % n) * stride) % n];
}

/// The six masks [TearLanes.chrome] holds, which is every mask that can be on the glass at any
/// moment: chrome is the only lane that is on every screen.
List<String> chromeMasks(MaterialLibrary lib) => [
      for (var r = 0; r < TearLanes.chrome.span; r++)
        tearAt(lib, lane: TearLanes.chrome, row: r) ?? '',
    ];

/// The scrap a feeling object is drawn on — **the seventh place the pool was indexed, and the one
/// the source test could not see.**
///
/// `material/objects.dart` read `final scraps = lib?.scrapTears ?? const []` and then
/// `scraps[hashOf(feeling.id) % scraps.length]`, and `the_pool_is_indexed_in_one_place_test`
/// matches `scrapTears\s*\[` — so binding the getter to a local defeated it and the site survived
/// firing 46 untouched. Firing 48 found it when the tear test was made to pump each region inside
/// the shell: `01_pulse` drew `tear_011` on the pulse's their-sheet and on a feeling object in the
/// day's traffic beside it.
///
/// **The chrome masks are taken out of the pool this chooses from, and that is not a nicety.** 26
/// of the 28 square-ish masks `scrapTears` returns are also in `writableTears`, so a scrap chosen
/// by a hash can land on any lane's mask — and a collision with chrome is not luck, because chrome
/// is on every screen. Removing the six chrome masks makes that class of collision impossible for
/// the cost of one scrap (`tear_011` is the only mask in both sets today).
///
/// **The tab and heading masks are taken out as well, and firing 62 measured why.** Every screen
/// that shows a list of objects shows them under tabs: moments' three views, the feeling corner's
/// family tabs, settings' headings. With the scraps walked by row the objects stopped sharing with
/// each other and the first case written for it found `scrap.goodnight.5` on `tear_050`, which is
/// row 30 of the pool and moments' `what we felt` tab. Leaving out the tabs' window (rows 28-40,
/// which holds the headings too) keeps 19 of the 27 scraps, more than any list shows at once.
///
/// **[row] is where the object sits in the list it is in, and a list passes one.** A hash cannot
/// promise distinctness -- `tearAt`'s own docstring says why -- and this one was picking between
/// 27 scraps for a vocabulary of the same order, so two feelings on one screen could be torn
/// alike, and two of the SAME feeling in the day's traffic always were. So the scrap pool is
/// walked by row with a stride coprime with its size, exactly as the writable pool is: any run of
/// consecutive rows up to the pool's size holds that many different scraps. The scrap pool is its
/// own index space, not a window of the writable one, which has no room left (see [TearLanes]).
///
/// A list that shares a screen with another list of objects numbers into its own block of rows
/// (the reactions on a note take three rows per note). An object that is the only one of its kind
/// on the screen -- the one landing, the preview in the authoring sheet -- passes no row and keeps
/// the hash, which is still the same scrap on both phones.
String? scrapFor(MaterialLibrary? lib, String feelingId, {int? row}) {
  if (lib == null) return null;
  final skip = {...chromeMasks(lib), ..._tabMasks(lib)};
  final scraps = [for (final t in lib.scrapTears) if (!skip.contains(t)) t];
  if (scraps.isEmpty) return null;
  final n = scraps.length;
  if (row == null) return scraps[hashOf(feelingId) % n];
  return scraps[((row.abs() % n) * _coprimeStride(n)) % n];
}

/// The masks the tabs' window of the pool can take, rows 28-40, which the headings share.
List<String> _tabMasks(MaterialLibrary lib) => [
      for (var r = 0; r < TearLanes.tabs.span; r++) tearAt(lib, lane: TearLanes.tabs, row: r) ?? '',
    ];

/// The mask a page-sized sheet laid over a whole region is torn from: the writable mask whose
/// tear leaves the most of the sheet to write on, which none of [avoid] and no chrome mask is.
///
/// **A row cannot choose this, because a row does not know the shape of what it tears.** The
/// feeling sheet first took [ChromeRows.overlay], which walks to `tear_001` -- a 1024x578 strip
/// whose tear may reach 25.5% down from the top and 20.8% up from the bottom. `safe` is a
/// fraction of the piece, and below four times the mask's own size the mask is scaled rather
/// than sliced, so on a sheet the height of a 360x780 region 46% of it was torn band and the
/// vocabulary did not fit in what was left: in 07_feeling_landing Warmth, Ache and Shelter were
/// scrolled off its top. `tear_026` leaves 81% of the area inside its safe insets, `tear_001`
/// 50%. What is under the sheet is covered by it, so the masks that could repeat on the glass
/// are the chrome above it, whatever sits on it ([avoid]), and nothing else.
String? sheetTearFor(MaterialLibrary? lib, {Iterable<String> avoid = const []}) {
  if (lib == null) return null;
  final skip = {...chromeMasks(lib), ...avoid};
  String? best;
  var most = -1.0;
  for (final t in lib.writableTears) {
    if (skip.contains(t)) continue;
    final s = lib.safeOf(t);
    final inside = (1 - s[0] - s[2]) * (1 - s[1] - s[3]);
    if (inside > most) {
      best = t;
      most = inside;
    }
  }
  return best;
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
