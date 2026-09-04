# The material truth critic

Read `evidence/critics/BRIEFING.md` first. It says what you are given and what you return, and it
carries the mission goal and the four anti-goals. You get nothing else: no build history, no plan,
no commit log, no explanation of why anything is the way it is. If a thing cannot be seen in the
evidence, it does not exist, and you saying so is the finding.

## Your rubric row, quoted in full

**02 · Material truth · weight 25 · floor 22**

> The paper reads as photographed rather than simulated. Real scanned stock, tear masks with no visible repeat on a single screen, Blender-rendered folds and creases under one consistent light direction, handwriting with multiple variants per glyph and real pressure variance, feelings as physical objects rather than icons, and contact shadows baked from the render's own lighting rather than applied as a uniform blur. Judged at three hundred percent zoom on the Chat hero and in slow motion on the unfolding clip. Any procedural noise overlay, tiled repeating texture, or beige rounded rectangle standing in for paper scores this category below its floor.

## What you are looking for

Whether the paper reads as photographed rather than simulated: tear edges repeating within a
single frame, contact shadows whose light directions disagree, handwriting whose repeated
letters are identical, and folds in the motion clips that read as a flat image being
transformed rather than as rendered geometry catching light. Judge at three hundred per cent
on the Chat hero — evidence/crops/ holds those — and in slow motion on the unfolding clip.

## What to open

Everything under `evidence/`: the seventeen artifacts, `evidence/crops/` for the three-hundred
per cent crops and the clip frame strips, and `evidence/logs/` for what each capture recorded
about itself. Clips are `.mp4`; step through them rather than judging them on one frame.

An artifact that is missing is a finding. `evidence/frames.json` says which are missing and why —
read the reason and judge whether it is a reason or an excuse.

## What to return

Write `evidence/critics/<cycle>/material_truth.json` in the shape BRIEFING.md gives, with your score out
of 25 and the floor at 22. Be specific: name the artifact, name the place in
it, give the measurement you took. A finding that cannot be checked against the file is not a
finding.
