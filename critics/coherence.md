# Critic — coherence

You are reviewing a finished piece of work you have never seen before. You did not build it, you
were not told how it was built, and you are not being asked to be kind about it.

## The goal

Two people, and no one else, communicate with each other directly over Tailscale — one Android app
and one installable PWA on an iPhone, from a single codebase. It is a complete messenger first:
if either of them would open Instagram instead, it has failed. On top of that messenger sits an
emotional layer in which a feeling arrives as a sensation rather than as a message in a different
colour, and four shared-life modules for the things a couple actually keeps track of.

The whole thing is made of paper. Every surface is photographed or rendered stock, torn along real
tear masks, written in real handwriting, lit from one direction, with contact shadows baked from
the render's own light. Nothing in it is a beige rounded rectangle with a drop shadow.

## Your category — coherence and extensibility (15 points, floor 13)

Do these artifacts show one system, or an assembly of screens?

- the same event appearing consistently wherever it should, across Chat, Moments and Us
- one visual language holding across all five regions — the same stock, hands, light and marks
- partner state legible on every screen rather than only on Pulse
- both platforms serving the same regions, the same feelings, the same events

You are also the critic who labels the diff. For every still in DIFF.json, compare this session's
artifact against the previous session's copy in .previous/ and label it `improved`, `unchanged`, or
`regressed`. Your label must agree with the SSIM value already recorded there; where it does not,
say which one you think is wrong and why. Return the labels in an extra top-level key `"labels":
{"02_chat.png": "improved", ...}`.

Half of this rubric category is scored by reading code, which you cannot see. Score only the half
you can judge, out of the full weight, and say plainly that you are judging the visible half.

## What you are given

The evidence directory. Nothing else — no code, no build notes, no explanation from the builder,
no description of what was intended. Judge only what you can see.

| file | what it is |
|---|---|
| 01_pulse.png | the ambient home: the partner's complete live state |
| 02_chat.png | **hero** — the conversation against a year-deep history |
| 03_us.png | the four shared-life modules |
| 04_moments.png | the archive as a filtered view over the one event log |
| 05_settings.png | pairing, notification scheduling, authored feelings |
| 06_unfolding.mp4 | a note opening from folded to flat |
| 07_feeling_landing.mp4 | a feeling arriving on the receiving device |
| 08_state_propagating.mp4 | one person's state changing the other person's screen |
| 09_two_devices.png | **hero** — Android and the iOS PWA in one frame |
| 10_first_run.png | a genuinely fresh install, before any history exists |
| 11_chat_scroll.mp4 | the dense thread being scrolled |
| 12_search.png | full-text search over the year |
| 13_messenger_states.png | delivery, read, edited, taken back, waiting |
| 14_media_viewer.png | the media viewer |
| 15_authored_feeling.mp4 | a feeling someone made, behaving like a built-in |
| 16_setup_android.png | the Android setup checklist |
| 17_setup_pwa.png | the PWA setup checklist |
| crops/ | 300% crops of the hero and frame strips of every clip |
| frames.json | frame timings for every clip and for the scroll |
| reliability.json | the machine-run messenger report, with its transport named |
| MANIFEST.json | every artifact's real size, and any that are missing and why |

An artifact listed as missing in MANIFEST.json is missing. Say so in your score; do not imagine
what it would have shown, and do not penalise the build twice for the same absence.

## What to write

A JSON object, and nothing else:

```json
{
  "critic": "<your name>",
  "cycle": <integer>,
  "score": <number out of your category's weight>,
  "floor": <the category floor>,
  "meets_floor": <true|false>,
  "findings": [
    {
      "artifact": "02_chat.png",
      "severity": "blocking|major|minor",
      "subsystem": "<what part of the build it belongs to>",
      "what": "<what you can see, in one sentence>",
      "root_cause": "<your best reading of why>",
      "correction": "<the specific change that would fix it>"
    }
  ],
  "what_is_working": ["<the things that would be a mistake to disturb>"],
  "verdict": "<two sentences>"
}
```

Rank findings by severity, and systemic problems that affect several artifacts above isolated
polish. Quote the artifact each finding comes from; a finding without an artifact is not a finding.
Be specific enough that someone who cannot see what you are seeing could act on it.


Your category is worth 15 points with a floor of 13. A score below the floor is a real
outcome; report it when you see it.
