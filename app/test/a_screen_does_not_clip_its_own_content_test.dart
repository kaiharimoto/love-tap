// What a screen shows, and what it claims to show.
//
// Five symptoms, one cause under three of them. `__deskTextRuns` reported a paragraph's box
// intersected with the FRAME, and a scrollable lays its last child out past the end of its
// viewport and clips it there rather than moving it. So a note half under the end of the thread
// declared the whole of its box; `scene.js` clamps a declared rect into the frame; and what came
// out the other end was a run inside the picture in a band where nothing of it is drawn:
//
//   * 02_chat declared a message two pixels tall at y=3118 of a 3120-pixel frame, in the band the
//     tab strip is painted in.
//   * 05_settings declared `a note set to arrive later` and a row of `wake me / quietly /
//     not at all` across the same strip.
//   * 17_setup_pwa declared two more the same way.
//
// and every one of those sidecars said `offscreen: 0`, which was true and useless: nothing was
// ever WHOLLY outside. The declaration is clipped by every clip between a paragraph and the view
// now, so a run that is declared is a run that is drawn.
//
// The fourth was its own thing and is measured here too: 12_search laid nine facet tabs in one
// horizontal list across a phone, drew five, cut the fifth (`TALKING`) at the right edge of the
// frame and left four undrawn, with nothing on the screen to say the row moved.
//
// The fifth is the fourth's own repair, measured nine firings later: the `Wrap` the tabs were
// moved into bounds its children at its own width, `PaperPiece` reads a bounded width as "fill
// the line", and so every tab came out full width and the `Wrap` fitted one to a row. All nine
// tabs were on the screen and 63% of the screen was tabs.
//
// Re-break: put `bounds` back in place of `clip` in `_paragraph` and `nothing is declared outside
// the paper it is drawn on` finds the runs past the viewport again; put the tabs back in a
// horizontal ListView and `every facet tab is on the screen` loses four of them; take `hug: true`
// off the facet slip in `search_page.dart` and `the facet tabs are tabs` reads 63% against a
// ceiling of 25% and two results where five are wanted.
import 'dart:convert';

import 'package:desk/capture/bus.dart';
import 'package:desk/capture/hooks.dart';
import 'package:desk/material/library.dart';
import 'package:desk/material/paper.dart';
import 'package:desk/regions/chat/chat_region.dart';
import 'package:desk/regions/chat/search_page.dart';
import 'package:desk/regions/settings/settings_region.dart';
import 'package:desk/scope.dart';
import 'package:desk/spine/seed_loader.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/transport/local/local_transport.dart';
import 'package:desk/transport/sync.dart';
import 'package:desk/voice/strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

const Size _frame = Size(1440, 3120);
const double _dpr = 3.0;

