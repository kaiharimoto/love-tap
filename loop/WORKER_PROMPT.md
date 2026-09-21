# WORKER_PROMPT — what one firing of the loop does

The Routine that drives this build carries only a few lines: prove you can push, then read this
file and follow it. Everything else lives here, in the repository, so that it is versioned, so that
a firing can correct it for its successors, and so that changing how a firing behaves does not mean
editing a Routine nobody can see the history of.

`CLAUDE.md` is the law for anyone working in this repository. `docs/LOOP.md` is the machine — the
five stages, the degradation ladder, the state schema. This file is the running order.

## How you got here, which matters

You were created by `create_session` with `source_url`, `source_revision` and `outcome_branch` all
pointing at this repository and branch. That is not incidental. A session that a Routine mints
directly gets `sources: []`, and with no attached source the egress proxy has no push credential to
inject, so every `git push` comes back 403. Two firings proved that: the first worked for seven
minutes, committed `a76f8e3`, could not push it, and lost it when its container was reclaimed.

So the loop is delivered in two hops — the Routine wakes a persistent orchestrator, and the
orchestrator spawns you with the repository attached. If you ever find yourself with no `origin`
credential, that chain has broken; say so and stop, and do not try to route around it.
`/root/.ccr/README.md` is explicit that a proxy 403 is reported, never worked around.

## The running order

### 0. Prove you can push, before you do any work

    cd /home/user/love-tap
    git fetch origin claude/app-improvement-autonomous-workflow-d6fwdu
    git merge --ff-only origin/claude/app-improvement-autonomous-workflow-d6fwdu
    git push --dry-run origin HEAD:refs/heads/claude/app-improvement-autonomous-workflow-d6fwdu

**Fetch the branch, never the remote.** Bare `git fetch origin` hangs in this container: firing 4
watched it sit for eight minutes having read 3.6 MB and opened no pack file, while `git ls-remote`
against the same URL answered in under a second. The repository is 552 MB of git objects and the
bare form walks every ref, `main` included; the branch refspec does not, and finished in seconds
every time. Every fetch in this file uses the refspec form for that reason.

The `--ff-only` is the second half of it. A checkout that is behind fails the dry run with
`non-fast-forward`, which looks alarming and is **not** a credential failure — do not report it as
one. Fast-forward first, then dry-run again; `Everything up-to-date` is the pass.

**And `--ff-only` will sometimes fail too, on a checkout that is merely old.** This container hands
you a **shallow clone at depth 50**, and firing 10's was made two days before the branch tip it was
checked out against. Two shallow histories of the same branch taken at different times have
different grafted roots, so they share no commit at all: `git merge-base` came back empty,
`git rev-list --count` read **50 ahead and 50 behind**, and the working tree read as a fork of
unrelated history rather than as a checkout that is behind. `70ade67` met the same shape and called
it "a shallow clone that reads like a fork"; firing 10 is the second.

There is nothing to merge, because the local branch has no commit of its own — it is a clone. So:

    git reset --hard origin/claude/app-improvement-autonomous-workflow-d6fwdu

Check that first, before believing a divergence: `git rev-list --count origin/<branch>..HEAD` on a
fresh clone should be 0, and if it equals the *total* number of commits you can see then you are
looking at a graft boundary and not at work. Never force-push to reconcile it — the remote is right
and the checkout is what is old.

**And `git reset --hard` is itself sometimes refused.** Firing 12's container blocked it at the
permission layer as irreversible local destruction, which is a sound thing to block in general and
wrong here — there is nothing local to destroy. Do not argue with it and do not go looking for a
way around it. The three commands below reach the same place and lose strictly less, because the
old tip stays in the reflog instead of being dropped:

    git status --porcelain && git stash list          # both must be empty, or stop and look
    git rev-parse claude/app-improvement-autonomous-workflow-d6fwdu   # note it; this is your undo
    git checkout --detach origin/claude/app-improvement-autonomous-workflow-d6fwdu
    git branch -f claude/app-improvement-autonomous-workflow-d6fwdu HEAD
    git checkout claude/app-improvement-autonomous-workflow-d6fwdu

