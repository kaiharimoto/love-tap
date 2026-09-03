The mission brief is attached. Read all of it, then begin. Follow it exactly, including the state block on every reply.

# An android app and an apple…

An Android app and an Apple-compatible installable PWA that let exactly two people communicate directly with each other over Tailscale between their devices. It must first be a complete, reliable, genuinely pleasant multimedia messenger — text, photos, video, voice notes, reactions, replies, delivery and read state, searchable history — because it is replacing Instagram DMs as the couple's primary channel and will be judged unusable if any of that is missing or flaky. On top of that solid messenger sits the actual reason the app exists: an emotional nervous system that transmits feeling rather than sentences, where a gesture on one device becomes a sensation on the other, and where each person's inner state is continuously legible to the other. Beyond messaging and feeling, it grows into a shared relationship OS with modules for the couple's life together — date planner and tracker, shared to-do lists, anniversaries and calendar, rituals and streaks, ambient widgets and scheduled pings — and it must be architected so new modules of this kind can be added later without rework.

`task-id: an-android-app-and-an-apple` · 4+ review cycles · 5 critics · 10 final artifacts · exit at 95/100

---

## 00 / RUNTIME

**COMPUTE** · A headless Linux container with no GPU and no physical phones attached. Blender renders run headless on CPU and their output is committed to the repository as baked assets, so the material library is generated once rather than regenerated on every run. Screen captures come from an Android emulator and a headless browser rather than real hardware, and Tailscale is exercised between two container profiles rather than between two real phones, with verification on physical devices left to the builder.

**PRIMARY TOOL** · A single Flutter and Dart codebase compiled both to a native Android app and to a web build that serves as the iOS-installable PWA, so there is one UI, one material system, and one asset set rather than two of each. The supporting toolchain is Blender running headless for the paper, fold, crumple, and lighting assets, plus an Android emulator and a headless browser for capturing the evidence set.

**HARNESS** · A single agent working sequentially, with no subagents and no parallel branches. The material system is the aesthetic backbone of the entire app, so it stays in one head and consistency across paper, ink, lighting, and handwriting is a property of how the build proceeds rather than something reconciled at merge time. The agent commits as it goes rather than at the end.

**STARTING ASSETS** · Nothing pre-made. Everything is generated from scratch.

**BUDGET** · 100 million tokens

**WALL CLOCK** · Repeating sessions of four to six hours. Every session ends by recapturing all ten evidence artifacts and committing them, regardless of which build step it reached, so each cycle produces a visual diff against the previous cycle and regressions are caught by comparison rather than by memory. The loop continues until the artifacts are good rather than until a fixed date.

**AUTONOMY** · Fully autonomous, zero human intervention until the quality gates are met.


You have **no tool access and no filesystem** in this conversation. You are producing the work as text, turn by turn, for a human who is relaying your output by hand. Never claim to have run a command, written a file, or inspected an artifact. When the mission needs work you cannot perform here, produce the exact instructions or content the human should apply, and say plainly that it is unexecuted.

---

## 01 / TASK

**SCALE** · A relationship OS, not a demo: roughly 10 to 15 screens across a messenger core (conversation, media viewer, voice notes, search, history), an emotional layer (send/receive feelings, live partner state, ambient presence, ritual and streak surfaces), and shared-life modules (date planner and tracker, shared to-do list, anniversaries and calendar), plus pairing, notification scheduling, and settings. Both targets ship and work end-to-end: a native Android app and an iOS-installable PWA, communicating device-to-device over Tailscale. This is multi-week scope and is expected to keep growing, so the architecture must make adding a new module cheap.

**JUDGED BY** · The builder judges it, as a craft object — the standard is that the code and the interaction design are things he is proud of, with the relationship as the reason to build it well rather than the panel of critics. There is one hard functional bar underneath that craft standard: it has to be good enough that he and his partner actually stop using Instagram and move to this instead, so any messenger shortcoming that would push them back to Instagram counts as a failure regardless of how good the emotional layer is.


**Defining story**

Two people wired together. Everything that would normally take a paragraph of typing arrives instead as a sensation — a tap here becomes a buzz there, a mood set on one phone changes what the other phone looks like. The messenger underneath never drops a beat, so the couple can abandon Instagram without losing anything, but the thing they actually come back for is the feeling of being physically connected to someone who is somewhere else.

**Avoid these interpretations and shortcuts**
- No engagement machinery: no badges, points, leaderboards, guilt-inducing streak breakage, or notifications engineered to pull someone back into the app. Streaks and rituals may exist as a quiet record of what the couple actually does, but nothing may ever punish, nag, or turn affection into a metric that can be failed.
- No emoji soup: the emotional layer must never be a grid of system emoji, and feelings must never be drawn as stock illustration, 3D gradient blobs, or animation-pack cuteness.
- No product-marketing voice anywhere in the app: no 'Oops! Something went wrong', no exclamation-mark cheerfulness, no third-person app-speak. The app never refers to itself by name and never addresses either person like a brand.
- No simulated paper. A beige rounded rectangle with a drop shadow, a tiled repeating texture, or a procedural noise overlay is a failure of the entire visual concept. If a surface reads as an approximation of paper rather than as a photograph of real paper, it is wrong and must be redone.

---

## 02 / PROTOCOL

Perform the actual work. Do not answer with only a plan, a tutorial, or sample code.

The user may be unavailable. Make conservative, reversible assumptions, record them, and continue. Do not pause for non-blocking choices, optional downloads, or missing conveniences. Stop only for credentials, a potentially destructive external action, or an ambiguity that cannot be resolved without materially changing the authorised project.

Continue until the explicit quality gates in this brief are satisfied — not merely until the first working result exists.

**Before committing to the implementation**

Inspect the working environment, the available tools and their versions, and any existing assets. Optional dependencies must not become blockers; provide a native alternative instead.

**Maintain these working documents throughout**

```
love-tap/
  DIRECTION.md      # the visual or design language, and decisions made
  PLAN.md           # dimensions, structure, coverage, required parts
  INVENTORY.md      # component families, sources, status, substitutions
  TASK_STATE.md     # completed work, worst problems, next action, score
  checkpoints/      # a recoverable milestone after every stable stage
```

**If context is compacted or work resumes later**

Re-read this brief plus `DIRECTION.md` and `TASK_STATE.md`, open the latest valid checkpoint, and continue from the recorded next action rather than rebuilding blindly. Keep `TASK_STATE.md` carrying the last successful commands, the current rubric score, and known failures, so that any future session can resume mid-flight.

**Progress heartbeat — required on every reply**

End every response with this block, fenced exactly as shown. It is read by tooling; keep it short, keep the keys, and never omit it.

```mpstate
v=1
task=an-android-app-and-an-apple
phase=<bootstrap|build|review|validation|done>
step=<current step, a few words>
cycle=<review cycle number, 0 before review begins>
score=<current rubric score out of 100, or 0>
next=<the single next action>
blocked=<none, or what is blocking>
ask=<none, or one question for the user>
```

Because this conversation may be cut off by a usage limit at any point, the block above is the only thing that survives. Treat it as the handover note to your own successor.

---

## 03 / BUILD ORDER

Work in this order. Keep the whole thing viewable and evaluable after every stage — never leave it in a state that cannot be inspected.

**STEP 01 — Transport**

Prove device-to-device delivery over Tailscale between two profiles before anything else exists. A payload must travel from one device to the other and survive app restart, going offline mid-send, and reconnecting after a long gap. Nothing is styled and nothing is beautiful at this stage; the only question is whether the wire works.

**STEP 02 — The single event spine**

Build the one chronological event log that every part of the app will read from, with local persistence, stable ordering, attribution to one of the two people, and timestamps. Define all fourteen event types up front even though most are not yet produced, so no later feature has to widen the schema, and make adding a fifteenth type cheap.

**STEP 03 — The messenger, deliberately unstyled**

Build the complete messenger with no visual design at all: text, photos, video, voice notes, reactions, replies, delivery and read state, typing indication, editing and deleting, full-text and media search, and the media viewer. It must be functionally good enough to replace Instagram before a single pixel of paper exists, because a messenger shortcoming is the defined failure condition.

**STEP 04 — The seeded year**

Author the year-deep seeded history that every screen will be designed and judged against: months of messages, hundreds of feelings, photographs, past dates, and finished to-dos, written to read like two specific people with uneven rhythms, silent stretches, in-jokes, mundane logistics, and conversations that trail off. This must exist before any screen is styled.

**STEP 05 — The material pipeline**

