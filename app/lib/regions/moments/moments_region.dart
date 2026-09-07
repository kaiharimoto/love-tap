// Moments: the shared archive, and nothing but a filtered view of the one spine.
//
// There is no second store here and no separate index: every list on this screen is the same
// List<Event> the thread reads, narrowed by person, by date, by type, or by a particular feeling.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';

import '../../capture/bus.dart';
import '../../feelings/builtins.dart';
import '../../feelings/registry.dart';
import '../../material/hands.dart';
import '../../material/marks.dart';
import '../../material/objects.dart';
import '../../material/palette.dart';
import '../../material/slip.dart';
import '../../scope.dart';
import '../../spine/spine.dart';
import '../../voice/strings.dart';
import '../chat/blob_widgets.dart';
import '../../spine/projections/thread.dart';
import '../../thread/renderers.dart';
import '../../material/assignment.dart';

enum MomentsView { media, milestones, feelings }

/// How many tiles the pile has built since it was last reset: the capture report reads it, and
/// the test that the pile is viewport-bound reads it.
class MomentsGalleryStats {
  static int get built => _Gallery.built;
  static void reset() => _Gallery.built = 0;
}

class MomentsRegion extends StatefulWidget {
  const MomentsRegion({super.key});

  @override
  State<MomentsRegion> createState() => _MomentsRegionState();
}

class _MomentsRegionState extends State<MomentsRegion> {
  /// Opens on whichever of the three views has anything in it.
  ///
  /// It opened on media unconditionally, and with the seed's photographs not yet rendered that
  /// meant the one region whose entire job is to show that these are views over a single log
  /// opened on an empty surface, against a year of history.
  MomentsView? _picked;
  MomentsView get _view => _picked ?? _firstWithSomething();
  set _view(MomentsView v) => _picked = v;
  Person? _person;
  String? _feelingId;
  DateTimeRange? _range;

  @override
  void initState() {
    super.initState();
    CaptureBus.momentsReport = _report;
  }

  @override
  void dispose() {
    if (CaptureBus.momentsReport == _report) CaptureBus.momentsReport = null;
    super.dispose();
  }

