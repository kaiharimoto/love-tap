# What the handwriting check failed on, as one sentence for the missing-artifact list: it has
# three different kinds of failure and the note used to name only one of them.
import json
d = json.load(open("evidence/logs/fonts.json"))
why = []
for f in d["fonts"]:
    for x in f["findings"]:
        why.append(f"{f['font']} {x['glyph']}: {x['why']}")
    for x in f["variants_apart"]["too_close"]:
        if x.get("identical"):
            why.append(f"{f['font']} {x['glyph']}: its variants are the same outline")
print(("; ".join(why))[:170] or "the handwriting check failed and said nothing")
