# What a critic is given

Every critic is a fresh context. It receives three things and nothing else:

1. **The mission goal** — the paragraph below, and nothing about how the thing was built.
2. **The evidence** — the artifacts in `evidence/`, the derived crops in `evidence/crops/`, and
   the capture's own records in `evidence/logs/`, `evidence/frames.json`, `evidence/MANIFEST.json`,
   `evidence/DIFF.json`, `evidence/reliability.json` and `evidence/coldstart.json`.
3. **Its own rubric row**, quoted in full.

It never receives the build history, the plan, the commit log, the task list, or any explanation
of why something is the way it is. If a thing cannot be seen in the evidence, it does not exist
as far as a critic is concerned, and a critic saying so is the finding.

**Not part of the evidence, and not to be opened:** `evidence/SCORE.json` (the builder's own
scoring and the builder's prose about earlier cycles) and `evidence/critics/<n>/` (earlier
critics' reports). They are moved out of the directory while a cycle's critics run, and a critic
who finds one anyway leaves it closed: a report that leans on another report is not a fresh look.

## How to read a clip

Every clip is a directory of single frames taken one at a time with the app's own clock stepped
between them, then assembled at 60 frames a second without re-encoding. The timebase of a clip is
therefore **the app's time, not the wall clock**: one frame is one step of the driven clock, and
`evidence/frames.json` records, per clip and per run, how many milliseconds each step was worth
(`runs[].step_ms`), the total app time (`app_seconds`) and the ratio of playback to app time
(`playback_over_app_time` — 1.0 means real time, 2.0 means the clip plays at half speed). A
statement about how long something took on screen is a statement in app time, read off those
fields; the wall-clock interval between two grabs (`evidence/logs/<clip>.json`, `steps[].ms`) is
the harness's cost of taking the frame and says nothing about the app. Two identical adjacent
frames in a clip are a fault, and `frames.json` names them.

## The mission goal, as given to every critic

An Android app and an Apple-compatible installable PWA that let exactly two people communicate
directly with each other over Tailscale between their devices. It must first be a complete,
reliable, genuinely pleasant multimedia messenger — text, photos, video, voice notes, reactions,
replies, delivery and read state, searchable history — because it is replacing Instagram DMs as
the couple's primary channel and will be judged unusable if any of that is missing or flaky. On
top of that solid messenger sits the actual reason the app exists: an emotional nervous system
that transmits feeling rather than sentences, where a gesture on one device becomes a sensation
on the other, and where each person's inner state is continuously legible to the other. Beyond
messaging and feeling, it grows into a shared relationship OS with modules for the couple's life
together — date planner and tracker, shared to-do lists, anniversaries and calendar, rituals and
streaks, ambient widgets and scheduled pings — and it must be architected so new modules of this
kind can be added later without rework.

## The four anti-goals, as given to every critic

- No engagement machinery. No badges, points, streak-breakage warnings, or guilt.
- No emoji soup or stock illustration standing in for feeling.
- No product-marketing voice. No "Oops!", no exclamation marks, the reader is never addressed as
  a user, and the app never names itself.
- No simulated paper. A beige rounded rectangle with a drop shadow, a tiled repeating texture, or
  a procedural noise overlay is a failure of the entire visual concept. If a surface reads as an
  approximation of paper rather than as a photograph of real paper, it is wrong.

## What a critic returns

A JSON object written to `evidence/critics/<cycle>_<name>.json`:

    {
      "critic": "material-truth",
      "cycle": 1,
      "score": 0,              // out of the category's weight
      "floor": 22,             // the floor for this category
      "meets_floor": false,
      "findings": [
        {"severity": "blocking|serious|minor",
         "artifact": "02_chat.png",
         "where": "the top third, behind the notes",
         "what": "one sentence naming what is wrong",
         "why": "one sentence on why it fails the rubric row"}
      ],
      "what_is_working": ["..."],
      "verdict": "one paragraph"
    }

Severity `blocking` means the category cannot exceed its floor while this stands.
