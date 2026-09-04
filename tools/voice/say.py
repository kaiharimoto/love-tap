"""tools/voice/say.py — render the fifty-four voice notes the seeded year refers to.

    python3 tools/voice/say.py --all
    python3 tools/voice/say.py --only 2026-08_noor_kitchen_late --spectrogram

Each entry in seed/voice/index.<month>.json says who is talking, how long the note runs, and
exactly what is around them. This reads that sentence, builds the place out of tools/voice/sound.py,
puts the person into it out of tools/voice/talk.py, and writes seed/voice/<id>.ogg at the stated
duration. It then measures the file it just made and writes the waveform back into the index, so
the shape drawn in the thread is the shape of the audio rather than a decoration.

Nothing is sampled and nothing is downloaded. What the two of them say is written down in
seed/year/*.jsonl; the audio is the sound of them saying it.
"""
import argparse
import json
import os
import re
import subprocess
import sys
import tempfile

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)

import sound as S      # noqa: E402
import talk            # noqa: E402

VOICE_DIR = os.path.join(ROOT, "seed", "voice")
FFMPEG = os.path.join(ROOT, "toolchain", "ffmpeg", "ffmpeg")
MANIFEST = os.path.join(ROOT, "seed", "MANIFEST.json")


# ------------------------------------------------------------------ reading the setting
def has(text, *words):
    """True when the sentence says the thing is there. "no traffic at all" says it is not, and
    the first version of this heard the word traffic and put a road under Christmas morning."""
    for w in words:
        for m in re.finditer(r"\b" + w + r"\b", text):
            before = text[max(0, m.start() - 22):m.start()]
            after = text[m.end():m.end() + 18]
            if re.search(r"\b(no|not|without|never)\s+$", before):
                continue
            if re.search(r"^\s+not at all\b", after):
                continue
            return True
    return False


def seconds_named(text):
    """"eleven seconds", "twelve seconds", "four seconds" — the note says how long it stops."""
    words = {"two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8,
             "nine": 9, "ten": 10, "eleven": 11, "twelve": 12, "fifteen": 15, "twenty": 20,
             "thirty": 30, "forty": 40}
    out = []
    for m in re.finditer(r"\b([a-z]+|\d+)\s+seconds\b", text):
        w = m.group(1)
        out.append(int(w) if w.isdigit() else words.get(w, 0))
    return [s for s in out if s]


def count_word(text, word):
    m = re.search(word + r"\b[^,;.]*?\b(once|twice|three times|four times|five times|eight times)", text)
    if not m:
        return 0
    return {"once": 1, "twice": 2, "three times": 3, "four times": 4,
            "five times": 5, "eight times": 8}[m.group(1)]


PLACES = [
    # (test, room, surface, beds)
    ("hill|walk|walking|road|verge|climb|descent|street", "outdoor", "grit", ["air"]),
    ("kitchen", "kitchen", "lino", ["room"]),
    ("classroom|art room|artroom|stripped|empty room|bare boards", "artroom", "boards", ["room"]),
    ("corridor", "corridor", "lino", ["room"]),
    ("train", "small", None, ["rails"]),
    ("bus", "small", None, ["bus"]),
    ("back step|yard|garden", "outdoor", None, ["air"]),
    ("marquee|field", "outdoor", None, ["air"]),
]


