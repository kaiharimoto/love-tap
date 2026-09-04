# What a critic is given

Every critic is a fresh context. It receives three things and nothing else:

1. **The mission goal** — the paragraph below, and nothing about how the thing was built.
2. **The evidence** — the artifacts in `evidence/`, and the derived crops in `evidence/crops/`.
3. **Its own rubric row**, quoted in full.

It never receives the build history, the plan, the commit log, the task list, or any explanation
of why something is the way it is. If a thing cannot be seen in the evidence, it does not exist
as far as a critic is concerned, and a critic saying so is the finding.

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
