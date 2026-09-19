// A feeling with no rendered object is still a mark.
//
// In crops/15_authored_feeling_strip.png the authored feeling `pigeon` arrives as a blank sheet
// carrying its name and nothing else, while every built-in beside it in the fan has its object on
// it. The row requires authored feelings to behave identically to built-ins in every path, and
// they do -- `objectLanding` is the renderer for `feeling` whoever made it, and the registry hands
// back built-ins and authored ones in one list with nothing downstream asking which is which.
// What differed was that the seeded year's two authored feelings name objects nobody has baked
// (`obj_user_pigeon`, `obj_user_soup`), and `objects.dart` has had an answer for that since it was
// written: a scribble in the feeling's own colour, drawn by hand, never a system glyph.
//
// It had never drawn a pixel. `CustomPaint` with no child and no `size` lays out at `Size.zero`,
// so the one thing standing between a feeling with no baked object and an empty sheet of paper
// was a widget of no size.
//
// Re-break by taking `size: Size.infinite` off `_Fallback` and watching the mark go back to
// nothing at all.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:desk/feelings/builtins.dart';
import 'package:desk/feelings/drawn.dart';
import 'package:desk/feelings/registry.dart';
import 'package:desk/material/library.dart';
import 'package:desk/material/objects.dart';
import 'package:desk/regions/chat/renderers.dart';
import 'package:desk/spine/spine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const Feeling _authored = Feeling(
  id: 'pigeon',
  name: 'pigeon',
  family: Family.mischief,
  object: 'obj_user_pigeon', // nobody has baked this, and nobody on a phone can
  haptic: '30@200 off80 30@200',
  sound: 'snd_user_pigeon',
  colour: '#3a3a3c',
  authoredBy: 'noor',
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await MaterialLibrary.load();
  });

  /// How many pixels of the drawn square are not the colour of the corner of it. A blank sheet
  /// answers zero; a mark of any kind answers more.
  Future<int> markedPixels(WidgetTester tester, Feeling f) async {
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFFFFFFFF),
        body: Center(
          child: RepaintBoundary(
            key: key,
            child: FeelingObject(feeling: f, size: 128, onPaper: false),
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    late int marked;
    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final bytes = Uint8List.view(data!.buffer);
      final background = bytes.sublist(0, 4);
      var n = 0;
      for (var i = 0; i < bytes.length; i += 4) {
        if (bytes[i] != background[0] ||
            bytes[i + 1] != background[1] ||
            bytes[i + 2] != background[2] ||
            bytes[i + 3] != background[3]) {
          n++;
        }
      }
      marked = n;
    });
    return marked;
  }

  testWidgets('a feeling whose object was never baked is drawn, not left blank', (tester) async {
    final n = await markedPixels(tester, _authored);
    expect(n, greaterThan(200),
        reason: 'the authored feeling is a blank square, which on the artifact is a blank sheet '
            'of paper with only its name under it');
  });

  testWidgets('and so is a built-in, through the same widget', (tester) async {
    // A built-in whose object is a drawn mark rather than a rendered one, because a widget test
    // has no decoded images in it: `Image.asset` resolves nothing here, so a built-in with a
    // baked object measures zero in this harness and says nothing about the app. What this holds
    // is that the one widget marks the paper for a built-in as well as for an authored feeling;
    // that a baked object arrives on the sheet is what the capture measures.
    final builtIn = kBuiltInFeelings.firstWhere((f) => DrawnFeelingMark.has(f.object));
    expect(await markedPixels(tester, builtIn), greaterThan(200));
  });

  test('an authored feeling takes the same path through the app as a built-in', () async {
    // Not a claim about widgets that happen to look alike: the registry holds one list, and the
    // thread asks the registry for the renderer by event type, so there is no branch to differ.
    final spine = await Spine.open(
        SpineStore.memory(), const Identity(person: Person.teo, device: DeviceKind.pwa));
    await spine.append('feeling_authored', {
      'feeling_id': 'pigeon',
      'name': 'pigeon',
      'family': 'Mischief',
      'colour': '#3a3a3c',
      'object_asset': 'obj_user_pigeon',
      'haptic': '30@200 off80 30@200',
      'sound': 'snd_user_pigeon',
      'retired': false,
    }, hostAssign: true);
    final registry = FeelingRegistry(spine.all);
    final authored = registry.byId('pigeon')!;
    final builtIn = registry.byId(kBuiltInFeelings.first.id)!;
    expect(authored.runtimeType, builtIn.runtimeType);
    expect(registry.active, contains(authored));
    expect(kThreadRenderers[kEventTypeById['feeling']!.renderer], same(objectLanding),
        reason: 'the thread draws a feeling through one renderer whoever made it');
    await spine.close();
  });
}
