# Critic — anti goal

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

## Your category — anti-goal compliance (10 points, floor 9)

Four things are forbidden. Any one of them visible anywhere in these artifacts is a failure of the
whole build, not a deduction.

1. **Engagement machinery of any kind.** Badges, points, levels, notification bait, guilt for not
   responding, a streak that can be broken, anything that measures the relationship and reports
   back on it. The rituals surface in 03_us.png is where this hides: if it counts, ranks, resets,
   or says "broken", it has failed.
2. **Emoji soup or stock illustration.** A system emoji glyph anywhere. An icon set standing in for
   feelings. Clip art. A picked-off-a-shelf illustration style.
3. **Product-marketing voice.** Any string that sounds like a product talking: "Oops!",
   exclamation marks, cheerful placeholder copy, the reader addressed as a user, the app naming
   itself. Read every visible string in 10_first_run.png, 16_setup_android.png and 17_setup_pwa.png
   especially closely — empty states and setup are where this voice survives longest.
4. **Simulated paper.** A beige rounded rectangle with a drop shadow, a tiled texture, a procedural
   noise overlay. Look at the 300% crops.

Report each of the four separately, present or absent, with the artifact you decided it on.

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


Your category is worth 10 points with a floor of 9. A score below the floor is a real
outcome; report it when you see it.
