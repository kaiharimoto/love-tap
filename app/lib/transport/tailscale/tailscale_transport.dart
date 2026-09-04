// The transport the app is for: the two phones, over Tailscale, and nothing in between.
//
// It is the same wire protocol as the local transport — the same pairing, the same cursor sync,
// the same outbox — bound to this device's tailnet address instead of to loopback. That is the
// whole difference, and it is deliberately the whole difference: the protocol was written once
// and tested against faults under `local`, and moving it onto the tailnet must not be a chance to
// write a second one.
//
// What this file adds is a refusal. The host binds its tailnet address or it does not start:
//
//   · a declared address that is not in 100.64.0.0/10 or fd7a:115c:a1e0::/48 is refused;
//   · with nothing declared, the interfaces are enumerated and a tailnet address is taken from
//     them, and if there is none the transport reports why rather than falling back;
//   · there is no path here that reaches 0.0.0.0, and the test asserts it.
//
// The client reaches the host at the address the pairing recorded. Pairing itself is unchanged:
// six spoken words, HKDF to a key, every request signed. Being on the same tailnet is not
// authentication — it is only the reason nobody else can see the traffic.
import 'package:http/http.dart' as http;

import '../faults.dart';
import '../protocol/http_transport.dart';
import '../transport.dart';
import '../../spine/spine.dart';
import 'proxy_client.dart';
import 'tailnet.dart';

class TailscaleBinding implements Binding {
  TailscaleBinding({
    this.port = 8443,
    this.declaredAddress = '',
    this.peerAddress = '',
    this.userspaceProxy = '',
    ScriptedFaults? faults,
  }) : faults = faults ?? ScriptedFaults();

  /// The port both phones agree on. Nothing else on the tailnet is listening on it.
  final int port;

  /// This phone's own tailnet address, if the setup list was told it. Checked, not trusted.
  final String declaredAddress;

  /// The other phone's tailnet address, learned during pairing.
  final String peerAddress;

  /// Set only for a node whose tailscaled has no TUN device — the two development nodes, which
  /// cannot have one inside a container.
  ///
  /// On a phone the tailnet address is a real address on a real interface, so the host binds it
  /// and that is the whole safety property. A userspace tailscaled has no interface, so there is
  /// no such address to bind: it accepts the inbound connection itself and hands it to loopback
  /// on the same port. The listener is then on 127.0.0.1, which is *narrower* than the tailnet
  /// address rather than wider — nothing but tailscaled can reach it — and outbound requests go
  /// through tailscaled's own proxy, which is what this holds. `host:port`, and empty on a phone.
  final String userspaceProxy;

  bool get isUserspace => userspaceProxy.isNotEmpty;

  @override
  final ScriptedFaults faults;

  @override
  String get name => 'tailscale';

  /// The address this transport actually bound, once it has. Reported in TransportStatus and in
  /// evidence/reliability.json, so the claim can be checked rather than believed.
  String? boundTo;

  /// The tailnet address this host answers on, whichever address the socket is bound to.
  String? reachableAt;

  @override
  Future<HostBind> hostBind() async {
    // Checked first and in both modes: a node that is not on the tailnet does not serve, and a
    // declared address that is not a tailnet address is refused whether there is a TUN or not.
    final address = await addressToServeOn(declared: declaredAddress);
    reachableAt = address;
    boundTo = isUserspace ? '127.0.0.1' : address;
    return HostBind(address: boundTo!, port: port);
  }

  @override
  Future<Uri> clientBase(String? storedAddress) async {
    final target = (storedAddress != null && storedAddress.isNotEmpty)
        ? storedAddress
        : peerAddress;
    if (target.isEmpty) {
      throw const NotOnTheTailnet(
          'the other phone has not been paired yet, so there is no address to reach it at');
    }
    final uri = target.startsWith('http') ? Uri.parse(target) : Uri.parse(_url(target));
    final host = uri.host;
    if (!isTailnetAddress(host)) {
      throw NotOnTheTailnet('$host is not a tailnet address; this only talks over the tailnet');
    }
    return uri;
  }

  String _url(String address) =>
      address.contains(':') ? 'http://[$address]:$port' : 'http://$address:$port';

  @override
  http.Client makeClient() => tailnetClient(proxy: userspaceProxy);
}

/// The transport the two phones use. Nothing here but the binding: the protocol is the one in
/// transport/protocol/, which is the point.
Transport tailscaleTransport({
  required TransportRole role,
  required Spine spine,
  required String deviceId,
  int port = 8443,
  String declaredAddress = '',
  String peerAddress = '',
  String userspaceProxy = '',
}) =>
    HttpTransport(
      role: role,
      spine: spine,
      deviceId: deviceId,
      binding: TailscaleBinding(
        port: port,
        declaredAddress: declaredAddress,
        peerAddress: peerAddress,
        userspaceProxy: userspaceProxy,
      ),
    );
