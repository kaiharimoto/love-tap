// The library loads in the second widget test in a file as well as the first.
//
// `MaterialLibrary.load()` read `assets/INDEX.json` off `rootBundle`, and `rootBundle` is a
// `CachingAssetBundle`: the first call puts its Future in the bundle's cache and every later call
// awaits that same Future. The first call in a file happens inside the first `testWidgets`'
// fake-async zone, and that zone has stopped by the time the second test runs, so the second
// `await` never returns. What the runner says ten minutes later is `TimeoutException after
// 0:10:00`, naming no bundle, no asset and no library — which is why this cost firing 13 an hour
// and is why the case is held here rather than remembered.
//
// This is the re-break: put the bundle read back at the top of `load()` and the second test below
// hangs until its timeout while the first still passes.
import 'package:desk/material/library.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // No `setUpAll`, no `if (!MaterialLibrary.loaded)` guard, and no shared state between the two:
  // the trap is laid for someone who writes the obvious thing, so the obvious thing is what is
  // tested. The timeout is short because the failure mode is a hang, and a hang that takes ten
  // minutes to report is a hang nobody runs twice.
  testWidgets('the first widget test in a file can load the library', (tester) async {
    await MaterialLibrary.load();
    expect(MaterialLibrary.loaded, isTrue);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('and so can the second, in the same process', (tester) async {
    await MaterialLibrary.load();
    expect(MaterialLibrary.loaded, isTrue);
    expect(MaterialLibrary.instance, isNotNull);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('and the third, which is where a real file would be by now', (tester) async {
    final a = await MaterialLibrary.load();
    final b = await MaterialLibrary.load();
    expect(identical(a, b), isTrue,
        reason: 'the library is decoded once and handed out, not rebuilt per call');
  }, timeout: const Timeout(Duration(seconds: 30)));
}
