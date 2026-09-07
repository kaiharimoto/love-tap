// A line off the list, in the thread: a box drawn in pencil, ticked when it was done, and the
// line struck through when it came off. Nothing is ever overdue and nothing is ever failed.
import 'package:flutter/material.dart';

import '../../material/hands.dart';
import '../../material/marks.dart';
import '../../material/palette.dart';
import '../../spine/spine.dart';
import '../../thread/note_body.dart';

Widget listLine(NoteContext c) {
  final p = c.event.payload;
  final action = '${p['action']}';
  final done = action == 'done';
  final gone = action == 'removed';
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 3, right: 9),
        child: SizedBox(
          width: 16,
          height: 16,
          child: Stack(
            children: [
              const Positioned.fill(child: CustomPaint(painter: _PencilBox())),
              if (done)
                Positioned(
                  left: 1,
                  top: -4,
                  child: Mark.tick(
                    size: 18,
                    colour: c.event.author == Person.noor ? Pen.ballpoint : Pen.graphite,
                  ),
                ),
            ],
          ),
        ),
      ),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${p['text'] ?? ''}',
              style: Hands.of(c.event.author, size: 17).copyWith(
                decoration: gone ? TextDecoration.lineThrough : null,
                decorationColor: Pen.margin,
                decorationThickness: 1.4,
              ),
            ),
            Text(switch (action) {
              'done' => 'done',
              'reopened' => 'back on the list',
              'removed' => 'off the list',
              'assigned' => p['assignee'] == null ? 'passed over' : 'for ${p['assignee']}',
              _ => 'put down',
            }, style: Hands.margin(size: 11.5)),
          ],
        ),
      ),
    ],
  );
}

class _PencilBox extends CustomPainter {
  const _PencilBox();
  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(0.8, 0.8, size.width - 1.6, size.height - 1.6);
    final path = Path()
      ..moveTo(r.left, r.top + 0.6)
      ..lineTo(r.right - 0.4, r.top)
      ..lineTo(r.right, r.bottom - 0.5)
      ..lineTo(r.left + 0.5, r.bottom)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = Pen.margin
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );
  }

  @override
  bool shouldRepaint(_PencilBox old) => false;
}

/// What was done to the list, in the words a person would use about their own list.
///
/// These are the module's own five actions — the ones `projectTodos` folds and the ones
/// docs/EVENT_TYPES.md declares. The words here were `ticked`/`unticked`/`dropped` for most of
/// this build, which the module has never written: they came from a table shared with the dates
/// module and nobody had checked them against either module's vocabulary. Ninety-five of the
/// seeded year's hundred and ninety-nine list events are `done`, and every one of them read as
/// its own text with a space in front of it — in search, in a notification, and on the lock
/// screen. The fall-through says something rather than nothing for the same reason.
String todoVerb(Object? action) => switch ('$action') {
      'added' => 'put down',
      'done' => 'done:',
      'reopened' => 'back on the list:',
      'removed' => 'off the list:',
      'assigned' => 'passed over:',
      _ => 'on the list:',
    };

String todoSentence(Event e) {
  final assignee = e.payload['assignee'];
  final tail = e.payload['action'] == 'assigned' && assignee != null ? ' · for $assignee' : '';
  return '${todoVerb(e.payload['action'])} ${e.payload['text']}$tail';
}