def plan_for(entry):
    """Turn the sentence the index holds into a list of layers and a list of arrivals."""
    text = entry["setting"].lower()
    dur = entry["duration_ms"] / 1000.0
    p = {"dur": dur, "room": None, "surface": "grit", "walking": False, "beds": [], "events": [],
         "tone": "level", "rate": 1.0, "ending": "fall", "handling": 0.0, "tunnel": [],
         "silences": [], "false_starts": 0, "abandoned": 0, "laugh": 0, "yawn": 0, "hum": 0,
         "breath_between": 0.5}

    for pattern, room, surface, beds in PLACES:
        if re.search(pattern, text):
            p["room"] = room
            if surface:
                p["surface"] = surface
            # a copy: PLACES holds one list per place, shared by every note that matches it, and
            # appending to it put a marquee band and a train under a school corridor
            p["beds"] = list(beds)
            break

    walking = has(text, "walking", "walk", "footsteps", "steps", "boots", "climb", "descent")
    p["walking"] = walking and not has(text, "standing still", "stops talking", "seat")
    if has(text, "standing still"):
        p["walking"] = False
    if has(text, "grit"):
        p["surface"] = "grit"
    if has(text, "slush", "snow"):
        p["surface"] = "slush"
    if has(text, "wet", "rain", "standing water"):
        p["surface"] = "wet"
    if has(text, "boards", "echoing"):
        p["surface"] = "boards"
    if has(text, "gravel"):
        p["surface"] = "grit"

    # what is continuously there
    if has(text, "traffic"):
        p["beds"].append("traffic_building" if has(text, "building") else "traffic")
    if has(text, "wind"):
        p["beds"].append("wind")
    if has(text, "rain"):
        p["beds"].append("rain_hood" if has(text, "hood") else "rain")
    if has(text, "extractor"):
        p["beds"].append("extractor")
    if has(text, "fridge"):
        p["beds"].append("fridge")
    if has(text, "radiator"):
        p["beds"].append("radiator")
    if has(text, "desk fan"):
        p["beds"].append("deskfan")
    if has(text, "simmer"):
        p["beds"].append("simmer")
    if has(text, "birds", "hedge full of birds", "birds loud"):
        p["beds"].append("birds")
    if has(text, "gulls", "swifts"):
        p["beds"].append("gulls")
    if has(text, "band"):
        p["beds"].append("band")
    if has(text, "engine drone", "engine"):
        p["beds"].append("bus")
    if has(text, "rails"):
        p["beds"].append("rails")
    if has(text, "radio"):
        p["beds"].append("radio")
    if p["room"] is None:
        # nothing in PLACES matched, so decide it from what else the sentence heard: gulls and
        # traffic are not indoors, and no note is recorded in a vacuum
        p["room"] = "outdoor" if any(b in p["beds"] for b in
                                     ("gulls", "birds", "traffic", "traffic_building",
                                      "wind", "rain", "rain_hood")) else "kitchen"
    if p["room"] == "outdoor" and "air" not in p["beds"]:
        p["beds"].insert(0, "air")
    if p["room"] in ("kitchen", "artroom", "corridor", "small") and "room" not in p["beds"]:
        p["beds"].append("room")
    p["handling"] = 0.8 if p["walking"] else 0.15

    # how they sound
    if has(text, "flat", "flattened", "level", "thinned"):
        p["tone"] = "flat"
    if has(text, "hoarse"):
        p["tone"] = "hoarse"
    if has(text, "low", "lower", "quietly", "half swallowed", "half in his collar", "under the carriage"):
        p["tone"] = "low"
    if has(text, "bright", "pleased"):
        p["tone"] = "bright"
    if has(text, "quick", "faster", "speeding up", "too fast"):
        p["tone"] = "quick"
        p["rate"] = 1.18
    if has(text, "slower", "slow", "unhurried", "tired", "easy"):
        p["rate"] = 0.86
    if has(text, "vowels going long"):
        p["rate"] = 0.78
    if has(text, "up at the end of every sentence", "as if still checking"):
        p["ending"] = "rise"
    if has(text, "trailing off", "trails", "never finished", "left unfinished", "cut off",
           "abandoned", "given up", "left alone", "left where it was", "no ending"):
        p["ending"] = "trail"

    # structure
    p["silences"] = seconds_named(text)
    for word, n in (("two long pauses", 2), ("three long pauses", 3), ("two long silences", 2),
                    ("a long pause", 1), ("a long silence", 1), ("a long stretch", 1),
                    ("a long unfilled gap", 1), ("long gaps", 2), ("a long stop", 1),
                    ("a stop halfway", 1)):
        if word in text:
            p["silences"] += [8] * n
    if not p["silences"] and has(text, "pause", "silence", "stop"):
        p["silences"] = [6]
    p["false_starts"] = (2 if "two false starts" in text else
                         3 if "three times" in text and has(text, "starting", "started") else
                         2 if "begun twice" in text or "started twice" in text else
                         3 if "started three times" in text else 0)
    p["abandoned"] = 1 if p["ending"] == "trail" else 0
    p["laugh"] = count_word(text, "laugh") or (1 if has(text, "laugh", "laughs", "laughing") else 0)
    p["yawn"] = 1 if has(text, "yawn") else 0
    p["hum"] = 1 if has(text, "hummed", "hums") else 0
    if has(text, "only breathes", "breathing", "breath"):
        p["breath_between"] = 0.95
    if has(text, "saying almost nothing", "mostly holding the phone"):
        p["breath_between"] = 0.3

    # arrivals: things that happen once, at a time the sentence implies
    def when(hint, default):
        if hint == "halfway":
            return dur * 0.5
        if hint == "end":
            return dur * 0.88
        if hint == "start":
            return dur * 0.08
        return default

    ev = p["events"]
    if has(text, "bus"):
        if has(text, "pulling away", "pulling out", "going up", "pulls"):
            ev.append(("bus", when("halfway", dur * 0.52), 4.5))
        if has(text, "door"):
            ev.append(("bus_door", dur * 0.62, 1.4))
        if has(text, "bell"):
            ev.append(("bell_ping", dur * 0.35, 1.0))
            ev.append(("bell_ping", dur * 0.72, 1.0))
    if has(text, "gritting lorry", "bin lorry", "delivery lorry", "lorry"):
        if has(text, "reversing"):
            ev.append(("reversing", dur * 0.45, min(6.0, dur * 0.25)))
        else:
            ev.append(("lorry", dur * 0.5, 5.5))
    if has(text, "car"):
        if has(text, "door"):
            ev.append(("car_door", dur * 0.72, 0.9))
        if has(text, "passing", "passes"):
            ev.append(("car", dur * 0.66, 3.5))
    if has(text, "gate"):
        ev.append(("gate", dur * (0.9 if has(text, "at the end", "ending with") else 0.62), 1.1))
    if has(text, "door bang", "banging", "bangs", "door shutting", "stairwell door", "the door"):
        ev.append(("door", dur * 0.80, 0.8))
    if has(text, "keys", "key"):
        ev.append(("keys", dur * 0.93, 0.9))
    if has(text, "church bell"):
        ev.append(("church", dur * 0.40, 4.5))
    if has(text, "chair", "chairs"):
        if has(text, "onto tables", "on the tables", "going up onto tables", "one at a time"):
            p["beds"].append("stacking")
        else:
            ev.append(("chair", dur * 0.5, 0.6))
    if has(text, "tap"):
        if has(text, "dripping"):
            ev.append(("drip", dur * 0.30, 0.3))
            ev.append(("drip", dur * 0.42, 0.3))
        else:
            ev.append(("tap", dur * 0.35, 2.2))
            ev.append(("tap", dur * 0.70, 1.4))
    if has(text, "knife"):
        for k in range(4):
            ev.append(("knife", dur * 0.45 + k * 0.55, 0.35))
    if has(text, "spoon"):
        ev.append(("spoon", dur * 0.6, 0.7))
    if has(text, "lid"):
        ev.append(("lid_rattle" if has(text, "rattling") else "lid", dur * 0.55, 0.9))
    if has(text, "plates"):
        for k in range(3):
            ev.append(("plate", dur * 0.5 + k * 0.8, 0.7))
    if has(text, "mug"):
        ev.append(("mug", dur * 0.86, 0.7))
    if has(text, "folder", "folders", "papers", "paper", "roster", "bag"):
        ev.append(("paper", dur * 0.33, 1.6))
        ev.append(("paper", dur * 0.64, 1.1))
    if has(text, "trolley"):
        ev.append(("trolley", dur * 0.45, 6.0))
    if has(text, "window catch"):
        ev.append(("window", dur * 0.55, 0.6))
    if has(text, "bin lid"):
        ev.append(("bin", dur * 0.70, 1.0))
    if has(text, "tunnel"):
        p["tunnel"] = [(dur - 12.0, dur)]
    if has(text, "cutting"):
        p["tunnel"] = [(dur - 5.0, dur)]
    if has(text, "crossing"):
        p["silences"].append(3)
    return p


