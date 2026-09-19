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
import 'package:desk/regions/chat/viewer_page.dart';
import 'package:desk/regions/moments/moments_region.dart';
import 'package:desk/spine/store/store.dart';
import 'package:desk/scope.dart';
import 'package:desk/spine/projections/state.dart';
import 'package:desk/spine/projections/thread.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/transport/local/local_transport.dart';
import 'package:desk/transport/sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:async';
import 'dart:typed_data';

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
      id: 'A$k', seq: seq, author: Person.noor, device: DeviceKind.android,
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

/// The store as the web actually has it: one lane.
///
/// `MemoryStore.getBlob` is an `async` getter over a map, so every read it is given completes on
/// the next microtask and the order they were asked in never matters. IndexedDB is not that. It
/// serves one read at a time, in the order the reads arrived, and a read issued late waits for
/// every read issued early — which is the whole of the defect this models. Making the test store
/// honest about that is what lets a widget test see a bug that only ever showed up in a capture.
///
/// It records the order it served, which is the measurement.
class _OneLaneStore implements SpineStore {
  final MemoryStore _inner = MemoryStore();

  /// The hashes the store was asked for, in the order it actually served them.
  final List<String> served = [];

  final List<({String hash, Completer<StoredBlob?> done})> _lane = [];

  /// How many reads are sitting in the store's lane, asked for and not yet answered.
  int get queued => _lane.length;

  /// Puts a blob in without going through the lane: this is the seeding, not the reading.
  Future<void> seedBlob(String hash, Uint8List bytes) => _inner.putBlob(hash, 'image/png', bytes);

  /// Answers the oldest outstanding read, and only that one.
  ///
  /// Hand-driven rather than timed, because what is being measured is which read is at the front
  /// of the queue when the next answer comes back, and a store that answers by itself would make
  /// that depend on how many times the test happened to pump.
  Future<void> serveOne() async {
    if (_lane.isEmpty) return;
    final next = _lane.removeAt(0);
    served.add(next.hash);
    next.done.complete(await _inner.getBlob(next.hash));
  }

  @override
  Future<StoredBlob?> getBlob(String hash) {
    final done = Completer<StoredBlob?>();
    _lane.add((hash: hash, done: done));
    return done.future;
  }

  @override
  Future<List<Event>> loadAll() => _inner.loadAll();
  @override
  Future<void> upsertAll(Iterable<Event> events) => _inner.upsertAll(events);
  @override
  Future<String?> getMeta(String key) => _inner.getMeta(key);
  @override
  Future<void> setMeta(String key, String? value) => _inner.setMeta(key, value);
  @override
  Future<void> putBlob(String hash, String mime, Uint8List bytes) => _inner.putBlob(hash, mime, bytes);
  @override
  Future<bool> hasBlob(String hash) => _inner.hasBlob(hash);
  @override
  Future<List<String>> blobHashes() => _inner.blobHashes();
  @override
  Future<void> wipe() => _inner.wipe();
  @override
  Future<void> close() => _inner.close();
}

