# JOURNAL — one block per firing

A firing appends here. Nothing is edited in place; a wrong entry is corrected by a later one that
says so. This is the prose record of what the loop actually did, as distinct from `loop/STATE.json`,
which is what the loop believes right now.

## Firing 1 · cycle 3 · DESIGN · 2026-09-15

Step 0 passed on the first try. `git push --dry-run` returned `Everything up-to-date`, which is the
first firing of this loop that has been able to say so — the two before it were minted by a Routine,
got `sources: []`, and had no push credential at all. The orchestrator commit that landed alongside
this one, `47f29b9`, is the fix for that, and it arrived while this firing was working. It did not
touch `loop/STATE.json`, so the lease held and the two did not collide; the colour-law commit was
rebased onto it, unpushed and therefore no rewrite of pushed history.

The stage ran as `docs/LOOP.md` specifies: a fresh-context subagent briefed as a senior art director
and colour specialist, given the nine stills, the 300% crops, `legibility.json`, `palette.json`, the
brief and the owner's own words, and **not** given `DIRECTION.md` until it had written its law and
formed its verdict. That withholding earned its keep twice over, and the second time is the more
interesting: reading `DIRECTION.md` afterwards did not overturn the law, it revealed that almost
every failure in the evidence is the build having drifted *away* from a rule `DIRECTION.md` already
had. Dimming was forbidden in four words — "Never a dim overlay" — and shipped anyway. The blue
rules and the red pen are in the declared palette and never reached the glass. "Each region is a
different stack of paper on it" was already there, and the build became a plank with a note in the
middle of it. The law this build needed was mostly the law it already had, minus the numbers. That
is the whole argument for a file that carries them.

Three things this firing checked rather than accepted.

The first was a trap `docs/CONTINUE.md` §5 warns about by name: a stale render looks exactly like a
design decision. `assets/shell/desk.png` *did* change after the stills were captured — different
blobs, `e430f9ff` against `17971cbf` — so the verdict was at risk of condemning a desk that no longer
exists. Both blobs were extracted and measured: L mean 0.4846 against 0.4839, grain sd 0.0444
against 0.0464, chroma 0.0346 against 0.0344. Re-encoded, not re-rendered. The desk in the evidence
is the desk in the repository and the verdict is safe. That measurement went to the subagent
mid-flight and is quoted in §1.

The second was the briefing itself, and the subagent corrected it. This firing handed over the
received claim that `17_setup_pwa.png` is the one still with no desk in it. The pixels say 25.7% of
its frame *is* desk. What it has is a desk with no words on it. That correction is the verdict: the
thing that correlates with 404 failures is desk **area**, at r = 0.87, not desk **presence**. A
premise stated confidently in the prompt was wrong, and the stage caught it because it was told to
look before it believed. Worth remembering the next time a firing writes a brief.

The third was the arithmetic. Every constant in `docs/COLOR.md` was re-derived from source before
the file was committed — the six ink lightnesses, `Pen.red` at chroma 0.1553 as the ceiling anchor,
`Paper.legal` at 0.0805, the accent chromas — and all of them matched. So did the load-bearing
result: 4.5:1 against the plank's grain at Y 0.1467 requires a darker ink at Y **−0.006**. Not a hard
number to hit. A number that does not exist. No ink of any colour has ever been able to be legible
on this desk, which is why `Pen.onWood` was never a tuning problem, and why the law forbids the case
instead of adjusting the pair.

**Verdict: keep and retune.** Not replace, and the reason is that all three measured causes would
follow a replacement surface across unchanged — the 0.120 L drift between the render and the flat
it was tuned against, the 1.62:1 internal contrast that any textured ground has, and the fact that
the desk is the *most* chromatic band in the build. The app is grey because the paper is grey.
Swapping the wood would spend the migration and leave the owner's second complaint exactly where it
was found. Nothing under `assets/` is deleted, so the migration constraint never bound.

On that second complaint, the number is worse than the prose suggested. Six of the nine stills
contain **zero** pixels a colorimeter would call coloured. Across nine full-resolution screenshots
there are about 550 of them, 0.006% of what was sampled. And the colour was designed and then never
spent: `docs/FEELINGS.md` already declares 21 distinct colours across six hue families with a widest
gap of 132°. The palette that is written down covers the wheel; the one that ships is a wedge fifty
degrees across. So `docs/COLOR.md` invents no colour — it requires the ones the build already owns to
carry area, and for the first time states a chroma **floor** as well as a ceiling. The build has been
paying a legibility bill and a charm bill to buy a restraint it already had for free: it passes every
ceiling with room to spare.

One number in the law is a judgment and is labelled as one: the dusk floors of 5.0 and 4.5, set from
WCAG's flare constant overstating dark-pair contrast, because the evidence set holds one dusk still
and it is a crop. §6 names the capture that would settle it.

No amendment to the brief's anti-goals was requested, and the reasoning is recorded: every floor set
here is a floor on *area*, not on saturation, and none asks for anything more saturated than
`Pen.red`, which the brief already names.