  Map<String, dynamic> _report() {
    final all = AppScope.of(context).spine.all;
    final counts = {for (final v in MomentsView.values) v.name: all.where((e) => _keepsIn(e, v)).length};
    return {
      'lens': _view.name,
      'lenses': counts,
      'filters': {
        'person': _person?.name,
        'feeling': _feelingId,
        'range': _range == null ? null : [_range!.start.toIso8601String(), _range!.end.toIso8601String()],
      },
      'showing': all.where(_keeps).length,
      'tiles_built': _Gallery.built,
      'blobs': BlobCache.stats(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final registry = scope.feelings;
    final all = scope.spine.all;
    final filtered = all.where(_keeps).toList();
    return Column(
      children: [
        _Filters(
          view: _view,
          person: _person,
          feelingId: _feelingId,
          range: _range,
          registry: registry,
          onView: (v) => setState(() => _view = v),
          onPerson: (p) => setState(() => _person = p),
          onFeeling: (f) => setState(() => _feelingId = f),
          onRange: (r) => setState(() => _range = r),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const EmptySurface(id: 'moments', line: S.emptyMoments, aside: S.emptyMomentsAside)
              : switch (_view) {
                  MomentsView.media => _Gallery(events: filtered),
                  MomentsView.milestones => _Timeline(events: filtered),
                  MomentsView.feelings => _FeelingHistory(events: filtered, registry: registry, me: scope.me),
                },
        ),
      ],
    );
  }

  MomentsView _firstWithSomething() {
    final all = AppScope.of(context).spine.all;
    for (final v in MomentsView.values) {
      if (all.any((e) => _keepsIn(e, v))) return v;
    }
    return MomentsView.media;
  }

  bool _keeps(Event e) => _keepsIn(e, _view);

  bool _keepsIn(Event e, MomentsView view) {
    // Which lens an event belongs in is a facet the type declares, not a set kept here: the set
    // named four of the five kinds of thing that happen and left the shelf out, so a book one of
    // them handed the other was in no lens at all.
    final facets = kEventTypeById[e.type]?.search.facets ?? const <String>[];
    final typeOk = switch (view) {
      MomentsView.media => facets.contains('media'),
      MomentsView.milestones => facets.contains('happened'),
      MomentsView.feelings => facets.contains('feeling'),
    };
    if (!typeOk) return false;
    if (_person != null && e.author != _person) return false;
    if (_feelingId != null && e.payload['feeling_id'] != _feelingId) return false;
    final r = _range;
    if (r != null) {
      final t = DateTime.fromMillisecondsSinceEpoch(e.ts);
      if (t.isBefore(r.start) || t.isAfter(r.end)) return false;
    }
    return true;
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.view,
    required this.person,
    required this.feelingId,
    required this.range,
    required this.registry,
    required this.onView,
    required this.onPerson,
    required this.onFeeling,
    required this.onRange,
  });

  final MomentsView view;
  final Person? person;
  final String? feelingId;
  final DateTimeRange? range;
  final FeelingRegistry registry;
  final ValueChanged<MomentsView> onView;
  final ValueChanged<Person?> onPerson;
  final ValueChanged<String?> onFeeling;
  final ValueChanged<DateTimeRange?> onRange;

  @override
  Widget build(BuildContext context) {
    final now = AppScope.of(context).clock.now().toLocal();
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // three of these across a narrow phone is thirty-five points more than there is, and a
          // filter that runs off the edge of the screen is a filter nobody knows is there
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                for (final v in MomentsView.values)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onView(v),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 14),
                      // stamped straight on the wood, so in the ink that reads on wood: the
                      // chosen lens was Pen.stamp on the desk at under 2:1 and the others fainter
                      child: Stamped.onDesk(
                        switch (v) {
                          MomentsView.media => 'what we sent',
                          MomentsView.milestones => 'what happened',
                          MomentsView.feelings => 'what we felt',
                        },
                        size: v == view ? 12 : 10,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _Chip(label: 'both', on: person == null, onTap: () => onPerson(null)),
                for (final p in Person.values)
                  _Chip(label: p.name, on: person == p, onTap: () => onPerson(p)),
                const SizedBox(width: 12),
                _Chip(
                  label: range == null
                      ? 'all year'
                      : '${DateFormat('d MMM').format(range!.start)}–${DateFormat('d MMM').format(range!.end)}',
                  on: range != null,
                  onTap: () => onRange(
                    range == null
                        ? DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now)
                        : null,
                  ),
                ),
                if (view == MomentsView.feelings) ...[
                  const SizedBox(width: 12),
                  _Chip(
                    label: feelingId == null ? 'any feeling' : feelingId!,
                    on: feelingId != null,
                    onTap: () async {
                      final f = await showModalBottomSheet<Feeling>(
                        context: context,
                        backgroundColor: Colors.transparent,
                        barrierColor: const Color(0x2E3A2A1C),
                        builder: (ctx) => DeskSheet(
                          id: 'which.feeling',
                          row: 8,
                          child: GridView.count(
                            crossAxisCount: 4,
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            children: [
                              for (final f in registry.active)
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => Navigator.pop(ctx, f),
                                  child: Column(
                                    children: [
                                      FeelingObject(feeling: f, size: 52, intensity: 0.6),
                                      Text(
                                        f.name,
                                        style: Hands.margin(size: 10),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                      onFeeling(f?.id == feelingId ? null : f?.id);
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.on, required this.onTap});
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    // a filter is a tab on a sticky note: the one you are on is stuck down, the rest are
    // half-lifted and paler
    padding: EdgeInsets.only(right: 6, top: on ? 0 : 4, bottom: on ? 4 : 0),
    // the one that is on sits up on a yellow sticky; the others are index card, in the same ink:
    // a label that was dimmed to say it was not chosen read at under 4.5:1 against its own paper
    child: Slip(
      id: 'moments.$label',
      row: label.length,
      stock: on ? 'sticky_yellow' : 'index',
      torn: false,
      padding: const EdgeInsets.fromLTRB(11, 5, 11, 6),
      onTap: onTap,
      child: Text(label, style: Hands.margin(size: 13).copyWith(color: Pen.stamp)),
    ),
  );
}

/// Everything they have sent each other, as prints on the desk.
///
/// Not a grid. A grid gives every item the same square hole, and two things go wrong at once: a
/// photograph is centre-cropped to a square, so a wide render of a room becomes an unreadable
/// patch of its middle; and a voice note — a receipt slip four lines tall — sits at the top of a
/// square with a hand's width of bare desk under it. Eleven of those on one screen read as a
/// layout that has failed rather than as a pile of prints.
///
/// So: three columns, each print at its own shape, each new thing laid on whichever column is
/// currently shortest. That is also how a pile actually grows.
///
/// And only the part of the pile that is on screen is built. It used to be a Column of every
/// tile in the year inside one scroll view, which asked the store for a hundred and twenty-nine
/// pictures at once the moment the region opened; fifteen seconds later the visible tiles still
/// said they were fetching, because theirs were somewhere in the middle of the queue. The pile is
/// laid out once, on paper, and a sliver builds the tiles the viewport reaches.
class _Gallery extends StatelessWidget {
  const _Gallery({required this.events});
  final List<Event> events;

  static const columns = 3;
  static const gap = 7.0;

  /// How many tiles have been built since the region opened — the capture report reads it, and
  /// the test that fewer tiles than events are built reads it.
  static int built = 0;

  @override
  Widget build(BuildContext context) {
    final media = events.reversed.toList();
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 90),
          sliver: SliverGrid(
            gridDelegate: _PileDelegate(media),
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                // the layout the delegate made is the one the tile is drawn at, so the two
                // never disagree about a height (they did: the estimate clamped the ratio and
                // the tile did not, and the columns drifted apart by a screen)
                final layout = _PileDelegate.layoutFor(media, _PileDelegate.lastWidth);
                final placed = layout.placed[i];
                built++;
                return _One(event: placed.event, row: placed.row, width: layout.tileWidth, height: placed.height);
              },
              childCount: media.length,
              addAutomaticKeepAlives: false,
              addRepaintBoundaries: true,
            ),
          ),
        ),
      ],
    );
  }

  /// Roughly how tall a thing will be. A print is its own shape; a slip is the few lines that
  /// fit on it. This is the one estimate, and the tile is drawn at exactly this height.
  static double heightOf(Event e, double width) {
    if (e.type == 'voice_note') return 74;
    final w = (e.payload['w'] as num?)?.toDouble() ?? 4;
    final h = (e.payload['h'] as num?)?.toDouble() ?? 3;
    return (width * (h / (w == 0 ? 4 : w)).clamp(0.6, 1.6)).roundToDouble();
  }
}

class _Placed {
  const _Placed(this.event, this.row, this.column, this.top, this.height);
  final Event event;
  final int row;
  final int column;
  final double top;
  final double height;
  double get bottom => top + height;
}

class _PileLayoutData {
  const _PileLayoutData(this.placed, this.tileWidth, this.tallest, this.extent);

  /// In the order the sliver builds them: by top edge, so a scroll offset maps to a run of
  /// indices.
  final List<_Placed> placed;
  final double tileWidth;
  final double tallest;
  final double extent;
}

/// Lays the pile once per width and answers the sliver's questions about it.
class _PileDelegate extends SliverGridDelegate {
  const _PileDelegate(this.events);
  final List<Event> events;

  static double lastWidth = 0;
  static List<Event>? _forEvents;
  static double _forWidth = -1;
  static _PileLayoutData? _cached;

  static _PileLayoutData layoutFor(List<Event> events, double crossAxisExtent) {
    if (identical(events, _forEvents) && _forWidth == crossAxisExtent && _cached != null) return _cached!;
    final width = ((crossAxisExtent - _Gallery.gap * (_Gallery.columns - 1)) / _Gallery.columns).floorToDouble();
    final heights = List.filled(_Gallery.columns, 0.0);
    final placed = <_Placed>[];
    var tallest = 0.0;
    for (final (i, e) in events.indexed) {
      final tall = _Gallery.heightOf(e, width);
      var shortest = 0;
      for (var c = 1; c < _Gallery.columns; c++) {
        if (heights[c] < heights[shortest]) shortest = c;
      }
      placed.add(_Placed(e, i, shortest, heights[shortest], tall));
      heights[shortest] += tall + _Gallery.gap;
      if (tall > tallest) tallest = tall;
    }
    placed.sort((a, b) => a.top.compareTo(b.top));
    final extent = heights.fold(0.0, (m, h) => h > m ? h : m);
    _forEvents = events;
    _forWidth = crossAxisExtent;
    lastWidth = crossAxisExtent;
    return _cached = _PileLayoutData(placed, width, tallest, extent);
  }

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) =>
      _PileLayout(layoutFor(events, constraints.crossAxisExtent));

  @override
  bool shouldRelayout(_PileDelegate old) => !identical(old.events, events);
}

class _PileLayout extends SliverGridLayout {
  const _PileLayout(this.data);
  final _PileLayoutData data;

