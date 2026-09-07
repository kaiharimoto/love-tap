// One line of a module, on the shared desk.
//
// Us puts five modules on one desk. Measured at the width the shell leaves and with the seeded
// year's own events, one row of each module costs 216, 143, 102, 242 and 157 points — 860 in all,
// against the 884 the shell leaves once the five headings are taken off it. Five cards do not fit
// on one desk, and the desk was showing two of them and calling the other three present.
//
// So on the desk a module is a line: the thing, and one short word about it in the margin. The
// card is what you get when you open the module on its own, which is the same distinction a desk
// makes — the top line of each pile is what you can see, and you pick one up to read it.
import 'package:flutter/material.dart';

import '../material/assignment.dart';
import '../material/hands.dart';
import '../material/palette.dart';
import '../material/slip.dart';

class DeskLine extends StatelessWidget {
  const DeskLine({
    super.key,
    required this.id,
    required this.row,
    required this.text,
    required this.type,
    this.aside,
    this.lead,
    this.struck = false,
    this.onTap,
  });

  final String id;
  final int row;

  /// What the thing is, in the couple's own words.
  final String text;

  /// The event type this line stands for. The paper comes from the type, through the same
  /// assignment the thread and Moments use — a module that names its own stock disagrees with the
  /// thread about what the event is, and one_kind_of_paper_per_kind_of_event_test says so.
  final String type;

  /// One short thing in the margin: when, how many, who has it.
  final String? aside;

  /// A mark in front of the line — a box, a tally, a stamp.
  final Widget? lead;
  final bool struck;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 2, 16, 2),
        child: Slip(
          id: id,
          row: row,
          stock: stockForType(type),
          padding: const EdgeInsets.fromLTRB(12, 7, 12, 8),
          onTap: onTap,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (lead != null) ...[lead!, const SizedBox(width: 8)],
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Hands.margin(size: 16).copyWith(
                    color: struck ? Pen.margin : Pen.graphite,
                    decoration: struck ? TextDecoration.lineThrough : null,
                    decorationColor: Pen.margin,
                  ),
                ),
              ),
              if (aside != null) ...[
                const SizedBox(width: 10),
                Text(aside!, maxLines: 1, style: Hands.margin(size: 12.5).copyWith(color: Pen.margin)),
              ],
            ],
          ),
        ),
      );
}
