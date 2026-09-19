"""blender/rig/common.py — the one rig every render imports.

Run scripts headless:  blender -b -noaudio -P blender/<script>.py -- <args>

Everything in assets/ is rendered through here so that the light direction, the camera, the render
settings and the paper base material are identical across every file. Do not add lights anywhere
else. Do not change these numbers without updating DIRECTION.md.
"""
import math
import os
import sys
import numpy as np

import bpy

# ---- light direction (DIRECTION.md) -------------------------------------------------------
# Daylight from a window up and to the left of the desk. In image space the light comes from the
# top-left, so contact shadows fall down and to the right.
DAY_AZIMUTH_DEG = 315.0     # measured clockwise from +Y (top of the image) → light from upper-left
DAY_ELEVATION_DEG = 50.0
DAY_ANGLE_DEG = 5.0         # angular diameter → soft edges

# ---- the day illuminant, and why it is written as a temperature -----------------------------
#
# DIRECTION.md declares the key as "soft daylight from a window up and to the left ... warm
# (5200 K)". What used to sit here was DAY_COLOR = (1.0, 0.965, 0.905), annotated "~5200 K". It is
# a 6125 K sun. The annotation was nine hundred kelvin out, nothing checked it, and every asset in
# the build was rendered through it. So the temperature is now the constant and the colour is
# derived from it by Planck's law, and tools/check/illuminant.py fails if the two disagree or if
# either disagrees with DIRECTION.md.
#
# The world background is the larger error and it is not a mistyped number, it is a wrong model.
# Blender's world is a full unoccluded hemisphere. A sheet of paper on a desk beside a window does
# not see a full hemisphere of sky: it sees the window, which is a small solid angle, and then a
# whole room — walls, ceiling, the desk itself — every surface of it returning that same daylight
# with its own warm albedo on it. Lighting the background as open sky lights this desk as though it
# were outdoors on a lawn. Measured, sun and sky together came to R:G:B = 1.000:0.995:0.980, which
# is a neutral lamp, and an object rendered under a neutral lamp cannot be more chromatic than its
# own albedo. That is the whole of why a build made of warm paper measured at mean chroma 0.0181
# against a floor of 0.045: the build was not made of grey things, it was lit by a neutral lamp.
#
# So the background is the room's own bounce — DAY_COLOR reflected off a warm-white emulsion wall —
# and the net illuminant comes to R:G:B = 1.000:0.806:0.651, which is daylight in a room rather
# than daylight on a lawn.
DAY_TEMPERATURE_K = 5200.0          # DIRECTION.md, "Light"
ROOM_ALBEDO = (0.78, 0.75, 0.70)    # warm-white emulsion, the ordinary colour of a room


def _blackbody_srgb(kelvin, samples=471):
    """A blackbody at `kelvin` as linear sRGB, normalised so the largest channel is 1.

    Planck's law through the CIE 1931 2° observer (the Wyman/Sloan/Shirley multi-lobe fit, which
    is within 1% of the tabulated curves) and then the D65 sRGB matrix. Written out here rather
    than imported because blender's bundled python has no colour library and because a colour
    temperature that is computed is a colour temperature that cannot drift from its own comment.
    """
    w = np.linspace(360.0, 830.0, samples)

    def g(x, m, s1, s2):
        return np.exp(-0.5 * ((x - m) / np.where(x < m, s1, s2)) ** 2)

    xb = 1.056 * g(w, 599.8, 37.9, 31.0) + 0.362 * g(w, 442.0, 16.0, 26.7) - 0.065 * g(w, 501.1, 20.4, 26.2)
    yb = 0.821 * g(w, 568.8, 46.9, 40.5) + 0.286 * g(w, 530.9, 16.3, 31.1)
    zb = 1.217 * g(w, 437.0, 11.8, 36.0) + 0.681 * g(w, 459.0, 26.0, 13.8)
    lam = w * 1e-9
    h, c, kB = 6.62607015e-34, 2.99792458e8, 1.380649e-23
    rad = (2 * h * c ** 2) / lam ** 5 / np.expm1(h * c / (lam * kB * kelvin))
    # numpy renamed trapz to trapezoid at 2.0; blender 4.5 bundles 1.26 and the container's
    # python is 2.x, and this module is imported by both.
    integrate = getattr(np, "trapezoid", None) or np.trapz
    xyz = np.array([integrate(rad * cmf, w) for cmf in (xb, yb, zb)])
    m = np.array([[3.2404542, -1.5371385, -0.4985314],
                  [-0.9692660, 1.8760108, 0.0415560],
                  [0.0556434, -0.2040259, 1.0572252]])
    rgb = m @ xyz
    return tuple(float(v) for v in rgb / rgb.max())


