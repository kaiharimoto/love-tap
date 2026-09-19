// No word in this app is written on the desk.
//
// This is the structural half of `docs/COLOR.md` section 6, and it exists because the arithmetic
// half admits no exceptions and therefore needs none. The desk plate's grain reaches Y 0.1467, and
// 4.5:1 against that requires a darker ink at Y = (0.1467 + 0.05) / 4.5 - 0.05, which is -0.006.
// That is not a hard number to hit. It does not exist. No ink of any colour, at any weight, is
// legible on this plank, so there is nothing here to tune and the only available move is to stop
// writing on it.
//
// `legible_on_what_it_is_on_test.dart` checks declared pairs and cannot see this: a pair is two
// colours, and the failure was never about the colours, it was about one of them being a
// photograph. `tools/check/legibility.py` can see it but only after a capture, which takes
// forty-five minutes and a browser. This is the guard that runs in a second and fails in the pull
// request: walk the widget tree of every screen, and for every piece of text, check that there is
// a `PaperPiece` between it and the `Desk`.
//
// A mark that is not a word may still sit on the wood — a tally stroke, a rule, an arrow, the
// pencil-stub battery. A shape is recognised by its silhouette and a word by its counters. So this
// looks for `Text` and nothing else; `Mark` and `CustomPaint` are allowed on the plank by design.
//
// It scrolls, and that is not incidental. The first version of this pumped each region once and
// passed, and `05_settings.png` came back from the next capture with two whole sections written
// on the wood at about one to one — the four facts about the two phones, the export line, the
// authored feelings. The test viewport is 480 by 1040 logical pixels and `SettingsRegion` is a
// lazy `ListView`, so everything below the fold had never been built, and a guard that only sees
// the first screenful of a scrolling region is a guard over the first screenful. So each region
// is dragged to its end and checked the whole way down.
import 'package:desk/material/desk.dart';
import 'package:desk/material/library.dart';
import 'package:desk/material/paper.dart';
import 'package:desk/regions/chat/chat_region.dart';
import 'package:desk/regions/moments/moments_region.dart';
import 'package:desk/regions/pulse/pulse_region.dart';
import 'package:desk/regions/settings/settings_region.dart';
import 'package:desk/regions/us/us_region.dart';
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

/// Every `Text` in this screen that has a `Desk` above it and no `PaperPiece` in between, with
/// the words themselves, because a failure that only says "three of them" is a failure somebody
/// has to go and reproduce before they can fix it.
List<String> _wordsOnTheWood(WidgetTester tester) {
  final stranded = <String>[];
  for (final element in find.byType(Text).evaluate()) {
    final text = element.widget as Text;
    final word = text.data ?? text.textSpan?.toPlainText() ?? '';
    if (word.trim().isEmpty) continue;

    var onPaper = false;
    var overDesk = false;
    element.visitAncestorElements((ancestor) {
      final w = ancestor.widget;
      if (w is PaperPiece) {
        onPaper = true;
        return false; // paper first: whatever is above it no longer matters
      }
      if (w is Desk) {
        overDesk = true;
        return false;
      }
      return true;
    });
    if (overDesk && !onPaper) stranded.add(word);
  }
  return stranded;
}

void main() {
  late AppScope scope;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await MaterialLibrary.load();
  });
  setUp(() async => scope = await _aScope());
  tearDown(() => scope.dispose());

  final screens = <String, Widget Function()>{
    'the pulse': () => const PulseRegion(),
    'the thread': () => const ChatRegion(),
    'the two of them': () => const UsRegion(),
    'moments': () => const MomentsRegion(),
    'settings': () => const SettingsRegion(),
  };

  screens.forEach((name, build) {
    testWidgets('$name writes on paper', (tester) async {
      tester.view.physicalSize = const Size(1440, 3120);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(AppScope.provide(
        scope: scope,
        child: MaterialApp(home: Scaffold(body: Desk(child: build()))),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);

      // Down the whole region, a screenful at a time. A lazy list only builds what is near the
      // viewport, so what is never scrolled to is never checked.
      final stranded = <String>{...(_wordsOnTheWood(tester))};
      final scrollable = find.byType(Scrollable);
      if (scrollable.evaluate().isNotEmpty) {
        final state = tester.state<ScrollableState>(scrollable.first);
        for (var step = 0; step < 40; step++) {
          final before = state.position.pixels;
          await tester.drag(scrollable.first, const Offset(0, -700));
          await tester.pump();
          stranded.addAll(_wordsOnTheWood(tester));
          // At the bottom the drag stops moving it, and that is the end of the region.
          if (state.position.pixels <= before + 1) break;
        }
      }
      expect(stranded.toList(), isEmpty,
          reason: 'these words are written straight onto the desk, where no ink reaches 4.5:1 '
              'because the plank would need one at Y -0.006: ${stranded.join(' / ')}. '
              'Put a Strip (material/slip.dart) under them.');
    });
  });
}
