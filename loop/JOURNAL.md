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

**Correction, firing 3, on the direction of the legibility number.** This entry's commit subject —
*"the half of the measurement that went the wrong way"* — reads, next to the two percentages below,
as though legibility regressed. It did not, and a firing that stops at the subject line will get
this backwards. Legibility improved, and it is the one number in this build that has moved the
right way at every capture: **48.4% → 38.8% → 27.7%** of text runs below floor (404 of 834, then
329 of 848, then 206 of 743). 27.7% is the current reading and it is the best this build has ever
measured. `evidence/legibility.json` holds it: `total_runs` 743, `total_below_floor` 206, and the
per-artifact shares in it match this entry's pair by pair.

What *did* go the wrong way is two named things, neither of them the overall share, and both of
them already written up under the desk-retune heading below: `lightness_drift_room` 0.4363 → 0.5377
against a 0.20 ceiling, and `14_media_viewer` 54% → 65% of runs below floor, with `05_settings` flat
at 43% → 44%. Those are the cost the retune paid, they are the content of
`paper-is-the-median-pixel`, and they are what the subject line meant.

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

## Cycle 3 · firing 3 · IMPLEMENT · 2026-09-16

The lease was taken and pushed before anything was touched. The container was fresh, so
`tools/apt-prereqs.sh`, `bootstrap.sh --profile=web` and `pip install numpy pillow` came first, and
`app/assets/` had to be packed by `tools/pack_assets.py` before a single test could run — the
repository does not carry it and `flutter test` fails on eleven missing asset directories without it.
That is worth knowing before you conclude the suite is broken.

**`app/test/legible_on_what_it_is_on_test.dart` compiles.** `WORKER_PROMPT.md` has flagged since it
was written that this file had never once been through a compiler, and that it gates every code
commit. It compiles, and its six tests pass. That claim can come out of the prompt.

**The thing this firing was sent to check first: legibility did not regress.** The number is
`evidence/legibility.json`, its per-artifact shares match the journal entry above pair by pair, and
the sequence over four captures is 48.4% → 38.8% → 27.7% → **26.3%**. It has fallen every time. The
phrase that caused the alarm — *the half of the measurement that went the wrong way* — is the
previous firing's **commit subject**, and sitting next to two percentages it reads as though the
percentages are what went the wrong way. Its journal entry never said that. What went the wrong way
was `lightness_drift_room` and `14_media_viewer`, both of which that entry wrote up correctly. The
correction is now at the head of that entry rather than left for the next firing to re-derive.

**`paper-is-the-median-pixel`, worked and not closed.** `DIRECTION.md` says the shell is a desk seen
from above and each region is a different stack of paper on it. `app.dart` says the same thing in a
comment: *the paper underneath does not move; what is on it is exchanged*. There was no paper
underneath — every region drew onto the wood, and a vertical profile of `10_first_run` reads bare
plank at L 0.405 from the top of the region to the bottom with one bright band across the middle.
`RegionPad` is that sentence implemented: a sheet behind the region, taking no child and clipping
nothing, so every region keeps its own layout, its lazy slivers and its scroll position and goes on
scrolling over the page exactly as it scrolled over the desk.

What it bought, on a capture taken against it:

| | was | now | floor |
|---|---|---|---|
| `01_pulse` p50 | 0.7793 | 0.9313 | ≥ 0.78 |
| `13_messenger_states` p50 | 0.7687 | 0.9311 | ≥ 0.78 |
| `10_first_run` p50 | 0.4093 | 0.9434 | ≥ 0.78 |
| `10_first_run` ground | 0.7912 | 0.1291 | ≤ 0.50 |
| `04_moments` ground | 0.6199 | 0.3763 | ≤ 0.50 |
| `lightness_drift_room` | 0.5377 | 0.2105 | ≤ 0.20 |

Every `value_bands.ground` breach in the set is gone and seven room screens' `p50` breaches with
them. Three breaches remain, and **two of them are one screen**: `04_moments` at 0.7365 is the last
room under the floor and is also the low end of the drift, so taking it to 0.78 also takes the drift
to 0.167. The third is `10_first_run`'s mid band at 0.0203 against 0.04.

**The entry to read, because it nearly went into the tree as a success.** The first `RegionPad` was
three full-region `Slip`s, and a `Slip` at that size is four assets — stock, tear mask, lit edge,
baked shadow — resampled to a whole screen. That put `04_moments` into the exact failure its own
gallery comment warns about: the blob reads for the prints do not fail, they queue. The capture came
back as a sheet of lined paper with every photograph missing, and it measured `lightness.p50`
**0.9432** — comfortably inside [0.78, 0.95], the best number on the board, and produced by deleting
the content. Nothing in the gate caught it. `flutter analyze` was clean, 106 tests passed, the scene
report was byte-identical to the previous one because the widget tree *was* identical, and the
palette gate cheerfully recorded a pass. It was caught by looking at the picture.

So the pad was measured rather than argued about, four builds against one committed scene:

| build | prints that arrived |
|---|---|
| no pad at all (probe, compiled out) | 8 |
| three torn sheets | 0 |
| one cut sheet plus one under it | 2 |
| the same behind a `RepaintBoundary` | 5 |

`torn: false` drops the mask, the edge and the shadow and leaves the stock, and a pad has a cut edge
rather than a torn one anyway; every sheet takes the same id, so it is one decoded asset painted
twice, which is what a pad literally is. The `RepaintBoundary` is the other half: without one, a
sheet that never changes is re-rasterised into the same layer as everything scrolling over it, once
per frame. The committed capture returns the first two columns and is short on the third.

Two things follow that the next firing should not have to rediscover. The probe is the important
one: **with the pad compiled out entirely, the third column is already empty at this scene's settle**,
so `04_moments.png` was photographing an incomplete screen before any of this existed. And the
prints are not missing from the app — a twelve-second wait brings all of them back. They are missing
from a two-and-a-half-second screenshot. Neither the scene's wait nor any other capture parameter
was touched to make a number look better.

**The charm half: both items are the same job, and neither can be done the way its note says.**
`one-coloured-thing-per-screen` says to spend its accent area on objects that already exist. Every
`obj_*.png` was converted to OKLab with `palette.py`'s own matrices and asked what fraction of its
opaque pixels reaches `ACCENT_C = 0.09`. **One object of twenty-six has any: `obj_clover`, at 0.1363%
of itself.** `gold_star` is p99 0.0791, `snapped_pencil` 0.0728, and neither touches 0.09 anywhere. A
screen needs 1% of itself at that threshold, which out of a clover that is 0.14% accent by area is
about seven screens of clover, and §5 shuts the other door: multiply cannot produce chroma the ground
does not support. The same measurement is the more useful half of `families-b-c-and-d-reach-the-glass`
— the two families that have never registered are *already in the library at the wrong saturation*,
`obj_clover` at hue 134.7° being family D and `obj_ribbon` at 353.7° being family B. The hues are
right and the chroma is not. Both were recorded and neither was worked, because the fix is a re-render
through the committed blender recipes and that is a larger item than "the cheapest of the charm floors
to satisfy". Nothing was placed on the strength of the old note.

Free on the side: `06_unfolding.mp4` captured, 320 frames at 60fps, so it is no longer recorded
missing on its frame check — 15 of 17 rather than 14. `surfaces-folds-family` itself is untouched:
`surfaces.py` still reports 94 flat frames between 1.04 and 1.18 against a floor of 1.2. And the
unioned hue gap went 310° → 140°, inside §4's 150° ceiling for the first time, with
`named_families` at 2.

**What the next firing should expect.** Four items open and the stage stays IMPLEMENT. The cheapest
real move on the board is the bordered print: `04_moments` needs 0.044 more median, it is the last
screen under the floor and it is two of the three remaining breaches. That idea was considered and
rejected *this* firing, on the arithmetic that no border reaches a median-pixel floor starting from
0.4167 — but the pad has since done that lifting, and from 0.7365 it is a different sum. A print with
a paper margin and the date written in it is also what `_One`'s own comment already calls these
things. The gallery's load behaviour deserves an item of its own and does not have one.

A last note on process, since it cost twenty minutes. `CLAUDE.md` says never `pkill -f <pattern>`
where the pattern appears in your own command line. It is the fourth time here. `fuser -k -n tcp
<port>` does the same job and cannot match itself.

## Firing 4 · cycle 3 · IMPLEMENT · 2026-09-16

Step 0 passed, but not on the first command, and the reason is worth a successor's thirty seconds.
`git fetch origin` — the bare form, which `loop/WORKER_PROMPT.md` §0 and `CLAUDE.md` both still
print — **hangs indefinitely in this container**. It sat for eight minutes having read 3.6 MB and
opened no pack file, while `git ls-remote` against the same URL answered in under a second. A
targeted `git fetch origin claude/app-improvement-autonomous-workflow-d6fwdu` completed in seconds.
The repository is 552 MB of git objects and the bare fetch walks every ref including `main`; the
branch refspec does not. Every fetch in this firing used the refspec form and none of them took
longer than four seconds. The first `--dry-run` push then failed `non-fast-forward`, which is not a
credential failure and should not be reported as one: the checkout was three commits behind. After
a fast-forward the dry run returned `Everything up-to-date`.

The lease was taken, committed and pushed before a single file was read for work, per §2. It was
the second commit of the firing and the first thing on the branch.

**The stage.** IMPLEMENT, four items open, worked in queue order. One item advanced and did not
close, two were diagnosed down to a cause neither of them had, and one new item was filed. No item
closed outright.

### The measurement that reframed the whole colour half