Build the paper asset library: high-resolution scans of real lined, graph, spiral-bound and loose notebook stock; several dozen alpha masks cut from genuinely torn paper; Blender-rendered fold, crease and crumple sequences under one consistent soft daylight; handwriting captured and converted to fonts with multiple variants per glyph; feeling objects scanned or rendered from real things; and contact shadows baked from the render's own lighting. This is the riskiest part of the vision, so before styling anything else the agent must render a close-up of a single note and judge it against the anti-goal: if it reads as an approximation of paper rather than as photographed paper, it is redone rather than carried forward.

**STEP 06 — Material applied to the shell and to Chat**

Apply the material system to the app shell and to the Chat region first, because Chat is the hero artifact and the screen the couple will live in. Scroll it against the seeded year and verify that no two visible tears repeat, that every contact shadow shares one light direction, and that the paper still reads as real when the capture is zoomed to three hundred percent.

**STEP 07 — The emotional layer**

Build the nervous system on top of the working messenger: at least thirty built-in feelings across at least five named families, each with its own name, colour, icon, haptic rhythm, sound and animation; user-authored feelings that behave identically to built-ins everywhere; the twelve or more partner-state signals; and the three ambient presence surfaces. Every platform gap, above all the absence of haptics in the iOS PWA, must be filled with a deliberate designed substitute rather than left as a missing feature.

**STEP 08 — The shared-life modules**

Build the four modules inside Us — date planner and tracker, shared to-do list with assignment, calendar with anniversaries and countdowns, and rituals and streaks as a quiet record that never nags or punishes. Each writes its events into the single spine rather than keeping private history, and the fourth must be addable without touching the first three, proving a fifth would cost little.

**STEP 09 — Moments, Settings, and first run**

Build Moments as a filtered view over the single spine rather than a second store, build Settings with pairing, per-event notification scheduling and the feeling-authoring tools, and write and draw the first-run empty states specifically for each surface in the couple's own voice, with no product-marketing tone and no self-reference by the app.

**STEP 10 — Evidence capture**

At the end of every session, whatever step the build has reached, capture all ten evidence artifacts to their fixed filenames and commit them alongside the code. Everything except the first-run artifact is captured against the seeded year-deep history. This is a per-session ritual rather than a final step, and the diff between one session's artifacts and the last is the primary signal of progress or regression.


---

## 04 / REVIEW LOOP

Use the complete evidence set in section 08 as the fixed judgeset. Perform at least **4 complete cycles** of:

build or change → capture the fixed evidence set → inspect the actual captured artifacts → diagnose → fix → re-capture the identical set

Criticism must be based on the captured evidence — not on code, the object tree, descriptions, or the builder's own summary.

For each finding, record the artifact it came from, the severity, the affected subsystem, the likely root cause, and an actionable correction. Repair systemic issues affecting several artifacts before isolated polish.

Use 5 specialist critics. Each must be a **fresh-context subagent** that receives only the mission goal, the captured evidence, and the rubric — never the build history.

- **The messenger-reliability critic** — Whether anything visible in the ten artifacts would give either person a reason to open Instagram instead: a missing capability, a state that has stalled, ordering that makes no sense after a reconnect, jank in the dense scroll, or a delivery and read marker that cannot be trusted.
- **The material-truth critic** — Whether the paper reads as photographed rather than simulated: tear edges repeating within a single frame, contact shadows whose light directions disagree, handwriting whose repeated letters are identical, and folds in the motion clips that read as a flat image being transformed rather than as rendered geometry catching light.
- **The emotional-transmission critic** — Whether a feeling arrives as a sensation rather than as a message in a different colour, judged from the landing clip, the propagation clip, and the two-device frame — including whether the iOS substitute for the missing haptic reads as equally physical rather than as an absence.
- **The coherence critic** — Whether the ten artifacts show one system rather than an assembly: the same event appearing consistently wherever it should across Chat, Moments and Us, one visual language holding across all five regions, and partner state legible on every screen rather than only on Pulse. The code-reading half of this rubric category stays inside the self-score, because critics see only artifacts.
- **The anti-goal critic** — Whether any of the four forbidden interpretations is visible anywhere in the ten artifacts: engagement machinery of any kind, emoji soup or stock illustration standing in for feelings, product-marketing voice in any string the app displays, or simulated paper.

**After every cycle**

After every repair cycle, compare each artifact against the preceding version and label it improved, unchanged, or regressed. Fix or roll back regressions before continuing.

If the score is below the exit threshold and improves by less than one point across two consecutive complete cycles, perform a structural pass instead of adding more small detail.

---

## 05 / RUBRIC

Score the work out of 100 against these weighted categories.

| # | Category | Weight | Minimum | Judged on |
|---|---|---:|---:|---|
| 01 | Messenger reliability | 30 | 26 | Every messenger capability is present and dependable: text, photos, video, voice notes, reactions, replies, delivery and read state, typing indication, editing and deleting, full-text and media search, and the media viewer. No dropped or duplicated messages, no lost drafts, correct ordering after going offline and reconnecting, no spinner that outstays its welcome, and no scroll jank against the year-deep seeded history. This is the category that decides whether the couple actually leaves Instagram, so any single failure that would give either person a reason to open Instagram instead scores this category at or below its floor regardless of how well everything else is working. |
| 02 | Material truth | 25 | 22 | The paper reads as photographed rather than simulated. Real scanned stock, tear masks with no visible repeat on a single screen, Blender-rendered folds and creases under one consistent light direction, handwriting with multiple variants per glyph and real pressure variance, feelings as physical objects rather than icons, and contact shadows baked from the render's own lighting rather than applied as a uniform blur. Judged at three hundred percent zoom on the Chat hero and in slow motion on the unfolding clip. Any procedural noise overlay, tiled repeating texture, or beige rounded rectangle standing in for paper scores this category below its floor. |
| 03 | Emotional transmission | 20 | 17 | A gesture on one device arrives on the other as a sensation rather than as a message in a different colour. At least thirty built-in feelings across at least five named families, each identifiable by its haptic pattern alone with the screen face down; user-authored feelings behaving identically to built-ins in every path; at least twelve partner-state signals; three ambient presence surfaces; state changes perceptible without opening the app; a feeling reachable in one gesture from any region of the app; and on the iOS PWA a deliberately designed non-haptic substitute that reads as equally physical rather than as a missing feature. |
| 04 | Coherence and extensibility | 15 | 13 | There is exactly one event log and no second store anywhere; every region is a view onto it and every module writes into it; a fifth shared-life module could be added without touching the existing four; and both platforms serve the same regions, the same feelings, and the same event types from the one codebase. This category is scored partly by reading the code rather than only by looking at the artifacts, because an architecture that merely looks coherent in a screenshot is not coherent. |
| 05 | Anti-goal compliance | 10 | 9 | None of the four forbidden interpretations appear anywhere in the build: no engagement machinery of any kind, no emoji soup or stock illustration in the emotional layer, no product-marketing voice in any string the app displays, and no simulated paper. Simulated paper is scored here as well as under material truth, so that failure costs the build twice, which is intended given it is the single riskiest part of the vision. |
| | **Total** | **100** | | |

**Exit threshold — 95 / 100.** Do not declare the mission complete below it.

Additional exit conditions, all of which must hold:
- Every category at or above its stated minimum, where one is given.
- Complete coverage of every required part and every artifact in the evidence set.
- No regression across the final two review cycles.

---

## 06 / VALIDATION

Before declaring completion, prove the result survives being reopened from nothing.

git clone <repo> && cd love-tap && ./bootstrap.sh installs pinned Flutter, Android cmdline-tools with one AVD, Blender, ffmpeg, and tailscaled into ./toolchain with no sudo and no prompts, stops with a named message if any tool prerequisite is missing, and records TS_AUTHKEY as pending rather than failing when it is absent. During the build ./run.sh --seed=year --transport=local builds the APK, installs it into the AVD, opens the PWA in Playwright WebKit against the emulator host through an adb port forward, and runs the local transport with its faults. In the final phase ./run.sh --seed=year --transport=tailscale requires TS_AUTHKEY, starts two tailscaled nodes in userspace mode from ./toolchain/ts/a and ./toolchain/ts/b with SSL_CERT_FILE and HTTPS_PROXY honoured, exposes the emulator host through node a, opens the PWA in WebKit through node b's SOCKS proxy at node a's address, completes the setup checklists and the six-word pairing code, sends one message and one feeling in each direction, and writes evidence/coldstart.json with transport: tailscale, both nodes' tailscale status --json, the four event ids, and arrival timestamps. ./capture.sh regenerates all seventeen artifacts and evidence/DIFF.json. Verify by confirming coldstart.json says tailscale, holds two distinct node keys and two distinct 100.x addresses, that all four event ids appear in both spine dumps in the same order, and that the seventeen files exist at their exact names with the minimum dimensions and frame rates. The real-phone path is the in-app setup checklist itself, mirrored in docs/PHONES.md.

