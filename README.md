# love-tap

Two people, one thread of paper. An Android app and an iOS-installable PWA from one Flutter
codebase, talking directly to each other over Tailscale: a complete multimedia messenger, an
emotional layer that turns a gesture on one phone into a sensation on the other, and a shared-life
hub for dates, to-dos, anniversaries and rituals — all views over a single event log.

The mission brief is `docs/BRIEF.md`. The design language is `DIRECTION.md`. Resumable state is
`TASK_STATE.md`.

## The three commands

```
./bootstrap.sh                                 # pinned toolchain into ./toolchain (no sudo, no prompts)
./run.sh --seed=year --transport=local         # build APK, install into the AVD, open the PWA in WebKit,
                                               # run the local transport with its faults
./run.sh --seed=year --transport=tailscale     # final phase: two userspace tailscaled nodes, real crossing
./capture.sh                                   # regenerate all seventeen evidence artifacts + DIFF.json
```

`bootstrap.sh` installs Flutter, Android cmdline-tools with one AVD, Blender, ffmpeg, tailscaled and
Playwright WebKit into `./toolchain`. It stops with a named message if a system prerequisite is
missing (`tools/apt-prereqs.sh` lists them for Ubuntu 24.04). `TS_AUTHKEY` is only needed for
`--transport=tailscale`; when it is absent bootstrap records it as pending and continues.

`--seed=year` loads the year-deep seeded history from `seed/`; without it the app starts empty.

## Cold start

`git clone <repo> && cd love-tap && ./bootstrap.sh && ./run.sh --seed=year --transport=local`
is the single path every session and every reviewer depends on.

## Unverified here (honest list)

This is built in a headless container: no phones, no GPU, no scanner. Left to the builder on real
hardware, with the in-app setup checklist and `docs/PHONES.md` as the path:
- real iPhone install of the PWA and the CA profile;
- a real Web Push arriving on the iPhone;
- real haptics on the Android phone;
- the two real phones talking over Tailscale (the container proof uses two userspace tailscaled nodes).
