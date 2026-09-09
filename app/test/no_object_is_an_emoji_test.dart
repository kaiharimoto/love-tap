// An object a feeling can be made of is a thing on a desk, not a symbol.
//
// obj_heart_fold shipped in the bundle for five cycles: a heart silhouette, 1200x1200, left-right
// symmetric to a correlation of 1.0000, with no crease, no fold and no cut edge — the emoji shape
// the anti-goal names, inside the first thirty objects the feeling-authoring picker offers. No
// feeling named it, which is why nothing caught it: it was reachable without being used.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no object in the library is a symbol', () {
    // A silhouette that is exactly symmetric about its own middle is a symbol, not a thing lit by
    // a lamp on one side: every object in this library is rendered under the same light as the
    // paper, so its left and its right cannot match.
    const forbidden = ['heart', 'star', 'crown', 'trophy', 'medal', 'thumbs', 'smile', 'face'];
    final dir = Directory('../assets/objects');
    expect(dir.existsSync(), isTrue, reason: 'no object library to read');
    final named = <String>[];
    for (final f in dir.listSync().whereType<File>()) {
      final name = f.uri.pathSegments.last;
      for (final word in forbidden) {
        if (name.contains(word)) named.add(name);
      }
    }
    expect(named, isEmpty,
        reason: 'the library carries ${named.join(', ')} — an object a feeling can be made of is a '
            'thing somebody could pick up off the desk, and these are the shapes the anti-goal '
            'names');
  });
}