Confirm each of the following:
- All ten evidence artifacts exist at their exact fixed filenames in the evidence directory, every one captured from the running app, and every one except the first-run artifact captured against the seeded year-deep history.
- The committed scoring file records a total of at least ninety-five out of one hundred with all five category floors met in the same session, and shows all five critics having run in that session with any declined finding justified in writing.
- One Flutter codebase builds and runs both targets: the native Android app and the web build that serves as the iOS-installable PWA.
- A real message and a real feeling have crossed Tailscale between two freshly paired instances, not a local simulation of that exchange.
- There is exactly one event log, and no region or module keeps a private history of its own.
- Every family floor is genuinely met: at least thirty built-in feelings across at least five named families, at least four shared-life modules, at least twelve partner-state signals, at least fourteen timeline event types, and at least three ambient presence surfaces.
- The material library in the repository is real and baked: paper scans, dozens of distinct tear masks, Blender-rendered fold and crumple sequences, handwriting fonts with multiple variants per glyph, and contact shadows baked from the render's own lighting.
- None of the four anti-goals appears anywhere: no engagement machinery, no emoji soup, no product-marketing voice in any displayed string, and no simulated paper.
- Partner state is legible from every screen in the app, and a feeling is reachable in at most one gesture from any region.
- The mission brief is committed and current in the repository, so the agent can re-read it from disk at the start of any session, and the README documents the single command that the cold start depends on.
- evidence/ contains exactly the seventeen named artifacts plus SCORE.json, DIFF.json, reliability.json, coldstart.json, frames.json, and crops/ holding three 300 percent crops of 02_chat.png and frame strips of every clip, all regenerated by capture.sh in the final session.
- The transport interface has two implementations, local with injectable disconnects and tailscale, both behind the same interface, and the commit that added tailscale touches nothing under app/lib/transport/ except its own directory.
- reliability.json in the final session shows transport: tailscale and every rubric row 01 capability exercised across two tailscaled nodes with zero duplicates and monotonic ordering after kill, offline, host-offline, and reconnect; earlier sessions' reports say local.
- coldstart.json shows transport: tailscale, one message and one feeling crossing in each direction between nodes with distinct node keys, with the same event ids in both spine dumps.
- The setup checklist on each platform ticks only on observed events: tailnet address detected, host listening, partner's first fetch, first successful TLS handshake, pairing code accepted, push subscription received; every tick state is reachable in capture mode and the two setup artifacts show the checklists on a fresh install.
- The HTTP bootstrap page serves the CA profile, probes the HTTPS app until trust is in place, and then hands over; it carries no spine data and no service worker.
- docs/EVENT_TYPES.md lists at least fourteen types including message, photo, video, voice_note, reaction, message_edit, message_delete, read_marker, feeling, state_declared, state_passive, date_event, todo_event, milestone, ritual_kept, ping, and feeling_authored, each with thread rendering, notification treatment, and search behaviour; the spine schema test asserts the same list; adding one more in a scratch branch touches only the registry file and one renderer.
- docs/SIGNALS.md lists at least twelve signals meeting the per-kind minimums, each naming its Android source, its PWA source or freshness-faded substitute, and its material rendering.
- docs/FEELINGS.md lists at least thirty feelings in at least five named families with object asset id, haptic sequence, sound file, intensity mapping, and family signature, with no two rows sharing an asset id or haptic sequence.
- seed/people.json names the two invented people and their hands, and the seed marks three anchor events that are visible in 02_chat.png, 03_us.png, and 04_moments.png.
- The commit that added the fourth module touches no file under the first three modules' directories, verified by git diff --stat on the hash recorded in TASK_STATE.md.
- The persistence-boundary test and the spine replay golden test pass.
- The Web Push sender passes unit tests against the RFC 8291 and VAPID test vectors, and docs/PHONES.md records the date the builder confirmed a push arriving on the real iPhone.
- The capture log records the driven clock, RNG seed, and scroll anchor for every capture, and lists the tear-mask ids on screen in 02_chat.png with no id repeated and at least eight notes visible.
- Every clip passes the frame-distinctness check; 07 and 15 carry the feeling's sound and its haptic annotation generated from the app's event log; 06 shows at least 30 unique fold frames per second.
- 09_two_devices.png was grabbed from one display, one window is the AVD and the other is Playwright WebKit, and the log records both window ids.
- The PWA serves over HTTPS from the host's origin with a standalone manifest, apple-touch-icon, and a registered service worker, and installs in Playwright WebKit; a Chromium-only result does not count.
- The string-table lint passes across every displayed string including setup, and no font in the app is a downloaded font.
- SCORE.json records five category scores, each equal to the lower of the critic's and the builder's, all six critic reports from the same session, every floor met, total at least 95, and no row 01 disqualifier present.
- DIFF.json shows no regressed label in the final two cycles, every label assigned by the coherence critic, and every label agreeing with its SSIM value.
- A dusk-appearance capture of Pulse exists in evidence/crops/ and shows the transform and lamp render rather than an overlay.
- assets/MANIFEST.json covers every file in assets/, no file exceeds 95 MB, and the repository uses no Git LFS.
- TASK_STATE.md and the heartbeat carry ask=TS_AUTHKEY only from the session in which the Tailscale phase begins, and no earlier session was blocked on it.
- README.md documents bootstrap.sh, run.sh with both transport flags, capture.sh, TS_AUTHKEY and when it is needed, and an honest unverified list: real iPhone install, real push, real haptics, real phones over Tailscale.
- evidence/ contains exactly the seventeen named artifacts plus SCORE.json, DIFF.json, reliability.json, coldstart.json, frames.json, and crops/ holding three 300 percent crops of 02_chat.png and frame strips of every clip, all regenerated by capture.sh in the final session.
- The transport interface has two implementations, local with injectable disconnects and tailscale, both behind the same interface, and the commit that added tailscale touches nothing under app/lib/transport/ except its own directory.
- reliability.json in the final session shows transport: tailscale and every rubric row 01 capability exercised across two tailscaled nodes with zero duplicates and monotonic ordering after kill, offline, host-offline, and reconnect; earlier sessions' reports say local.
- coldstart.json shows transport: tailscale, one message and one feeling crossing in each direction between nodes with distinct node keys, with the same event ids in both spine dumps.
- The setup checklist on each platform ticks only on observed events: tailnet address detected, host listening, partner's first fetch, first successful TLS handshake, pairing code accepted, push subscription received; every tick state is reachable in capture mode and the two setup artifacts show the checklists on a fresh install.
- The HTTP bootstrap page serves the CA profile, probes the HTTPS app until trust is in place, and then hands over; it carries no spine data and no service worker.
- docs/EVENT_TYPES.md lists at least fourteen types including message, photo, video, voice_note, reaction, message_edit, message_delete, read_marker, feeling, state_declared, state_passive, date_event, todo_event, milestone, ritual_kept, ping, and feeling_authored, each with thread rendering, notification treatment, and search behaviour; the spine schema test asserts the same list; adding one more in a scratch branch touches only the registry file and one renderer.
- docs/SIGNALS.md lists at least twelve signals meeting the per-kind minimums, each naming its Android source, its PWA source or freshness-faded substitute, and its material rendering.
- docs/FEELINGS.md lists at least thirty feelings in at least five named families with object asset id, haptic sequence, sound file, intensity mapping, and family signature, with no two rows sharing an asset id or haptic sequence.
- seed/people.json names the two invented people and their hands, and the seed marks three anchor events that are visible in 02_chat.png, 03_us.png, and 04_moments.png.
- The commit that added the fourth module touches no file under the first three modules' directories, verified by git diff --stat on the hash recorded in TASK_STATE.md.
- The persistence-boundary test and the spine replay golden test pass.
- The Web Push sender passes unit tests against the RFC 8291 and VAPID test vectors, and docs/PHONES.md records the date the builder confirmed a push arriving on the real iPhone.
- The capture log records the driven clock, RNG seed, and scroll anchor for every capture, and lists the tear-mask ids on screen in 02_chat.png with no id repeated and at least eight notes visible.
- Every clip passes the frame-distinctness check; 07 and 15 carry the feeling's sound and its haptic annotation generated from the app's event log; 06 shows at least 30 unique fold frames per second.
- 09_two_devices.png was grabbed from one display, one window is the AVD and the other is Playwright WebKit, and the log records both window ids.
- The PWA serves over HTTPS from the host's origin with a standalone manifest, apple-touch-icon, and a registered service worker, and installs in Playwright WebKit; a Chromium-only result does not count.
- The string-table lint passes across every displayed string including setup, and no font in the app is a downloaded font.
- SCORE.json records five category scores, each equal to the lower of the critic's and the builder's, all six critic reports from the same session, every floor met, total at least 95, and no row 01 disqualifier present.
- DIFF.json shows no regressed label in the final two cycles, every label assigned by the coherence critic, and every label agreeing with its SSIM value.
- A dusk-appearance capture of Pulse exists in evidence/crops/ and shows the transform and lamp render rather than an overlay.
- assets/MANIFEST.json covers every file in assets/, no file exceeds 95 MB, and the repository uses no Git LFS.
- TASK_STATE.md and the heartbeat carry ask=TS_AUTHKEY only from the session in which the Tailscale phase begins, and no earlier session was blocked on it.
- README.md documents bootstrap.sh, run.sh with both transport flags, capture.sh, TS_AUTHKEY and when it is needed, and an honest unverified list: real iPhone install, real push, real haptics, real phones over Tailscale.
- evidence/ contains exactly the seventeen named artifacts plus SCORE.json, DIFF.json, reliability.json, coldstart.json, frames.json, and crops/ holding three 300 percent crops of 02_chat.png and frame strips of every clip, all regenerated by capture.sh in the final session.
- The transport interface has two implementations, local with injectable disconnects and tailscale, both behind the same interface, and the commit that added tailscale touches nothing under app/lib/transport/ except its own directory.
- reliability.json in the final session shows transport: tailscale and every rubric row 01 capability exercised across two tailscaled nodes with zero duplicates and monotonic ordering after kill, offline, host-offline, and reconnect; earlier sessions' reports say local.
- coldstart.json shows transport: tailscale, one message and one feeling crossing in each direction between nodes with distinct node keys, with the same event ids in both spine dumps.
- The setup checklist on each platform ticks only on observed events: tailnet address detected, host listening, partner's first fetch, first successful TLS handshake, pairing code accepted, push subscription received; every tick state is reachable in capture mode and the two setup artifacts show the checklists on a fresh install.
- The HTTP bootstrap page serves the CA profile, probes the HTTPS app until trust is in place, and then hands over; it carries no spine data and no service worker.
- docs/EVENT_TYPES.md lists at least fourteen types including message, photo, video, voice_note, reaction, message_edit, message_delete, read_marker, feeling, state_declared, state_passive, date_event, todo_event, milestone, ritual_kept, ping, and feeling_authored, each with thread rendering, notification treatment, and search behaviour; the spine schema test asserts the same list; adding one more in a scratch branch touches only the registry file and one renderer.
- docs/SIGNALS.md lists at least twelve signals meeting the per-kind minimums, each naming its Android source, its PWA source or freshness-faded substitute, and its material rendering.
- docs/FEELINGS.md lists at least thirty feelings in at least five named families with object asset id, haptic sequence, sound file, intensity mapping, and family signature, with no two rows sharing an asset id or haptic sequence.
- seed/people.json names the two invented people and their hands, and the seed marks three anchor events that are visible in 02_chat.png, 03_us.png, and 04_moments.png.
- The commit that added the fourth module touches no file under the first three modules' directories, verified by git diff --stat on the hash recorded in TASK_STATE.md.
- The persistence-boundary test and the spine replay golden test pass.
- The Web Push sender passes unit tests against the RFC 8291 and VAPID test vectors, and docs/PHONES.md records the date the builder confirmed a push arriving on the real iPhone.
- The capture log records the driven clock, RNG seed, and scroll anchor for every capture, and lists the tear-mask ids on screen in 02_chat.png with no id repeated and at least eight notes visible.
- Every clip passes the frame-distinctness check; 07 and 15 carry the feeling's sound and its haptic annotation generated from the app's event log; 06 shows at least 30 unique fold frames per second.
- 09_two_devices.png was grabbed from one display, one window is the AVD and the other is Playwright WebKit, and the log records both window ids.
- The PWA serves over HTTPS from the host's origin with a standalone manifest, apple-touch-icon, and a registered service worker, and installs in Playwright WebKit; a Chromium-only result does not count.
- The string-table lint passes across every displayed string including setup, and no font in the app is a downloaded font.
- SCORE.json records five category scores, each equal to the lower of the critic's and the builder's, all six critic reports from the same session, every floor met, total at least 95, and no row 01 disqualifier present.
- DIFF.json shows no regressed label in the final two cycles, every label assigned by the coherence critic, and every label agreeing with its SSIM value.
- A dusk-appearance capture of Pulse exists in evidence/crops/ and shows the transform and lamp render rather than an overlay.
- assets/MANIFEST.json covers every file in assets/, no file exceeds 95 MB, and the repository uses no Git LFS.
- TASK_STATE.md and the heartbeat carry ask=TS_AUTHKEY only from the session in which the Tailscale phase begins, and no earlier session was blocked on it.
- README.md documents bootstrap.sh, run.sh with both transport flags, capture.sh, TS_AUTHKEY and when it is needed, and an honest unverified list: real iPhone install, real push, real haptics, real phones over Tailscale.
- evidence/ contains exactly the seventeen named artifacts plus SCORE.json, DIFF.json, reliability.json, coldstart.json, frames.json, and crops/ holding three 300 percent crops of 02_chat.png and frame strips of every clip, all regenerated by capture.sh in the final session.
- The transport interface has two implementations, local with injectable disconnects and tailscale, both behind the same interface, and the commit that added tailscale touches nothing under app/lib/transport/ except its own directory.
- reliability.json in the final session shows transport: tailscale and every rubric row 01 capability exercised across two tailscaled nodes with zero duplicates and monotonic ordering after kill, offline, host-offline, and reconnect; earlier sessions' reports say local.
- coldstart.json shows transport: tailscale, one message and one feeling crossing in each direction between nodes with distinct node keys, with the same event ids in both spine dumps.
- The setup checklist on each platform ticks only on observed events: tailnet address detected, host listening, partner's first fetch, first successful TLS handshake, pairing code accepted, push subscription received; every tick state is reachable in capture mode and the two setup artifacts show the checklists on a fresh install.
- The HTTP bootstrap page serves the CA profile, probes the HTTPS app until trust is in place, and then hands over; it carries no spine data and no service worker.
- docs/EVENT_TYPES.md lists at least fourteen types including message, photo, video, voice_note, reaction, message_edit, message_delete, read_marker, feeling, state_declared, state_passive, date_event, todo_event, milestone, ritual_kept, ping, and feeling_authored, each with thread rendering, notification treatment, and search behaviour; the spine schema test asserts the same list; adding one more in a scratch branch touches only the registry file and one renderer.
- docs/SIGNALS.md lists at least twelve signals meeting the per-kind minimums, each naming its Android source, its PWA source or freshness-faded substitute, and its material rendering.
- docs/FEELINGS.md lists at least thirty feelings in at least five named families with object asset id, haptic sequence, sound file, intensity mapping, and family signature, with no two rows sharing an asset id or haptic sequence.
- seed/people.json names the two invented people and their hands, and the seed marks three anchor events that are visible in 02_chat.png, 03_us.png, and 04_moments.png.
- The commit that added the fourth module touches no file under the first three modules' directories, verified by git diff --stat on the hash recorded in TASK_STATE.md.
- The persistence-boundary test and the spine replay golden test pass.
- The Web Push sender passes unit tests against the RFC 8291 and VAPID test vectors, and docs/PHONES.md records the date the builder confirmed a push arriving on the real iPhone.
- The capture log records the driven clock, RNG seed, and scroll anchor for every capture, and lists the tear-mask ids on screen in 02_chat.png with no id repeated and at least eight notes visible.
- Every clip passes the frame-distinctness check; 07 and 15 carry the feeling's sound and its haptic annotation generated from the app's event log; 06 shows at least 30 unique fold frames per second.
- 09_two_devices.png was grabbed from one display, one window is the AVD and the other is Playwright WebKit, and the log records both window ids.
- The PWA serves over HTTPS from the host's origin with a standalone manifest, apple-touch-icon, and a registered service worker, and installs in Playwright WebKit; a Chromium-only result does not count.
- The string-table lint passes across every displayed string including setup, and no font in the app is a downloaded font.
- SCORE.json records five category scores, each equal to the lower of the critic's and the builder's, all six critic reports from the same session, every floor met, total at least 95, and no row 01 disqualifier present.
- DIFF.json shows no regressed label in the final two cycles, every label assigned by the coherence critic, and every label agreeing with its SSIM value.
- A dusk-appearance capture of Pulse exists in evidence/crops/ and shows the transform and lamp render rather than an overlay.
- assets/MANIFEST.json covers every file in assets/, no file exceeds 95 MB, and the repository uses no Git LFS.
- TASK_STATE.md and the heartbeat carry ask=TS_AUTHKEY only from the session in which the Tailscale phase begins, and no earlier session was blocked on it.
- README.md documents bootstrap.sh, run.sh with both transport flags, capture.sh, TS_AUTHKEY and when it is needed, and an honest unverified list: real iPhone install, real push, real haptics, real phones over Tailscale.