/// The smallest thing Image.memory will decode: a 1x1 transparent PNG. The test is about which
/// order the bytes are fetched in, not about what they are a picture of.
final Uint8List _onePixelPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

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

  testWidgets('the photograph somebody opened is not read after the gallery behind it',
      (tester) async {
    // app.dart puts all five regions in an IndexedStack, so every region is laid out whatever is
    // on screen, and the Moments gallery is reading blobs for its tiles while a person is in
    // chat. Open a photograph and the viewer's read joins the back of a queue the gallery made.
    // The store is one lane on the web, so joining the back of the queue is the whole cost: two
    // captures photographed the result, firing 3 as `04_moments` with every print missing and
    // firing 4 as `14_media_viewer` with a caption and no photograph. Firing 3 established the
    // prints are not lost -- twelve seconds brings them all back -- so it is a queue, not a
    // decode failure, and a queue is a thing a test can see.
    //
    // What is asserted is position in the store's queue rather than a duration, because a
    // duration here would be measuring this machine. Position is the defect itself.
    // Guarded, and it has to be. `load()` reads `assets/INDEX.json` off `rootBundle`, and
    // rootBundle is a CachingAssetBundle: the SECOND call in a process awaits the Future the
    // FIRST call cached. That Future was completed inside the first test's fake-async zone, so a
    // later test awaiting it waits for a clock that has stopped -- ten minutes, then
    // `TimeoutException`, with no hint that a bundle was involved. `loaded` is a synchronous
    // getter for exactly this. The first widget test in this file calls load() unguarded and is
    // fine because it is first; any test added after it is not.
    if (!MaterialLibrary.loaded) await MaterialLibrary.load();
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    BlobCache.reset();
    addTearDown(BlobCache.reset);

    final prints = _aYearOfPrints();
    // An existing print from well down the year, not a new event bolted on the end. Two earlier
    // versions of this test invented an extra photograph, and both times the gallery put it in
    // the first screenful -- it carried the highest seq, and seq is what the gallery orders by,
    // so dating it oldest changed nothing. It was therefore tile one, the first blob the store
    // served, and the test passed with the fix taken out. A person scrolls down and taps an old
    // photograph; this is that, and it cannot drift back into the first screenful.
    final photo = prints[150];
    final opened = photo.payload['blob'] as String;
    // The same gallery across both pumps: a new key would throw its element away and re-issue
    // every read, which is not what tapping a photograph does.
    final galleryKey = GlobalKey();

    final store = _OneLaneStore();
    for (final e in prints) {
      await store.seedBlob(e.payload['blob'] as String, _onePixelPng);
    }

    final spine = await Spine.open(
      store, const Identity(person: Person.teo, device: DeviceKind.pwa));
    await spine.importSeed(prints);
    final transport = LocalTransport(role: TransportRole.client, spine: spine, deviceId: 'test');
    final scope = AppScope(
      spine: spine,
      transport: transport,
      sync: SyncEngine(spine: spine, transport: transport),
      clock: Clock(frozenAt: DateTime.utc(2026, 8, 30, 9, 14)),
    );
    addTearDown(scope.dispose);

    final item = ThreadItem(
      event: photo, text: null, edited: false, deleted: false,
      reactions: const [], replyTo: null, delivery: Delivery.read, writtenEarlier: false,
    );

    // The order this happens in is the whole thing, and the first version of this test got it
    // wrong. Mounting the gallery and the viewer in the same frame proves nothing: the viewer's
    // photograph is built during the build phase and the gallery's tiles are built during layout,
    // so the viewer's read is issued first anyway and the test passes with the fix taken out.
    //
    // What actually happens to a person is sequential. They are looking at Moments, its tiles are
    // already asked for and not yet answered, and then they tap one. So the gallery is pumped
    // first, and the viewer arrives while the gallery's reads are outstanding.
    await tester.pumpWidget(AppScope.provide(
      scope: scope,
      child: MaterialApp(home: Scaffold(body: Desk(child: MomentsRegion(key: galleryKey)))),
    ));
    await tester.pump();

    final tiles = find.byType(BlobImage).evaluate().length;
    expect(tiles, greaterThan(BlobCache.inFlightLimit + 1),
        reason: 'only $tiles tiles were laid out, so there is no queue here to get stuck behind '
            'and this test would prove nothing');
    expect(store.queued, BlobCache.inFlightLimit,
        reason: 'the store was handed ${store.queued} reads at once. BlobCache is supposed to let '
            'only ${BlobCache.inFlightLimit} through, and hold the rest where they can still be '
            'reordered — a read the store has accepted cannot be overtaken.');

    // Now the photograph is tapped. The viewer goes over the gallery on a route that is not
    // opaque (ViewerPage.open), so the gallery stays laid out underneath and its remaining tiles
    // are still queued.
    await tester.pumpWidget(AppScope.provide(
      scope: scope,
      child: MaterialApp(
        home: Scaffold(
          body: Desk(
            child: Stack(children: [MomentsRegion(key: galleryKey), ViewerPage(item: item)]),
          ),
        ),
      ),
    ));
    await tester.pump();

    // Drain the store one read at a time, the way one lane drains.
    for (var i = 0; i < tiles + 8 && !store.served.contains(opened); i++) {
      await store.serveOne();
      await tester.pump();
    }

    final at = store.served.indexOf(opened);
    expect(at, isNot(-1),
        reason: 'the opened photograph was never read; the store served ${store.served.length} '
            'blobs and none of them was it');

    // It cannot be first: the reads already accepted by the store when the viewer asked cannot be
    // overtaken. That bound is the budget, and it is the reason inFlightLimit is a small number
    // rather than a comfortable one.
    expect(at, lessThanOrEqualTo(BlobCache.inFlightLimit),
        reason: 'the opened photograph was blob number ${at + 1} out of the store, behind $at of '
            "the gallery's own tiles. That is what a person gets for tapping a photograph: an "
            'empty frame until every tile ahead of it has been read. The budget is '
            '${BlobCache.inFlightLimit}, the number of reads already in the store when they '
            'tapped.');

    expect(tester.takeException(), isNull);
  });

  testWidgets('a region that is not on screen does not read a year of pictures', (tester) async {
    // This is here because the queue item that produced the test above asserted the opposite, and
    // the opposite is what everything downstream of it was reasoning from: "IndexedStack builds
    // all five regions, so the Moments gallery is issuing blob reads even on a screen that is
    // showing chat". Built, yes. Reading, no -- and the difference is layout.
    //
    // IndexedStack keeps its other children in the tree with `maintainState`, which is `Offstage`,
    // and an offstage subtree is built but never laid out. A lazy sliver decides what to build
    // during layout, so with no layout it builds almost nothing. Measured here on the same year of
    // 183 prints: on screen the gallery builds 18 tiles, offstage inside an IndexedStack it builds
    // none at all, and laid out beside the viewer in a Stack it builds 18.
    //
    // So a viewer opened from chat is not waiting behind the gallery. It is the viewer opened from
    // Moments that has a queue in front of it, which is the arrangement the test above uses.
    // Guarded, and it has to be. `load()` reads `assets/INDEX.json` off `rootBundle`, and
    // rootBundle is a CachingAssetBundle: the SECOND call in a process awaits the Future the
    // FIRST call cached. That Future was completed inside the first test's fake-async zone, so a
    // later test awaiting it waits for a clock that has stopped -- ten minutes, then
    // `TimeoutException`, with no hint that a bundle was involved. `loaded` is a synchronous
    // getter for exactly this. The first widget test in this file calls load() unguarded and is
    // fine because it is first; any test added after it is not.
    if (!MaterialLibrary.loaded) await MaterialLibrary.load();
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    BlobCache.reset();
    addTearDown(BlobCache.reset);

    final prints = _aYearOfPrints();
    final store = _OneLaneStore();
    for (final e in prints) {
      await store.seedBlob(e.payload['blob'] as String, _onePixelPng);
    }
    final spine = await Spine.open(
      store, const Identity(person: Person.teo, device: DeviceKind.pwa));
    await spine.importSeed(prints);
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
      child: const MaterialApp(
        home: Scaffold(
          body: Desk(
            child: IndexedStack(
              index: 1,
              children: [MomentsRegion(), SizedBox.expand()],
            ),
          ),
        ),
      ),
    ));
    await tester.pump();

    final built = find.byType(BlobImage).evaluate().length;
    // ignore: avoid_print
    print('moments offstage: $built of ${prints.length} prints built');
    expect(built, lessThan(4),
        reason: '$built tiles were built by a gallery nobody is looking at. An offstage region '
            'reading the store is a region competing with the one on screen.');
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
