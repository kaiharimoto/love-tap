# FEELINGS

The shipped vocabulary: 34 built-in feelings in six named families. Each row is one physical
object, one haptic sequence, one sound, one colour. No two rows share an object asset or a haptic
sequence, and no two are told apart by colour alone: every one is recognisable face-down by rhythm.
User-authored feelings (`feeling_authored` events) join this table at runtime and behave identically
everywhere: same send paths, same thread rendering, same haptics, same sound, same notification,
same place in history and search.

## Haptic notation

`on@amp` pairs separated by `off` gaps, in milliseconds, amplitude 0–255. This is exactly the Android
`VibrationEffect.createWaveform(timings, amplitudes)` shape. On the PWA the same sequence drives the
**page rhythm**: the sheet lifts on each `on` (height ∝ amplitude) and settles on each `off`, and the
feeling's sound plays with the same envelope. Same data, different body.

## Intensity

A feeling is sent with `intensity` 0–1 from how long the corner is held (0.2 s → 0.3, 2 s → 1.0).
Intensity scales: haptic amplitude (×0.45 → ×1.0), object scale (×0.88 → ×1.12), landing drop height
(6 px → 28 px), sound gain (−9 dB → 0 dB). It never changes the rhythm, so the feeling stays identifiable.

## Family signatures

| family | register | haptic shape | paper | ink | sound family |
|---|---|---|---|---|---|
| Warmth | affection | long soft swells that rise then ease | lined notebook | ballpoint blue-black | paper pressed by a hand |
| Ache | longing, missing | slow, sparse pulses, each fading | graph | graphite | a page turned slowly, a breath |
| Shelter | comfort, reassurance | even pulses like a slow breath | loose leaf | soft pencil | paper smoothed flat |
| Mischief | playfulness | quick, uneven taps | sticky note | red pen | flicks, snaps, taps |
| Static | distress, frustration | jittery rapid buzz, uneven | crumpled anything | hard-pressed biro | crumples, scratches |
| Sparkle | celebration | ascending bursts | legal pad | highlighter over ink | punches, foil, rustle |

## The table

