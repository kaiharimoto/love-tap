import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'ambient/ambient.dart';
import 'app.dart';
import 'capture/hooks.dart';
import 'flags.dart';
import 'scope.dart';
import 'material/library.dart';
import 'ready.dart';
import 'spine/seed_loader.dart';
import 'spine/store/open_store.dart';
import 'spine/spine.dart';
import 'transport/local/local_transport.dart';
import 'transport/tailscale/tailscale_transport.dart';
import 'transport/sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MaterialLibrary.load();
  final scope = await bootstrap();
  runApp(AppScope.provide(scope: scope, child: const DeskApp()));
  CaptureHooks.install(scope);
  // the capture harness waits for this rather than guessing at a delay
  WidgetsBinding.instance.addPostFrameCallback((_) {
    WidgetsBinding.instance.addPostFrameCallback((_) => markReady());
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
    await SeedLoader(rootBundle).load(spine);
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
  return AppScope(spine: spine, transport: transport, sync: sync, clock: clock, ambient: ambient);
}
