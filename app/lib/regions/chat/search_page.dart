// Searching a year of it.
//
// This was a Material Scaffold with an AppBar, chips and ListTiles for a long time — the last
// screen in the app still wearing the framework's own clothes, which is why the artifact of it
// showed no field, no query and no filters that anybody could see. It is a desk now: what you are
// looking for is written on a slip at the top in your own hand, the facets are the stamped tabs
// down the side of a card index, and every hit is a torn strip with the line on it.
import 'package:flutter/material.dart';

import '../../material/assignment.dart';
import '../../material/desk.dart';
import '../../material/hands.dart';
import '../../material/library.dart';
import '../../material/marks.dart';
import '../../material/paper.dart';
import '../../material/palette.dart';
import '../../material/slip.dart';
import '../../scope.dart';
import '../../spine/spine.dart';
import '../../voice/strings.dart';
import 'renderers.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, this.initialQuery = ''});
  final String initialQuery;

  /// Opens the search on its own desk and returns the id of the hit that was tapped, or null.
  static Future<String?> open(BuildContext context, {String query = ''}) =>
      Navigator.of(context).push<String>(PageRouteBuilder<String>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 160),
        // Material, because there is no Scaffold on this route and a Text with no Material over
        // it anywhere is drawn by Flutter in red under a double yellow underline — a diagnostic,
        // painted in release too. It put sixty-three thousand pure #FFFF00 pixels through the
        // search results and twelve thousand through the photograph's caption, two lines under
        // every line of writing, and it read as a design decision rather than as the error it is.
        // Transparency, so the desk is still what is under the page.
        pageBuilder: (_, _, _) => Material(
          type: MaterialType.transparency,
          child: SearchPage(initialQuery: query),
        ),
      ));

  @override
  State<SearchPage> createState() => SearchPageState();
}

class SearchPageState extends State<SearchPage> {
  late final TextEditingController _ctl = TextEditingController(text: widget.initialQuery);
  List<SearchHit> _hits = const [];
  String? _typeFilter;
  Person? _author;
  DateTimeRange? _range;

