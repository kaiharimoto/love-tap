# An experiment, not a capture

Nine records here belong to one experiment run on 2026-09-11 between 16:59 and 17:08, not to any
capture. They sat in `evidence/logs/` beside the capture's own records, and a messenger critic
caught exactly what that costs: "the numbers that say the scroll is cheap belong to no artifact in
the set" — they were written after `MANIFEST.json`, so nothing in the manifest's `checks` list
accounts for them, and a reader had no way to tell an experiment's records from a run's.

## What was asked

Whether the hands' contextual alternates were what made the scroll expensive. Three cycles had
blamed the scroll on something and been wrong twice, and the alternates were the third guess. A
test had been read as ruling them out — a note of handwriting shaped in 0.074 ms — but that test
runs under `flutter test`, which passes `--use-test-fonts --disable-asset-fonts`, so it laid every
paragraph out in a font with nothing to shape and could not have seen this whatever the answer was.

## How

Two builds of the same commit, one with `--dart-define=PLAIN_FONTS=true` (`Flags.plainFonts`,
which is never set in a build anybody uses), and the same fling shot against each:

- `11_alternates.*` and `scroll_webkit_alternates.json` — the hands as they ship.
- `11_plain.*` and `scroll_webkit_plain.json` — the same hands with `calt` off.

## What it said

`what_the_alternates_cost.json` holds the comparison. The alternates cost the scroll nothing, so
the guess was wrong and the search went on; what it did find is in the eleventh capture's own
`scroll_webkit.json` — sixty paper pieces rebuilt on every fourth frame, which is the positioned
list re-anchoring and a `LayoutBuilder` on the hot path.
