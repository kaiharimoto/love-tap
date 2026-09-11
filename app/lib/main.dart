import 'dart:convert';
import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import 'ambient/ambient.dart';
import 'app.dart';
import 'capture/hooks.dart';
import 'flags.dart';
import 'regions/settings/notifications.dart';
import 'scope.dart';
import 'material/desk.dart';
import 'material/ink.dart';
import 'material/library.dart';
import 'boot.dart';
import 'ready.dart';
import 'spine/seed_bundle.dart';
import 'spine/seed_loader.dart';
import 'spine/store/open_store.dart';
import 'spine/spine.dart';
import 'transport/local/local_transport.dart';
import 'transport/tailscale/tailscale_transport.dart';
import 'transport/sync.dart';

/// How long each part of the first launch took, in milliseconds.
///
/// A messenger critic read the first launch at 8.9 to 10.0 seconds across the set and could say
/// nothing about what it was made of, because neither could the record: `load: {ms: 8827}` and no
/// parts. Nine seconds might be the bundle arriving over the wire, the year being parsed, the year
/// being written into IndexedDB, or the first frame — and those have four different fixes. Timed
/// here rather than guessed at from the outside.
final Map<String, int> bootPhases = {};

Future<void> main() async {
  final began = DateTime.now();
  var mark = began;
  void took(String what) {
    final now = DateTime.now();
    bootPhases[what] = now.difference(mark).inMilliseconds;
    mark = now;
  }

  WidgetsFlutterBinding.ensureInitialized();
  // The stocks are not in here any more — see StockCache in material/paper.dart. They were, and
  // the eleventh capture measured what that cost: over an 844-frame fling, 199 frames built
  // exactly sixty paper pieces in 571 to 1150 ms each and 645 frames built none in about two,
  // with this cache pinned at 398 MB of its 402 MB ceiling. What is left in here is the baked
  // shadows, the objects, the fold frames and the photographs, and this number is due to come down
  // once a capture has said what that actually needs. It is kept where it was for now so that one
  // change is measured at a time.
  //
  // The paper had to stay in memory, because a stock that has been evicted paints as a flat fill.
  //
  // Flutter's image cache holds 100 MB by default. The packed stocks decode to **763 MB** across
  // 54 files — an A5 sheet at 1574x2200 is 13.8 MB and the receipt at 1601x3420 is 21.9 — because
  // a piece now takes a window of its stock at the stock's own density and the stocks were
  // re-rendered big enough for that. So the cache thrashes: a piece whose stock has just been
  // evicted draws its real torn mask over `Paper.forStock`, which is a flat colour, and that is
  // exactly what 04_moments' voice-note tile is — 233.3 grey levels at a standard deviation of
  // 0.000 over four 40-pixel cells, inside a tile whose fringe is plainly drawn, while the receipt
  // stock's own windows measure 0.82 to 1.45.
  //
  // This is a floor under the fault rather than the fix for it. The fix is not to decode a
  // 1574x2200 sheet to draw a 450x195 window of it: a stock wants packing as a patch at its own
  // density and tiling, the way the ink plates already are, which is 56 MB for the whole library
  // instead of 763. Until then the cache is told to hold the working set, and this number is a
  // thing to be embarrassed about on a phone.
  PaintingBinding.instance.imageCache.maximumSizeBytes = 384 << 20;
  took('the framework');
  await MaterialLibrary.load();
  took('the library index');
  await InkPlates.load();
  took('the ink plates');
  await warmDeskSurface();
  took('the desk');
  final scope = await bootstrap();
  took('the log');
  if (Flags.capture) {
    // Under capture an uncaught error has to be legible in the scene log: the harness records
    // the browser's console, and a Dart exception that reaches the page as a bare object reads
    // there as `pageerror: object` and nothing else. Both channels are written out in words.
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('flutter error: ${details.exceptionAsString()}\n${details.stack}');
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('uncaught: $error\n$stack');
      return true;
    };
  }
  runApp(AppScope.provide(scope: scope, child: const DeskApp()));
  CaptureHooks.install(scope);
  // the capture harness waits for this rather than guessing at a delay
  WidgetsBinding.instance.addPostFrameCallback((_) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      took('the first frame');
      bootPhases['everything'] = DateTime.now().difference(began).inMilliseconds;
      // The desk the *page* put out goes now, on the frame that replaces it, rather than on a
      // timer that would either flash or overstay.
      bootDone();
      markReady();
    });
  });
}