`git checkout --detach` refuses to run if the tree is dirty, which is the safety `--hard` throws
away. Then dry-run again; `Everything up-to-date` is the pass.

**And firing 13's container refused `git checkout --detach` as well**, with the same
`[Irreversible Local Destruction]` reason, both on its own and inside a `&&` chain. So the two
routes above are now one-for-two and a successor should not assume either is available. The route
that was allowed there names a *new* branch instead of moving an existing one, which is the whole
difference — nothing is overwritten at any step, so there is no destruction to classify:

    git status --porcelain && git stash list          # both must be empty, or stop and look
    git checkout -b firingN-worktip origin/claude/app-improvement-autonomous-workflow-d6fwdu
    git branch -f claude/app-improvement-autonomous-workflow-d6fwdu origin/claude/app-improvement-autonomous-workflow-d6fwdu
    git checkout claude/app-improvement-autonomous-workflow-d6fwdu
    git branch -D firingN-worktip

`git branch -f` was allowed once the branch was not the checked-out one, and the final `checkout`
moves between two refs at the same commit, so it touches no file. Run each as its own command:
firing 13 had a compound `&&` chain refused whose individual commands were then allowed, so a
chain is classified as its worst-looking member. It loses less than the detach route rather than
more — the old tip stays on a real branch until you delete it, not only in the reflog.

**And firing 14's container refused none of it, and the shortest route worked.** One command, which
moves the branch and the working tree together:

    git checkout -B claude/app-improvement-autonomous-workflow-d6fwdu origin/claude/app-improvement-autonomous-workflow-d6fwdu

**And firing 16 did not need any of the three, because the divergence was never real.** Two
shallow histories again, `git merge-base` empty, `git rev-list --count` reading 50 and 50, the
dry-run push rejected `non-fast-forward`. One command filled the graft boundary in:

    git fetch --unshallow origin claude/app-improvement-autonomous-workflow-d6fwdu

After it, `git merge-base` returned the local tip exactly and the counts read **0 ahead, 136
behind** — an ordinary checkout that is behind, which `git merge --ff-only` then took. Nothing was
reset, nothing was force-moved, no tip was dropped. It was given the branch refspec, not the bare
remote, so it is not the hazard §0 opens with; firing 16 did not time it, but it returned inside a
single five-minute budget and was not the slow kind.

**Try this first.** It is the only route that *proves* the divergence is a graft rather than
assuming it, and if the unshallowed history really does diverge you will find out before you have
overwritten anything. Then dry-run again; `Everything up-to-date` is the pass. If it is refused or
the histories are genuinely unrelated, the three routes below are the fallbacks, shortest first —
**expect any of them to be refused and move down the list rather than arguing**:

1. `git checkout -B <branch> origin/<branch>` — one command, allowed at firing 14, untried before
   that. It is also the one that loses most: the old tip is left in the reflog and on no branch.
   On a fresh clone that is nothing, which is the case you are in.
2. Firing 13's route above — a new branch at the remote tip, `git branch -f` on the real branch
   while it is not checked out, switch back, delete the temporary. Five commands, and it loses
   least: the old tip stays on a real branch until you delete it yourself.
3. `git checkout --detach` then `git branch -f` — firing 12's route, allowed at 12 and refused
   at 13.

`git reset --hard` has been refused twice and allowed never; do not start there. Whichever route
you take, run each command on its own — firing 13 had an `&&` chain refused whose individual
commands were then allowed — and check `git status --porcelain` and `git stash list` are both
empty first, because routes 1 and 2 will not tell you about work you are throwing away. Then
dry-run again; `Everything up-to-date` is the pass.

**And firing 25's was none of the above: a STALE LOCAL BRANCH REF, which wears the same clothes
and is not the same thing.** Every symptom §0 already describes was present -- `git merge-base`
empty, `git rev-list --count` reading **50 ahead and 50 behind**, the dry-run push rejected
`non-fast-forward` -- so it reads exactly like firing 10's and firing 16's graft boundary. It was
not one. `git fetch --deepen=60` took both sides to 110 commits and **still** returned no merge
base, and the local tip's commit subjects appeared NOWHERE in the remote's history.