The final response must list actual project and output paths, the evidence-backed rubric result, and any remaining non-critical limitations honestly.

---

## 07 / BRIEF

**Required parts**

Every one of the following must exist with real depth, believable access, and enough substance to explain its purpose.

**01 · Pulse** — The ambient home and the seat of the nervous system — where you read your partner's live state and send feelings.
- Presents the partner's complete current state as one continuously updating surface, covering every declared, passive, need, and place signal at once.
- Carries the feeling sender, with all built-in and user-authored feelings reachable without leaving the screen.
- Provides an ambient presence surface whose colour, motion, and texture visibly change as the partner's state changes, so the screen looks different depending on how they are.
- Lets you set your own mood, status line, availability, need dial, energy, and place in the same place you read theirs.
- Shows a live pulse of the feelings exchanged recently, so the day's emotional traffic is visible at a glance.

**02 · Chat** — The complete multimedia messenger that replaces Instagram DMs, and the full chronological rendering of the single event spine.
- Supports text, photos, video, voice notes, reactions, replies, delivery and read state, typing indication, and editing or deleting messages.
- Renders every non-message event type inline in the same chronological thread, so feelings, mood changes, and module events appear in context alongside conversation.
- Includes full-text and media search across the entire history, plus a media viewer with full-resolution playback.
- Remains completely usable if neither person ever touches the emotional layer, because a messenger shortcoming is what would send the couple back to Instagram.