def _luma(rgb):
    return 0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2]


DAY_COLOR = _blackbody_srgb(DAY_TEMPERATURE_K)
DAY_SKY = tuple(float(min(1.0, DAY_COLOR[i] * ROOM_ALBEDO[i] / max(ROOM_ALBEDO))) for i in range(3))

# The exposure is the invariant; only the colour of the light changed.
#
# This matters more than it looks. Legibility is the other half of what this build is scored on and
# it has been clawed back from 48.4% of runs below floor to 26.3%; a warmer lamp that also moved the
# exposure would put that at risk for no reason, and an exposure change moves chroma the WRONG way
# in any case, because OKLab chroma goes as the cube root of a uniform scaling. So the luminous
# irradiance each source lands on a horizontal sheet is held at exactly what the rig has always
# delivered, and the strengths are solved for rather than typed. A sheet's LIGHTNESS is unchanged by
# construction; its HUE is what moves.
DAY_SUN_IRRADIANCE_Y = math.sin(math.radians(DAY_ELEVATION_DEG)) * 2.6 * _luma((1.0, 0.965, 0.905))
DAY_SKY_IRRADIANCE_Y = math.pi * 0.55 * _luma((0.80, 0.83, 0.87))

DAY_STRENGTH = DAY_SUN_IRRADIANCE_Y / (math.sin(math.radians(DAY_ELEVATION_DEG)) * _luma(DAY_COLOR))
DAY_SKY_STRENGTH = DAY_SKY_IRRADIANCE_Y / (math.pi * _luma(DAY_SKY))

# Dusk: the sky drops and cools, a desk lamp on the right becomes the key.
DUSK_SUN_ELEVATION_DEG = 8.0
DUSK_SUN_STRENGTH = 0.35
DUSK_SUN_COLOR = (1.0, 0.72, 0.52)
DUSK_SKY = (0.36, 0.40, 0.50)
DUSK_SKY_STRENGTH = 0.28
LAMP_POSITION = (0.42, -0.10, 0.34)   # metres, right of the desk, low, in front
LAMP_COLOR = (1.0, 0.76, 0.52)        # ~2700 K
LAMP_POWER_W = 38.0
LAMP_SIZE = 0.09

DESK_COLOR = (0.30, 0.24, 0.19, 1.0)  # a worn wooden desk under everything

# ---- argv ------------------------------------------------------------------------------------
def argv():
    """Arguments after the first '--' (any further leading '--' tokens are dropped)."""
    if "--" not in sys.argv:
        return []
    rest = sys.argv[sys.argv.index("--") + 1:]
    while rest and rest[0] == "--":
        rest = rest[1:]
    return rest


def repo_root():
    here = os.path.dirname(os.path.abspath(__file__))
    return os.path.abspath(os.path.join(here, "..", ".."))


# ---- scene ----------------------------------------------------------------------------------
def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    return scene


