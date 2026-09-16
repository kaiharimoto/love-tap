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
