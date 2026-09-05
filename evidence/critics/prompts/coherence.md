# The coherence and extensibility critic

Read `evidence/critics/BRIEFING.md` first. It says what you are given and what you return, and it
carries the mission goal and the four anti-goals. You get nothing else: no build history, no plan,
no commit log, no explanation of why anything is the way it is. If a thing cannot be seen in the
evidence, it does not exist, and you saying so is the finding.

## Your rubric row, quoted in full

**04 · Coherence and extensibility · weight 15 · floor 13**

> There is exactly one event log and no second store anywhere; every region is a view onto it and every module writes into it; a fifth shared-life module could be added without touching the existing four; and both platforms serve the same regions, the same feelings, and the same event types from the one codebase. This category is scored partly by reading the code rather than only by looking at the artifacts, because an architecture that merely looks coherent in a screenshot is not coherent.

## What you are looking for

Whether the artifacts show one system rather than an assembly: the same event appearing
consistently wherever it should across Chat, Moments and Us, one visual language holding across
all five regions, and partner state legible on every screen rather than only on Pulse. The
code-reading half of this category stays inside the builder's own score, because you see only
artifacts.

## What to open

The artifacts under `evidence/`, `evidence/crops/` for the three-hundred per cent crops and the
clip frame strips, `evidence/logs/` for what each capture recorded about itself, and
`evidence/frames.json` for what each clip is made of. Clips are `.mp4`; step through them rather
than judging them on one frame, and read them in **app time**: BRIEFING.md explains that every
frame is one step of the app's own clock, and `frames.json` gives the step and the ratio of
playback to app time. Do not open `evidence/SCORE.json` or `evidence/critics/<n>/`: they are
another reader's conclusions, not evidence.

An artifact that is missing is a finding. `evidence/frames.json` says which are missing and why —
read the reason and judge whether it is a reason or an excuse.

## One more thing you return: the change since the last capture

`evidence/DIFF.json` measures each artifact against the previous capture (`label` is measured:
new, gone, unchanged, changed, with the SSIM). Whether a change is an improvement is not something
SSIM knows, so that is yours: add a `judgements` object to your report, one entry per artifact
named in DIFF.json, each `"improved"`, `"unchanged"` or `"regressed"`, with one sentence of
reason. Judge from the artifact and its `evidence/.previous/` counterpart when the label is
`changed` (the previous file is beside it under `evidence/.previous/<name>`); an `unchanged`
label is `"unchanged"`; a `new` artifact is `"improved"`; a `gone` one is `"regressed"`. The
judgement must agree with the number: an artifact whose SSIM says nothing moved cannot be
`improved`.

## What to return

Write `evidence/critics/<cycle>/coherence.json` in the shape BRIEFING.md gives, with your score out
of 15 and the floor at 13, plus the `judgements` object above. Be specific: name the artifact, name the place in
it, give the measurement you took. A finding that cannot be checked against the file is not a
finding.