# ------------------------------------------------------------------ speech schedule
def schedule(p, rng):
    """Lay the talking out over the whole note: phrases, the gaps, and where it stops dead."""
    dur = p["dur"]
    out = []
    t = rng.uniform(0.4, 1.4)
    silences = sorted(p["silences"], reverse=True)
    # where the long stops land: spread through the middle rather than at the ends
    stops = []
    for k, s in enumerate(silences[:4]):
        frac = 0.30 + 0.5 * (k / max(len(silences[:4]) - 1, 1)) if len(silences[:4]) > 1 else 0.45
        stops.append((dur * frac, float(s)))
    stops.sort()
    false_left = p["false_starts"]
    while t < dur - 0.6:
        for (st, sl) in list(stops):
            if t >= st:
                t += sl
                stops.remove((st, sl))
                if t >= dur - 0.6:
                    break
        if t >= dur - 0.6:
            break
        if false_left:
            d = min(rng.uniform(0.7, 1.5), dur - t - 0.3)
            out.append(("phrase", t, d, "trail"))
            t += d + rng.uniform(0.5, 1.1)
            false_left -= 1
            continue
        remaining = dur - t
        d = min(rng.uniform(2.2, 5.5), remaining - 0.2)
        if d < 0.6:
            break
        last = t + d > dur - 4.0
        ending = p["ending"] if last else ("rise" if p["ending"] == "rise" else
                                           str(rng.choice(["fall", "level", "fall"])))
        out.append(("phrase", t, d, ending))
        t += d
        gap = rng.uniform(0.35, 1.3) * (1.6 if p["breath_between"] > 0.8 else 1.0)
        if rng.random() < p["breath_between"]:
            out.append(("breath", t + 0.05, min(rng.uniform(0.35, 0.75), gap), ""))
        t += gap
    return out


