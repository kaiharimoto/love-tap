// What Us hands out has to be desk that exists.
//
// `shareOfTheDesk` takes the chrome off the slot the shell leaves, gives every module one row of
// itself, and shares the rest by what each module asks for. When the minima came to more than the
// room, it returned them anyway — so the answer to "how much of the desk does this module get" was
// a number bigger than the desk, and the modules at the bottom were drawn off the end of it.
//
// Five modules clear by eight points, which is why nothing showed. Three files — registry.dart,
// us_region.dart and module.dart — say a sixth module is a directory and one line in the registry.
// A sixth costs 82 pt of chrome and its own row, which is 164 pt more desk than there is. So the
// sixth module is built here and measured rather than asserted in a comment.
import 'package:desk/modules/module.dart';
import 'package:desk/modules/registry.dart';
import 'package:desk/spine/event.dart';
import 'package:desk/regions/us/us_region.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// A sixth module: nothing but the two numbers the desk shares by.
class _SixthModule extends Module {
  const _SixthModule();
  @override
  String get id => 'sixth';
  @override
  String get label => 'SIXTH';
  @override
  List<String> get eventTypes => const [];
  @override
  double get rowHeight => 90.0;
  @override
  Widget build(BuildContext context, ModuleContext ctx) => const SizedBox.shrink();
  @override
  String glance(List<Event> events, DateTime now) => 'nothing yet';
}

/// The chrome the region charges, kept here so the test knows the same number the region does.
double _chrome(int modules) => modules * (kUsHeading + kUsSectionGap) + 4 + 8;

void main() {
  // The slot the shell leaves on the phone the capture is shot at, measured in the twelfth
  // capture: a 2340 x 1080 device at 3x is 780 pt tall, less the shell's own chrome.
  const slots = [896.0, 780.0, 640.0, 480.0, 300.0, 120.0, 0.0];

  test('no desk is shared out that the desk does not have', () {
    for (final slot in slots) {
      final shares = shareOfTheDesk(slot);
      final room = slot - _chrome(kModules.length);
      final given = shares.fold<double>(0, (a, b) => a + b);
      expect(given, lessThanOrEqualTo((room < 0 ? 0.0 : room) + 0.01),
          reason: 'at a $slot pt slot the five modules were handed $given pt of a desk with '
              '${room < 0 ? 0 : room} pt left on it');
      expect(shares.every((s) => s >= 0), isTrue, reason: 'a module was given a negative desk');
    }
  });

  test('a sixth module is a directory and one line, and the desk still adds up', () {
    const six = [...kModules, _SixthModule()];
    for (final slot in slots) {
      final shares = shareOfTheDesk(slot, modules: six);
      expect(shares.length, six.length);
      final room = slot - _chrome(six.length);
      final given = shares.fold<double>(0, (a, b) => a + b);
      expect(given, lessThanOrEqualTo((room < 0 ? 0.0 : room) + 0.01),
          reason: 'at a $slot pt slot six modules were handed $given pt of a desk with '
              '${room < 0 ? 0 : room} pt left on it — which is what the old arithmetic did, and it '
              'is why the claim that a sixth module costs one line was never true');
    }
    // and it is on the desk at the size it is shot at, not merely present in the list
    final atCapture = shareOfTheDesk(780, modules: six);
    expect(atCapture.last, greaterThan(0.0),
        reason: 'the sixth module was given none of the desk at the height Us is photographed at');
  });

  test('the share each module asks for is what decides the room left over', () {
    // A tall desk: past the minima, the two that ask for two get twice what the three that ask for
    // one get, and nothing else is in the arithmetic.
    final shares = shareOfTheDesk(2000);
    final over = [
      for (var i = 0; i < kModules.length; i++) shares[i] - kModules[i].rowHeight,
    ];
    final unit = over[kModules.indexWhere((m) => m.share == 1.0)];
    for (var i = 0; i < kModules.length; i++) {
      expect(over[i], closeTo(unit * kModules[i].share, 0.01),
          reason: '${kModules[i].id} asks for ${kModules[i].share} and got ${over[i]} of the '
              'spare desk against $unit for one share');
    }
  });
}
