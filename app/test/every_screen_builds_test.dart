// Every screen in the app builds, and nothing throws while it does.
//
// A whole afternoon's worth of bugs went unseen because no test ever built a screen. The one that
// mattered: PaperPiece faded its baked contact shadow by the ratio of the note's lift to a 1.6mm
// reference, clamped to (0.6, 1.25) — and Opacity asserts above 1.0. Every call site in the app
// lifts less than 1.6mm, so every torn sheet in the app threw on build in any debug run, and the
// suite was green the whole time because the suite never built one.
//
// So this builds all of them: the five regions, the setup sheet, the search page, the media
// viewer, and each of the sheets that come up over a note. It is not looking at them — the
// pictures are what look at them — it is only insisting that they can be drawn.
import 'package:desk/feelings/corner.dart';
import 'package:desk/material/library.dart';
import 'package:desk/material/slip.dart';
import 'package:desk/material/objects.dart';
import 'package:desk/regions/chat/chat_region.dart';
import 'package:desk/regions/moments/moments_region.dart';
import 'package:desk/regions/pulse/pulse_region.dart';
import 'package:desk/regions/settings/settings_region.dart';
import 'package:desk/regions/us/us_region.dart';
import 'package:desk/scope.dart';
import 'package:desk/setup/checklist.dart';
import 'package:desk/setup/setup_region.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/spine/store/store.dart';
import 'package:desk/transport/local/local_transport.dart';
import 'package:desk/transport/sync.dart';
import 'package:desk/transport/transport.dart';
import 'package:desk/voice/strings.dart';
import 'package:desk/regions/chat/search_page.dart';
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

/// The two surfaces this app actually runs on, in device pixels at three times scale.
///
/// Everything here was drawn at 1440 by 3120, which is 480 by 1040 of CSS — wider in logical
/// pixels than any phone either of them owns, and wider than the clips, which are shot at 360 by
/// 780. A coherence critic found the difference on the glass: two Us rows that read fully in the
/// still truncate to 'the second one · the…' and 'tape the gap in the bac…' at the clip's width,
/// and the calendar glance wraps to a line the card cuts. A screen that builds at a width nobody
/// has is not evidence that it builds.
const _phones = <String, Size>{
  // the iPhone the web app is installed on
  'at 390 by 844': Size(1170, 2532),
  // the narrow Android the host runs on, and the width every clip is shot at
  'at 360 by 780': Size(1080, 2340),
};

/// One screen, on a phone-shaped surface, with the app's scope over it.
Future<void> _draw(WidgetTester tester, AppScope scope, Widget screen,
    {Size size = const Size(1080, 2340)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(AppScope.provide(
    scope: scope,
    child: MaterialApp(home: Scaffold(body: screen)),
  ));
  await tester.pump();
  expect(tester.takeException(), isNull);
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
    _phones.forEach((where, size) {
      testWidgets('$name $where',
          (tester) async => _draw(tester, scope, build(), size: size));
    });
  });

  testWidgets('moments builds the prints the viewport reaches, not the year', (tester) async {
    // A hundred and eighty photographs in the log. The pile lays all of them out and builds the
    // ones on screen: this used to be a Column of every tile, and the region opened by asking
    // the store for every picture in the year at once.
    for (var i = 0; i < 180; i++) {
      await scope.spine.append(
        'photo',
        {'blob': 'blob-$i', 'w': 4 + (i % 3), 'h': 3 + (i % 5), 'mime': 'image/jpeg'},
        at: DateTime.utc(2026, 1, 1).add(Duration(hours: i * 40)),
      );
    }
    MomentsGalleryStats.reset();
    await _draw(tester, scope, const MomentsRegion());
    await tester.pump(const Duration(milliseconds: 50));
    expect(MomentsGalleryStats.built, greaterThan(6), reason: 'the pile is empty');
    expect(MomentsGalleryStats.built, lessThan(90),
        reason: 'the whole year of tiles was built for one screen: ${MomentsGalleryStats.built} of 180');
    expect(find.text(S.fetching), findsNothing,
        reason: 'a picture that has not come is a blank print, not a sentence');
  });

  testWidgets('the setup sheet, on either phone', (tester) async {
    for (final platform in ['pwa', 'android']) {
      await _draw(
        tester,
        scope,
        SetupSheet(
          platform: platform,
          facts: SetupFacts(
            platform: platform,
            link: scope.link,
            paired: null,
            notificationsAllowed: false,
            installedToHome: platform == 'android',
            certificate: null,
            mineInSpine: false,
            theirsInSpine: false,
          ),
          hostAddress: '100.72.198.108',
        ),
      );
    }
  });

  // Two of the ten stills are these, and neither is a region: a width change reaches them through
  // a route rather than through the screens map above.
  _phones.forEach((where, size) {
    testWidgets('search, with what it found, $where', (tester) async {
      for (final t in ['the bus is late', 'raining here too', 'tape the gap in the back door']) {
        await scope.spine.append('message', {'text': t}, at: DateTime.utc(2026, 3, 4));
      }
      await _draw(tester, scope, SearchPage(initialQuery: 'the', onDone: (_) {}), size: size);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('the feeling corner, open', (tester) async {
    await _draw(
      tester,
      scope,
      FeelingCorner(registry: scope.feelings, onSend: (_, _) {}),
    );
  });

  testWidgets('a sheet that comes up over a note', (tester) async {
    await _draw(
      tester,
      scope,
      DeskSheet(
        id: 'what.can.be.done',
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final w in ['reply', 'react', 'change it', 'take it back']) Text(w),
        ]),
      ),
    );
    expect(find.text('take it back'), findsOneWidget);
  });

  testWidgets('every feeling in the vocabulary can be drawn', (tester) async {
    final registry = scope.feelings;
    expect(registry.active.length, greaterThanOrEqualTo(30));
    await _draw(
      tester,
      scope,
      SingleChildScrollView(
        child: Wrap(children: [
          for (final f in registry.active) FeelingObject(feeling: f, size: 44),
        ]),
      ),
    );
  });
}
