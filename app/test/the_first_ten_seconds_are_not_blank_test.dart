// The page puts the desk out before Flutter can, and takes it away on the first frame.
//
// `runApp` is not called until the log is open, and on a first launch that is eight to ten seconds
// — measured in five scene logs, against two on a phone that already has the year. For all of it
// the page was a flat rectangle of the desk's colour, which is why a messenger critic could write
// that no artifact in the set shows what is on the screen during either: nothing was.
//
// The surface lives in index.html, because nothing Dart draws exists yet, so this reads the page
// and holds it to the same rules the rest of the app is held to. It also reads main.dart, because
// a boot surface with nothing to take it away is worse than none.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final raw = File('web/index.html').readAsStringSync();
  // What the browser is left with: the comments explaining the surface are not part of it, and a
  // rule about what may spin should not be answered by the sentence saying nothing does.
  final page = raw
      .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '')
      .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
      .replaceAll(RegExp(r'^\s*//.*$', multiLine: true), '');
  final main_ = File('lib/main.dart').readAsStringSync();

  test('there is a surface, and it is the desk', () {
    expect(page, contains('id="boot"'));
    expect(page, contains('assets/assets/shell/desk.webp'),
        reason: 'the boot surface is not the desk the app draws');
    // The line is on paper, in a hand, not set in the browser's default face on the wood.
    expect(page, contains('assets/assets/paper/'));
    expect(page, contains("font-family: 'NoorHand'"));
  });

  test('and it says one thing, in the voice', () {
    final m = RegExp(r'<p>([^<]+)<').firstMatch(page);
    expect(m, isNotNull, reason: 'the boot surface says nothing');
    final line = m!.group(1)!.trim();
    expect(line, isNotEmpty);
    expect(line, isNot(contains('!')), reason: 'docs/VOICE.md rule 2');
    expect(line, equals(line.toLowerCase()), reason: 'docs/VOICE.md rule 5');
    for (final banned in ['app', 'welcome', 'loading…', 'please wait', 'user']) {
      expect(line.toLowerCase(), isNot(contains(banned)), reason: 'docs/VOICE.md: "$line"');
    }
  });

  test('nothing on it spins', () {
    // A spinner is the thing the row calls out by name, and a progress bar is a claim about how
    // long is left that this build cannot make. The count of months can move; nothing else may.
    expect(page, isNot(contains('@keyframes')));
    expect(page.toLowerCase(), isNot(contains('spinner')));
    expect(page, isNot(contains('<progress')));
    expect(page, contains('__deskBoot'), reason: 'no way for Dart to say how far in it is');
  });

  test('and the app takes it away on the frame that replaces it', () {
    expect(page, contains('__deskDrawn'));
    expect(main_, contains('bootDone()'));
    // On a frame, not on a timer: a timer either flashes the desk away before the app is there or
    // leaves it over the top of a thread somebody is already reading.
    final i = main_.indexOf('bootDone()');
    final before = main_.substring(0, i);
    expect(before, contains('addPostFrameCallback'));
    expect(RegExp(r'Timer\([^)]*bootDone').hasMatch(main_), isFalse);
  });
}