Left for the next firing, which is IMPLEMENT: 17 open items, led by the two that change no pixels.
`palette.py` has carried no pass/fail floor since it was written because its docstring declined to
invent one until `docs/COLOR.md` declared one. It does now.

Two things the next firing should not have to rediscover. `docs/BRIEF.md` §05 has no `visual_design`
row — that sixth row lives in `tools/score.py`, added at firing 0, and the brief still reads as five
categories out of 100 while the loop scores six out of 120. And `Desk` paints its plate with
`repeat: ImageRepeat.repeatY`, which is a tiled repeating texture; the anti-goal's wording is
"standing in for paper" and a desk is not paper, so §9 reads it as out of scope, but it is exactly
what a fresh-context anti-goal critic will find, and it is better answered than discovered.

## Firing 2 · cycle 3 · IMPLEMENT · 2026-09-16

The owner asked for the work to be implemented and released so they could test it. Six queue items
closed, all of them the legibility half. The charm half was not started, and the number says so:
mean chroma across the set is 0.0236 against a floor of 0.045, and it moved *down* from 0.025.
Anyone reading this and about to report that cycle 3 fixed what the owner complained about should
read that sentence again. The owner said two things.

Three things cost this firing real time and all three are worth writing down.

**`bootstrap.sh` could not complete in a fresh container.** It checked for a python module named
`skia_pathops`, which is the distribution name; what pip puts on the path is `pathops`, which is
what `tools/handwriting/build.py` imports. So bootstrap died on a package that was installed and
working, and no firing before this one had a toolchain.

**The first capture produced 0 of 17 and took forty minutes doing it.** Every scene reported
`browserType.launch:` with an empty message after it, which reads like a broken harness. Calling
`webkit.launch()` by hand printed what the harness had swallowed: `libevent-2.1-7t64` and
`libwayland-server0`. `CLAUDE.md` has said from the beginning that `tools/apt-prereqs.sh` is the
difference between a capture and nothing here, and it was right; the list was two packages short.
What `capture.sh` did under that failure is the reason it is trustworthy: it refused to count the
stills already on disk, named each with the time it was actually written, and wrote 0 of 17. A
harness that counted them would have reported 14 of 17 and a clean diff, and this firing would
have claimed the colour work was verified against artifacts that predate it by a day.

**The widget guard passed while two whole sections were unreadable.** `05_settings.png` came back
with the four facts about the two phones, the export line and the authored feelings written on the
wood at about one to one, and `no_word_is_written_on_the_desk_test.dart` was green. The test
viewport is 480 by 1040 logical pixels and `SettingsRegion` is a lazy `ListView`: everything below
the fold had never been built. A guard over a scrolling region that does not scroll is a guard over
its first screenful. It scrolls now, and re-breaking it names exactly the text that is invisible in
the committed still.

The media viewer is the one to learn from, because the first fix made it worse and the measurement
is the only reason that was known. Its scrim was 0xCC over near-black, which put the desk at OKLab
L 0.198 -- below dusk's 0.265 -- and body text at 1.43:1. Lightening it to 0x80 put the desk at
0.268, which was the stated goal, and the next capture went from 25 of 40 runs below floor to 56 of
66. The darkness had been hiding that the route is not opaque: behind a translucent barrier is the
live chat screen, and the still came back with the note's text showing through itself twice and
`put it back` sitting on top of the composer. A scrim was the wrong instrument in both directions.
The viewer now brings its own desk at the dusk condition and nothing shows through it.
`DIRECTION.md` has said "never a dim overlay" in four words since the beginning.

The law was wrong about one thing and implementing it is what found it. Section 2 put every ink at
OKLab L <= 0.40 and section 10's table then checked five inks and quietly omitted the sixth.
`Pen.red` is L 0.494, and forcing it down takes its chroma from 0.1553 to 0.1215 -- while section 5
anchors the entire `figure` chroma ceiling *on red's 0.1553*. The rule as written would have
destroyed the number the next rule depends on. The ceiling now binds by what the ink is for, and
section 2 carries the amendment with the measurement that forced it, which is what the freeze rule
requires of a reversal.

Where it got to: 495 of 834 runs below floor at the start of the cycle, 329 of 848 now, 14 of 17
artifacts, 100 tests passing against 94. `02_chat` went from 92 of 139 to 33 of 105, which is the
composer coming off the wood and is the largest single thing in the cycle. `17_setup_pwa` is still
0 of 89 and its worst run improved from 4.5 to 7.98.

Left for the next firing: `color-palette-floors` first, because `palette.py` still has no
`--floors` and a law with no gate is prose. Then the two charm items, which are the half of the
owner's complaint nobody has started. Four clips still fail their frame checks, which is why this
run was 14 of 17 rather than better, and that was not looked at.

A release the owner can install on an Android phone is still blocked on them: four signing secrets
only they can set. `tools/pack_pwa.py` is named by the workflow's guard and does not exist, and it
is not a missing script -- nothing in the app sets `pwaRoot`, so serving the PWA from the phone is
an unfinished feature. A web build was made and handed over instead.