**03 · Us** — The hub for the couple's shared life, holding the practical modules that make the app worth living in beyond messaging.
- Holds at least four modules: a date planner and tracker for planning, scheduling, rating, and remembering dates; a shared to-do list whose items can be assigned to either person; a shared calendar carrying anniversaries and recurring milestones with countdowns; and a rituals and streaks module tracking recurring shared habits.
- Every module writes its events into the single spine rather than keeping a private history.
- Adding a fifth module must not require changing the existing four.

**04 · Moments** — The shared archive — the couple's accumulated history made browsable and searchable.
- Is a filtered view over the single event spine and never a second store of its own.
- Offers a media gallery of everything the two people have shared, a milestone and anniversary timeline, and a feeling history showing what was sent, when, and by whom.
- Allows filtering and searching by person, date range, event type, and specific feeling.

**05 · Settings** — Pairing, notification control, and the customization surface that lets the couple make the app their own.
- Handles device-to-device pairing so exactly two people are linked, with a clear path to re-pair a replaced device.
- Configures notification behaviour and scheduled pings per event type, including quiet hours.
- Contains the feeling authoring tools: creating, renaming, recolouring, re-patterning, and retiring user-authored feelings.
- Covers theme and ambient appearance, each person's profile, and export or backup of the shared history.

No required part may exist only as a label. A part may be compact, but its interior, its boundaries, and its relationship to the rest must be legible in the final evidence.

**Relationships that must hold**
- There is exactly one chronological event log for the couple, and every part of the app is a view onto it: Chat renders it in full, Moments and any module history are filtered views over the same log, and no region keeps a private record that could drift out of sync.
- Every module action emits an event into the spine, so completing a to-do, planning or finishing a date, hitting an anniversary, or extending a streak all appear in the conversation thread in the order they happened.
- The partner's current state must be legible from every screen in the app, not just from Pulse, so the nervous system is never something you have to navigate to.
- Sending a feeling must be reachable in at most one gesture from any region of the app.
- A change in one person's state must be perceptible on the other person's device without opening the app, through ambient and notification surfaces, not only in-app.
- User-authored feelings are first-class and indistinguishable in behaviour from built-in ones: the same send paths, the same timeline rendering, the same haptics and sound, the same notification treatment, and the same presence in history and search.
- Nothing in the emotional layer may be a precondition for messaging — the messenger works completely even if the partner never sets a state or sends a feeling.
- Both platforms expose the same regions, the same feelings, and the same event types; the iOS PWA is not a reduced edition, and anywhere the platform genuinely cannot match the Android app the fallback must be a deliberate designed substitute rather than a missing feature.
- Anything either person authors — feelings, rituals, module content, profile — travels over the same direct device-to-device channel as messages, with no second sync path.
- Every event in the spine is attributed to one of the two people and timestamped, and search reaches all event types rather than only text.

**Component families**

Build coherent reusable families rather than unrelated one-offs. Repetition may use instances, but silhouette, orientation, state, and placement must vary enough to avoid copy-paste regularity.

- **Built-in feelings** — The shipped emotional vocabulary — the gestures that turn a tap on one device into a sensation on the other. _At least 30._
  Variation: Each has its own name, colour, icon, haptic rhythm, sound, send animation, and receive animation, belongs to one named feeling family, and supports a range of intensity so the same feeling can arrive gently or urgently. No two are distinguishable by colour alone — each must be recognisable by its haptic pattern with the screen face down.
- **Feeling families** — The named emotional registers the vocabulary is organised into, so thirty-plus feelings stay navigable. _At least 5._
  Variation: Each family covers a distinct emotional register — affection, longing, comfort, playfulness, distress, celebration and the like — and shares a visual and haptic signature across its members that marks them as related without making them interchangeable.
- **Shared-life modules** — The practical modules inside Us that carry the couple's life together. _At least 4._
  Variation: Each solves a different shared-life problem — planning and remembering dates, dividing tasks, tracking dates that matter, sustaining recurring rituals — and each contributes its own event types to the spine while sharing the same module scaffolding.
- **Partner-state signals** — The individual channels that together make one person's inner and outer situation continuously legible to the other. _At least 12._
  Variation: The set spans four kinds: declared signals the person sets by hand, passive signals the device reports on its own, need and energy signals that change how the other person's app looks and behaves, and coarse place presence. Each signal has its own distinct representation rather than being collapsed into a single mood blob.
- **Timeline event types** — The distinct kinds of thing that can land in the single chronological spine. _At least 14._
  Variation: Each type has its own rendering in the thread, its own notification treatment, and its own place in search and filtering, covering conversation, media, feelings, state changes, and every module's activity.
- **Ambient presence surfaces** — The ways your partner's state and pings reach you without opening the app. _At least 3._
  Variation: Each occupies a different part of the device's attention — a glanceable always-present surface, an interruptive one, and a peripheral one — and each reflects live partner state rather than only announcing discrete events.

**Palette**
- Paper whites that are warm and uneven rather than clean: the off-white of cheap lined notebook paper, the yellower cast of a page that has been in a bag for a year, the cool blue-grey of graph paper.
- Inks drawn from real pens and pencils: ballpoint blue-black, graphite grey, the too-dark blue of a cheap biro pressed hard, and occasional red pen.
- Accent colour comes from stationery rather than from a UI palette: faded highlighter yellow and pink, correction-fluid white, the translucent amber of aged tape, the washed-out colours of sticky notes.
- Nothing in the app emits light. No glows, no neon, no saturated brand colour, and no gradient that is not the shading of a physical fold or curl.
- Partner state is expressed through the choice of paper, ink, and object rather than through a coloured status dot.

**Materials and surfaces**
- Every paper surface in the app is a photograph or a render of real paper rather than a CSS approximation: high-resolution scans of actual lined, graph, spiral-bound, and loose notebook pages, retaining real fibre, tooth, print misregistration, and age.
- Torn edges come from a library of at least several dozen alpha masks cut from genuinely ripped paper, and each note draws from that pool so no two tears visible at once are identical.
- Folded, creased, and crumpled states are modelled and rendered in Blender under a single consistent soft daylight and shipped as baked image sequences or sprite sheets, so a note unfolding shows real creases catching real light instead of a CSS transform pretending to be a fold.
- Handwriting is real handwriting: each person's hand is captured and turned into a font with several variants per glyph so repeated letters never look stamped, and stroke weight varies with pen pressure.
- Feelings are physical objects rather than icons — doodles, folded paper shapes, tape, staples, stickers, pressed flowers, biro scribbles — each scanned from a real object or rendered from a real model.
- Shadows are contact shadows baked from the render's own lighting, never a uniform blur applied to a rectangle, and the light direction is identical across every screen in the app.
- The asset library must be large enough for genuine variation: paper stocks, tears, folds, tape pieces, and ink strokes each need enough distinct instances that scrolling through a year of history never shows a visible repeat.