# ------------------------------------------------------------------ rendering
def render(entry, rng):
    p = plan_for(entry)
    dur = p["dur"]
    n = S.secs(dur)
    voice = talk.Voice(entry["by"])

    bed = np.zeros(n)
    for name in p["beds"]:
        if name == "air":
            bed += S.air(dur, rng, bright=0.5)
        elif name == "room":
            bed += S.room_tone(dur, rng)
        elif name == "traffic":
            bed += S.traffic(dur, rng, distance=1.4)
        elif name == "traffic_building":
            bed += S.traffic(dur, rng, distance=1.6, building=1.1)
        elif name == "wind":
            bed += S.wind_on_mic(dur, rng, strength=1.0)
        elif name == "rain":
            bed += S.rain(dur, rng)
        elif name == "rain_hood":
            bed += S.rain(dur, rng, on_hood=True)
        elif name == "extractor":
            bed += S.fan(dur, rng, level=0.045, blade=112.0)
        elif name == "fridge":
            cycles = [(dur * 0.42, dur)] if dur > 40 else None
            bed += S.hum(dur, rng, base=50.0, level=0.030, cycling=cycles)
        elif name == "radiator":
            bed += S.radiator_tick(dur, rng)
        elif name == "deskfan":
            bed += S.fan(dur, rng, level=0.035, blade=74.0)
        elif name == "simmer":
            bed += S.bubbling(dur, rng)
        elif name == "birds":
            bed += S.birds(dur, rng, density=2.2)
        elif name == "gulls":
            bed += S.birds(dur, rng, density=0.5, gulls=True)
        elif name == "band":
            bed += S.band_through_canvas(dur, rng)
        elif name == "bus":
            bed += S.engine_drone(dur, rng, level=0.055)
        elif name == "rails":
            bed += S.rails(dur, rng)
        elif name == "radio":
            bed += S.band_through_canvas(dur, rng, level=0.012)
        elif name == "stacking":
            bed += S.stack_chairs(dur, rng)

    gaps = []
    if p["walking"]:
        for (t0, s) in [(x[1], x[2]) for x in [] ]:
            pass
        pace = 0.62 if p["rate"] < 0.9 else 0.55
        unsteady = 0.10 if "uneven" in entry["setting"].lower() or "slightly uneven" in entry["setting"].lower() else 0.02
        bed += S.walking(dur, rng, surface=p["surface"], pace=pace, unsteady=unsteady,
                         level=0.55, gaps=gaps)

    ONE_SHOT = {
        "bus": lambda d: S.vehicle_pass(d, rng, "bus", close=0.8),
        "lorry": lambda d: S.vehicle_pass(d, rng, "lorry", close=0.7),
        "car": lambda d: S.vehicle_pass(d, rng, "car", close=0.7),
        "reversing": lambda d: S.reversing_beep(d, rng),
        "bus_door": lambda d: S.bus_door(rng),
        "bell_ping": lambda d: S.bell_ping(rng),
        "car_door": lambda d: S.car_door(rng),
        "gate": lambda d: S.gate_latch(rng, "shut"),
        "door": lambda d: S.door_bang(rng),
        "keys": lambda d: S.keys(rng),
        "church": lambda d: S.church_bell(rng),
        "chair": lambda d: S.chair_scrape(rng),
        "tap": lambda d: S.tap_water(d, rng),
        "drip": lambda d: S.drip(rng),
        "knife": lambda d: S.knife_on_board(rng),
        "spoon": lambda d: S.set_down(rng, "spoon", "steel"),
        "lid": lambda d: S.set_down(rng, "lid", "stone"),
        "lid_rattle": lambda d: S.lid_rattle(rng),
        "plate": lambda d: S.set_down(rng, "plate", "steel"),
        "mug": lambda d: S.set_down(rng, "mug", "stone"),
        "paper": lambda d: S.paper_rustle(d, rng),
        "trolley": lambda d: S.trolley(d, rng),
        "window": lambda d: S.window_catch(rng),
        "bin": lambda d: S.bin_lid(rng),
    }
    for (kind, t, d) in p["events"]:
        fn = ONE_SHOT.get(kind)
        if fn is None or t >= dur:
            continue
        S.at(bed, fn(d), max(0.0, min(t, dur - 0.2)))

    # the person
    speech = np.zeros(n)
    for (what, t, d, ending) in schedule(p, rng):
        if what == "phrase":
            piece = voice.phrase(d, rng, tone=p["tone"], rate=p["rate"], ending=ending or "fall")
        else:
            piece = voice.breath(d, rng, voiced=0.25 if p["breath_between"] > 0.8 else 0.0)
        S.at(speech, piece, t)
    if p["laugh"]:
        for k in range(p["laugh"]):
            S.at(speech, voice.laugh(rng), dur * (0.55 + 0.12 * k) % max(dur - 2, 1))
    if p["yawn"]:
        S.at(speech, voice.yawn(rng, 2.8), dur * 0.78)
    if p["hum"]:
        S.at(speech, voice.hum_notes(rng), dur * 0.46)

    # the phone is held near the mouth, so the voice arrives close and the room arrives late
    if p["room"] and p["room"] != "outdoor":
        speech = S.echo_room(speech, rng, p["room"])[:n]
        if p["room"] in ("artroom", "corridor"):
            bed = S.echo_room(bed, rng, p["room"])[:n]
    speech = S.lowpass(speech, 7000)
    speech = speech / (np.max(np.abs(speech)) + 1e-9) * 0.68

    # A phone is held at the mouth. Whatever is going on in the room reaches the microphone a
    # long way down from that, and how far down is the difference between a hill in the wind and
    # a kitchen at three in the morning. Setting it here rather than letting it fall out of the
    # sum of whatever layers the sentence happened to name is what makes the quiet stretches in
    # these notes actually quiet, which is most of what they are for.
    UNDER = {"outdoor": 0.16, "kitchen": 0.085, "artroom": 0.065, "corridor": 0.10,
             "small": 0.26, None: 0.09}
    ratio = UNDER.get(p["room"], 0.09)
    if "wind" in p["beds"] or "rain_hood" in p["beds"]:
        ratio *= 1.5
    if p["walking"]:
        ratio *= 1.15
    loud = np.abs(speech) > np.percentile(np.abs(speech), 90)
    speech_rms = float(np.sqrt(np.mean(speech[loud] ** 2))) if loud.any() else 0.15
    bed_rms = float(np.sqrt(np.mean(bed ** 2))) + 1e-9
    bed = bed * (speech_rms * ratio / bed_rms)

    mix = speech + bed
    mix = S.phone_mic(mix, rng, tunnel=p["tunnel"], handling=p["handling"])
    return mix[:n], p


