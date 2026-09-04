// What it costs to draw one frame against a year of history.
//
// Rubric row 01 says "no scroll jank against the year-deep seeded history", which is a claim about
// milliseconds, so it is measured here rather than asserted. The seeded year is about fourteen
// thousand events; a frame at sixty a second has sixteen milliseconds for everything.
//
// The numbers below are budgets, not measurements of a good day: they are set well above what the
// code does now, so this fails when something gets slower rather than when a machine is busy.
import 'package:desk/feelings/registry.dart';
import 'package:desk/spine/event.dart';
import 'package:desk/spine/projections/state.dart';
import 'package:desk/spine/projections/thread.dart';
import 'package:flutter_test/flutter_test.dart';

List<Event> _aYear({int count = 14000}) {
  final out = <Event>[];
  const kinds = ['message', 'message', 'message', 'feeling', 'reaction', 'state_passive',
                 'read_marker', 'message_edit'];
  var seq = 0;
  for (var i = 0; i < count; i++) {
    seq++;
    final type = kinds[i % kinds.length];
    final author = i % 2 == 0 ? Person.noor : Person.teo;
    final target = out.isEmpty ? '' : out[out.length ~/ 2].id;
    final payload = switch (type) {
      'message' => {'text': 'a line of the year, number $i'},
      'feeling' => {'feeling_id': 'hold', 'intensity': 0.7},
      'reaction' => {'target': target, 'feeling_id': 'hold'},
      'state_passive' => {'signal': 'battery', 'value': 'low'},
      'read_marker' => {'upto_seq': seq - 1},
      'message_edit' => {'target': target, 'text': 'a line of the year, corrected'},
      _ => <String, dynamic>{},
    };
    out.add(Event(
      id: 'E${i.toString().padLeft(6, '0')}',
      seq: seq,
      author: author,
      device: author == Person.noor ? DeviceKind.android : DeviceKind.pwa,
      ts: DateTime.utc(2025, 9, 1).millisecondsSinceEpoch + i * 37000,
      type: type,
      payload: payload.cast<String, dynamic>(),
      refs: target.isEmpty ? const [] : [target],
    ));
  }
  // a handful of feelings the two of them made themselves, scattered through the year
  for (var k = 0; k < 6; k++) {
    seq++;
    out.add(Event(
      id: 'A${k}', seq: seq, author: Person.noor, device: DeviceKind.android,
      ts: DateTime.utc(2026, 2, 1).millisecondsSinceEpoch + k * 900000,
      type: 'feeling_authored',
      payload: {
        'feeling_id': 'made_$k', 'name': 'the $k one', 'family': 'warmth',
        'colour': '#1f2a44', 'object_asset': 'obj_pinch', 'haptic': '80@90',
        'sound': 'snd_squeeze', 'retired': false,
      },
    ));
  }
  return out;
}

int _ms(void Function() f) {
  final sw = Stopwatch()..start();
  f();
  sw.stop();
  return sw.elapsedMicroseconds;
}

