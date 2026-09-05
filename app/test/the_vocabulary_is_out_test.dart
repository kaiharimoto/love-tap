// The vocabulary comes out from the corner, all of it, and goes back when something is picked.
//
// The authored-feeling clip caught the sheet open with six family cards the full width of the
// sheet and not one feeling on it, and it stayed open through the whole clip after the send. A
// slip given no width takes all the width a Wrap offers; the harness sent past the sheet instead
// of off it. Both are read here from the widget itself.
import 'package:desk/feelings/builtins.dart';
import 'package:desk/feelings/corner.dart';
import 'package:desk/material/library.dart';
import 'package:desk/material/objects.dart';
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

void main() {
  late AppScope scope;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await MaterialLibrary.load();
  });
  setUp(() async => scope = await _aScope());
  tearDown(() => scope.dispose());

  testWidgets('every family is on the sheet, with its feelings, and a pick puts the sheet away',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    final sent = <String>[];
    await tester.pumpWidget(AppScope.provide(
      scope: scope,
      child: MaterialApp(
        home: Scaffold(
          body: Stack(children: [
            FeelingCorner(registry: scope.feelings, onSend: (f, _) => sent.add(f.id)),
          ]),
        ),
      ),
    ));
    await tester.pump();

    // the corner is the bottom right of the screen; a tap on it turns the sheet out
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    await tester.tapAt(Offset(size.width - 16, size.height - 16));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);

    for (final f in Family.values) {
      expect(find.text(f.label.toUpperCase()), findsOneWidget, reason: '${f.label} is not on the sheet');
    }
    // the family cards are cards, not bars: each is narrower than half the sheet
    for (final f in Family.values) {
      final card = tester.getSize(find.ancestor(of: find.text(f.label.toUpperCase()), matching: find.byType(IntrinsicWidth)).first);
      expect(card.width, lessThan(size.width / 2), reason: '${f.label} card is ${card.width} wide');
    }
    // and the feelings of the family that is open are on it, with their whole names
    final tiles = find.byType(FeelingObject);
    expect(tiles, findsAtLeastNWidgets(4), reason: 'no feelings on the sheet');
    for (final f in scope.feelings.family(Family.warmth)) {
      expect(find.text(f.name), findsOneWidget, reason: '${f.name} is not on the sheet');
    }

    // picking one sends it and the sheet goes back under the corner
    await tester.tap(tiles.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    expect(sent, hasLength(1));
    expect(find.text(Family.warmth.label.toUpperCase()), findsNothing, reason: 'the sheet is still out');
  });
}
