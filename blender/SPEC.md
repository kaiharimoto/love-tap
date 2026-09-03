# blender/ — SPEC

Scenes and headless scripts that regenerate every file in `assets/` from nothing. Every script
imports `blender/rig/common.py` and uses only its lights; nothing else may add a light. Run with
`toolchain/blender/blender -b -noaudio -P <script> -- <args>` (or `blender/run.sh <script> …`).

Every output file gets a `assets/MANIFEST.json` entry written by the script through
`blender/rig/manifest.py` (`record(path, generator, settings)`), so no asset exists without its
generator and settings. `tools/manifest.py --check` fails if any file under `assets/` is missing
from the manifest, if any file exceeds 95 MB, or if any entry points at a missing generator.

## Real-world scale

Paper is modelled at real size in metres (A5 148×210 mm; a torn strip ~ 120×45 mm; a sticky note
76×76 mm; an index card 127×76 mm). The orthographic top camera frames the sheet with a 4 mm margin
so the desk shows at the edges (cropped by the app). Renders are 300 px per cm (≈ 762 dpi) for
stocks → A5 = 4440×6300 px; that is the "scan"; stocks are downsampled to 2400×3400 for the app
and the full render kept under `assets/paper/full/` only if ≤ 95 MB, else not committed and noted.

## Stocks (`blender/paper/stocks.py`)

| id | base | rules (Python-generated image, misregistered) | extras |
|---|---|---|---|
| `lined` | warm off-white `#f1ecdf` | 8 mm feint blue `#b9cbe0` rules, red margin `#d98c86` at 32 mm | 4 aging variants (rule offset ±0.4 mm, rotation ±0.2°, yellowing 0.1–0.55, warp) |
| `graph` | cool `#e9ecec` | 5 mm grid `#b9cbe0`, heavier every 10 mm | 4 variants |
| `spiral` | as lined | as lined | left edge with punched spiral holes and the torn fringe geometry, 4 variants |
| `looseleaf` | `#f3eee3` | 7 mm rules, no margin | two punched holes on the left, 4 variants |
| `legal` | `#f3e6a8` | 8.7 mm blue rules, double red margin | 2 variants |
| `index` | `#f6f1e6` | one red top rule, 6 mm blue rules | 2 variants |
| `sticky_yellow` / `sticky_pink` / `sticky_blue` | `#f3e08a` / `#f2c1c1` / `#bcd8e8` | none | slight curl at the bottom edge (shape key), 2 variants each |
| `receipt` | `#f4f2ea` | faint printed lines (stamp face) | thermal-paper grey `#8a8a8a` print, 1 variant |

Every stock is rendered under **daylight** and **dusk** (`_dusk` suffix). Paper material from
`common.paper_material` with tooth 0.8–1.3 and per-stock fibre scale; the sheet has a very slight
warp (a 2-term sine displacement, ≤ 0.6 mm) so the rules are not perfectly straight.

## Tears (`tools/tears/tear.py` → `blender/paper/tear_relief.py`)

1. `tear.py` generates ≥ 48 alpha masks (2048×2048, the mask is the paper piece, white = paper):
   a wandering fracture line from a seeded random walk with 1/f roughness, then per-fibre pull-out
   (short fibres 0.3–2.5 mm along the line, both sides), then a feathered fuzz band (0.4 mm).
   Each mask has its own seed, its own piece shape (strip, half sheet, corner, ragged rectangle,
   diagonal), and its own tear direction. `tools/tears/distinct.py` computes normalised
   cross-correlation of each mask's edge signature against every other mask under the D4 group and
   scales 0.8–1.25; any pair above 0.72 rejects the newer mask, and the generator draws again.
2. `tear_relief.py` extrudes each mask into a thin sheet (0.1 mm) with the fibre edge displaced, and
   renders under the rig: the **edge light** (a colour PNG with alpha of the torn piece lit by the
   rig, so the fibres catch the daylight from the upper-left) and its **contact shadow**
   (`_shadow.png`, shadow-catcher render, alpha only). The app composites stock × mask, then edge
   light, over the shadow.

Outputs: `assets/tears/tear_NNN.png` (mask), `tear_NNN_edge.png`, `tear_NNN_shadow.png`,
`tear_NNN_shadow_dusk.png`.

