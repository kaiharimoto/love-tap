// What it costs to draw one frame against a year of history.
//
// Rubric row 01 says "no scroll jank against the year-deep seeded history", which is a claim about
// milliseconds, so it is measured here rather than asserted. The seeded year is about fourteen
// thousand events; a frame at sixty a second has sixteen milliseconds for everything.
//
// The numbers below are budgets, not measurements of a good day: they are set well above what the
// code does now, so this fails when something gets slower rather than when a machine is busy.
import 'package:desk/feelings/builtins.dart';
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
      // Real transitions, and ones the projector will actually say something about. This used to
      // be {'signal': 'battery', 'value': 'low'} for every passive event in the fixture, and
      // _worthSaying wants a num for battery — so the whole 14,000-event year produced no margin
      // marks at all, _saidLast stayed empty for the fixture's life, and the rebuild test below
      // compared two projections neither of which had anything to lose. That is why a projector
      // that dropped three rows of the real year on every reset passed this file.
      'state_passive' => i % 2 == 0
          // a phone that leaves home four times over the year and is home at both ends of it,
          // which is what makes the rebuild test below able to see anything at all
          ? {'signal': 'at_home', 'value': (i ~/ 3000) % 2 == 0}
          : {'signal': 'ringer', 'value': (i ~/ 1100) % 2 == 0 ? 'silent' : 'normal'},
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

/// A log of nothing but authored feelings, for measuring what the size of the library costs.
List<Event> _authored(int n) => [
      for (var k = 0; k < n; k++)
        Event(
          id: 'F$k',
          seq: k + 1,
          author: Person.teo,
          device: DeviceKind.pwa,
          ts: DateTime.utc(2026, 2, 1).millisecondsSinceEpoch + k * 1000,
          type: 'feeling_authored',
          payload: {
            'feeling_id': 'made_$k', 'name': 'the $k one', 'family': 'warmth',
            'colour': '#1f2a44', 'object_asset': 'obj_pinch', 'haptic': '80@90',
            'sound': 'snd_squeeze', 'retired': false,
          },
        ),
    ];

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
    //
    // What is asserted is the *shape* of the lookup, and it took three goes to find a way to say
    // that which holds on someone else's machine. A fixed ceiling — 20,000 us for 6,000 lookups —
    // went red on one full-suite run in four here. Timing the same questions against a linear walk
    // instead was better and still wrong: the two are different code and the compiler treats them
    // differently, so the margin was 22x here, 10x on a loaded run here, and 2.2x on a CI runner,
    // where it failed. A ratio between two different things is not a measurement of either.
    //
    // So: the same code, on the same machine, over two libraries a hundred times apart in size.
    // A map does not care how many feelings there are and a walk cares linearly, and nothing about
    // how fast the machine is or how warm the compiler got changes which of those is happening.
    final small = FeelingRegistry(_authored(50));
    final big = FeelingRegistry(_authored(5000));
    expect(big.all.length - small.all.length, 4950,
        reason: 'the two libraries have to differ by the amount this is measuring');

    const rounds = 2000;
    void spin(FeelingRegistry r) {
      for (var i = 0; i < rounds; i++) {
        r.byId('hold');
        r.byId('made_3');
        r.byId('not a feeling');
      }
    }

    // Both warmed before either is timed, so the first one timed is not paying for the compiler.
    spin(small);
    spin(big);
    final overFifty = _ms(() => spin(small));
    final overFiveThousand = _ms(() => spin(big));

    expect(small.byId('made_3')?.name, 'the 3 one');
    expect(big.byId('made_3')?.name, 'the 3 one');
    expect(big.byId('hold'), isNotNull);
    expect(big.byId('nope'), isNull);

    // A walk would be about a hundred times dearer over a hundred times the library; a map is
    // within noise of the same, give or take what a bigger table costs the cache. Eight is well
    // clear of both, which is the point: nothing in between has to be guessed at.
    expect(overFiveThousand, lessThan(overFifty * 8),
        reason: '${rounds * 3} lookups cost ${overFifty}us over 50 feelings and '
            '${overFiveThousand}us over 5000 — byId grows with the library, so it is walking it');

    final build = _ms(() => FeelingRegistry(year));
    expect(build, lessThan(60000), reason: 'building the registry took ${build}us');
    // ignore: avoid_print
    print('registry: build ${build}us, ${rounds * 3} lookups ${overFifty}us over 50 feelings, '
        '${overFiveThousand}us over 5000');
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

  test('a rebuild does not swallow the first mark of the year', () {
    // The projector holds, per person and signal, the last word it said, so a phone that flickers
    // between two networks does not narrate itself. _reset() cleared the hourly throttle and not
    // that, so a rebuild began holding what the previous fold had ended saying and suppressed the
    // first mark of every key whose opening word matched. It cost three rows of the seeded year,
    // silently, and five attempts at the 06 capture, which waited for a send that never crossed.
    //
    // A shorter log forces the rebuild, which is what a device that has been rolled back or has
    // caught up out of order hands the projector.
    final projector = ThreadProjector(me: Person.teo);
    projector.update(year);
    final shorter = year.sublist(0, year.length - 1);
    final folded = projector.update(shorter);
    final fresh = projectThread(shorter, me: Person.teo);
    expect(folded.items.length, fresh.items.length,
        reason: 'the rebuild lost ${fresh.items.length - folded.items.length} rows');
    for (var i = 0; i < fresh.items.length; i++) {
      expect(folded.items[i].id, fresh.items[i].id, reason: 'order differs at row $i');
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
