// What is allowed to interrupt, per event type, plus quiet hours and the pings a person has
// scheduled. Nothing here can be turned into engagement: a ping exists only because one of the
// two people wrote it, and the app never schedules one of its own.
import '../../material/assignment.dart';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../material/choice.dart';
import '../../material/hands.dart';
import '../../material/palette.dart';
import '../../material/slip.dart';
import '../../spine/spine.dart';

/// How each event type may announce itself on this phone.
enum Announce { interrupt, quiet, off }

class NotificationPrefs {
  NotificationPrefs({required this.byType, required this.quietFrom, required this.quietTo});

  /// event type -> how it may announce itself
  final Map<String, Announce> byType;

  /// Quiet hours, local, inclusive of from, exclusive of to. Nothing interrupts between them.
  final int quietFrom;
  final int quietTo;

  static const _key = 'notify.prefs';

  static Future<NotificationPrefs> load(Spine spine) async {
    final raw = await spine.meta(_key);
    if (raw == null) return NotificationPrefs.defaults();
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return NotificationPrefs(
      byType: {
        for (final e in (j['by_type'] as Map).entries) e.key as String: Announce.values.byName(e.value as String),
      },
      quietFrom: (j['quiet_from'] as num?)?.toInt() ?? 23,
      quietTo: (j['quiet_to'] as num?)?.toInt() ?? 7,
    );
  }

  factory NotificationPrefs.defaults() => NotificationPrefs(
        byType: {
          for (final t in kEventTypes)
            t.id: switch (t.notify) {
              Notify.interruptive => Announce.interrupt,
              Notify.quiet => Announce.quiet,
              Notify.none => Announce.off,
            },
        },
        quietFrom: 23,
        quietTo: 7,
      );

  Future<void> save(Spine spine) => spine.setMeta(
        _key,
        jsonEncode({
          'by_type': {for (final e in byType.entries) e.key: e.value.name},
          'quiet_from': quietFrom,
          'quiet_to': quietTo,
        }),
      );

  NotificationPrefs copyWith({Map<String, Announce>? byType, int? quietFrom, int? quietTo}) =>
      NotificationPrefs(
        byType: byType ?? this.byType,
        quietFrom: quietFrom ?? this.quietFrom,
        quietTo: quietTo ?? this.quietTo,
      );

  bool isQuietAt(DateTime local) {
    final h = local.hour;
    return quietFrom <= quietTo ? (h >= quietFrom && h < quietTo) : (h >= quietFrom || h < quietTo);
  }

  /// What this type may do right now.
  Announce forType(String type, DateTime local) {
    final a = byType[type] ?? Announce.quiet;
    if (a == Announce.interrupt && isQuietAt(local)) return Announce.quiet;
    return a;
  }
}

/// What each kind of event is, said the way one of them would say it. The registry's ids are for
/// the log; this list is a person deciding what may wake them up.
String _said(String type) => switch (type) {
      'message' => 'something written',
      'photo' => 'a picture',
      'video' => 'something to watch',
      'voice_note' => 'their voice',
      'reaction' => 'an answer to something of yours',
      'message_edit' => 'a change to something already said',
      'message_delete' => 'something taken back',
      'read_marker' => 'them catching up',
      'feeling' => 'a feeling',
      'state_declared' => 'something they say about themselves',
      'state_passive' => 'something their phone notices',
      'date_event' => 'a date moving',
      'todo_event' => 'the list moving',
      'milestone' => 'a day that matters',
      'ritual_kept' => 'one of the things you keep',
      'ping' => 'a note set to arrive later',
      'feeling_authored' => 'a feeling one of you made',
      _ => type.replaceAll('_', ' '),
    };

class NotificationSettings extends StatelessWidget {
  const NotificationSettings({super.key, required this.prefs, required this.onChanged});
  final NotificationPrefs prefs;
  final ValueChanged<NotificationPrefs> onChanged;

  @override
  Widget build(BuildContext context) {
    return Slip(
      id: 'settings.notify',
      row: 7,
      lane: TearLanes.panels,
      stock: 'looseleaf',
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Stamped('quiet from', size: 9, colour: Pen.margin),
            const SizedBox(width: 8),
            _Hour(value: prefs.quietFrom, onPick: (h) => onChanged(prefs.copyWith(quietFrom: h))),
            const SizedBox(width: 10),
            Stamped('until', size: 9, colour: Pen.margin),
            const SizedBox(width: 8),
            _Hour(value: prefs.quietTo, onPick: (h) => onChanged(prefs.copyWith(quietTo: h))),
          ]),
          const SizedBox(height: 10),
          // The name on its own line, the three choices under it.
          //
          // They were one Row: `Expanded(name)` against three `Choice`s, and a Choice is a
          // Row(mainAxisSize: min) that takes whatever its word needs. `wake me`, `quietly` and
          // `not at all` come to about 320 logical pixels between them, and on a 480-pixel phone
          // inside two lots of padding there are only about 424 to share -- so Expanded was left
          // with NINE AND A HALF, and the name wrapped one character per line into a column 400
          // pixels tall. Every row did it. The matrix measured 4,282 logical pixels from the top
          // of its first row to the top of its last, which is four screenfuls of a settings page
          // for fourteen lines of text, and it is why `05_settings.png` could not show the table
          // however far the page was scrolled: at the very bottom of it exactly one row was in
          // the frame. Stacking them is what makes it a table you can read and a thing a capture
          // can see; a Wrap rather than a Row so a longer word in a future type moves to the next
          // line instead of starving the one beside it.
          for (final t in kEventTypes)
            if (t.notify != Notify.none)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_said(t.id), style: Hands.margin(size: 14)),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 18,
                      runSpacing: 4,
                      children: [
                        for (final a in Announce.values)
                          Choice(
                            label: switch (a) {
                              Announce.interrupt => 'wake me',
                              Announce.quiet => 'quietly',
                              Announce.off => 'not at all',
                            },
                            size: 13,
                            chosen: (prefs.byType[t.id] ?? Announce.quiet) == a,
                            chosenInk: Pen.stamp,
                            onTap: () =>
                                onChanged(prefs.copyWith(byType: {...prefs.byType, t.id: a})),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _Hour extends StatelessWidget {
  const _Hour({required this.value, required this.onPick});
  final int value;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => onPick((value + 1) % 24),
        child: Text('${value.toString().padLeft(2, '0')}:00', style: Hands.teo(size: 16)),
      );
}