/// Wires the one object graph from the build flags and the platform. The transport is chosen
/// here, outside app/lib/transport/, so adding the Tailscale transport touches only its own
/// directory plus this switch.
Future<AppScope> bootstrap() async {
  final role = Flags.role.isNotEmpty
      ? TransportRole.values.byName(Flags.role)
      : (kIsWeb ? TransportRole.client : TransportRole.host);
  final person = Flags.person.isNotEmpty
      ? Person.parse(Flags.person)
      : (role == TransportRole.host ? Person.noor : Person.teo);
  final device = kIsWeb ? DeviceKind.pwa : DeviceKind.android;
  final identity = Identity(person: person, device: device);

  final store = await openStore(Flags.profile);
  final spine = await Spine.open(store, identity);

  if (Flags.seeded) {
    await SeedLoader(BundleSeedSource(rootBundle)).load(spine);
  }

  final clock = Clock(frozenAt: Flags.frozenNow.isEmpty ? null : DateTime.parse(Flags.frozenNow));
  final deviceId = await deviceIdFor(spine);

  final Transport transport;
  switch (Flags.transport) {
    case 'local':
      transport = LocalTransport(role: role, spine: spine, deviceId: deviceId, binding: LocalBinding(port: Flags.port));
    case 'tailscale':
      transport = tailscaleTransport(
        role: role,
        spine: spine,
        deviceId: deviceId,
        port: Flags.port == 8480 ? 8443 : Flags.port,
        declaredAddress: Flags.tailnetAddress,
        peerAddress: Flags.peerAddress,
        // The key and certificate live in the app's own storage, which the Android manifest
        // excludes from the cloud backup and from the phone-to-phone transfer. They are made once,
        // on the phone, for the address it is actually serving on.
        certificateDir: () async =>
            Directory('${(await getApplicationSupportDirectory()).path}/tls'),
      );
    default:
      throw UnsupportedError('transport ${Flags.transport} is not built yet');
  }
  // The wire being down is never a reason for a blank screen: the messenger reads its own spine
  // and keeps writing into it, and the sync engine retries in the background.
  try {
    await transport.start();
  } catch (e, st) {
    debugPrint('transport did not start: $e\n$st');
  }
  final sync = SyncEngine(spine: spine, transport: transport);
  await sync.start();
  final ambient = Ambient.of();
  await ambient.start();
  // What a phone in a pocket says for each kind of arrival, written where the service worker can
  // read it. The worker runs when the app does not and cannot import the registry, so it used to
  // keep a table of its own and the two drifted. There is one list, and this is how it gets there.
  await spine.setMeta('push.words', jsonEncode({
    for (final t in kEventTypes)
      if (t.pushed != null) t.id: t.pushed,
  }));
  // And what each kind is allowed to do about it. The registry declares a treatment per type and
  // Settings lets a person change any of them, but nothing wrote the answer down until they did:
  // `notify.prefs` was absent on a phone nobody had been into Settings on, and the worker reads an
  // absent preference as `interrupt` — so a type the registry says never announces itself would
  // have announced itself, and the quiet hours were not in force either. The defaults are the
  // registry's own treatments, written once, and a person's changes overwrite them.
  if (await spine.meta('notify.prefs') == null) {
    await NotificationPrefs.defaults().save(spine);
  }
  return AppScope(spine: spine, transport: transport, sync: sync, clock: clock, ambient: ambient);
}