`palette.py --floors` against the committed capture reports 58 breaches, and **roughly fifty of
them are §5 chroma floors** — ground, mid and figure mean chroma, figure p99, accent fraction,
spread across every still in the set. That is the owner's "doesn't evoke cuteness", and it dwarfs
everything else on the board.

Firing 3 established that the objects cannot pay for it: one `obj_*.png` of twenty-six has a pixel
at the accent threshold. Its conclusion was that the charm floors need the objects re-rendered at
higher chroma. **That conclusion was right about the numbers and wrong about the cause.**

Every paper stock carries three to five times more chroma in its **dusk** render than in its **day**
render, off the same albedo, through the same recipe. `lined_01` is Cmean 0.0132 by day and 0.0554
at dusk. `graph_01` is 0.0074 and 0.0467. `looseleaf_01` is 0.0117 and 0.0540. Every dusk stock in
the library clears §5's 0.030 ground floor; almost no day stock does.

The obvious explanation is the dusk aperture — `DUSK_STOPS = -3.0`, a darker image, more room for
colour — and it is the wrong one, which is why it was tested rather than assumed. Darkening the day
render by those same three stops in linear light measures Cmean **0.0067**: not four times up but
**half**, because OKLab chroma scales as the cube root of a uniform exposure change. Exposure moves
chroma the *wrong* way. The illuminant's hue is therefore doing all of the work and then some,
against the exposure rather than with it.

And the day rig's illuminant is neutral. A near-white sun `(1.0, 0.965, 0.905)` at strength 2.6 plus
a **cool** sky fill `(0.80, 0.83, 0.87)` at 0.55 nets out to R:G:B = **1.000 : 0.975 : 0.931**. The
cool fill is actively cancelling what warmth the sun has. Nothing rendered under a neutral lamp can
be more chromatic than its own albedo, and that is the entire mechanism: **the build is not made of
grey things, it is lit by a neutral lamp.**

This was proved by render, not by argument. `blender/paper/stocks.py` was run twice at identical
settings — res 700, samples 10, `--condition day`, `lined` variant 1 — once against the committed
`blender/rig/common.py` and once against a copy with `DAY_SKY` moved to `(0.92, 0.84, 0.70)`:

| | baseline | warmed | |
|---|---:|---:|---|
| `ground.mean_chroma` | 0.0142 | **0.0278** | +96%, from one constant; floor is 0.030 |
| `ground.p99_chroma` | 0.0273 | 0.0366 | ceiling is 0.09 — not remotely threatened |
| `lightness.L50` | 0.9675 | 0.9699 | the sheet gets *lighter* |
| ballpoint contrast | 12.98:1 | 13.06:1 | *improves* |
| graphite / margin | 10.33 / 8.57 | 10.40 / 8.63 | *improve* |

**Warmth here is free of legibility cost.** That is the opposite of the intuition — that colour is
bought out of contrast — and it is the single most useful thing this firing learned, because the
legibility half is the half that has been won and must not be given back. Read the ratios and not
the absolutes: the probe renders at res 700 / samples 10 / PNG and the shipped asset is res 3000 /
samples 24 / WebP, so the probe's L50 is 0.9675 where the committed `lined_01.webp` is 0.9306. The
baseline-versus-warmed comparison is valid; the absolute numbers do not transfer.

`(0.92, 0.84, 0.70)` is a probe and not a proposal. A tint sweep over the committed asset puts the
net illuminant needed to clear the ground floor at about B = 0.80.

**It was filed, not done**, and that is deliberate. The day illuminant is `DIRECTION.md`'s light
section rather than an implementation detail, it moves every asset in the build in one stroke, and
`loop/WORKER_PROMPT.md` §3b is explicit that a worker who finds something worth doing that is not in
the queue adds it with its measurement and leaves it for ADDRESS to rank. So
`the-day-rig-is-what-took-the-colour-out` is in the queue with the render numbers above, and both
charm items now point at it and say not to start placing objects until it has been ranked — because
a warmed rig raises every object's chroma at once and changes what is left for them to do.

### paper-is-the-median-pixel: the print landed, the shadow did not

The previous firing's named next step was the bordered print, and it is in. `_One` in
`moments_region.dart` was returning a picture bled to the edge of its tile; the gallery's own
`_heightOf` has called these things prints since it was written. It is a print now — cut rather than
torn, on index card, a 5 px paper margin, the date along the bottom in `Pen.margin` — and
`_heightOf` carries the margin so the column balance stays honest.

The arithmetic was done against the committed still first. `04_moments` is bimodal and its median
sits on the seam: p50 0.7365, p60 0.9238, 43% of the frame already paper. Converting **2%** of the
frame from picture to paper reaches 0.8031, and a print margin converts about a quarter of each
tile, so the change has room rather than being sized to the floor. 106 tests pass, `flutter analyze`
is clean of errors and warnings, and `scroll_cost` still reports a lazy gallery at 18 of 183 prints
built for the first screenful. The print is pinned to one stock so a screenful shares a single
decode — deliberately, because firing 3 recorded a pad starving the gallery's blob reads and
photographing a screen with no photographs in it.

**The other breach on this item has a root cause now, and it is not a tuning problem.** `RegionPad`
draws its sheets with `Slip(torn: false)`; `Slip` only assigns a `tearId` when `torn` is true; and
`app/lib/material/paper.dart:180` draws the baked contact shadow `if (tearId != null)`. **The largest
piece of paper on every screen casts no contact shadow at all.** On a seeded screen nobody noticed,
because the notes' own tear shadows supply the mid band — `01_pulse` 0.0514, `13_messenger_states`
0.0741, both passing. `10_first_run` is a fresh install with nothing on the paper, so the only paper
is the shadowless pad and `value_bands.mid` collapses to 0.0203 against a floor of 0.04. Its
histogram is 80.5% of the frame at the top of its own range, 11.8% at the bottom and 2.0% in
between: the two-value image §2 describes, caused by precisely the thing §2 calls the ladder's
missing rung.

It was recorded and not fixed. Every shadow in `assets/tears` is keyed to a torn mask — 57 of them,
all `tear_NNN_shadow*.png` — and there is **no cut-edge shadow in the library**, which is why the
gate is written the way it is. Closing it needs a new render through `blender/paper/tear_relief.py`
(which already emits a contact shadow alone, alpha only, framed at `SHADOW_FRAME` 1.20) plus a
wiring pass through `MANIFEST.json`, `pack_assets.py` and `MaterialLibrary`. That was too much to
start well with a capture already running. Nothing was bodged in its place, and in particular the
pad's sheets were **not** made torn to borrow a shadow a cut sheet has no material right to.

### What the capture said

A full `./capture.sh` at degradation rung 0 — `apt-prereqs`, `bootstrap --profile=web`, both builds,
every scene, every check — 15 of 17, the two Android artifacts the standing hardware ceiling.

| | before | after | |
|---|---:|---:|---|
| `04_moments` `lightness.p50` | 0.7365 | **0.7988** | floor 0.78 — **cleared** |
| `04_moments` `value_bands.ground` | 0.3763 | 0.3368 | in band |
| `04_moments` `value_bands.mid` | 0.1221 | 0.1339 | in band |
| `across_the_set.lightness_drift_room` | 0.2105 | **0.1482** | ceiling 0.20 — **cleared** |
| runs below contrast floor | 26.26% | **25.28%** | not paid out |
| `10_first_run` `value_bands.mid` | 0.0203 | 0.0203 | floor 0.04 — unmoved |
| `04_moments` `widest_hue_gap_deg` | 140 | **160** | **regression, mine** |

The prediction was 0.8031 from the committed still and the capture returned 0.7988, which is close
enough to trust the method next time.

**The regression is mine and it is more interesting than it is expensive.** `04_moments` held hue
bins at 245°, 255°, 265° and 275°; with a quarter of each tile now paper, only 255° still clears the
0.012 area floor, so its own gap opened to 160° and the set takes the union. What that exposes is
worth more than the breach costs: **`04_moments` is the only still in the set that carries family C
at all, and its blues were photographic content, not stationery.** The declared blue-grey graph
stock — `#e9ecec` with `#b9cbe0` rules, which `DIRECTION.md` and `blender/SPEC.md` both promise —
renders at Cmean 0.0074 and is the *least* chromatic thing in the library. The one cool family the
build has was an accident of the seed photographs. That is the day rig again, and closing that item
should close this breach on the way past. The wrong response is to trim the margin back: `p50` sits
0.019 above its floor and the feedback loop is a forty-minute capture.

The date in the print margin was measured rather than assumed: `04_moments` went from 47 text runs
to 67 and from 29 failures to 30, so nineteen of the twenty new runs clear their floor.

### The capture caught the absent-content trap a second time

`14_media_viewer` came out of the full run as a **bare dark desk with its caption and no photograph**
— `value_bands.ground` 0.8757, `grey_fraction` 0.0026, `value_bands.mid` 0.0076. Those are pretty
numbers produced by a missing image, which is exactly what firing 3 was bitten by on `04_moments`.

It was re-captured alone with `--only --no-build` and came back **byte-identical** to the previous
capture's artifact, so it is a race under full-run load and not a deterministic break. It is also
**not** caused by the print: `evidence/scenes/14_media_viewer.json` reaches the viewer through chat
(`goTo 1`, `openViewer photo`) and never touches the gallery. What ties the two instances together
is that `IndexedStack` builds all five regions, so the Moments gallery is issuing blob reads even on
a screen showing chat.

Firing 3 wrote that the gallery's load behaviour deserved an item of its own and did not have one.
It has one now — `the-gallery-loses-its-pictures-under-load` — and its measurement deliberately
requires three consecutive clean captures, because "capture it again until it looks right" is
precisely how this build would begin falsifying itself. The committed artifact is the re-capture;
the empty one is not in the tree and must not be quoted.

