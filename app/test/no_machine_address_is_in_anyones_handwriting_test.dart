// 05_settings.png printed `connecting · http://127.0.0.1:8480` and a second bare
// `http://127.0.0.1:8480` in the handwriting face, on the THE TWO PHONES card — the one moment in
// the build where a raw debug address is treated as something a person wrote by hand, on the
// artifact whose deliverable is pairing state.
//
// An address is a fact the phone knows. It is set in the stamped face and it is behind a
// disclosure, because it is a thing you go and look at when something is wrong rather than a
// thing the screen is about. The second one was a `TextEditingController` opening with a
// development default in it; a field on this card holds what a person typed, and it opens empty.
//
// Re-break by putting the default back in the controller, or by taking `machine: true` off the
// address fact, and watching a `://` come back in a handwritten run.
import 'package:desk/capture/bus.dart';
import 'package:desk/capture/hooks.dart';
import 'package:desk/material/library.dart';
import 'package:desk/regions/settings/settings_region.dart';
import 'package:desk/scope.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/transport/local/local_transport.dart';
import 'package:desk/transport/sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Anything that reads as a machine address: a scheme, a bare host:port, or a dotted quad.
final RegExp _machineAddress = RegExp(r'://|\b\d{1,3}(\.\d{1,3}){3}\b|:\d{4,5}\b');

void main() {
  late AppScope scope;
  late Spine spine;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await MaterialLibrary.load();
    spine = await Spine.open(
        SpineStore.memory(), const Identity(person: Person.teo, device: DeviceKind.pwa));
    // A host, and started: that is what puts an address in the link status, which is the run
    // 05_settings.text.json declared in the handwriting face. A client that has never paired has
    // no address at all, and a test against one would be asserting nothing.
    final t = LocalTransport(
        role: TransportRole.host,
        spine: spine,
        deviceId: 'android-s',
        binding: LocalBinding(port: 0));
    await t.start();
    addTearDown(t.stop);
    scope = AppScope(
      spine: spine,
      transport: t,
      sync: SyncEngine(spine: spine, transport: t),
      clock: Clock(frozenAt: DateTime.utc(2026, 9, 3, 17, 33)),
    );
    addTearDown(() async {
      scope.dispose();
      await spine.close();
    });
  });

  Future<List<Map<String, dynamic>>> draw(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    CaptureBus.wanted = true;
    addTearDown(() => CaptureBus.wanted = false);
    await tester.pumpWidget(AppScope.provide(
      scope: scope,
      child: const MaterialApp(home: Scaffold(body: SettingsRegion())),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    return CaptureHooks.textRuns();
  }

  testWidgets('nothing on the settings screen writes a machine address by hand', (tester) async {
    for (final r in await draw(tester)) {
      final text = r['text'] as String;
      if (!_machineAddress.hasMatch(text)) continue;
      expect(r['role'], 'stamp',
          reason: 'the address "$text" is set in the ${r['role']} face, which is somebody\'s '
              'handwriting — it is a fact the phone knows, not one a person wrote');
    }
  });

  testWidgets('the address field opens empty, not holding a development default', (tester) async {
    await draw(tester);
    final fields = tester.widgetList<TextField>(find.byType(TextField));
    for (final f in fields) {
      expect(f.controller?.text ?? '', isEmpty,
          reason: 'a field on this card opens with "${f.controller?.text}" already in it, and '
              'whatever is in it is drawn as though a person had written it');
    }
  });

  testWidgets('the feeling-authoring tools are on the screen this artifact is of',
      (tester) async {
    final texts = [for (final r in await draw(tester)) r['text'] as String];
    expect(texts, contains('FEELINGS YOU MADE'),
        reason: 'the artifact whose deliverable includes the authoring tools does not reach them: '
            '$texts');
    expect(texts, contains('make one'));
  });
}