def render_settings(scene, width, height, samples=128, transparent=False, seed=20260903, file_format="PNG", webp_quality=92):
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_adaptive_sampling = True
    scene.cycles.adaptive_threshold = 0.02
    scene.cycles.use_denoising = True
    scene.cycles.denoiser = "OPENIMAGEDENOISE"
    scene.cycles.seed = seed
    scene.cycles.max_bounces = 6
    scene.cycles.diffuse_bounces = 3
    scene.cycles.glossy_bounces = 3
    scene.cycles.transparent_max_bounces = 8
    scene.render.resolution_x = width
    scene.render.resolution_y = height
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = transparent
    scene.render.image_settings.file_format = file_format
    scene.render.image_settings.color_mode = "RGBA" if transparent else "RGB"
    if file_format == "PNG":
        scene.render.image_settings.color_depth = "8"
        scene.render.image_settings.compression = 50
    elif file_format == "WEBP":
        scene.render.image_settings.quality = webp_quality
    scene.render.dither_intensity = 1.0
    scene.view_settings.view_transform = "Standard"   # a scan, not a filmic photograph
    scene.view_settings.look = "None"
    scene.view_settings.exposure = 0.0
    scene.view_settings.gamma = 1.0
    scene.render.threads_mode = "AUTO"
    return scene


def _sun_direction(azimuth_deg, elevation_deg):
    az = math.radians(azimuth_deg)
    el = math.radians(elevation_deg)
    # direction the light travels *toward* the scene, from a point on the sky dome
    x = math.sin(az) * math.cos(el)
    y = math.cos(az) * math.cos(el)
    z = math.sin(el)
    return (x, y, z)


def _aim(obj, direction):
    """Point -Z of obj along direction (the way lights and cameras look)."""
    from mathutils import Vector
    d = Vector(direction)
    rot = d.to_track_quat("-Z", "Y")
    obj.rotation_euler = rot.to_euler()


def add_daylight(scene, elevation=None, azimuth=None):
    """The daylight condition. Returns (sun, world).

    The elevation can be lowered for a photograph taken early or late, but the azimuth stays
    where DIRECTION.md put it unless a caller has a reason: everything in this build agrees that
    the light comes from the upper left, and a photograph lit from the other side would sit in
    the thread arguing with the note beside it.
    """
    sun_data = bpy.data.lights.new("window_sun", "SUN")
    sun_data.energy = DAY_STRENGTH
    sun_data.color = DAY_COLOR
    sun_data.angle = math.radians(DAY_ANGLE_DEG)
    sun = bpy.data.objects.new("window_sun", sun_data)
    scene.collection.objects.link(sun)
    sun.location = (0, 0, 2.0)
    # the sun sits at (azimuth, elevation) and shines toward the origin
    src = _sun_direction(DAY_AZIMUTH_DEG if azimuth is None else azimuth,
                         DAY_ELEVATION_DEG if elevation is None else elevation)
    _aim(sun, (-src[0], -src[1], -src[2]))
    world = _world(scene, DAY_SKY, DAY_SKY_STRENGTH)
    return sun, world


# How far the camera stops down for the dusk condition.
#
# The desk lamp is thirty-eight watts half a metre from the sheet, which is about four times what
# the daylight sun puts on it. That is physically right and it came out as a dusk plate brighter
# than its own daylight twin, clipped at 254 with half the tooth. A person in front of a desk lamp
# stops down; so does this. The rig is untouched — this is the aperture, and it is here rather
# than in one generator because everything lit at dusk has to agree about it. It did not: the
# paper stopped down three stops and the desk did not, so the dusk desk was brighter than the
# daylight desk with the paper on it dimmer than both.
DUSK_STOPS = -3.0


def stop_down_for_dusk(scene):
    """Set the dusk aperture. Call after add_dusk, before rendering."""
    scene.view_settings.exposure = DUSK_STOPS


def add_dusk(scene):
    """The dusk condition: low warm sun, cool sky, a desk lamp on the right."""
    sun_data = bpy.data.lights.new("dusk_sun", "SUN")
    sun_data.energy = DUSK_SUN_STRENGTH
    sun_data.color = DUSK_SUN_COLOR
    sun_data.angle = math.radians(DAY_ANGLE_DEG * 1.6)
    sun = bpy.data.objects.new("dusk_sun", sun_data)
    scene.collection.objects.link(sun)
    sun.location = (0, 0, 2.0)
    src = _sun_direction(DAY_AZIMUTH_DEG, DUSK_SUN_ELEVATION_DEG)
    _aim(sun, (-src[0], -src[1], -src[2]))
    lamp_data = bpy.data.lights.new("desk_lamp", "AREA")
    lamp_data.energy = LAMP_POWER_W
    lamp_data.color = LAMP_COLOR
    lamp_data.shape = "DISK"
    lamp_data.size = LAMP_SIZE
    lamp = bpy.data.objects.new("desk_lamp", lamp_data)
    scene.collection.objects.link(lamp)
    lamp.location = LAMP_POSITION
    _aim(lamp, (-LAMP_POSITION[0], -LAMP_POSITION[1], -LAMP_POSITION[2]))
    world = _world(scene, DUSK_SKY, DUSK_SKY_STRENGTH)
    return sun, lamp, world


