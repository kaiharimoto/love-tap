// The shared to-do list: lines torn off a list, ticked in the ink of whoever did them. Assigning
// one to the other person is the only thing in the app that makes a sound on their phone without
// being a message, and it is still just an event in the same spine.
import 'package:flutter/material.dart';

import '../../material/assignment.dart';
import '../../material/hands.dart';
import '../../material/palette.dart';
import '../../material/slip.dart';
import '../../spine/spine.dart';
import '../../material/marks.dart';
import '../desk_line.dart';
import '../../thread/note_body.dart';
import '../module.dart';
import 'thread_row.dart';

class TodosModule extends Module {
  const TodosModule();

  @override
  String get id => 'todos';

  @override
  String get label => 'to do';

  @override
  List<String> get eventTypes => const ['todo_event'];

  /// On the desk, a line with a box in front of it and who it is for after it — measured at the width the shell leaves, not guessed.
  @override
  double get rowHeight => 60.0;

  /// What anyone reads standing up.
  @override
  double get share => 2.0;

  @override
  Map<String, ThreadBody> get bodies => const {'list_line': listLine};

  @override
  String? sentence(Event e, String who) => e.type == 'todo_event' ? todoSentence(e) : null;

  @override
  Map<String, String> get stocks => const {'todo_event': 'looseleaf'};

  @override
  Widget build(BuildContext context, ModuleContext ctx) => TodoList(ctx: ctx);

  @override
  String glance(List<Event> events, DateTime now) {
    final all = projectTodos(events).where((t) => !t.removed).toList();
    final open = all.where((t) => !t.done).length;
    if (all.isEmpty) return 'nothing to do';
    if (open == 0) return 'all ${all.length} done';
    return '$open open · ${all.length - open} done';
  }
}

class TodoItem {
  TodoItem(this.id);
  final String id;
  String text = '';
  Person? assignee;
  Person? addedBy;
  Person? doneBy;
  bool done = false;
  bool removed = false;
  int reopened = 0;
  int lastTs = 0;
}

List<TodoItem> projectTodos(List<Event> events) {
  final byId = <String, TodoItem>{};
  for (final e in events) {
    if (e.type != 'todo_event') continue;
    // A projection is handed whatever is in the log, including whatever the other phone
    // sent, so it may not assume a payload is well formed: an event missing the key that
    // identifies it used to take down the whole module and with it the whole screen.
    final id = e.payload['todo_id'] as String?;
    if (id == null) continue;
    final t = byId.putIfAbsent(id, () => TodoItem(id)..addedBy = e.author);
    t.text = (e.payload['text'] as String?) ?? t.text;
    final a = e.payload['assignee'] as String?;
    if (a != null) t.assignee = Person.parse(a);
    switch (e.payload['action'] as String?) {
      case 'done':
        t.done = true;
        t.doneBy = e.author;
      case 'reopened':
        t.done = false;
        t.reopened++;
      case 'removed':
        t.removed = true;
      case 'assigned':
        t.done = false;
    }
    t.lastTs = e.ts;
  }
  return byId.values.where((t) => !t.removed).toList()..sort((a, b) => a.lastTs.compareTo(b.lastTs));
}

class TodoList extends StatelessWidget {
  const TodoList({super.key, required this.ctx});
  final ModuleContext ctx;

