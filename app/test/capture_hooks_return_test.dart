// A capture handle returns when the thing has happened, not when somebody closes it.
//
// Two of the seventeen artifacts were accused of proving nothing: the media viewer frame was a
// picture of the thread, and search never opened. Both handles opened a route with Navigator.push
// and awaited it — and a push does not complete until the page is popped. So the harness asked for
// search, waited for somebody to close it, ran out of time with no shot taken, and what shipped
// was whatever had been captured before.
//
// Nothing here can see a Navigator, so this reads the source: a handle registered on CaptureBus
// may not await a push.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _pushes = [
  'await ViewerPage.open(',
  'await SearchPage.open(',
  'await Navigator.of(context).push',
  'await Navigator.push',
];

void main() {
  test('no capture handle waits for a page to be closed', () {
    final offenders = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final f in files) {
      final src = f.readAsStringSync();
      var at = src.indexOf('CaptureBus.');
      while (at >= 0) {
        final end = src.indexOf('\n    };', at);
        if (end < 0) break;
        final body = src.substring(at, end);
        for (final push in _pushes) {
          if (body.contains(push)) {
            final line = '\n'.allMatches(src.substring(0, at)).length + 1;
            offenders.add('${f.path}:$line  $push');
          }
        }
        at = src.indexOf('CaptureBus.', at + 1);
      }
    }
    expect(offenders, isEmpty,
        reason: 'a capture handle that awaits a route waits for the page to be popped, and the '
            'harness waits with it until the scene times out:\n${offenders.join('\n')}');
  });
}
