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

/// An empty surface: one sentence, on a piece of paper, on the desk.
///
/// The brief allows exactly one empty-state artifact, and it is the one place the couple's own
/// voice has to carry the whole screen. Floating grey text in the middle of a desk is a product
/// saying "no items"; a line written on a piece of paper that somebody left there is two people
/// who have not got round to it yet.
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
