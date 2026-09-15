# What is rough

The list a build's release notes carry, so whoever installs one knows what they are looking at
before they find it themselves. `tools/release_notes.py` reads this file; keep it true and keep it
short. Something that gets fixed comes off it in the same commit that fixes it.

- **The host serves only while the app is open.** There is no foreground service, so the Android
  phone answers the iPhone while somebody has it open and not while it is in a pocket. Nothing is
  lost — both phones keep what they wrote and the cursor catches up when it is reopened — but it is
  not live unless both are awake. Largest thing still missing.
- **The haptics have never run on hardware.** There is no motor in a browser, so every vibration
  pattern in here is untested by anything except its own notation.
- **Three feeling objects are untextured** — `overwhelmed`, `hold` and `nyeh` — and the writing
  sits about half a line off the printed rules on the paper that has them.
- **Push on a real iPhone is unverified.** The manifest, the service worker and the three Apple
  meta tags are all there and recorded in `evidence/logs/pwa.json`; nobody has watched one arrive.