### Two things that cost time, written down so they cost nobody else any

**`git fetch origin` hangs in this container.** Eight minutes, 3.6 MB read, no pack file opened,
while `git ls-remote` against the same URL answered in under a second. The repository is 552 MB of
git objects and the bare form walks every ref including `main`. `git fetch origin <branch>` finished
in seconds every time. §0 of `loop/WORKER_PROMPT.md` printed the bare form and has been corrected.

**A blender generator writes `assets/MANIFEST.json` even when `--out` points elsewhere.** The two
probe renders went to the scratchpad and still added two manifest entries whose paths climbed out of
the repository with `../../../tmp/...`. Reverted before anything was committed. Anyone rendering a
throwaway comparison should expect to `git checkout -- assets/MANIFEST.json` afterwards.

### Where this leaves the loop

The stage stays IMPLEMENT with six items open, and the ordering question for ADDRESS is now sharp
rather than diffuse. Four of the six are downstream of one constant. `one-coloured-thing-per-screen`
and `families-b-c-and-d-reach-the-glass` are the same job and that job is the day rig;
`paper-is-the-median-pixel`'s new hue breach is the same job again; and roughly fifty of the
sixty-three palette breaches are §5 chroma floors that a neutral illuminant cannot satisfy at any
albedo. **The cheapest real move on the board is no longer a widget. It is a light.**

What a firing taking that item should know before it starts: it is a whole-library re-render, it
touches `DIRECTION.md`'s light section rather than a constant in a leaf file, and the one thing it
must not do is buy chroma out of contrast. The probe says it does not have to — warmth came out
free, and slightly to the good — but that is one stock at one setting, and the measurement clause on
the item requires `legibility.py` to hold across the whole set before it closes.

---

## Cycle 3 · IMPLEMENT · firing 5 — the lamp

Step 0 passed. `git fetch origin <branch>` and `git push --dry-run` both answered; the bare
`git fetch origin` that §0 warns about was tried first by habit, hung exactly as described, and was
abandoned for the refspec form, which finished in seconds. The lease was taken and pushed before
anything was touched.

One item: **`the-day-rig-is-what-took-the-colour-out`**. It does not close. What follows is what it
cost, what it bought, and the two things it turned up that nobody was looking for.

### The lamp was never 5200 K

`DIRECTION.md` declares one day rig, "warm (5200 K)". `blender/rig/common.py` carried
`DAY_COLOR = (1.0, 0.965, 0.905)` annotated `# ~5200 K`. Fitting a blackbody to it gives **6125 K**.
The annotation was nine hundred kelvin out and nothing in the build could tell, because a comment is
not a measurement.

The larger half was not a wrong number but a wrong model, and firing 4 had already named it without
having the arithmetic: the world background was open sky at `(0.80, 0.83, 0.87)`. Blender's world is
a full unoccluded hemisphere, and a sun at 50° contributes `sin(el) × energy` while a world of
radiance *S* contributes `π × S`, so the sky was **41% of the total irradiance**, not the fifth a
reading of the constants suggests. Sun and sky together: **R:G:B = 1.000:0.995:0.980**. A neutral
lamp, and an object under a neutral lamp cannot be more chromatic than its own albedo.

The fix makes the temperature the constant and derives the colour from it by Planck's law, so the
comment and the value cannot drift apart again; makes the background the key bounced off a
warm-white room, because that is what a desk beside a window actually sees; and **solves the
strengths rather than typing them**, holding the luminous irradiance each source lands on a
horizontal sheet at exactly what the rig has always delivered. Net: **1.000:0.805:0.650, 5080 K,
exposure unchanged to one part in 10⁹**. Lightness is held by construction and only hue moves.

`tools/check/illuminant.py` is the gate. It fails on the value that shipped, and — the case worth
having — it also fails on fixing the key alone and leaving the fill as open sky, which is the same
defect at half strength and which a 700 K tolerance would have waved through at 5825 K. Both were
put back and watched to fail. It runs in `capture.sh`'s pre-flight, because a gate nobody runs is
`texture_budget.py` again.

### What it bought, measured on disk and not predicted

| | before | after |
|---|---:|---:|
| `assets/shell/desk.png` mean chroma | 0.0276 | **0.0418** |
| 27 day paper stocks, mean chroma | ~0.018 | **0.0475** |
| `graph_01` mean chroma | 0.0072 | **0.0350** |
| 26 objects, mean p99 chroma | 0.0335 | **0.0577** |
| objects clearing the 0.09 accent threshold | 0 | **3** |

**Legibility was not paid.** That was the one condition on the item and it is the thing this build
has clawed back from 48.4% to 26.3% of runs below floor. Measured against each sheet's own dark end
at Y p10 — the adversarial ground, not the flat — the worst of the three declared body inks moved by
**0.048 contrast ratio points** across all 27 sheets, on values between 3.5:1 and 7.6:1. The largest
lightness change anywhere in the paper family is 0.0084 of OKLab L, and the desk plate stayed inside
the 0.40 ± 0.03 its own retune set. That is the exposure invariant doing its job.

### What it does not buy, which is the more useful half

A warm illuminant multiplies up a **warm** albedo and drags a cool or green one toward orange. So it
raises family A and squeezes B, C and D, and it cannot manufacture presence:

- `figure.p99_chroma` reaches **0.0981** at best against a floor of 0.10. All ten stills still fail.
- `across_the_set.mean_chroma` goes 0.0181 → about **0.0435** against a floor of 0.045.
- `widest_hue_gap_deg` gets **worse**, 310° → 330°.
- `sticky_blue`'s rendered hue went **222.7° → 84.6°**; `obj_staple_chain` 267.3° → 61.9°;
  `obj_stone` 271.4° → 59.8°. The stock library and the object library now carry **no family C at
  all**.

`docs/COLOR.md` §7 wrote this down in advance — "a build can meet a mean by warming the whole frame,
which produces a sepia photograph". So the lamp is corrected to exactly what the law declares and
**stopped there**, rather than pushed further to chase a number it would reach.

### Family C is not dim. It is out of gamut.

This is the finding worth the firing. Sweeping every in-gamut albedo through the corrected
illuminant and asking for the most chromatic render inside each family band, per lightness:

| OKLab L | family C, old lamp | **new** | family B, old | **new** | family D, old | **new** |
|---:|---:|---:|---:|---:|---:|---:|
| 0.95 | 0.0431 | **0.0000** | 0.0366 | **0.0000** | 0.2233 | **0.0000** |
| 0.90 | 0.0821 | **0.0000** | 0.0729 | **0.0629** | 0.2668 | **0.1444** |
| 0.87 | 0.1081 | **0.0070** | 0.0986 | **0.0883** | 0.2943 | **0.2195** |
| 0.80 | 0.1459 | **0.0583** | 0.1536 | **0.1550** | 0.2766 | **0.2743** |
| 0.70 | 0.1727 | **0.1271** | 0.2559 | **0.2514** | 0.2416 | **0.2413** |

§3 requires every room's median pixel to be paper at L 0.78–0.95 and the stocks measure 0.87–0.95.
**At that lightness, under the light this build declares, no albedo renders into family C.** A
direct search for one that would put `sticky_blue` back in C at its own lightness returns nothing in
gamut. The declared "graph paper cool blue-grey" cannot exist as a pale sheet under this lamp.

The way out costs no render and was in the palette the whole time: **the app's own flat colours are
Dart constants composited over the render, so the rig cannot touch them.** `Pen.red #a8322b` is
chroma **0.1553** at hue 27.7° — family B, and the only declared colour in the build already above
the accent threshold. `Pen.ballpoint #1f2a44` is 0.0503 at 265.9° and `Pen.biro #141a2e` is 0.0402 at
270.2°, both family C, both dark enough that the gamut result does not bind them, and both already
feeding the area-weighted hue histogram, which counts from chroma 0.004 and not from 0.09. **The hue
families belong to the ink and the objects, not to the paper.**

### Two corrections to notes this firing itself wrote

`tools/relight.py` predicts a capture in seconds instead of forty-five minutes by multiplying the
committed stills in linear light, and it is committed with its three known errors written down. It
was 1.1% out on the desk plate. But it **under-called `obj_gold_star` by half** — 0.0881 predicted,
0.0976 rendered — because a first-order multiply cannot see specular or interreflection and a foil
star is mostly both. So the earlier note that the lamp moves objects "five to twelve percent" is too
pessimistic: three objects crossed the accent threshold. Firing 3's conclusion that no object in the
library can carry an accent patch was true *under the old lamp* and is not true now. That half of
`one-coloured-thing-per-screen` is a placement job today; the `figure.p99 ≥ 0.10` half is still a
render job, and the item has come apart into two.

### An asset with no maker

Fifty of the fifty-two object day files came back newer after the re-render. The two that did not
are `obj_heart_fold.png` and its shadow — because `blender/objects/objects.py` builds twenty-five
objects and `heart_fold` is not one of them. Their `assets/MANIFEST.json` entries name `objects.py`
as their generator anyway, and `tools/check/manifest.py` passes, reporting "634 files in assets/, 0
without an entry naming their generator", because **it checks that an entry exists, not that the
generator it names can make the file**. Two assets in this library are not reproducible and the gate
says all of them are. Filed with a measurement and a way to re-break it. Found by rendering, not by
reading, which is the argument for the mtime comparison in the new coherence item.

### Where this leaves it

`tools/render_queue6.sh` is the backlog — objects, bits, tears, photos — ordered by how much of a
screen each family covers, idempotent, resumable by re-running it, and with `assets/folds` noted in
its header as owed and deliberately last because `palette.py` reads stills and no fold frame appears
in one. Shell, paper, objects and bits are done and pushed. Tears was running when this firing ran
out of lease and is partially done; photos and folds are untouched.

