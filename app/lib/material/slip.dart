// A piece of paper with something written on it, anywhere outside the thread.
//
// The thread has Note, which is the full rendering of one event. Everything else in the app that
// needs to sit on a piece of paper — a date's ticket stub, a line off a list, a card in the
// calendar, an empty surface with one sentence on it — comes through here, so a module cannot
// quietly become a beige rounded rectangle with a drop shadow while nobody is looking. That is the
// named failure of the whole visual concept, and it is the failure a card widget arrives at by
// default.
import 'package:flutter/material.dart';

import 'assignment.dart';
import 'hands.dart';
import 'library.dart';
import 'marks.dart';
import 'palette.dart';
import 'paper.dart';

/// One slip of paper. [id] is anything stable about the thing on it — an event id, a date id, a
/// surface's name — and it decides which stock the slip is torn from and along which tear, so the
/// same date is the same piece of paper every time it is drawn, on both phones.
class Slip extends StatelessWidget {
  const Slip({
    super.key,
    required this.id,
    required this.child,
    this.row = 0,
    this.stock,
    this.width,
    this.torn = true,
    this.padding = const EdgeInsets.fromLTRB(15, 11, 15, 11),
    this.overlays = const [],
    this.onTap,
    this.onLongPress,
  });

  final String id;
  final Widget child;

  /// Where this slip sits in whatever list it is in: what keeps two slips on one screen from being
  /// torn along the same edge (material/assignment.dart).
  final int row;

  /// A stock name from assets/INDEX.json. Null lets the id pick one.
  final String? stock;
  final double? width;

  /// A whole sheet rather than a torn piece: a card, a stub, something that was cut.
  final bool torn;
  final EdgeInsets padding;
  final List<Widget> overlays;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  static const _stocks = ['index', 'lined', 'looseleaf', 'graph', 'receipt', 'legal'];

  @override
  Widget build(BuildContext context) {
    final lib = MaterialLibrary.loaded ? MaterialLibrary.instance : null;
    final h = hashOf(id);
    final want = stock ?? _stocks[h % _stocks.length];
    var variants = lib?.stockVariants(want) ?? const <String>[];
    if (variants.isEmpty) variants = lib?.stockVariants('lined') ?? const <String>[];
    final stockId = variants.isEmpty ? '' : variants[(h >> 8) % variants.length];

    String? tear;
    if (torn && lib != null && lib.writableTears.isNotEmpty) {
      final masks = lib.writableTears;
      final n = masks.length;
      tear = masks[((row % n) * _stride(n)) % n];
    }

    final piece = PaperPiece(
      stockId: stockId,
      tearId: tear,
      liftMm: 0.5 + (h % 5) * 0.24,
      tilt: ((h >> 16) % 100 - 50) / 100.0 * 0.016,
      width: width,
      stockAlignment: Alignment(((h >> 3) % 100) / 50.0 - 1, ((h >> 11) % 100) / 50.0 - 1),
      stockScale: 1.12,
      padding: padding,
      safe: tear == null || lib == null ? const [0.05, 0.06, 0.05, 0.06] : lib.safeOf(tear),
      overlays: overlays,
      child: child,
    );
    if (onTap == null && onLongPress == null) return piece;
    return GestureDetector(onTap: onTap, onLongPress: onLongPress, child: piece);
  }

  static int _stride(int n) {
    for (var s = (n * 0.37).round(); s < n; s++) {
      if (_gcd(s, n) == 1) return s;
    }
    return 1;
  }

  static int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);
}