**Atmosphere and light**

Soft indirect daylight, like a classroom by a window in the afternoon. The mood is nostalgic and faintly illicit — the feeling of a note passed under a desk when you are not supposed to be passing notes. Nothing glows, hums, or pulses with its own light; the app is lit from outside rather than from within, and everything in it feels quiet, warm, handmade, and a little worn.

**Detail standard**

The baseline is screen-level: every screen looks finished and considered at a glance, with excellent micro-interaction where it matters most — sending and receiving a feeling, a state change arriving — and solid, unremarkable competence elsewhere. The single exception is the material system itself, which is the riskiest part of the entire vision and therefore carries the highest scrutiny in the project: paper, tears, folds, ink, handwriting, and lighting must survive close inspection and slow-motion screen recording, and must be reviewed against the vision repeatedly rather than accepted on first pass, because a paper aesthetic that reads as fake is worse than having no aesthetic at all.

**Evidence of use**

The result must feel operational rather than staged. Include restrained evidence such as:
- The app ships with a realistic seeded history — months of messages, hundreds of feelings, photographs, past dates, and finished to-dos — so that no screen is ever designed or evaluated against an empty grid.
- The seeded content must read like two specific people rather than like sample data: uneven rhythms, silent stretches, in-jokes, mundane logistics, and conversations that trail off without resolving.
- Every screen is judged against that populated history first, and an empty state is treated as a secondary case rather than as the default view during design.

Every detail must communicate function, recent activity, maintenance, or occupancy. Do not scatter clutter to hide weak fundamentals.


---

## 08 / DELIVERABLES

**Evidence set — the fixed judgeset**

Produce exactly these 10 artifacts, with these names. They are re-captured identically every review cycle, and they must collectively prove that every required part is complete — not merely repeat the best angle.

**01 · `01_pulse.png`** — Pulse
  The ambient home rendering the partner's complete live state at once — declared mood and status line, passive device signals, the need and energy dials, and coarse place presence — on real paper stock, with the feeling sender present and reachable without leaving the screen. Captured against the seeded history so the day's exchanged feelings are visible rather than an empty surface.
  _Minimum: 1440x3120_

**02 · `02_chat.png`** — Chat, year-deep
  The hero artifact and the cold-start check. The conversation scrolled to a dense stretch of the seeded year-deep history, showing torn paper notes, real handwriting, tape, photographs, voice notes, reactions, replies, and non-message events all rendered inline in the same single chronological thread. It carries the strictest standard in the set: no two visible tears may repeat, every contact shadow must share one light direction, and the paper must still read as photographed rather than simulated when this capture is zoomed to 300 percent. If this single frame does not convince someone seeing the project for the first time, the build is not finished.
  _Minimum: 1440x3120, native capture, no downscaling and no lossy compression_
  _This is the hero artifact._

**03 · `03_us.png`** — Us
  All four shared-life modules present and populated from the seeded history — the date planner and tracker with past and upcoming dates, the shared to-do list with items assigned to both people, the calendar showing anniversaries counting down, and rituals and streaks presented as a quiet record that never nags or punishes. Proves the module floor is met and that a fifth module would fit without disturbing the other four.
  _Minimum: 1440x3120_

**04 · `04_moments.png`** — Moments
  The shared archive working as a filtered view over the single event spine rather than as a second store, showing the media gallery, the milestone and anniversary timeline, and the feeling history against a full year of seeded content, with filtering by person, date range, event type, and specific feeling visible in the frame. Proves the archive holds up under real volume rather than against a handful of sample rows.
  _Minimum: 1440x3120_

**05 · `05_settings.png`** — Settings
  Pairing state showing exactly two linked devices, per-event-type notification and scheduled-ping configuration including quiet hours, and the feeling-authoring tools with at least one user-created feeling sitting first-class alongside the built-ins. Proves that customization is real rather than promised.
  _Minimum: 1440x3120_

**06 · `06_unfolding.mp4`** — A note unfolding
  A received note opening from folded to flat, with real creases catching a consistent soft daylight across the entire motion. A still cannot prove this: the fold must read as rendered geometry lit from one direction rather than as a transform applied to a flat image, and this is the clip that exposes a faked material system.
  _Minimum: 1080x2340, 60 fps, at least 4 seconds, no dropped frames_

**07 · `07_feeling_landing.mp4`** — A feeling landing
  A feeling arriving on the receiving device from end to end — the ambient or notification surface reacting first, the feeling appearing as a physical object rather than an icon, the haptic pattern annotated on the timeline of the clip, and the event settling into the single thread. Proves the emotional layer works as transmitted sensation rather than as a message wearing a different colour.
  _Minimum: 1080x2340, 60 fps, at least 6 seconds_

**08 · `08_state_propagating.mp4`** — State propagating
  One person changing their mood, need, energy, or place, and the other person's device visibly changing in response — including on at least one screen outside Pulse, proving partner state is legible from everywhere rather than only from home, and showing the change reaching the other device without the app being opened.
  _Minimum: 1080x2340, 60 fps, at least 8 seconds, both devices' screens visible in sequence_

**09 · `09_two_devices.png`** — Two devices, one moment
  The second hero. The Android app and the iOS PWA in a single frame, one device mid-gesture and the other showing the sensation arriving, both rendering the same paper stock, the same handwriting, the same feeling object, and the same partner state. This is the only artifact in the fixed set that proves the PWA is not a reduced edition of the Android app, so it carries the same strictest standard as the Chat hero.
  _Minimum: 3840x2160, both screens legible enough to compare material rendering side by side_
  _This is the hero artifact._

**10 · `10_first_run.png`** — First run, empty
  The single permitted empty-state artifact: the app on a genuinely fresh install before any history exists, showing that every empty surface is specifically written and drawn in the couple's own voice, with no product-marketing tone, no self-reference by the app, and no cheerful placeholder copy. Every other artifact in this set is captured against the seeded year-deep history; this is the only one that is not.
  _Minimum: 1440x3120_

**File structure**

```
app/                                                # the single Flutter codebase; app/lib/spine/ is the only package allowed to import a storage driver
assets/                                             # baked material library with MANIFEST.json recording generator and settings for every file
blender/                                            # scenes and headless scripts that regenerate every file in assets/ from nothing
evidence/                                           # the seventeen fixed artifacts: 01_pulse.png, 02_chat.png, 03_us.png, 04_moments.png, 05_settings.png, 06_unfolding.mp4, 07_feeling_landing.mp4, 08_state_propagating.mp4, 09_two_devices.png, 10_first_run.png, 11_chat_scroll.mp4, 12_search.png, 13_messenger_states.png, 14_media_viewer.png, 15_authored_feeling.mp4, 16_setup_android.png, 17_setup_pwa.png
seed/                                               # the year-deep history as spine events against a frozen now, with people.json naming the two invented people, loaded only behind --seed=year
docs/                                               # the committed brief, README.md, PHONES.md, VOICE.md, EVENT_TYPES.md, SIGNALS.md, FEELINGS.md
app/lib/transport/                                  # the transport interface with host and client roles, cursor sync, outbox, and pairing authentication, fixed in the first commit
app/lib/transport/local/                            # the development transport with injectable disconnects, naming itself in every report; never used in the final proof
app/lib/transport/tailscale/                        # the production transport added last without touching the interface
app/lib/setup/                                      # the startup checklists for Android and the PWA, and the HTTP bootstrap page that serves the CA profile
app/lib/modules/<name>/                             # one directory per shared-life module, registered through one registry file so a new module is a directory plus one line
tools/                                              # the handwriting font builder, the capture scripts, the SSIM and frame-distinctness checks, and the string lint
evidence/crops/                                     # derived 300 percent crops, clip frame strips, and the dusk Pulse capture, handed to critics, never counted as artifacts
evidence/SCORE.json                                 # per-session category scores as the lower of critic and builder, total, and declined findings with quoted artifact and reason
evidence/DIFF.json                                  # per-artifact SSIM against the previous session and the coherence critic's label
evidence/reliability.json                           # machine-run messenger test report with a transport field, tailscale in the final session
evidence/frames.json                                # scroll frame timings from the emulator per session
evidence/coldstart.json                             # transport field, both nodes' tailscale status, the exchanged event ids, and arrival timestamps from the last cold start
evidence/critics/<cycle>/                           # the six critic reports for that cycle, one JSON file each
critics/                                            # the six critic prompts, each containing only the mission goal, its rubric category, and the artifact list; the code critic's prompt also names app/
docs/PHONES.md                                      # a mirror of the in-app setup checklists for the two phones, the key expiry note, and the builder's verification dates
docs/VOICE.md                                       # tone rules and example strings for setup, empty states, errors, pings, and notifications, written before step 09
toolchain/                                          # gitignored; pinned Flutter, Android SDK and AVD, Blender, ffmpeg, tailscaled, and the two tailscaled state directories installed by bootstrap.sh
bootstrap.sh, run.sh, capture.sh                    # the three documented commands; run.sh takes --transport=local during the build and --transport=tailscale in the final phase
DIRECTION.md, PLAN.md, INVENTORY.md, TASK_STATE.md  # as in the brief, with TASK_STATE.md also carrying the fourth-module commit hash, the transport in use, the WebKit texture budget, and the last successful commands
```


