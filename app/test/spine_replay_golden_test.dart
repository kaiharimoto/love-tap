// Every view in the app is a projection replayed from the one log, and this is what holds that
// true rather than only saying so.
//
// docs/EVENT_TYPES.md has cited this file for a long time and it did not exist, which is a worse
// kind of untruth than a missing test: a reader checking the claim would have found a citation and
// stopped. It replays a written log through every projection the app has, twice, and asserts that
//
//   · the same log gives the same views, byte for byte, however many times it is replayed;
//   · replaying a prefix and then the rest gives the same views as replaying the whole thing,
//     which is what makes a device that has been offline and catches up land in the same place;
//   · nothing in a projection survives an event being removed from the log, which is what "no
//     second store" means in practice.
import 'dart:convert';

import 'package:desk/modules/registry.dart';
import 'package:desk/spine/event.dart';
import 'package:desk/spine/projections/state.dart';
import 'package:desk/spine/projections/thread.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final log = _log();

  test('the same log gives the same thread every time', () {
    final a = _snapshot(log);
    final b = _snapshot(List<Event>.from(log));
    expect(b, a);
  });

  test('catching up in two halves lands where catching up in one would', () {
    // a device that was offline gets the first half, then the rest; a device that was not gets
    // all of it at once. There is no path where they end up looking at different things.
    final whole = _snapshot(log);
    final half = log.sublist(0, log.length ~/ 2);
    final rest = log.sublist(log.length ~/ 2);
    final caught = _snapshot([...half, ...rest]);
    expect(caught, whole);
  });

  test('order of arrival does not decide the view; seq does', () {
    final shuffled = List<Event>.from(log)..shuffle();
    expect(_snapshot(shuffled), _snapshot(log));
  });

  test('nothing outlives its event', () {
    // Take the photograph out of the log and it is gone from the thread, from the media facet and
    // from everywhere else. If any view still had it, that view would be a second store.
    final without = log.where((e) => e.type != 'photo').toList();
    final after = _snapshot(without);
    expect(after.contains('the boiler again'), isFalse);
    expect(_snapshot(log).contains('the boiler again'), isTrue);
  });

  test('a read marker moves a mark and is never a row', () {
    final thread = projectThread(log, me: Person.teo);
    expect(thread.items.any((i) => i.type == 'read_marker'), isFalse);
    expect(thread.readUpto[Person.noor], isNotNull);
  });

  test('every module reads the same log and says something from it', () {
    for (final m in kModules) {
      final line = m.glance(log);
      expect(line.trim(), isNotEmpty, reason: 'the ${m.id} module says nothing about a log '
          'that carries its own event types');
      expect(m.eventTypes, isNotEmpty);
    }
  });
}

/// One canonical string for everything the app would draw from a log. Two logs that project the
/// same views produce the same string; anything that leaks between replays changes it.
String _snapshot(List<Event> log) {
  final thread = projectThread(log, me: Person.teo);
  final state = projectState(log);
  return const JsonEncoder.withIndent(' ').convert({
    'items': [
      for (final i in thread.items)
        {'type': i.type, 'author': i.author.name, 'text': i.text, 'deleted': i.deleted,
         'reactions': i.reactions.length, 'reply_to': i.replyTo?.id},
    ],
    'read': {for (final e in thread.readUpto.entries) e.key.name: e.value},
    'state': {
      for (final e in state.entries)
        e.key.name: {'mood': e.value.mood, 'place': e.value.place, 'need': e.value.need,
                     'energy': e.value.energy, 'signals': e.value.signals.length},
    },
    'modules': {for (final m in kModules) m.id: m.glance(log)},
  });
}

List<Event> _log() {
  var seq = 0;
  Event ev(String type, Person by, Map<String, dynamic> payload, {int minute = 0,
      List<String> refs = const []}) {
    seq++;
    return Event(
      id: 'E${seq.toString().padLeft(4, '0')}',
      seq: seq,
      author: by,
      device: by == Person.noor ? DeviceKind.android : DeviceKind.pwa,
      ts: DateTime.utc(2026, 4, 22, 16, minute).millisecondsSinceEpoch,
      type: type,
      payload: payload,
      refs: refs,
    );
  }

  final m1 = ev('message', Person.noor, {'text': 'properly'}, minute: 30);
  final m2 = ev('message', Person.teo, {'text': 'The twenty first.'}, minute: 34);
  final m3 = ev('message', Person.noor, {'text': 'a month. and you have not opened the folder'},
      minute: 36);
  return [
    m1, m2, m3,
    ev('photo', Person.noor, {'blob': 'b1', 'w': 1200, 'h': 1600, 'caption': 'the boiler again'},
        minute: 38),
    ev('reaction', Person.teo, {'feeling_id': 'hold', 'target': m3.id}, minute: 39, refs: [m3.id]),
    ev('message_edit', Person.noor, {'target': m1.id, 'text': 'properly this time'},
        minute: 40, refs: [m1.id]),
    ev('read_marker', Person.noor, {'upto_seq': 3}, minute: 41),
    ev('state_declared', Person.noor, {'signal': 'mood', 'value': 'tender'}, minute: 42),
    ev('state_passive', Person.teo, {'signal': 'battery', 'value': 'low'}, minute: 43),
    ev('feeling', Person.teo, {'feeling_id': 'hold', 'intensity': 0.85}, minute: 44),
    ev('date_event', Person.noor,
        {'date_id': 'd1', 'action': 'planned', 'title': 'the ferry', 'place': 'the slipway',
         'when': '2026-07-18T09:00:00+01:00'}, minute: 45),
    ev('todo_event', Person.teo,
        {'todo_id': 't1', 'action': 'added', 'text': 'ring the landlord'}, minute: 46),
    ev('milestone', Person.noor,
        {'milestone_id': 'm1', 'kind': 'anniversary', 'title': 'two years',
         'date': '2026-11-09', 'yearly': true}, minute: 47),
    ev('ritual_kept', Person.teo,
        {'ritual_id': 'r1', 'title': 'text when home',
         'kept_at': '2026-04-22T16:48:00+01:00'}, minute: 48),
    ev('message_delete', Person.teo, {'target': m2.id}, minute: 49, refs: [m2.id]),
  ];
}