def _world(scene, color, strength):
    world = bpy.data.worlds.new("sky")
    world.use_nodes = True
    nodes = world.node_tree.nodes
    bg = nodes.get("Background")
    bg.inputs["Color"].default_value = (*color, 1.0)
    bg.inputs["Strength"].default_value = strength
    scene.world = world
    return world


def add_top_camera(scene, width_m, height_m, ortho=True, tilt_deg=0.0, distance=1.0):
    """A camera looking straight down at a width_m × height_m area centred on the origin."""
    cam_data = bpy.data.cameras.new("scan_cam")
    if ortho:
        cam_data.type = "ORTHO"
        cam_data.ortho_scale = max(width_m, height_m)
    else:
        cam_data.type = "PERSP"
        cam_data.lens = 50.0
        cam_data.sensor_width = 36.0
    cam_data.clip_start = 0.001
    cam_data.clip_end = 100.0
    cam = bpy.data.objects.new("scan_cam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = (0.0, 0.0, distance)
    cam.rotation_euler = (math.radians(tilt_deg), 0.0, 0.0)
    scene.camera = cam
    # an orthographic camera fills the frame to the *larger* axis; match the aspect
    scene.render.pixel_aspect_x = 1.0
    scene.render.pixel_aspect_y = 1.0
    return cam


def add_desk(scene, size_m=2.0, z=-0.0005):
    """The desk plane under everything (catches contact shadows)."""
    bpy.ops.mesh.primitive_plane_add(size=size_m, location=(0, 0, z))
    desk = bpy.context.active_object
    desk.name = "desk"
    mat = bpy.data.materials.new("desk")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = DESK_COLOR
    bsdf.inputs["Roughness"].default_value = 0.72
    desk.data.materials.append(mat)
    return desk


def add_shadow_catcher(scene, size_m=2.0):
    """An invisible plane that only receives shadows: for baking contact shadows with alpha."""
    bpy.ops.mesh.primitive_plane_add(size=size_m, location=(0, 0, -0.0002))
    catcher = bpy.context.active_object
    catcher.name = "shadow_catcher"
    catcher.is_shadow_catcher = True
    return catcher


def paper_material(name, base_rgb, tooth=1.0, yellowing=0.0, sheen=0.25, rules_image=None,
                   fibre_scale=900.0, roughness=0.78, subsurface=0.012,
                   rules_uv_scale=(1.0, 1.0), rules_uv_offset=(0.0, 0.0),
                   albedo_tooth=1.0):
    """The base paper material. Fibre relief is a bump from layered noise; the printed rules
    (an image texture generated in Python) are multiplied over the base colour; yellowing warms
    the base toward the edges. tooth scales the relief. Returns the material.

    `tooth` is a COMPOUND knob and firing 26 measured what that costs. It scales the albedo
    mottle amplitudes below AND the Bump node's Strength, which ships at 0.85 * tooth. Blender's
    bump strength is meaningful over 0..1; past about 1.2 it tilts the shading normal far enough
    off the surface that the sheet loses light faster than the mottle adds variance to it. Swept
    on lined_01 at res 3000, raising `tooth` alone took mean luminance 218.9 -> 193.9 -> 173.9 ->
    137.4 at scales 1.0/1.5/2.0/3.0 while L_std FELL 6.83 -> 6.14 -> 6.52 -> 5.70. Relative
    contrast did rise (3.12% -> 4.15%); the sheet just went dark faster. So `tooth` cannot be
    used to answer "make the paper toothier" -- it makes the paper dimmer.

    `albedo_tooth` is the half that can. It multiplies ONLY the four mottle amplitudes and leaves
    the relief exactly where it is, so the variance rises without the sheet losing luminance.

    `rules_uv_scale` and `rules_uv_offset` exist because the rules image is sampled by raw UV and
    every sheet's UV is 0..1 over its own size, so a rules image drawn for one sheet lands at the
    wrong pitch on a sheet of a different size. blender/paper/rules.py prints in millimetres -- 8 mm
    feint rules, a red margin at 32 mm -- and stretching that over a sheet half as tall halves the
    pitch and prints a lie. A caller whose sheet is a different size from the image's says so here:
    scale is the fraction of the image the sheet covers, offset is which part of it. The default is
    the identity, so every existing caller is unchanged.
    """
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nodes, links = nt.nodes, nt.links
    for n in list(nodes):
        nodes.remove(n)
    out = nodes.new("ShaderNodeOutputMaterial")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Sheen Weight"].default_value = sheen
    bsdf.inputs["Subsurface Weight"].default_value = subsurface
    bsdf.inputs["Subsurface Radius"].default_value = (0.002, 0.0018, 0.0012)
    bsdf.inputs["Specular IOR Level"].default_value = 0.28
    links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])

    texco = nodes.new("ShaderNodeTexCoord")
    # base colour with yellowing toward the edges
    base = nodes.new("ShaderNodeRGB")
    base.outputs[0].default_value = (*base_rgb, 1.0)
    warm = nodes.new("ShaderNodeRGB")
    warm.outputs[0].default_value = (base_rgb[0] * 0.98, base_rgb[1] * 0.93, base_rgb[2] * 0.80, 1.0)
    grad = nodes.new("ShaderNodeTexGradient")
    grad.gradient_type = "SPHERICAL"
    mapping = nodes.new("ShaderNodeMapping")
    mapping.inputs["Location"].default_value = (-0.5, -0.5, 0.0)
    mapping.inputs["Scale"].default_value = (0.9, 0.9, 1.0)
    links.new(texco.outputs["UV"], mapping.inputs["Vector"])
    links.new(mapping.outputs["Vector"], grad.inputs["Vector"])
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.35
    ramp.color_ramp.elements[1].position = 1.0
    mixy = nodes.new("ShaderNodeMix")
    mixy.data_type = "RGBA"
    mixy.inputs["Factor"].default_value = yellowing
    links.new(grad.outputs["Color"], ramp.inputs["Fac"])
    # invert: centre bright, edges warm
    inv = nodes.new("ShaderNodeInvert")
    links.new(ramp.outputs["Color"], inv.inputs["Color"])
    edge_mix = nodes.new("ShaderNodeMix")
    edge_mix.data_type = "RGBA"
    links.new(inv.outputs["Color"], edge_mix.inputs["Factor"])
    links.new(base.outputs[0], edge_mix.inputs[6])
    links.new(warm.outputs[0], edge_mix.inputs[7])
    links.new(base.outputs[0], mixy.inputs[6])
    links.new(edge_mix.outputs[2], mixy.inputs[7])
    colour_out = mixy.outputs[2]

    # The fibres, in the colour.
    #
    # Paper is a pressed mat of fibres of unequal brightness with filler between them, and at any
    # magnification where you can see a letterform you can also see that. Carrying the tooth only
    # as a bump does not survive: the relief that matters is a couple of hundredths of a
    # millimetre, which at render resolution is about one pixel, and Cycles antialiases it into a
    # flat field. Measured on the sheets this replaced, the blank areas held 0.44 grey levels of
    # high-frequency variation — less than the desk under them. So the fibres are put into the
    # albedo as well, where nothing can average them away and where downsampling to display size
    # preserves them, and the relief stays for the raking light to find.
    fibre_layers = []

    def _mottle(scale, detail, rough, amount, stretch_uv=None):
        n = nodes.new("ShaderNodeTexNoise")
        n.inputs["Scale"].default_value = scale
        n.inputs["Detail"].default_value = detail
        n.inputs["Roughness"].default_value = rough
        if stretch_uv is None:
            links.new(texco.outputs["UV"], n.inputs["Vector"])
        else:
            links.new(stretch_uv, n.inputs["Vector"])
        r = nodes.new("ShaderNodeValToRGB")
        r.color_ramp.elements[0].position = 0.30
        r.color_ramp.elements[0].color = (1.0 - amount, 1.0 - amount * 0.97, 1.0 - amount * 0.92, 1)
        r.color_ramp.elements[1].position = 0.70
        r.color_ramp.elements[1].color = (1.0 + amount, 1.0 + amount * 0.99, 1.0 + amount * 0.96, 1)
        links.new(n.outputs["Fac"], r.inputs["Fac"])
        fibre_layers.append(r.outputs["Color"])
        return n

    # the machine direction: the fibres lie along the way the sheet came off the wire
    machine = nodes.new("ShaderNodeMapping")
    machine.inputs["Scale"].default_value = (1.0, 9.0, 1.0)
    machine.inputs["Rotation"].default_value = (0.0, 0.0, 0.10)
    links.new(texco.outputs["UV"], machine.inputs["Vector"])

    # The scales are chosen against the size the sheet is actually drawn at, not against the size
    # it is rendered at. A sheet is about eleven hundred pixels across on the screen and 210 mm
    # across in the world, so a feature has to be bigger than about a fifth of a millimetre to
    # survive to a person's eye at all; the first pass put the speckle at a twelfth of that and it
    # averaged to nothing on the way down.
    _a = tooth * albedo_tooth
    _mottle(120.0, 6.0, 0.62, 0.030 * _a)                      # look-through, the cloudiness
    _mottle(360.0, 8.0, 0.70, 0.034 * _a)                       # individual fibres
    _mottle(220.0, 6.0, 0.55, 0.028 * _a, machine.outputs["Vector"])   # along the machine
    speck = nodes.new("ShaderNodeTexWhiteNoise")
    speck.noise_dimensions = "2D"
    speck_map = nodes.new("ShaderNodeMapping")
    speck_map.inputs["Scale"].default_value = (820.0, 820.0, 1.0)
    links.new(texco.outputs["UV"], speck_map.inputs["Vector"])
    links.new(speck_map.outputs["Vector"], speck.inputs["Vector"])
    speck_ramp = nodes.new("ShaderNodeValToRGB")
    speck_ramp.color_ramp.elements[0].position = 0.32
    speck_ramp.color_ramp.elements[0].color = (1.0 - 0.022 * _a, 1.0 - 0.022 * _a,
                                               1.0 - 0.021 * _a, 1)
    speck_ramp.color_ramp.elements[1].position = 0.68
    speck_ramp.color_ramp.elements[1].color = (1.0 + 0.022 * _a, 1.0 + 0.022 * _a,
                                               1.0 + 0.022 * _a, 1)
    links.new(speck.outputs["Value"], speck_ramp.inputs["Fac"])
    fibre_layers.append(speck_ramp.outputs["Color"])

    for layer in fibre_layers:
        m = nodes.new("ShaderNodeMix")
        m.data_type = "RGBA"
        m.blend_type = "MULTIPLY"
        m.inputs["Factor"].default_value = 1.0
        links.new(colour_out, m.inputs[6])
        links.new(layer, m.inputs[7])
        colour_out = m.outputs[2]

    if rules_image is not None:
        img = nodes.new("ShaderNodeTexImage")
        img.image = rules_image
        img.interpolation = "Cubic"
        if tuple(rules_uv_scale) != (1.0, 1.0) or tuple(rules_uv_offset) != (0.0, 0.0):
            place = nodes.new("ShaderNodeMapping")
            place.vector_type = "POINT"
            place.inputs["Scale"].default_value = (rules_uv_scale[0], rules_uv_scale[1], 1.0)
            place.inputs["Location"].default_value = (rules_uv_offset[0], rules_uv_offset[1], 0.0)
            links.new(texco.outputs["UV"], place.inputs["Vector"])
            links.new(place.outputs["Vector"], img.inputs["Vector"])
        else:
            links.new(texco.outputs["UV"], img.inputs["Vector"])
        ruled = nodes.new("ShaderNodeMix")
        ruled.data_type = "RGBA"
        ruled.blend_type = "MULTIPLY"
        ruled.inputs["Factor"].default_value = 1.0
        links.new(colour_out, ruled.inputs[6])
        links.new(img.outputs["Color"], ruled.inputs[7])
        colour_out = ruled.outputs[2]
    links.new(colour_out, bsdf.inputs["Base Color"])

    # fibre relief: fine noise + coarse mottle + very fine grain, as a bump
    fine = nodes.new("ShaderNodeTexNoise")
    # a third of what it was: features of about half a millimetre, which at render resolution is
    # four or five pixels rather than one, so the relief survives being antialiased
    fine.inputs["Scale"].default_value = fibre_scale / 3.0
    fine.inputs["Detail"].default_value = 8.0
    fine.inputs["Roughness"].default_value = 0.7
    links.new(texco.outputs["UV"], fine.inputs["Vector"])
    coarse = nodes.new("ShaderNodeTexNoise")
    coarse.inputs["Scale"].default_value = fibre_scale / 9.0
    coarse.inputs["Detail"].default_value = 4.0
    links.new(texco.outputs["UV"], coarse.inputs["Vector"])
    grain = nodes.new("ShaderNodeTexWhiteNoise")
    grain.noise_dimensions = "2D"
    links.new(texco.outputs["UV"], grain.inputs["Vector"])
    # long fibres: the same noise stretched along one direction (machine direction of the paper)
    stretch = nodes.new("ShaderNodeMapping")
    stretch.inputs["Scale"].default_value = (1.0, 7.0, 1.0)
    stretch.inputs["Rotation"].default_value = (0.0, 0.0, 0.12)
    links.new(texco.outputs["UV"], stretch.inputs["Vector"])
    fibres = nodes.new("ShaderNodeTexNoise")
    fibres.inputs["Scale"].default_value = fibre_scale * 0.45
    fibres.inputs["Detail"].default_value = 5.0
    fibres.inputs["Roughness"].default_value = 0.55
    links.new(stretch.outputs["Vector"], fibres.inputs["Vector"])
    m1 = nodes.new("ShaderNodeMath"); m1.operation = "MULTIPLY"; m1.inputs[1].default_value = 0.50
    m2 = nodes.new("ShaderNodeMath"); m2.operation = "MULTIPLY"; m2.inputs[1].default_value = 0.22
    m3 = nodes.new("ShaderNodeMath"); m3.operation = "MULTIPLY"; m3.inputs[1].default_value = 0.05
    m4 = nodes.new("ShaderNodeMath"); m4.operation = "MULTIPLY"; m4.inputs[1].default_value = 0.23
    links.new(fine.outputs["Fac"], m1.inputs[0])
    links.new(coarse.outputs["Fac"], m2.inputs[0])
    links.new(grain.outputs["Value"], m3.inputs[0])
    links.new(fibres.outputs["Fac"], m4.inputs[0])
    a1 = nodes.new("ShaderNodeMath"); a1.operation = "ADD"
    a2 = nodes.new("ShaderNodeMath"); a2.operation = "ADD"
    a3 = nodes.new("ShaderNodeMath"); a3.operation = "ADD"
    links.new(m1.outputs[0], a1.inputs[0]); links.new(m2.outputs[0], a1.inputs[1])
    links.new(a1.outputs[0], a2.inputs[0]); links.new(m3.outputs[0], a2.inputs[1])
    links.new(a2.outputs[0], a3.inputs[0]); links.new(m4.outputs[0], a3.inputs[1])
    a2 = a3
    bump = nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.85 * tooth
    bump.inputs["Distance"].default_value = 0.00030
    links.new(a2.outputs[0], bump.inputs["Height"])
    links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


