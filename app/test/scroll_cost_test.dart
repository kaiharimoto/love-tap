// What it costs to draw one frame against a year of history.
//
// Rubric row 01 says "no scroll jank against the year-deep seeded history", which is a claim about
// milliseconds, so it is measured here rather than asserted. The seeded year is about fourteen
// thousand events; a frame at sixty a second has sixteen milliseconds for everything.
//
// The numbers below are budgets, not measurements of a good day: they are set well above what the
// code does now, so this fails when something gets slower rather than when a machine is busy.
import 'package:desk/feelings/registry.dart';
import 'package:desk/material/desk.dart';
import 'package:desk/material/library.dart';
import 'package:desk/regions/chat/blob_widgets.dart';
import 'package:desk/regions/moments/moments_region.dart';
import 'package:desk/scope.dart';
import 'package:desk/spine/projections/state.dart';
import 'package:desk/spine/projections/thread.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/transport/local/local_transport.dart';
import 'package:desk/transport/sync.dart';
import 'package:flutter/material.dart';
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

List<Event> _aYearOfPrints({int count = 183}) {
  final out = <Event>[];
  for (var i = 0; i < count; i++) {
    out.add(Event(
      id: 'P${i.toString().padLeft(6, '0')}',
      seq: i + 1,
      author: i % 2 == 0 ? Person.noor : Person.teo,
      device: i % 2 == 0 ? DeviceKind.android : DeviceKind.pwa,
      ts: DateTime.utc(2025, 9, 1).millisecondsSinceEpoch + i * 1800000,
      type: 'photo',
      // The shapes vary because the gallery is masonry: every tile the same height would hide
      // whether the column arithmetic still works.
      payload: {'blob': 'hash$i', 'w': 4, 'h': 3 + (i % 3)},
      blobs: ['hash$i'],
    ));
  }
  return out;
}

