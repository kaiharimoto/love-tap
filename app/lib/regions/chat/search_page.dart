// Searching a year of it.
//
// This was a Material Scaffold with an AppBar, chips and ListTiles for a long time — the last
// screen in the app still wearing the framework's own clothes, which is why the artifact of it
// showed no field, no query and no filters that anybody could see. It is a desk now: what you are
// looking for is written on a slip at the top in your own hand, the facets are the stamped tabs
// down the side of a card index, and every hit is a torn strip with the line on it.
import 'package:flutter/material.dart';

import '../../material/assignment.dart';
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

  /// Opens the sheet over the desk and returns the id of the hit that was tapped, or null.
  ///
  /// The sheet is drawn over the thread rather than replacing it, because a search is something
  /// you do while holding your place, and because the desk has to still be under it.
  static Future<String?> open(BuildContext context, {String query = ''}) =>
      Navigator.of(context).push<String>(PageRouteBuilder<String>(
        opaque: false,
        barrierColor: const Color(0x66120D08),
        transitionDuration: const Duration(milliseconds: 160),
        pageBuilder: (_, __, ___) => SearchPage(initialQuery: query),
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
    return ColoredBox(
      color: Colors.transparent,
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
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
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

  @override
  Widget build(BuildContext context) {
    final e = hit.event;
    final tear = lib == null ? null : tearFor(e, lib!, row: row);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: PaperPiece(
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
  const _Marked({required this.text, required this.query, required this.by});
  final String text;
  final String query;
  final Person by;

  @override
  Widget build(BuildContext context) {
    final style = Hands.of(by, size: 17);
    final q = query.trim().toLowerCase();
    if (q.isEmpty || !text.toLowerCase().contains(q)) {
      return Text(text, style: style, maxLines: 3, overflow: TextOverflow.ellipsis);
    }
    final spans = <TextSpan>[];
    var at = 0;
    final lower = text.toLowerCase();
    while (true) {
      final i = lower.indexOf(q, at);
      if (i < 0) {
        spans.add(TextSpan(text: text.substring(at)));
        break;
      }
      if (i > at) spans.add(TextSpan(text: text.substring(at, i)));
      spans.add(TextSpan(
        text: text.substring(i, i + q.length),
        style: const TextStyle(backgroundColor: Accent.highlighterYellow),
      ));
      at = i + q.length;
    }
    return Text.rich(TextSpan(style: style, children: spans),
        maxLines: 3, overflow: TextOverflow.ellipsis);
  }
}
