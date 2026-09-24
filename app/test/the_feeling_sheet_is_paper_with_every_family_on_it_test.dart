// The feeling corner turns up a sheet of paper with the whole vocabulary on it, not a scrim.
//
// Until firing 59 the open corner laid a gradient of 18% to 84% black over the page and put six
// family names on tabs, with only the selected family's objects under them. In 07_feeling_landing
// the cycle 3 critics read the partner card through it -- `room smells right again`, MOOD, HERE,
// PLACE -- and found five of the six families to be empty torn tabs with a name on them.
//
// This pumps the corner over Pulse, the way the shell stacks it, opens it where a thumb would, and
// asks two things. The sheet is an opaque torn piece of library stock whose rect covers every rect
// of their card's writing, found by what the writing says. And every active feeling in the
// registry -- counted, not assumed -- is on the sheet as an object, inside the screen, so none is
// more than one tap away and no family is a bare name.
//
// Re-break: put the gradient DecoratedBox back as `_Fan`'s ground, or draw only one family's
// members, and watch the matching case fail.
import 'package:desk/feelings/builtins.dart';
import 'package:desk/feelings/corner.dart';
import 'package:desk/material/desk.dart';
import 'package:desk/material/library.dart';
import 'package:desk/material/objects.dart';
import 'package:desk/material/paper.dart';
import 'package:desk/material/slip.dart';
import 'package:desk/regions/pulse/pulse_region.dart';
import 'package:desk/scope.dart';
import 'package:desk/spine/seed_loader.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/transport/local/local_transport.dart';
import 'package:desk/transport/sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String? absent;
  late AppScope scope;

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
        SpineStore.memory(), const Identity(person: Person.teo, device: DeviceKind.pwa));
    await SeedLoader(rootBundle).load(spine);
    final t = LocalTransport(role: TransportRole.client, spine: spine, deviceId: 'test');
    scope = AppScope(
      spine: spine,
      transport: t,
      sync: SyncEngine(spine: spine, transport: t),
      clock: Clock(frozenAt: DateTime.utc(2026, 9, 3, 19, 40)),
    );
  });

  Future<Rect> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(AppScope.provide(
      scope: scope,
      child: MaterialApp(
        // Inside what the shell puts around it: the partner strip above and the tab bar below.
        // Pumped bare, the region was 150 points taller than it is on the phone, everything fit,
        // and the first render of this sheet inside the real shell had Warmth scrolled off the
        // top of it. The bar is a stand-in of the shell's tab bar's height.
        home: Scaffold(
          body: Column(children: [
            PartnerStrip(
              partner: scope.partner,
              state: scope.partnerState,
              nowMs: scope.clock.now().millisecondsSinceEpoch,
              lastHeard: scope.partnerLastHeard,
            ),
            Expanded(
              child: Stack(children: [
                const PulseRegion(),
                FeelingCorner(registry: scope.feelings, onSend: (_, _) {}),
              ]),
            ),
            const SizedBox(height: 62),
          ]),
        ),
      ),
    ));
    await tester.pump();
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    await tester.tapAt(Offset(screen.width - 20, screen.height - 62 - 20));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    return Offset.zero & screen;
  }

  testWidgets('the open corner is an opaque torn sheet over their card, not a tint', (tester) async {
    if (absent != null) return markTestSkipped(absent!);
    await open(tester);
    final sheet = find.byWidgetPredicate((w) => w is PaperPiece && w.id == 'feelings.sheet');
    expect(sheet, findsOneWidget, reason: 'the vocabulary is not on a sheet of paper');
    final piece = tester.widget<PaperPiece>(sheet);
    expect(piece.tearId, isNotNull);
    expect(MaterialLibrary.instance.paper.map((p) => p.id), contains(piece.stockId));
    final sheetRect = tester.getRect(sheet);

    // their card's writing, by what it says: the status line and the stamped labels under it
    final them = scope.partnerState;
    final says = <String>[
      if (them.statusLine != null) them.statusLine!,
      if (them.mood != null) them.mood!,
    ];
    expect(says, isNotEmpty, reason: 'the scenario needs their card to have writing on it');
    var checked = 0;
    for (final t in says) {
      for (final e in find.descendant(of: find.byType(PulseRegion), matching: find.text(t)).evaluate()) {
        checked++;
        final r = tester.getRect(find.byWidget(e.widget).first);
        expect(sheetRect.contains(r.topLeft) && sheetRect.contains(r.bottomRight), isTrue,
            reason: '"$t" at $r is outside the sheet at $sheetRect, so it reads through');
      }
    }
    expect(checked, greaterThan(0), reason: 'none of their card\'s writing was found to check');
    // and nothing between the page and the sheet is a tint
    final grounds = tester.widgetList<DecoratedBox>(find.descendant(
        of: find.byType(FeelingCorner), matching: find.byType(DecoratedBox)));
    for (final g in grounds) {
      final d = g.decoration;
      expect(d is BoxDecoration && d.gradient != null, isFalse,
          reason: 'the corner still lays a gradient over the page');
    }
  });

  testWidgets('every feeling is on the sheet, and every family has its objects beside it',
      (tester) async {
    if (absent != null) return markTestSkipped(absent!);
    final screen = await open(tester);
    // inside the sheet's own writing area, which is what a scroll view in it can show: the tear's
    // safe insets off the piece's rect, so a row scrolled up under the torn top edge is not seen
    final sheetFinder = find.byWidgetPredicate((w) => w is PaperPiece && w.id == 'feelings.sheet');
    final piece = tester.widget<PaperPiece>(sheetFinder);
    final outer = tester.getRect(sheetFinder);
    final sheet = Rect.fromLTRB(
      outer.left + outer.width * piece.safe[0],
      outer.top + outer.height * piece.safe[1],
      outer.right - outer.width * piece.safe[2],
      outer.bottom - outer.height * piece.safe[3],
    );
    final active = scope.feelings.active;
    // POPULATION: the registry's own count, read rather than assumed
    expect(active.length, greaterThanOrEqualTo(Family.values.length));
    final drawn = <String>{};
    for (final e in find.byType(FeelingObject).evaluate()) {
      final w = e.widget as FeelingObject;
      final r = tester.getRect(find.byWidget(w).first);
      if (sheet.contains(r.topLeft) && sheet.contains(r.bottomRight)) drawn.add(w.feeling.id);
    }
    final missing = active.where((f) => !drawn.contains(f.id)).map((f) => f.name).toList();
    expect(missing, isEmpty,
        reason: '${missing.length} of ${active.length} feelings are not on the open sheet: $missing');
    for (final f in Family.values) {
      final tab = find.byWidgetPredicate((w) => w is Slip && w.id == 'family_${f.name}');
      expect(tab, findsOneWidget);
      final r = tester.getRect(tab);
      expect(screen.contains(r.topLeft) && screen.contains(r.bottomRight), isTrue,
          reason: '${f.label}\'s tab is not on the screen at $r');
      expect(scope.feelings.family(f), isNotEmpty, reason: '${f.label} has nothing in it');
    }
  });
}
