// Nothing in the app is drawn by Flutter's own error style.
//
// A Text with no Material ancestor anywhere above it is not an error you get told about: Flutter
// draws it in red under a double yellow underline and carries on, in release builds too. Both
// routes the app pushes over the desk — search and the photograph viewer — were built with
// PageRouteBuilder and no Scaffold, so every word on them came out underlined twice in #FFFF00.
// It reads as a highlighter, which is why it survived a whole capture: sixty-three thousand pure
// yellow pixels in 12_search and twelve thousand in 14_media_viewer, and both looked deliberate.
//
// This builds each route the way Navigator builds it — with nothing above it — and reads the
// style the framework resolved for the text inside.
import 'package:desk/material/library.dart';
import 'package:desk/regions/chat/chat_region.dart';
import 'package:desk/regions/chat/search_page.dart';
import 'package:desk/regions/chat/viewer_page.dart';
import 'package:desk/scope.dart';
import 'package:desk/spine/projections/thread.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/spine/store/store.dart';
import 'package:desk/transport/local/local_transport.dart';
import 'package:desk/transport/sync.dart';
import 'package:desk/transport/transport.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// What Flutter paints text with when it cannot find a Material: red, double-underlined in yellow.
const _yellow = Color(0xFFFFFF00);

Future<AppScope> _scope() async {
  final spine = await Spine.open(
    SpineStore.memory(),
    const Identity(person: Person.teo, device: DeviceKind.pwa),
  );
  await spine.append('message', {'text': 'the canal has gone all dimples'});
  final transport = LocalTransport(role: TransportRole.client, spine: spine, deviceId: 'test');
  return AppScope(
    spine: spine,
    transport: transport,
    sync: SyncEngine(spine: spine, transport: transport),
    clock: Clock(frozenAt: DateTime.utc(2026, 9, 3, 19, 40)),
  );
}

/// Every Text in the tree, and the decoration the framework actually resolved for it.
List<String> _underlinedInYellow(WidgetTester tester) {
  final bad = <String>[];
  for (final element in find.byType(Text).evaluate()) {
    final text = element.widget as Text;
    final inherited = DefaultTextStyle.of(element).style;
    final style = text.style == null ? inherited : inherited.merge(text.style);
    final yellow = style.decorationColor == _yellow ||
        (style.decoration == TextDecoration.underline &&
            style.decorationStyle == TextDecorationStyle.double);
    if (yellow) bad.add(text.data ?? '<rich>');
  }
  return bad;
}

void main() {
  late AppScope scope;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await MaterialLibrary.load();
  });
  setUp(() async => scope = await _scope());
  tearDown(() => scope.dispose());

  Future<void> pushAndRead(WidgetTester tester, Future<void> Function(BuildContext) open) async {
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    late BuildContext ctx;
    await tester.pumpWidget(AppScope.provide(
      scope: scope,
      child: MaterialApp(
        home: Builder(builder: (c) {
          ctx = c;
          return const Scaffold(body: ChatRegion());
        }),
      ),
    ));
    await tester.pump();
    unawaited(open(ctx));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(_underlinedInYellow(tester), isEmpty,
        reason: 'these are being drawn by the framework as an error, not by the app');
  }

  testWidgets('the search page is not drawn by the error style', (tester) async {
    await pushAndRead(tester, (c) => SearchPage.open(c, query: 'canal'));
  });

  testWidgets('the photograph viewer is not drawn by the error style', (tester) async {
    final item = projectThread(scope.spine.all, me: Person.teo).items.first;
    await pushAndRead(tester, (c) => ViewerPage.open(c, item));
  });
}

void unawaited(Future<void> f) {}