**The next firing should finish that script before it does anything else, and certainly before any
capture.** A capture taken now would measure a library lit by two lamps, which is a real state — it
is queued as `the-library-is-lit-by-two-lamps` so it cannot quietly become a design decision — but
it is not a state worth spending forty-five minutes measuring. The prediction for the capture that
follows a drained backlog is in `tools/relight.py` and in the item's note; the honest expectation is
that the ground, mid and figure **mean** floors and every ceiling come good, and that
`across_the_set.mean_chroma`, `figure.p99_chroma`, `accent_fraction` and the hue families do not,
because those are albedo and this was a light.

## Cycle 3 · IMPLEMENT · firing 6 — the order, and an asset with no maker

### The question this firing was handed, and what it decided

The firing arrived with a fair challenge: `evidence/palette.json` still reads `mean_chroma` 0.0181
from the capture taken *before* the lamp changed, so two firings of work on the illuminant are
currently an assertion, and this repository's first rule is that a measurement beats an assertion.
A capture is what turns that into a result. Should it have run OBSERVE?

**No, and the reason is that the capture would not have measured what it appears to measure.**
`loop/STATE.json` named IMPLEMENT and the queue was not drained, which settles the protocol half.
The substantive half is the one worth writing down. At the moment this firing started, the library
was in the state its own queue item `the-library-is-lit-by-two-lamps` describes: `assets/shell`,
`assets/paper`, `assets/objects` and most of `assets/bits` re-rendered under the corrected 5080 K
day rig, and `assets/tears` (8 of 168 day files), `seed/photos` (0 of 115) and `assets/folds`
(0 of 240) still under the neutral 6445 K lamp that firing 5 proved was never 5200 K. Every screen
in the build composites the two together.

A capture of that is a real state and an unrepeatable one. Its `palette.json` would be neither the
number the lamp work predicts nor the number it replaced; it would be an average over a boundary
that exists only until the backlog drains, and it would be quoted afterwards as though it measured
the lamp. 04_moments and 14_media_viewer are the two stills that fail the ground chroma floor
hardest and they are *made of* photographs — the single family with zero files relit. Measuring
them before the photographs are relit measures the old lamp and attributes it to the new one.

Firing 5 reached the same conclusion from the other end and wrote it down in plain words at the
close of its entry: *"The next firing should finish that script before it does anything else, and
certainly before any capture."* This firing agrees, and adds the argument above so the reasoning
survives independently of the instruction.

So: the queue first, and the ordering inside the queue is the render backlog, because the backlog
is the thing standing between this build and a capture that means anything. The warmth thread stays
an unproven claim for one more firing, and the alternative was to make it a *disproven* one on
evidence that could not be reproduced.

### An asset whose generator could not make it

`obj_heart_fold.png` and its two shadows named `blender/objects/objects.py` as their generator.
That file builds twenty-five objects and heart_fold is not among them — and the reason it is not is
already written, in the docstring of the object that replaced it:

> This replaces an origami heart. A heart is a glyph whatever it is modelled out of — a filled
> white one on a warm ground is the emoji whether or not it was folded — and the anti-goal is about
> what a thing reads as, not how it was made.

So the design call was made three cycles ago and only half of it landed. `app/lib/feelings/builtins.dart`
has shipped `obj_pinch` for `squeeze` ever since; `docs/FEELINGS.md`, `blender/SPEC.md` and three
files in `assets/` never heard. `loop/STATE.json`'s note on the item reserved the authoring-or-
retiring question for design — correctly, when it was written — but there was no question left to
reserve. Retiring the files is executing a decision, not making one.

### The hole in the gate, which is the part that generalises

`tools/check/manifest.py` reported *"634 files in assets/, 0 without an entry naming their
generator"* while two of those files had no maker. It asked whether an entry **exists**. It never
asked whether the named generator could **produce** the file, and those are not the same question.

It now reads each generator's catalogue out of the generator itself and fails on an entry whose
subject is not in it. Statically, with `ast`, because these modules import `bpy` at the top and a
gate that only runs where Blender is installed is a gate that does not run — this one runs in
`capture.sh`'s pre-flight.

The coverage is partial, and **the report says so rather than implying otherwise**: 458 entries
checked against a catalogue, 308 named as having none, broken down by generator. Understating what
a gate knows is the entire lesson of the bug it was written to catch. The five generators that keep
a catalogue (`objects.py`, `stocks.py`, `bits.py`, `fold.py`, `synth.py`) are covered; the five that
are procedural, seeded or single-output (`tear.py`, `tear_relief.py`, `still.py`, `desk.py`,
`build.py`) are named as unverified, and each is a few lines to add when someone decides what its
catalogue is.

Re-broken as the item required: dropping `obj_clover` from `OBJECTS` makes the check name
`obj_clover.png`, its shadow and its dusk shadow alongside heart_fold's three, and exit 1. Putting
it back returns it to green. Before the retirement the gate found exactly the three heart_fold
files and exited 1; after it, 634 files, zero unbuildable, exit 0.

`tools/render_queue6.sh` had a comment naming heart_fold as the live example of why
`restore_missing` exists. That example is no longer true, and a false comment in a script this
build relies on is the same defect one layer up, so it now records the case in the past tense and
says what replaced it.

### The test that had never been compiled

`docs/CONTINUE.md` and `loop/WORKER_PROMPT.md` both flag `app/test/legible_on_what_it_is_on_test.dart`
as rewritten by a firing with no Flutter toolchain, never built, and gating every code commit. This
is the first firing to bootstrap a toolchain since. **It compiles, and its four tests pass**, inside
a full suite of 98 passed. The flag can come down.

One setup step is not written down anywhere and cost this firing ten minutes: `flutter test` fails
at *"unable to find directory entry in pubspec.yaml: app/assets/paper/"* in a fresh container,
because `app/assets/` is generated and gitignored. `python3 tools/pack_assets.py` writes it, and
`run.sh` calls that only on a build. Run it once after `bootstrap.sh` and the suite runs.

### What the backlog actually bought, per family, measured rather than predicted

The photographs went first because they are the whole of 04_moments and 14_media_viewer and were
the one family with nothing relit. All 115 rendered and developed. Old blob against new file:

| | mean chroma | ratio | ΔL |
|---|---:|---:|---:|
| 76 on the day rig | 0.0126 → 0.0159 | ×1.26 | +0.0002 |
| 39 on their own lamps | 0.0195 → 0.0204 | ×1.05 | +0.0067 |

The overall figure is ×1.17, and quoting it alone would be misleading. A recipe names its own
light, and only five of the eleven conditions in this family are daylight; `strip`, `kitchen_bulb`,
`lamp` and `torch` do not move at all, which is correct — a kitchen bulb is not the day rig.
`window_left`, which is 46 of the 76, moves ×1.45.

**This corrects firing 5's prediction for the two photograph screens, in the unhelpful direction.**
`tools/relight.py` multiplies a committed still by the illuminant ratio uniformly, so it applied the
full day-rig ratio to pixels a kitchen bulb lit. Its 04_moments ground chroma of 0.0266 and
14_media_viewer of 0.0250 are therefore *overstated*, not merely short of the 0.030 floor. A third
of that family cannot move and the rest moves a quarter. Expect those two stills to miss by more
than predicted — which is the same conclusion firing 5 reached about presence, arriving a second
time down a different road: the chroma has to come from albedo and ink, not from the lamp.

The torn edges are the opposite case and the more interesting one. Fourteen done, 005–018, measured
only where the edge actually paints:

    mean OKLab L   0.9508 → 0.8622   (−0.0886)
    mean chroma    0.0127 → 0.0436   (×3.44)

**That comparison is not clean, and the commit that carries it, 74eec99, over-attributes it to the
lamp. The correction is here.** `assets/MANIFEST.json` records tears 005 onward at res 640 and 10
samples, and tears 001–004 — firing 5's — at 1400 and 48. The manifest was telling the truth: most
of this library's tears were committed as *draft* renders. So the backlog is a quality upgrade as
well as a relight, and a before/after across it moves two variables at once.

Isolating them costs one render. `tear_005` was re-rendered at **the old 640/10 settings under the
new lamp** and compared with the committed old file at the same settings, so that only the
illuminant differs:

| tear_005_edge, alpha > 0.5 | L | chroma | any channel ≥250 | all three ≥254 |
|---|---:|---:|---:|---:|
| old lamp, 640/10 (committed) | 0.9535 | 0.0130 | 43.57% | 1.06% |
| **new lamp, 640/10 (probe)** | 0.9154 | **0.0447** | 49.82% | **0.00%** |
| new lamp, 1400/48 (shipped) | 0.8625 | 0.0436 | 5.94% | 0.00% |

Read across those rows:

- **The chroma is the lamp.** 0.0130 → 0.0447 at identical resolution and sample count, ×3.44. The
  headline number survives intact, and the jump to 1400/48 barely touches it (0.0447 → 0.0436).
- **Flat-white clipping is the lamp too**, and that part of the original claim holds: 1.06% → 0.00%
  of painted pixels at 255 on all three channels. A clipped highlight is white by construction —
  three equal channels, no hue — so removing it is precisely where some of the new chroma comes
  from.
- **The collapse in *near*-clipping is not the lamp. It is resolution.** 43.57% → 49.82% under the
  new lamp at the old settings — it goes slightly *up* — and only falls to 5.94% at 1400/48. A
  640px render of a two-millimetre lit lip puts that edge in a handful of large bright pixels; at
  1400px the same edge is resolved into a gradient. The "42.86% → 5.61%" in 74eec99 is almost
  entirely that, and reading it as an exposure fault the lamp fixed was wrong.
