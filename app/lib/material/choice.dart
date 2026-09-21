// A word you are choosing between, and the mark that says which one is chosen.
//
// THE OWNER'S ORIGINAL COMPLAINT, in one rendering rule. Every picker in the app encoded
// `unchosen` as alpha: the interrupt matrix at 0x80 over `Pen.margin`, the mood picker and the
// family picker at 0x99. That is twenty-eight runs on 05_settings.png at 2.42-2.54:1 and nine on
// 01_pulse.png at 2.70-3.51:1, against a 4.5 floor — and it means two thirds of each screen's
// interactive vocabulary is the faintest thing on it, with the words a person is choosing between
// all harder to read than the one they have already chosen. docs/COLOR.md section 6 has said since
// it was written that an ink carrying a word composites at alpha >= 0.80, and nothing enforced it.
//
// A choice is not a brightness. Both words are written in full-strength ink; which one is chosen
// is said by a mark — the underline that was already there, and a pencil tick after it — and by
// the chosen one being in somebody's own pen rather than in the margin's pencil. Three signals,
// none of them a fade, and the unchosen word is as legible as the chosen one because it is the
// one you are being asked to read.
import 'package:flutter/widgets.dart';

import 'assignment.dart';
import 'hands.dart';
import 'marks.dart';
import 'palette.dart';

class Choice extends StatelessWidget {
  const Choice({
    super.key,
    required this.label,
    required this.chosen,
    required this.onTap,
    this.size = 15,
    this.chosenInk = Pen.ballpoint,
    this.ink = Pen.margin,
  });

  final String label;
  final bool chosen;
  final VoidCallback onTap;
  final double size;

  /// The pen the chosen one is written in. Both this and [ink] are inks: docs/COLOR.md's ladder
  /// puts every one of them at OKLab L <= 0.40, so either clears the body floor on every stock.
  final Color chosenInk;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final colour = chosen ? chosenInk : ink;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Hands.margin(size: size).copyWith(
              color: colour,
              decoration: chosen ? TextDecoration.underline : null,
            ),
          ),
          if (chosen) ...[
            SizedBox(width: size * 0.24),
            // The seed is the label's, so a given option's tick is the same tick every time it is
            // drawn rather than a different hand on every rebuild.
            // `hashOf`, not `hashCode`: the comment above is only true within one platform,
            // because a Dart string hash is not the same number in a browser as on the phone.
            Mark.tick(size: size * 0.78, colour: colour, seed: hashOf(label) & 0x7fff),
          ],
        ],
      ),
    );
  }
}
