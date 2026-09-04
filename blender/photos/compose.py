"""blender/photos/compose.py — turn each written scene into a recipe still.py can render.

    python3 blender/photos/compose.py --all
    python3 blender/photos/compose.py --only 2026-05_bluebells_wood --print

seed/photos/index.<month>.json says, for each of the hundred and fifteen photographs the year
refers to, who took it, what shape it is, and one sentence describing what is in it. This reads
that sentence and writes blender/photos/recipes/<id>.json: which of the three modes the picture
is in, what it stands on, what the light is doing, and what is in the frame and where.

Three modes, because the sentences fall into three kinds:

  · **tabletop** — a still life at arm's length. A loaf on a board, a rota flattened out, a
    passport on a kitchen table. The camera is thirty centimetres away and the subject fills it.
  · **room** — an interior seen from across it. A waiting room from a chair, a stripped art room,
    a drawer set on a carpet. The camera is at sitting height and there is a floor and a wall.
  · **outdoor** — a place. A canal at night, a wood full of bluebells, a car park in fog. The
    camera is at eye height and the far things are ten metres away.

Where a sentence names something the kit cannot build, the nearest thing it can is used and the
substitution is written into the recipe, so assets/MANIFEST.json records what was actually made
rather than what was asked for.
"""
import argparse
import glob
import json
import os
import re

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
RECIPES = os.path.join(HERE, "recipes")
INDEX = os.path.join(ROOT, "seed", "photos")


def said(text, *words):
    """True when the sentence says the thing is there, and not that it is absent."""
    for w in words:
        for m in re.finditer(r"\b" + w + r"\b", text):
            before = text[max(0, m.start() - 20):m.start()]
            if re.search(r"\b(no|not|without|never|empty of)\s+$", before):
                continue
            return True
    return False


# ------------------------------------------------------------------ mode
OUTDOOR = ("canal|towpath|car park|carpark|wood|woods|field|park|street|road|garden|yard|"
           "tree|trees|path|bridge|verge|marquee|hedge|tarmac|cobbles|sky|fog|moon|hill|"
           "pavement|allotment|beach|shore|platform|bus stop|scaffold|gutter|roof|lock|"
           "railing|bollard|wall of a|brick wall|lamp post|forecourt|churchyard")
TABLETOP = ("table|board|bowl|pan|mug|plate|loaf|bread|soup|cake|tin|jar|pencil|pen|"
            "sketchbook|notebook|passport|envelope|rota|timetable|roster|paper|sheet|card|"
            "worktop|counter|hob|tray|folder|folders|binders|knife|spoon|crumbs|cloth|"
            "still life|lying on|laid on|flattened out|seen from above")
ROOMISH = ("waiting room|classroom|corridor|ward|hall|carpet|stacking chairs|art room|"
           "the floor|on the floor|chest of drawers|drawer|shelf unit|staircase|landing|"
           "bathroom|hallway|stripped room|the room|studio|office|kitchen floor")


def cue_score(text, pattern):
    """How many of a mode's cue words the sentence actually uses.

    With word boundaries. Without them "a wooden table" contains "wood" and every kitchen
    still life in the year was classified as a photograph taken in a forest.
    """
    n = 0
    for word in pattern.split("|"):
        if re.search(r"\b" + word + r"\b", text):
            n += 1
    return n


# ------------------------------------------------------------------ light
def light_of(text, mode):
    """One of the conditions still.py can set up.

    Weighed rather than raced: "the night's condensation still on the roofs" at eight in the
    morning is a morning photograph, and the first version of this read the word night and shot
    a hospital car park in the dark.
    """
    day = sum(bool(re.search(r"\b" + w + r"\b", text)) for w in
              ("morning", "afternoon", "daylight", "daytime", "midday", "noon", "lunchtime",
               "sun", "sunlight", "overcast", "daylit"))
    night = sum(bool(re.search(w, text)) for w in
                (r"\bat night\b", r"\bafter dark\b", r"\bin the dark\b", r"\bno moon\b",
                 r"\bdark window\b", r"\blate at\b", r"\bmidnight\b", r"\bthree in the morning\b",
                 r"\bevening\b", r"\bdusk\b"))
    if night > day:
        if said(text, "lamp", "bulb", "lights", "lit", "lamplight", "strings of"):
            return "night_lamp"
        return "night"
    if said(text, "torch", "phone torch"):
        return "torch"
    if said(text, "fluorescent", "strip light", "strip lighting", "striplight"):
        return "strip"
    if said(text, "bare bulb", "one bulb", "bulb"):
        return "kitchen_bulb"
    if said(text, "lamp light", "anglepoise", "desk lamp", "warm lamp"):
        return "lamp"
    if said(text, "fog", "mist"):
        return "fog_dawn"
    if said(text, "overcast", "flat light", "no shadows", "grey even", "thin bright overcast"):
        return "overcast"
    if said(text, "low sun", "raking", "first light", "dawn", "early sun", "sunset", "golden",
            "low and hard"):
        return "low_sun"
    if said(text, "hard morning light", "hard light", "bright", "sunlight", "full sun"):
        return "hard_sun"
    return "window_left" if mode != "outdoor" else "overcast"