def ink_material(name, rgb, gloss=0.35):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    bsdf.inputs["Roughness"].default_value = 1.0 - gloss
    bsdf.inputs["Specular IOR Level"].default_value = 0.4
    return mat


def render(scene, path):
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    scene.render.filepath = os.path.abspath(path)
    bpy.ops.render.render(write_still=True)
    return path


def load_image(path):
    return bpy.data.images.load(os.path.abspath(path), check_existing=True)


# ---- images (Blender's own API: the bundled Python has no Pillow) ----------------------------
def load_image_array(path):
    """An RGBA float array (h, w, 4) in top-down row order, read through Blender."""
    import numpy as np
    img = bpy.data.images.load(os.path.abspath(path), check_existing=False)
    w, h = img.size
    buf = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(buf)
    bpy.data.images.remove(img)
    return np.flipud(buf.reshape(h, w, 4))


def save_image_array(path, arr, colorspace="sRGB"):
    """Write an RGBA float array (h, w, 4), top-down, as PNG through Blender."""
    import numpy as np
    h, w = arr.shape[:2]
    img = bpy.data.images.new("out", width=w, height=h, alpha=True, float_buffer=False)
    img.colorspace_settings.name = colorspace
    img.pixels.foreach_set(np.flipud(arr).astype(np.float32).ravel())
    img.filepath_raw = os.path.abspath(path)
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)
    return path


