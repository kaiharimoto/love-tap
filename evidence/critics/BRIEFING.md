# What a critic is given

Every critic is a fresh context. It receives three things and nothing else:

1. **The mission goal** — the paragraph below, and nothing about how the thing was built.
2. **The evidence** — the artifacts in `evidence/`, the derived crops in `evidence/crops/`, and
   the capture's own records in `evidence/logs/`, `evidence/frames.json`, `evidence/MANIFEST.json`,
   `evidence/DIFF.json`, `evidence/reliability.json` and `evidence/coldstart.json`.

   Not everything in `evidence/` is one of the seventeen artifacts, and what is not says what it
   is: `crops/` holds derived measurements and one scene that is not an artifact at all
   (`crops/reception*.png` and `logs/reception.json`, which say in the record what they are, on
   what browser, and what they are not). `MANIFEST.json` says which files this capture wrote and
   which predate it — a still that predates the run is a still of an older build, and saying so is
   a finding.
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
between them, then assembled at 62.5 frames a second without re-encoding — which is the rate the
clock is stepped at, sixteen milliseconds a frame, so a clip plays at the speed the app ran. The
timebase of a clip is therefore **the app's time, not the wall clock**: one frame is one step of
the driven clock, and the seconds between two grabs on a wall clock are the harness's cost of
taking the picture, not the app's.

## What a report has to carry about itself

Alongside your score and your findings, `opened` — every artifact, crop and log you opened, by
path — and `not_worth_opening`, for anything in the set you decided your row did not need, with
the reason. A row scored without opening half the evidence is a row scored on half the evidence,
and the only way anyone can tell is if the report says.

## Four logs you can check against the pictures

Three of the logs are measurements taken the way a critic would take them, so they can be checked
against the pictures rather than trusted: `evidence/logs/hand.json` lays every mark of ink on the
thread still over every other and reports how many have a near-twin (a font repeats itself
exactly, a hand a little); `evidence/logs/pwa.json` is what the served page offers an iPhone, read
from the page; `evidence/logs/scroll_webkit.json` is the framework's own per-frame build and raster
cost during the scroll clip, under a headless WebKit with no GPU, one frame per harness step — the
cost of drawing a frame, not a refresh rate; and `evidence/logs/11_chat_scroll.fling.json` is the
thread's own record of that clip — for every frame of every throw, how far the simulation asked the
thread to move, how far it actually moved, and where it was sitting when it did. Each scene log's `load` says whether its load time
was a first launch with the year importing (`store: fresh`) or a phone that already had it
(`store: kept`); the seeded scenes share one browser profile, and only the first is cold.

Five more records are new this cycle, each written because a report last cycle rested on a number
that was not anywhere. `logs/torn.json` measures the profile every torn edge in the rig is built
from — self-correlation past the central lobe, against the two-sine shape it replaced, which is
measured in the same file as a control. `logs/flat.json` takes its floor from the packed library
rather than from one screenshot, and carries the derivation and a negative control. Each scene log's
`load.made_of` breaks the first launch into the framework, the library index, the ink plates, the
desk, the log and the first frame. Each region report may carry `asked_a_motor_for` — every ask the
app made of a vibration motor, with what answered, which on this machine is nothing, because there
is no motor in a browser and no phone in this environment; the ask and the answer are different
things and both are written down. And the chat report carries `replies_on_the_glass`,
`refusals_on_the_glass` and `clipped_at_an_edge`: a delivered reply with the row it answers, the
words the other phone refused in, and any row whose ink is outside the frame.

`logs/lines.json` is a measurement the build makes of itself and does not pass: how far the writing
sits from the ruled line nearest it, as a fraction of the pitch. Nought is on the line, a half is
exactly between two, and writing laid out with no relation to the rules lands uniformly and
averages 0.25. The set reads **0.33**. The same file records a second thing found on the way — the
same ruled stock, printed at eight millimetres a rule, appears at pitches from 61 to 178 pixels
across the ten stills, a ratio of 2.9, because a stock is drawn at whatever scale the piece cut
from it turns out to be. Both are reported and neither is gated; both are named in the builder's
own sheet.

`evidence/frames.json` records, per clip and per run, how many milliseconds each step was worth
(`runs[].step_ms`), the total app time (`app_seconds`) and the ratio of playback to app time
(`playback_over_app_time` — 1.0 means real time, 2.0 means the clip plays at half speed). A
statement about how long something took on screen is a statement in app time, read off those
fields; the wall-clock interval between two grabs (`evidence/logs/<clip>.json`, `steps[].ms`) is
the harness's cost of taking the frame and says nothing about the app.

**A frame a reader sees as held is a fault, and `frames.json` names them.** The test is three
terms at once, on luma, in grey levels: the mean absolute change over the whole frame under 0.5,
the share of pixels changing by more than two under 0.15 per cent, and the busiest 32-pixel tile's
mean change under 2.0. It used to be bit-identity, which a fortieth of a grey level of renderer
noise was enough to pass, so half a second of a frozen sheet counted as motion. `held_frame_test`
in each entry carries the thresholds and the frame that came closest to failing. If your own eye
disagrees with that number on a clip, say so and say where — the check is a floor, not a verdict.

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

## Two rows, one score, and what `blocking` means

Row 04 is read twice: once from the artifacts by the coherence critic and once from the source by
the code critic. `tools/score.py` folds the code reading into coherence and takes **the lower of
the two**, for the same reason it takes the lower of critic and builder — a row cannot be talked up
by whichever reader liked it more. Neither critic needs to know what the other said; the rule is
here so that nobody has to guess at it afterwards.

`blocking` is the severity that caps a category at its floor. It is not a synonym for "bad": a
serious finding is a serious finding. If your row does **not** meet its floor, say in your verdict
which finding is the one holding it there, and mark that finding `blocking`. A review in which
three rows fail their floors and not one finding is marked blocking — which is what the last cycle
produced — leaves the arithmetic and the vocabulary disagreeing, and a builder cannot tell from it
what would have to change for the row to pass.

## The recipe that made an artifact

`evidence/scenes/*.json` is the script each clip and still was shot to: the steps, in order, with
the app's clock stepped between them. It is not one of the artifacts and it is not a claim about
the build — it is the framing. Reading it is how you tell a fault in the app from a fault in how
the picture was taken, and the last cycle's review filed at least one of the second kind as the
first.

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
