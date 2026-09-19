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

  // ---- userspace mode, which is the mode every measured run in this repository uses -----------
  //
  // `coldstart_test.dart` and `reliability_test.dart` both run it, because a container cannot have
  // a TUN device. Nothing tested the branch. `hostBind` reads
  // `boundTo = isUserspace ? '127.0.0.1' : address`, so the whole of the mode that actually runs
  // here turned on a ternary no test could see: changing that literal to `'0.0.0.0'` would have
  // put the conversation on every interface of the phone and the suite would have stayed green.

  test('userspace narrows to loopback, and the phone is still reached on the tailnet', () async {
    final b = TailscaleBinding(
      declaredAddress: '100.90.80.70', port: 8443, userspaceProxy: '127.0.0.1:1055');
    expect(b.isUserspace, isTrue);
    final bind = await b.hostBind();

    // The listener is loopback and nothing else. This is narrower than the tailnet address rather
    // than wider -- tailscaled accepts the inbound connection and hands it here -- and it is the
    // only narrowing allowed: a wildcard is the failure condition itself.
    expect(bind.address, '127.0.0.1');
    expect(isTailnetAddress(bind.address), isFalse,
        reason: 'loopback is not a tailnet address; it is the deliberate exception');
    for (final wide in ['0.0.0.0', '::', '192.168.0.10', '10.0.0.7']) {
      expect(bind.address, isNot(wide));
    }

    // and the address the other phone is told to reach it at is still a tailnet address, which is
    // what the failure condition is actually protecting
    expect(b.reachableAt, '100.90.80.70');
    expect(isTailnetAddress(b.reachableAt!), isTrue);
  });

  test('userspace is not a way round the address check', () async {
    // the check runs before the ternary, in both modes: a declared address is refused in userspace
    // exactly as it is with a TUN, or userspace would be a hole shaped like the whole rule
    for (final bad in ['0.0.0.0', '127.0.0.1', '192.168.0.10', '10.0.0.7', '::']) {
      await expectLater(
        TailscaleBinding(declaredAddress: bad, userspaceProxy: '127.0.0.1:1055').hostBind(),
        throwsA(isA<NotOnTheTailnet>()),
        reason: 'declaring $bad must not be a way round the rule in userspace either',
      );
    }
  });

  test('whichever mode it is in, the host never binds a wide address', () async {
    // the property the brief states, over both branches of the ternary at once
    for (final proxy in ['', '127.0.0.1:1055']) {
      final b = TailscaleBinding(
        declaredAddress: '100.90.80.70', port: 8443, userspaceProxy: proxy);
      final bind = await b.hostBind();
      final ok = isTailnetAddress(bind.address) || bind.address == '127.0.0.1';
      expect(ok, isTrue,
          reason: 'bound ${bind.address} with userspaceProxy "$proxy": a host serves on its '
              'tailnet address, or on loopback behind a userspace tailscaled, and nowhere else');
      expect(isTailnetAddress(b.reachableAt ?? ''), isTrue,
          reason: 'the address the other phone is given must always be a tailnet address');
    }
  });
}
