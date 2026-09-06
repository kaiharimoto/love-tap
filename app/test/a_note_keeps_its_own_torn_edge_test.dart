// The same note is the same piece of paper wherever you meet it.
//
// A torn edge was chosen by the row index alone, which fails in both directions. A surface that
// draws every row at index zero gave every piece the same edge — a completeness pass measured one
// mask repeated twelve times down the search results, which is the tiled-texture failure the
// anti-goal forbids. And the same event torn one way in search and another way in the thread said
// the two surfaces were looking at different paper.
import 'package:desk/material/assignment.dart';
import 'package:desk/material/library.dart';
import 'package:desk/spine/event.dart';
import 'package:flutter_test/flutter_test.dart';

Event _at(String id) => Event(
      id: id, seq: 1, author: Person.noor, device: DeviceKind.android,
      ts: DateTime.utc(2026, 4, 22).millisecondsSinceEpoch,
      type: 'message', payload: const {'text': 'x'},
    );

void main() {
  // the library is read off the bundle, which needs the binding up even for a plain test
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await MaterialLibrary.load();
  });

  test('a note has the same edge whatever row it is drawn in', () {
    final lib = MaterialLibrary.instance;
    final e = _at('00035DFJ2RVAY9KNK0GR8WXBBN');
    final edges = {for (var row = 0; row < 12; row++) tearFor(e, lib, row: row)};
    expect(edges.length, 1, reason: 'one note came out with ${edges.length} different edges');
    expect(edges.first, isNotNull);
  });

  test('a screen that draws every row at one index still gets many edges', () {
    final lib = MaterialLibrary.instance;
    // what a search result list does: twelve different events, all at row zero
    final ids = [
      for (var i = 0; i < 12; i++) '00035DFJ2RVAY9KNK0GR8WXBB${String.fromCharCode(65 + i)}',
    ];
    final edges = [for (final id in ids) tearFor(_at(id), lib, row: 0)];
    final distinct = edges.toSet().length;
    expect(distinct, greaterThanOrEqualTo(8),
        reason: 'twelve notes on one screen shared their edges down to $distinct: $edges');
  });
}