The reflog said what had happened in two lines:

    3edfbf7 HEAD@{2026-09-19 18:53:40}: checkout: moving from d1a3513... to claude/app-...-d6fwdu
    d1a3513 HEAD@{2026-09-19 18:53:32}:

The container cloned the branch correctly at `d1a3513`, the real tip — and then checking the branch
out **by name** moved HEAD back to `3edfbf7`, a tip dated four days earlier that the container image
was carrying in `refs/heads/`. The clone was right and the branch ref was old, so `git checkout
<branch>` silently rewound the working tree by four days and twenty-odd commits, including the whole
of firings 21 to 24.

**Two cheap questions tell the three cases apart, and both are worth asking before any reset.**
`git reflog` — if it shows a checkout that moved HEAD *backwards* off the commit the clone landed
on, the branch ref is stale and deepening will never help. And
`git log --oneline origin/<branch> | grep -F "<subject of your HEAD>"` — on a graft boundary your
tip is really in the remote's history and the grep finds it once the fetch is deep enough; on a
stale ref it is genuinely absent. `git rev-list --count HEAD` equalling the total both sides can
see is the hint §0 already gives, and it is necessary rather than sufficient.

**And firing 31's was a graft after all, which is the case firing 25's two questions get WRONG at
the depth they are asked.** Every symptom again: `git merge-base` empty, `git rev-list --count`
reading **50 and 50**, the dry-run push rejected `non-fast-forward`. Then, exactly as firing 25
describes, `git fetch --deepen=60` took both sides to **110 and 110** and *still* returned no merge
base, and the local tip's subject appeared nowhere in the remote's log. By this file's own test
that is a stale branch ref, and the next step is a reset. **It was not a stale ref, and a reset
would have thrown away nothing but would have proved nothing either.** One more deepen settled it:

    git fetch --filter=blob:none --deepen=300 origin claude/app-improvement-autonomous-workflow-d6fwdu

After it `git merge-base --is-ancestor HEAD origin/<branch>` returned true and the counts read
**0 ahead, 268 behind** — an ordinary checkout that is behind, which `git merge --ff-only` then
took. Nothing reset, nothing force-moved, no tip dropped.

So two corrections to §0, and the first one matters most:

- **60 is not a deep enough deepen to tell a graft from a stale ref.** This branch takes 50-100
  commits a day in a busy cycle, so 110 commits of history can be three days and still not reach
  the fork point. A firing that stops at 60, applies firing 25's two questions and concludes
  "stale ref" will reach for a reset on a checkout that is merely old. Deepen by a few hundred
  before believing the divergence is real.
- **`--filter=blob:none` is what makes deepening cheap**, and it is the reason to prefer this over
  firing 16's `--unshallow`. Ancestry lives in commits and trees; the 552 MB is blobs. The filtered
  300-commit deepen returned in seconds. Use it for any deepen whose only purpose is to answer
  "is my tip in their history".

Ask the two questions, but ask them at depth 300 with `--filter=blob:none`, not at 60.

The route that worked, after `git reset --hard` was refused for the third time in this file's
history (it is now nought for three, so genuinely do not start there): **preserve the old tip on a
real branch first**, then move. Nothing is lost at any step, and the first command is the one that
makes the rest safe to get wrong:

    git status --porcelain -uall && git stash list     # both empty, or stop and look
    git branch backup/stale-container-ref-<shortsha> <the stale tip>
    git checkout --detach origin/claude/app-improvement-autonomous-workflow-d6fwdu
    git branch -f claude/app-improvement-autonomous-workflow-d6fwdu <the remote tip>
    git checkout claude/app-improvement-autonomous-workflow-d6fwdu