/// A torn strip of stock, sized to whatever is written on it.
///
/// This is what the furniture of the app is written on now: the composer, the word `search`, a day
/// separator, a section heading. It exists because of an arithmetic result rather than a taste:
/// the desk plate's grain reaches Y 0.1467, and 4.5:1 against that requires a darker ink at
/// Y -0.006, which is not a hard number to hit so much as a number that does not exist. No ink of
/// any colour is legible on the wood, so `docs/COLOR.md` section 6 forbids the case instead of
/// tuning the pair: no word is set on a rendered ground, and every word in this app is written on
/// a piece of paper.
///
/// A [Slip] is a piece of paper with something *on* it — a date, a line off a list, an empty
/// surface. A [Strip] is smaller and dumber: it is the paper that has to be under a label for the
/// label to be readable at all, and it hugs what it is given rather than taking a width.
///
/// A mark that is not a word may still sit on the wood. A tally stroke, a rule, an arrow, the
/// pencil-stub battery: a shape is recognised by its silhouette and a word by its counters, so the
/// shapes stay on the desk and the sentences come off it.
class Strip extends StatelessWidget {
  const Strip({
    super.key,
    required this.id,
    required this.child,
    this.row = 0,
    this.stock,
    this.padding = const EdgeInsets.fromLTRB(9, 5, 9, 5),
    this.liftMm = 0.35,
  });

  final String id;
  final Widget child;
  final int row;
  final String? stock;
  final EdgeInsets padding;

  /// Lower than a [Slip]'s by default: a strip under a label is lying flat on the desk, not
  /// dropped onto it, and a tall shadow under a heading reads as a floating card.
  final double liftMm;

  /// The stocks a strip is torn from. Narrower than [Slip]'s list on purpose: these are the pale
  /// ones, because a strip is small and a small piece of paper has to carry its ink on less of it.
  static const _stocks = ['index', 'looseleaf', 'lined'];

  @override
  Widget build(BuildContext context) {
    final lib = MaterialLibrary.loaded ? MaterialLibrary.instance : null;
    final h = hashOf(id);
    final want = stock ?? _stocks[h % _stocks.length];
    var variants = lib?.stockVariants(want) ?? const <String>[];
    if (variants.isEmpty) variants = lib?.stockVariants('lined') ?? const <String>[];
    final stockId = variants.isEmpty ? '' : variants[(h >> 8) % variants.length];

    String? tear;
    final masks = lib?.writableTears ?? const <String>[];
    if (masks.isNotEmpty) {
      final n = masks.length;
      tear = masks[((row % n) * Slip._stride(n)) % n];
    }

    return PaperPiece(
      stockId: stockId,
      tearId: tear,
      liftMm: liftMm,
      tilt: ((h >> 16) % 100 - 50) / 100.0 * 0.008,
      stockAlignment: Alignment(((h >> 3) % 100) / 50.0 - 1, ((h >> 11) % 100) / 50.0 - 1),
      stockScale: 1.2,
      padding: padding,
      safe: tear == null || lib == null ? const [0.04, 0.05, 0.04, 0.05] : lib.safeOf(tear),
      child: child,
    );
  }
}

/// An empty surface: one sentence, on a piece of paper, on the desk.
///
/// The brief allows exactly one empty-state artifact, and it is the one place the couple's own
/// voice has to carry the whole screen. Floating grey text in the middle of a desk is a product
/// saying "no items"; a line written on a piece of paper that somebody left there is two people
/// who have not got round to it yet.
///
/// It is a small slip again, and the reason is [RegionPad]. This widget briefly grew into a
/// full-region pad of its own, because `10_first_run.png` is this widget and almost nothing else
/// and it measured `lightness.p50` 0.4093 against a floor of 0.78. That fixed one screen. The
/// sentence in `DIRECTION.md` that the screen was breaking — *each region is a different stack of
/// paper on it* — is about every region, not about the empty ones, so the paper moved down to the
/// shell where it is true of all five and this went back to being a note left on the page.
class EmptySurface extends StatelessWidget {
  const EmptySurface({super.key, required this.id, required this.line, this.aside});

  final String id;
  final String line;

