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
  Future<Uint8List> loadBytes(String path) async {
    // The asset's own bytes, not the buffer they sit in. On the web an asset loaded from the
    // bundle is a view into a larger buffer, and `.buffer.asUint8List()` hands back all of it
    // from byte zero: every photograph in the seeded year went into the store as some other
    // region of memory, decoded as nothing, and Moments was a wall of blank prints.
    final d = await bundle.load(path);
    return d.buffer.asUint8List(d.offsetInBytes, d.lengthInBytes);
  }
}
