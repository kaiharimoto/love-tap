// Built-ins plus every feeling_authored event in the spine, in one list. Nothing downstream
// asks whether a feeling is built in: the sender, the thread, notifications, Moments and search
// all read this.
import '../spine/event.dart';
import 'builtins.dart';

class FeelingRegistry {
  FeelingRegistry(List<Event> events) {
    _all.addAll(kBuiltInFeelings);
    for (final e in events) {
      if (e.type != 'feeling_authored') continue;
      final p = e.payload;
      final f = Feeling(
        id: p['feeling_id'] as String,
        name: p['name'] as String,
        family: FamilyName.parse(p['family'] as String),
        object: p['object_asset'] as String,
        haptic: p['haptic'] as String,
        sound: p['sound'] as String,
        colour: p['colour'] as String,
        authoredBy: e.author.name,
        retired: p['retired'] == true,
      );
      final i = _all.indexWhere((x) => x.id == f.id);
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

  List<Feeling> family(Family fam) => active.where((f) => f.family == fam).toList();
}