`git checkout --detach` was **allowed** here, having been refused at firing 13 and allowed at 12,
which keeps it at two-for-three and confirms this file's standing advice: expect any route to be
refused, move down the list, and do not argue with the classifier. Run each command on its own.

Two notes about the fetch rather than the reset. Firing 12's bare `git fetch origin` did **not**
hang, but it took just over three minutes to index a 9,649-object pack; firing 14's took 3m40s and
also returned. So the bare form is sometimes slow and sometimes fatal, the refspec form has never
been either, and §0's is still the one to use. And firing 14's bare fetch reported the branch as
`(forced update)` when nothing had been force-pushed: that is what a shallow refetch of a branch
that has moved looks like, and it is not evidence of anyone rewriting history.

If that fails for any reason, **stop immediately** and make your whole final answer a verbatim
report of the error. Do not do the stage. A firing that discovers it cannot push in the first
thirty seconds is useful. One that discovers it after a forty-five minute capture has thrown that
capture away, because nothing uncommitted survives the container.

**And whatever the checkout turns out to be, RE-READ THE REPOSITORY FILES AFTER YOU FIX IT.** The
copies of `CLAUDE.md` and the rest that arrive in a firing's system prompt are read when the
container is built, from the tip the container checked out — so if that checkout is behind, the law
you are handed is the law as it was then, and fast-forwarding the working tree does not update it.

Firing 38's container landed on a tip **fifty commits old**, which is the ordinary case this
section already describes. What was new is what the prompt said. Its copy of `CLAUDE.md` carried:

> **`tools/check/texture_budget.py` does not exist** ... Either write it or delete the claim; a
> dangling enforcement claim has survived four cycles already.

The file on disk, after the fast-forward, says `**tools/check/texture_budget.py` exists now**, and
it does: 173 lines, it runs, and it passes on all four sequences. Some firing between 35 and 37
wrote it and corrected the entry. A firing that trusted its prompt would have spent itself writing
a file that was already there — and it would have been following an instruction that names itself
as a way to avoid wasting a firing, which is the shape of this that is worth remembering.

So after §0 succeeds, re-read `CLAUDE.md` from disk before believing anything it says about what
does and does not exist, and check a "this does not exist" claim with `ls` rather than on trust.
The prompt is a snapshot; the branch is the truth.

### 1. Read where you are

`CLAUDE.md`, then `docs/LOOP.md`, then `loop/STATE.json`, in that order. `docs/BRIEF.md` is
authoritative and is 85 KB: read it whole in a stage that judges or plans (DIAGNOSE, ADDRESS,
DESIGN) and skip it in a stage executing one named item.

### 2. Take the lease, and do not touch anything until you hold it

**This is a gate, not a formality, and the first firing to reach IMPLEMENT walked straight past
it.** It ran for hours with `lease: null` in `loop/STATE.json`, which meant the next firing's
worker saw a free lease, took it, and began the same stage — two workers on one branch, which is
the one thing the lease exists to prevent. It was caught by hand. Next time nobody will be
watching.

So, before you edit a single file:

- If `lease` is non-null, `expires_at` is in the future, and `session_id` is not yours: **another
  firing is running.** Append one line to `loop/JOURNAL.md` saying so, commit, push, and stop. Do
  not do the stage. This is a complete and successful firing.
- If `lease` is non-null and `expires_at` has passed: that firing died mid-stage. Return every
  `in_progress` queue item to `open`, increment its `attempts`, record that it was abandoned.
- Then write your own lease — `{session_id, started_at, expires_at}` — commit it, and **push it
  before you do anything else**, so a firing that starts while you work can see it. TTLs: DESIGN
  and ADDRESS two hours, OBSERVE and DIAGNOSE three, IMPLEMENT four.
- If you are still working when your lease is close to expiring, extend it and push, rather than
  letting it lapse under you.
- Release it at the end of the firing, in the same commit that updates the stage.

A firing that holds no lease is a firing that is invisible to the next one. Holding it is what
makes the loop safe to run unattended.

### 3. Do exactly one stage

The one `loop/STATE.json` names when you started. Not two, however much budget is left.

