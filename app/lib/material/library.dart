// What is actually in the baked library. tools/pack_assets.py writes app/assets/INDEX.json when it
// builds the app's copy; this reads it once at startup so the app never guesses at a file name.
import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

class LibraryEntry {
  const LibraryEntry(this.id, this.w, this.h, [this.safe, this.usable = 1.0]);
  final String id;
  final int w;
  final int h;

  /// For a tear mask: how far in from each edge (left, top, right, bottom, as fractions) writing
  /// must sit so the tear cannot cut it. tools/pack_assets.py measures it from the mask itself.
  final List<double>? safe;

  /// How much of the piece is inside that rectangle: a long strip has little, a half sheet a lot.
  final double usable;

  double get aspect => h == 0 ? 1 : w / h;
}

class MaterialLibrary {
  MaterialLibrary._(this.paper, this.tears, this.objects, this.bits, this.shell, this.folds, this.fonts,
      this.sounds, this.shadowFrame);

  final List<LibraryEntry> paper;
  final List<LibraryEntry> tears;
  final List<LibraryEntry> objects;
  final List<LibraryEntry> bits;
  final List<LibraryEntry> shell;

  /// sequence name -> frame count
  final Map<String, int> folds;
  final List<String> fonts;
  final List<String> sounds;

  /// How much wider than the piece the baked contact shadow was framed, straight from
  /// blender/paper/tear_relief.py. The visible part of a contact shadow is the part outside the
  /// paper, so the shadow render reaches past the piece and the app has to inflate it to match.
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
            ))
        .toList();
    final folds = <String, int>{};
    final f = j['folds'];
    if (f is Map) {
      f.forEach((k, v) => folds[k as String] = (v as num).toInt());
    }
    return _instance = MaterialLibrary._(
      family('paper'),
      family('tears'),
      family('objects'),
      family('bits'),
      family('shell'),
      folds,
      ((j['fonts'] as List?) ?? const []).cast<String>(),
      ((j['sound'] as List?) ?? const []).cast<String>(),
      ((j['relief'] as Map?)?['shadow_frame'] as num?)?.toDouble() ?? 1.0,
    );
  }

  /// Whether the dusk half of the library exists at all.
  ///
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

  /// The safe writing insets of a mask (left, top, right, bottom as fractions), or a modest
  /// default when the library has not been baked.
  List<double> safeOf(String tearId) {
    for (final e in tears) {
      if (e.id == tearId) return e.safe ?? const [0.06, 0.07, 0.06, 0.07];
    }
    return const [0.06, 0.07, 0.06, 0.07];
  }

  List<String> get objectIds =>
      objects.map((e) => e.id).where((id) => !id.contains('_shadow')).toList()..sort();

  bool hasObject(String id) => objects.any((e) => e.id == id);

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
