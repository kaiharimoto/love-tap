// The PWA never hosts. This stub keeps the web build honest.
import 'dart:typed_data';

import '../../spine/spine.dart';
import '../transport.dart';
import 'http_transport.dart';

class HostServer {
  HostServer({
    required Spine spine,
    required String deviceId,
    required String transportName,
    required Pairing? Function() pairingFor,
    required Uint8List? Function() keyFor,
    required (PairingCode, Uint8List)? Function() openPairing,
    required Future<void> Function(Pairing, Uint8List) onPaired,
    required void Function(Ephemeral) onEphemeral,
    required void Function(int cursor) onPeerContact,
    String? pwaRoot,
  });

  Future<void> listen(HostBind bind) async => throw UnsupportedError('the PWA does not host');

  void queueForClient(Ephemeral frame) {}

  Future<void> close() async {}
}