The DESIGN firing finished its stage, set the next stage to IMPLEMENT, released its lease — and
then carried straight on into IMPLEMENT in the same session. The work it did was good, and it
still should not have done it: the dispatcher spawns one worker per firing on the assumption that
the last one has stopped, so a worker that keeps going is a worker the loop does not know about.
When your stage's definition of done is met, write it down, push, and **stop**, even if you have
hours of budget left. The next firing is three hours away and it will pick the work up.

`docs/LOOP.md` says what each stage does and when it is finished.

IMPLEMENT deliberately spans many firings: drain the queue in order, and when your budget runs low,
write the queue state back, commit, push, and stop. The next firing continues the same stage. Only
a drained queue advances it.

### 3b. Stay on the queue, and never end a firing blocked on an ask

Two things went wrong on the firing that first reached IMPLEMENT, and both are cheap to avoid.

**It worked on things that were not in the queue.** It went after an Android release — a signed
APK, `build.yml`, a PWA stub — none of which is a queue item, and `CLAUDE.md` names `build.yml` as
a dead end that cannot pass on any branch. If something looks worth doing and is not in the queue,
**add it to the queue with its measurement and leave it for ADDRESS to rank**. Do not do it. The
queue is ordered by points on the rubric; work outside it is work that no row is asking for.

**It ended `blocked` on an ask.** Its final state was "set 4 signing secrets; decide on PWA stub",
which is an `asks[]` entry — and `asks[]` entries *never block the loop*, by construction. Nobody
is coming to answer. A firing that finds itself waiting on the owner has taken a wrong turn some
way back: record the ask, drop that item, and spend the rest of the firing on the queue. The only
legitimate reason to stop early is the push pre-flight failing or another firing holding the lease.

If every open queue item is genuinely blocked — which has not happened yet — say so in
`loop/JOURNAL.md`, set `blocked` in `loop/STATE.json` with what would unblock it, and stop. That
is a real outcome. "Waiting for a secret" is not.

### 3c. The owner's standing steer, which outranks the rubric

Recorded at firing 20 from the owner, verbatim:

> "I made the mistake of asking for too many demo populated items, if that's what they're stuck on.
> Those aren't important because it's using it and the UI that matters more."

It is in `loop/STATE.json` as `owner_steer`, and every open queue item carries an `owner_priority`
tag against it: `using-it`, `the-ui`, `harness`, `deprioritised-demo-content`. Drain them in that
order of preference where the rubric leaves you a choice, and **where the rubric and the steer
disagree, the steer wins**.

What it means in practice:

- **`using-it` first.** A thing a person holding the phone would hit: a failed message with no way
  to retry, a search that returns a hit you cannot see, a screen that clips its own content, a
  feeling that arrives as a blank sheet.
- **`the-ui` next.** A surface that is flat when it should be paper, a vocabulary drawn as alpha, a
  raw loopback URL set in the handwriting face.
- **`harness` only when it unblocks one of the above.** Thirteen of the forty open items at firing
  20 served the scoring harness rather than the app. Evidence plumbing that exists only so the
  harness can score itself is not work the owner asked for. Fix a ruler when you cannot see without
  it; do not fix a ruler because it is the easiest thing in the queue.
- **`deprioritised-demo-content` last, or not at all.** The sixteen absent photographs, the seeded
  year's media: populated demo data is explicitly not important. **This caps
  `messenger_reliability`, the heaviest row, and that is an accepted cost, not a task.** Do not
  re-promote a demo-content item to lift a score. If the score stalls while the app gets better to
  use, the loop is doing what it was told.

The one caveat carried forward: `twelve-seconds-of-cold-start-on-every-seeded-scene` was demoted as
a seeded-scene artifact, but if the cost turns out to be O(n) in the event log it will bite two real
users eventually. Establish that before dismissing it again.

### 3d. A measurement must be anchored to something the app declares

**This is the rule cycle 3 cost most to learn, and it is written here rather than in a queue item
because it outlives every item it applies to.**