- **The lightness drop splits.** Of −0.0886 L, the lamp accounts for −0.038 and the resolution and
  sample count for the remaining −0.053.

So: the tears gained their colour from the corrected illuminant, at ×3.44 — the largest gain of any
family, and real. They stopped blowing out to flat white because of the illuminant as well. But
they are also no longer 640-pixel drafts, and that is what most of the lightness change and nearly
all of the near-clipping change actually measure. Two of the four claims in 74eec99 stand and two
are corrected here rather than quietly left in the log.

### Two bugs in the backlog script, both found by running it

`blender/paper/tear_relief.py` takes `--conditions` and defaults to `day,dusk`.
`tools/render_queue6.sh` never passed it, and `--skip-existing` tests only `tear_NNN_edge.png`, so
pruning a day edge made the generator render that tear's dusk shadow as well — **6.5 minutes a tear
against the 4.1 measured after the fix**, a third of the largest remaining family spent on the one
condition this backlog exists to leave alone. It is also where the four stray `*_shadow_dusk.png`
in `assets/tears` came from: tears 001–004 have one and the other fifty-three do not, and those
four are exactly what firing 5 rendered before its lease ran out. Nothing reads them. Queued.

The second one cost more. The header's stop procedure ended with

    git checkout -- assets seed/photos

described as putting back anything pruned but not yet rendered. It does that, and it also restores
every **modified** file in those directories — so it does not recover the pruned, it destroys the
rendered. This firing ran it as written and lost three finished tears. It now restores the deleted
paths and nothing else, which is what `restore_missing` in the same file has always done:

    git ls-files -d -- assets seed/photos | xargs -r git checkout --

The 115 photographs were already committed and pushed when that happened and were untouched. That
is the argument for `WORKER_PROMPT.md`'s "push after every completed item, never once at the end",
restated as something this firing paid for: a pushed commit is the only thing here that a mistake
at the stop step cannot reach.

### Where this leaves the backlog

| family | state |
|---|---|
| `assets/shell`, `assets/paper`, `assets/objects` | clean |
| `seed/photos` | **clean — 115 of 115, done this firing** |
| `assets/tears` | 18 of 56 day edges; **76 files stale**, ~2.6 h at the measured 4.1 min a tear |
| `assets/bits` | **8 files stale** — the script's step-3 sweep never ran this firing |
| `assets/folds` | 240 frames, untouched, still not a step in the script |

The next firing re-runs `tools/render_queue6.sh`: photographs are skipped in seconds now, and it
resumes the tears at file granularity. It is roughly three more hours of rendering to a clean day
library, not counting folds — and folds still cannot be seen by `palette.py`, which reads stills, so
the case for spending a firing on them before a capture remains weak.

**The capture is the next firing's after the library is clean, and not before.** `evidence/palette.json`
will still read 0.0181 until then, and that is the correct state for it to be in: it is the last
number this build actually measured, and replacing it with one taken over a lamp boundary would
have been worse than leaving it stale.

## Firing 7 · cycle 3 · IMPLEMENT · 2026-09-17

Step 0 failed on the first attempt and was not a credential failure, which is the case
`WORKER_PROMPT.md` §0 warns about by name and is worth one paragraph because the warning was
earned again. The container's checkout was a **shallow clone fifty commits behind** `origin`, so
`git push --dry-run` came back `non-fast-forward` and `git merge-base` reported no common ancestor
at all — the shared history was simply cut off by `.git/shallow`. It reads exactly like two
divergent branches. The tell is the server's own words in the rejection: *"the tip of your current
branch is behind its remote counterpart"*, which is an ancestry claim only the server can make and
the shallow client cannot. Fast-forwarded to `5a89bab`, re-ran the dry run, `Everything
up-to-date`. Also worth writing down: **bare `git fetch origin` hung again**, exactly as firing 4
recorded, and the branch refspec answered in seconds. The file already says this; it is true.

### The library is lit by one lamp, for everything a still can see

The day tear family is finished: 56 lit edges and 56 contact shadows at 1400/48 under the corrected
5080 K room, against the 18 firing 6 left. Thirty-eight tears in two hours fifty-five minutes, 4.6
minutes apiece over the whole run and 3.5 once the bootstrap and the test suite stopped sharing the
four cores — so firing 6's 4.1 and this firing's 4.6 are the same number measured through different
amounts of contention, and a firing that renders and tests at once should expect to pay about a
third more per tear in that window.

`assets/objects`, `assets/paper`, `assets/shell` and `seed/photos` were re-measured rather than
assumed, and were already clean. **What remains is `assets/folds` and nothing else.**

That changes what the next firing may do, and it is the whole point of the last three. `assets/folds`
is 240 frames and feeds `06_unfolding.mp4` alone; `tools/check/palette.py` reads stills and no fold
frame appears in one. So the chroma numbers a capture takes now measure a single illuminant. The
argument firing 6 made for withholding the capture — that a library lit by two lamps averages two
lighting conditions and produces a number meaning neither — no longer applies to any still in the
set. `evidence/palette.json` can stop reading 0.0181. `tools/check/surfaces.py` *does* read the fold
frames, so folds are still owed for `material_truth` and for `surfaces-folds-family`; they are not
owed for the chroma floors, and the two should not be confused again.

### The bits step had been doing nothing, and said nothing about it

The backlog's last step printed `assets/bits: 14 already relit, 8 to render`, finished in **one
second**, and then printed `restored 8 file(s) the generator did not rebuild`. No error anywhere.

`bits.py`'s `--skip-existing` asked whether `{name}.png` was on disk. `render_bit` writes four files
for a bit — the colour pass and the contact shadow, under each of the two lights. `render_queue6.sh`
had pruned eight `*_shadow.png` whose colour pass was still there, so the generator skipped those
bits outright and `restore_missing` put the stale shadows back. This is the same hole `tear_relief.py`
had, which firing 6 found the same way: by running the thing and reading what it said. Closed the
same way, and `bits.py` gains `--conditions` so the dusk rig this backlog exists to leave alone is
left alone. Re-broken to check it: before, all eleven bits print "already rendered" and none of the
eight files come back; after, the three whose four files are complete skip and exactly the eight
render.

A second, smaller one in the same place: `run()`'s filter matched `bit:` and `bits.py` prints
`bits:`, so that family's output never reached the log at all. That is why the step looked silent
rather than skipped, and it is why it took a re-run to see.

### The resume ledger has a blind spot, and it cannot be rendered away

The eight bit shadows come back **bit-for-bit identical** under the corrected lamp — `maxdiff 0.0000`
on every channel of every one. The contact shadow pass carries no colour from the illuminant. So it
never changes, so git never records a change, and `prune_stale` — which infers *already relit* from
*changed in a commit since `a6f46fd`* — will report those eight stale forever, however many times a
firing renders them.

The ledger is sound for everything the lamp moves and structurally cannot clear an asset the lamp
does not move. The eight are verified relit by reproduction instead, which is the stronger evidence
anyway. Whoever runs the backlog again: **eight bit shadows reported stale is the expected reading,
not work.**

### A queue item was wrong in the direction that costs an asset

`four-tears-have-a-dusk-shadow-and-fifty-three-do-not` said that nothing reads a tear's dusk shadow,
that the four `*_shadow_dusk.png` were the side effect of a missing flag, and — carefully, and to its
credit — filed the deletion rather than doing it in passing, because removing a committed asset is
not a thing to do without looking. Looking is what this firing did, because the item's own
measurement told it to: *grep the app for a dusk tear path*.

There is one. `PaperPiece.build` reads `Light.of(context)` and `_bakedShadow` puts the suffix
straight into `tearAsset('${tearId}_shadow$suffix')` at `app/lib/material/paper.dart:112`. At dusk
the app asks for a dusk contact shadow for **every** torn note in the build. Four of the fifty-six
exist. The other fifty-two draw nothing, silently, because the load carries `errorBuilder: none` —
so on one dusk screen some notes sit on the desk and some float, and no check, no test and no
capture has ever been able to tell. `app/lib/material/objects.dart:118` is the same construction and
is one file short, `obj_plaster_shadow_dusk`. Deleting the four would have removed the only four
that work.

`MaterialLibrary` carries a guard for each of these — `hasTearRender`, `hasObjectShadow` — and
**neither is called from anywhere.** A guard nobody calls and a render nobody made fail together
and in silence.

So the gate went where the app cannot see: `tools/check/dusk_shadows.py` takes each place the app
appends `_dusk`, cites the line that does it, and requires the file. It names 53 today; `paper_stock`
(27 of 27) and `desk_plate` (1 of 1) pass, so this is two families that never had a dusk pass rather
than a habit of the build. Re-broken by hiding `assets/paper/lined_01_dusk.webp`: `paper_stock` went
from `ok 27 of 27` to `MISSING 26 of 27` and printed the file. It is wired into `capture.sh` beside
the illuminant gate.

The app half is a widget test, because the cheap way to make a completeness check pass is to stop
asking for the asset. Re-broken by dropping `$suffix` from `paper.dart:112`: the dusk case fails and
names the day asset it got instead. 109 tests pass with it.

The renders are 2.1 hours and no decision, and they are queued rather than done, because the day
tear backlog held the machine for this firing. Filed as `fifty-two-notes-have-no-shadow-at-dusk`.

### What the next firing should expect

The stage is still IMPLEMENT and the queue is not drained. The two things now worth a firing, in
this order:

