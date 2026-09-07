// Where a tailnet crossing actually went, as opposed to what its shape suggests.
//
// The record used to say `"path": "direct to 192.0.2.2:52340"`, which reads as a peer-to-peer
// crossing between two machines. That endpoint is this container's own eth0 address: the two
// "phones" are one host and the WireGuard session never left it. The tunnel is real, the peers
// are real, and the underlay is a loopback — all three of those belong in the record.
import 'dart:io';

/// Every IPv4 address this machine holds, loopback included.
Future<Set<String>> thisHostV4() async {
  final ifs = await NetworkInterface.list(
      type: InternetAddressType.IPv4, includeLoopback: true);
  return {for (final i in ifs) for (final a in i.addresses) a.address};
}

/// What a peer entry from `tailscale status --json` says about the path, classified.
Map<String, dynamic> wirePath(Map<String, dynamic> peer, Set<String> mine) {
  final cur = '${peer['CurAddr'] ?? ''}';
  if (cur.isEmpty) {
    return {'kind': 'relay', 'path': 'relayed through ${peer['Relay']}'};
  }
  final colon = cur.lastIndexOf(':');
  final ip = colon < 0 ? cur : cur.substring(0, colon);
  final onThisHost = mine.contains(ip);
  return {
    'kind': onThisHost ? 'same_host' : 'direct',
    'underlay_endpoint': cur,
    'underlay_is_this_container': onThisHost,
    'path': onThisHost
        ? 'both nodes are in this one container: node b reached node a at $cur, which is this '
            "container's own address, so the WireGuard session was carried over the container "
            'link and never crossed a network. On two phones this endpoint is a LAN or public '
            'address and the crossing is between two machines.'
        : 'direct to $cur',
  };
}