# ------------------------------------------------------------------ what it stands on
SURFACE_WORDS = [
    ("chopping board|bread board|board", "board"),
    ("steel bench|stainless|steel", "steel"),
    ("hob|stove", "hob"),
    ("kitchen table|wooden table|table|desk", "desk"),
    ("worktop|counter|melamine|formica", "melamine"),
    ("trestle|market", "trestle"),
    ("lino|linoleum", "lino"),
    ("tiles|tiled floor", "lino"),
    ("stone|windowsill|sill", "melamine"),
]

GROUND_WORDS = [
    ("wet cobbles|cobbles", "cobbles"),
    ("wet tarmac|wet road", "wet_tarmac"),
    ("tarmac|car park|road|forecourt", "tarmac"),
    ("gravel", "gravel"),
    ("leaf litter|beech|wood floor of|the floor of a|woodland", "leaf_litter"),
    ("grass|verge|lawn|meadow", "grass"),
    ("paving|pavement|flagstones", "paving"),
    ("carpet", "carpet"),
    ("snow|slush|frost", "snow"),
    ("earth|mud|bare earth|desire path", "earth"),
    ("sand|shingle|shore", "sand"),
]


def pick(text, table, default):
    for pattern, value in table:
        if re.search(pattern, text):
            return value
    return default