1. **Take the capture.** It is what four firings have been waiting on and the library is finally
   consistent for it. `evidence/palette.json` and `evidence/legibility.json` are both stale against
   a lamp that has changed underneath them, and until they are re-taken the owner's second complaint
   is unanswerable rather than unanswered. Legibility is the one to watch: 25.3% of runs below floor
   is the number to hold or beat, and the relight must not have bought warmth with it.
2. **The 53 dusk shadows**, which are CPU and no decision, and `assets/folds`, which is the last
   family under the old lamp and the whole of `surfaces-folds-family`.

Neither is blocked. Nothing in `asks[]` moved.

## Firing 8 · cycle 3 · IMPLEMENT · 2026-09-17

Step 0 hit the shallow-clone trap a second time, exactly as firing 7 wrote it down, and the note
saved the diagnosis rather than the time. The container's checkout was at `3edfbf7`, fifty commits
behind; `git merge-base` reported **no common ancestor at all** and both `git log A..B` and `B..A`
printed long disjoint lists, which reads like two unrelated histories rather than one that is
behind. `.git/shallow` is the whole of it — `git rev-parse --is-shallow-repository` says `true`,
and the grafted boundary hides the join. Two tells, both cheap: the server's rejection says *"the
tip of your current branch is behind its remote counterpart"*, an ancestry claim only the server
can make; and `git ls-remote` puts the branch at `034937c`, which was already in the object store
because the session was minted at that revision. Fast-forwarded to `034937c`, re-ran the dry run,
`Everything up-to-date`. Bare `git fetch origin` did NOT hang this time — it took about two
minutes and completed — but the refspec form is still the right default and the file still says so.

This entry is being written before the stage, alongside the lease, so that a firing arriving on top
of this one can see what is running. The rest of it is appended at the end of the firing.

**Lease taken: IMPLEMENT, four hours, to 2026-09-17T10:58Z.**

---

**Firing 6, waking on a container restart after its stage had closed.** Firing 8 holds a live lease
(`session_01Wgu5shvuK8cAZcazr2CtDz`, expires 10:58Z), so this is a note and not a stage.

`assets/MANIFEST.json` carries two entries that should not be in it, committed by firing 6 in
`5a89bab` and still on HEAD:

    ../../../tmp/.../scratchpad/tearprobe/tear_005_edge.png
    ../../../tmp/.../scratchpad/tearprobe/tear_005_shadow.png

They came from the one probe render that firing 6 used to separate the lamp from the resolution on
the torn edges — rendered into a scratch directory with `--dir`, on the assumption that output going
elsewhere meant the manifest was untouched. It is not: a blender generator writes
`assets/MANIFEST.json` wherever its output goes, which `CLAUDE.md` now records as a standing trap,
and firing 6 committed the result without re-checking the file it had been warned about.

Nothing is broken by them. `tools/check/manifest.py` exits 0 — `ok` depends on files missing an
entry and on entries whose generator cannot build them, and these are neither — and its `--fill`
path already deletes entries that climb out of `assets/`. The legitimate `tear_005` entries are
intact at 1400/48 with bytes matching the files. So this is a wrong line in the library's own
inventory rather than a defect in the library.

**Whoever next holds the lease:** delete those two keys from `assets/MANIFEST.json`, or run
`python3 tools/check/manifest.py --fill`, which does it and says how many it dropped. One commit.
Firing 6 did not do it itself because doing so is stage work and the lease was not its to take.


### The capture, and the two things it says

`evidence/palette.json` no longer reads 0.0181. The number is **0.0358**, against a floor of 0.045.
It nearly doubled and it did not arrive, which is what firing 5 wrote down in advance and is the
answer as it landed rather than as it was hoped.

The set mean hides where the relight actually paid, so both are recorded. `chroma_by_band.ground.mean_chroma`
went from **0 of 10** stills over the 0.030 floor to **7 of 10**; `mid` is 8 of 10; `figure` mean is 8
of 10 over 0.035. `grey_fraction` 0.0454 → 0.0241, `lightness_drift_room` 0.1482 → 0.0534, and every
section 5 ceiling holds — of 42 breaches, not one is a ceiling. The three stills that did not move
are the three the lamp does not light: `17_setup_pwa` 0.0256 → 0.0256 and `14_media_viewer` 0.0150 →
0.0150, unchanged to four decimals, and `04_moments` 0.0162 → 0.0219. Firing 5 predicted that and
firing 6 explained it. So `the-day-rig-is-what-took-the-colour-out` should close on the per-band
floors and hand the set mean to the albedo items: the lamp has now given everything it has, and the
remaining 0.009 is owed by ink and objects.

The wheel narrowed exactly as firing 5 said it would, and it is worse than before: `named_families`
2 → 1, `widest_hue_gap_deg` 160 → 320. Family C is gone from the set.

### Legibility went the wrong way, and the relight is what did it

**25.28% → 30.70%** of runs below floor, 179 of 708 → 233 of 759. Nothing in `app/lib` changed
between the baseline capture and this one, so it is the library.

It is not a dimming, and the split is the whole diagnosis: failures on **still** ground went 43 →
41, and every one of the 54 extra failures is on **moving** ground, 136 → 192. Measured on
`tear_010`'s lit edge where alpha > 0.5, the torn lip's own luminance is **Y 0.8649** under the old
lamp and **0.6424** under the new one, against a sheet at 0.8936 — and flat-white pixels went 7.10%
→ 0.00%.

That is the mechanism, and it is the same measurement firings 6 and 7 both counted as a win. What
was being clipped away was the lip's entire tonal presence: blown out it sat within 3% of the sheet
and was not a feature of the image at all. Unclipped, it is a dark band 28% below the paper it is
part of. Every torn note now carries a dark ring; text near a torn edge has a ground whose dark end
is genuinely dark; `ground_swing` crosses the 1.20 gate; and `legibility.py` reads the ink against
that end, correctly. `03_us` carries most of it — 9 failures of 52 runs → 36 of 83, median contrast
as rendered 5.87 → 2.72, and 35 of the 36 are at boxes that were not failing before.

The crops were looked at rather than argued about, because the alternative reading is that the gate
is wrong. It is not: at (60,520)–(860,780) the old still has a fine white torn lip and the new one
has a coarse dark stepped band in the same place. Filed as `the-relit-tear-edge-is-a-dark-band`
with the route **not** to take written into it — re-clipping the edge would undo the ×3.44 chroma
gain that the same change bought, and the still-ground failures did not move, so there is nothing
to be won by trading them.

### Two things about the instruments, both of which cost this firing time

**`capture.sh` runs neither `palette.py` nor `legibility.py`.** A full capture finishes, reports 15
of 17, and leaves both files reading the numbers from the previous cycle. Both came back
byte-identical to the stale ones and were very nearly reported as the result; the mtimes are what
gave it away — the stills were rewritten at 07:15 and the two JSONs still said 06:57. Run them by
hand after a capture, and match the previous invocation: the baseline ran `legibility.py` with no
`--dusk`, so this one did too, or the comparison would have measured a changed command.

**The gallery lost its pictures again, in this capture, partially.** `04_moments` is at
`lightness.p50` 0.9254 against the ≤ 0.85 that `the-gallery-loses-its-pictures-under-load` names as
violated precisely when the content is absent, and about half the tiles are bordered prints with
their date and no photograph. `14_media_viewer` is clean this time (0.5771 against ≤ 0.62), so the
two screens do not fail together. The three-consecutive-captures clause is therefore at **0, not 1**.
And `04_moments`' own figures in this capture measure a half-empty gallery: its ground chroma of
0.0219 and its apparent legibility improvement, 30 of 67 → 19 of 54, are both artefacts of absent
content and are not results. The photographs carry chroma, so the set mean is understated by this
rather than flattered by it.

### Fifty-six of fifty-six, at dusk

`fifty-two-notes-have-no-shadow-at-dusk` is closed. `tools/check/dusk_shadows.py` exits 0 on all
four rules against the 53 it named this morning; re-broken by hiding one file, which takes it to
MISSING 55 of 56, names the file and exits 1. The app half stayed green with it — three tests in
`a_note_at_dusk_asks_for_its_dusk_shadow_test.dart`, inside 109 passed — which is the clause that
stops the cheap fix of no longer asking for the asset.

**None of it would have rendered.** `tear_relief.py`'s `--skip-existing` tested only
`tear_NNN_edge.png`, and the edge is baked once under daylight and is the one file a dusk pass never
writes, so `--conditions dusk` over the complete day library would have skipped all fifty-six tears
and printed `skip` fifty-six times. `objects.py` had the same shape, which is how
`obj_plaster_shadow_dusk` stayed missing while its family reported finished. This is the third copy
of the hole firing 7 found in `bits.py` — and `bits.py`'s docstring said firing 6 had already closed
it in `tear_relief.py`. It had not: firing 6 had worked around it from `render_queue6.sh` by passing
`--conditions day`. Both closed, the false sentence corrected where it was read, and verified
against the library without spending a render: `tear_001` skips under `--conditions dusk` and
`tear_005` does not, where the old rule skipped both.

Cost, for whoever estimates the next single-condition family: **3.2 minutes a shadow**, 52 in 2h45m,
against the 2.4 the queue item derived by subtracting firing 6's day-only figure from its
day-and-dusk one. That subtraction charges the second condition with none of the scene setup it
repeats, and under-calls by about a third.

### A second firing arrived while this one held the lease, and the lease worked

`c9bc763` landed on the branch mid-firing. It had read `loop/STATE.json`, found a live lease that
was not its own, wrote one journal note and took no stage — which is exactly what `WORKER_PROMPT.md`
§2 asks for, and the first time the gate has been observed doing its job. This firing rebased its
own unpushed commit onto that one rather than over it. Nothing was lost on either side. The lease
was later extended to 11:30Z rather than allowed to lapse under a running render, because a lapsed
lease is precisely what invites a second worker to start the stage.

