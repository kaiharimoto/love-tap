// Holding a feeling is a gesture that takes time, so the picture has to move while it does.
//
// The frame check counted forty byte-identical frames in a row in 15_authored_feeling — the whole
// of the run where the scene puts a finger on `pigeon` and holds it. Two things were wrong and
// only the first had been found. The charge does grow the object, but from 0.952 to 1.12 of scale
// over 1.8 seconds, which on a 92 point tile is 0.05 of a device pixel between frames: the growth
// was real and invisible. And nothing was asking for a frame at all on a phone — `_curl` has
// finished by the time a finger is resting, and an AnimatedBuilder on a finished controller does
// not rebuild — so the earlier fix, which asked the *driven* clock for a repaint, moved nothing on
// the clock a phone runs on.
//
// So the hold lifts the thing off the sheet, the way the landing puts it down, and the ticker that
// drives it is the one both clocks turn. Both halves are read here from the widgets themselves.
import 'package:desk/feelings/builtins.dart';
import 'package:desk/feelings/corner.dart';
import 'package:desk/feelings/drawn.dart';
import 'package:desk/material/library.dart';
import 'package:desk/material/objects.dart';
import 'package:desk/material/paper.dart';
import 'package:desk/scope.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/spine/store/store.dart';
import 'package:desk/transport/local/local_transport.dart';
import 'package:desk/transport/sync.dart';
import 'package:desk/transport/transport.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<AppScope> _aScope() async {
  final spine = await Spine.open(
    SpineStore.memory(),
    const Identity(person: Person.teo, device: DeviceKind.pwa),
  );
  final transport = LocalTransport(role: TransportRole.client, spine: spine, deviceId: 'test');
  return AppScope(
    spine: spine,
    transport: transport,
    sync: SyncEngine(spine: spine, transport: transport),
    clock: Clock(frozenAt: DateTime.utc(2026, 8, 30, 9, 14)),
  );
}

/// A [FeelingObject] on its own, at a stated lift.
Future<void> _one(WidgetTester tester, Feeling f, double lift, {required bool onPaper}) =>
    tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: FeelingObject(feeling: f, size: 96, lift: lift, onPaper: onPaper),
        ),
      ),
    ));

void main() {
  late AppScope scope;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await MaterialLibrary.load();
  });
  setUp(() async => scope = await _aScope());
  tearDown(() => scope.dispose());

  testWidgets('a finger resting on a tile keeps changing the picture', (tester) async {
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(AppScope.provide(
      scope: scope,
      child: MaterialApp(
        home: Scaffold(
          body: Stack(children: [
            FeelingCorner(registry: scope.feelings, onSend: (f, _) {}),
          ]),
        ),
      ),
    ));
    await tester.pump();

    // press the corner and keep the thumb down: that is the hold
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    final thumb = await tester.startGesture(Offset(size.width - 16, size.height - 16));
    await tester.pump(const Duration(milliseconds: 600)); // past the long-press threshold
    await tester.pump(const Duration(milliseconds: 400)); // the sheet is out

    // drag onto the first feeling of the family that is open
    final tiles = find.byType(FeelingObject);
    expect(tiles, findsAtLeastNWidgets(4), reason: 'the sheet is not out');
    await thumb.moveTo(tester.getCenter(tiles.first));
    await tester.pump();
    await tester.pump();

    FeelingObject held() => tester
        .widgetList<FeelingObject>(tiles)
        .reduce((a, b) => a.size >= b.size ? a : b); // the held tile is drawn larger

    final atFirst = held();
    // read first, so a drag that did not land reads as that rather than as a hold that did nothing
    final resting = tester
        .widgetList<FeelingObject>(tiles)
        .map((t) => t.size)
        .reduce((a, b) => a <= b ? a : b);
    expect(atFirst.size, greaterThan(resting), reason: 'the thumb is not on a tile');
    expect(atFirst.lift, lessThan(0.05), reason: 'the hold has barely begun');

    // The charge is written against the clock the app is running on, which in a test is the wall
    // clock, so the time has to actually pass. runAsync is the only thing that lets it — and it is
    // *real* time, so a fixed delay is a race with whatever else the machine is doing. Under a
    // loaded box this test passed alone and failed in the suite. It waits for the thing it is
    // about instead: the hold having grown.
    for (var tries = 0; tries < 20 && held().lift <= 0.1; tries++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
      await tester.pump();
      await tester.pump();
    }

    final later = held();
    expect(later.lift, greaterThan(0.1),
        reason: 'the thing being charged is still flat on the sheet after 0.9 s of holding');
    expect(later.shadowScale, lessThan(0.95),
        reason: 'it came off the sheet and its shadow did not change');
    expect(later.intensity, greaterThan(atFirst.intensity), reason: 'the charge is not growing');

    await thumb.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('a lift moves a drawn mark, not only a rendered object', (tester) async {
    // Half the vocabulary is a mark somebody made rather than a thing that was photographed, and
    // the mark branches threw `lift` away: in the same picker one tile rose off the sheet and the
    // one beside it stayed flat, which is two physics in one picture.
    final drawn = scope.feelings.all.firstWhere((f) => DrawnFeelingMark.has(f.object));

    await _one(tester, drawn, 0.0, onPaper: false);
    final flat = tester.getTopLeft(find.byType(DrawnFeelingMark));
    await _one(tester, drawn, 0.5, onPaper: false);
    final up = tester.getTopLeft(find.byType(DrawnFeelingMark));
    expect(up.dy, lessThan(flat.dy - 8.0), reason: 'a held mark does not leave the desk');

    // and on a scrap the scrap is what is picked up, so what changes is the shadow under it
    await _one(tester, drawn, 0.0, onPaper: true);
    final resting = tester.widget<PaperPiece>(find.byType(PaperPiece)).liftMm;
    await _one(tester, drawn, 0.5, onPaper: true);
    final lifted = tester.widget<PaperPiece>(find.byType(PaperPiece)).liftMm;
    expect(lifted, greaterThan(resting + 1.0), reason: 'the scrap stays on the desk when held');
  });
}
