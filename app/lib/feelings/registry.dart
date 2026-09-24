// Built-ins plus every feeling_authored event in the spine, in one list. Nothing downstream
// asks whether a feeling is built in: the sender, the thread, notifications, Moments and search
// all read this.
import '../spine/event.dart';
import 'builtins.dart';
import 'drawn.dart';

class FeelingRegistry {
  FeelingRegistry(List<Event> events) {
    _all.addAll(kBuiltInFeelings);
    for (final e in events) {
      if (e.type != 'feeling_authored') continue;
      final p = e.payload;
      final id = p['feeling_id'] as String;
      final i = _all.indexWhere((x) => x.id == id);
      final f = Feeling(
        id: id,
        name: p['name'] as String,
        family: FamilyName.parse(p['family'] as String),
        object: p['object_asset'] as String,
        haptic: p['haptic'] as String,
        sound: p['sound'] as String,
        colour: p['colour'] as String,
        // Whoever made it first. A later event renames, recolours or puts it away, and either of
        // them can write that one; it does not make the feeling theirs.
        authoredBy: i >= 0 && _all[i].authoredBy != null ? _all[i].authoredBy : e.author.name,
        retired: p['retired'] == true,
      );
      if (i >= 0) {
        _all[i] = f; // a later feeling_authored (rename, recolour, retire) replaces the earlier one
      } else {
        _all.add(f);
      }
    }
  }

  final List<Feeling> _all = [];

  /// byId is the hottest call in the app — the thread asks it once a row, the fan once a feeling
  /// — and it was a linear walk of every feeling either of them has ever made, which cost most on
  /// the misses. _all is fixed once the constructor has run, so this is built once and asked.
  Map<String, Feeling>? _index;
  Map<String, Feeling> get _byId => _index ??= {for (final f in _all) f.id: f};

  List<Feeling> get all => List.unmodifiable(_all);
  List<Feeling> get active => _all.where((f) => !f.retired).toList();
  Feeling? byId(String id) => _byId[id];

  /// Where a feeling sits among the vocabulary's DRAWN marks, retired ones included, so that it
  /// keeps its place when another is put away. Only a drawn mark is laid on a scrap, so only they
  /// are counted: a grid of the vocabulary passes this as the object's row, and every drawn mark
  /// in it then takes a different scrap (see `scrapFor`) whichever family tab or sheet it is on,
  /// and the same one on both phones. Counting every feeling instead spread nine marks over 35
  /// rows, which the scrap pool then folds back onto itself.
  Map<String, int>? _rows;
  int rowOf(Feeling f) => (_rows ??= () {
        final rows = <String, int>{};
        for (final g in _all) {
          if (DrawnFeelingMark.has(g.object)) rows[g.id] = rows.length;
        }
        return rows;
      }())[f.id] ?? 0;

  List<Feeling> family(Family fam) => active.where((f) => f.family == fam).toList();
}
