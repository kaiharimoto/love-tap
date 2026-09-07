// Searching a year of it.
//
// This was a Material Scaffold with an AppBar, chips and ListTiles for a long time — the last
// screen in the app still wearing the framework's own clothes, which is why the artifact of it
// showed no field, no query and no filters that anybody could see. It is a desk now: what you are
// looking for is written on a slip at the top in your own hand, the facets are the stamped tabs
// down the side of a card index, and every hit is a torn strip with the line on it.
import 'package:flutter/material.dart';

import '../../capture/bus.dart';
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
  const SearchPage({super.key, this.initialQuery = '', required this.onDone});
  final String initialQuery;

  /// Called with the id of the hit that was tapped, or null when the search is put away.
  ///
  /// The search used to be a route of its own, pushed over the whole app on an opaque page with
  /// its own desk — so the region strip, the tabs and the feeling corner all went, and the
  /// critics saw a different app. It is a surface in the Chat region now: the thread's place is
  /// held by the region, the shell stays where it is, and the desk under the results is the desk.
  final ValueChanged<String?> onDone;

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
    // The search artifact's report used to be a stale snapshot of the thread underneath it: the
    // capture hooks dispatch on the region index, which is still Chat while the search page is
    // up, and the chat report reads the scroll positions of a list that is no longer mounted. So
    // the record for 12_search said which nine notes were visible in a thread nobody was looking
    // at. The page that is on the glass says what it is showing.
    CaptureBus.searchReport = () => {
          'query': _ctl.text,
          'hits': _hits.length,
          'type_filter': _typeFilter,
          'author': _author?.name,
          'range': _range == null
              ? null
              : {
                  'from': _range!.start.toIso8601String(),
                  'to': _range!.end.toIso8601String(),
                },
          'order': [for (final h in _hits.take(12)) h.event.id],
          'kinds': {
            for (final k in {for (final h in _hits) h.event.type})
              k: _hits.where((h) => h.event.type == k).length,
          },
        };
    if (widget.initialQuery.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _run());
    }
  }

  @override
  void dispose() {
    CaptureBus.searchReport = null;
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
    // On the region's own desk, in the thread's place: not a translucent page with a year of
    // somebody else's sentences legible between the results, and not an opaque page of its own
    // that takes the shell with it.
    return Material(
      type: MaterialType.transparency,
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
                    behavior: HitTestBehavior.opaque,
                    onTap: () => widget.onDone(null),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 10, bottom: 2),
                      child: Mark.cross(size: 15, seed: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // The tabs down the side of a card index: what kind, and whose. They used to run off the
          // right edge of the screen — TALKING cut through its last letter, four more never seen —
          // with nothing to say there was more. A card index does not scroll sideways: every tab
          // is on the box at once, in as many rows as it takes.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Wrap(
              alignment: WrapAlignment.start,
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
                          onTap: () => widget.onDone(_hits[i].event.id),
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
        behavior: HitTestBehavior.opaque,
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(timeLabel(e.ts), style: Hands.margin(size: 11)),
                  // a hit whose line does not carry the words says where they were found: a
                  // photograph found by its caption, a feeling found by its name, a date by its
                  // title. Without this a result with nothing marked on it read as a mistake.
                  if (reasonFor(e, query, me: me) case final why?) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(why, style: Hands.margin(size: 11), maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ],
              ),
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


/// Why this event is a hit for [query], when the line shown for it does not contain the words.
/// Null when it does — the highlighter is the reason then.
String? reasonFor(Event e, String query, {required Person me}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return null;
  if (summaryOf(e, me: me).toLowerCase().contains(q)) return null;
  const words = {
    'photo': 'a photograph', 'video': 'a video', 'voice_note': 'something said', 'feeling': 'a feeling',
    'date_event': 'a date', 'todo_event': 'the list', 'state_declared': 'a state', 'message': 'written',
    'milestone': 'a milestone', 'reaction': 'a reaction', 'ritual_kept': 'a ritual',
  };
  final kind = words[e.type] ?? e.type.replaceAll('_', ' ');
  if (kind.toLowerCase().contains(q) || e.type.toLowerCase().contains(q)) return 'found as $kind';
  for (final entry in e.payload.entries) {
    final v = entry.value;
    if (v is String && v.toLowerCase().contains(q)) {
      final field = entry.key.replaceAll('_', ' ').replaceAll(' id', '');
      return 'found in its $field: $v';
    }
    if (v is List && v.any((x) => x is String && x.toLowerCase().contains(q))) {
      return 'found in its ${entry.key.replaceAll('_', ' ')}';
    }
  }
  return 'found as $kind';
}
