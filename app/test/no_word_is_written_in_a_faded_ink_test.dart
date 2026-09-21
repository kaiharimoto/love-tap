// docs/COLOR.md section 6: an ink carrying a word composites at alpha >= 0.80. Nothing enforced it.
//
// Every picker in the app encoded `unchosen` as alpha. 05_settings.png declared twenty-eight runs
// at `80464648` — the margin pencil at half strength — measuring 2.42 to 2.54:1 against a 4.5
// floor; 01_pulse.png declared nine at `99464648`, 2.70 to 3.51:1, and those nine are the mood
// picker, which is the emotional core of the app. Two thirds of each screen's interactive
// vocabulary was the faintest thing on it, and the words a person was choosing between were all
// harder to read than the one they had already chosen. It is the owner's first complaint — that
// the text was hard to read — in one rendering rule.
//
// A choice is not a brightness. `material/choice.dart` writes both words in full-strength ink and
// says which is chosen with the underline that was already there, a pencil tick, and the chosen
// one being in somebody's own pen rather than the margin's pencil.
//
// Re-break by putting `Pen.margin.withValues(alpha: 0.5)` back in any picker and watching the run
// come back under the floor.
import 'dart:convert';

import 'package:desk/capture/bus.dart';
import 'package:desk/capture/hooks.dart';
import 'package:desk/material/library.dart';
import 'package:desk/regions/chat/chat_region.dart';
import 'package:desk/regions/moments/moments_region.dart';
import 'package:desk/regions/pulse/pulse_region.dart';
import 'package:desk/regions/settings/settings_region.dart';
import 'package:desk/regions/us/us_region.dart';
import 'package:desk/scope.dart';
import 'package:desk/spine/seed_loader.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/transport/local/local_transport.dart';
import 'package:desk/transport/sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

