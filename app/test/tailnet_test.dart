// The one line the whole premise rests on: which address the host serves the conversation from.
//
// The brief names it as a failure condition — "the host binding to any address other than its
// tailnet address" — so it is not enough for the code to bind the right thing today. There has to
// be no path through it that reaches a wildcard, and that is what these check.
import 'package:desk/transport/tailscale/tailnet.dart';
import 'package:desk/transport/tailscale/tailscale_transport.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an address is on the tailnet or it is not', () {
    // 100.64.0.0/10, which is what Tailscale allocates from
    expect(isTailnetAddress('100.64.0.1'), isTrue);
    expect(isTailnetAddress('100.101.102.103'), isTrue);
    expect(isTailnetAddress('100.127.255.254'), isTrue);
    expect(isTailnetAddress('fd7a:115c:a1e0::1'), isTrue);
    expect(isTailnetAddress('FD7A:115C:A1E0:AB12::3'), isTrue);

    // everything a mistake would reach for
    expect(isTailnetAddress('0.0.0.0'), isFalse);
    expect(isTailnetAddress('127.0.0.1'), isFalse);
    expect(isTailnetAddress('192.168.1.4'), isFalse);
    expect(isTailnetAddress('10.0.0.7'), isFalse);
    expect(isTailnetAddress('100.63.255.255'), isFalse);   // just below the range
    expect(isTailnetAddress('100.128.0.0'), isFalse);      // just above it
    expect(isTailnetAddress('::'), isFalse);
    expect(isTailnetAddress('fe80::1'), isFalse);
    expect(isTailnetAddress(''), isFalse);
    expect(isTailnetAddress('everywhere'), isFalse);
  });

  test('a declared address is checked rather than trusted', () async {
    for (final bad in ['0.0.0.0', '127.0.0.1', '192.168.0.10', '::']) {
      await expectLater(
        TailscaleBinding(declaredAddress: bad).hostBind(),
        throwsA(isA<NotOnTheTailnet>()),
        reason: 'declaring $bad must not be a way round the rule',
      );
    }
    final ok = await TailscaleBinding(declaredAddress: '100.90.80.70', port: 8443).hostBind();
    expect(ok.address, '100.90.80.70');
    expect(ok.port, 8443);
  });

  test('with no tailnet address there is no fallback, only a reason', () async {
    // The test host has no tailnet interface, so this exercises the real path: it must refuse and
    // say why, never quietly serve on something that happens to work.
    Object? thrown;
    try {
      await TailscaleBinding().hostBind();
    } catch (e) {
      thrown = e;
    }
    if (thrown != null) {
      expect(thrown, isA<NotOnTheTailnet>());
      expect('$thrown', contains('tailnet'));
    } else {
      // if this machine really is on a tailnet, then what it bound has to be a tailnet address
      final bind = await TailscaleBinding().hostBind();
      expect(isTailnetAddress(bind.address), isTrue);
    }
  });

  test('the client will not talk to anything off the tailnet', () async {
    final b = TailscaleBinding(peerAddress: '100.70.60.50');
    expect((await b.clientBase(null)).host, '100.70.60.50');
    await expectLater(b.clientBase('http://192.168.1.9:8443'), throwsA(isA<NotOnTheTailnet>()));
    await expectLater(TailscaleBinding().clientBase(null), throwsA(isA<NotOnTheTailnet>()));
  });

  test('an IPv6 tailnet address is bracketed in a URL', () async {
    final b = TailscaleBinding(peerAddress: 'fd7a:115c:a1e0::9', port: 8443);
    expect((await b.clientBase(null)).toString(), 'http://[fd7a:115c:a1e0::9]:8443');
  });
}