Future<Spine> _spineOf(List<Event> events) async {
  final spine = await Spine.open(
    SpineStore.memory(),
    const Identity(person: Person.teo, device: DeviceKind.pwa),
  );
  await spine.importSeed(events);
  return spine;
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

  test('reading the whole log twice between two changes costs one walk, not two', () async {
    // MomentsRegion and UsRegion both open build() with `scope.spine.all`, and that getter was
    // `[..._ordered, ..._pending]` — a fresh fourteen-thousand-element list allocated per frame,
    // per region. `countOf` was a linear scan beside it, and the scope asks it on every change,
    // which a scroll emits constantly because a read marker is an event.
    final spine = await _spineOf(year);

    // Warm, so this measures the work and not the JIT.
    for (var i = 0; i < 3; i++) {
      spine.all;
      spine.countOf('message');
    }

    final again = _ms(() {
      for (var i = 0; i < 200; i++) {
        spine.all;
      }
    });
    final counts = _ms(() {
      for (var i = 0; i < 200; i++) {
        spine.countOf('feeling_authored');
      }
    });

    // ignore: avoid_print
    print('spine.all: 200 reads ${again}us; 200 countOf ${counts}us '
        'over ${spine.all.length} events');

    expect(spine.all.length, year.length);
    expect(spine.countOf('feeling_authored'), 6);
    expect(spine.countOf('message'), year.where((e) => e.type == 'message').length);
    expect(spine.countOf('not an event type'), 0);

    // 200 frames' worth of asking. Memoised this measures 65us and 88us; with the old getters put
    // back it is 12602us and 17085us, so 2000 is twenty times the headroom a warm machine needs
    // and six times below the regression it has to catch. A 16000 budget — one frame — was not
    // enough: 200 copies of the year came in under it and only the scan tripped.
    expect(again, lessThan(2000),
        reason: 'asking for the whole log 200 times cost ${again}us — it is being rebuilt');
    expect(counts, lessThan(2000),
        reason: 'counting one type 200 times cost ${counts}us — it is still a scan');
  });

  test('the memoised log is never stale, whichever way an event arrives', () async {
    // The cache is invalidated by hand at six mutation sites, and the failure mode of missing one
    // is silent and terrible: a region drawing a year that no longer exists. So each way in is
    // walked here and the memoised answer is checked against the arithmetic every time.
    final spine = await _spineOf(year.sublist(0, 200));

    void agrees(String after) {
      final all = spine.all;
      expect(all.length, spine.ordered.length + spine.pending.length, reason: 'length, $after');
      final tally = <String, int>{};
      for (final e in all) {
        tally[e.type] = (tally[e.type] ?? 0) + 1;
      }
      for (final type in tally.keys) {
        expect(spine.countOf(type), tally[type], reason: 'countOf($type), $after');
      }
    }

    agrees('a seed import');

    // minted here and accepted immediately: straight into _ordered
    final was = spine.all.length;
    await spine.append('message', {'text': 'written on this device'}, hostAssign: true);
    expect(spine.all.length, was + 1, reason: 'a minted event is missing from the memoised list');
    expect(spine.all.last.payload['text'], 'written on this device');
    agrees('an event minted with a seq');

    // minted into the outbox: into _pending, and `all` is ordered-then-pending
    final pending = await spine.append('message', {'text': 'still in the outbox'});
    expect(spine.all.length, was + 2);
    expect(spine.pending.map((e) => e.id), contains(pending.id));
    agrees('an event minted into the outbox');

    // and the host giving that pending event its seq, which moves it between the two lists
    // without changing the length — which is exactly what a length-based cache key would miss.
    await spine.applyFromHost([pending.withSeq(spine.maxSeq + 1)]);
    expect(spine.pending.map((e) => e.id), isNot(contains(pending.id)),
        reason: 'the event left the outbox but the memoised list still shows it there');
    expect(spine.all.length, was + 2);
    agrees('the outbox event coming back with a seq');
  });

  testWidgets('a year of prints does not all get built to show the first screenful',
      (tester) async {
    // Moments came back from the capture as five rows of "still fetching the picture." and no
    // thumbnail at all. The gallery was a SingleChildScrollView over a Row of three Columns, which
    // has no lazy child model: every tile in the year is built on the first frame. A tile is a
    // BlobImage, so that is one IndexedDB read per print, all issued at once. They do not fail,
    // they queue, and the queue is longer than the frame that was going to draw them.
    //
    // So the number that matters is not a duration, it is how many tiles exist. This is the case
    // that fails against the SingleChildScrollView: with it, the count below is the whole year.
    await MaterialLibrary.load();
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final prints = _aYearOfPrints();
    final spine = await _spineOf(prints);
    final transport = LocalTransport(role: TransportRole.client, spine: spine, deviceId: 'test');
    final scope = AppScope(
      spine: spine,
      transport: transport,
      sync: SyncEngine(spine: spine, transport: transport),
      clock: Clock(frozenAt: DateTime.utc(2026, 8, 30, 9, 14)),
    );
    addTearDown(scope.dispose);

    await tester.pumpWidget(AppScope.provide(
      scope: scope,
      child: const MaterialApp(home: Scaffold(body: Desk(child: MomentsRegion()))),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);

    final built = find.byType(BlobImage).evaluate().length;
    // ignore: avoid_print
    print('moments: $built of ${prints.length} prints built for the first screenful');

    // The screen is 480 by 1040 and a tile is about a third of that wide, so a screenful is
    // roughly a dozen. A sliver builds a cache extent either side of that, so the budget is
    // generous; what it will not tolerate is the whole year.
    expect(built, greaterThan(0), reason: 'no print was built at all — the gallery is empty');
    expect(built, lessThan(60),
        reason: '$built of ${prints.length} prints were built to fill one screen. That is every '
            'tile in the year, which is $built concurrent blob reads, which is why the capture '
            'caught "still fetching the picture." and no thumbnail.');

    // and it is still the whole year underneath: lazy, not truncated
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -20000));
    await tester.pump();
    expect(tester.takeException(), isNull);
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