# ------------------------------------------------------------------ files
def write_ogg(path, x, bitrate="28k"):
    pcm = np.clip(x, -1.0, 1.0)
    pcm = (pcm * 32767).astype("<i2").tobytes()
    with tempfile.NamedTemporaryFile(suffix=".raw", delete=False) as f:
        f.write(pcm)
        raw = f.name
    try:
        subprocess.run([FFMPEG, "-y", "-loglevel", "error", "-f", "s16le", "-ar", str(S.SR),
                        "-ac", "1", "-i", raw, "-c:a", "libopus", "-b:a", bitrate,
                        "-application", "voip", path], check=True)
    finally:
        os.unlink(raw)


def waveform_of(x, buckets=64):
    """What the thread draws: the loudest thing in each slice, which is what a person reads as
    the shape of a recording."""
    n = len(x)
    edges = np.linspace(0, n, buckets + 1).astype(int)
    peaks = np.array([np.sqrt(np.mean(x[a:b] ** 2)) if b > a else 0.0
                      for a, b in zip(edges[:-1], edges[1:])])
    top = np.percentile(peaks, 96) + 1e-9
    return [round(float(min(v / top, 1.0)) ** 0.72, 3) for v in peaks]


def record_manifest(rel, settings):
    data = {"version": 1, "files": {}}
    if os.path.exists(MANIFEST):
        with open(MANIFEST, encoding="utf-8") as f:
            data = json.load(f)
    data["files"][rel] = settings
    with open(MANIFEST, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=1, sort_keys=True)


