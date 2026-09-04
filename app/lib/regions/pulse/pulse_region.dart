// Pulse: the ambient home and the seat of the nervous system.
//
// The partner's whole current state at once — what they have declared, what their phone is
// reporting, the need and energy dials, where they are — on the paper their mood picks; your own
// state set in the same place; the feelings that have crossed today laid out along the desk; and
// the sender reachable without leaving the screen.
import 'package:flutter/material.dart';

import '../../feelings/registry.dart';
import '../../material/assignment.dart';
import '../../material/hands.dart';
import '../../material/library.dart';
import '../../material/objects.dart';
import '../../material/paper.dart';
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
    final registry = FeelingRegistry(scope.spine.all);
    final now = scope.clock.now();
    final since = now.subtract(const Duration(hours: 24)).millisecondsSinceEpoch;
    final today = feelingsSince(scope.spine.all, since);

    if (them.signals.isEmpty && today.isEmpty) {
      return const EmptySurface(id: 'pulse', line: S.emptyPulse, aside: S.emptyPulseAside);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
      children: [
        _TheirSheet(partner: scope.partner, state: them, lib: lib),
        const SizedBox(height: 14),
        _Traffic(events: today, registry: registry, me: scope.me),
        const SizedBox(height: 14),
        _MySheet(me: scope.me, state: me, lib: lib, onSet: (signal, value) => scope.emit('state_declared', {'signal': signal, 'value': value})),
      ],
    );
  }
}

/// Their state, whole, on one sheet.
class _TheirSheet extends StatelessWidget {
  const _TheirSheet({required this.partner, required this.state, required this.lib});
  final Person partner;
  final PersonState state;
  final MaterialLibrary? lib;

  @override
  Widget build(BuildContext context) {
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
      safe: tear == null || lib == null ? const [0.07, 0.08, 0.07, 0.08] : lib!.safeOf(tear),
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
              _Fact('mood', state.mood),
              _Fact('here', state.availability),
              _Fact('place', state.place),
              _Fact('need', '${state.need}/4'),
              _Fact('energy', '${state.energy}/4'),
              if (state.battery != null) _Fact('battery', '${state.battery}%${state.charging ? ' on charge' : ''}'),
              if (state.lastActiveMinutes != null) _Fact('last up', '${state.lastActiveMinutes}m ago'),
              if (state.localHour != null) _Fact('their clock', '${state.localHour}:00'),
              if (state.ringer != null) _Fact('ringer', state.ringer),
              if (state.moving != null) _Fact('moving', state.moving),
              if (state.network != null) _Fact('signal', state.network),
              if (state.atHome != null) _Fact('at home', state.atHome! ? 'yes' : 'no'),
            ],
          ),
        ],
      ),
    );
  }
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

/// The day's traffic: every feeling that crossed in the last day, laid along the desk in the order
/// it arrived. A glance says how the day has gone.
class _Traffic extends StatelessWidget {
  const _Traffic({required this.events, required this.registry, required this.me});
  final List<Event> events;
  final FeelingRegistry registry;
  final Person me;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 92,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: events.length,
        itemBuilder: (context, i) {
          final e = events[i];
          final f = registry.byId(e.payload['feeling_id'] as String);
          if (f == null) return const SizedBox.shrink();
          final mine = e.author == me;
          return Padding(
            padding: EdgeInsets.only(right: 4, top: mine ? 14 : 0),
            child: FeelingObject(
              feeling: f,
              size: 66,
              intensity: (e.payload['intensity'] as num).toDouble(),
              tilt: ((hashOf(e.id) % 24) - 12) / 80,
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
          _Row(label: 'mood', options: moods, value: state.mood, onPick: (v) => onSet('mood', v)),
          _Row(label: 'here', options: availability, value: state.availability, onPick: (v) => onSet('availability', v)),
          _Row(label: 'place', options: places, value: state.place, onPick: (v) => onSet('place', v)),
          _Dial(label: 'need', value: state.need, onPick: (v) => onSet('need', v)),
          _Dial(label: 'energy', value: state.energy, onPick: (v) => onSet('energy', v)),
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
  Widget build(BuildContext context) => TextField(
        controller: _c,
        style: Hands.of(widget.me, size: 18),
        decoration: InputDecoration(
          isDense: true,
          border: UnderlineInputBorder(borderSide: BorderSide(color: Pen.margin.withValues(alpha: 0.4))),
          hintText: 'a line about now',
          hintStyle: Hands.margin(size: 16),
        ),
        onSubmitted: widget.onSet,
      );
}