### What the next firing should expect

The stage is still IMPLEMENT and the queue is not drained. Eight items open. In order of what this
firing would do next:

1. **`the-relit-tear-edge-is-a-dark-band`** — the regression, with its diagnosis and its forbidden
   route already written into the item. `legibility.py --only 03_us.png` is the cheap inner loop.
   Note that `17_setup_pwa`, the one still with no desk and no tears in it, went 0 failures → 3 and
   its `worst_ink_core` 7.98 → 1.07, so the tears are not the whole of it and that screen is worth
   its own look.
2. **`assets/folds`** — 240 frames, the last family under the old lamp, the whole of
   `surfaces-folds-family`, and the only thing keeping `the-library-is-lit-by-two-lamps` open. CPU
   and no decision.
3. **`the-gallery-loses-its-pictures-under-load`** now has a committed partial instance to debug
   against, which is more useful than either of the all-or-nothing ones.

Nothing is blocked. Nothing in `asks[]` moved.

**Lease released.**

---

## Firing 9 — IMPLEMENT — the regression was mostly the instrument

Firing 8 handed over `the-relit-tear-edge-is-a-dark-band` as first business and it was the right
item to pick up. Its diagnosis of the pixels is correct and its conclusion about the text is not,
and the difference is 47 of 54 failures.

### The denominator moved, and it was most of the story

The run count went 708 → 759 between the two captures. `legibility.py` is **byte-identical** at
`e5d6ce8` and at HEAD — checked, not assumed — so every bit of that is the pixels. A run is not a
declared thing: it is found by a mark detector, so the denominator of
`total_below_floor / total_runs` moves whenever the light does, and comparing that ratio across a
relight is not a comparison of the same thing.

Both captures were re-measured from the committed stills with the current tool (baseline
reproduced exactly: 708 runs, 179 below) and then paired run by run, by box overlap within each
artifact:

```
  the same text, lit twice   124 -> 131 of 622 matched runs     0.1994 -> 0.2106
  the whole-set ratio        179 -> 233 of 708 -> 759 runs      0.2528 -> 0.3070
  runs that went                86, 55 of them failing
  runs that arrived            137, 102 of them failing (74% against 21% on matched runs)
```

**Of the +54, seven are the same text reading differently and forty-seven are the population
moving under the detector.** The legibility regression this cycle caused is 0.1994 → 0.2106, not
0.2528 → 0.3070.

Per-artifact it is starker than the total. `03_us` was named as carrying most of the regression:
its matched runs went **6 failures → 6**, and the whole of its apparent 9 → 36 is thirty-five new
boxes. `05_settings` 38 → 38. `04_moments`, `13_messenger_states`, `14_media_viewer` all unchanged
on matched runs. `17_setup_pwa` went **0 → 0** on matched runs, so the item's note that "that
screen is worth its own look" can be struck — its three new failures are the same artefact as
everything else.

### The new boxes are not text, and this was looked at rather than argued

Cropped at 300%, before and after side by side, in `03_us`, `05_settings` and `01_pulse`. Not one
of the sampled boxes contains writing. They are torn-paper fibre steps, sheet edges against the
desk, and in one case the blank lined space beside a word — in two of the crops the real text
("able go", "ne table", "YOURS") is plainly visible *above* the box that was drawn. The population
reads `ink_core` median **1.18** — stroke and ground at the same luminance, which is what a piece
of one surface reads as — against **7.77** for the matched runs.

So the relight did not make the writing hard to read. It stopped the torn lips clipping to flat
white, the real fibre structure underneath became visible, and the mark detector started counting
it as writing.

### Three routes tried, three refuted, so nobody spends a firing on them again

1. **Shape.** Nothing separates the two populations: glyph count, fill fraction, glyph-height CV,
   baseline CV, median glyph width all overlap heavily. `glyphs >= 3` removes 83 of the 102 false
   failures — and 53 of the 131 **true** matched failures with them, plus 132 real runs. That is
   improving the number by hiding real problems.
2. **Straddle.** The idea that a torn edge is a boundary between two surfaces while writing sits on
   one, tested as the contrast between a band above the run and a band below it. Refuted by its own
   measurement: at every threshold from 1.5 to 4.0 it drops more true matched failures than false
   new ones — at 1.5, twenty-six against six.
3. **Quantization.** The staircase look of the relit lip is not posterization and the rig is not
   mis-exposed. Over the `05_settings` lip the distinct RGB count went **up**, 1899 → 2098, and the
   mean flat run got **shorter**, 3.59px → 2.91px, with the luminance range widening at the dark
   end. It is the truthful render of structure that was previously clipped away.

Re-clipping the edge was already forbidden for costing the ×3.44 chroma gain. It is now also
pointless: the edge was never what moved the number.

### What was built

`tools/check/legibility_delta.py`. It pairs two captures run by run and splits the headline into
the part that is the same text reading differently and the part that is the population moving.
Re-broken three ways rather than asserted: against itself the matched rate moves 0.0000 and
`--gate` exits 0; against a set washed toward its paper with the geometry held fixed — so every run
still matches its twin — it puts +492 of +545 on the matched runs and exits 1; against the real
pair it exits 1 at tolerance 0 and passes at 0.02.

This was treated as part of the item rather than as work outside the queue, because the item's own
`measurement` field named a comparison that does not hold, and supplying the one that does is the
item's work. The field has been restated in `loop/STATE.json` so the next firing gates on the
matched-run rate and not on the whole-set ratio.

### What was not done, and why

No fix was pushed, because the three cheap fixes are measured and none is safe, and the honest
remaining question — what makes a mark writing rather than a piece of the surface it is on — is a
designed answer and not a threshold. It is filed as `writing-is-not-the-same-as-texture` with its
measurement and with both halves that have to be quoted together, so that it cannot be closed by
deleting true findings. Two directions are written into it that were not tried: writing is authored
and therefore repeats, where fibre does not; and the app knows where its own text is, so a
render-time text mask would turn this from inference into fact.

`evidence_note` in `loop/STATE.json` has been amended, because as written it sent this firing at the
wrong thing and would have sent the next one too. The chroma half of it stands untouched. No file
under `evidence/` was altered.

**Not run:** `flutter analyze` and `flutter test`. There is no Dart toolchain in this container and
this firing touched no Dart and no `app/` code — one new Python analysis tool, plus JSON and prose.
Bootstrapping fifteen minutes of Flutter to gate a file it cannot see was not worth the firing.

### What the next firing should expect

The stage is still IMPLEMENT and the queue is not drained. The regression no longer jumps the
queue: at +7 matched runs it is a small real item, not the emergency it was recorded as. In order:

1. **`assets/folds`** — 240 frames, the last family under the old lamp, the whole of
   `surfaces-folds-family`, and the only thing keeping `the-library-is-lit-by-two-lamps` open. CPU
   and no decision, and now the most valuable thing on the board.
2. **`the-gallery-loses-its-pictures-under-load`** — still has the committed partial instance from
   firing 8 to debug against, which is more useful than either all-or-nothing one.
3. **`writing-is-not-the-same-as-texture`** — worth doing, wants DESIGN, do not attempt it with a
   threshold.

Nothing is blocked. Nothing in `asks[]` moved.

**Lease released.**

---

## Firing 10 — IMPLEMENT — lease taken

Step 0 passed on the second attempt, and the first attempt's failure is worth recording because it
will recur. This container's checkout was a **shallow clone at depth 50, made two days before the
branch tip it was checked out against**. `git merge-base` between it and `origin/<branch>` is empty
and `git rev-list --count` reads 50 ahead / 50 behind, so the working tree reads as a fork of
unrelated history rather than as a checkout that is behind. `git merge --ff-only` cannot fix that;
`git reset --hard origin/<branch>` can, and did. The dry run then returned `Everything up-to-date`.
The credential was never in question: the first dry run was rejected by the remote with
`non-fast-forward`, which is the server having authenticated and then declined the ref update.

`70ade67` already named this shape — "a shallow clone that reads like a fork" — so this is the
second firing to meet it. `loop/WORKER_PROMPT.md` §0 prescribes `--ff-only`, which is not sufficient
here; that is amended below.

Picking up firing 9's handoff in the order it wrote: `assets/folds` first.

## Firing 10 — IMPLEMENT — the folds, and a gate that had never opened its eyes

Picked up firing 9's handoff in the order it wrote it: `assets/folds` first, the last family under
the old lamp and the whole of `surfaces-folds-family`.

### The gate was green because it had read nothing

`tools/check/surfaces.py` reads `app/assets`. `tools/pack_assets.py` writes `app/assets` and
`.gitignore` excludes it, so in a fresh container there is no such directory. Every glob matched
nothing and the report came back `"read": 0, "ok": true`, exit 0 — the check that exists to catch a
flat plate declaring the library sound having opened none of it. That is the file's own docstring
happening to the file: *nobody notices, because it looks approximately like the thing.*

Reading fewer than `--min-read` surfaces is now its own error, exit 2, tested before the flat list
because a run that found nothing has an empty flat list as well. Re-broken to prove the guard is
what does it and not the rewrite around it: `--min-read 0` reproduces the old behaviour exactly,
0 surfaces read and exit 0. `--root` now picks the library, so the source renders can be checked
before a pack, and PNG is matched as well as WebP.

Against `--root assets` it reads 321 surfaces, names the folds family, and fails on 94 of the 240
frames of `unfold_thirds` between 0.912 and 1.197 — which reproduces from the source library the
number firing 3 recorded from the packed copy.

### The queue note's own hypothesis, measured and refuted

