// What is allowed to interrupt, per event type, plus quiet hours and the pings a person has
// scheduled. Nothing here can be turned into engagement: a ping exists only because one of the
// two people wrote it, and the app never schedules one of its own.
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../material/hands.dart';
import '../../material/palette.dart';
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

class NotificationSettings extends StatelessWidget {
  const NotificationSettings({super.key, required this.prefs, required this.onChanged});
  final NotificationPrefs prefs;
  final ValueChanged<NotificationPrefs> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      color: const Color(0xFFF3EEE3),
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
          for (final t in kEventTypes)
            if (t.notify != Notify.none)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(child: Text(t.id.replaceAll('_', ' '), style: Hands.margin(size: 14))),
                    for (final a in Announce.values)
                      GestureDetector(
                        onTap: () => onChanged(prefs.copyWith(byType: {...prefs.byType, t.id: a})),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Text(
                            switch (a) {
                              Announce.interrupt => 'wake me',
                              Announce.quiet => 'quietly',
                              Announce.off => 'not at all',
                            },
                            style: Hands.margin(size: 13).copyWith(
                              color: (prefs.byType[t.id] ?? Announce.quiet) == a ? Pen.stamp : Pen.margin.withValues(alpha: 0.5),
                              decoration: (prefs.byType[t.id] ?? Announce.quiet) == a ? TextDecoration.underline : null,
                            ),
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
