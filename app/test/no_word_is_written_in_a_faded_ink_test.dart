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
