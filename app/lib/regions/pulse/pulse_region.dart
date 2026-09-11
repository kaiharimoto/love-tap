// Pulse: the ambient home and the seat of the nervous system.
//
// The partner's whole current state at once — what they have declared, what their phone is
// reporting, the need and energy dials, where they are — on the paper their mood picks; your own
// state set in the same place; the feelings that have crossed today laid out along the desk; and
// the sender reachable without leaving the screen.
import 'package:flutter/material.dart';

import '../../feelings/landing.dart';
import '../../feelings/registry.dart';
import '../../material/assignment.dart';
import '../../material/hands.dart';
import '../../material/marks.dart';
import '../../material/library.dart';
import '../../material/objects.dart';
import '../../material/paper.dart';
import '../../material/motion.dart';
import '../../material/palette.dart';
import '../../material/slip.dart';
import '../../scope.dart';
import '../../spine/projections/state.dart';
import '../../spine/spine.dart';
import '../../voice/strings.dart';

class PulseRegion extends StatelessWidget {
  const PulseRegion({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final lib = MaterialLibrary.loaded ? MaterialLibrary.instance : null;
    final them = scope.partnerState;
    final me = scope.myState;
    final registry = scope.feelings;
    final now = scope.clock.now();
    final since = now.subtract(const Duration(hours: 24)).millisecondsSinceEpoch;
    final today = feelingsSince(scope.spine.all, since);

    // A fresh phone shows the empty surface until the first thing arrives, and then it shows
    // their sheet — which for eight seconds of a capture is a whole screen replaced between two
    // frames, and for a person is the page blinking. It turns.
    if (them.signals.isEmpty && today.isEmpty) {
      return const Turning(
        child: EmptySurface(
          key: ValueKey('pulse.empty'),
          id: 'pulse',
          line: S.emptyPulse,
          aside: S.emptyPulseAside,
        ),
      );
    }

    return Turning(
      child: ListView(
      key: const ValueKey('pulse.theirs'),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
      children: [
        _TheirSheet(
            key: const ValueKey('pulse.their.sheet'),
            partner: scope.partner,
            state: them,
            lib: lib,
            nowMs: scope.clock.now().millisecondsSinceEpoch),
        const SizedBox(height: 14),
        _Traffic(events: today, registry: registry, me: scope.me),
        const SizedBox(height: 14),
        _MySheet(me: scope.me, state: me, lib: lib, onSet: (signal, value) => scope.emit('state_declared', {'signal': signal, 'value': value})),
      ],
      ),
    );
  }
}

/// Their state, whole, on one sheet.
/// Their whole state, on the paper their mood picks — and when that state changes, a new sheet
/// going down on the desk over the old one.
///
/// It used to swap: the same widget rebuilt with new words on new stock, in one frame. That is the
/// wrong thing twice over. A mood changing is the one moment this screen exists for, and it went
/// past in a sixtieth of a second with nothing to see; and 08_state_propagating — the clip named
/// for a state reaching the other phone — had sixty-two identical frames in it, because after the
/// swap there was nothing moving to film. A sheet lands the way every other piece of paper in the
/// app lands: from a little above, over the one it replaces.
class _TheirSheet extends StatefulWidget {
  const _TheirSheet({
    super.key,
    required this.partner,
    required this.state,
    required this.lib,
    required this.nowMs,
  });
  final Person partner;
  final PersonState state;
  final MaterialLibrary? lib;

  /// The clock the region is drawn against, so "last up" is counted from now.
  final int nowMs;

  @override
  State<_TheirSheet> createState() => _TheirSheetState();
}

class _TheirSheetState extends State<_TheirSheet> {
  /// The state that was on the desk before this one, kept only until the new sheet has landed.
  PersonState? _under;

  /// What makes this a different sheet from the last one: what it says, not when it was said.
  static String _saying(PersonState s) => [
        s.statusLine, s.mood, s.availability, s.place, s.need, s.energy,
        s.battery, s.charging, s.lastActiveMinutes, s.localHour, s.ringer, s.moving,
        s.network, s.atHome,
      ].join('|');

