// The browser cannot be told to use a proxy, and does not need to be: on iOS the Tailscale app
// owns the tunnel, so a request to a tailnet address goes there by itself.
//
// Nor can it be told which certificate to accept. Safari decides that, once, when the person
// installs the profile the other phone is serving and trusts it in settings — which is the
// certificate step on the PWA checklist, and why that list has a step Android's does not. So the
// pin here is not a no-op standing in for something missing: the decision is made outside this
// process by the person, and the browser enforces it on every request afterwards.
import 'package:http/http.dart' as http;

http.Client makeTailnetClient(String proxy) => http.Client();

String? get pinnedFingerprint => null;

void setPinnedFingerprint(String? fingerprint) {}

/// Safari does not hand the page the certificate it validated. What the PWA can say for itself is
/// that the origin is secure, which it reads from `window.isSecureContext`; that is recorded on
/// the web side rather than here.
String? lastSeenFingerprint() => null;
