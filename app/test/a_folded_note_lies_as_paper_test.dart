// An unopened note of theirs lies in the thread as the paper it is written on, folded.
//
// Until firing 59 it lay there as frame zero of the fold sequence: `FoldedNote` drew
// `Unfolding(autoplay: false)` as its resting face, and frame zero of `assets/folds/unfold_thirds`
// is a square-cornered cream slab with a hard uniform shadow -- no tear, no stock, and no entry in
// the surfaces sidecar, because `_FramePainter` is not a piece of paper. Five critics at cycle 3
// found it in 13_messenger_states and called it the brief's anti-goal by name. It was not a clip
// standing still; it was what every unread note looked like to the person holding the phone.
//
// Re-break by putting `Unfolding(seq: widget.seq, width: widget.width, autoplay: false)` back as
// the resting face in `_FoldedNoteState._face`, and watch `lies as its own torn sheet` fail.

import 'package:desk/material/fold.dart';
import 'package:desk/material/library.dart';
import 'package:desk/material/paper.dart';
import 'package:desk/regions/chat/note.dart';
import 'package:desk/scope.dart';
import 'package:desk/spine/projections/thread.dart';
import 'package:desk/spine/seed_loader.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/transport/local/local_transport.dart';
import 'package:desk/transport/sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppScope scope;
  String? absent;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    try {
      await MaterialLibrary.load();
    } catch (_) {
      absent = 'this bundle was packed without a material library '
          '(tools/pack_assets.py --seed=year puts it in)';
      return;
    }
    final spine = await Spine.open(
      SpineStore.memory(),
      const Identity(person: Person.teo, device: DeviceKind.pwa),
    );
    await SeedLoader(rootBundle).load(spine);
    final transport = LocalTransport(role: TransportRole.client, spine: spine, deviceId: 'test');
    scope = AppScope(
      spine: spine,
      transport: transport,
      sync: SyncEngine(spine: spine, transport: transport),
      clock: Clock(frozenAt: DateTime.utc(2026, 9, 3, 19, 40)),
    );
  });

  tearDown(Folds.reset);

  /// A message of theirs with words on it, and a read marker just below it, so it lies folded.
  (ThreadItem, int, int) theirs() {
    final items = scope.thread.items;
    final it = items.lastWhere((i) =>
        i.event.author != scope.me &&
        i.type == 'message' &&
        (i.text ?? '').length > 12 &&
        !i.deleted);
    final unreadFrom = (it.event.seq ?? 1) - 1;
    expect(noteLiesFolded(it, me: scope.me, unreadFrom: unreadFrom), isTrue,
        reason: 'the scenario has to contain a folded note or nothing below measures anything');
    return (it, items.indexOf(it), unreadFrom);
  }

  Future<void> pumpNote(WidgetTester tester, ThreadItem it, int row, int unreadFrom,
      {VoidCallback? onOpened}) async {
    await tester.pumpWidget(AppScope.provide(
      scope: scope,
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 380,
              child: Note(
                item: it,
                row: row,
                unreadFrom: unreadFrom,
                registry: scope.feelings,
                onLongPress: () {},
                onOpened: onOpened,
              ),
            ),
          ),
        ),
      ),
    ));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    }
  }

  testWidgets('an unopened note lies as its own torn sheet, not as a frame of the fold',
      (tester) async {
    if (absent != null) {
      markTestSkipped(absent!);
      return;
    }
    final (it, row, unreadFrom) = theirs();
    await pumpNote(tester, it, row, unreadFrom);

    final folded = find.byType(FoldedNote);
    expect(folded, findsOneWidget);
    expect(find.descendant(of: folded, matching: find.byType(Unfolding)), findsNothing,
        reason: 'at rest the note must not draw the fold sequence: its frame zero is the blank card');

    final pieces = tester
        .widgetList<PaperPiece>(find.descendant(of: folded, matching: find.byType(PaperPiece)))
        .toList();
    expect(pieces, hasLength(1), reason: 'the resting face is one sheet of paper');
    final face = pieces.single;
    expect(face.tearId, isNotNull, reason: 'a folded note is a torn sheet, not a square card');
    expect(MaterialLibrary.instance.paper.map((p) => p.id), contains(face.stockId),
        reason: 'and it is torn from a stock in the library');
    expect(face.id, it.event.id,
        reason: 'the surfaces sidecar can name the row it is, as the open note does');

    // Its writing stays inside it until it is opened: the read marker waits on this row.
    expect(find.descendant(of: folded, matching: find.textContaining(it.text!)), findsNothing);
  });

  testWidgets('touching it plays the fold, and the writing arrives after', (tester) async {
    if (absent != null) {
      markTestSkipped(absent!);
      return;
    }
    final (it, row, unreadFrom) = theirs();
    var opened = 0;
    await pumpNote(tester, it, row, unreadFrom, onOpened: () => opened++);
    await tester.tap(find.byType(FoldedNote));
    await tester.pump();
    expect(find.byType(Unfolding), findsOneWidget, reason: 'a touch starts the sequence');
    expect(opened, 0, reason: 'tapping is a commitment to open, not having read it');
  });
}
