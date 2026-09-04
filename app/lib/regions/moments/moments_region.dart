// Moments: the shared archive, and nothing but a filtered view of the one spine.
//
// There is no second store here and no separate index: every list on this screen is the same
// List<Event> the thread reads, narrowed by person, by date, by type, or by a particular feeling.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../feelings/builtins.dart';
import '../../feelings/registry.dart';
import '../../material/hands.dart';
import '../../material/objects.dart';
import '../../material/palette.dart';
import '../../material/slip.dart';
import '../../scope.dart';
import '../../spine/spine.dart';
import '../../voice/strings.dart';
import '../chat/blob_widgets.dart';

enum MomentsView { media, milestones, feelings }

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
    const media = {'photo', 'video', 'voice_note'};
    const marks = {'milestone', 'date_event', 'ritual_kept', 'feeling_authored'};
    final typeOk = switch (view) {
      MomentsView.media => media.contains(e.type),
      MomentsView.milestones => marks.contains(e.type),
      MomentsView.feelings => e.type == 'feeling' || e.type == 'reaction',
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
                    onTap: () => onView(v),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: Stamped(
                        switch (v) {
                          MomentsView.media => 'what we sent',
                          MomentsView.milestones => 'what happened',
                          MomentsView.feelings => 'what we felt',
                        },
                        size: v == view ? 12 : 10,
                        colour: v == view ? Pen.stamp : Pen.margin,
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
    child: Opacity(
      opacity: on ? 1.0 : 0.72,
      child: Slip(
        id: 'moments.$label',
        row: label.length,
        stock: on ? 'sticky_yellow' : 'index',
        torn: false,
        padding: const EdgeInsets.fromLTRB(11, 5, 11, 6),
        onTap: onTap,
        child: Text(label, style: Hands.margin(size: 13).copyWith(color: on ? Pen.stamp : Pen.margin)),
      ),
    ),
  );
}

/// Everything they have sent each other, as prints on the desk.
class _Gallery extends StatelessWidget {
  const _Gallery({required this.events});
  final List<Event> events;

  @override
  Widget build(BuildContext context) {
    final media = events.reversed.toList();
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 90),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: media.length,
      itemBuilder: (context, i) {
        final e = media[i];
        final hash = (e.payload['poster_blob'] ?? e.payload['blob']) as String;
        if (e.type == 'voice_note') {
          // a voice note in the gallery is the slip it was written on, with its length on it
          return Slip(
            id: e.id,
            row: i,
            stock: 'receipt',
            padding: const EdgeInsets.all(8),
            child: Center(
              child: Text(
                '${((e.payload['duration_ms'] as num) / 1000).round()}s',
                style: Hands.margin(size: 14),
              ),
            ),
          );
        }
        return BlobImage(hash: hash, fit: BoxFit.cover);
      },
    );
  }
}

/// What happened: milestones, dates, rituals and new feelings, in order.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.events});
  final List<Event> events;

  @override
  Widget build(BuildContext context) {
    final list = events.reversed.toList();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final e = list[i];
        final title = (e.payload['title'] ?? e.payload['name'] ?? e.type) as String;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 86,
                child: Text(
                  DateFormat('d MMM yy').format(DateTime.fromMillisecondsSinceEpoch(e.ts)),
                  style: Hands.margin(size: 12),
                ),
              ),
              Expanded(child: Text(title, style: Hands.of(e.author, size: 17))),
              Stamped(e.type.replaceAll('_', ' '), size: 8, colour: Pen.margin),
            ],
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
