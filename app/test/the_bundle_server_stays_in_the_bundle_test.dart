// The host serves the PWA without authentication, and must serve nothing else.
//
// Serving the bundle before pairing is deliberate: it is how the other phone gets the app, and a
// phone that had to be paired before it could fetch the thing that does the pairing could never be
// paired. A code critic read the unauthenticated branch as a hole. The hole was real but it was
// one line further down: `p.join(root, rel)` returns `rel` whole when `rel` is absolute, and
// `req.uri.path.substring(1)` leaves a leading slash on `//etc/passwd`, which normalize keeps — so
// that request walked out of the bundle and read the machine.
@TestOn('vm')
library;

import 'package:desk/transport/protocol/server_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  const root = '/srv/desk/bundle';
  final within = p.normalize(p.absolute(root));

  test('the bundle itself is reachable', () {
    expect(insideTheBundle(root, '/'), p.join(within, 'index.html'));
    expect(insideTheBundle(root, '/index.html'), p.join(within, 'index.html'));
    expect(insideTheBundle(root, '/assets/fonts/NoorHand.ttf'),
        p.join(within, 'assets/fonts/NoorHand.ttf'));
  });

  test('nothing above it is', () {
    // An absolute path cannot climb above its own root — p.normalize('/../../etc/passwd') is
    // '/etc/passwd' — so these are not refused, they are *confined*: a leading slash is a spelling
    // of the bundle's own root, so this asks for bundle/etc/passwd, which does not exist and falls
    // back to index.html. What matters is the path it resolves to, and the old code resolved this
    // one to /etc/passwd because p.join returns an absolute second argument whole.
    expect(insideTheBundle(root, '//etc/passwd'), p.join(within, 'etc/passwd'));
    expect(insideTheBundle(root, '/../../etc/passwd'), p.join(within, 'etc/passwd'));
    // A *relative* climb is refused outright, because that one really does leave.
    expect(insideTheBundle(root, 'assets/../../secrets.env'), isNull);
    expect(insideTheBundle(root, '../secrets.env'), isNull);
    // Dart has already percent-decoded req.uri.path by the time this sees it, so `%2e%2e` arrives
    // as `..` and is the case above. What must NOT happen is a second decode here, which would
    // turn a literal `%252e%252e` into `..`; a path that still has escapes in it after Dart is
    // done with it is a file name, not an instruction.
    expect(insideTheBundle(root, '/%2e%2e/%2e%2e/etc/passwd'),
        p.join(within, '%2e%2e/%2e%2e/etc/passwd'));
    expect(insideTheBundle(root, '///etc/passwd'), p.join(within, 'etc/passwd'));
  });

  test('a path that climbs and comes back is still inside', () {
    expect(insideTheBundle(root, '/assets/../index.html'), p.join(within, 'index.html'));
  });

  test('whatever is asked for, the answer is inside the bundle or it is nothing', () {
    const hostile = [
      '/', '//', '///', '/..', '/../', '/../..', '//etc/passwd', '/../../../../etc/shadow',
      '/assets/../../secrets.env', '/./././..', '/%2e%2e/etc', '/a/b/c/../../../../..',
      r'/\..\..\windows\win.ini', '/....//....//etc/passwd', '/index.html/../../..',
    ];
    for (final path in hostile) {
      final got = insideTheBundle(root, path);
      if (got == null) continue;
      expect(got == within || p.isWithin(within, got), isTrue,
          reason: '$path resolved to $got, which is outside $within');
    }
  });
}
