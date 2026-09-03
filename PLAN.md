# PLAN

Dimensions, structure, coverage, required parts. The brief is `docs/BRIEF.md`; this is how it is met.

## Targets

- Android native app (host role), built as APK by `run.sh`, installed into the AVD `lovetap`
  (1440×3120 @ 560 dpi — the artifact minimum is the Pixel 7 Pro panel).
- iOS-installable PWA (client role): the Flutter web build served by the host over HTTPS on its
  tailnet address, standalone manifest, apple-touch-icon, service worker; exercised in Playwright
  WebKit at 1080×2340 device pixels (the clip minimum) — a Chromium result does not count.

## Architecture (one codebase, `app/`)

```
app/lib/
  spine/            the only package that imports a storage driver (drift + sqlite3 native / wasm)
                    Event, EventType registry (14+), append/replay, cursors, FTS, blob store, projections
  transport/        Transport interface: roles Host|Client, cursor sync, outbox, pairing auth, blobs
  transport/local/  dev transport: loopback HTTP with injectable faults; reports transport:"local"
  transport/tailscale/  production transport: same protocol bound only to the tailnet address
  setup/            startup checklists (Android, PWA) driven by observed events; HTTP bootstrap page
  material/         paper, tears, folds, handwriting, objects, shadows, light condition, motion
  feelings/         30+ built-ins, families, authored feelings, haptic + sound + animation engines
  state/            partner-state signals (declared, passive, need/energy, place), sources, renderers
  presence/         ambient surfaces: glanceable, interruptive, peripheral (per platform)
  regions/          pulse/ chat/ us/ moments/ settings/ — views over the spine
  modules/          dates/ todos/ calendar/ rituals/ + registry.dart (a fifth = directory + one line)
  voice/            the string table (linted by tools/lint/strings.py)
  app.dart, main.dart, flags.dart (--seed=year, --transport=, capture mode)
app/test/           persistence-boundary test, spine schema test, replay golden test, transport
                    fault tests, web-push RFC 8291 / VAPID vectors, string lint test
```

Every region and module is a projection over `spine`. No second store. Typing and presence ticks
travel on the transport as ephemeral frames and are never events. Read markers are events but are
rendered as marks on messages, never as rows.

## Coverage grid

| Family | Floor | Planned | Where |
|---|---:|---:|---|
| Built-in feelings | 30 | 33 | `app/lib/feelings/builtins.dart`, `docs/FEELINGS.md` |
| Feeling families | 5 | 6 (Warmth, Ache, Shelter, Mischief, Static, Sparkle) | same |
| Shared-life modules | 4 | 4 (dates, todos, calendar, rituals) | `app/lib/modules/` |
| Partner-state signals | 12 | 13 (3 declared, 6 passive, 2 need/energy, 2 place) | `docs/SIGNALS.md` |
| Timeline event types | 14 | 17 | `docs/EVENT_TYPES.md`, `app/lib/spine/types.dart` |
| Ambient presence surfaces | 3 | 3 per platform (PWA peripheral documented absent) | `app/lib/presence/` |
| Paper stocks | — | 9 stocks, 4 variants of notebook stocks, dusk of each | `assets/paper/` |
| Tear masks | dozens | 48+ distinct | `assets/tears/` |
| Fold sequences | — | 4 (240/240/120/60 frames) | `assets/folds/` |
| Handwriting fonts | multi-variant | 3 faces × 5 variants per glyph | `assets/fonts/` |
| Evidence artifacts | 17 | 17 + crops + 5 json | `evidence/` |

## Build order (from the brief) and session plan

1. Transport (interface fixed in its first commit; local transport with faults; restart / offline /
   long-gap tests) — session 1.
2. Spine (17 types, persistence in one package, boundary + replay tests) — session 1.
3. Unstyled messenger + `reliability.json` runner — sessions 1–2.
4. Seeded year (`seed/`), `people.json`, three anchors — session 2 (authored in parallel).
5. Material pipeline: rig, stocks, tears, folds, hands, objects, MANIFEST — sessions 2–3; the
   single-note close-up gate before any screen is styled.
6. Shell + Chat styled; scroll check; 300% crops — session 3.
7. Emotional layer — session 3–4.
8. Us modules — session 4.
9. Moments, Settings, setup, first run, VOICE.md, string lint — session 4.
10. Evidence capture every session; review cycles 1–4+ with six fresh-context critics — sessions 4+.
11. Tailscale transport, two userspace nodes, `coldstart.json` — final phase (asks for TS_AUTHKEY then).

## Evidence set (fixed names, `evidence/`)

01_pulse.png · 02_chat.png (hero) · 03_us.png · 04_moments.png · 05_settings.png ·
06_unfolding.mp4 · 07_feeling_landing.mp4 · 08_state_propagating.mp4 · 09_two_devices.png (hero) ·
10_first_run.png · 11_chat_scroll.mp4 · 12_search.png · 13_messenger_states.png ·
14_media_viewer.png · 15_authored_feeling.mp4 · 16_setup_android.png · 17_setup_pwa.png
+ SCORE.json, DIFF.json, reliability.json, frames.json, coldstart.json, crops/, critics/<cycle>/.

PNG minimum 1440×3120 (09: 3840×2160); clips 1080×2340 at 60 fps, 06 ≥ 4 s, 07 ≥ 6 s, 08 ≥ 8 s.
Captures use a driven clock and a recorded RNG seed; 09 is one grab of one X display holding the
AVD window and the WebKit window, both window ids logged.

## Assumptions recorded

- This session has tools and a filesystem; the brief's "no tool access" paragraph does not apply,
  so the work is executed rather than described.
- No KVM in the container: the AVD runs under QEMU software emulation (`-no-accel`, swiftshader).
  Boot is slow; captures use the driven clock so frame rate does not depend on emulation speed.
- No scanner, no camera, no microphone: paper is rendered (see DIRECTION.md), handwriting is
  built from authored stroke skeletons, feeling sounds are synthesised from paper-noise models in
  `tools/sound/`. Slots for real scans and recordings are documented for the builder.
- Critics run as fresh-context subagents (the brief requires it) even though the build itself is
  one head; parallel helpers may draft seed text and docs, but every material decision lives here.