  /// A second, quieter line, in the margin hand.
  final String? aside;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width * 0.72;
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 80),
        child: Slip(
          id: 'empty.$id',
          row: 3,
          width: width,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(line, style: Hands.noor(size: 19)),
              if (aside != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(aside!, style: Hands.margin(size: 14)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The stack of paper a region *is*, under everything that region draws.
///
/// `DIRECTION.md` has said from the beginning that the shell is a desk seen from above and that
/// each region is a different stack of paper on it, and `app.dart` says the same thing one line
/// above where this is used: *the paper underneath does not move; what is on it is exchanged*.
/// There was no paper underneath. Every region drew its contents straight onto the wood, and the
/// measurement said so plainly — on the capture before this one `04_moments` had a median pixel
/// at L 0.4167 and `10_first_run` 0.4093, against `docs/COLOR.md` section 2 asking every room
/// screen for [0.78, 0.95] and at most half its pixels in its own darkest third.
///
/// This is deliberately not a container. It takes no child and clips nothing: it is a sheet drawn
/// behind the region, and the region goes on scrolling over it exactly as it scrolled over the
/// desk. That keeps every region's own layout, its lazy slivers and its scroll position untouched
/// — the gallery's three-column masonry is the shape it is for reasons written down where it
/// lives, and a page under it is not allowed to change them.
///
/// **It has to be as cheap as the desk, and the first version was not.** A [Slip] at full region
/// size is four assets — the stock, the tear mask, the lit edge and the baked shadow — resampled
/// to a whole screen, and three of those stacked put `04_moments` back into the failure its own
/// gallery comment warns about: the blob reads for the prints do not fail, they queue, and the
/// capture caught a screen of paper with the photographs missing. It measured `lightness.p50`
/// 0.9432, which is a number you can get by deleting the content. Re-running that scene with a
/// twelve second wait brought the prints back and proved it timing rather than breakage.
///
/// So: `torn: false`, which drops the mask, the edge and the shadow and leaves the stock — and a
/// pad is a cut edge rather than a torn one anyway. And every sheet takes the *same* id, so it is
/// the same stock and the same variant and therefore one decoded asset painted twice, which is
/// also what a pad literally is: many sheets of one paper. The cost is now the desk's.
///
/// The desk still shows at the margin, and that is not a leftover. A stack of paper on a desk has
/// to be *on* something or the screen is a page rather than a surface, which is the anti-goal the
/// whole visual concept is defined against.
class RegionPad extends StatelessWidget {
  const RegionPad({super.key, required this.id, this.row = 0});

  /// Which region this is. It picks the stock, so Moments is the same paper every time it is
  /// turned to and a different paper from Us — five regions, five stacks, which is what the
  /// sentence in DIRECTION.md actually says.
  final String id;
  final int row;

  /// The stocks a region pad is torn from.
  ///
  /// Its own list, and narrower than [Slip]'s, because a pad is the only sheet in this app that
  /// is the whole screen and the stocks are not all the same shape. `receipt` is the one that
  /// mattered: `receipt_01` is a 702x1500 render of a till roll, and the PWA drew it as the
  /// backing of two regions for the life of the build -- narrow, smooth, no printed rules and
  /// almost no tooth, stretched 1.94x across the screen, which is a flat cream rectangle and the
  /// named failure of the whole visual concept. `index` is left out for the same reason and it is
  /// worse: `index_02` is 1500x933, landscape, and covering a portrait screen with it magnifies
  /// it 3.27 times.
  ///
  /// What is left is the four full-page portrait stocks plus the spiral one, all of them
  /// 1073x1500, which is one sheet of paper the shape a sheet of paper is.
  static const stocks = ['lined', 'looseleaf', 'graph', 'legal', 'spiral'];

  /// The desk left showing around the pad.
  static const _margin = 12.0;

  /// The sheet under the top one, and how far it shows past the corner. One, not two: each extra
  /// sheet is another full-screen paint for a few millimetres of edge, and what it buys is the
  /// only mid tone a screen of paper on wood has. `value_bands.mid` has a floor of 0.04 in
  /// section 2 and this does not reach it on its own — see the journal for firing 3.
  static const _peek = 7.0;
  static const _under = 1;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      // The pad never changes while a region is on screen, but without this it is re-rasterised
      // into the same layer as everything that scrolls over it, so a full-screen sheet is
      // repainted on every frame of a scroll. That is what the prints in the gallery were losing
      // their raster budget to. Behind a boundary it is rasterised once and composited.
      child: RepaintBoundary(
        child: IgnorePointer(
        child: LayoutBuilder(
          builder: (context, box) {
            final outerW = box.maxWidth - _margin * 2;
            final outerH = box.maxHeight - _margin * 2;
            if (!outerW.isFinite || !outerH.isFinite) return const SizedBox.shrink();
            if (outerW <= _peek * _under || outerH <= _peek * _under) {
              return const SizedBox.shrink();
            }
            final sheetW = outerW - _peek * _under;
            final sheetH = outerH - _peek * _under;
            // One id for every sheet: same stock, same variant, one decode, painted twice.
            final sheet = Slip(
              id: 'pad.$id',
              row: row,
              stock: stocks[hashOf('pad.$id') % stocks.length],
              width: sheetW,
              torn: false,
              padding: EdgeInsets.zero,
              child: SizedBox(width: sheetW, height: sheetH),
            );
            return Padding(
              padding: const EdgeInsets.all(_margin),
              // The under-sheet is offset down and right, so the stack occupies exactly outerW by
              // outerH and no sheet is clipped at the Stack's edge.
              child: Stack(
                children: [
                  for (var i = _under; i >= 1; i--)
                    Positioned(left: _peek * i, top: _peek * i, child: sheet),
                  Positioned(left: 0, top: 0, child: sheet),
                ],
              ),
            );
          },
        ),
        ),
      ),
    );
  }
}

/// The paper that comes up from the bottom edge when a note is asked what can be done to it.
///
/// A modal sheet arrives at a flat rectangle by default, and that is what this was: one uniform
/// fill at L=235, sharp-cornered, with "reply" and "react" written on bare colour — a flat surface
/// standing in for paper in the one place the reader is asked to act on a note. So it is a piece
/// of paper now, torn like every other piece, carrying the edge light and the contact shadow out
/// of the same render, with the desk showing around it.
///
/// [id] decides the stock and the tear, so the same question is always asked on the same slip.
class DeskSheet extends StatelessWidget {
  const DeskSheet({super.key, required this.id, required this.child, this.row = 5});

  final String id;
  final Widget child;
  final int row;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(width * 0.055, 10, width * 0.055, 18),
        child: Slip(
          id: 'sheet.$id',
          row: row,
          width: width * 0.89,
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          child: child,
        ),
      ),
    );
  }
}