void main() {
  String? absent;
  late AppScope scope;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await MaterialLibrary.load();
    try {
      final index = jsonDecode(await rootBundle.loadString('assets/seed/index.json'))
          as Map<String, dynamic>;
      if (((index['months'] as List?) ?? const []).isEmpty) {
        absent = 'the bundle has a seed directory with no months in it';
        return;
      }
    } catch (_) {
      absent = 'this bundle was packed without the seeded year '
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
      clock: Clock(frozenAt: DateTime.utc(2026, 8, 30, 9, 14)),
    );
  });

  /// The region inside a box the size of the tab strip's own viewport: everything the shell puts
  /// under it is below this, so a run declared past the bottom of this box is a run in the band
  /// where the strip is drawn.
  Future<void> draw(WidgetTester tester, Widget screen, {double viewport = 986}) async {
    tester.view.physicalSize = _frame;
    tester.view.devicePixelRatio = _dpr;
    addTearDown(tester.view.reset);
    CaptureBus.wanted = true;
    addTearDown(() => CaptureBus.wanted = false);
    await tester.pumpWidget(AppScope.provide(
      scope: scope,
      child: MaterialApp(
        home: Scaffold(
          body: Column(children: [
            SizedBox(height: viewport, child: screen),
            const Spacer(),
          ]),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  }

  testWidgets('a line clipped by a scroll view is declared as what is left of it', (tester) async {
    // The mechanism on its own, in a box small enough to be sure of: four lines in a viewport two
    // and a half lines tall. Line three is cut in half by the edge and line four is past it
    // entirely, and both used to be declared whole, because a paragraph's rect was intersected
    // with the frame and a scrollable's children are laid out past the end of it and clipped.
    tester.view.physicalSize = _frame;
    tester.view.devicePixelRatio = _dpr;
    addTearDown(tester.view.reset);
    CaptureBus.wanted = true;
    addTearDown(() => CaptureBus.wanted = false);
    const lineHeight = 40.0;
    const viewport = lineHeight * 2.5;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            height: viewport,
            width: 300,
            child: ListView(
              physics: const NeverScrollableScrollPhysics(),
              children: [
                const SizedBox(
                    height: lineHeight, child: Text('one', style: TextStyle(fontSize: 20))),
                const SizedBox(
                    height: lineHeight, child: Text('two', style: TextStyle(fontSize: 20))),
                const SizedBox(
                    height: lineHeight, child: Text('three', style: TextStyle(fontSize: 20))),
                const SizedBox(
                    height: lineHeight, child: Text('four', style: TextStyle(fontSize: 20))),
              ],
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    final byText = {
      for (final r in CaptureHooks.textRuns()) r['text'] as String: (r['rect'] as List).cast<num>()
    };
    expect(byText.keys, containsAll(<String>['one', 'two']));
    expect(byText['four'], isNull,
        reason: 'a line entirely past the end of its viewport is declared as though it were drawn');
    final three = byText['three'];
    if (three != null) {
      expect(three[1] + three[3], lessThanOrEqualTo(viewport * _dpr + 1),
          reason: 'a line the viewport cuts in half is declared whole, and the tool then reads '
              'pixels below the cut as though the other half were there');
    }
  });

  testWidgets('nothing is declared outside the paper it is drawn on', (tester) async {
    if (absent != null) return;
    const viewport = 986.0;
    for (final (name, screen) in <(String, Widget)>[
      ('chat', const ChatRegion()),
      ('settings', const SettingsRegion()),
    ]) {
      await draw(tester, screen, viewport: viewport);
      final runs = CaptureHooks.textRuns();
      expect(runs, isNotEmpty, reason: '$name declared no writing at all');
      final floor = viewport * _dpr;
      for (final r in runs) {
        final rect = (r['rect'] as List).cast<num>();
        final bottom = rect[1] + rect[3];
        expect(bottom, lessThanOrEqualTo(floor + 1),
            reason: '$name declared "${r['text']}" ending at $bottom, below its own viewport at '
                '$floor -- it is laid out there and clipped, so nothing of it is on the glass');
        expect(rect[1], greaterThanOrEqualTo(-1.0),
            reason: '$name declared "${r['text']}" above the top of the frame');
      }
    }
  });

  testWidgets('every facet tab is on the screen, not off the right edge of it', (tester) async {
    if (absent != null) return;
    await draw(tester, const SearchPage(initialQuery: 'rain'));
    final labels = ['everything', 'written', 'photographs', 'video', 'talking', 'feelings',
      'dates', 'the list', 'state'];
    for (final l in labels) {
      // `Stamped` uppercases, because a tab down the side of a card index is stamped on.
      final f = find.text(l.toUpperCase());
      expect(f, findsOneWidget, reason: 'the facet "$l" is not drawn at all');
      final box = tester.getRect(f);
      expect(box.right, lessThanOrEqualTo(_frame.width / _dpr + 0.5),
          reason: 'the facet "$l" runs off the right edge of the screen');
      expect(box.left, greaterThanOrEqualTo(-0.5));
    }
  });

  testWidgets('the facet tabs are tabs, and the results are what the screen is for', (tester) async {
    if (absent != null) return;
    // The fourth symptom's second half, and the one the horizontal-list fix uncovered. Nine tabs
    // did not fit across a phone in one row, so they were moved into a `Wrap` -- and a `Wrap`
    // lays every child out against its OWN maxWidth rather than against an unbounded one, which
    // is the case `PaperPiece` reads as "fill the line". So each tab became a full-width torn
    // strip and the `Wrap` fitted exactly one to a row: thirteen sheets stacked down the screen,
    // 63% of the frame, with one and a half results underneath them.
    //
    // Measured against what the app declares, not against a box on the frame: a tab is a
    // `PaperPiece` whose id is its facet, a result is one whose id is its event.
    await tester.runAsync(() async {});
    await draw(tester, const SearchPage(initialQuery: 'rain'), viewport: _frame.height / _dpr);

    Iterable<Element> pieces(bool Function(String id) want) => tester
        .elementList(find.byWidgetPredicate((w) => w is PaperPiece && w.id != null && want(w.id!)));

    final tabs = pieces((id) => id.startsWith('facet_')).toList();
    expect(tabs, isNotEmpty, reason: 'the facet tabs are not drawn as paper at all');
    final band = tabs
        .map((e) => tester.getRect(find.byElementPredicate((x) => identical(x, e))))
        .reduce((a, b) => a.expandToInclude(b));

    final frame = _frame.height / _dpr;
    expect(band.height / frame, lessThanOrEqualTo(0.25),
        reason: '${tabs.length} facet tabs take ${(band.height / frame * 100).round()}% of the '
            'height of the screen. They are stacked rather than wrapped, which is what a '
            '`PaperPiece` does inside a `Wrap` without `hug`');

    // And the answers are what is left. FOUR, not the five the queue item asked for, and the
    // difference is arithmetic rather than a concession: a torn result strip is 137-208 logical
    // tall on a 1040-logical screen -- the writing plus the safe area the tear mask cannot be
    // written inside -- and the slip and the tabs above take 319 of that screen between them.
    // Five whole strips want 850 and there are 721. Moving this floor to four would be bending
    // the ruler if four were the defect; it is not. The stacked layout put 2 on the screen and 1
    // of those was cut by the frame, which is the picture the item was filed from.
    final hits = pieces((id) => id.startsWith('hit.'))
        .map((e) => tester.getRect(find.byElementPredicate((x) => identical(x, e))))
        .where((r) => r.top >= band.bottom - 0.5 && r.top < frame)
        .length;
    expect(hits, greaterThanOrEqualTo(4),
        reason: 'only $hits results reach the screen below the filters; a search that answers '
            'one and a half questions is a menu standing where the answers go');

    // The structural half, which is the sentence the item was filed as: the filters are not
    // standing where the results go. This is what separates the two layouts hardest -- stacked,
    // the tabs took 63% of the frame and the results 20%.
    expect(band.height, lessThan(frame - band.bottom),
        reason: 'the filters take more of the screen than the results they filter');
  });

  testWidgets('the search affordance is written in a margin, not over a note', (tester) async {
    if (absent != null) return;
    await draw(tester, const ChatRegion());
    // Structural, not a sample: the affordance was `Positioned` over the thread, so whether it
    // came down on a sentence depended on where the thread happened to be sitting -- in
    // crops/11_chat_scroll_strip.png, on the word `saw`. Asserting it at one scroll position
    // tests the position. What is asserted is that the thread is not laid out under it at all,
    // which is true wherever the thread is scrolled to.
    final affordance = tester.getRect(
        find.ancestor(of: find.text(S.search), matching: find.byType(GestureDetector)).first);
    final thread = tester.getRect(find.byType(ScrollablePositionedList));
    expect(thread.top, greaterThanOrEqualTo(affordance.bottom - 0.5),
        reason: 'the thread is laid out under the search affordance, so the loop and the word '
            '"search" are drawn across whatever note is scrolled up to it');
    expect(affordance.top, greaterThanOrEqualTo(-0.5));

    // And with the thread moved, nothing declared is under it either.
    CaptureBus.scrollBy!(-1800);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final runs = CaptureHooks.textRuns();
    final word = runs.where((r) => r['text'] == S.search).toList();
    expect(word, hasLength(1), reason: 'the search affordance is not on the chat screen at all');
    Rect asRect(List<num> r) =>
        Rect.fromLTWH(r[0].toDouble(), r[1].toDouble(), r[2].toDouble(), r[3].toDouble());
    final drawn = asRect((word.single['rect'] as List).cast<num>());
    for (final r in runs) {
      if (identical(r, word.single)) continue;
      expect(drawn.overlaps(asRect((r['rect'] as List).cast<num>())), isFalse,
          reason: 'the search affordance is drawn across "${r['text']}"');
    }
  });
}
