// A ritual kept, in the thread: the name in the hand, and a tally stroke for the keeping.
//
// A tally and not a number: the marks a person makes beside a habit, counted how many times and
// never how many in a row. There is no streak here to break.
import 'package:flutter/material.dart';

import '../../material/hands.dart';
import '../../material/palette.dart';
import '../../spine/spine.dart';
import '../../thread/note_body.dart';

Widget tallyMark(NoteContext c) {
  final p = c.event.payload;
  final n = ((p['streak'] as num?) ?? (p['count'] as num?) ?? 1).toInt().clamp(1, 7);
  return Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(child: Written('${p['title'] ?? ''}', by: c.event.author, size: 17)),
      const SizedBox(width: 8),
      SizedBox(
        width: 6.0 * n + 8,
        height: 18,
        child: CustomPaint(
          painter: _Tally(n, c.event.author == Person.noor ? Pen.ballpoint : Pen.graphite),
        ),
      ),
      const SizedBox(width: 6),
      Stamped('kept', size: 9, colour: Pen.margin),
    ],
  );
}

class _Tally extends CustomPainter {
  const _Tally(this.n, this.colour);
  final int n;
  final Color colour;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colour
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < n; i++) {
      final x = 4.0 + i * 6.0;
      final lean = (i % 2 == 0 ? 0.6 : -0.4);
      canvas.drawLine(Offset(x + lean, 2), Offset(x - lean, size.height - 2), paint);
    }
    if (n >= 5) {
      canvas.drawLine(
        Offset(1, size.height - 4),
        Offset(4.0 + 5 * 6.0 - 2, 3),
        paint..strokeWidth = 1.3,
      );
    }
  }

  @override
  bool shouldRepaint(_Tally old) => old.n != n || old.colour != colour;
}

String ritualSentence(Event e) => '${e.payload['title']} · kept';
