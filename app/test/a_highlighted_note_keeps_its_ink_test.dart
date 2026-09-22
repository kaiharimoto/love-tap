// The note a search hit takes you to is lit for three seconds, and its words must stay as dark as
// they were.
//
// `ChatRegion._goTo` sets `highlight` on the note a person jumps to from a search hit. Until firing
// 49 that highlight was a `DecoratedBox` in the note's `overlays` -- which `PaperPiece` paints AFTER
// the words -- at 45% yellow, on top. So the one note the person had asked to see was the one note
// on the screen with its ink washed toward yellow. `a_highlighter_is_a_dye_test.dart` checks the
// source says multiply; this checks the pixels, on the real `Note`, built the way the thread builds
// it, because a test of a blend mode on a bare box would be a test of a widget the app never draws.
//
// The ink is read as the darkest two per cent of the note's pixels. `flutter test` sets text in
// Ahem, whose glyphs are solid squares, so that tail is the ink and nothing else.

import 'dart:ui' as ui;

import 'package:desk/material/library.dart';
import 'package:desk/regions/chat/note.dart';
import 'package:desk/scope.dart';
import 'package:desk/spine/seed_loader.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/transport/local/local_transport.dart';
import 'package:desk/transport/sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppScope scope;
  String? absent;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    try {
      await MaterialLibrary.load();
    } catch (_) {
      absent = 'this bundle was packed without a material library '
          '(tools/pack_assets.py --seed=year puts it in)';
      return;
    }
    final spine = await Spine.open(
      SpineStore.memory(),
      const Identity(person: Person.teo, device: DeviceKind.pwa),
    );
    await SeedLoader(rootBundle).load(spine);
    final transport = LocalTransport(role: TransportRole.client, spine: spine, deviceId: 'test');
    scope = AppScope(
      spine: spine,
      transport: transport,
      sync: SyncEngine(spine: spine, transport: transport),
      clock: Clock(frozenAt: DateTime.utc(2026, 9, 3, 19, 40)),
    );
  });

  /// (ink, paper blue): the luminance of the darkest 2% of the note, and the median blue channel,
  /// which is what a yellow highlighter takes away and so says whether the highlight was drawn.
  Future<(double, double)> read(WidgetTester tester, {required bool highlight}) async {
    // Mine, so it is never folded, and with words on it.
    final items = scope.thread.items;
    final it = items.lastWhere(
        (i) => i.event.author == scope.me && (i.text ?? '').length > 20 && !i.deleted);
    final row = items.indexOf(it);
    final key = GlobalKey();
    await tester.pumpWidget(AppScope.provide(
      scope: scope,
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: 380,
                child: Note(
                  key: ValueKey('${it.id}$highlight'),
                  item: it,
                  row: row,
                  unreadFrom: 1 << 30,
                  registry: scope.feelings,
                  highlight: highlight,
                  onLongPress: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    ));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    }
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final bytes = (await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      return image.toByteData(format: ui.ImageByteFormat.rawRgba);
    }))!;
    final lum = <double>[];
    final blue = <double>[];
    for (var p = 0; p + 3 < bytes.lengthInBytes; p += 4) {
      if (bytes.getUint8(p + 3) < 250) continue;
      final r = bytes.getUint8(p), g = bytes.getUint8(p + 1), b = bytes.getUint8(p + 2);
      lum.add(0.2126 * r + 0.7152 * g + 0.0722 * b);
      blue.add(b.toDouble());
    }
    lum.sort();
    blue.sort();
    expect(lum.length, greaterThan(5000), reason: 'the note drew almost nothing opaque');
    return (lum[(lum.length * 0.02).floor()], blue[blue.length ~/ 2]);
  }

  testWidgets('a highlighted note is lit, and its ink is no lighter than it was', (tester) async {
    if (absent != null) {
      markTestSkipped(absent!);
      return;
    }
    final (inkOff, blueOff) = await read(tester, highlight: false);
    final (inkOn, blueOn) = await read(tester, highlight: true);
    // ignore: avoid_print
    print('ink p2 ${inkOff.toStringAsFixed(1)} -> ${inkOn.toStringAsFixed(1)}, '
        'paper median blue ${blueOff.toStringAsFixed(0)} -> ${blueOn.toStringAsFixed(0)}');
    expect(blueOn, lessThan(blueOff - 40),
        reason: 'the highlight did not reach the paper, so the ink reading below means nothing');
    expect(inkOn, lessThanOrEqualTo(inkOff + 3),
        reason: 'the highlight lightened the words it was meant to point at: on top, it veils '
            'them; multiplied, the ink is as dark as the paper under it lets it be');
  });
}
