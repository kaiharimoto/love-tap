// The ink plate: how much of each stroke actually reached the paper.
//
// A critic eroded every letter to its core and found three grey values, two thirds of them the
// same one. That is what a font drawn in a flat colour measures as, and it is the whole difference
// between writing and printing: a ballpoint skips and pools, a pencil takes the tops of the fibres
// and misses the pits. Nothing here changes a letter's shape — a coverage field is tiled under the
// text and multiplied into its alpha, so a stroke arrives unevenly the way a stroke does.
//
// The plate is anchored to the text it covers, not to the screen. A shader in screen coordinates
// would let the pattern crawl across the letters as the thread scrolls, which is worse than flat
// ink: ink belongs to the letter. A ShaderMask paints in its own layer's coordinates, so the
// coverage moves with the words.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'library.dart';

/// The plates, decoded once. Null until [load] has run, and null forever on a build with no ink
/// packed — in which case the text is drawn exactly as it was before, flat.
class InkPlates {
  static final Map<String, ui.Image> _plates = {};
  static bool _loading = false;

  static ui.Image? of(String pen) => _plates[pen];

  static bool get ready => _plates.isNotEmpty;

  /// Decodes the packed plates. Safe to call more than once.
  static Future<void> load() async {
    if (_loading || !MaterialLibrary.loaded) return;
    _loading = true;
    for (final entry in MaterialLibrary.instance.ink) {
      final pen = entry.id.startsWith('plate_') ? entry.id.substring(6) : entry.id;
      try {
        final data = await rootBundle.load('assets/ink/${entry.id}.webp');
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final frame = await codec.getNextFrame();
        _plates[pen] = frame.image;
      } catch (_) {
        // no plate for this pen: its text is drawn flat, which is what it was
      }
    }
  }
}

/// How large one tile of the plate is on the page, in logical pixels. Small enough that the
/// variation happens inside a letter rather than across a paragraph; large enough that a stroke
/// crosses several of the plate's own pixels and is not stippled.
const double kInkTileLogicalPx = 46;

double _k(ui.Image plate) => kInkTileLogicalPx / plate.width;

/// Text with the pen's coverage multiplied into it.
class Inked extends StatelessWidget {
  const Inked({super.key, required this.pen, required this.child});

  /// 'ballpoint' or 'graphite'.
  final String pen;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final plate = InkPlates.of(pen);
    if (plate == null) return child;
    return ShaderMask(
      // dstIn keeps the letter's colour and takes its alpha from the plate: where the pen laid
      // less down, less of the letter arrives. srcIn would paint the plate instead of the words.
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => ui.ImageShader(
        plate,
        TileMode.repeated,
        TileMode.repeated,
        (Matrix4.identity()..scaleByDouble(_k(plate), _k(plate), 1, 1)).storage,
      ),
      child: child,
    );
  }
}