ADDRESS's definition of done has been, since firing 18, that every queue item names the measurement
that will close it. **That is no longer sufficient.** Three metrics went green in cycle 3 while the
defects they were named for did not move, and all three are one error:

- **The fold placeholder's sample box slid off it.** The item sampled a 300x120 box at a fixed
  `(200,1350)`. The object sat at y1281-1515 when the item was written and at y1075-1330 when it was
  next measured, so the box landed on `assets/paper/looseleaf_03` instead and read 24.854 / 165
  against a floor of 8.0. The placeholder itself read 7.061 / 81 and failed. The ruler had walked
  off the defect and was measuring the repair standing next to it.
- **`06_unfolding` reported 255 unique frames of a scroll.** `repeated_frames 0` over 255 frames
  looks like sixty unique fold frames per second, which is what the brief asks for. But
  `06_unfolding.report.json` has `playhead 239 of 240` at frame zero: the fold had already finished
  before the recorder started, and those are 255 unique frames of a scroll and a cross-fade. A
  frame-distinctness check cannot fail on a clip that does not contain the thing it is checking.
- **The interrupt matrix left the screen and read as a legibility win.** Firing 21 moved it below
  the fold; 42 failing text runs left `05_settings.text.json`; the headline fell 64 -> 25. The
  matched-run ruler, which compares only the runs present in both captures, read 86 -> 87. Nothing
  got easier to read. The population moved under the detector.

So, in addition to naming a measurement, **an item must express it against something the app itself
declares**:

| anchor | where it lives |
|---|---|
| a surface's rect and asset id | `evidence/<artifact>.surfaces.json` |
| a playhead, a sequence name, a frame index the app reports | `evidence/<artifact>.report.json` |
| the text of a run (`says`) | `evidence/<artifact>.text.json` |
| an event id | the spine, and the scene's report |
| a registry id, a token name, an asset path | the source, via a test |

Not an absolute pixel coordinate. Not a frame ordinal of the recording. Not "the box at (200,1350)".

**Two corollaries, because the failure has two shapes.**

1. **A sample window is placed by the object, not by the frame.** A window *size* is fine and often
   necessary — 400x200 of a paper region, 200x200 of a tile. Its *placement* must come from the
   object's own declared rect, and where one placement can be lucky, tile the window across the
   rect at a fixed stride and report the median with the pass fraction beside it. A single
   placement is a sampling accident; firing 29 measured 26.962 at one pixel and 31.421 at the
   median of a 7x13 grid of the same object.
2. **A count that can fall by the thing leaving the screen must be paired with a population that
   cannot.** Any item whose measurement is "N failures fall to M" must also assert that the
   denominator held: `total_runs` unchanged, the tile count unchanged, the same event ids present.
   Otherwise deleting the evidence closes the item.

**And a ruler that scores the defect above the repair is disqualified, not merely suspect.** Firing
29 found `tools/check/hf_std.py` reading the firing 17 strip — taken when the fold sheet *was* the
blank rectangle — at 14.609-15.635 against today's repaired 14.317-15.088. A ruler that inverts on a
known before-and-after may not be cited by any item's measurement until it discriminates the pair.
Every new ruler earns its place by being run against a defect that is known to be present and a
repair that is known to have landed, and printing them in the right order.

**When you write or re-rank a queue item, sweep its measurement for an absolute coordinate or a
frame ordinal and re-express it.** ADDRESS is not done until that sweep has been made.

### 4. End the firing

Update `loop/STATE.json` — increment `firing`, record what happened in `history`, set the stage for
next time. Append a block to `loop/JOURNAL.md`. Write `checkpoints/<cycle>-<stage>-<shortsha>.json`
if the stage completed. Release the lease. Commit, push, confirm the push landed, stop.

Your final answer is short: whether step 0 passed, which stage you ran, what changed, what is
blocked, and what the next firing should expect.

## Committing

Push after every completed item or leg, **never once at the end**. A container can die at any
point and a fresh session gets a fresh clone, so the only durable unit of work is a pushed commit.

