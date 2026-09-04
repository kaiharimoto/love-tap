// Every mark in the app is drawn; none of it is a glyph looked up in a font.
//
// The anti-goal is emoji soup or stock illustration standing in for feeling, and the whole visual
// concept is that a surface is photographed paper. Both fail the same way: a character out of an
// icon font — a Material play arrow, a heart, a checkmark — laid on a torn sheet reads as a
// sticker stuck to it, because it has no pressure, no wobble, and no light on it.
//
// One survived a long time: a Material play arrow on every voice note, the last IconData in the
// app. It is now Mark.play, three pencil strokes that overshoot at the corners. This is what
// stops the next one arriving, because reaching for an icon is one import away at all times.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Icon fonts, by the four ways one gets used: the set, the type, the button, the constructor.
final _iconFont = RegExp(r'\b(Icons|CupertinoIcons|IconData|IconButton)\b|\bIcon\(');

/// A system emoji glyph is a font lookup too, and the brief names it as a failure: no emoji
/// anywhere. Anything above U+1F000, plus the blocks the dingbats and the arrows live in — an
/// arrow drawn by a colour emoji font is exactly the sticker this is about.
final _emoji = RegExp(
  r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}\u{2190}-\u{21FF}\u{2B00}-\u{2BFF}]',
  unicode: true,
);

/// What sits inside quotes: the only text on a line that can reach a screen. Prose in a comment
/// may use an arrow, because nobody reads a comment on a phone.
final _quoted = RegExp('\'[^\']*\'|"[^"]*"');

List<File> _sources() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList()
  ..sort((a, b) => a.path.compareTo(b.path));

void main() {
  test('no icon font glyph is drawn anywhere in the app', () {
    final offenders = <String>[];
    for (final f in _sources()) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // a comment saying why there are no icons is not an icon
        if (line.trimLeft().startsWith('//')) continue;
        if (_iconFont.hasMatch(line)) offenders.add('${f.path}:${i + 1}  ${line.trim()}');
      }
    }
    expect(offenders, isEmpty,
        reason: 'these reach for an icon font; draw the mark in material/marks.dart instead:\n'
            '${offenders.join('\n')}');
  });

  test('no system emoji glyph appears in any displayed string', () {
    final offenders = <String>[];
    for (final f in _sources()) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        for (final m in _quoted.allMatches(line)) {
          if (_emoji.hasMatch(m[0]!)) offenders.add('${f.path}:${i + 1}  ${line.trim()}');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'an emoji is a glyph out of a font the operating system chose:\n'
            '${offenders.join('\n')}');
  });
}
