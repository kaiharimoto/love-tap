// Finding this device's own address on the tailnet, and refusing to serve on anything else.
//
// The whole point of the app is that the two phones talk to each other and to nothing else. That
// is a property of one line of code: which address the host binds. Bind 0.0.0.0 and the phone is
// serving the couple's conversation to every network it is ever on; bind 127.0.0.1 and it is not
// reachable at all. It has to be the tailnet address, and if there is no tailnet address it has to
// refuse to start rather than fall back to something that works.
//
// A tailnet address is a CGNAT-range IPv4 (100.64.0.0/10) or a Tailscale IPv6 (fd7a:115c:a1e0::/48).
// Nothing else is one, whatever it is called.
import 'dart:io';

/// Why a bind was refused, in words the setup list can show.
class NotOnTheTailnet implements Exception {
  const NotOnTheTailnet(this.what);
  final String what;
  @override
  String toString() => what;
}

/// True for an address Tailscale itself hands out and for no other.
bool isTailnetAddress(String address) {
  final v4 = InternetAddress.tryParse(address);
  if (v4 == null) return false;
  if (v4.type == InternetAddressType.IPv4) {
    final parts = address.split('.').map(int.tryParse).toList();
    if (parts.length != 4 || parts.any((p) => p == null)) return false;
    // 100.64.0.0/10 — the carrier-grade NAT range Tailscale allocates from
    return parts[0] == 100 && parts[1]! >= 64 && parts[1]! <= 127;
  }
  final low = address.toLowerCase();
  return low.startsWith('fd7a:115c:a1e0');
}

/// Every address this device holds that is on the tailnet.
Future<List<String>> tailnetAddresses() async {
  final out = <String>[];
  try {
    for (final nic in await NetworkInterface.list(includeLoopback: false)) {
      for (final a in nic.addresses) {
        if (isTailnetAddress(a.address)) out.add(a.address);
      }
    }
  } on Exception {
    // no permission to enumerate interfaces (some Android configurations); fall through
  }
  return out;
}

/// The address to serve on, or an exception saying why there is not one.
///
/// [declared] is what the build or the setup list was told to use — the tailnet IP of this phone,
/// which the Tailscale app shows and which run.sh passes for the two test nodes. It is checked
/// rather than trusted: a declared address that is not a tailnet address is refused, because the
/// point of declaring it is not to make binding convenient.
Future<String> addressToServeOn({String declared = ''}) async {
  if (declared.isNotEmpty) {
    if (!isTailnetAddress(declared)) {
      throw NotOnTheTailnet(
          '$declared is not a tailnet address, and this only ever serves on one of those');
    }
    return declared;
  }
  final found = await tailnetAddresses();
  if (found.isEmpty) {
    throw const NotOnTheTailnet(
        'this phone is not on the tailnet yet, so there is nowhere safe to serve from');
  }
  // prefer the IPv4: it is the one a person can read off the Tailscale app and type in
  found.sort((a, b) => a.contains(':') ? 1 : (b.contains(':') ? -1 : 0));
  return found.first;
}
