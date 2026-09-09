// A letter with a counter in it must have a counter in it.
//
// DeskStamp is the face on every tab and every module heading, and it lost every counter it had:
// the O, D, B, P, R, A, Q and 0 were solid blobs, so the strip read `T● D●` and `M●MENTS` in every
// capture for eight cycles. The cause was in the build — after eroding, the eroded contours were
// re-unioned with every one of them turned positive, and a hole turned positive is a disc, and a
// disc unioned into the shape it was cut from fills it.
//
// This reads the built font rather than the source, because the font is what the app loads.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// How many contours the glyph for [ch] has in the TrueType file at [path].
///
/// Parsed straight out of `glyf`: a simple glyph's first int16 is its contour count, and a
/// negative count is a composite, which is resolved by counting the components' own.
int _contours(String path, String ch) {
  final b = File(path).readAsBytesSync().buffer.asByteData();
  int u16(int o) => b.getUint16(o);
  int u32(int o) => b.getUint32(o);
  final numTables = u16(4);
  final tables = <String, (int, int)>{};
  for (var i = 0; i < numTables; i++) {
    final o = 12 + i * 16;
    final tag = String.fromCharCodes([for (var k = 0; k < 4; k++) b.getUint8(o + k)]);
    tables[tag] = (u32(o + 8), u32(o + 12));
  }
  final head = tables['head']!.$1;
  final longLoca = b.getInt16(head + 50) == 1;
  final maxp = tables['maxp']!.$1;
  final numGlyphs = u16(maxp + 4);
  final loca = tables['loca']!.$1;
  final glyf = tables['glyf']!.$1;

  // cmap format 4, the Windows BMP subtable
  final cmap = tables['cmap']!.$1;
  var sub = -1;
  for (var i = 0; i < u16(cmap + 2); i++) {
    final rec = cmap + 4 + i * 8;
    if (u16(rec) == 3 && u16(rec + 2) == 1) sub = cmap + u32(rec + 4);
  }
  expect(sub, isNot(-1), reason: '$path has no Windows BMP cmap');
  final segX2 = u16(sub + 6);
  final ends = sub + 14;
  final starts = ends + segX2 + 2;
  final deltas = starts + segX2;
  final ranges = deltas + segX2;
  final code = ch.codeUnitAt(0);
  var gid = 0;
  for (var s = 0; s < segX2 ~/ 2; s++) {
    if (u16(ends + s * 2) >= code && u16(starts + s * 2) <= code) {
      final ro = u16(ranges + s * 2);
      if (ro == 0) {
        gid = (code + b.getInt16(deltas + s * 2)) & 0xFFFF;
      } else {
        final at = ranges + s * 2 + ro + (code - u16(starts + s * 2)) * 2;
        gid = u16(at);
        if (gid != 0) gid = (gid + b.getInt16(deltas + s * 2)) & 0xFFFF;
      }
      break;
    }
  }
  expect(gid, isNot(0), reason: '$path has no glyph for $ch');
  expect(gid, lessThan(numGlyphs));
  final off = longLoca ? u32(loca + gid * 4) : u16(loca + gid * 2) * 2;
  final end = longLoca ? u32(loca + gid * 4 + 4) : u16(loca + gid * 2 + 2) * 2;
  if (end <= off) return 0; // an empty glyph, like a space
  return b.getInt16(glyf + off);
}

void main() {
  const stamp = '../assets/fonts/DeskStamp.ttf';
  const noor = '../assets/fonts/NoorHand.ttf';

  test('the stamp face keeps the holes in its letters', () {
    // the letters whose shape *is* the hole
    for (final ch in ['O', 'D', 'P', 'Q', 'R', 'A', '0', '4', '6', '9']) {
      expect(_contours(stamp, ch), greaterThanOrEqualTo(2),
          reason: 'DeskStamp $ch is a solid blob: it has ${_contours(stamp, ch)} contour');
    }
    // and the two-holed ones have two
    for (final ch in ['B', '8']) {
      expect(_contours(stamp, ch), greaterThanOrEqualTo(3),
          reason: 'DeskStamp $ch has ${_contours(stamp, ch)} contours, and it needs three');
    }
  });

  test('so do the hands, which never lost them', () {
    expect(_contours(noor, 'O'), greaterThanOrEqualTo(2));
    expect(_contours(noor, 'B'), greaterThanOrEqualTo(3));
  });
}