  @override
  Widget build(BuildContext context) {
    final items = projectTodos(ctx.events);
    final open = items.where((t) => !t.done).toList();
    final done = items.where((t) => t.done).toList().reversed.toList();
    // On the desk a line off the list is a line: the thing, and who it is for. The full row —
    // the box, the hand, who added it, how many times it has come back — is what it is when the
    // module is opened on its own.
    if (ctx.onTheDesk) {
      return ctx.fit([
        for (final (i, t) in ctx.few(open).indexed)
          DeskLine(
            id: t.id,
            row: i,
            type: 'todo_event',
            text: t.text,
            aside: t.assignee?.name,
            lead: Mark.box(size: 11, colour: Pen.margin, seed: i),
          ),
        if (open.isEmpty)
          const DeskLine(id: 'todos.none', row: 0, type: 'todo_event',
              text: 'nothing to do. suspicious.'),
      ]);
    }
    final rows = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        child: Row(children: [
          const Stamped.onDesk('open', size: 11),
          const Spacer(),
          GestureDetector(onTap: () => _add(context), child: Text('add one', style: Hands.onDesk(size: 15))),
        ]),
      ),
      if (open.isEmpty)
        Padding(padding: const EdgeInsets.all(12), child: Text('nothing to do. suspicious.', style: Hands.margin(size: 15))),
      for (final (i, t) in ctx.few(open).indexed) _Line(item: t, ctx: ctx, row: i),
      const SizedBox(height: 14),
      const Padding(padding: EdgeInsets.fromLTRB(12, 4, 12, 4), child: Stamped('done', size: 11)),
      for (final (i, t) in done.take(30).indexed) _Line(item: t, ctx: ctx, row: open.length + i),
    ];
    return ListView(padding: const EdgeInsets.fromLTRB(4, 4, 4, 90), children: rows);
  }

  Future<void> _add(BuildContext context) async {
    final text = await askOnPaper(
      context,
      id: 'what.needs.doing',
      hint: 'what needs doing',
      hand: Hands.of(ctx.me, size: 19),
    );
    if (text == null || text.trim().isEmpty) return;
    await ctx.emit('todo_event', {
      'todo_id': 'todo_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}',
      'action': 'added',
      'text': text.trim(),
    });
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.item, required this.ctx, required this.row});
  final int row;
  final TodoItem item;
  final ModuleContext ctx;

  @override
  Widget build(BuildContext context) {
    final by = item.doneBy ?? item.addedBy ?? ctx.me;
    return GestureDetector(
      onTap: () => ctx.emit('todo_event', {
        'todo_id': item.id,
        'action': item.done ? 'reopened' : 'done',
        'text': item.text,
      }),
      onLongPress: () => ctx.emit('todo_event', {
        'todo_id': item.id,
        'action': 'assigned',
        'text': item.text,
        'assignee': (item.assignee == ctx.partner ? ctx.me : ctx.partner).name,
      }),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 3, 20, 3),
        child: Slip(
          id: item.id,
          row: row,
          stock: stockForType('todo_event'),
          width: MediaQuery.sizeOf(context).width - 32,
          padding: const EdgeInsets.fromLTRB(13, 8, 13, 8),
          child: Row(
          children: [
            SizedBox(width: 22, child: item.done ? _Tick(by: by) : const SizedBox.shrink()),
            Expanded(
              child: Text(
                item.text,
                style: Hands.of(item.addedBy ?? ctx.me, size: 18).copyWith(
                  decoration: item.done ? TextDecoration.lineThrough : null,
                  color: item.done ? Pen.margin : null,
                ),
              ),
            ),
            if (item.assignee != null) Stamped(item.assignee!.name, size: 9, colour: Pen.margin),
            if (item.reopened > 1)
              Padding(padding: const EdgeInsets.only(left: 6), child: Text('again', style: Hands.margin(size: 12))),
            ],
          ),
        ),
      ),
    );
  }
}

/// A tick in the ink of whoever did it.
class _Tick extends StatelessWidget {
  const _Tick({required this.by});
  final Person by;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(18, 18), painter: _TickPainter(by == Person.noor ? Pen.ballpoint : Pen.graphite));
}

class _TickPainter extends CustomPainter {
  _TickPainter(this.colour);
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = colour
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * 0.12, size.height * 0.52)
      ..lineTo(size.width * 0.42, size.height * 0.82)
      ..lineTo(size.width * 0.92, size.height * 0.16);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_TickPainter old) => old.colour != colour;
}
