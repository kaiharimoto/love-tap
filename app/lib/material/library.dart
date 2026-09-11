// What is actually in the baked library. tools/pack_assets.py writes app/assets/INDEX.json when it
// builds the app's copy; this reads it once at startup so the app never guesses at a file name.
import 'dart:convert';

import 'package:flutter/painting.dart' show Rect, Size;
import 'package:flutter/services.dart' show AssetBundle, rootBundle;

class LibraryEntry {
  const LibraryEntry(this.id, this.w, this.h, [this.safe, this.usable = 1.0, this.tear]);
  final String id;
  final int w;
  final int h;

  /// For a tear mask: how far in from each edge (left, top, right, bottom, as fractions) writing
  /// must sit so the tear cannot cut it. tools/pack_assets.py measures it from the mask itself.
  final List<double>? safe;

  /// How much of the piece is inside that rectangle: a long strip has little, a half sheet a lot.
  final double usable;

  /// For a tear mask: how far in the tear actually eats on each side (left, top, right, bottom, as
  /// fractions) — the band a nine-patch must keep at its rendered size instead of stretching.
  ///
  /// Not the same question as [safe], which asks where writing can go and answers with the largest
  /// rectangle entirely inside the paper. This asks where the fibres are. They were the same
  /// number — a flat four tenths for every mask and every side — and a material critic measured
  /// what that costs: the four widest pieces in 02_chat had edges at 0.78 to 1.01 px rms against
  /// the masks' own 2.417, because the top band of a nine-patch is pulled across the whole width
  /// of the piece and fibres stretched four times are below what a high-pass can see.
  final List<double>? tear;

  double get aspect => h == 0 ? 1 : w / h;
}

class MaterialLibrary {
  MaterialLibrary._(this.paper, this.tears, this.objects, this.bits, this.shell, this.folds,
      this.ink, this.foldSize, this.objectInk, this.objectShadow, this.fonts, this.sounds,
      this.shadowFrame);

  final List<LibraryEntry> paper;
  final List<LibraryEntry> tears;
  final List<LibraryEntry> objects;
  final List<LibraryEntry> bits;
  final List<LibraryEntry> shell;

  /// The coverage plates: how much ink reached the paper, one per pen. Tiled under a letter's own
  /// alpha, so a stroke is not one flat value from end to end. tools/ink_plate.py makes them.
  final List<LibraryEntry> ink;

  /// sequence name -> frame count
  final Map<String, int> folds;

  /// sequence name -> the shape one frame is, so a note can take up its room before it has one
  final Map<String, Size> foldSize;

  /// object id -> the box its ink actually fills, as fractions of its own frame.
  ///
  /// Every object is rendered into the same square, and how much of it the thing fills is a
  /// property of the thing: a candle's ink is 27 per cent of its frame and a paper crane's is 85.
  /// Without this, `size: 96` meant a different physical size for every feeling.
  final Map<String, Rect> objectInk;

  /// Per shadow file: how much wider its frame is than the object's own box, and where the frame's
  /// centre sits, in units of that box. A shadow is longer than the thing casting it and falls the
  /// other way at dusk, so each shadow is packed in its own frame rather than the object and the
  /// shadow sharing one that is half empty whichever is being drawn.
  final Map<String, List<double>> objectShadow;
  final List<String> fonts;
  final List<String> sounds;

  /// How much wider than the piece the baked contact shadow was framed, straight from
  /// blender/paper/tear_relief.py.
  ///
  /// Read, kept, and no longer what places the shadow. Inflating by this alone put the render's
  /// own paper edge at 0.986 of a piece box whose paper — nine-sliced to fill it — ends at 1.0, so
  /// the whole penumbra was drawn under opaque paper. `PaperPiece._bakedShadow` maps the render by
  /// the rect its paper occupies instead, which is what makes the part outside the paper land
  /// outside the paper.
  final double shadowFrame;

  static MaterialLibrary? _instance;
  static MaterialLibrary get instance {
    final i = _instance;
    if (i == null) throw StateError('MaterialLibrary.load() has not run');
    return i;
  }