The item has said for three firings that what remains is "the re-render of `blender/folds/fold.py`
with the tooth the stocks carry". The natural reading is that the fold's fibre is the wrong size:
`paper_material`'s noise scales are in UV, a stock's UV spans 210 mm and the fold's spans 148, so
the same number is a 1.64× finer fibre on the fold than on the paper it is supposed to be made of.

That reading is wrong, and it is wrong in the expensive direction. Matching the stocks in
millimetres — `fibre_scale` 1100 → 669 — made every frame worse at both resolutions tested.

Measured one variable at a time, as `surfaces.py`'s own `patch_std`. "packed" is the frame put
through `pack_assets.convert` at the size the app ships it, which is what the default gate reads.

```
                                        frame 0000    frame 0150
  committed, old lamp, 540/16              1.096         1.354
  new lamp, 540/16                         0.831          --
  new lamp, 540/64                         0.864         1.098     samples are not the lever
  new lamp, 540/16, fibre 1100 -> 669      0.822         1.073     worse, not better
  new lamp, 540/16, exposure -0.30         1.027         1.296     not taken; see below
  new lamp, 1080/16      source            1.677         1.944
                         packed            1.179         1.371     still short
  new lamp, 1440/16      source            2.047         2.084
                         packed            1.489         1.607

and on the two worst frames in the set, which are what the floor has to clear:

                                        frame 0235    frame 0238
  committed, old lamp, 540/16              0.912         0.924
  new lamp, 1440/16      source            1.946         1.925
                         packed            1.384         1.399
  new lamp, 1440/64      source            2.047          --
                         packed            1.396          --
```

The fold's fibre was never too fine for the paper. It was too fine for 540 pixels. This is the
tears' lesson again, which firing 6 wrote down in the same words — *the '42.86% → 5.61%' is
RESOLUTION, not the lamp* — and which the folds were owed as much as the tears were.

So the default is 1440/16, and the last line is why the samples did not move with the resolution:
quadrupling them buys 0.012 at the size the frame is actually shown at, for three times the render.
The packed WebP was measured through `pack_assets.convert` itself rather than through a stand-in
resize, and the four frames tested land at 1.384, 1.399, 1.489 and 1.607 against the 1.2 floor.

Two checks that the number is texture and not noise, because a patch-variance floor is satisfied by
render noise as happily as by tooth and firing 9 was right to say so. A 2.67× downsample would cut
white noise by about the same factor: 2.047 → 0.77. It reads 1.489. And 16 samples against 64
agree to 0.012, which undenoised noise would not.

### What the relight alone would have done, which is the opposite of what was wanted

Rendering frame 0000 under the corrected lamp with nothing else changed took it from 1.096 to
**0.831**. Worse. The cause is a finding larger than this item and it is filed as its own queue
entry rather than absorbed: **the corrected day illuminant pins the red channel.**

The relight holds *luminous* irradiance constant. Luminance is 0.2126R + 0.7152G + 0.0722B, which
is almost all green, so holding it while moving the spectrum to 1.000:0.805:0.650 raises red by
construction. `tools/check/illuminant.py` gates the temperature. Nothing gates the headroom.

Measured against the pre-relight blobs in git, so it is this change and not a state that was always
there — the fraction of opaque pixels at exactly R = 255:

```
  paper/graph_01        0.0000 -> 0.5123        objects/obj_plaster   0.2272 -> 0.8274
  paper/looseleaf_01    0.0000 -> 0.5931        objects/obj_crane     0.3450 -> 0.7199
  paper/receipt_01      0.0025 -> 0.7735        a fresh fold frame            0.9564
```

25 of 27 day paper files and 13 of 25 day objects are over 1%.

The rig already names this defect for the other condition — *"clipped at 254 with half the tooth"* —
and answers it with `DUSK_STOPS`, an aperture that lives in `blender/rig/common.py` "because
everything lit at dusk has to agree about it". There is no day equivalent. A probe at a −0.30 stop
cleared a fold frame's clipping completely, 0.9564 → 0.0000, and raised its `patch_std`
0.831 → 1.027, so an aperture is a measured route and not a guess.

**It was filed and not acted on, deliberately.** Whatever fixes it re-renders every day asset in
`assets/`, which is four firings and the whole library that answered the owner's warmth complaint.
`loop/WORKER_PROMPT.md` §3b says that is ADDRESS's to rank, not something to do on the side of
another item. Two things for whoever ranks it: a clipped channel carries no hue and no tooth, which
is the same argument that made the tears' un-clipping worth ×3.44 their chroma — so this may be
taking back part of what the relight bought, and `evidence/palette.json` was measured with it. And
it is a *candidate* mechanism for the legibility half, because ink contrast against a ground whose
red is pinned loses the red component of that contrast. That last is a hypothesis with a way to
test it, not a finding, and it is written into the item as one.

Do not fix it by moving `DAY_COLOR` back. The quantity with no gate on it is the exposure.

### The re-render, and what it came to

240 frames at 1440/16, two and a half hours, 33 seconds a frame on four cores, committed in eight
chunks of thirty as they landed rather than held to the end — which is also why `render_sequence`
needed fixing first. It recorded the manifest by listing its output directory, so a chunked run
wrote *this* call's resolution over every frame sitting in the directory, including ones still on
disk at 540. It records the range it rendered now, and the half-finished library's provenance was
true at every commit along the way: after chunk one, `0029` read 1440 and `0030` read 540 while
`0030.png` was already on disk at 1440 and its call had not returned.

```
  tools/check/surfaces.py --root assets        before   94 of 240 below floor, worst 0.912, median 1.371
                                               after     0 of 240 below floor, worst 1.840, median 2.057

  tools/check/surfaces.py  (app/assets, packed to 540 WebP, what the app ships)
                                               after     0 of 240 below floor, worst 1.477, median 1.691
```

321 and 318 surfaces read respectively, none flat, exit 0 both ways.
`tools/check/texture_budget.py` still passes: 28.0 MB of 32 on a 36-frame window, because the packed
size did not change — only the source did.

**Re-broken rather than asserted.** The frames as they were, restored from `25638eb` into a tree of
their own and run through the same tool, fail with exactly 94 and exit 1.

### The library is under one lamp

`the-library-is-lit-by-two-lamps` closes with it. Checked by the same git test `prune_stale` uses
rather than assumed: of 508 day-lit files under `assets/`, 64 have no commit touching them since
`a6f46fd`, and all 64 are accounted for.

56 of them are `tear_NNN.png`, which are the tear **masks** — white-on-black alpha, no illuminant
falls on them, and the relight renders `tear_NNN_edge.png` and `tear_NNN_shadow.png` instead. They
were never day-lit; the filter that flags them is too broad. The other 8 are the bit shadows firing
7 wrote down as a permanent blind spot: bit-identical when re-rendered, verified relit by
reproduction, and "reported stale is the expected reading, not work."

Zero genuinely stale files. Four firings and a whole library, done.

### For whoever runs next

The stage is still IMPLEMENT and eight items are open. Firing 9's order still holds for what is
left of it, minus the one that is now done:

1. **`the-gallery-loses-its-pictures-under-load`** — has the committed partial instance from firing
   8 to debug against. Wants a Flutter toolchain, which this container did not have and this firing
   did not need; budget fifteen minutes for `./bootstrap.sh --profile=web` before anything else.
2. **`writing-is-not-the-same-as-texture`** — wants DESIGN. Do not attempt it with a threshold.
3. **`the-corrected-lamp-pins-the-red-channel`** — new, and it is the one that may reorder the rest,
   because it touches the same two numbers the owner asked about. It is ADDRESS's to rank and not an
   IMPLEMENT firing's to take on the side.

Two things this firing learned about the container, both cheap and both wasted a slice of it:

- The checkout arrived as a **shallow clone at depth 50 made two days before the tip**, so
  `git merge-base` with `origin/<branch>` is empty and it reads 50 ahead / 50 behind — a fork, not a
  checkout that is behind. `WORKER_PROMPT.md` §0 prescribes `git merge --ff-only`, which cannot fix
  it. `git reset --hard origin/<branch>` can, and the section has been amended to say so. The
  credential was never in question: the first dry run came back `non-fast-forward`, which is the
  remote authenticating and then declining.
- `bootstrap.sh` is not needed to render. Blender alone is a 360 MB download and one `tar -xJf` into
  `toolchain/blender`, about ninety seconds, plus `pip install numpy pillow` for the check tools and
  `opencv-python-headless` for `pack_assets.py` — which is in `bootstrap.sh`'s python list and is
  worth knowing separately, because `pack_assets.py` dies on `import cv2` two thirds of the way in
  after it has already written half of `app/assets`.

Nothing is blocked. Nothing in `asks[]` moved.

**Lease released.**

## Firing 11 — IMPLEMENT — lease taken

Step 0 passed on the second attempt, in exactly the shape firing 10 wrote up and amended
`loop/WORKER_PROMPT.md` §0 for: a **shallow clone at depth 50**, grafted at a different point from
the branch tip, so `git merge-base` came back empty and `git rev-list --count HEAD...origin/<branch>`
read **50 ahead / 50 behind** — which is the *total* commit count on both sides, the tell §0 names.
`git rev-list --count origin/<branch>..HEAD` was 50, equal to the total, so it is a graft boundary
and not work. `git reset --hard origin/<branch>` fixed it; the dry run then returned
`Everything up-to-date`. The credential was never in question — the first rejection was
`non-fast-forward`, which is the remote authenticating and then declining the ref update.

Third firing to meet this. The amendment held: reading it cost two minutes rather than the slice it
cost firing 10.

Lease held to 2026-09-18T02:00Z. The stage is IMPLEMENT and seven items are open.
