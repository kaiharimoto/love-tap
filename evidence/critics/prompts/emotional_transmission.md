# The emotional transmission critic

Read `evidence/critics/BRIEFING.md` first. It says what you are given and what you return, and it
carries the mission goal and the four anti-goals. You get nothing else: no build history, no plan,
no commit log, no explanation of why anything is the way it is. If a thing cannot be seen in the
evidence, it does not exist, and you saying so is the finding.

## Your rubric row, quoted in full

**03 · Emotional transmission · weight 20 · floor 17**

> A gesture on one device arrives on the other as a sensation rather than as a message in a different colour. At least thirty built-in feelings across at least five named families, each identifiable by its haptic pattern alone with the screen face down; user-authored feelings behaving identically to built-ins in every path; at least twelve partner-state signals; three ambient presence surfaces; state changes perceptible without opening the app; a feeling reachable in one gesture from any region of the app; and on the iOS PWA a deliberately designed non-haptic substitute that reads as equally physical rather than as a missing feature.

## What you are looking for

Whether a feeling arrives as a sensation rather than as a message in a different colour, judged
from the landing clip, the propagation clip, and the two-device frame — including whether the
iOS substitute for the missing haptic reads as equally physical rather than as an absence.

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

## What to return

Write `evidence/critics/<cycle>/emotional_transmission.json` in the shape BRIEFING.md gives, with your score out
of 20 and the floor at 17. Be specific: name the artifact, name the place in
it, give the measurement you took. A finding that cannot be checked against the file is not a
finding.