## Folds (`blender/folds/`)

Cloth-free: shape keys with a per-crease hinge, rendered as image sequences under the rig, film
transparent, sheet 148×105 mm (A6) at 540×720 px per frame, WebP lossless via ffmpeg from PNG.

| sequence | frames | motion |
|---|---|---|
| `unfold_thirds` | 240 (4 s @ 60) | a letter folded in thirds opens: top flap lifts and lays back (0–1.6 s), bottom flap (1.4–3.2 s), sheet settles with the creases still catching light (3.2–4 s) |
| `unfold_half` | 240 | folded in half, opens like a book, settles |
| `crumple_open` | 120 | a crumpled ball relaxes into a creased sheet (lattice + noise displacement decreasing) |
| `corner_curl` | 60 | a corner lifts and curls, then drops (a loop for the sender corner) |

Every frame must differ from its predecessor (tools/check/frames_distinct.py). Creases are real
geometry (a bevelled hinge line with a slight tear of the fibres on the outside of the fold) so the
light changes across the crease as it turns. Contact shadow is rendered in the same frame (shadow
catcher) so the shadow moves with the flap.

## Objects (`blender/objects/`)

The 3D objects from `docs/FEELINGS.md`, one script per object family, each rendered from the top
camera at 1200×1200 with film transparent, plus `_shadow.png` from a shadow-catcher render of the
same frame, daylight and dusk. Materials: paper (from `common.paper_material`), foil (metallic
0.9, roughness 0.25, gold), thread/string (a curve with a fibre bump), rubber, pencil (wood +
graphite core), steel (staples), wax (candle), thermal paper (ticket), plaster (fabric + gauze pad).

Objects: `obj_heart_fold`, `obj_crane`, `obj_boat`, `obj_blanket_fold`, `obj_crumple_ball`,
`obj_plane`, `obj_fortune_teller`, `obj_crown`, `obj_ribbon`, `obj_string_loop`, `obj_knot`,
`obj_rubber_band`, `obj_stone`, `obj_candle`, `obj_snapped_pencil`, `obj_staple_chain`,
`obj_spitball`, `obj_torn_corner`, `obj_ticket`, `obj_plaster`, `obj_gold_star`, `obj_confetti`,
`obj_clover`, `obj_coffee_ring` (a stain rendered as a wet-ring material on a paper card).

Flat doodles (`obj_thumbprint`, `obj_margin_sun`, `obj_corner_moon`, `obj_chair`, `obj_window`,
`obj_scribble`, `obj_rain`, `obj_tongue_face`, `obj_firework`, `obj_mug`) are drawn by
`tools/doodles/draw.py` with the stroke engine from `tools/handwriting` (ballpoint and pencil pen
models), rendered at 1200×1200 with alpha; they have no shadow (ink is flat).

## Bits (`blender/bits/bits.py`)

≥ 16 tape pieces (translucent amber `#d9b46b` α 0.55, torn ends, slight wrinkles, each a distinct
length and tear), 6 staples, 4 paper clips, 3 bulldog clips, 2 pins, 4 sticker remnants, all with
baked shadows, daylight and dusk.

## Shell furniture (`blender/shell/`)

The desk surface (`desk_2400x3400.png` + dusk), the index-card tabs (five, torn differently), the
partner strip backing (torn strips from every stock, four each), the feeling corner (a curled
corner sequence reused from `corner_curl`).

## Seed photographs (`blender/seed_photos/`)

Renders `seed/photos/<id>.jpg` for every entry in `seed/photos/index.json`: still lifes under a
phone-photo camera (perspective, 28 mm, slight tilt, shallow depth of field, natural light from
the same window rig or an interior lamp), 1200×1600, JPEG quality 86 with slight noise. Scenes are
built from primitives and procedural materials; no textures are downloaded.

## The gate

Before any screen is styled, `blender/paper/closeup.py` renders one note: a torn strip of `lined`
with two lines of NoorHand ink, a piece of tape, and its contact shadow, at 300 % of the app's
scale. The builder judges it against the anti-goal (does it read as photographed paper?) and
records the verdict in `DIRECTION.md`. If it reads as an approximation, the pipeline is redone.