  /// The facets, in the words the app uses for them elsewhere.
  static const Map<String, String> _facets = {
    'written': 'message',
    'photographs': 'photo',
    'video': 'video',
    'talking': 'voice_note',
    'feelings': 'feeling',
    'dates': 'date_event',
    'the list': 'todo_event',
    'state': 'state_declared',
  };

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _run());
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  /// Runs the query. Public so the capture harness drives the real thing rather than a stand-in.
  void run(String q) {
    _ctl.text = q;
    _run();
  }

  void _run() {
    final scope = AppScope.of(context);
    var hits = scope.spine.search(_ctl.text,
        types: _typeFilter == null ? null : {_typeFilter!}, author: _author);
    final r = _range;
    if (r != null) {
      hits = hits
          .where((h) =>
              h.event.ts >= r.start.millisecondsSinceEpoch &&
              h.event.ts <= r.end.millisecondsSinceEpoch)
          .toList();
    }
    setState(() => _hits = hits);
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final lib = MaterialLibrary.loaded ? MaterialLibrary.instance : null;
    final width = MediaQuery.sizeOf(context).width;
    // The desk this is on is this page's own desk, not the thread's showing through a scrim.
    //
    // It was opaque: false with a forty per cent barrier, on the reasoning that a search is
    // something you do while holding your place. What that actually produced was every note of the
    // conversation legible *between* the results — `end off.`, `Thu 3 Sep 16:55 sent`, `you the
    // better one, which is` — a year of somebody else's sentences interleaved with the eight this
    // page found. Holding your place is what the Navigator does; it does not need to be visible.
    return Desk(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // what you are looking for, written down
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Slip(
              id: 'search_query',
              width: width - 28,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Stamped('looking for', size: 9, colour: Pen.margin),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _ctl,
                      autofocus: true,
                      style: Hands.of(scope.me, size: 22),
                      cursorColor: Pen.ballpoint,
                      cursorWidth: 1.2,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        hintText: S.searchHint,
                        hintStyle: Hands.margin(size: 18),
                      ),
                      onChanged: (_) => _run(),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 10, bottom: 2),
                      child: Mark.cross(size: 15, seed: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // the tabs down the side of a card index: what kind, and whose
          //
          // They were one horizontal list, and nine tabs do not fit across a phone: five were on
          // screen, the fifth (`TALKING`) was cut off at the right edge of the frame, and four --
          // `FEELINGS`, `DATES`, `THE LIST`, `STATE` -- were not drawn at all, with nothing on the
          // screen to say the row moved. A card index shows you all of its tabs; that is what a
          // tab is for. They wrap.
          //
          // And wrapping was not enough on its own, which took nine firings to see. A `Wrap`
          // hands each child its own maxWidth rather than an unbounded one, and a `PaperPiece`
          // with a bounded width fills it -- so every tab came out the full width of the line and
          // the `Wrap` fitted exactly one to a row. Nine tabs became thirteen full-width torn
          // strips stacked down 63% of the frame with one and a half results underneath, which
          // is the same defect as the cut-off horizontal row wearing the opposite clothes.
          // `hug: true` on the slip is the whole of the fix.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 0,
              runSpacing: 2,
              children: [
                _Tab(
                  label: 'everything',
                  on: _typeFilter == null,
                  onTap: () {
                    _typeFilter = null;
                    _run();
                  },
                ),
                for (final f in _facets.entries)
                  _Tab(
                    label: f.key,
                    on: _typeFilter == f.value,
                    onTap: () {
                      _typeFilter = _typeFilter == f.value ? null : f.value;
                      _run();
                    },
                  ),
                const SizedBox(width: 10),
                for (final p in Person.values)
                  _Tab(
                    label: p.name,
                    on: _author == p,
                    onTap: () {
                      _author = _author == p ? null : p;
                      _run();
                    },
                  ),
                _Tab(
                  label: _range == null ? 'this year' : 'that month',
                  on: _range != null,
                  onTap: () {
                    final now = scope.clock.now();
                    _range = _range == null
                        ? DateTimeRange(
                            start: DateTime(now.year, now.month - 1, 1), end: now)
                        : null;
                    _run();
                  },
                ),
              ],
            ),
          ),

          Expanded(
            child: _ctl.text.isEmpty
                ? const EmptySurface(id: 'search', line: S.searchHint, aside: S.searchAside)
                : _hits.isEmpty
                    ? const EmptySurface(id: 'search_none', line: S.searchNothing,
                        aside: S.searchNoneAside)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 40),
                        itemCount: _hits.length,
                        itemBuilder: (context, i) => _Hit(
                          hit: _hits[i],
                          row: i,
                          lib: lib,
                          me: scope.me,
                          query: _ctl.text,
                          onTap: () => Navigator.of(context).pop(_hits[i].event.id),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

/// One stamped tab. Never a count on it: what a filter narrows to is the list under it.
class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.on, required this.onTap});
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
          child: Slip(
            id: 'facet_$label',
            stock: 'index',
            // A tab is the width of the word stamped on it. Without this the slip fills the
            // width the `Wrap` offers, the `Wrap` fits one tab to a line, and thirteen tabs
            // become thirteen full-width strips down 63% of the screen with the results
            // underneath them. PaperPiece.hug is the whole of the fix.
            hug: true,
            padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
            child: Stamped(label, size: 9.5, colour: on ? Pen.stamp : Pen.margin),
          ),
        ),
      );
}

/// One hit: a torn strip with the line on it and the day it was written in the margin.
class _Hit extends StatelessWidget {
  const _Hit({required this.hit, required this.row, required this.lib, required this.me,
    required this.query, required this.onTap});
  final SearchHit hit;
  final int row;
  final MaterialLibrary? lib;
  final Person me;
  final String query;
  final VoidCallback onTap;

