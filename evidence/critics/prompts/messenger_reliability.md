# The messenger reliability critic

Read `evidence/critics/BRIEFING.md` first. It says what you are given and what you return, and it
carries the mission goal and the four anti-goals. You get nothing else: no build history, no plan,
no commit log, no explanation of why anything is the way it is. If a thing cannot be seen in the
evidence, it does not exist, and you saying so is the finding.

## Your rubric row, quoted in full

**01 · Messenger reliability · weight 30 · floor 26**

> Every messenger capability is present and dependable: text, photos, video, voice notes, reactions, replies, delivery and read state, typing indication, editing and deleting, full-text and media search, and the media viewer. No dropped or duplicated messages, no lost drafts, correct ordering after going offline and reconnecting, no spinner that outstays its welcome, and no scroll jank against the year-deep seeded history. This is the category that decides whether the couple actually leaves Instagram, so any single failure that would give either person a reason to open Instagram instead scores this category at or below its floor regardless of how well everything else is working.

## What you are looking for

Whether anything visible in the artifacts would give either person a reason to open Instagram
instead: a missing capability, a state that has stalled, ordering that makes no sense after a
reconnect, jank in the dense scroll, or a delivery and read marker that cannot be trusted.

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

Write `evidence/critics/<cycle>/messenger_reliability.json` in the shape BRIEFING.md gives, with your score out
of 30 and the floor at 26. Be specific: name the artifact, name the place in
it, give the measurement you took. A finding that cannot be checked against the file is not a
finding.
