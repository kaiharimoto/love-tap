import 'dart:io';
import 'dart:typed_data';

import 'package:desk/material/library.dart';
import 'package:desk/material/paper.dart';
import 'package:desk/spine/seed_loader.dart';
import 'package:desk/spine/spine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _OffDisk implements SeedSource {
  _OffDisk(this.root);
  final String root;
  @override
  Future<String> loadString(String path) async => File('$root/$path').readAsStringSync();
  @override
  Future<Uint8List> loadBytes(String path) async => File('$root/$path').readAsBytesSync();
}

void main() {
  testWidgets('what a fresh mask costs to compose', (tester) async {
    await MaterialLibrary.load();
    final lib = MaterialLibrary.instance;
    await tester.runAsync(() async {
      final mask = await MaskCache.load(tearAsset(lib.writableTears.first));
      final sw = Stopwatch()..start();
      for (var i = 0; i < 8; i++) {
        SlicedMasks.at('probe$i', mask, Size(340, 100.0 + i * 20), 3.0);
      }
      sw.stop();
      debugPrint('SlicedMasks.at fresh: ${(sw.elapsedMicroseconds / 8000).toStringAsFixed(1)} ms a piece');
      final sw2 = Stopwatch()..start();
      for (var i = 0; i < 8; i++) {
        SlicedMasks.at('probe$i', mask, Size(340, 100.0 + i * 20), 3.0);
      }
      sw2.stop();
      debugPrint('SlicedMasks.at cached: ${(sw2.elapsedMicroseconds / 8000).toStringAsFixed(3)} ms a piece');
    });
  });

  test('what a sync round walks', () async {
    final spine = await Spine.open(SpineStore.memory(),
        const Identity(person: Person.teo, device: DeviceKind.pwa));
    await SeedLoader(_OffDisk(Directory.current.path)).load(spine);
    debugPrint('spine ${spine.length} events');
    for (var round = 0; round < 3; round++) {
      final a = Stopwatch()..start();
      final missing = await spine.missingBlobs();
      a.stop();
      final b = Stopwatch()..start();
      final push = spine.pushable.length;
      b.stop();
      debugPrint('round $round: missingBlobs ${a.elapsedMilliseconds} ms (${missing.length} wanted), '
          'pushable ${b.elapsedMilliseconds} ms ($push)');
    }
  });
}