  /// The words for a kind of thing, in the same vocabulary the facet tabs down the side use, so
  /// a hit that matched on its kind says `photographs` and not `photo` or `state_declared`.
  static const Map<String, String> _kindWords = {
    'message': 'written',
    'photo': 'photographs',
    'video': 'video',
    'voice_note': 'talking',
    'feeling': 'feelings',
    'reaction': 'feelings',
    'date_event': 'dates',
    'todo_event': 'the list',
    'state_declared': 'state',
    'ritual_kept': 'rituals',
    'milestone': 'dates',
  };

  /// The line under the sentence: the field the term is actually in, or the kind of thing this
  /// is when that is all that matched. Null when the sentence itself carries the match.
  String? get _aside {
    final summary = summaryOf(hit.event, me: me);
    final terms = SearchIndex.tokenize(query);
    if (terms.isEmpty) return null;
    if (SearchIndex.carries(summary, terms)) return null;
    for (final m in hit.matchedIn) {
      if (m != summary) return m;
    }
    final kind = hit.matchedKind;
    if (kind == null) return null;
    return _kindWords[hit.event.type] ?? kind.replaceAll('_', ' ');
  }

  @override
  Widget build(BuildContext context) {
    final e = hit.event;
    final aside = _aside;
    final tear = lib == null ? null : tearFor(e, lib!, row: row);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: PaperPiece(
          // Named, so `12_search.surfaces.json` says how many results were on the desk rather
          // than leaving a reader to guess it from a stock the facet tabs are torn from too.
          id: 'hit.${e.id}',
          stockId: lib == null ? '' : stockVariantFor(e, lib!),
          tearId: tear,
          liftMm: 0.6,
          tilt: tiltFor(e) * 0.5,
          stockAlignment: Alignment(((row % 7) / 3.0) - 1.0, ((row % 5) / 2.0) - 1.0),
          stockScale: 1.15,
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 7),
          safe: lib == null || tear == null
              ? const [0.06, 0.07, 0.06, 0.07]
              : lib!.safeOf(tear),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _Marked(text: summaryOf(e, me: me), query: query, by: e.author),
              // What it matched on, when the sentence above shows none of it. `ritual_kept`
              // prints `title . kept` and its note is indexed and never drawn, so a search for
              // `rain` put `text when home . kept` on the desk with nothing on it to see, and a
              // hit you cannot see the match in is indistinguishable from a wrong answer.
              if (aside != null) ...[
                const SizedBox(height: 3),
                _Marked(text: aside, query: query, by: e.author, size: 14, colour: Pen.margin),
              ],
              const SizedBox(height: 3),
              Text(timeLabel(e.ts), style: Hands.margin(size: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The line, with the words you were looking for gone over in highlighter.
class _Marked extends StatelessWidget {
  const _Marked(
      {required this.text, required this.query, required this.by, this.size = 17, this.colour});
  final String text;
  final String query;
  final Person by;
  final double size;
  final Color? colour;

  @override
  Widget build(BuildContext context) {
    var style = Hands.of(by, size: size);
    if (colour != null) style = style.copyWith(color: colour);
    // Word by word, the way the index matched, rather than the whole query as one literal
    // substring. Two words that are both in the line but not next to each other in it -- which is
    // most of what anybody types into a search box -- highlighted nothing at all, and the last
    // word of a query is a prefix while somebody is still typing, so `ros` matched `roster` in
    // the index and lit nothing on the paper.
    final spans = SearchIndex.spansOf(text, query);
    if (spans.isEmpty) {
      return Text(text, style: style, maxLines: 3, overflow: TextOverflow.ellipsis);
    }
    final out = <TextSpan>[];
    var at = 0;
    for (final (start, end) in spans) {
      if (start > at) out.add(TextSpan(text: text.substring(at, start)));
      out.add(TextSpan(
        text: text.substring(start, end),
        style: const TextStyle(backgroundColor: Accent.highlighterYellow),
      ));
      at = end;
    }
    if (at < text.length) out.add(TextSpan(text: text.substring(at)));
    return Text.rich(TextSpan(style: style, children: out),
        maxLines: 3, overflow: TextOverflow.ellipsis);
  }
}
