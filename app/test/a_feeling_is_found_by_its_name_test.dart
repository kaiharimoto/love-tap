// A feeling is findable by what it is called and what family it is in — including the ones the
// couple made up.
//
// docs/EVENT_TYPES.md has promised search "by feeling, by its name, by family" for the feeling and
// reaction rows since the registry was written. A code critic found neither word indexed: the
// index carried the raw `feeling_id`, so a search for `mischief` found nothing and a search for
// `nyeh` found everything. Names and families went in for the built-ins — and stopped there,
// because `kBuiltInById` knows the thirty-six the app ships with and nothing about `pigeon`, which
// is exactly the kind a person goes looking for by name.
import 'package:desk/spine/search.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/spine/store/store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Spine spine;
  late SearchIndex index;

  setUp(() async {
    spine = await Spine.open(
      SpineStore.memory(),
      const Identity(person: Person.teo, device: DeviceKind.pwa),
    );
    // one they made up, then a use of it, then one that ships with the app
    await spine.append('feeling_authored', {
      'feeling_id': 'pigeon',
      'name': 'pigeon',
      'family': 'Mischief',
      'colour': '#3a3a3c',
      'object_asset': 'obj_user_pigeon',
      'haptic': '30@200 off80 30@200',
      'sound': 'snd_user_pigeon',
      'retired': false,
    }, at: DateTime.utc(2026, 1, 1), hostAssign: true);
    await spine.append('feeling', {'feeling_id': 'pigeon', 'intensity': 0.7},
        at: DateTime.utc(2026, 2, 1), hostAssign: true);
    await spine.append('feeling', {'feeling_id': 'warm_palm', 'intensity': 0.6},
        at: DateTime.utc(2026, 3, 1), hostAssign: true);
    index = SearchIndex();
    for (final e in spine.all) {
      index.add(e);
    }
  });

  Set<String> found(String q) => index.search(q).map((h) => h.event.type).toSet();
  int hits(String q) => index.search(q).length;

  test('a built-in is found by its name and by its family', () {
    expect(hits('warm palm'), greaterThan(0), reason: 'the name found nothing');
    expect(hits('warmth'), greaterThan(0), reason: 'the family found nothing');
  });

  test('one they made up is found the same way', () {
    expect(hits('pigeon'), greaterThan(0), reason: 'the name found nothing');
    expect(hits('mischief'), greaterThan(0),
        reason: 'the family of an authored feeling found nothing, so only the built-ins are '
            'searchable by family');
  });

  test('and the row it finds is the sending, not only the authoring', () {
    final types = found('mischief');
    expect(types.contains('feeling'), isTrue,
        reason: 'found $types: a search for a family should reach the times it was sent');
  });
}