/// docs/COLOR.md section 6. 0.80 of 255 is 204, which is `cc`.
const int kMinInkAlpha = 204;

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

  Future<List<Map<String, dynamic>>> draw(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    CaptureBus.wanted = true;
    addTearDown(() => CaptureBus.wanted = false);
    await tester.pumpWidget(AppScope.provide(
      scope: scope,
      child: MaterialApp(home: Scaffold(body: screen)),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // A RenderFlex overflow lands here, which is what catches a mark that made a row too wide.
    expect(tester.takeException(), isNull);
    return CaptureHooks.textRuns();
  }

  testWidgets('no region writes a word in an ink under 0.80 alpha', (tester) async {
    if (absent != null) return;
    for (final (name, screen) in <(String, Widget)>[
      ('pulse', const PulseRegion()),
      ('chat', const ChatRegion()),
      ('us', const UsRegion()),
      ('moments', const MomentsRegion()),
      ('settings', const SettingsRegion()),
    ]) {
      for (final r in await draw(tester, screen)) {
        final ink = r['ink'] as String;
        if (ink.isEmpty) continue;
        final alpha = int.parse(ink.substring(0, 2), radix: 16);
        expect(alpha, greaterThanOrEqualTo(kMinInkAlpha),
            reason: '$name writes "${r['text']}" in $ink — alpha $alpha of 255, against '
                "docs/COLOR.md section 6's floor of $kMinInkAlpha. A word that has been faded is "
                'a word somebody has to lean in to read.');
      }
    }
  });

  testWidgets('and no word is faded by the thing it is standing on either', (tester) async {
    // THE SAME RULE, ONE LAYER UP, AND THIS IS WHERE IT SURVIVED. The test above reads the ink a
    // run DECLARES. `Opacity` declares nothing: it composites the whole subtree, paper and word
    // together, and the run underneath goes on saying `ff3f3f41` while the glass shows 0.72 of it.
    //
    // The Moments filter tabs were exactly that — `Opacity(opacity: on ? 1.0 : 0.72)` around the
    // slip. All four chips declare the same full-strength ink in `04_moments.text.json`, and
    // `tools/check/legibility.py` reads the chosen one at 7.97:1 and two of the unchosen at 3.89:1
    // and 4.47:1 against a floor of 4.5, on ground that is not moving (ground_swing 1.21 and 1.14,
    // against the ~1.8 above which a reading is the instrument rather than the ink). Firing 31's
    // visual-design critic confirmed the same two at 300%. They were the one real legibility
    // failure left in the set, and the guard written for this exact defect could not see them.
    //
    // So the question is asked of the tree rather than of the run: nothing that carries a word may
    // be composited under docs/COLOR.md section 6's floor. `Pen.marginThinning` is 1.0 for the
    // same reason — the thread's timestamps were thinned to 0.78 and thirteen of them went under
    // the floor while `legible_on_what_it_is_on_test` read the ink at full strength and passed.
    if (absent != null) return;
    for (final (name, screen) in <(String, Widget)>[
      ('pulse', const PulseRegion()),
      ('chat', const ChatRegion()),
      ('us', const UsRegion()),
      ('moments', const MomentsRegion()),
      ('settings', const SettingsRegion()),
    ]) {
      await draw(tester, screen);
      for (final (kind, el, value) in _fades(tester)) {
        if (value >= kMinInkAlpha / 255) continue;
        // Zero is not a fade, it is an absence. `CaptureHooks._painted` says the same thing — a
        // subtree the framework does not put on the glass is not declared — so a word at 0 is not
        // a word anybody is being asked to read. It is also how the framework hides a TextField's
        // hint once there is something in the field, which is every field carrying a seeded line.
        if (value <= 0) continue;
        final word = _wordUnder(el);
        expect(word, isNull,
            reason: '$name puts "$word" inside a $kind at '
                '${value.toStringAsFixed(2)}, so it composites at '
                '${(value * 255).round()} of 255 against the floor of $kMinInkAlpha. The run will '
                'go on declaring its ink at full strength and the glass will show less, which is '
                'the shape of defect the test above was written for and cannot see.');
      }
    }
  });

  testWidgets('the mood picker says which one is chosen with a mark, not a brightness',
      (tester) async {
    if (absent != null) return;
    final runs = await draw(tester, const PulseRegion());
    final moods = ['bright', 'tender', 'restless', 'low', 'flat', 'open'];
    final drawn = [
      for (final r in runs)
        if (moods.contains(r['text'])) r,
    ];
    expect(drawn, isNotEmpty, reason: 'the mood picker is not on the pulse at all');
    final inks = {for (final r in drawn) r['ink'] as String};
    for (final ink in inks) {
      expect(ink.substring(0, 2), 'ff',
          reason: 'a mood is written in $ink, and the six a person is choosing between have to be '
              'as readable as the one already chosen');
    }
  });
}

/// Every fade currently in the tree, with what it is set to.
///
/// The three the framework offers: `Opacity`, `AnimatedOpacity` (whose current value is on its
/// state, so the settled frame is what is read), and `FadeTransition`.
List<(String, Element, double)> _fades(WidgetTester tester) {
  final out = <(String, Element, double)>[];
  void take(Finder f, String kind, double Function(Widget) value) {
    for (final el in tester.elementList(f)) {
      out.add((kind, el, value(el.widget)));
    }
  }
  take(find.byType(Opacity), 'Opacity', (w) => (w as Opacity).opacity);
  take(find.byType(AnimatedOpacity), 'AnimatedOpacity', (w) => (w as AnimatedOpacity).opacity);
  take(find.byType(FadeTransition), 'FadeTransition',
      (w) => (w as FadeTransition).opacity.value);
  return out;
}

/// The first word under [root], or null if it carries none.
///
/// A fade over a drawn object is not this defect: `settings_region` dims a retired feeling's
/// object and `authoring` dims the objects in the drawer, and neither is a word somebody is being
/// asked to read. Only a `Text` with something in it counts.
String? _wordUnder(Element root) {
  String? found;
  void down(Element e) {
    if (found != null) return;
    final w = e.widget;
    if (w is Text && (w.data ?? '').trim().isNotEmpty) {
      found = w.data;
      return;
    }
    if (w is RichText) {
      final t = w.text.toPlainText().trim();
      if (t.isNotEmpty) {
        found = t;
        return;
      }
    }
    e.visitChildren(down);
  }
  root.visitChildren(down);
  return found;
}
