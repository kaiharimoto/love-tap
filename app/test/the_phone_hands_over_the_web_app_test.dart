// The iPhone installs the client by opening the Android phone's address in Safari, so the Android
// phone has to hold the page it hands over. It did not: `pwaRoot` — a directory beside the process
// — was passed only by the capture's far phone under `dart run`, the app passed nothing, and
// `_serveStatic` answered 404 to every GET while the setup list ticked a step telling a person to
// open that address. Nothing failed anywhere; there was simply nothing at the other end.
//
// The bundle is packed in two halves — the page and the engine into Android's own assets, the
// material library left to this build's own `flutter_assets` — and this is the join between the
// two layouts. A wrong answer here is a blank screen on the other phone rather than an error
// anywhere, so it is tested rather than read.
import 'package:desk/transport/pwa_assets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('what the phone looks up for a request', () {
    test('the root of the origin is the page', () {
      expect(pwaPathFor('/'), 'index.html');
      expect(pwaPathFor(''), 'index.html');
      expect(pwaPathFor('/push/'), 'push/index.html');
    });

    test('a file is itself', () {
      expect(pwaPathFor('/main.dart.js'), 'main.dart.js');
      expect(pwaPathFor('/canvaskit/canvaskit.wasm'), 'canvaskit/canvaskit.wasm');
      expect(pwaPathFor('/push/sw.js'), 'push/sw.js');
      expect(pwaPathFor('/icons/Icon-192.png'), 'icons/Icon-192.png');
    });

    test('a path with a space in it survives the url', () {
      expect(pwaPathFor('/assets/assets/seed/a%20name.webp'), 'assets/assets/seed/a name.webp');
    });

    test('nothing walks out of the bundle', () {
      expect(pwaPathFor('/../../etc/passwd'), isNull);
      expect(pwaPathFor('/canvaskit/../../secret'), isNull);
      expect(pwaPathFor('/%2e%2e/%2e%2e/etc/passwd'), isNull);
      expect(pwaPathFor(r'/canvaskit\..\secret'), isNull);
      expect(pwaPathFor('//double'), 'double');
      expect(pwaPathFor('/a//b'), isNull);
    });
  });

  group('which half of the build answers', () {
    test('the material library is the app\'s own, packed once', () {
      expect(sharedAssetFor('assets/assets/paper/index_02.webp'), 'assets/paper/index_02.webp');
      expect(sharedAssetFor('assets/assets/tears/w_014.webp'), 'assets/tears/w_014.webp');
      expect(sharedAssetFor('assets/assets/seed/year/log.jsonl'), 'assets/seed/year/log.jsonl');
    });

    test('the page, the engine and the manifests come out of the packed half', () {
      // Not assets/assets/, so not this build's own: these are the web build's own copies and
      // tools/pack_pwa.py puts them in Android's assets.
      expect(sharedAssetFor('index.html'), isNull);
      expect(sharedAssetFor('main.dart.js'), isNull);
      expect(sharedAssetFor('canvaskit/canvaskit.wasm'), isNull);
      expect(sharedAssetFor('assets/AssetManifest.bin.json'), isNull);
      expect(sharedAssetFor('assets/FontManifest.json'), isNull);
      expect(sharedAssetFor('assets/NOTICES'), isNull);
      expect(sharedAssetFor('assets/packages/cupertino_icons/assets/CupertinoIcons.ttf'), isNull);
    });
  });
}
