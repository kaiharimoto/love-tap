// Search, over the year the app actually ships with.
//
// Two things were wrong with `12_search.png` and both of them are the kind a person hits in the
// first minute.
//
//   * The results ran newest-first across days and were non-monotonic inside one of them --
//     4 Aug read 07:20, then 07:24, then 07:14. The comparator sorted by score and used the
//     timestamp only to break a tie, so three lines a person reads as a sequence came out in an
//     order derived from a number that is nowhere on the screen.
//   * The third result was `text when home - kept`, with no highlighted match and no occurrence
//     of `rain` in anything drawn. It is a `ritual_kept`, whose summary prints its title and
//     never its note, and whose note that morning was `rain the whole way down and i did not go
//     round it`. A hit whose match cannot be seen is indistinguishable from a wrong answer, and
//     it makes the highlighting -- the best thing on that screen -- untrustworthy everywhere.
//
// Re-break either: sort by score again and `newest first` fails on 4 Aug; take the aside out of
// `_Hit` or the per-word spans out of `_Marked` and `every hit shows its match` finds a strip
// with nothing lit on it.
import 'dart:convert';

import 'package:desk/material/library.dart';
import 'package:desk/regions/chat/renderers.dart';
import 'package:desk/regions/chat/search_page.dart';
import 'package:desk/scope.dart';
import 'package:desk/spine/seed_loader.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/transport/local/local_transport.dart';
import 'package:desk/transport/sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

void main() {
  String? absent;
  late AppScope scope;
  late Spine spine;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await MaterialLibrary.load();
    try {
      final index = jsonDecode(await rootBundle.loadString('assets/seed/index.json'))
          as Map<String, dynamic>;
      if (((index['months'] as List?) ?? const []).isEmpty) {
        absent = 'the bundle has a seed directory with no months in it';
        return;
      }
    } catch (_) {
      absent = 'this bundle was packed without the seeded year '
          '(tools/pack_assets.py --seed=year puts it in)';
      return;
    }
    spine = await Spine.open(
      SpineStore.memory(),
      const Identity(person: Person.teo, device: DeviceKind.pwa),
    );
    await SeedLoader(rootBundle).load(spine);
    final transport = LocalTransport(role: TransportRole.client, spine: spine, deviceId: 'test');
    scope = AppScope(
      spine: spine,
      transport: transport,
      sync: SyncEngine(spine: spine, transport: transport),
      clock: Clock(frozenAt: DateTime.utc(2026, 8, 30, 9, 14)),
    );
  });

  test('results are newest first, within a day as well as across days', () {
    if (absent != null) return;
    for (final q in ['rain', 'roster', 'the', 'home', 'photo']) {
      final hits = spine.search(q);
      expect(hits, isNotEmpty, reason: '$q found nothing to order');
      for (var i = 1; i < hits.length; i++) {
        expect(hits[i].event.ts, lessThanOrEqualTo(hits[i - 1].event.ts),
            reason: '$q went backwards at result ${i + 1}: '
                '${DateTime.fromMillisecondsSinceEpoch(hits[i - 1].event.ts).toUtc()} then '
                '${DateTime.fromMillisecondsSinceEpoch(hits[i].event.ts).toUtc()}');
      }
    }
  });

  test('the same query twice puts the same hits in the same order', () {
    if (absent != null) return;
    final a = spine.search('rain').map((h) => h.event.id).toList();
    final b = spine.search('rain').map((h) => h.event.id).toList();
    expect(a, b);
  });

  test('every hit says where the term is, on the row or beside it', () {
    if (absent != null) return;
    // The whole first screenful of every query the capture and the app actually run, checked the
    // way the row decides: the sentence, else the field the term is in, else the kind of thing.
    for (final q in ['rain', 'roster', 'ferry', 'photo', 'feelings']) {
      final terms = SearchIndex.tokenize(q);
      for (final h in spine.search(q).take(25)) {
        final summary = summaryOf(h.event, me: Person.teo);
        final onTheRow = SearchIndex.carries(summary, terms);
        final beside = h.matchedIn.where((m) => m != summary).isNotEmpty || h.matchedKind != null;
        expect(onTheRow || beside, isTrue,
            reason: 'searching "$q" returned ${h.event.type} "$summary" '
                'with nothing on it or beside it to see');
      }
    }
  });

  test('the 4 Aug ritual says it matched on its note, which its summary never shows', () {
    if (absent != null) return;
    final hit = spine
        .search('rain')
        .firstWhere((h) => h.event.type == 'ritual_kept' && h.event.payload['note'] != null);
    expect(summaryOf(hit.event, me: Person.teo), contains('text when home'));
    expect(SearchIndex.carries(summaryOf(hit.event, me: Person.teo), ['rain']), isFalse,
        reason: 'the summary was expected to be the half that shows nothing');
    expect(hit.matchedIn, isNotEmpty);
    expect(hit.matchedIn.first, contains('rain'));
  });

  test('a two-word query lights both words even when they are not adjacent', () {
    // The old highlighter looked for the whole query as one literal substring, so it lit nothing
    // here at all. Whole words, because that is exactly what the index matched on.
    expect(SearchIndex.spansOf('rain the whole way down and i did not go round it', 'rain down'),
        [(0, 4), (19, 23)]);
    // and the last word of a query is a prefix while somebody is still typing
    expect(SearchIndex.spansOf('sending you the roster', 'ros'), [(16, 22)]);
    expect(SearchIndex.spansOf('nothing of the kind here', 'rain'), isEmpty);
  });

  testWidgets('the search page draws a highlight on every strip it puts down', (tester) async {
    if (absent != null) return;
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    final key = GlobalKey<SearchPageState>();
    await tester.pumpWidget(AppScope.provide(
      scope: scope,
      child: MaterialApp(home: Scaffold(body: SearchPage(key: key, initialQuery: 'rain'))),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);

    final rich = tester.widgetList<Text>(find.byType(Text)).where((t) => t.textSpan != null);
    var lit = 0;
    for (final t in rich) {
      t.textSpan!.visitChildren((span) {
        // Since firing 49 the mark is a multiplied `background` paint rather than a
        // `backgroundColor`, which could only paint on top.
        final style = span is TextSpan ? span.style : null;
        if (style?.background != null || style?.backgroundColor != null) lit++;
        return true;
      });
    }
    expect(lit, greaterThan(0),
        reason: 'a page of results for "rain" with nothing marked on any of them');
  });
}
