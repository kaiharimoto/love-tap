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


---

## Cycle 3 · firing 2 · IMPLEMENT · 2026-09-16

Seven items closed, and then the container was bootstrapped and the evidence recaptured, so for
the first time in this cycle the artifacts postdate the work they are used to judge.

The lease was taken and pushed before anything else was touched, which is the thing the previous
firing did not do and which cost this build a second worker on one branch.

**What the gate said the first time it was allowed to speak.** `color-palette-floors` was the item
that mattered, because `docs/COLOR.md` had been law with no mechanism since it was written. It has
one now, and against the committed set it exits 1 and names 62 breaches, each carrying the section
it breaches. Not one of them is a ceiling. Every chroma ceiling in §5 passes with room to spare —
nothing in this build is remotely as saturated as a red biro — and the whole failure is absence.
Eight of nine rooms are at an accent fraction of zero. That is the client's "it doesn't evoke
cuteness" with a number under it, and it is a different complaint from the one a ceiling would
catch.

**Building the gate corrected the law.** §4 asks for four families over the union of the set, and a
"family" as `palette.py` computes it is a ten-degree histogram bin. The union of the committed set
is bins 55 through 105 — six of them, every one inside family A, at a gap of 310°. So the floor as
written read 6 ≥ 4 and passed, on the most monochrome build the document was written to describe.
It binds on `named_families` now, which read 1. The bin count stays reported beside it, the way
`legibility.py` keeps `GROUND_PCTL` beside its adversarial reading.

That was found rather than assumed because of `palette_selftest.py`, and the reason that file
exists is worth keeping: the committed set breaches 62 floors, so it cannot tell a gate that is
correctly red from a gate that is red at everything. The self-test builds a still out of flat OKLab
patches that clears every floor, proves `--floors` exits 0 on it, then breaks one quantity at a
time and proves the matching floor comes back. A gate that can never pass is not a gate.

**Two budgets, and the first one was too loose.** `spine-all-in-build` memoises `Spine.all` and
`countOf`, and the obvious budget was one frame — 16000 µs. With the old getters put back, 200
copies of a fourteen-thousand-event year came in *under* it and only the linear scan tripped. A
budget that admits the regression it was written for is worse than none, so it is 2000 µs, which
is twenty times what the memoised path costs and six times below what the old one does. The same
care is why the cache is keyed on a revision counter and not on a length: an outbox event coming
back from the host with its seq moves between the two lists without changing the total.

**The desk retune met its measurement and cost something elsewhere, which is the entry to read.**
The plate came down to its declared flat: day 0.5002 → 0.4007 against `DeskColour.day` 0.3751,
dusk 0.3626 → 0.2595 against 0.2653, both inside 0.05 L, on an exposure change and not a second
light — relative grain moved by four ten-thousandths. Then the capture said what that cost.
`04_moments`' median pixel went 0.5107 → 0.4167 and `10_first_run`'s 0.5129 → 0.4093, while
`17_setup_pwa` has no desk in it and stayed at 0.9470, so `lightness_drift_room` went 0.4363 →
0.5377 against a ceiling of 0.20. `14_media_viewer` went 54% → 65% of runs below floor, and a dusk
plate 1.44 stops darker is the first place to look.

None of that is a reason to undo it. Those two screens are mostly desk, which is the entire content
of `paper-is-the-median-pixel`, and that item's note predicted the coupling before the render
happened. But a firing that reports the plate landing on its target and not the drift widening has
reported half a measurement.

Two things moved the right way for free. `04_moments`' mid band went 0.0249 → 0.1707 and now clears
its floor, and family C registers for the first time, so `named_families` went 1 → 2 and the unioned
hue gap went 310° → 150°, which is §4's ceiling exactly. Nothing this cycle added any colour, so
that is a darker ground letting the printed blue rules carry area they always had. It is also a
warning: half of `families-b-c-and-d-reach-the-glass` arrived as a side effect nobody designed, and
the other half — B and D — is still at zero area on every still.

**Legibility, overall:** 329 of 848 runs below floor → 206 of 743, 38.8% → 27.7%. `02_chat` 31% →
11%, `12_search` 20% → 9%, `01_pulse` 40% → 26%. `17_setup_pwa` is still the one screen with no
desk in it and still the one with no failures in it, which has now been true for three captures and
is the whole argument of `paper-is-the-median-pixel` in one line.

**Two claims the repository was making that were not true.** `tools/check/texture_budget.py` did not
exist, though `DIRECTION.md` said it enforced the budget; it exists now, and writing it found that
the figures `TASK_STATE.md` recorded under the words "measured rather than guessed" described a
sequence that is not in this repository — 150 frames at 460×405 against an actual 240 at 490×315.
And `evidence/haptics.json` did not exist at all, so the one channel the brief cares most about had
no record of any kind. It has one now: 34 feelings, duration, envelope and a strip you can read in
a diff, held to the app by a Dart test that checks every segment against the parser the app plays.

That test earned its place twice before it was committed. The first Python parser lost `steady` and
`hold` to a lazy `.*?` under DOTALL running past the end of a row; the second lost `overwhelmed` and
`grey` by cutting each row at its first `)`, which falls inside `(60@70 off60) ×8`. Both wrote a
file that looked complete and was short by two, and neither would have been noticed by reading it.

**What the next firing should expect.** Four items open, and the stage stays IMPLEMENT because only
a drained queue advances it. `paper-is-the-median-pixel` is first and is now the largest single
number on the board: it owns the whole of the 0.5377 room drift and both of the two worst screens.
`one-coloured-thing-per-screen` and the B and D half of `families-b-c-and-d` are untouched and are
the colour half of the owner's complaint. `surfaces-folds-family` wants a re-render of
`blender/folds/fold.py`, and `06_unfolding.mp4` is recorded missing on its frame check for exactly
that reason.

The evidence is fresh as of this firing, so those three can be worked and measured without a
capture first. The toolchain is not: a fresh container has none, and `bash tools/apt-prereqs.sh`
before `./bootstrap.sh --profile=web` is about twenty minutes before anything can be built.