void main() {
  final year = _aYear();

  setUpAll(() {
    // The first call through any of this pays for the VM compiling it, which measured as 177
    // milliseconds and sent me looking for a slowness that was partly the measurement. Warm the
    // paths up first so what follows is the cost of the work.
    for (var i = 0; i < 3; i++) {
      projectThread(year.sublist(0, 3000), me: Person.teo);
      projectState(year.sublist(0, 3000));
      FeelingRegistry(year.sublist(0, 3000));
    }
  });

  test('the feeling registry is not rebuilt from the whole log to answer one question', () {
    // It used to be constructed inside build(), in five regions, from every event in the spine,
    // and then answered byId with a linear scan. That is the whole year, five times, per frame.
    final build = _ms(() => FeelingRegistry(year));
    final registry = FeelingRegistry(year);
    final lookups = _ms(() {
      for (var i = 0; i < 2000; i++) {
        registry.byId('hold');
        registry.byId('made_3');
        registry.byId('not a feeling');
      }
    });
    expect(registry.byId('made_3')?.name, 'the 3 one');
    expect(registry.byId('hold'), isNotNull);
    expect(registry.byId('nope'), isNull);
    // 6000 lookups is far more than a frame ever does; if this is not effectively free it is a
    // scan rather than a lookup
    expect(lookups, lessThan(20000),
        reason: 'byId took ${lookups}us for 6000 lookups — that is a linear scan');
    expect(build, lessThan(60000), reason: 'building the registry took ${build}us');
    // ignore: avoid_print
    print('registry: build ${build}us, 6000 lookups ${lookups}us');
  });

  test('the first projection of a year is slow, and it only happens once', () {
    final t = _ms(() => projectThread(year, me: Person.teo));
    final s = _ms(() => projectState(year));
    expect(projectThread(year, me: Person.teo).items, isNotEmpty);
    // ignore: avoid_print
    print('cold projectThread ${t}us, projectState ${s}us over ${year.length} events');
    expect(s, lessThan(60000), reason: 'projectState took ${s}us');
  });

  test('scrolling a year costs the new events and nothing else', () {
    // Every scroll moves a read marker, which is a spine change, which used to reproject the
    // whole year. This is the number that decides whether the dense scroll is smooth.
    final projector = ThreadProjector(me: Person.teo);
    final cold = _ms(() => projector.update(year));
    final again = _ms(() => projector.update(year));

    final withOneMore = [...year, Event(
      id: 'NEW', seq: 99999, author: Person.teo, device: DeviceKind.pwa,
      ts: DateTime.utc(2026, 9, 3).millisecondsSinceEpoch,
      type: 'message', payload: const {'text': 'one more'})];
    final appended = _ms(() => projector.update(withOneMore));

    // and a read marker landing, which is what a scroll actually emits
    final withRead = [...withOneMore, Event(
      id: 'READ', seq: 100000, author: Person.noor, device: DeviceKind.android,
      ts: DateTime.utc(2026, 9, 3).millisecondsSinceEpoch,
      type: 'read_marker', payload: const {'upto_seq': 99999})];
    final marker = _ms(() => projector.update(withRead));

    // ignore: avoid_print
    print('projector: cold ${cold}us, unchanged ${again}us, +1 event ${appended}us, '
        '+1 read marker ${marker}us');
    expect(again, lessThan(16000), reason: 'redrawing an unchanged year cost ${again}us');
    expect(appended, lessThan(16000), reason: 'one new event cost ${appended}us');
    expect(marker, lessThan(16000), reason: 'one read marker cost ${marker}us');
  });

  test('folding gives the same thread as building it from nothing', () {
    // The whole reason the incremental path is allowed to exist. If these two ever disagree, the
    // fast one is wrong and the app is showing something the log does not say.
    final projector = ThreadProjector(me: Person.teo);
    for (var upto = 1; upto <= year.length; upto += 997) {
      final prefix = year.sublist(0, upto);
      final folded = projector.update(prefix);
      final fresh = projectThread(prefix, me: Person.teo);
      expect(folded.items.length, fresh.items.length, reason: 'row count differs at $upto');
      for (var i = 0; i < fresh.items.length; i++) {
        expect(folded.items[i].id, fresh.items[i].id, reason: 'order differs at $upto, row $i');
        expect(folded.items[i].text, fresh.items[i].text, reason: 'text differs at $upto, row $i');
        expect(folded.items[i].deleted, fresh.items[i].deleted);
        expect(folded.items[i].edited, fresh.items[i].edited);
        expect(folded.items[i].reactions.length, fresh.items[i].reactions.length,
            reason: 'reactions differ at $upto, row $i');
        expect(folded.items[i].delivery, fresh.items[i].delivery,
            reason: 'delivery differs at $upto, row $i');
      }
      expect(folded.readUpto, fresh.readUpto);
    }
  });

  test('a log that is not an append is rebuilt rather than trusted', () {
    final projector = ThreadProjector(me: Person.teo);
    projector.update(year);
    // the same events in a different order, which is what a catch-up can look like
    final shuffled = [...year]..shuffle();
    final folded = projector.update(shuffled);
    final fresh = projectThread(year, me: Person.teo);
    expect(folded.items.map((i) => i.id).toList(), fresh.items.map((i) => i.id).toList());
    // and a shorter log entirely
    final shorter = year.sublist(0, 500);
    expect(projector.update(shorter).items.length,
           projectThread(shorter, me: Person.teo).items.length);
  });
}
