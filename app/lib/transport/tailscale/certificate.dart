// The certificate the host serves on, made on the phone and never anywhere else.
//
// The transport had a `securityContext` on its bind and nothing ever passed one, so the host was
// serving plain HTTP while the setup checklist ticked a step called "trust the certificate the
// other phone holds" and docs/PHONES.md told the reader to open an https address. A code critic
// found all three at once and was right about every one of them.
//
// Two things turn on this and neither is cosmetic. A page served over http:// at a 100.64/10
// address is not a secure context, so `navigator.serviceWorker` is undefined in Safari and the
// iPhone cannot register the worker that receives a push — the third ambient surface simply does
// not exist without this. And a checklist that ticks for a thing that did not happen is worse than
// one step short.
//
// What this is not: a certificate authority. There is no CA anywhere in this, no CA key, and
// nothing signs anything but itself. The key is generated on the phone at first start, written
// into the app's own storage and read back afterwards; it is never in this repository, never in a
// build, and never sent anywhere. What authenticates the two phones to each other is the six
// spoken words and the key they derive, exactly as before — the certificate is what makes the
// origin secure, not what makes it trusted.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:basic_utils/basic_utils.dart';
import 'package:crypto/crypto.dart';

/// A key and a certificate for one address, made once and kept.
class HostCertificate {
  const HostCertificate({required this.certificatePem, required this.privateKeyPem, required this.fingerprint});

  final String certificatePem;
  final String privateKeyPem;

  /// SHA-256 of the certificate's DER bytes, lower-case hex in colon-separated pairs — the same
  /// digest a browser shows when it asks whether to trust it, so a person can compare the two.
  final String fingerprint;

  SecurityContext get context => SecurityContext(withTrustedRoots: false)
    ..useCertificateChainBytes(utf8.encode(certificatePem))
    ..usePrivateKeyBytes(utf8.encode(privateKeyPem));
}

/// The fingerprint of a PEM certificate, in the form a browser prints.
String fingerprintOf(String certificatePem) {
  final body = certificatePem
      .replaceAll(RegExp(r'-----(BEGIN|END) CERTIFICATE-----'), '')
      .replaceAll(RegExp(r'\s'), '');
  final der = base64.decode(body);
  final hex = sha256.convert(der).bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).toList();
  final pairs = <String>[];
  for (var i = 0; i < hex.length; i++) {
    pairs.add(hex[i]);
  }
  return pairs.join(':');
}

/// Make one for [address], valid for ten years. Slow — a 2048-bit key takes a second or two on a
/// phone — so it is made once and read back after that.
HostCertificate makeCertificate(String address) {
  final pair = CryptoUtils.generateRSAKeyPair(keySize: 2048);
  final private = pair.privateKey as RSAPrivateKey;
  final public = pair.publicKey as RSAPublicKey;
  final dn = {'CN': address, 'O': 'the other phone'};
  // The address goes in the subject alternative name as well as the common name: a name in CN
  // alone has not been accepted by anything since 2017.
  final csr = X509Utils.generateRsaCsrPem(dn, private, public, san: [address]);
  final pem = X509Utils.generateSelfSignedCertificate(
    private,
    csr,
    3650,
    sans: [address],
  );
  return HostCertificate(
    certificatePem: pem,
    privateKeyPem: CryptoUtils.encodeRSAPrivateKeyToPem(private),
    fingerprint: fingerprintOf(pem),
  );
}

/// Whether a stored certificate was made for [address] — read out of it, not guessed from it.
bool certificateIsFor(String pem, String address) {
  try {
    final data = X509Utils.x509CertificateFromPem(pem);
    final tbs = data.tbsCertificate;
    final subject = tbs?.subject.values.whereType<String>().join(' ') ?? '';
    final sans = tbs?.extensions?.subjectAlternativNames ?? const <String>[];
    return subject.contains(address) || sans.contains(address);
  } catch (_) {
    return false;   // unreadable is not "mine"
  }
}

/// Read the one in [dir], or make it and write it there.
///
/// Two files, both inside the app's own storage: `host.crt` and `host.key`. The key is written
/// with no group or world access where the platform allows it. Nothing copies them anywhere — the
/// Android manifest excludes the whole of this directory from cloud backup and from the
/// phone-to-phone transfer, which is what `nothing_leaves_the_phone_test` checks.
Future<HostCertificate> certificateIn(Directory dir, String address) async {
  final crt = File('${dir.path}/host.crt');
  final key = File('${dir.path}/host.key');
  if (await crt.exists() && await key.exists()) {
    final pem = await crt.readAsString();
    // A phone that moved to a different tailnet address needs a certificate for the new one, so
    // the stored one is decoded and its subject read. Searching the PEM for the address was the
    // first attempt and it never matched anything: a PEM is base64, so the name is not in it as
    // text and every certificate looked like it was for the wrong address, or for the right one,
    // at random.
    if (certificateIsFor(pem, address)) {
      return HostCertificate(
        certificatePem: pem,
        privateKeyPem: await key.readAsString(),
        fingerprint: fingerprintOf(pem),
      );
    }
  }
  final made = makeCertificate(address);
  await dir.create(recursive: true);
  await crt.writeAsString(made.certificatePem, flush: true);
  await key.writeAsString(made.privateKeyPem, flush: true);
  try {
    await Process.run('chmod', ['600', key.path]);
  } catch (_) {
    // not every platform has chmod, and the directory is already app-private on both
  }
  return made;
}

/// The bytes a client would pin, for the record. Never the key.
Uint8List certificateBytes(HostCertificate c) => Uint8List.fromList(utf8.encode(c.certificatePem));
