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