# ------------------------------------------------------------------ the vocabulary of things
# Each entry: pattern, builder, and a function giving its arguments from a seeded generator.
def _tabletop_vocab():
    return [
        ("loaf|sourdough|bread|heel of bread", "loaf",
         lambda r: {"length": float(r.uniform(0.20, 0.27)), "width": float(r.uniform(0.10, 0.14)),
                    "height": float(r.uniform(0.075, 0.10)), "cut": float(r.uniform(0.2, 0.45)),
                    "rot": float(r.uniform(-30, 30)), "flour": float(r.uniform(0.2, 0.8))}),
        ("chopping board|bread board|board", "board",
         lambda r: {"w": float(r.uniform(0.28, 0.40)), "d": float(r.uniform(0.20, 0.27)),
                    "thick": float(r.uniform(0.016, 0.026)), "rot": float(r.uniform(-14, 14)),
                    "scars": int(r.integers(8, 24))}),
        ("bowl", "bowl",
         lambda r: {"r": float(r.uniform(0.085, 0.125)), "h": float(r.uniform(0.045, 0.07)),
                    "rot": float(r.uniform(0, 90))}),
        ("pan|saucepan|pot", "pan",
         lambda r: {"r": float(r.uniform(0.09, 0.13)), "h": float(r.uniform(0.07, 0.11))}),
        ("mug|cup of|coffee|tea", "mug",
         lambda r: {"r": float(r.uniform(0.037, 0.045)), "h": float(r.uniform(0.085, 0.105)),
                    "rot": float(r.uniform(0, 360)), "full": float(r.choice([0.0, 0.55, 0.66]))}),
        ("knife|bread knife", "knife",
         lambda r: {"length": float(r.uniform(0.18, 0.24)), "rot": float(r.uniform(-60, 60))}),
        ("spoon|ladle handle|wooden spoon", "spoon",
         lambda r: {"length": float(r.uniform(0.22, 0.30)), "rot": float(r.uniform(-70, 70))}),
        ("ladle", "ladle", lambda r: {"rot": float(r.uniform(-30, 30))}),
        ("crumbs", "crumbs",
         lambda r: {"spread": float(r.uniform(0.05, 0.11)), "count": int(r.integers(70, 150))}),
        ("tin|biscuit tin", "tin",
         lambda r: {"r": float(r.uniform(0.07, 0.10)), "h": float(r.uniform(0.06, 0.09)),
                    "rot": float(r.uniform(0, 90)),
                    "lid": str(r.choice(["on", "beside"]))}),
        ("jar of brushes|jar", "jar",
         lambda r: {"r": float(r.uniform(0.035, 0.05)), "h": float(r.uniform(0.09, 0.14)),
                    "holds": int(r.integers(2, 7))}),
        ("pencil|stub of pencil", "pen",
         lambda r: {"as_kind": "pencil", "length": float(r.uniform(0.07, 0.16)),
                    "rot": float(r.uniform(0, 180))}),
        ("red pen|biro|pen", "pen",
         lambda r: {"as_kind": "pen", "length": float(r.uniform(0.12, 0.15)),
                    "rot": float(r.uniform(0, 180))}),
        ("folded into thirds|folded|rota|timetable|roster|shift", "folded",
         lambda r: {"w": float(r.uniform(0.19, 0.23)), "h": float(r.uniform(0.26, 0.31)),
                    "folds": 3, "rot": float(r.uniform(-12, 12)), "printed": 1.0}),
        ("grid sheet|photocopied|form|printed", "folded",
         lambda r: {"w": 0.21, "h": 0.297, "folds": 1, "rot": float(r.uniform(-10, 10)),
                    "printed": 1.0}),
        ("sketchbook|open book|notebook|book", "book",
         lambda r: {"w": float(r.uniform(0.17, 0.23)), "d": float(r.uniform(0.24, 0.31)),
                    "rot": float(r.uniform(-9, 9)), "open_book": True}),
        ("passport", "card",
         lambda r: {"w": 0.088, "h": 0.125, "rot": float(r.uniform(-25, 25)),
                    "colour": [0.020, 0.028, 0.045], "thick": 0.005}),
        ("envelope", "envelope",
         lambda r: {"w": float(r.uniform(0.20, 0.28)), "h": float(r.uniform(0.14, 0.19)),
                    "rot": float(r.uniform(-20, 20))}),
        ("card|ticket|insert|leaflet|price card|postcard|receipt", "card",
         lambda r: {"w": float(r.uniform(0.07, 0.13)), "h": float(r.uniform(0.09, 0.17)),
                    "rot": float(r.uniform(-35, 35))}),
        ("binders|folders|stack|pile of|papers", "stack",
         lambda r: {"count": int(r.integers(4, 11)), "rot": float(r.uniform(-14, 14))}),
        ("tea towel|cloth|rag|napkin", "cloth",
         lambda r: {"w": float(r.uniform(0.26, 0.40)), "d": float(r.uniform(0.18, 0.26)),
                    "rot": float(r.uniform(0, 180))}),
        ("keys|bunch of keys", "crumbs",
         lambda r: {"spread": 0.02, "count": 14}),
        ("eggs|egg tray|tray", "tray",
         lambda r: {"rows": int(r.integers(4, 6)), "cols": int(r.integers(5, 7)),
                    "rot": float(r.uniform(-10, 10))}),
        ("crate", "crate",
         lambda r: {"rot": float(r.uniform(-20, 20))}),
        ("gauge|dial|pressure", "gauge", lambda r: {"needle_deg": float(r.uniform(-70, 40))}),
        ("lift panel|buttons|button panel", "panel", lambda r: {"buttons": int(r.integers(6, 12))}),
        ("sheet of paper|paper|page|note", "sheet",
         lambda r: {"w": float(r.uniform(0.10, 0.21)), "h": float(r.uniform(0.14, 0.30)),
                    "rot": float(r.uniform(-30, 30))}),
        ("hob ring|ring of a hob|gas hob", "hob_ring", lambda r: {}),
        ("plate|saucer", "plate",
         lambda r: {"r": float(r.uniform(0.09, 0.135)), "rot": float(r.uniform(0, 90))}),
        ("cake|sponge", "cake",
         lambda r: {"r": float(r.uniform(0.07, 0.10)), "layers": int(r.integers(2, 4)),
                    "lean": float(r.uniform(3, 12))}),
        ("flask|thermos", "flask",
         lambda r: {"r": float(r.uniform(0.032, 0.042)), "h": float(r.uniform(0.20, 0.28)),
                    "rot": float(r.uniform(0, 90))}),
        ("rope|knotted length", "rope", lambda r: {"rot": float(r.uniform(0, 90))}),
        ("bag", "bag",
         lambda r: {"w": float(r.uniform(0.24, 0.34)), "d": float(r.uniform(0.16, 0.24)),
                    "h": float(r.uniform(0.26, 0.38)), "rot": float(r.uniform(0, 90))}),
    ]


