// Native: go out through the userspace tailscaled's own outbound proxy when there is one, and
// accept exactly one certificate — the other phone's, by its fingerprint.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// The fingerprint of the certificate this client will accept, and nothing else.
///
/// The host signs its own certificate, so there is no authority to check it against and the
/// default answer is to refuse. What takes the authority's place is the six spoken words: pairing
/// happens with two people in one room, the certificate that was on the wire at that moment is
/// written down, and from then on a certificate that is not that one is a different phone.
///
/// Null means nothing is pinned, which is true exactly once — during the pairing request itself,
/// where the words are the proof and the certificate is not yet known. Every request after it is
/// checked against what was seen then.
String? _pinned;

/// What the last connection actually presented. Read after pairing so that what gets written down
/// is a thing that was on the wire rather than a thing somebody typed in.
String? _seen;

String? get pinnedFingerprint => _pinned;

void setPinnedFingerprint(String? fingerprint) =>
    _pinned = (fingerprint == null || fingerprint.isEmpty) ? null : fingerprint;

String? lastSeenFingerprint() => _seen;

/// SHA-256 of a certificate's DER bytes, lower-case hex with colons, the way a browser prints it
/// and the way a person can read it out loud to compare with the other phone's screen.
String fingerprintOfDer(List<int> der) =>
    sha256.convert(der).bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(':');

/// Called by dart:io for a certificate the default rules rejected — which, for a certificate that
/// signs itself, is every one of them. There is no path here where a certificate is accepted
/// without being seen: the only two answers are "this is the one that was pinned" and, before
/// anything is pinned, "this is the pairing request, and the words are the proof".
bool acceptCertificate(X509Certificate cert) {
  final fingerprint = fingerprintOfDer(cert.der);
  _seen = fingerprint;
  final pin = _pinned;
  if (pin == null) return true;
  return fingerprint == pin;
}

http.Client makeTailnetClient(String proxy) {
  final client = HttpClient()..badCertificateCallback = (cert, host, port) => acceptCertificate(cert);
  if (proxy.isNotEmpty) client.findProxy = (_) => 'PROXY $proxy';
  return IOClient(client);
}

/// Only ever used to carry the host's own certificate to its client, never a key.
String pemToBase64(String pem) => pem
    .replaceAll(RegExp(r'-----(BEGIN|END) CERTIFICATE-----'), '')
    .replaceAll(RegExp(r'\s'), '');

/// The DER bytes of a PEM certificate.
List<int> derOf(String pem) => base64.decode(pemToBase64(pem));
