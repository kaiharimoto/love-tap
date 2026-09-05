// The seed read out of the app's own asset bundle: the one SeedSource the app itself uses. It is
// the only file on the seed path that imports Flutter, so the loader can also be held by a plain
// Dart program reading the same files off disk.
import 'dart:typed_data';

import 'package:flutter/services.dart' show AssetBundle;

import 'seed_loader.dart';

class BundleSeedSource implements SeedSource {
  const BundleSeedSource(this.bundle);
  final AssetBundle bundle;

  @override
  Future<String> loadString(String path) => bundle.loadString(path);

  @override
  Future<Uint8List> loadBytes(String path) async => (await bundle.load(path)).buffer.asUint8List();
}