  @override
  int getMinChildIndexForScrollOffset(double scrollOffset) {
    // tiles are in top order, and no tile is taller than the tallest, so the first one that can
    // still be on screen has its top after offset - tallest
    final placed = data.placed;
    var lo = 0, hi = placed.length;
    final edge = scrollOffset - data.tallest - _Gallery.gap;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (placed[mid].top < edge) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo.clamp(0, placed.isEmpty ? 0 : placed.length - 1);
  }

  @override
  int getMaxChildIndexForScrollOffset(double scrollOffset) {
    final placed = data.placed;
    if (placed.isEmpty) return 0;
    var lo = 0, hi = placed.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (placed[mid].top <= scrollOffset) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return (lo - 1).clamp(0, placed.length - 1);
  }

  @override
  SliverGridGeometry getGeometryForChildIndex(int index) {
    final p = data.placed[index];
    return SliverGridGeometry(
      scrollOffset: p.top,
      crossAxisOffset: p.column * (data.tileWidth + _Gallery.gap),
      mainAxisExtent: p.height,
      crossAxisExtent: data.tileWidth,
    );
  }

  @override
  double computeMaxScrollOffset(int childCount) => data.extent;
}

class _One extends StatelessWidget {
  const _One({required this.event, required this.row, required this.width, required this.height});
  final Event event;
  final int row;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (event.type == 'voice_note') {
      // a voice note in the gallery is the slip it was written on, with its length on it
      return Align(
        alignment: Alignment.topCenter,
        child: Slip(
          id: event.id,
          row: row,
          stock: 'receipt',
          width: width,
          padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
          child: Center(
            child: Text(
              '${((event.payload['duration_ms'] as num) / 1000).round()}s',
              style: Hands.margin(size: 14),
            ),
          ),
        ),
      );
    }
    final poster = event.payload['poster_blob'] as String?;
    // A photograph has no poster_blob and never can — spine/types.dart gives the photo spec
    // required ['blob','w','h'] and validate() rejects unknown keys — so branching on the poster
    // alone sent every photograph in the gallery down the video path. Branch on what the thing is.
    // A video with no poster frame is not a picture, and drawing it as one gave the gallery four
    // blank prints: the report counted twenty-six tiles laid out and eighteen pictures asked for,
    // and the eight it never asked about were holes with nothing loading in them. Frame extraction
    // does not exist on both platforms yet (docs), so until it does a video is what a video is on a
    // desk — a strip with its length written on it and the mark you press.
    if (event.type == 'video' && (poster == null || poster.isEmpty)) {
      final ms = (event.payload['duration_ms'] as num?)?.toDouble();
      return Align(
        alignment: Alignment.topCenter,
        child: Slip(
          id: event.id,
          row: row,
          stock: 'index',
          torn: false,
          width: width,
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 11),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Mark.play(size: 22, colour: Pen.graphite, seed: row),
              const SizedBox(height: 6),
              Text(ms == null ? S.video : '${(ms / 1000).round()}s',
                  style: Hands.margin(size: 14)),
            ],
          ),
        ),
      );
    }
    final hash = (poster != null && poster.isNotEmpty)
        ? poster
        : event.payload['blob'] as String;
    // A print: the picture with a white border of card around it, cut, with the edge and shadow
    // every piece of paper on the desk has. The cut card's safe area and border are solved the
    // way paper.dart solves them, so the print comes out exactly the height the pile laid it at.
    const border = 3.0;
    final inner = Size((width * 0.90 - border * 2).clamp(24.0, width), (height * 0.87 - border * 2).clamp(24.0, height));
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Align(
      alignment: Alignment.topCenter,
      child: Slip(
        id: event.id,
        row: row,
        stock: 'index',
        torn: false,
        width: width,
        padding: const EdgeInsets.all(border),
        child: SizedBox(
          width: inner.width,
          height: inner.height,
          child: BlobImage(
            hash: hash,
            fit: BoxFit.cover,
            cacheWidth: (inner.width * dpr).round(),
            quiet: true,
          ),
        ),
      ),
    );
  }
}

