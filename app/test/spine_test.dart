import 'dart:io';

import 'package:desk/spine/spine.dart';
import 'package:desk/spine/store/store_native.dart';
import 'package:desk/spine/ulid.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ulids are 26 chars, valid, and monotonic within a millisecond', () {
    final f = UlidFactory();
    final at = DateTime.utc(2026, 9, 3, 18, 40);
    final a = f.next(at);
    final b = f.next(at);
    expect(a.length, 26);
    expect(UlidFactory.isValid(a), isTrue);
    expect(a.compareTo(b), lessThan(0));
    expect(UlidFactory.timeOf(a), at.millisecondsSinceEpoch);
  });

  test('append persists, replays in order, and the outbox comes back after reopen', () async {
    final dir = await Directory.systemTemp.createTemp('spine-');
    final path = '${dir.path}/s.sqlite3';
    var s = await Spine.open(NativeStore.openAt(path), const Identity(person: Person.noor, device: DeviceKind.android));
    await s.append('message', {'text': 'one'}, hostAssign: true);
    await s.append('message', {'text': 'two'}, hostAssign: true);
    await s.append('message', {'text': 'pending'});
    await s.close();
    s = await Spine.open(NativeStore.openAt(path), const Identity(person: Person.noor, device: DeviceKind.android));
    expect(s.ordered.map((e) => e.payload['text']), ['one', 'two']);
    expect(s.pending.single.payload['text'], 'pending');
    expect(s.cursor, 2);
    await s.close();
  });

  test('search reaches every type and follows edits and deletes', () async {
    final s = await Spine.open(SpineStore.memory(), const Identity(person: Person.noor, device: DeviceKind.android));
    final m = await s.append('message', {'text': 'bread from the place by the bridge'}, hostAssign: true);
    await s.append('feeling', {'feeling_id': 'squeeze', 'intensity': 0.5}, hostAssign: true);
    await s.append('todo_event', {'todo_id': 'todo_bread', 'action': 'added', 'text': 'bread'}, hostAssign: true);
    await s.append('date_event', {'date_id': 'date_ferry', 'action': 'planned', 'title': 'ferry to the island'}, hostAssign: true);
    expect(s.search('bread').map((h) => h.event.type).toSet(), {'message', 'todo_event'});
    expect(s.search('squeeze').single.event.type, 'feeling');
    expect(s.search('ferry').single.event.type, 'date_event');
    expect(s.search('photo'), isEmpty);
    await s.append('message_edit', {'target': m.id, 'text': 'bread from the bakery'}, hostAssign: true);
    expect(s.search('bridge').where((h) => h.event.type == 'message'), isEmpty);
    expect(s.search('bakery').single.event.id, m.id);
    await s.append('message_delete', {'target': m.id}, hostAssign: true);
    expect(s.search('bakery'), isEmpty);
    await s.close();
  });

  test('invalid payloads are refused', () async {
    final s = await Spine.open(SpineStore.memory(), const Identity(person: Person.noor, device: DeviceKind.android));
    expect(() => s.append('message', {}), throwsArgumentError);
    expect(() => s.append('nonsense', {'x': 1}), throwsArgumentError);
    await s.close();
  });
}
