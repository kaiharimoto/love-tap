// docs/EVENT_TYPES.md is the table the whole build is described by, and a table that has drifted
// from the code is worse than no table: it is a set of claims a reader has no reason to doubt.
//
// A code critic checked two of its eighteen rows by hand — "the document promises reaction is
// searchable 'by feeling, by family' and feeling 'by feeling, by family, by intensity'; neither
// 'family' nor 'intensity' [is indexed]" — and was right about both. This checks every row that
// makes a mechanically checkable claim, so the next drift is found by the build rather than by a
// reader with an afternoon.
@TestOn('vm')
library;

import 'dart:io';

import 'package:desk/spine/types.dart';
import 'package:flutter_test/flutter_test.dart';

/// The registry table, as {type id: {'payload': ..., 'search': ...}}.
Map<String, Map<String, String>> _table() {
  final lines = File('../docs/EVENT_TYPES.md').readAsLinesSync();
  final rows = <String, Map<String, String>>{};
  for (final line in lines) {
    if (!line.startsWith('|')) continue;
    final cells = line.split('|').map((c) => c.trim()).toList();
    // | # | type | payload | thread rendering | notification | search |
    if (cells.length < 8) continue;  // '' # type payload rendering notification search ''
    // the row number is a number; the header's is the word `#` and the separator's is dashes
    if (!RegExp(r'^\d+$').hasMatch(cells[1])) continue;
    final type = cells[2].replaceAll('`', '');
    if (!RegExp(r'^[a-z_]+$').hasMatch(type)) continue;
    rows[type] = {'payload': cells[3], 'notification': cells[5], 'search': cells[6]};
  }
  return rows;
}

void main() {
  late Map<String, Map<String, String>> table;
  setUpAll(() => table = _table());

  test('the table has a row for every type and no row for anything else', () {
    expect(table.keys.length, greaterThan(15), reason: 'the table did not parse: ${table.keys}');
    final known = {for (final s in kEventTypes) s.id};
    expect(table.keys.toSet().difference(known), isEmpty,
        reason: 'the table has rows the registry does not: '
            '${table.keys.toSet().difference(known)}');
    expect(known.difference(table.keys.toSet()), isEmpty,
        reason: 'the registry has types the table does not: '
            '${known.difference(table.keys.toSet())}');
  });

  test('every payload key the table names is one the type accepts', () {
    for (final s in kEventTypes) {
      // The question mark that marks an optional key is *inside* the backticks — `note?` — and
      // a regex that expected it outside dropped every optional key silently, which is a check
      // that reads a table and asserts nothing about half of it.
      final claimed = RegExp(r'`([a-z_]+)\??`')
          .allMatches(table[s.id]!['payload']!)
          .map((m) => m.group(1)!)
          .toSet();
      final known = {...s.required, ...s.optional};
      expect(claimed.difference(known), isEmpty,
          reason: '${s.id}: the table names ${claimed.difference(known)}, which the type does '
              'not accept (it takes $known)');
    }
  });

  test('a row that says it is excluded from search is', () {
    for (final s in kEventTypes) {
      final says = table[s.id]!['search']!.toLowerCase();
      if (says.contains('excluded')) {
        expect(s.search.excluded, isTrue, reason: '${s.id} says excluded and is indexed');
      } else {
        expect(s.search.excluded, isFalse, reason: '${s.id} is excluded and does not say so');
      }
    }
  });

  test('every text field the search column names is indexed', () {
    // the column is prose, so this checks the words that name a payload key
    for (final s in kEventTypes) {
      if (s.search.excluded) continue;
      final says = table[s.id]!['search']!.toLowerCase();
      for (final key in {...s.required, ...s.optional}) {
        if (!RegExp('\\b$key\\b').hasMatch(says)) continue;
        if (key == 'feeling_id' || key == 'signal') continue; // handled by name, below
        expect(s.search.textFields, contains(key),
            reason: '${s.id}: the table says it is searchable by $key and it is not indexed');
      }
    }
  });

  test('every facet the table implies is a facet the type has', () {
    for (final s in kEventTypes) {
      final says = table[s.id]!['search']!.toLowerCase();
      if (says.contains('media facet')) {
        expect(s.search.facets, contains('media'),
            reason: '${s.id} claims a media facet it does not have');
      }
    }
  });
}