def keep_shadow_only(path):
    """A shadow-catcher render carries the shadow in its alpha and the ground in its colour.
    Keep the alpha, drop the colour: the app multiplies this over whatever is beneath."""
    import numpy as np
    a = load_image_array(path)
    shadow = np.clip(a[..., 3] * (1.0 - a[..., 0]), 0.0, 1.0)
    out = np.zeros_like(a)
    out[..., 3] = shadow
    save_image_array(path, out, colorspace="Non-Color")
    return path



# ---------------------------------------------------------------- image maths without scipy
# Blender's bundled Python has numpy and nothing else, so the two image operations the paper
# scripts need are written out here rather than pulled in from scipy.

def blur(a, sigma):
    """A separable Gaussian blur. Same result as scipy's gaussian_filter to within rounding."""
    radius = max(1, int(round(sigma * 3)))
    x = np.arange(-radius, radius + 1, dtype=np.float32)
    k = np.exp(-(x ** 2) / (2.0 * sigma * sigma))
    k /= k.sum()
    out = a.astype(np.float32)
    for axis in (0, 1):
        pad = [(0, 0), (0, 0)]
        pad[axis] = (radius, radius)
        padded = np.pad(out, pad, mode="edge")
        moved = np.moveaxis(padded, axis, -1)
        stacked = np.stack([moved[..., i:i + out.shape[axis]] for i in range(len(k))], axis=-1)
        out = np.moveaxis((stacked * k).sum(axis=-1), -1, axis)
    return out


def distance_inside(solid, max_px):
    """Distance in pixels from each solid pixel to the nearest edge, capped at [max_px].

    An octagonal distance: 4- and 8-connected erosions alternate, which stays within about four
    per cent of the Euclidean distance and is what the fibre band ramp needs. It is capped because
    nothing beyond the band is used, which is also why an exact transform would be wasted here.
    """
    d = np.zeros(solid.shape, dtype=np.float32)
    cur = solid.copy()
    for step in range(1, int(max_px) + 1):
        e = cur.copy()
        e[1:, :] &= cur[:-1, :]
        e[:-1, :] &= cur[1:, :]
        e[:, 1:] &= cur[:, :-1]
        e[:, :-1] &= cur[:, 1:]
        if step % 2 == 0:  # every other pass takes the diagonals too
            e[1:, 1:] &= cur[:-1, :-1]
            e[1:, :-1] &= cur[:-1, 1:]
            e[:-1, 1:] &= cur[1:, :-1]
            e[:-1, :-1] &= cur[1:, 1:]
        d[e] = step
        cur = e
        if not cur.any():
            break
    d[solid & (d == 0)] = 0.0
    d[~solid] = 0.0
    return d