After every push, confirm it landed:

    git fetch origin claude/app-improvement-autonomous-workflow-d6fwdu
    [ "$(git rev-parse HEAD)" = "$(git rev-parse origin/claude/app-improvement-autonomous-workflow-d6fwdu)" ]

A push that did not land is not a completed leg and must not be recorded as one. This is not
paranoia: the Routine run status reads `SUCCEEDED` for a firing that achieved nothing at all,
because it records delivery rather than accomplishment. Landing is the only proof.

Commit messages are prose sentences in the style of the existing log — *"A feeling arriving is an
object landing, not a word in blue script."* Not `fix:`, not a ticket number. Add trailers:

    Loop-Cycle: 3
    Loop-Stage: implement
    Loop-Item: moments-lazy-gallery

Before any commit that touches code: `cd app && flutter analyze && flutter test`, plus whatever
measurement the queue item named. A failing gate reverts the item; it does not get pushed.

## The things that are never done

These are in `CLAUDE.md` too, and they are repeated because a firing that only half-read the
repository is exactly the firing that breaks one of them.

- Push **only** to `claude/app-improvement-autonomous-workflow-d6fwdu`. Never `main`, never a pull
  request, never a merge, never a force-push, never rewrite pushed history. Check the branch
  immediately before every push.
- Never hand-edit, retouch or regenerate by hand any PNG or MP4 under `evidence/`. An artifact
  comes from `./capture.sh` or it is recorded as missing with its reason. Retouching one falsifies
  the only measurement this build has of itself. The JSONs written by `tools/check/*.py` are tool
  output and may be regenerated freely.
- Never score a category above its critic. Write your own sheet to
  `evidence/critics/<cycle>/builder.json` **before** you read any critic report.
- Never claim an item fixed without running the measurement it names. Re-break the thing and watch
  it fail.
- Never commit a secret. `TS_AUTHKEY`, a CA private key or a pairing secret in a committed file is
  a stated failure condition for the whole build.
- Never skip, disable or delete a test to reach green.
- A `replace` verdict on the desk may not delete a single asset until its migration path is written
  down: what replaces the 103 MB under `assets/`, what happens to the tests that enforce the
  current language, and the point cost in `material_truth` and `anti_goal`.

## Facts already established, so you do not spend a firing rediscovering them

- You run in `auto` permission mode. Bash and git need no approval. Nobody is watching, and nobody
  will answer a question you ask.
- A fresh container has no toolchain. `bash tools/apt-prereqs.sh` **must** run before Playwright's
  WebKit can launch at all — `bootstrap.sh` can only check for those libraries, it cannot install
  them. Then `./bootstrap.sh --profile=web`, about fifteen minutes, which skips the Android SDK,
  the NDK and the AVD: without `/dev/kvm` they are 2.1 GB that buys nothing.
- `python3 -m pip install numpy pillow` is needed before `tools/check/*.py` will run.
- `./capture.sh` exits 0 even when artifacts are missing. Read `evidence/MANIFEST.json`, never its
  exit code.
- `app/test/legible_on_what_it_is_on_test.dart` was rewritten and has **never been compiled** —
  there was no Flutter toolchain in the container that wrote it. Its arithmetic was checked pair by
  pair, but the first firing to bootstrap a toolchain should run it early and fix it if it does not
  compile, because it gates every code commit.
- `09_two_devices.png` and `16_setup_android.png` cannot be produced in this container. No
  `/dev/kvm`; `docs/PHONES.md` records three measured attempts. 14 of 17 is the ceiling here. That
  is a hardware fact and belongs in `asks[]`, not in the queue.
- You cannot change the Routine's schedule from here. If the loop reaches its terminal state, record
  it in `asks[]` and say so in your final answer.

## If a stage fails twice for the same reason

Do not try a third time. Go down the degradation ladder in `docs/LOOP.md`, write the reason into
`loop/ESCALATIONS.md`, and switch to a stage that can still make progress. Anything only the owner
can clear goes into `asks[]` and **never blocks the loop**.