  @override
  void didUpdateWidget(_TheirSheet old) {
    super.didUpdateWidget(old);
    if (_saying(old.state) != _saying(widget.state)) {
      setState(() => _under = old.state);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fresh = _sheet(context, widget.state);
    final under = _under;
    if (under == null) return fresh;
    return Settling(
      key: ValueKey('their.${_saying(widget.state)}'),
      duration: Motion.land,
      curve: Curves.linear,
      builder: (_, raw, _) {
        // and once it is down, the one underneath is off the desk: an invisible sheet left in the
        // tree is a second copy of every word on this screen for anything that reads it
        if (raw >= 1.0 && _under != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _under != null) setState(() => _under = null);
          });
        }
        final t = Motion.drop.transform(raw);
        return Stack(
          alignment: Alignment.topCenter,
          children: [
            // the sheet it lands on, still there under it until it is covered
            Opacity(opacity: 1 - t * t, child: _sheet(context, under)),
            Transform.translate(
              offset: Offset(0, -18 * (1 - t)),
              child: Opacity(opacity: (t * 2).clamp(0.0, 1.0), child: fresh),
            ),
          ],
        );
      },
    );
  }

  Widget _sheet(BuildContext context, PersonState state) {
    final partner = widget.partner;
    final lib = widget.lib;
    final stock = stockForMood(state.mood);
    final variants = lib?.stockVariants(stock) ?? const <String>[];
    final id = variants.isEmpty ? '' : variants[(state.mood?.length ?? 1) % variants.length];
    final masks = lib?.writableTears ?? const <String>[];
    final tear = masks.isEmpty ? null : masks[(partner.index * 7 + 11) % masks.length];
    return PaperPiece(
      stockId: id,
      tearId: tear,
      liftMm: 1.1,
      tilt: -0.008,
      safe: tear == null || lib == null ? const [0.07, 0.08, 0.07, 0.08] : lib.safeOf(tear),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(state.statusLine ?? state.mood ?? '', style: Hands.of(partner, size: 24)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _Fact(signalLabel('mood'), state.mood),
              _Fact(signalLabel('availability'), _words(state.availability)),
              _Fact(signalLabel('place'), _words(state.place)),
              // never a score out of anything: a dial is how much, said in words
              // the same word the strip and the picker use: two fields, two names
              _Fact(signalLabel('need'), _dial(state.need)),
              _Fact(signalLabel('energy'), _dial(state.energy)),
              if (state.battery != null)
                _Fact('battery', '${state.battery}%${state.charging ? ' on charge' : ''}'),
              // counted from now, not from when they said it — the same arithmetic the standing
              // line uses, because it is the same fact and they used to disagree by seven hours
              if (state.lastActiveMinutesAt(widget.nowMs) != null)
                _Fact('last up', _ago(state.lastActiveMinutesAt(widget.nowMs)!)),
              if (state.localHour != null) _Fact('their clock', '${state.localHour}:00'),
              if (state.ringer != null) _Fact('ringer', _words(state.ringer)),
              if (state.moving != null) _Fact('moving', _words(state.moving)),
              if (state.network != null) _Fact('signal', _words(state.network)),
              if (state.atHome != null) _Fact('at home', state.atHome! ? 'yes' : 'no'),
            ],
          ),
        ],
      ),
    );
  }
}

/// Nothing on this screen is stored the way it is read. `heads_down` is a key; "heads down" is
/// what one person says about another.
String? _words(String? key) => key?.replaceAll('_', ' ');

/// A need or an energy is how much, and how much is a word. Four out of four is a score, and a
/// score is a thing to be measured against.
String _dial(int level) => switch (level) {
      <= 0 => 'nothing',
      1 => 'a little',
      2 => 'some',
      3 => 'a lot',
      _ => 'everything',
    };

String _ago(int minutes) {
  if (minutes < 2) return 'just now';
  if (minutes < 60) return '$minutes minutes ago';
  final hours = minutes ~/ 60;
  if (hours < 24) return hours == 1 ? 'an hour ago' : '$hours hours ago';
  final days = hours ~/ 24;
  return days == 1 ? 'yesterday' : '$days days ago';
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    if (value == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Stamped(label, size: 9, colour: Pen.margin),
        Text(value!, style: Hands.margin(size: 15)),
      ],
    );
  }
}