def spectrogram(x, path, win=1024, hop=256):
    """A picture of the thing, because a voice cannot be judged by looking at a waveform."""
    from PIL import Image
    n = (len(x) - win) // hop
    n = min(n, 1600)
    w = np.hanning(win)
    cols = []
    for i in range(n):
        seg = x[i * hop:i * hop + win] * w
        sp = np.abs(np.fft.rfft(seg))[:320]
        cols.append(20 * np.log10(sp + 1e-6))
    m = np.array(cols).T[::-1]
    m = np.clip((m - m.max() + 62) / 62, 0, 1)
    img = Image.fromarray((m * 255).astype("uint8"), "L").resize((min(n, 1400), 480))
    img.save(path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--month", default="")
    ap.add_argument("--spectrogram", default="")
    ap.add_argument("--skip-existing", action="store_true")
    args = ap.parse_args()

    files = sorted(f for f in os.listdir(VOICE_DIR) if f.startswith("index.") and f.endswith(".json"))
    if args.month:
        files = [f for f in files if args.month in f]
    made = 0
    for fname in files:
        path = os.path.join(VOICE_DIR, fname)
        with open(path, encoding="utf-8") as f:
            entries = json.load(f)
        changed = False
        for entry in entries:
            if args.only and entry["id"] != args.only:
                continue
            if not args.only and not args.all:
                continue
            out = os.path.join(VOICE_DIR, entry["id"] + ".ogg")
            if args.skip_existing and os.path.exists(out):
                continue
            seed = abs(hash(entry["id"])) % (2 ** 31)
            seed = int.from_bytes(entry["id"].encode()[:4].ljust(4, b"\0"), "big")
            rng = np.random.default_rng(seed)
            x, p = render(entry, rng)
            write_ogg(out, x)
            entry["waveform"] = waveform_of(x)
            entry["made"] = "tools/voice/say.py"
            changed = True
            made += 1
            record_manifest(f"seed/voice/{entry['id']}.ogg", {
                "generator": "tools/voice/say.py",
                "from": "the setting written in " + fname,
                "voice": entry["by"], "seconds": entry["duration_ms"] / 1000.0,
                "layers": p["beds"] + (["footsteps on " + p["surface"]] if p["walking"] else []),
                "arrivals": [e[0] for e in p["events"]],
                "tone": p["tone"], "stops_for": p["silences"],
                "synthesis": "glottal source and a moving four-formant tract; not a recording, "
                             "and not intelligible as words",
                "bytes": os.path.getsize(out),
            })
            if args.spectrogram:
                spectrogram(x, args.spectrogram)
            print(f"voice: {entry['id']}  {entry['duration_ms']/1000:.0f}s  "
                  f"{os.path.getsize(out)//1024}kB  {'+'.join(p['beds'])}", flush=True)
        if changed:
            with open(path, "w", encoding="utf-8") as f:
                json.dump(entries, f, indent=1, ensure_ascii=False)
                f.write("\n")
    if not made:
        print("say.py: pass --only <id> or --all")


if __name__ == "__main__":
    main()