OUTDOOR_VOCAB = [
    # A canal is long. Sixteen by eleven metres is a pond, and a pond photographed from its bank
    # is a mirror lying on a field: the thing that says canal is that it runs away from you and
    # goes on after the picture stops.
    ("water|canal|lock|river|reflection", "water",
     lambda r: {"w": float(r.uniform(6.0, 9.0)), "d": float(r.uniform(70.0, 120.0))}),
    ("blossom", "canopy",
     lambda r: {"radius": float(r.uniform(2.2, 3.4)), "count": 420, "leaf": 0.055,
                "colour": [0.72, 0.68, 0.62], "centre_h": float(r.uniform(4.4, 6.0))}),
    ("bare tree|bare-limbed|bare branches|branches", "limbs",
     lambda r: {"count": int(r.integers(6, 11)), "length": float(r.uniform(2.0, 3.4))}),
    ("wood|woods|trees|trunks|beech|copse|between the trunks", "wood",
     lambda r: {"count": int(r.integers(9, 18)), "height": float(r.uniform(9.0, 15.0)),
                "radius": float(r.uniform(0.16, 0.34))}),
    ("tree|trunk", "trunk",
     lambda r: {"height": float(r.uniform(5.0, 9.0)), "radius": float(r.uniform(0.14, 0.30)),
                "lean": float(r.uniform(-0.06, 0.06))}),
    ("leaves|canopy|green light|new leaves", "canopy",
     lambda r: {"radius": float(r.uniform(2.4, 3.6)), "count": 360,
                "centre_h": float(r.uniform(5.0, 7.5))}),
    ("bluebells|flowers|drift|nettles|grass running", "undergrowth",
     lambda r: {"count": int(r.integers(2600, 4200)), "height": float(r.uniform(0.20, 0.34)),
                "w": 26.0, "d": 26.0}),
    ("lamp post|lamp posts|street light", "post", lambda r: {"as_kind": "lamp",
                                                             "height": float(r.uniform(5.0, 7.0))}),
    ("bollard|mooring ring", "post", lambda r: {"as_kind": "bollard", "height": 0.85,
                                                "radius": 0.075}),
    ("railing|rail|fence", "railing", lambda r: {"length": float(r.uniform(4.0, 8.0)),
                                                 "height": float(r.uniform(0.7, 1.1))}),
    ("barrier arm|barrier|chevron", "barrier", lambda r: {"angle": float(r.uniform(-6, 6))}),
    ("brick wall|low brick wall|wall", "wall",
     lambda r: {"as_kind": "brick", "w": float(r.uniform(6.0, 12.0)),
                "h": float(r.uniform(0.9, 2.4))}),
    ("white-lined bays|bays|parking", "bays", lambda r: {"rows": 2, "cols": int(r.integers(4, 7))}),
    ("strings of small warm lights|lights wound|fairy lights|small warm lights", "string_lights",
     lambda r: {"count": int(r.integers(10, 20))}),
    ("crate|crates", "crate", lambda r: {"rot": float(r.uniform(-20, 20))}),
    ("cars|car|vehicles", "car",
     lambda r: {"rot": float(r.uniform(-10, 10)), "colour": [float(r.uniform(0.02, 0.28))] * 3}),
    ("cone|traffic cone", "cone", lambda r: {}),
    ("bench|slatted", "bench",
     lambda r: {"length": float(r.uniform(1.3, 2.0)), "rot": float(r.uniform(-25, 25))}),
    ("flask", "flask", lambda r: {"z": 0.47}),
    ("rope|cleat", "rope", lambda r: {"z": 0.0}),
    ("gravel path|gravel", "crumbs", lambda r: {"spread": 0.6, "count": 60}),
]

