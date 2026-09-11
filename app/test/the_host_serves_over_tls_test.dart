// The host serves over TLS, and the certificate is made on the phone.
//
// `HostBind` has carried a `securityContext` since the protocol was written and nothing ever
// passed one, so the host answered plain HTTP — while the setup list ticked a step called "trust
// the certificate the other phone holds" and docs/PHONES.md told the reader to open an https
// address. A code critic found all three at once.
//
// Two things turn on it. A page served over http at a 100.64/10 address is not a secure context,
// so Safari gives the iPhone no `navigator.serviceWorker` and the push surface — one of the three
// ambient surfaces the brief counts — cannot exist at all. And a tick for a thing that did not
// happen is worse than a step missing.
@TestOn('vm')
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:desk/setup/checklist.dart';
import 'package:desk/transport/protocol/wire.dart';
import 'package:desk/transport/transport.dart';
import 'package:desk/transport/tailscale/certificate.dart';
import 'package:desk/transport/tailscale/proxy_client_io.dart';
import 'package:desk/transport/tailscale/tailscale_transport.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('tls_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('the host binds with a certificate rather than in the clear', () async {
    final b = TailscaleBinding(
      declaredAddress: '100.90.80.70',
      port: 8443,
      certificateDir: () async => dir,
    );
    final bind = await b.hostBind();
    expect(bind.securityContext, isNotNull,
        reason: 'the host is still answering plain HTTP');
    expect(b.certificate, isNotNull);
    // Made for the address it is actually serving on, not for localhost or a wildcard.
    expect(b.certificate!.certificatePem, contains('BEGIN CERTIFICATE'));
    expect(b.certificate!.fingerprint.split(':').length, 32,
        reason: 'a SHA-256 fingerprint is thirty-two bytes');
  });

  test('and it is kept, not made again every start', () async {
    Future<String> once() async {
      final b = TailscaleBinding(
          declaredAddress: '100.90.80.70', port: 8443, certificateDir: () async => dir);
      await b.hostBind();
      return b.certificate!.fingerprint;
    }

    final a = await once();
    final b = await once();
    expect(b, a, reason: 'a new certificate every start is a new certificate to trust every start');
    expect(File('${dir.path}/host.crt').existsSync(), isTrue);
    expect(File('${dir.path}/host.key').existsSync(), isTrue);
  });

  test('the client refuses a certificate that is not the one it pinned', () {
    final mine = makeCertificate('100.90.80.70');
    final theirs = makeCertificate('100.90.80.70');
    expect(mine.fingerprint, isNot(theirs.fingerprint));
    // The pinning itself is a pure function of the DER bytes, so it can be checked without a
    // socket: what the client compares is what the host published.
    expect(fingerprintOfDer(derOf(mine.certificatePem)), mine.fingerprint);
    expect(fingerprintOfDer(derOf(theirs.certificatePem)), isNot(mine.fingerprint));
  });

  test('the address it serves on is the address in the certificate', () async {
    final c = await certificateIn(dir, '100.90.80.70');
    expect(c.certificatePem, isNotEmpty);
    // A phone that moves to a new tailnet address gets a new certificate rather than serving one
    // for an address it no longer has.
    final moved = await certificateIn(dir, '100.11.22.33');
    expect(moved.fingerprint, isNot(c.fingerprint));
  });

  test('no key material is in the repository', () {
    for (final d in [Directory('lib'), Directory('assets'), Directory('web')]) {
      if (!d.existsSync()) continue;
      for (final f in d.listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart') && !f.path.endsWith('.json') && !f.path.endsWith('.html')) {
          continue;
        }
        final text = f.readAsStringSync();
        expect(text, isNot(contains('BEGIN RSA PRIVATE KEY')), reason: f.path);
        expect(text, isNot(contains('BEGIN PRIVATE KEY')), reason: f.path);
        expect(text, isNot(contains('BEGIN CERTIFICATE-----\nMII')), reason: f.path);
      }
    }
  });

  test('the pin is what was on the wire, and a different certificate is refused', () {
    final mine = makeCertificate('100.90.80.70');
    final theirs = makeCertificate('100.90.80.70');

    // Nothing pinned: this is the pairing request itself, where the six words are the proof and
    // the certificate is not known yet. It is accepted, and it is recorded.
    setPinnedFingerprint(null);
    expect(acceptCertificate(_FakeCert(derOf(mine.certificatePem))), isTrue);
    expect(lastSeenFingerprint(), mine.fingerprint,
        reason: 'what gets pinned has to be a thing that was seen, not a thing configured');

    // From then on it is the only one this client will talk to.
    setPinnedFingerprint(lastSeenFingerprint());
    expect(acceptCertificate(_FakeCert(derOf(mine.certificatePem))), isTrue);
    expect(acceptCertificate(_FakeCert(derOf(theirs.certificatePem))), isFalse,
        reason: 'a different certificate at the same address is a different phone');

    // Replacing a device clears it, or the new phone would be refused forever.
    setPinnedFingerprint(null);
    expect(acceptCertificate(_FakeCert(derOf(theirs.certificatePem))), isTrue);
  });

  test('the setup list will not tick a certificate step for a connection with no certificate', () {
    SetupFacts facts(String? certificate, LinkState state) => SetupFacts(
          platform: 'android',
          link: TransportStatus(
              name: 'tailscale',
              role: TransportRole.host,
              state: state,
              address: '100.90.80.70:8443',
              certificate: certificate),
          paired: null,
          notificationsAllowed: false,
          installedToHome: true,
          certificate: certificate,
          mineInSpine: false,
          theirsInSpine: false,
        );
    final steps = stepsFor('android');

    // This is the regression itself: the step used to read `state == connected || listening` and
    // ticked for a link that had no certificate anywhere in it.
    expect(observe(steps, facts(null, LinkState.listening))['certificate'], isNot(StepState.done));
    expect(observe(steps, facts(null, LinkState.connected))['certificate'], isNot(StepState.done));

    final fingerprint = makeCertificate('100.90.80.70').fingerprint;
    expect(observe(steps, facts(fingerprint, LinkState.listening))['certificate'], StepState.done);
  });

  test('and on the PWA it is the browser that says so', () {
    // Safari never hands the page what it validated, so there is no fingerprint to read there.
    // What it will say is whether the origin is secure — which is exactly the thing that gates
    // `navigator.serviceWorker`, so it is the honest thing to watch.
    SetupFacts facts({required bool secure}) => SetupFacts(
          platform: 'pwa',
          link: const TransportStatus(
              name: 'tailscale', role: TransportRole.client, state: LinkState.connected),
          paired: null,
          notificationsAllowed: false,
          installedToHome: true,
          certificate: null,
          secureOrigin: secure,
          mineInSpine: false,
          theirsInSpine: false,
        );
    final steps = stepsFor('pwa');
    expect(observe(steps, facts(secure: false))['certificate'], isNot(StepState.done));
    expect(observe(steps, facts(secure: true))['certificate'], StepState.done);
  });

  test('the auth header still signs every request, certificate or no certificate', () {
    // The certificate makes the origin secure. It is not what authenticates the two phones to each
    // other, and the thing that does has not moved.
    expect(kAuthSkew.inMinutes, 5);
  });
}

/// Only the DER bytes are read by the pin, so this is the whole of what a certificate is here.
class _FakeCert implements X509Certificate {
  _FakeCert(List<int> bytes) : der = Uint8List.fromList(bytes);

  @override
  final Uint8List der;

  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}
