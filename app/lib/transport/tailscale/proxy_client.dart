// An HTTP client that reaches the tailnet.
//
// On a phone, Tailscale owns a TUN device: the tailnet is just a route, and an ordinary client
// reaches it with no help at all. The two development nodes have no TUN — they cannot have one in
// a container — so tailscaled runs its network stack in userspace and offers a proxy to reach the
// tailnet through. That is the only difference between the two, and it lives in this one file.
import 'package:http/http.dart' as http;

import 'proxy_client_stub.dart' if (dart.library.io) 'proxy_client_io.dart';

/// A client that reaches the tailnet. An empty [proxy] means the platform routes there itself.
http.Client tailnetClient({String proxy = ''}) => makeTailnetClient(proxy);

/// Accept this certificate and no other. Null clears the pin.
void pinTailnetCertificate(String? fingerprint) => setPinnedFingerprint(fingerprint);

/// The certificate the last connection actually presented, if this platform lets us see it.
String? tailnetCertificateSeen() => lastSeenFingerprint();

/// The pin in force, for the report. Never a key, and never enough to impersonate anything.
String? tailnetCertificatePinned() => pinnedFingerprint;
