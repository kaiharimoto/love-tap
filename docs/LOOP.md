# LOOP — the protocol a firing follows

This build is advanced by an autonomous loop: a scheduled Routine fires a fresh session, that
session executes **exactly one stage**, commits and pushes what it did, writes down where it got
to, and stops. Nothing is remembered between firings except what is in git, so everything a
successor needs is written down here or in `loop/STATE.json`.

`CLAUDE.md` carries the rules that hold in every stage. This file carries the machine.

## How a firing is actually delivered

This took four wrong designs to get right and every one of them looked plausible, so the dead ends
are written down here rather than left to be rediscovered.

A Routine can target a session three ways: mint a fresh one, wake a named other one, or wake the
one that created it. Only the third works for this loop.

| what was tried | why it failed |
|---|---|
| Routine mints a fresh session, which pushes | A minted session gets `sources: []`. The egress proxy injects a push credential only for a session's attached sources, so `git push` returns a deterministic 403. The first firing cloned the repo — public, so readable — worked seven minutes, committed, could not push, and lost it all when the container was reclaimed. |
| The minted session attaches the repo itself | It has no MCP tools at all. A probe instructed to call `add_repo` and then push landed nothing; a second probe instructed to call `create_session` produced no session and returned in eight seconds. |
| Routine wakes a named persistent orchestrator | The orchestrator's container had been reclaimed and the wake never re-provisioned it. Fired at 22:20; the session's `updated_at` never moved off its creation turn, and the Routine recorded no `last_run` at all. |
| **Routine wakes the session that created it** | **Works.** A self-bound wake was delivered on time to a live session. |

So the loop is a **dispatcher session plus a fresh worker per firing**:

    Routine (cron)  ->  dispatcher = the session that created the Routine
                            ->  worker = create_session with source_url,
                                source_revision and outcome_branch set

`create_session` *can* attach a repository, which is the asymmetry the whole design rests on. A
worker made that way has `sources` populated and pushes on its first attempt.

Two consequences, both already paid for:

- **A firing proves it can push before it does any work** (`git push --dry-run`) and stops dead if
  it cannot. Forty-five minutes of capture that cannot be pushed is forty-five minutes thrown away.
- **A Routine's run status is not evidence of progress.** `list_triggers` reported
  `last_run: SUCCEEDED` for the firing that lost everything: it records delivery, not
  accomplishment. Only a commit on `origin` counts, so every push is confirmed by comparing `HEAD`
  to `origin/<branch>` after a fetch.

### What will eventually need attention

The dispatcher is a real session with a real context window, and every firing adds a little to it.
Its prompt is therefore deliberately tiny — spawn one worker, report one line, never read the
repository. When it does fill, or if it is archived, the loop stops silently: the fix is to create
a Routine from a new session the same way, which is two calls, and nothing is lost because
`loop/STATE.json` holds all the state. A dispatcher that has stopped firing shows up as a branch
with no new commits, which is worth checking for if a day passes quietly.

## The five stages

The owner asked for diagnose, address, design and implement. Stage 0 exists because this repo's
whole discipline is that a measurement beats an assertion, and a diagnosis made from stale
artifacts is an assertion with a number attached.

```
      ┌──────────────────────────────────────────────────────┐
      ▼                                                      │
  0 OBSERVE → 1 DIAGNOSE → 2 ADDRESS → 3 DESIGN → 4 IMPLEMENT ┘
```

