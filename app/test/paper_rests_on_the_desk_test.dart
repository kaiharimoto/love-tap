// A piece of paper on a desk casts a shadow onto the desk.
//
// For four review cycles it did not, and the reason was one default. The baked contact shadow is
// framed a quarter wider than the piece — the visible part of a contact shadow is the part the
// paper is not covering — and it is drawn inside a Stack, which clips to its own bounds unless
// told otherwise. So every visible part of every shadow in the app was cut off, leaving only the
// part underneath the paper, which the paper then covers. Two critics and a completeness pass
// measured the same null: with the tear ink excluded, the desk beside a note has the same median
// luminance in every direction at every distance.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the stack a piece is composed in does not clip its shadow', () {
    final src = File('lib/material/paper.dart').readAsStringSync();
    final at = src.indexOf('_bakedShadow(context, suffix) else _cutShadow(dusk)');
    expect(at, greaterThan(0), reason: 'the shadow is no longer composed where this test looks');
    // the Stack that holds it, reading backwards from the shadow to the widget that contains it
    final before = src.substring(0, at);
    final stackAt = before.lastIndexOf('Stack(');
    expect(stackAt, greaterThan(0));
    final head = src.substring(stackAt, at);
    expect(head, contains('Clip.none'),
        reason: 'the piece is composed in a Stack that clips, so the part of the contact shadow '
            'that falls on the desk — the only part anyone sees — is cut off:\n$head');
  });
}