| id | family | shown as (in hand) | object asset | haptic sequence | sound | colour |
|---|---|---|---|---|---|---|
| `squeeze` | Warmth | a squeeze | `obj_heart_fold` — an origami heart | 80@90 off40 160@160 off40 320@230 | `snd_squeeze` press | `#1f2a44` |
| `forehead` | Warmth | forehead | `obj_thumbprint` — a blue-ink thumbprint | 200@120 off120 200@120 | `snd_forehead` two soft presses | `#1f2a44` |
| `warm_palm` | Warmth | warm palm | `obj_coffee_ring` — a coffee ring with a heart drawn inside | 600@140 | `snd_palm` slow rub | `#a67c52` |
| `nuzzle` | Warmth | nuzzle | `obj_clover` — a pressed clover | 90@150 off60 90@150 off60 90@150 off200 400@110 | `snd_nuzzle` three small rustles, one long | `#5d7a4a` |
| `thinking_of_you` | Warmth | thinking of you | `obj_margin_sun` — a sun doodled in a margin | 40@80 off300 40@80 off300 260@170 | `snd_thinking` two ticks, a press | `#1f2a44` |
| `goodnight` | Warmth | goodnight | `obj_corner_moon` — a folded corner with a moon | 500@120 off200 250@80 off200 120@50 | `snd_goodnight` fading press | `#2c3555` |
| `miss_you` | Ache | miss you | `obj_crane` — a paper crane | 150@220 off600 150@150 off600 150@90 | `snd_miss` page turned, slower each time | `#3a3a3c` |
| `empty_chair` | Ache | empty chair | `obj_chair` — a pencil chair | 300@200 off900 300@100 | `snd_chair` two slow breaths | `#3a3a3c` |
| `come_home` | Ache | come home | `obj_string_loop` — a loop of string | 60@255 off200 60@255 off200 60@255 off800 400@120 | `snd_home` three knocks, a sigh | `#6b5a3e` |
| `wish_you_were_here` | Ache | wish you were here | `obj_ticket` — a torn cinema ticket | 250@180 off400 250@120 off400 250@70 off400 250@40 | `snd_wish` four fading turns | `#8a6a4a` |
| `long_day` | Ache | long day | `obj_window` — a rainy window doodle | 800@100 off300 800@60 | `snd_longday` two long slow breaths | `#3a3a3c` |
| `here` | Shelter | here | `obj_boat` — a paper boat | 400@140 off400 400@140 off400 400@140 | `snd_here` three even smooths | `#4a4a4c` |
| `breathe` | Shelter | breathe | `obj_blanket_fold` — a blanket-folded sheet | 1200@110 off800 1200@110 | `snd_breathe` in, out | `#4a4a4c` |
| `its_okay` | Shelter | it's okay | `obj_plaster` — a plaster strip | 200@160 off200 200@160 off200 200@160 off200 200@160 | `snd_okay` four gentle pats | `#c9a98a` |
| `steady` | Shelter | steady | `obj_stone` — a smooth stone | 300@180 off300 300@180 off300 300@180 off300 300@180 off300 300@180 | `snd_steady` five slow taps | `#6d6d70` |
| `make_you_tea` | Shelter | i'll make you tea | `obj_mug` — a mug with steam | 100@120 off100 100@120 off100 500@150 | `snd_tea` two clinks, a pour | `#8b6b4a` |
| `hold` | Shelter | hold | `obj_candle` — a candle stub | 900@150 off100 900@150 | `snd_hold` two long presses | `#b89a5a` |
| `poke` | Mischief | poke | `obj_spitball` — a spitball | 30@255 | `snd_poke` one flick | `#a8322b` |
| `nyeh` | Mischief | nyeh | `obj_tongue_face` — a biro tongue-out face | 30@200 off50 30@200 off50 90@255 | `snd_nyeh` two taps, a raspberry of paper | `#a8322b` |
| `catch` | Mischief | catch | `obj_plane` — a paper plane | 40@120 off30 40@160 off30 40@200 off30 40@240 off30 120@255 | `snd_catch` rising flutter, a land | `#a8322b` |
| `pick_one` | Mischief | pick one | `obj_fortune_teller` — a paper fortune teller | 50@180 off120 ×6 | `snd_pick` six folds | `#e0a8b8` |
| `snap` | Mischief | snap | `obj_rubber_band` — a rubber band | 20@255 off40 60@255 off400 20@180 | `snd_snap` stretch, snap, drop | `#c98a5a` |
| `stuck_with_me` | Mischief | stuck with me | `obj_staple_chain` — a chain of staples | 30@220 off30 ×8 | `snd_stuck` eight staple clicks | `#7a7a7e` |
| `overwhelmed` | Static | overwhelmed | `obj_crumple_ball` — a crumpled ball | (25@255 off25 25@200 off25) ×5 | `snd_overwhelmed` continuous crumple | `#141a2e` |
| `ugh` | Static | ugh | `obj_scribble` — a scribbled-out line | 180@255 off60 180@255 off60 180@255 | `snd_ugh` three hard scratches | `#141a2e` |
| `snapped` | Static | snapped | `obj_snapped_pencil` — a snapped pencil | 15@255 off15 15@255 off15 15@255 off300 500@255 | `snd_snapped` three cracks, a long scrape | `#3a3a3c` |
| `tangled` | Static | tangled | `obj_knot` — a knot of thread | 40@180 off20 80@220 off20 40@180 off20 120@255 off20 40@180 off20 80@220 | `snd_tangled` uneven thread pulls | `#6b5a3e` |
| `grey` | Static | grey | `obj_rain` — rain in pencil | (60@70 off60) ×8 | `snd_grey` faint patter | `#8a8a8e` |
| `not_okay` | Static | not okay | `obj_torn_corner` — a torn-off corner | 400@255 off100 40@255 off100 40@255 off100 40@255 | `snd_notokay` one tear, three taps | `#141a2e` |
| `did_it` | Sparkle | did it | `obj_gold_star` — a foil star sticker | 40@120 off60 40@170 off60 40@220 off60 200@255 | `snd_didit` three rising taps, a peel | `#c9a23a` |
| `confetti` | Sparkle | confetti | `obj_confetti` — hole-punch circles | 30@150 off40 30@190 off40 30@230 off40 30@255 off40 30@230 off40 30@190 off40 30@150 | `snd_confetti` a handful of punches | `#f2a8c0` |
| `yes` | Sparkle | yes | `obj_firework` — a biro firework | 60@100 off40 60@180 off40 60@255 off200 60@255 off40 60@255 | `snd_yes` rising, then two bursts | `#a8322b` |
| `crown` | Sparkle | crown | `obj_crown` — a paper crown | 100@120 off100 100@170 off100 100@220 off100 100@255 off300 300@255 | `snd_crown` four rising folds, a flourish | `#f4ea6a` |
| `treat` | Sparkle | treat | `obj_ribbon` — a curled ribbon | 50@200 off80 50@200 off80 300@150 off80 50@255 | `snd_treat` two snips, a curl, a tap | `#f2a8c0` |

34 feelings · Warmth 6 · Ache 5 · Shelter 6 · Mischief 6 · Static 6 · Sparkle 5.

Sounds live in `assets/sound/<sound>.ogg`, synthesised by `tools/sound/synth.py` from paper-noise
models (no recordings exist in this container; the recipe names the real sound so the builder can
replace any file with a recording of the same length). Objects live in `assets/objects/<asset>.png`
with `<asset>_shadow.png` baked from the same render.

## Send and receive

- **Send**: hold the folded corner (any region), drag onto the feeling; releasing sends. The object
  slides off the corner and out of the top of the screen with a short paper sound. Intensity from
  hold length, shown as the object's lift while held.
- **Receive** (Android): the ambient surface reacts first (widget and standing notification take the
  object), then the haptic sequence plays, then the object lands in Pulse and in the thread: shadow
  first, object after, the sheet under it rocking once. **Receive (PWA)**: identical, with the page
  rhythm and sound in place of the haptic; the object lands in the same two places.
- **Reaction**: a feeling dropped onto a note becomes a `reaction` (object stuck to the note, no row).

## Authored feelings

Settings → feelings → "make one". A name in your hand, a family (which gives the haptic shape and
paper), an object chosen from the bits drawer (tape, staple, sticker, doodle pad) or drawn with a
finger and rendered by the stroke engine, a rhythm tapped on the screen (recorded as the same
notation), a sound picked from the recipe set. Emitted as `feeling_authored`; from then on it is in
the sender, the thread, the notifications, Moments, search — nothing checks whether a feeling is built in.
Retiring hides it from the sender but never from history.
