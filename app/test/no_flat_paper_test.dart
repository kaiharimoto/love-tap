// Nothing in the app is a flat rectangle where paper should be.
//
// The anti-goal critic found two of these and they cost the whole category: an action sheet that
// was one uniform fill at L=235 — three 80x80 patches each returning std 0.000, one unique value —
// with "reply" and "react" written on bare colour, and a setup screen that was one flat fill over
// its entire 1440x3120. Both arrived the same way: a modal sheet and a dialog take a background
// colour, so a surface becomes a flat fill by writing one line, and stays that way because it
// looks approximately right in a thumbnail.
//
// So the shapes that get there by default are named here, and the app is read for them.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The colours the paper stocks are. A widget filled with one of these is standing in for paper.
final _paperColours = RegExp(r'0xFF(F1ECDF|F4F0E4|EFE9DA|F2EEE1|FAF7EC|F6F2E6)', caseSensitive: false);

List<File> _sources() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList()
  ..sort((a, b) => a.path.compareTo(b.path));

void main() {
  test('no surface is a flat fill in a paper colour', () {
    final offenders = <String>[];
    for (final f in _sources()) {
      // palette.dart is where the stock colours are declared, and paper.dart is the one widget
      // allowed to paint one — under the render, so a sheet whose image is missing is still a
      // sheet rather than a hole.
      if (f.path.endsWith('material/palette.dart') || f.path.endsWith('material/paper.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (_paperColours.hasMatch(lines[i])) {
          offenders.add('${f.path}:${i + 1}  ${lines[i].trim()}');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'a paper colour painted flat, outside the paper widget:\n${offenders.join('\n')}');
  });

  test('no dialog box: a question is asked on a slip', () {
    final offenders = <String>[];
    for (final f in _sources()) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains('AlertDialog(') || lines[i].contains('SimpleDialog(')) {
          offenders.add('${f.path}:${i + 1}');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'a rounded rectangle with a flat fill and an elevation shadow under it, which is '
            'the named failure of the visual concept:\n${offenders.join('\n')}');
  });

  test('every modal sheet comes up transparent, so what is on it has to be paper', () {
    // showModalBottomSheet paints its own background unless told not to. Told not to, the builder
    // has to supply a surface, and the only surfaces the app has are pieces of paper.
    final offenders = <String>[];
    for (final f in _sources()) {
      final src = f.readAsStringSync();
      var at = src.indexOf('showModalBottomSheet');
      while (at >= 0) {
        // the call's arguments, up to its builder
        final end = src.indexOf('builder:', at);
        final head = end < 0 ? src.substring(at) : src.substring(at, end);
        if (!head.contains('backgroundColor: Colors.transparent')) {
          final line = '\n'.allMatches(src.substring(0, at)).length + 1;
          offenders.add('${f.path}:$line');
        }
        at = src.indexOf('showModalBottomSheet', at + 1);
      }
    }
    expect(offenders, isEmpty,
        reason: 'a sheet that paints its own flat background:\n${offenders.join('\n')}');
  });
}
