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

/// The pen's coverage, as the paint a letter is drawn with.
///
/// The plate used to be a ShaderMask over the words: the letters drawn into a layer, the plate
/// multiplied into that layer in dstIn. It gave the same ink and it cost a compositing layer for
/// every piece of handwriting in the app — and a piece of paper whose subtree needs a layer of its
/// own cannot have its tear drawn straight into the canvas, so every note in the thread fell back
/// to baking its mask into an image on the build thread. That is 189 of 789 frames of a scroll
/// over 400 ms to build, at p95 688, from one widget.
///
/// A glyph run is drawn with a Paint like anything else, so the plate can be that Paint's shader:
/// the pen's colour through a colour filter, the plate's coverage as the alpha. No layer, one draw.
Paint? inkPaint(String pen, Color colour) {
  final plate = InkPlates.of(pen);
  if (plate == null) return null;
  return Paint()
    ..shader = ui.ImageShader(
      plate,
      TileMode.repeated,
      TileMode.repeated,
      (Matrix4.identity()..scaleByDouble(_k(plate), _k(plate), 1, 1)).storage,
    )
    // srcIn keeps the plate's coverage and takes the letter's colour: where the pen laid less
    // down, less of the letter arrives.
    ..colorFilter = ColorFilter.mode(colour, BlendMode.srcIn);
}

/// Text with the pen's coverage multiplied into it.
///
/// Kept for whatever is not a single run of text in one colour — a widget rather than a style.
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
