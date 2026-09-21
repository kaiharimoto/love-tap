// Twelve seconds is what it costs to LAY the year down, not what it costs to open it.
//
// The queue item this belongs to was filed on a real measurement and read the wrong thing off it.
// Firing 30 timed `cold_ms` at 10,884-12,327 ms on the thirteen scenes served the seeded build and
// 1,259-1,321 ms on the three served the fresh one, called it 8.7x and about 0.7 ms per event, and
// concluded: "A person opening this app after a year of using it waits twelve seconds."
//
// Every one of those thirteen numbers is a FIRST RUN. `tools/capture/scene.js` does
// `browser.launch()` and `newContext()` per scene, one node process per scene, so every scene gets
// an empty IndexedDB and pays the whole seed import — 14,061 events and 197 blobs out of the
// bundle and into the store. A person pays that once, on the install, and never again:
// `SeedLoader.load` asks `alreadyLoaded` first and returns null.
//
// Measured on the real platform at firing 40, chromium against the release web build, ONE context
// loaded three times:
//
//     load 0 (empty store, the import):   8,686 ms     14,061 events
//     load 1 (same context):              1,301 ms     14,061 events
//     load 2 (same context):              1,101 ms     14,061 events
//     a fresh context, for the control:   8,306 ms
//
// So opening a spine with a year in it costs the same as opening an empty one — 1,101-1,301 ms
// against the seedless build's 1,259-1,321. The honest limit firing 30 recorded, that the seeded
// and fresh builds differ in bundle weight as well as in seed, is settled by this and not by the
// third build it asked for: loads 1 and 2 ship the identical bundle and take a tenth of load 0.
//
// A clock is not a thing to assert on, so this asserts the PROPERTY the numbers are made of: the
// import happens once, and the open after it reads the whole year without doing the import again.
// Re-break by deleting the `alreadyLoaded` guard in `SeedLoader.load` and watching the second open
// re-import the year.
import 'dart:io';

import 'package:desk/spine/seed_loader.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/spine/store/store_sqlite.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the year is laid down once and opened ever after', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    try {
      await rootBundle.loadString('assets/seed/index.json');
    } catch (_) {
      // ignore: avoid_print
      print('skipped: this bundle was packed without the seeded year '
          '(tools/pack_assets.py --seed=year puts it in)');
      return;
    }

    final dir = Directory.systemTemp.createTempSync('a_year_opened');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/spine.sqlite3';

    // The install.
    var store = NativeStore.openAt(path);
    var spine = await Spine.open(
      store, const Identity(person: Person.teo, device: DeviceKind.pwa));
    final laid = Stopwatch()..start();
    final first = await SeedLoader(rootBundle).load(spine);
    laid.stop();
    expect(first, isNotNull, reason: 'the first load did not import the year at all');
    expect(first!.events, greaterThan(14000),
        reason: 'the year is ${first.events} events, so this is not the year');
    final events = spine.length;
    await store.close();

    // Every time after it. Three of them, because "it is not re-imported" has to be true of the
    // third open as well as the second — the meta key is the whole mechanism and a store that
    // forgets it on close would pass a single reopen.
    for (var i = 0; i < 3; i++) {
      store = NativeStore.openAt(path);
      final opened = Stopwatch()..start();
      spine = await Spine.open(
        store, const Identity(person: Person.teo, device: DeviceKind.pwa));
      opened.stop();
      final again = await SeedLoader(rootBundle).load(spine);

      expect(again, isNull,
          reason: 'open $i re-imported the year: ${again?.events} events laid down a second '
              'time. That is the twelve seconds, and it would now be twelve seconds every time '
              'somebody opened the app rather than once when they installed it.');
      expect(spine.length, events,
          reason: 'open $i read ${spine.length} of $events events, so the year did not survive '
              'the close and the number above is about the wrong thing');
      // ignore: avoid_print
      print('import ${laid.elapsedMilliseconds} ms; open $i '
          '${opened.elapsedMilliseconds} ms over ${spine.length} events');
      await store.close();
    }
  }, timeout: const Timeout(Duration(minutes: 10)));

  test('every capture scene is a first run, which is why every capture scene is slow', () {
    // The other half, and the half that makes the numbers in the item readable. This is a fact
    // about the harness rather than about the app, so it is read off the harness: one browser and
    // one fresh context per scene means an empty IndexedDB per scene, so `cold_ms` in every scene
    // log is the install and never the reopen. Anybody reading those numbers as what a person
    // waits should find this test when they grep for the reason.
    final src = File('../tools/capture/scene.js').readAsStringSync();
    expect(src.contains('browser.newContext('), isTrue,
        reason: 'scene.js no longer makes its own context, so the claim above may have stopped '
            'being true and cold_ms may now mean something else');
    expect(src.contains('log.cold_ms = Date.now() - t0'), isTrue,
        reason: 'cold_ms is not measured where this thinks it is');
    // A context with storage state carried into it would change the answer, and quietly.
    expect(src.contains('storageState'), isFalse,
        reason: 'scene.js now hands its context a storage state, so a scene may no longer be a '
            'first run — which is the whole reading of cold_ms in evidence/logs/*.json');
  });
}
