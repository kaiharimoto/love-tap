// Every feeling family is on the screen, not merely in the widget tree.
//
// The evidence counted four families where the rubric floor is five, and the cause was not a
// missing family: `corner.dart` iterates `Family.values`, all six of them, and always has. They
// were in a horizontally scrolling `Row`, and six index-card tabs reading Warmth, Ache, Shelter,
// Mischief, Static and Sparkle do not fit across a phone. Four fitted. Two sat past the right edge
// of a strip with no arrow, no fade and no reason for anyone to guess it could be dragged.
//
// That is why this counts geometry rather than widgets. `find.byType` would have returned six for
// the whole life of the bug, and a test that reports six while a person can see four is worse than
// no test: it is a guard that certifies the thing it was written to catch. So each tab's rect is
// taken from the render tree and checked against the screen it is supposed to be on.
import 'package:desk/feelings/builtins.dart';
import 'package:desk/feelings/corner.dart';
import 'package:desk/material/desk.dart';
import 'package:desk/material/library.dart';
import 'package:desk/material/slip.dart';
import 'package:desk/scope.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/transport/local/local_transport.dart';
import 'package:desk/transport/sync.dart';
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

/// The families whose tab is actually inside the screen, by name.
///
/// "Inside" means the whole tab, not a sliver of it: a card cut in half by the right edge is not a
/// family a person can read, and counting it would reproduce the bug in the measurement.
Set<String> _familiesOnScreen(WidgetTester tester) {
  final screen = Offset.zero & (tester.view.physicalSize / tester.view.devicePixelRatio);
  final seen = <String>{};
  for (final element in find.byType(Slip).evaluate()) {
    final slip = element.widget as Slip;
    if (!slip.id.startsWith('family_')) continue;
    final box = element.renderObject as RenderBox?;
    if (box == null || !box.hasSize) continue;
    final topLeft = box.localToGlobal(Offset.zero);
    final rect = topLeft & box.size;
    if (screen.contains(rect.topLeft) && screen.contains(rect.bottomRight)) {
      seen.add(slip.id.substring('family_'.length));
    }
  }
  return seen;
}

void main() {
  late AppScope scope;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await MaterialLibrary.load();
  });
  setUp(() async => scope = await _aScope());
  tearDown(() => scope.dispose());

  testWidgets('all six families are on the screen at once', (tester) async {
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(AppScope.provide(
      scope: scope,
      child: MaterialApp(
        home: Scaffold(
          body: Desk(
            child: FeelingCorner(
              registry: scope.feelings,
              onSend: (_, _) {},
            ),
          ),
        ),
      ),
    ));
    await tester.pump();

    // The fan is shut until the turned-up corner is tapped, and the corner is a 74 by 74 target
    // pinned to the bottom right. Pressing the middle of `FeelingCorner` presses the desk, and
    // `CaptureBus.openCorner` -- which is how the capture harness opens it -- is only registered
    // under `Flags.capture`, a compile-time constant. So this taps where a thumb would.
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    await tester.tapAt(Offset(screen.width - 20, screen.height - 20));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final onScreen = _familiesOnScreen(tester);
    final missing = Family.values.map((f) => f.name).toSet().difference(onScreen);

    // ignore: avoid_print
    print('families on screen: ${onScreen.length} of ${Family.values.length}'
        '${missing.isEmpty ? '' : ', missing ${missing.join(', ')}'}');

    // Five is the rubric floor and six is the number there are. There is no reason to ship the
    // floor when the whole set fits on two lines.
    expect(onScreen.length, Family.values.length,
        reason: 'only ${onScreen.length} of ${Family.values.length} family tabs are on the '
            'screen; ${missing.join(', ')} ${missing.length == 1 ? 'is' : 'are'} past the edge. '
            'The evidence counts what is visible, not what is built.');
  });
}