  static bool get loaded => _instance != null;

  static Future<MaterialLibrary> load({AssetBundle? bundle}) async {
    final b = bundle ?? rootBundle;
    Map<String, dynamic> j;
    try {
      j = jsonDecode(await b.loadString('assets/INDEX.json')) as Map<String, dynamic>;
    } catch (_) {
      j = const {};
    }
    List<LibraryEntry> family(String name) => ((j[name] as List?) ?? const [])
        .map((e) => LibraryEntry(
              (e as Map)['id'] as String,
              (e['w'] as num).toInt(),
              (e['h'] as num).toInt(),
              (e['safe'] as List?)?.map((x) => (x as num).toDouble()).toList(),
              (e['usable'] as num?)?.toDouble() ?? 1.0,
              (e['tear'] as List?)?.map((x) => (x as num).toDouble()).toList(),
            ))
        .toList();
    final folds = <String, int>{};
    final f = j['folds'];
    if (f is Map) {
      f.forEach((k, v) => folds[k as String] = (v as num).toInt());
    }
    // the shape of one frame, so a note about to open can take up the room it is going to take up
    // before the first frame has decoded
    final foldSize = <String, Size>{};
    final fs = j['fold_size'];
    if (fs is Map) {
      fs.forEach((k, v) {
        if (v is List && v.length == 2) {
          foldSize[k as String] = Size((v[0] as num).toDouble(), (v[1] as num).toDouble());
        }
      });
    }
    final objectInk = <String, Rect>{};
    final oi = j['object_ink'];
    if (oi is Map) {
      oi.forEach((k, v) {
        if (v is List && v.length == 4) {
          objectInk[k as String] = Rect.fromLTRB(
            (v[0] as num).toDouble(), (v[1] as num).toDouble(),
            (v[2] as num).toDouble(), (v[3] as num).toDouble(),
          );
        }
      });
    }
    final objectShadow = <String, List<double>>{};
    final os = j['object_shadow'];
    if (os is Map) {
      os.forEach((k, v) {
        if (v is List && v.length == 3) {
          objectShadow[k as String] = [for (final n in v) (n as num).toDouble()];
        }
      });
    }
    return _instance = MaterialLibrary._(
      family('paper'),
      family('tears'),
      family('objects'),
      family('bits'),
      family('shell'),
      folds,
      family('ink'),
      foldSize,
      objectInk,
      objectShadow,
      ((j['fonts'] as List?) ?? const []).cast<String>(),
      ((j['sound'] as List?) ?? const []).cast<String>(),
      ((j['relief'] as Map?)?['shadow_frame'] as num?)?.toDouble() ?? 1.0,
    );
  }

  /// Whether the dusk half of the library exists at all.
  ///
  /// The pixel size of a paper stock, or null if the library has never heard of it.
  Size? stockSize(String id) {
    for (final e in paper) {
      if (e.id == id) return Size(e.w.toDouble(), e.h.toDouble());
    }
    return null;
  }

  /// The desk, the paper and every baked shadow were rendered under two conditions, and the app
  /// shows one of them at a time. A build lit at dusk with only the daylight paper baked would put
  /// a lamp on the desk and leave the notes in the afternoon — contact shadows disagreeing about
  /// where the light is, which is the first thing anyone looking for faked material checks. Not
  /// being dusk yet is honest; being half of each is not.
  bool get hasDusk => paper.any((e) => e.id.endsWith('_dusk'));

  // ---- paper stocks --------------------------------------------------------------------------
  /// Ids of a stock's variants under a light condition, e.g. stockVariants('lined') ->
  /// [lined_01, lined_02, …]; dusk variants carry the _dusk suffix.
  List<String> stockVariants(String stock, {bool dusk = false}) {
    final want = RegExp('^${RegExp.escape(stock)}_\\d+${dusk ? '_dusk' : ''}\$');
    return paper.map((e) => e.id).where(want.hasMatch).toList()..sort();
  }

