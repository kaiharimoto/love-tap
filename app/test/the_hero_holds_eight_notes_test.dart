// The chat hero's own standard, measured on the real year before a capture is spent on it.
//
// tools/check/tears.py fails 02_chat.png unless eight rows were on the glass, each on its own
// torn edge. Which stretch of a year does that cannot be worked out from the text: it depends on
// how tall each row lays out — how many words wrapped, what is stuck to it, whether it carries a
// waveform. Estimating it from the length of the writing framed six notes, then seven, and the
// artifact was recorded missing on its own standard twice. So the app measures instead, and so
// does this: the same seeded year, on a surface the size of the one the scene shoots, through
// the same handle the harness pulls.
import 'dart:io';
import 'dart:typed_data';

import 'package:desk/app.dart';
import 'package:desk/capture/bus.dart';
import 'package:desk/material/library.dart';
import 'package:desk/regions/chat/chat_region.dart';
import 'package:desk/scope.dart';
import 'package:desk/spine/seed_loader.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/spine/store/store.dart';
import 'package:desk/transport/local/local_transport.dart';
import 'package:desk/transport/sync.dart';
import 'package:desk/transport/transport.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the hero framing puts eight rows on the glass', timeout: const Timeout(Duration(minutes: 25)), (tester) async {
    final began = DateTime.now();
    void mark(String what) => debugPrint('[${DateTime.now().difference(began).inSeconds}s] $what');
    await MaterialLibrary.load();
    // The real hands, not the test font. A widget test lays every string out in Ahem unless the
    // face it names has been loaded, and Ahem is a different width and a different height: the
    // same stretch of thread that fits seven rows on a phone fitted five here, which would have
    // sent a capture off to frame the wrong place.
    for (final face in const ['TeoHand', 'NoorHand', 'DeskStamp']) {
      final loader = FontLoader(face)
        ..addFont(Future.value(
            File('assets/fonts/$face.ttf').readAsBytesSync().buffer.asByteData()));
      await loader.load();
    }
    CaptureBus.wanted = true;
    addTearDown(() => CaptureBus.wanted = false);

    final spine = await Spine.open(
      SpineStore.memory(),
      const Identity(person: Person.teo, device: DeviceKind.pwa),
    );
    // the same loader the app and the far phone use, off the packed assets rather than a bundle,
    // so the rows are the year's own rows with the year's own authors
    final seeded = await SeedLoader(_OffDisk(Directory.current.path)).load(spine);
    expect(seeded, isNotNull, reason: 'the seeded year did not load');
    expect(spine.length, greaterThan(10000), reason: 'only ${spine.length} events loaded');
    mark('the year is in: ${spine.length} events');
    final transport = LocalTransport(role: TransportRole.client, spine: spine, deviceId: 'test');
    final scope = AppScope(
      spine: spine,
      transport: transport,
      sync: SyncEngine(spine: spine, transport: transport),
      clock: Clock(frozenAt: DateTime.utc(2026, 9, 3, 19, 40)),
    );
    addTearDown(scope.dispose);

    // the surface 02_chat is shot on, and the app's own shell around the thread, so the room the
    // list has is the room it has on the phone rather than a guess at the chrome
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(AppScope.provide(
      scope: scope,
      child: const MaterialApp(home: Shell()),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    CaptureBus.goToRegion!(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    mark('the thread is drawn');

    var settled = false;
    CaptureBus.scrollTo!('types:voice_note,reacted').then((_) => settled = true);
    for (var i = 0; i < 2000 && !settled; i++) {
      await tester.pump(const Duration(milliseconds: 40));
      if (i % 20 == 0) mark('pump $i');
    }
    mark('the search is done');
    expect(settled, isTrue, reason: 'the framing search never finished');
    await tester.pump(const Duration(milliseconds: 200));

    final report = CaptureBus.chatReport!();
    final visible = (report['visible'] as List).length;
    final paper = (report['paper'] as List).length;
    final whole = report['paper_whole_on_the_glass'] as int;
    debugPrint('anchor: ${report['anchor']}');
    debugPrint('rows: $visible  paper: $paper  whole: $whole  kinds: ${report['kinds']}');
    debugPrint('viewport ${report['viewport_tall']} logical px');
    for (final r in report['rows_cost'] as List) {
      debugPrint('  row ${r['row']} ${r['type']} top ${r['top']} tall ${r['tall']}');
    }
    // eight pieces of paper on the glass, which is what the standard means by eight notes, and
    // seven of them whole, which is what makes it a photograph rather than a list of slivers
    expect(paper, greaterThanOrEqualTo(8),
        reason: 'the hero framed $paper sheets of paper among $visible rows: ${report['anchor']}');
    expect(whole, greaterThanOrEqualTo(7),
        reason: 'only $whole of $paper sheets were whole on the glass: ${report['anchor']}');
  });
}

class _OffDisk implements SeedSource {
  _OffDisk(this.root);
  final String root;

  // Read off the disk without going near the event loop. A widget test runs inside a fake-async
  // zone: a real asynchronous read completes on the real one, and awaiting it there is how a test
  // sits for twelve minutes and is then killed.
  @override
  Future<String> loadString(String path) async => File('$root/$path').readAsStringSync();

  @override
  Future<Uint8List> loadBytes(String path) async => File('$root/$path').readAsBytesSync();
}