/// The day's traffic: every feeling that crossed in the last day, laid along the desk newest
/// first, so the one that has just landed is the one under your eye. A glance says how the day
/// has gone; a name and a time under each one says what was felt and when.
///
/// It used to be oldest first with no way to scroll, so a feeling that arrived while you watched
/// was appended off the right-hand edge of the row and nothing on screen changed — a clip named
/// for a feeling landing showed the same five objects in the same five places from first frame to
/// last.
class _Traffic extends StatelessWidget {
  const _Traffic({required this.events, required this.registry, required this.me});
  final List<Event> events;
  final FeelingRegistry registry;
  final Person me;

  /// The ids that were already on the desk. Anything not in here when it is first drawn has just
  /// arrived, and lands.
  static final Set<String> _seen = {};
  static bool _primed = false;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();
    final newestFirst = events.reversed.toList();
    if (!_primed) {
      _seen.addAll(newestFirst.map((e) => e.id));
      _primed = true;
    }
    // The row is as tall as the tallest thing in it needs, not a number somebody typed. An object
    // whose render frames it loosely asks for a wider box than its nominal size, and a fixed
    // height cut the bottom off it — the layout said 124 and the drawing wanted 226.
    var tallest = 66.0;
    for (final e in newestFirst) {
      final f = registry.byId(e.payload['feeling_id'] as String);
      if (f == null) continue;
      final box = FeelingObject.boxFor(f, 66);
      if (box > tallest) tallest = box;
    }
    return SizedBox(
      // the object, plus the name, the time, and the ten points a note of one's own is offset by
      height: tallest + 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: newestFirst.length,
        itemBuilder: (context, i) {
          final e = newestFirst[i];
          final f = registry.byId(e.payload['feeling_id'] as String);
          if (f == null) return const SizedBox.shrink();
          final mine = e.author == me;
          final landing = !_seen.contains(e.id);
          _seen.add(e.id);
          final when = DateTime.fromMillisecondsSinceEpoch(e.ts, isUtc: true).toLocal();
          final hh = when.hour.toString().padLeft(2, '0');
          final mm = when.minute.toString().padLeft(2, '0');
          Widget object = FeelingObject(
            feeling: f,
            size: 66,
            intensity: (e.payload['intensity'] as num).toDouble(),
            tilt: ((hashOf(e.id) % 24) - 12) / 80,
          );
          if (landing) {
            // It lands here once the thing that was thrown has finished on the desk and been put
            // away: the stage's object goes up the desk and shrinks, and this one arrives from a
            // little above as it goes, so there is one object, not two. The wait is the same
            // arithmetic the stage uses, so the two agree on the driven clock as on the wall.
            final intensity = (e.payload['intensity'] as num).toDouble();
            final wait = Fall.restSeconds(f, intensity) + Fall.putAwaySeconds * 0.7;
            final total = wait + Motion.land.inMilliseconds / 1000.0;
            object = Settling(
              key: ValueKey('land.${e.id}'),
              duration: Duration(milliseconds: (total * 1000).round()),
              curve: Curves.linear,
              builder: (_, raw, child) {
                final t = Motion.drop.transform(((raw * total - wait) / (total - wait)).clamp(0.0, 1.0));
                return Transform.translate(
                  offset: Offset(0, -22 * (1 - t)),
                  child: Opacity(opacity: (t * 3).clamp(0.0, 1.0), child: child),
                );
              },
              child: object,
            );
          }
          return Padding(
            padding: EdgeInsets.only(right: 6, top: mine ? 10 : 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                object,
                const SizedBox(height: 2),
                SizedBox(
                  width: 72,
                  child: Text(f.name, style: Hands.onDesk(size: 10), maxLines: 1,
                      overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                ),
                Text('$hh:$mm${mine ? '' : ' · ${e.author.name}'}', style: Hands.onDesk(size: 8.5)),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Your own state, set on the same desk you read theirs from.
class _MySheet extends StatelessWidget {
  const _MySheet({required this.me, required this.state, required this.lib, required this.onSet});
  final Person me;
  final PersonState state;
  final MaterialLibrary? lib;
  final void Function(String signal, Object value) onSet;

  static const moods = ['bright', 'calm', 'tender', 'restless', 'low', 'flat'];
  static const availability = ['open', 'heads_down', 'asleep'];
  static const places = ['home', 'work', 'out', 'travelling'];

  @override
  Widget build(BuildContext context) {
    final variants = lib?.stockVariants('looseleaf') ?? const <String>[];
    final id = variants.isEmpty ? '' : variants.first;
    final masks = lib?.writableTears ?? const <String>[];
    final tear = masks.isEmpty ? null : masks[(masks.length - 3).clamp(0, masks.length - 1)];
    return PaperPiece(
      stockId: id,
      tearId: tear,
      liftMm: 0.7,
      tilt: 0.006,
      safe: tear == null || lib == null ? const [0.07, 0.08, 0.07, 0.08] : lib!.safeOf(tear),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Stamped('yours', size: 10),
          const SizedBox(height: 6),
          _Row(label: signalLabel('mood'), options: moods, value: state.mood, onPick: (v) => onSet('mood', v)),
          _Row(label: signalLabel('availability'), options: availability, value: state.availability,
              onPick: (v) => onSet('availability', v)),
          _Row(label: signalLabel('place'), options: places, value: state.place, onPick: (v) => onSet('place', v)),
          _Dial(label: signalLabel('need'), value: state.need, onPick: (v) => onSet('need', v)),
          _Dial(label: signalLabel('energy'), value: state.energy, onPick: (v) => onSet('energy', v)),
          const SizedBox(height: 6),
          _StatusField(me: me, current: state.statusLine, onSet: (v) => onSet('status_line', v)),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.options, required this.value, required this.onPick});
  final String label;
  final List<String> options;
  final String? value;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(width: 58, child: Stamped(label, size: 9, colour: Pen.margin)),
            Expanded(
              child: Wrap(
                spacing: 10,
                children: [
                  for (final o in options)
                    GestureDetector(
                      onTap: () => onPick(o),
                      child: Text(
                        o.replaceAll('_', ' '),
                        style: Hands.margin(size: 15).copyWith(
                          color: o == value ? Pen.ballpoint : Pen.margin.withValues(alpha: 0.6),
                          decoration: o == value ? TextDecoration.underline : null,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _Dial extends StatelessWidget {
  const _Dial({required this.label, required this.value, required this.onPick});
  final String label;
  final int value;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(width: 58, child: Stamped(label, size: 9, colour: Pen.margin)),
            for (var i = 0; i <= 4; i++)
              GestureDetector(
                onTap: () => onPick(i),
                child: Container(
                  width: 26,
                  height: 22,
                  alignment: Alignment.center,
                  child: Container(
                    width: 3,
                    height: 6.0 + i * 3.5,
                    color: Pen.margin.withValues(alpha: i <= value ? 0.9 : 0.28),
                  ),
                ),
              ),
          ],
        ),
      );
}

class _StatusField extends StatefulWidget {
  const _StatusField({required this.me, required this.current, required this.onSet});
  final Person me;
  final String? current;
  final ValueChanged<String> onSet;

  @override
  State<_StatusField> createState() => _StatusFieldState();
}

class _StatusFieldState extends State<_StatusField> {
  late final TextEditingController _c = TextEditingController(text: widget.current ?? '');

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _c,
            style: Hands.of(widget.me, size: 18),
            // it wraps rather than scrolling sideways: a line about now that runs off the edge of
            // the paper is a line you cannot read on paper
            minLines: 1,
            maxLines: 3,
            cursorColor: Pen.ballpoint,
            cursorWidth: 1.2,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.fromLTRB(0, 4, 0, 4),
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
              hintText: 'a line about now',
              hintStyle: Hands.margin(size: 16),
            ),
            onSubmitted: widget.onSet,
            onEditingComplete: () => widget.onSet(_c.text),
          ),
          const RuleLine(seed: 61),
        ],
      );
}
