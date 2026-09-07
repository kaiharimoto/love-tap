// A letter that opens and stays blank is not a letter.
//
// Three of the six cycle-5 critics measured the same thing on 06_unfolding.mp4: the note arriving
// from the other phone opens over four seconds and ends with a minimum luminance of 223 and not
// one pixel below 150 — no text, no timestamp, no author, no delivery mark. The completeness pass
// corrected one of them for reading it as a design choice and named it the build's worst messenger
// defect.
//
// The cause is a Flutter rule with no error attached to it: a Stack whose children are all
// positioned sizes to nothing under loose constraints, and everything inside it then fills nothing.
// FoldedNote's overlay returns exactly that — a Stack of two Positioned.fill children, the name on
// the folded sheet and the ink on the opened one — so it has to be given a size by whatever places
// it.
//
// This reads the composition rather than the pixels. A rendering test cannot see it: the fold
// frames are decoded asynchronously off the bundle and a widget test draws an empty box instead,
// which is how the defect reached three critics with a green suite behind it.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the sheet overlay is given a size by the frame it is drawn on', () {
    final src = File('lib/material/fold.dart').readAsStringSync();
    final at = src.indexOf('overlay(context, p, size)');
    expect(at, greaterThan(0), reason: 'the overlay is no longer placed where this test looks');
    final line = src.substring(src.lastIndexOf('\n', at) + 1, src.indexOf('\n', at));
    expect(line, contains('Positioned.fill'),
        reason: 'the overlay is placed as a loose child of the frame Stack, so its own positioned '
            'children fill nothing and the letter opens blank:\n$line');
  });

  test('the overlay is a Stack of positioned children, which is why it needs one', () {
    final src = File('lib/material/fold.dart').readAsStringSync();
    // both halves of the overlay return a positioned widget: the name at a corner of the folded
    // sheet, the ink filling the opened one
    expect(src, contains('Widget _name('));
    expect(src, contains('Widget _ink('));
    final name = src.substring(src.indexOf('Widget _name('), src.indexOf('Widget _ink('));
    final ink = src.substring(src.indexOf('Widget _ink('));
    expect(name + ink, contains('Positioned('),
        reason: 'if the overlay stops being positioned children, the sizing rule above changes '
            'and this pair of tests should be rewritten rather than deleted');
  });
}