ROOM_VOCAB = [
    ("stacking chairs|chairs|chair", "chair", lambda r: {"rot": float(r.uniform(-30, 30))}),
    ("low table|table|desk", "table",
     lambda r: {"w": float(r.uniform(0.8, 1.4)), "d": float(r.uniform(0.5, 0.8)),
                "h": float(r.uniform(0.42, 0.75)), "rot": float(r.uniform(-14, 14))}),
    ("rack of|leaflets|rack", "shelf_rack", lambda r: {"rows": int(r.integers(3, 6))}),
    ("chest of drawers|drawer|drawers", "block",
     lambda r: {"w": 0.86, "d": 0.46, "h": 0.16, "tone": [0.26, 0.19, 0.12],
                "rot": float(r.uniform(-20, 20))}),
    ("window", "window_light", lambda r: {"w": float(r.uniform(0.9, 1.6)),
                                          "h": float(r.uniform(1.1, 1.7))}),
    ("wall|walls|boards", "wall",
     lambda r: {"as_kind": "painted", "w": 7.0, "h": float(r.uniform(2.4, 3.2))}),
    ("bag|canvas bag", "bag", lambda r: {"rot": float(r.uniform(0, 90))}),
    ("stack|pile|folders|binders|magazines", "stack",
     lambda r: {"count": int(r.integers(4, 10)), "rot": float(r.uniform(-14, 14))}),
    ("box|crate|carton", "crate", lambda r: {"rot": float(r.uniform(-25, 25))}),
    ("coat|jacket", "coat", lambda r: {"rot": float(r.uniform(-30, 30))}),
    ("bench|slatted", "bench", lambda r: {"length": float(r.uniform(1.2, 1.8))}),
    ("plate|bowl|mug", "plate", lambda r: {"r": 0.11}),
]


def things_in(text, vocab, rng, limit=7):
    """Everything the sentence names that the kit can build, in the order it names them."""
    found = []
    used = set()
    for pattern, builder, args in vocab:
        m = re.search(pattern, text)
        if not m or builder in used:
            continue
        used.add(builder)
        found.append((m.start(), builder, args(rng)))
    found.sort()
    return [(b, a) for _, b, a in found[:limit]]


# ------------------------------------------------------------------ laying the frame out
def lay_tabletop(items, rng):
    """The subject is what the sentence names first. Everything else goes round it, and one or
    two things are pushed out to the edge of the frame where a photograph usually cuts them."""
    out = []
    if not items:
        return out
    ring = 0.0
    for k, (builder, args) in enumerate(items):
        if k == 0:
            at = [float(rng.uniform(-0.02, 0.02)), float(rng.uniform(-0.02, 0.02))]
        else:
            a = 2 * np.pi * ((k - 1) / max(len(items) - 1, 1)) + float(rng.uniform(-0.5, 0.5))
            ring = float(rng.uniform(0.15, 0.30))
            if k >= 3 and rng.random() < 0.5:
                ring = float(rng.uniform(0.26, 0.36))       # cut by the edge of the frame
            at = [float(np.cos(a) * ring), float(np.sin(a) * ring * 0.8)]
        spec = {"kind": builder, "at": at}
        spec.update(args)
        out.append(spec)
    # anything cut on a board sits on the board
    board = next((s for s in out if s["kind"] == "board"), None)
    if board:
        lift = board.get("thick", 0.021)
        for s in out:
            if s["kind"] in ("loaf", "knife", "crumbs", "cloth"):
                s["on"] = lift
                s["at"] = [board["at"][0] + (s["at"][0] - board["at"][0]) * 0.35,
                           board["at"][1] + (s["at"][1] - board["at"][1]) * 0.35]
    return out