| stage | profile | what it does | done when |
|---|---|---|---|
| **0 OBSERVE** | capture | `tools/apt-prereqs.sh`, `bootstrap.sh --profile=web`, build, `./capture.sh`, then `tools/check/*` and `tools/check/legibility.py` and `tools/check/palette.py` | the artifact set is fresh against this commit, or the ladder bottomed out |
| **1 DIAGNOSE** | none | write `evidence/critics/<n>/builder.json` **first**, then run the seven critics as fresh contexts in parallel, then `python3 tools/score.py --cycle <n>` | every category has a critic score and `score.py` accepts the arithmetic |
| **2 ADDRESS** | none | turn findings into an ordered queue in `loop/STATE.json`. **No code changes in this stage.** | every queue item names the measurement that will close it **and that measurement is anchored to something the app declares** — a surfaces rect, an event id, a playhead, a `says` string — never an absolute pixel coordinate or a frame ordinal. `loop/WORKER_PROMPT.md` §3d is the rule and why it exists |
| **3 DESIGN** | none | the design authority, below. Only when design state is stale. | a verdict is recorded and frozen |
| **4 IMPLEMENT** | app | drain the queue in order, one commit per item | queue empty → `cycle += 1`, back to OBSERVE |

**One stage per firing. Never two.** A stage has one toolchain profile, one kind of output and one
definition of done; mixing two is how a firing runs out of context halfway through both.

IMPLEMENT spans as many firings as the queue needs. A firing that is running low writes its queue
progress back, commits, pushes and stops. The next one picks the stage up where it was left.

## The order, and why ADDRESS sits before DESIGN

Triage first, so the design authority is handed the measured problems — the contrast numbers, the
palette report, the critics' findings — instead of being asked to have an opinion in a vacuum.

## The design authority (stage 3)

The owner has granted this stage **full authority, including replacing the desk and paper
metaphor**, and including amending `DIRECTION.md` and the brief's anti-goals. Use it carefully;
it is not a licence to rewrite the law every time a score disappoints.

Run it as a fresh-context subagent briefed as a senior art director and colour specialist. Give it
the artifacts, the 300% crops, `evidence/legibility.json`, `evidence/palette.json`, the owner's
own words — *"the desk was giving me visibility issues with text and it doesn't evoke cuteness to
me, I need a strong visual design (colour theory) guidelines and an expert perspective"* — and
`docs/BRIEF.md`. Do **not** give it `DIRECTION.md` on the first pass, so it forms an independent
judgment before it reads the rationale it may have to overturn.

It produces three things:

1. **`docs/COLOR.md`** — the colour law, stated in numbers a tool can check, not a swatch list:
   the lightness ladder and which steps are reserved for ground, mid and figure; the hue families
   and their angular relationships; a chroma ceiling per lightness band, which is how
   `DIRECTION.md`'s "nothing emits light" survives as something measurable; the contrast floors,
   per light condition; and the charm axis defined concretely enough to be scored.
2. **A verdict on the desk** — *keep and retune*, or *replace*. Either way it goes into
   `DIRECTION.md`'s decisions log, dated, with the measurement that forced it.
3. **Queue items** that carry the law into the code, each with its measurement.

**A `replace` verdict may not delete a single asset until its migration path is written down** —
what replaces the 103 MB under `assets/`, what happens to the eight tests that enforce the current
language, and what the point cost is in `material_truth` and `anti_goal`. Assets go only after
their replacement measures better.

**Freeze.** Every amendment sets `design.frozen_until_cycle = cycle + 3`. Inside that window the
authority may not reverse its own decision unless a measurement contradicts it, and the reversal
has to cite that measurement. A design authority that may rewrite the law every firing will
rewrite the app every firing and the build will never converge.

## `loop/STATE.json`

The one file that decides what a fresh session does. Read it before anything else.

| field | meaning |
|---|---|
| `cycle`, `stage`, `firing` | where the loop is. `firing` increments on every firing, including one that achieved nothing. |
| `stage_entered_at_firing` | how long this stage has been running, in firings |
| `lease` | `{session_id, started_at, expires_at}`. A firing that finds a **live** lease writes one journal line and exits — this is what stops a cron fire from landing on top of a firing that is still going. A firing that finds an **expired** one returns every `in_progress` item to `open`, `attempts += 1`, and records that it was abandoned. |
| `evidence_fresh_as_of` | the commit the artifacts were captured from. DIAGNOSE refuses to score if `app/`, `assets/` or `seed/` have changed since. |
| `degradation` | 0–4, which rung of the ladder the last firing reached |
| `design` | `verdict`, `decided_at_cycle`, `frozen_until_cycle` |
| `queue[]` | `{id, why, measurement, state, closed_by, attempts}` |
| `blocked` | `{reason, since_firing, what_would_unblock}` or null |
| `asks[]` | things only the owner can clear. **These never block the loop.** |
| `last_score`, `history[]` | for detecting a stall or a regression |