  List<String> get stocks {
    final names = <String>{};
    for (final e in paper) {
      final m = RegExp(r'^(.*)_\d+(_dusk)?$').firstMatch(e.id);
      if (m != null) names.add(m.group(1)!);
    }
    return names.toList()..sort();
  }

  bool get hasPaper => paper.isNotEmpty;

  LibraryEntry? entry(List<LibraryEntry> family, String id) {
    for (final e in family) {
      if (e.id == id) return e;
    }
    return null;
  }

  // ---- tears ---------------------------------------------------------------------------------
  /// Mask ids only (tear_001), not their edge or shadow renders.
  List<String> get tearMasks =>
      tears.map((e) => e.id).where((id) => !id.contains('_edge') && !id.contains('_shadow')).toList()..sort();

  /// Masks with room to write on: a note goes on one of these, a stamp or a strip can use any.
  List<String> get writableTears {
    final ok = tears
        .where((e) => !e.id.contains('_edge') && !e.id.contains('_shadow') && e.usable >= 0.5)
        .map((e) => e.id)
        .toList()
      ..sort();
    return ok.isEmpty ? tearMasks : ok;
  }

  bool hasTearRender(String id, String suffix) => tears.any((e) => e.id == '$id$suffix');

  /// Masks that are roughly as tall as they are wide: a scrap rather than a strip. A feeling that
  /// is a drawn mark is drawn on one of these, because ink has to be on something.
  List<String> get scrapTears {
    final ok = <String>[];
    for (final e in tears) {
      if (e.id.contains('_edge') || e.id.contains('_shadow')) continue;
      final w = e.w, h = e.h;
      if (w <= 0 || h <= 0) continue;
      final ratio = h / w;
      if (ratio > 0.72 && ratio < 1.4) ok.add(e.id);
    }
    ok.sort();
    return ok.isEmpty ? tearMasks : ok;
  }

  /// The safe writing insets of a mask (left, top, right, bottom as fractions), or a modest
  /// default when the library has not been baked.
  List<double> safeOf(String tearId) {
    for (final e in tears) {
      if (e.id == tearId) return e.safe ?? const [0.06, 0.07, 0.06, 0.07];
    }
    return const [0.06, 0.07, 0.06, 0.07];
  }

  /// The band of a tear render that is fibre rather than paper, per side, or null for a library
  /// packed before it was measured. Takes an id or an asset path.
  List<double>? tearBandOf(String assetOrId) {
    final id = assetOrId.split('/').last.replaceAll('.webp', '');
    for (final e in tears) {
      if (e.id == id) {
        final t = e.tear;
        return (t != null && t.length == 4) ? t : null;
      }
    }
    return null;
  }

  List<String> get objectIds =>
      objects.map((e) => e.id).where((id) => !id.contains('_shadow')).toList()..sort();

  bool hasObject(String id) => objects.any((e) => e.id == id);

  /// How much the render has to be scaled for [size] to mean the object rather than its frame.
  /// 1.0 when nothing is known about it, which is what it did before.
  double inkScaleOf(String id) {
    final box = objectInk[id];
    if (box == null) return 1.0;
    final fill = box.width > box.height ? box.width : box.height;
    if (fill <= 0.05) return 1.0;
    return (1.0 / fill).clamp(1.0, 3.4);
  }

  bool hasObjectShadow(String id, {bool dusk = false}) =>
      objects.any((e) => e.id == '${id}_shadow${dusk ? '_dusk' : ''}');
}

/// Asset paths (all WebP after packing).
String paperAsset(String id) => 'assets/paper/$id.webp';
String tearAsset(String id) => 'assets/tears/$id.webp';
String objectAsset(String id) => 'assets/objects/$id.webp';
String bitAsset(String id) => 'assets/bits/$id.webp';
String shellAsset(String id) => 'assets/shell/$id.webp';
String foldFrameAsset(String seq, int frame) => 'assets/folds/$seq/${frame.toString().padLeft(4, '0')}.webp';
String soundAsset(String id) => 'assets/sound/$id.ogg';
