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
  final done = action == 'ticked';
  final gone = action == 'dropped';
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
              'ticked' => 'done',
              'unticked' => 'back on the list',
              'dropped' => 'off the list',
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
String todoVerb(Object? action) => switch ('$action') {
  'added' => 'put down',
  'ticked' => 'done:',
  'unticked' => 'back on the list:',
  'dropped' => 'off the list:',
  _ => '',
};

String todoSentence(Event e) => '${todoVerb(e.payload['action'])} ${e.payload['text']}';