Two rules keep it honest:

- **A queue item closes only against its named measurement, and the measurement must be anchored
  to something the app declares.** A claim with no measurement is rejected; the item goes back to
  `open` and `attempts += 1`. A measurement written as an absolute pixel box or a frame ordinal is
  not a ruler for a defect that can move — three of cycle 3's green numbers were pointing somewhere
  else. `loop/WORKER_PROMPT.md` §3d carries the rule, the three cases and the two corollaries.
- **`attempts >= 3`** moves the item to the back of the queue, sets `blocked` with what would
  unblock it, and the loop carries on. It does not spin on one thing.

## The degradation ladder

A firing records the rung it reached in `degradation`, so the next one knows what the last one
could actually do.

| L | when | what runs |
|---|---|---|
| 0 | normal | `tools/apt-prereqs.sh` → `bootstrap.sh --profile=web` → build → `./capture.sh` → all checks |
| 1 | disk under 8 GB before capture | `rm -rf toolchain/downloads evidence/frames app/build`, retry once. Deleting `downloads` is safe: the `.done` markers mean nothing re-fetches. |
| 2 | capture still failing | `./capture.sh --only=<scene> --no-build` over the heroes — `01_pulse 02_chat 04_moments 06_unfolding 13_messenger_states`. Mark the set partial; DIAGNOSE may run on a partial set only if the heroes are fresh, and the builder sheet must say so. |
| 3 | no browser at all | `flutter analyze`, `flutter test`, the static checks, and `legibility.py`/`palette.py` over the *committed* stills. Do **not** advance to DIAGNOSE. Re-queue OBSERVE and spend the rest of the firing on IMPLEMENT. |
| 4 | no toolchain | documentation, design and tool-writing only, against committed evidence. **Do not score a cycle.** |
| 5 | three consecutive failures of one stage | write it into `loop/ESCALATIONS.md`, set `blocked`, and pin the loop to stages that can still progress. The build keeps moving; it just stops being able to measure itself, and says so. |

`capture.sh` **exits 0 even when artifacts are missing** — it records them in
`evidence/MANIFEST.json` and `evidence/frames.json` instead. Never read its exit code as success;
read the manifest.

## Committing

Push after every completed item, not once at the end of a firing. A container can die at any
point and nothing uncommitted survives it — a fresh session gets a fresh clone.

Commit messages are prose sentences, the way the existing log is: *"A feeling arriving is an object
landing, not a word in blue script."* Not `fix:`, not a ticket number. Add a trailer naming the
item so the log can be walked:

    Loop-Cycle: 3
    Loop-Stage: implement
    Loop-Item: moments-lazy-gallery

Before any commit: `cd app && flutter analyze && flutter test`, plus whatever check the item named
as its measurement. A failing gate reverts the item; it does not get pushed.

## When the loop stops

Terminal state: total at or above `tools/score.py`'s `EXIT` (114 of 120), **and** all six floors
met, **and** every artifact either present or recorded as environmentally impossible. On reaching
it, write it into `TASK_STATE.md`, set `stage` to `MAINTAIN`, and drop the Routine's cron to weekly
via `update_trigger`, where a firing only re-captures, re-scores and fixes regressions. Do not
delete the Routine — the run history is worth keeping.

Note the ceiling honestly: `09_two_devices.png` is a designated hero and a brief exit condition,
and it cannot be produced without `/dev/kvm`. The loop can meet every floor it is able to meet and
still not be able to declare completion. That belongs in `asks[]` from the first firing.
