// The development transport: the same protocol on the loopback, with injectable faults. It names
// itself "local" in every report and is never used in the final proof. On the emulator the host
// listens on 127.0.0.1 and `adb forward` exposes it to the WebKit client in the container.
import 'package:http/http.dart' as http;

import '../../spine/spine.dart';
import '../faults.dart';
import '../protocol/http_transport.dart';
import '../transport.dart';

export '../transport.dart';

class LocalBinding implements Binding {
  LocalBinding({this.port = 8480, this.host = '127.0.0.1', ScriptedFaults? faults})
      : faults = faults ?? ScriptedFaults();

  final int port;
  final String host;

  @override
  final ScriptedFaults faults;

  @override
  String get name => 'local';

  @override
  Future<HostBind> hostBind() async => HostBind(address: host, port: port);

  @override
  Future<Uri> clientBase(String? storedAddress) async =>
      Uri.parse(storedAddress ?? 'http://$host:$port');

  @override
  http.Client makeClient() => http.Client();
}

class LocalTransport extends HttpTransport {
  LocalTransport({
    required super.role,
    required super.spine,
    required super.deviceId,
    LocalBinding? binding,
    super.pwaRoot,
  }) : super(binding: binding ?? LocalBinding());

  ScriptedFaults get scriptedFaults => (binding as LocalBinding).faults;
}

/// A profile-scoped device id, minted once and kept in the spine's meta.
Future<String> deviceIdFor(Spine spine) async {
  final existing = await spine.meta('transport.device_id');
  if (existing != null) return existing;
  final id = '${spine.identity.device.name}-${DateTime.now().toUtc().millisecondsSinceEpoch.toRadixString(36)}';
  await spine.setMeta('transport.device_id', id);
  return id;
}