/// What happened: milestones, dates, rituals and new feelings, in order.
///
/// Each one on the same piece of paper it is in the thread on, with the same thing written on it:
/// the renderer the registry names for the type, on the stock material/assignment.dart picks for
/// it, torn along the tear its id picks. It used to be a bare row of text on the wood here, a torn
/// slip in Us and a pencil line in Chat — one event, three surfaces.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.events});
  final List<Event> events;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final list = events.reversed.toList();
    final width = MediaQuery.sizeOf(context).width - 28;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 90),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final e = list[i];
        final spec = kEventTypeById[e.type];
        final draw = spec == null ? null : kThreadRenderers[spec.renderer];
        final item = ThreadItem(
          event: e,
          text: null,
          edited: false,
          deleted: false,
          reactions: const [],
          replyTo: null,
          delivery: Delivery.values.first,
          writtenEarlier: false,
        );
        final body = draw == null
            ? Text((e.payload['title'] ?? e.payload['name'] ?? e.type) as String, style: Hands.of(e.author, size: 17))
            : draw(NoteContext(item: item, registry: scope.feelings, me: scope.me, context: context));
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Slip(
            id: e.id,
            row: i,
            stock: stockFor(e),
            width: width,
            padding: const EdgeInsets.fromLTRB(15, 10, 15, 9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                body,
                const SizedBox(height: 4),
                Text(
                  '${DateFormat('EEE d MMM yy').format(DateTime.fromMillisecondsSinceEpoch(e.ts).toLocal())} · ${e.author.name}',
                  style: Hands.margin(size: 11),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// What they felt: every feeling that crossed, whose it was, and when.
class _FeelingHistory extends StatelessWidget {
  const _FeelingHistory({required this.events, required this.registry, required this.me});
  final List<Event> events;
  final FeelingRegistry registry;
  final Person me;

  @override
  Widget build(BuildContext context) {
    final list = events.reversed.toList();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 90),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final e = list[i];
        final f = registry.byId(e.payload['feeling_id'] as String);
        if (f == null) return const SizedBox.shrink();
        final mine = e.author == me;
        return Padding(
          padding: EdgeInsets.fromLTRB(mine ? 60 : 8, 4, mine ? 8 : 60, 4),
          child: Row(
            mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!mine) FeelingObject(feeling: f, size: 54, intensity: 0.65),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Text(f.name, style: Hands.of(e.author, size: 16)),
                    Text(
                      DateFormat('EEE d MMM · HH:mm').format(DateTime.fromMillisecondsSinceEpoch(e.ts)),
                      style: Hands.margin(size: 11),
                    ),
                  ],
                ),
              ),
              if (mine) FeelingObject(feeling: f, size: 54, intensity: 0.65),
            ],
          ),
        );
      },
    );
  }
}
