// The icon on the home screen is the app's, not the framework's.
//
// "The app's icon, on the home screen and on every arrival banner, is the unaltered Flutter
// framework logo: app/web/icons/Icon-192.png (md5 ac9a721a12bbc803b44f645561ecb1e1) plus its three
// sibling web icons and all five android mipmaps." It is the one place the app appears when nobody
// has opened it — the service worker draws its notifications with it — and for six cycles it was
// somebody else's mark.
//
// The icons are made by tools/make_icon.py out of the app's own material: a torn note off the same
// stock the thread is written on, masked by one of the same tear masks, on the same desk. This
// holds them to that: not the framework's logo, and not a flat fill either.
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// The framework's own logo, as it shipped in every one of these files. Read out of the commit
/// that carried it, one hash per file, so this cannot pass by hashing the wrong thing.
const _flutter = {
  'ac9a721a12bbc803b44f645561ecb1e1',    // Icon-192.png
  '96e752610906ba2a93c65f8abe1645f1',    // Icon-512.png
  'c457ef57daa1d16f64b27b786ec2ea3c',    // Icon-maskable-192.png
  '301a7604d45b3e739efc881eb04896ea',    // Icon-maskable-512.png
  '5dcef449791fa27946b3d35ad8803796',    // favicon.png
  '6270344430679711b81476e29878caa7',    // mipmap-mdpi
  '13e9c72ec37fac220397aa819fa1ef2d',    // mipmap-hdpi
  'a0a8db5985280b3679d99a820ae2db79',    // mipmap-xhdpi
  'afe1b655b9f32da22f9a4301bb8e6ba8',    // mipmap-xxhdpi
  '57838d52c318faff743130c3fcfae0c6',    // mipmap-xxxhdpi
};

void main() {
  final icons = [
    'web/icons/Icon-192.png',
    'web/icons/Icon-512.png',
    'web/icons/Icon-maskable-192.png',
    'web/icons/Icon-maskable-512.png',
    'web/favicon.png',
    'android/app/src/main/res/mipmap-mdpi/ic_launcher.png',
    'android/app/src/main/res/mipmap-hdpi/ic_launcher.png',
    'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png',
    'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png',
    'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
  ];

  test('no icon is the framework\'s own logo', () {
    for (final path in icons) {
      final f = File(path);
      expect(f.existsSync(), isTrue, reason: '$path is missing');
      final sum = md5.convert(f.readAsBytesSync()).toString();
      expect(_flutter.contains(sum), isFalse, reason: '$path is the Flutter logo');
    }
  });

  test('every icon is a picture of something rather than a fill', () {
    // A PNG of one flat colour compresses to almost nothing. The icon is a photograph of paper on
    // a desk, so it does not.
    for (final path in icons) {
      final size = File(path).lengthSync();
      final side = int.tryParse(RegExp(r'(\d+)').firstMatch(path)?.group(1) ?? '') ?? 48;
      if (side < 32) continue;   // the favicon is sixteen pixels and carries what it can
      expect(size, greaterThan(side * 8),
          reason: '$path is $size bytes at $side px, which is a fill and not a picture');
    }
  });
}
