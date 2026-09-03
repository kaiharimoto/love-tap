"""blender/rig/dusk.py — helper to pick a light condition by name.

    from rig import common, dusk
    dusk.light(scene, "day")   # or "dusk"
"""
from . import common


def light(scene, condition):
    if condition == "day":
        return common.add_daylight(scene)
    if condition == "dusk":
        return common.add_dusk(scene)
    raise ValueError(f"unknown light condition {condition!r}; use 'day' or 'dusk'")