def lay_outdoor(items, rng):
    out = []
    # A tree is one thing. Placing the trunk, the limbs and the canopy independently put three
    # metres between a trunk and the branches that grow out of it, and what the picture showed
    # was a handful of black sticks hanging in an empty sky.
    tree_at = [float(rng.uniform(-3.0, 3.0)), float(rng.uniform(5.0, 11.0))]
    for k, (builder, args) in enumerate(items):
        if builder == "water":
            # the near edge of the water is a few metres off; the rest of it runs away
            at = [float(rng.uniform(-1.5, 1.5)), float(rng.uniform(30.0, 55.0))]
        elif builder == "bays":
            at = [float(rng.uniform(-1.5, 1.5)), float(rng.uniform(5.0, 9.0))]
        elif builder in ("trunk", "limbs", "canopy", "wood"):
            at = list(tree_at)
        elif builder == "undergrowth":
            at = [0.0, float(rng.uniform(6.0, 10.0))]
        elif builder in ("post",):
            at = [float(rng.uniform(-5.0, 5.0)), float(rng.uniform(7.0, 18.0))]
        elif builder in ("railing", "wall", "barrier"):
            at = [float(rng.uniform(-1.0, 1.0)), float(rng.uniform(3.0, 7.0))]
        else:
            at = [float(rng.uniform(-2.0, 2.0)), float(rng.uniform(2.5, 6.0))]
        spec = {"kind": builder, "at": at}
        spec.update(args)
        out.append(spec)
    return out


def lay_room(items, rng):
    out = []
    for k, (builder, args) in enumerate(items):
        if builder == "wall":
            at = [0.0, float(rng.uniform(3.5, 5.5))]
        elif builder == "window_light":
            at = [float(rng.uniform(-2.0, 2.0)), float(rng.uniform(3.4, 5.0)),
                  float(rng.uniform(1.2, 1.6))]
        elif builder == "shelf_rack":
            at = [float(rng.uniform(-1.6, 1.6)), float(rng.uniform(3.0, 4.6))]
        else:
            a = 2 * np.pi * (k / max(len(items), 1)) + float(rng.uniform(-0.6, 0.6))
            d = float(rng.uniform(1.2, 3.4))
            at = [float(np.cos(a) * d * 0.8), float(1.6 + np.sin(a) * d * 0.5)]
        spec = {"kind": builder, "at": at}
        spec.update(args)
        out.append(spec)
    return out


CAMERAS = {
    "tabletop": lambda r: {"look_at": [0, 0, float(r.uniform(0.01, 0.05))],
                           "height": float(r.uniform(0.26, 0.46)),
                           "distance": float(r.uniform(0.22, 0.38)),
                           "lean_deg": float(r.uniform(-16, 16)),
                           "mm": float(r.uniform(23, 28))},
    "room": lambda r: {"look_at": [float(r.uniform(-0.6, 0.6)), float(r.uniform(2.4, 3.6)),
                                   float(r.uniform(0.7, 1.2))],
                       "height": float(r.uniform(-0.15, 0.35)),
                       "distance": float(r.uniform(2.4, 4.0)),
                       "lean_deg": float(r.uniform(-14, 14)),
                       "mm": float(r.uniform(22, 26))},
    # Held at eye height and pointed at something on the ground four to nine metres off, which is
    # where a phone is when somebody stops on a towpath to take a picture.
    #
    # The first version aimed at a point up to two metres in the air ten metres away, from a
    # camera whose height was measured from that point rather than from the ground — so it looked
    # level into the sky, the horizon sat across the middle of the frame, and the near ground was
    # never in shot. Every outdoor picture came out as an empty plane meeting a flat sky.
    # phone_camera adds height to look_at, so the look_at stays near the ground and the height is
    # how far above it a person's eyes are.
    "outdoor": lambda r: {"look_at": [float(r.uniform(-1.2, 1.2)), float(r.uniform(4.0, 9.0)),
                                      float(r.uniform(0.0, 0.5))],
                          "height": float(r.uniform(0.95, 1.45)),
                          "distance": float(r.uniform(4.0, 9.0)),
                          "lean_deg": float(r.uniform(-12, 12)),
                          "mm": float(r.uniform(24, 30))},
}


