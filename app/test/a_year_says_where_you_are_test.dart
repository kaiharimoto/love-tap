// Scrolled back into the year, the thread says what day it is showing and how to get back.
//
// A messenger critic timed a hard fling at 1.2 to 3.1 per cent of an eight-thousand-row thread and
// wrote: no frame of the clip shows a scrollbar, a date rail, or a jump-to-latest control, and the
// only way back to now the evidence supports is leaving the tab and returning. Looking something
// up and then getting back to the newest message is a daily action, and the person was given
// neither a control nor any sense of where they were.
//
// Both marks are read from the list's own item positions, so this drives the list and reads the
// glass.
import 'package:desk/material/library.dart';
import 'package:desk/material/slip.dart';
import 'package:desk/regions/chat/chat_region.dart';
import 'package:desk/scope.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/transport/local/local_transport.dart';
import 'package:desk/transport/sync.dart';
import 'package:desk/voice/strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppScope scope;

  // One scope for the whole file, made once.
  //
  // Not a style choice: a second `AppScope` built inside a second `testWidgets` in the same file
  // never returns. Reduced to a scratch test that does nothing but build one, pump it, and do it
  // again — the first case passes in under a second and the second never reaches its first
  // statement. Every widget test in this build that needs a scope makes it in `setUpAll`, so
  // nothing had ever asked for two. It is a fault in how the app's boot is shaped against the
  // test binding rather than in what this file is testing, and it is written down here rather
  // than worked around silently.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await MaterialLibrary.load();
    final spine = await Spine.open(
      SpineStore.memory(),
      const Identity(person: Person.teo, device: DeviceKind.pwa),
    );
    final transport = LocalTransport(role: TransportRole.client, spine: spine, deviceId: 'test');
    scope = AppScope(
      spine: spine,
      transport: transport,
      sync: SyncEngine(spine: spine, transport: transport),
      clock: Clock(frozenAt: DateTime.utc(2026, 9, 3, 19, 40)),
    );
  });

  Future<void> show(WidgetTester tester,
      {DateTime? day, int rowsBehind = 0, bool atTheEnd = false, VoidCallback? onBack}) async {
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(AppScope.provide(
      scope: scope,
      child: MaterialApp(
        home: Scaffold(
          body: Stack(children: [
            whereWeAreForTest(
                day: day, rowsBehind: rowsBehind, atTheEnd: atTheEnd, onBack: onBack),
          ]),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  List<String> words(WidgetTester t) =>
      t.widgetList<Text>(find.byType(Text)).map((w) => w.data ?? '').toList();

  testWidgets('at the end it says nothing, because there is nowhere to go', (tester) async {
    await show(tester, atTheEnd: true);
    expect(words(tester), isEmpty,
        reason: 'the thread is on the newest note and still offered a way back to it');
  });

  testWidgets('scrolled back it says the day and the way out', (tester) async {
    await show(tester, day: DateTime.utc(2026, 6, 14, 9, 20), rowsBehind: 480);
    final on = words(tester);
    expect(on, contains(S.backToNow),
        reason: 'scrolled back into the year with no way back to now: ${on.join(" | ")}');
    expect(on, contains('14 june'),
        reason: 'the day at the top of the glass is not on it: ${on.join(" | ")}');
    expect(on, isNot(contains(S.today)));
    expect(on.any((w) => w.endsWith(S.weeksUp) || w.endsWith(S.monthsUp) || w.endsWith(S.daysUp)),
        isTrue, reason: 'the way back does not say how far back it is: ${on.join(" | ")}');
  });

  testWidgets('and it is a piece of paper, not a control', (tester) async {
    await show(tester, day: DateTime.utc(2026, 6, 14, 9, 20), rowsBehind: 480);
    // Two slips: the day at the top and the way back at the corner. Both torn, both on stock,
    // because everything in this app that carries words is paper.
    expect(find.byType(Slip), findsNWidgets(2));
    for (final s in tester.widgetList<Slip>(find.byType(Slip))) {
      expect(s.torn, isTrue, reason: '${s.id} is a cut rectangle');
      expect(s.stock, isNotNull, reason: '${s.id} has no stock under it');
    }
  });

  testWidgets('and tapping it is what takes the thread back', (tester) async {
    var asked = 0;
    await show(tester,
        day: DateTime.utc(2026, 6, 14, 9, 20), rowsBehind: 480, onBack: () => asked++);
    await tester.tap(find.text(S.backToNow));
    await tester.pump();
    expect(asked, 1, reason: 'the way back is not wired to anything');
  });

  test('how far up is said in the units a person uses', () {
    final now = DateTime.utc(2026, 9, 3, 19, 40);
    String far(DateTime d, [int rows = 100]) => whereWeAreHowFarBack(rows, d, now);
    expect(far(DateTime.utc(2026, 3, 1)), '6 ${S.monthsUp}');
    expect(far(DateTime.utc(2026, 8, 1)), '5 ${S.weeksUp}');
    expect(far(DateTime.utc(2026, 8, 29)), '5 ${S.daysUp}');
    expect(far(DateTime.utc(2026, 9, 3, 6, 0), 200), '200 ${S.rowsUp}');
    expect(far(DateTime.utc(2026, 9, 3, 6, 0), 4), S.aLittleUp);
  });

  test('and the day is said the way a person says it', () {
    final now = DateTime.utc(2026, 9, 3, 19, 40);
    expect(whereWeAreDayLine(DateTime.utc(2026, 9, 3, 8), now), S.today);
    expect(whereWeAreDayLine(DateTime.utc(2026, 9, 2, 8), now), S.yesterday);
    expect(whereWeAreDayLine(DateTime.utc(2026, 6, 14, 8), now), '14 june');
    expect(whereWeAreDayLine(DateTime.utc(2025, 6, 14, 8), now), '14 june 2025');
  });
}
