import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'app.dart';
import 'flags.dart';
import 'scope.dart';
import 'spine/seed_loader.dart';
import 'spine/spine.dart';
import 'transport/local/local_transport.dart';
import 'transport/sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final scope = await bootstrap();
  runApp(AppScope.provide(scope: scope, child: const DeskApp()));
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

  final store = await SpineStore.open(Flags.profile);
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
    default:
      throw UnsupportedError('transport ${Flags.transport} is not built yet');
  }
  await transport.start();
  final sync = SyncEngine(spine: spine, transport: transport);
  await sync.start();
  return AppScope(spine: spine, transport: transport, sync: sync, clock: clock);
}