---

## 09 / FAILURE CONDITIONS

The following make the delivered result unacceptable:

- Faked material: any paper surface that is a CSS gradient, a tiled repeating texture, procedural noise, or a stock texture pulled from the internet rather than produced through the scan and Blender pipeline. Reusing a single tear mask across the app because generating dozens of them was slow is the same failure by a different route.
- Mocked transport: anything that simulates delivery locally rather than genuinely crossing Tailscale between two devices — a fake latency timer, a local echo, a single-process stand-in — presented as though the transport were working.
- Staged evidence: any artifact that is a mockup, hand-composited, upscaled, or captured from a design file rather than from the running app, including a two-device frame assembled from two separate single-device captures.
- Hollow families: meeting a family floor nominally rather than genuinely — six feelings called a vocabulary, three partner-state signals, one module standing in for four, or reaching a required count with variants that differ only in colour.
- A reduced PWA: the iOS build missing regions, feelings, or event types that the Android build has, with nothing deliberately designed standing in their place.
- A second store: any part of the app keeping its own history alongside the single event spine, so that two records of the same relationship can drift apart.
- Sample-grade seed data: repeated messages, filler text, or obviously generated content in the seeded year, which is fatal because every screen in the app is designed and judged against that history.
- Silent scope reduction: quietly dropping a module, a region, a family member, or an artifact from the fixed set and reporting the work as complete anyway.
- Any file in assets/ without an entry in assets/MANIFEST.json naming the blender/ or tools/ script and settings that produced it, or any asset or font downloaded from the internet.
- A tear mask counted as distinct when it is a flip, rotation, scale, or crop of another mask in the pool.
- A transport interface whose first commit lacks host and client roles, cursor sync, an outbox, or pairing authentication, or a Tailscale implementation that required changing that interface.
- A reliability or cold-start report whose transport field is not tailscale presented as transport proof; the local transport is permitted only during the build and must name itself in every report.
- A Tailscale proof in which either peer address is outside 100.64.0.0/10 and not a MagicDNS name, or in which both peers share one process, one tailscaled state directory, or one node key.
- Spine content travelling by any path other than the Tailscale channel; a Web Push payload carrying anything beyond event kind and sender.
- The host binding to any address other than its tailnet address, or accepting a request not authenticated with the pairing key.
- TS_AUTHKEY, a CA private key, or a pairing secret appearing in any committed file.
- A setup step that asks a person to confirm something the device can verify itself, or a checklist tick not driven by an observed event.
- Setup copy that names the app, uses an exclamation mark, or addresses the reader as a user; naming Tailscale, the Play Store, the App Store, Safari, or Settings is allowed.
- A messenger capability from rubric row 01 not exercised in evidence/reliability.json: send, ack, read, reply, react, edit, delete, voice note, video, search across all event types, viewer, draft survival across restart, kill mid-send, offline queue, reconnect ordering, host-offline outbox.
- An evidence clip in which any frame is pixel-identical to its predecessor, or that was not produced by capture.sh with the driven clock and RNG seed recorded in its log.
- A two-device frame not produced by one grab of one display hosting both windows, as recorded in the capture log with both window ids.
- Any file outside app/lib/spine/ that imports a storage driver such as sqflite, drift, hive, shared_preferences, or indexed_db; enforced by a test that fails the build.
- A derived current-state cache that cannot be rebuilt from the spine alone, verified by a golden test that replays the log and compares every region's view.
- Typing indication or presence ticks stored as events, or read markers rendered as rows in the thread.
- A feeling that shares its object asset, name, or haptic sequence with another feeling; a family with fewer than five members; a partner-state signal without its own source and rendering; fewer than three declared, three passive, two need or energy, or one place signal.
- A category score in evidence/SCORE.json higher than that session's critic score for the category, or a declined finding that restores points.
- An artifact label in evidence/DIFF.json assigned by the builder, or a regressed artifact carried into the next cycle.
- A rubric row 01 disqualifier scored at the floor; a disqualifier scores strictly below the floor.
- The seed present in a build started without --seed=year, or 10_first_run.png, 16_setup_android.png, or 17_setup_pwa.png taken from a build started with it.
- A displayed string containing the app's own name, an exclamation mark, or a sentence addressing the reader as a user; enforced by a lint over the string table including setup, notifications, empty states, and errors.
- The word streak, any count, best run, reset, or broken state on the Rituals surface; any ping not authored and scheduled by one of the two people.
- A system emoji glyph rendered anywhere in the app.
- Night appearance implemented as a uniform dim or tint layer rather than the dusk transform and lamp render.
- The PWA missing any region, feeling, event type, or off-app surface other than the documented absent peripheral surface.
- A fold or crumple sequence playing fewer than 30 unique frames per second or exceeding the WebKit texture budget recorded in TASK_STATE.md.
- A missing artifact replaced by a placeholder image; a missing artifact is recorded as missing in SCORE.json.
- A critic run inside the builder's context; each critic is a separate invocation whose input is only critics/<name>.md plus the evidence directory, and the code critic additionally receives app/ with no history.
- Any file in assets/ without an entry in assets/MANIFEST.json naming the blender/ or tools/ script and settings that produced it, or any asset or font downloaded from the internet.
- A tear mask counted as distinct when it is a flip, rotation, scale, or crop of another mask in the pool.
- A transport interface whose first commit lacks host and client roles, cursor sync, an outbox, or pairing authentication, or a Tailscale implementation that required changing that interface.
- A reliability or cold-start report whose transport field is not tailscale presented as transport proof; the local transport is permitted only during the build and must name itself in every report.
- A Tailscale proof in which either peer address is outside 100.64.0.0/10 and not a MagicDNS name, or in which both peers share one process, one tailscaled state directory, or one node key.
- Spine content travelling by any path other than the Tailscale channel; a Web Push payload carrying anything beyond event kind and sender.
- The host binding to any address other than its tailnet address, or accepting a request not authenticated with the pairing key.
- TS_AUTHKEY, a CA private key, or a pairing secret appearing in any committed file.
- A setup step that asks a person to confirm something the device can verify itself, or a checklist tick not driven by an observed event.
- Setup copy that names the app, uses an exclamation mark, or addresses the reader as a user; naming Tailscale, the Play Store, the App Store, Safari, or Settings is allowed.
- A messenger capability from rubric row 01 not exercised in evidence/reliability.json: send, ack, read, reply, react, edit, delete, voice note, video, search across all event types, viewer, draft survival across restart, kill mid-send, offline queue, reconnect ordering, host-offline outbox.
- An evidence clip in which any frame is pixel-identical to its predecessor, or that was not produced by capture.sh with the driven clock and RNG seed recorded in its log.
- A two-device frame not produced by one grab of one display hosting both windows, as recorded in the capture log with both window ids.
- Any file outside app/lib/spine/ that imports a storage driver such as sqflite, drift, hive, shared_preferences, or indexed_db; enforced by a test that fails the build.
- A derived current-state cache that cannot be rebuilt from the spine alone, verified by a golden test that replays the log and compares every region's view.
- Typing indication or presence ticks stored as events, or read markers rendered as rows in the thread.
- A feeling that shares its object asset, name, or haptic sequence with another feeling; a family with fewer than five members; a partner-state signal without its own source and rendering; fewer than three declared, three passive, two need or energy, or one place signal.
- A category score in evidence/SCORE.json higher than that session's critic score for the category, or a declined finding that restores points.
- An artifact label in evidence/DIFF.json assigned by the builder, or a regressed artifact carried into the next cycle.
- A rubric row 01 disqualifier scored at the floor; a disqualifier scores strictly below the floor.
- The seed present in a build started without --seed=year, or 10_first_run.png, 16_setup_android.png, or 17_setup_pwa.png taken from a build started with it.
- A displayed string containing the app's own name, an exclamation mark, or a sentence addressing the reader as a user; enforced by a lint over the string table including setup, notifications, empty states, and errors.
- The word streak, any count, best run, reset, or broken state on the Rituals surface; any ping not authored and scheduled by one of the two people.
- A system emoji glyph rendered anywhere in the app.
- Night appearance implemented as a uniform dim or tint layer rather than the dusk transform and lamp render.
- The PWA missing any region, feeling, event type, or off-app surface other than the documented absent peripheral surface.
- A fold or crumple sequence playing fewer than 30 unique frames per second or exceeding the WebKit texture budget recorded in TASK_STATE.md.
- A missing artifact replaced by a placeholder image; a missing artifact is recorded as missing in SCORE.json.
- A critic run inside the builder's context; each critic is a separate invocation whose input is only critics/<name>.md plus the evidence directory, and the code critic additionally receives app/ with no history.
- Any file in assets/ without an entry in assets/MANIFEST.json naming the blender/ or tools/ script and settings that produced it, or any asset or font downloaded from the internet.
- A tear mask counted as distinct when it is a flip, rotation, scale, or crop of another mask in the pool.
- A transport interface whose first commit lacks host and client roles, cursor sync, an outbox, or pairing authentication, or a Tailscale implementation that required changing that interface.
- A reliability or cold-start report whose transport field is not tailscale presented as transport proof; the local transport is permitted only during the build and must name itself in every report.
- A Tailscale proof in which either peer address is outside 100.64.0.0/10 and not a MagicDNS name, or in which both peers share one process, one tailscaled state directory, or one node key.
- Spine content travelling by any path other than the Tailscale channel; a Web Push payload carrying anything beyond event kind and sender.
- The host binding to any address other than its tailnet address, or accepting a request not authenticated with the pairing key.
- TS_AUTHKEY, a CA private key, or a pairing secret appearing in any committed file.
- A setup step that asks a person to confirm something the device can verify itself, or a checklist tick not driven by an observed event.
- Setup copy that names the app, uses an exclamation mark, or addresses the reader as a user; naming Tailscale, the Play Store, the App Store, Safari, or Settings is allowed.
- A messenger capability from rubric row 01 not exercised in evidence/reliability.json: send, ack, read, reply, react, edit, delete, voice note, video, search across all event types, viewer, draft survival across restart, kill mid-send, offline queue, reconnect ordering, host-offline outbox.
- An evidence clip in which any frame is pixel-identical to its predecessor, or that was not produced by capture.sh with the driven clock and RNG seed recorded in its log.
- A two-device frame not produced by one grab of one display hosting both windows, as recorded in the capture log with both window ids.
- Any file outside app/lib/spine/ that imports a storage driver such as sqflite, drift, hive, shared_preferences, or indexed_db; enforced by a test that fails the build.
- A derived current-state cache that cannot be rebuilt from the spine alone, verified by a golden test that replays the log and compares every region's view.
- Typing indication or presence ticks stored as events, or read markers rendered as rows in the thread.
- A feeling that shares its object asset, name, or haptic sequence with another feeling; a family with fewer than five members; a partner-state signal without its own source and rendering; fewer than three declared, three passive, two need or energy, or one place signal.
- A category score in evidence/SCORE.json higher than that session's critic score for the category, or a declined finding that restores points.
- An artifact label in evidence/DIFF.json assigned by the builder, or a regressed artifact carried into the next cycle.
- A rubric row 01 disqualifier scored at the floor; a disqualifier scores strictly below the floor.
- The seed present in a build started without --seed=year, or 10_first_run.png, 16_setup_android.png, or 17_setup_pwa.png taken from a build started with it.
- A displayed string containing the app's own name, an exclamation mark, or a sentence addressing the reader as a user; enforced by a lint over the string table including setup, notifications, empty states, and errors.
- The word streak, any count, best run, reset, or broken state on the Rituals surface; any ping not authored and scheduled by one of the two people.
- A system emoji glyph rendered anywhere in the app.
- Night appearance implemented as a uniform dim or tint layer rather than the dusk transform and lamp render.
- The PWA missing any region, feeling, event type, or off-app surface other than the documented absent peripheral surface.
- A fold or crumple sequence playing fewer than 30 unique frames per second or exceeding the WebKit texture budget recorded in TASK_STATE.md.
- A missing artifact replaced by a placeholder image; a missing artifact is recorded as missing in SCORE.json.
- A critic run inside the builder's context; each critic is a separate invocation whose input is only critics/<name>.md plus the evidence directory, and the code critic additionally receives app/ with no history.
- Any file in assets/ without an entry in assets/MANIFEST.json naming the blender/ or tools/ script and settings that produced it, or any asset or font downloaded from the internet.
- A tear mask counted as distinct when it is a flip, rotation, scale, or crop of another mask in the pool.
- A transport interface whose first commit lacks host and client roles, cursor sync, an outbox, or pairing authentication, or a Tailscale implementation that required changing that interface.
- A reliability or cold-start report whose transport field is not tailscale presented as transport proof; the local transport is permitted only during the build and must name itself in every report.
- A Tailscale proof in which either peer address is outside 100.64.0.0/10 and not a MagicDNS name, or in which both peers share one process, one tailscaled state directory, or one node key.
- Spine content travelling by any path other than the Tailscale channel; a Web Push payload carrying anything beyond event kind and sender.
- The host binding to any address other than its tailnet address, or accepting a request not authenticated with the pairing key.
- TS_AUTHKEY, a CA private key, or a pairing secret appearing in any committed file.
- A setup step that asks a person to confirm something the device can verify itself, or a checklist tick not driven by an observed event.
- Setup copy that names the app, uses an exclamation mark, or addresses the reader as a user; naming Tailscale, the Play Store, the App Store, Safari, or Settings is allowed.
- A messenger capability from rubric row 01 not exercised in evidence/reliability.json: send, ack, read, reply, react, edit, delete, voice note, video, search across all event types, viewer, draft survival across restart, kill mid-send, offline queue, reconnect ordering, host-offline outbox.
- An evidence clip in which any frame is pixel-identical to its predecessor, or that was not produced by capture.sh with the driven clock and RNG seed recorded in its log.
- A two-device frame not produced by one grab of one display hosting both windows, as recorded in the capture log with both window ids.
- Any file outside app/lib/spine/ that imports a storage driver such as sqflite, drift, hive, shared_preferences, or indexed_db; enforced by a test that fails the build.
- A derived current-state cache that cannot be rebuilt from the spine alone, verified by a golden test that replays the log and compares every region's view.
- Typing indication or presence ticks stored as events, or read markers rendered as rows in the thread.
- A feeling that shares its object asset, name, or haptic sequence with another feeling; a family with fewer than five members; a partner-state signal without its own source and rendering; fewer than three declared, three passive, two need or energy, or one place signal.
- A category score in evidence/SCORE.json higher than that session's critic score for the category, or a declined finding that restores points.
- An artifact label in evidence/DIFF.json assigned by the builder, or a regressed artifact carried into the next cycle.
- A rubric row 01 disqualifier scored at the floor; a disqualifier scores strictly below the floor.
- The seed present in a build started without --seed=year, or 10_first_run.png, 16_setup_android.png, or 17_setup_pwa.png taken from a build started with it.
- A displayed string containing the app's own name, an exclamation mark, or a sentence addressing the reader as a user; enforced by a lint over the string table including setup, notifications, empty states, and errors.
- The word streak, any count, best run, reset, or broken state on the Rituals surface; any ping not authored and scheduled by one of the two people.
- A system emoji glyph rendered anywhere in the app.
- Night appearance implemented as a uniform dim or tint layer rather than the dusk transform and lamp render.
- The PWA missing any region, feeling, event type, or off-app surface other than the documented absent peripheral surface.
- A fold or crumple sequence playing fewer than 30 unique frames per second or exceeding the WebKit texture budget recorded in TASK_STATE.md.
- A missing artifact replaced by a placeholder image; a missing artifact is recorded as missing in SCORE.json.
- A critic run inside the builder's context; each critic is a separate invocation whose input is only critics/<name>.md plus the evidence directory, and the code critic additionally receives app/ with no history.

---

Begin now. Work in `love-tap`. Do not ask for confirmation before starting.