def compose(entry):
    text = entry["scene"].lower()
    seed = int.from_bytes(entry["id"].encode()[:4].ljust(4, b"\0"), "big") % (2 ** 31)
    rng = np.random.default_rng(seed)
    # Which mode this is, decided by what the sentence actually gives the renderer to build
    # rather than by one keyword winning a race. A picture is in the mode whose vocabulary it
    # fills; the cue words only break the tie.
    candidates = {
        "tabletop": (things_in(text, _tabletop_vocab(), np.random.default_rng(seed)),
                     cue_score(text, TABLETOP)),
        "room": (things_in(text, ROOM_VOCAB, np.random.default_rng(seed), limit=6),
                 cue_score(text, ROOMISH)),
        "outdoor": (things_in(text, OUTDOOR_VOCAB, np.random.default_rng(seed), limit=6),
                    cue_score(text, OUTDOOR)),
    }
    mode = max(candidates, key=lambda m: (len(candidates[m][0]) * 2 + candidates[m][1] * 3,
                                          m == "tabletop"))
    light = light_of(text, mode)

    if mode == "tabletop":
        items = things_in(text, _tabletop_vocab(), rng)
        objects = lay_tabletop(items, rng)
        surface = pick(text, SURFACE_WORDS, "desk")
        recipe = {"mode": mode, "surface": surface, "surface_size": float(rng.uniform(1.0, 1.6)),
                  "room": True, "room_colour": [0.055, 0.048, 0.042]}
    elif mode == "outdoor":
        items = things_in(text, OUTDOOR_VOCAB, rng, limit=6)
        objects = lay_outdoor(items, rng)
        recipe = {"mode": mode, "ground": pick(text, GROUND_WORDS, "tarmac"),
                  "room": False, "sky": True}
        if said(text, "fog", "mist"):
            recipe["fog"] = float(rng.uniform(0.012, 0.035))
    else:
        items = things_in(text, ROOM_VOCAB, rng, limit=6)
        objects = lay_room(items, rng)
        recipe = {"mode": mode, "ground": pick(text, GROUND_WORDS, "carpet"),
                  "room": False, "interior": True}
        if not any(o["kind"] == "wall" for o in objects):
            objects.append({"kind": "wall", "at": [0.0, 4.6], "as_kind": "painted",
                            "w": 7.0, "h": 2.8})

    recipe.update({
        "id": entry["id"], "by": entry["by"], "light": light, "seed": seed % 10000,
        "size": [entry["w"], entry["h"]],
        "camera": CAMERAS[mode](rng),
        "handheld": float(rng.uniform(0.0, 0.7)),
        "quality": int(rng.integers(80, 92)),
        "objects": objects,
        "from_scene": entry["scene"],
    })
    if not recipe["objects"]:
        # nothing in the sentence matched anything the kit can build. Rather than render an
        # empty surface, put the thing the sentence is most likely to be about on it, and say
        # in the recipe that that is what happened.
        recipe["objects"] = [{"kind": "sheet", "at": [0.0, 0.0],
                              "w": 0.18, "h": 0.25, "rot": float(rng.uniform(-20, 20))}]
        recipe["improvised"] = True

    named = set(re.findall(r"[a-z]+", text))
    built = {o["kind"] for o in objects}
    recipe["not_built"] = sorted(w for w in
                                 ("fish", "tank", "castle", "gravel", "magazines", "carpet",
                                  "bollard", "reflection", "steam", "graphite", "newsprint",
                                  "papier", "mache", "button", "receipt", "clip", "tape")
                                 if w in named and w not in built)
    return recipe


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--print", action="store_true", dest="show")
    # The fourteen videos are written the same way the photographs are — an index of sentences,
    # one per clip — so they are composed by the same reader into the same recipe shape, and the
    # motion is added on top of a scene that was built exactly like a still.
    ap.add_argument("--index-dir", default=INDEX, help="where the index.<month>.json files are")
    ap.add_argument("--out", default=RECIPES, help="where to write the recipes")
    args = ap.parse_args()
    index_dir, recipes_dir = args.index_dir, args.out
    os.makedirs(recipes_dir, exist_ok=True)
    made = 0
    counts = {"tabletop": 0, "room": 0, "outdoor": 0}
    empty = []
    for f in sorted(glob.glob(os.path.join(index_dir, "index.*.json"))):
        with open(f, encoding="utf-8") as fh:
            for entry in json.load(fh):
                if args.only and entry["id"] != args.only:
                    continue
                if not args.only and not args.all:
                    continue
                recipe = compose(entry)
                counts[recipe["mode"]] += 1
                if not recipe["objects"]:
                    empty.append(entry["id"])
                with open(os.path.join(recipes_dir, entry["id"] + ".json"), "w",
                          encoding="utf-8") as out:
                    json.dump(recipe, out, indent=1)
                made += 1
                if args.show:
                    print(json.dumps(recipe, indent=1))
    print(f"compose: {made} recipes  " +
          "  ".join(f"{k} {v}" for k, v in counts.items()))
    if empty:
        print(f"  {len(empty)} with nothing in them: {', '.join(empty)}")


if __name__ == "__main__":
    main()