/// A question, on a slip, rather than in a dialog box.
///
/// AlertDialog is a rounded rectangle with a flat fill and an elevation shadow under it, which is
/// the failure the whole visual concept is defined against. The question goes on paper like
/// everything else the app says.
Future<String?> askOnPaper(
  BuildContext context, {
  required String id,
  required String hint,
  required TextStyle hand,
  String initial = '',
  String keepWord = 'keep',
  String? leaveWord,
}) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    barrierColor: const Color(0x2E3A2A1C),
    builder: (ctx) => Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 26),
        child: Material(
          type: MaterialType.transparency,
          child: Slip(
            id: 'ask.$id',
            row: 4,
            width: MediaQuery.sizeOf(ctx).width * 0.82,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: c,
                  autofocus: true,
                  style: hand,
                  cursorColor: Pen.graphite,
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: Hands.margin(size: 16),
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onSubmitted: (v) => Navigator.pop(ctx, v),
                ),
                const Padding(padding: EdgeInsets.only(top: 6, bottom: 8), child: RuleLine(seed: 63)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (leaveWord != null)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.pop(ctx),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 4, 18, 4),
                          child: Text(leaveWord, style: Hands.margin(size: 15)),
                        ),
                      ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.pop(ctx, c.text),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 4, 2, 4),
                        child: Text(keepWord, style: Hands.margin(size: 15)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
