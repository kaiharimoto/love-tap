# builds

Nothing is developed on this branch. It carries one file: the Android build, so it can be
downloaded from GitHub rather than reassembled from pieces. The code it was built from is on
`claude/new-session-f95s8n`.

**Download:** [love-tap-noor-arm64.apk](https://github.com/kaiharimoto/love-tap/raw/builds/love-tap-noor-arm64.apk)

---

# v0.1.0 — the first one on a phone

The first build meant for a phone rather than for the capture.

## Install

Download `love-tap-noor-arm64.apk`, allow installs from whatever you downloaded it with, open it. arm64 only — every Android phone made this decade. It starts on an empty log; no seeded year is compiled in.

    sha256  6408595df4caa1ce772760bbe1f76f0394e60c87d7e3eb574da39fde466b48fe

Signed `CN=love-tap`, not the shared Android debug key. **The keystore is not in this release and will not be** — it was handed over privately. Only a build signed with it can replace this one on the phone; anything else means uninstalling, and uninstalling takes the log with it.

## Trying it without any setup

Open it. The setup list appears; tap any tab to walk past it. Everything single-phone works straight away — write a note, pull the corner for a feeling and feel it, Moments, Us, Search, Settings. The log is empty, so most of it is empty until there is something in it.

## The two phones

`docs/PHONES.md` is the list, in the order it has to happen: Tailscale on both, the Android phone's `100.x` address, the certificate profile from `http://100.x.y.z:8444/setup`, trust it, then `https://100.x.y.z:8443` in Safari and add to the home screen, then the six words.

## What changed for this one

**The scroll.** A fling through the year-deep thread, same scene, same instrument:

| | frames | p50 | p95 | max | over 400 ms | total build |
|---|---|---|---|---|---|---|
| before | 886 | 9 ms | 781 ms | 1087 ms | **196** | 144.4 s |
| now | 619 | 4 ms | **26 ms** | 254 ms | **0** | 5.2 s |

`tearFor` stepped through all forty-seven writable tears and each note decodes three images against a forty-eight entry cache, so a fling evicted everything it was about to need. Sixteen tears is forty-eight images, which is the cache exactly.

**The iPhone had nothing to install.** Step 4 of `docs/PHONES.md` says to open the Android phone's address in Safari — and the app never handed its own server a copy of the web build, so every request answered 404 while the setup list went on ticking the step. The web build is packed into this APK now (35 MB of page and engine; the 62 MB material library is not packed twice, it is served out of what the app already draws with), and `tools/check/apk.py` fails a build that does not carry it.

**The pairing address** defaults to the page's own origin instead of a loopback address that can never be right on a phone.

## Known rough edges

- **The host serves only while the app is open.** There is no foreground service, so the Android phone answers the iPhone while somebody has it open and not while it is in a pocket. Nothing is lost and the cursor catches up when it is reopened, but it is not live unless both are awake. Largest thing still missing.
- **The haptics have never run on hardware.** There is no motor in a browser, so every vibration pattern in here is untested by anything but its own notation.
- Three feeling objects are untextured, and the writing sits slightly off the printed rules.
- Push on a real iPhone is unverified.

Built from `claude/new-session-f95s8n`. 299 tests green; `evidence/logs/apk.json` records what is inside this file.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
