"""blender/rig/common.py — the one rig every render imports.

Run scripts headless:  blender -b -noaudio -P blender/<script>.py -- <args>

Everything in assets/ is rendered through here so that the light direction, the camera, the render
settings and the paper base material are identical across every file. Do not add lights anywhere
else. Do not change these numbers without updating DIRECTION.md.
"""
import math
import os
import sys

import bpy

# ---- light direction (DIRECTION.md) -------------------------------------------------------
# Daylight from a window up and to the left of the desk. In image space the light comes from the
# top-left, so contact shadows fall down and to the right.
DAY_AZIMUTH_DEG = 315.0     # measured clockwise from +Y (top of the image) → light from upper-left
DAY_ELEVATION_DEG = 50.0
DAY_ANGLE_DEG = 5.0         # angular diameter → soft edges
DAY_STRENGTH = 2.6
DAY_COLOR = (1.0, 0.965, 0.905)     # ~5200 K
DAY_SKY = (0.80, 0.83, 0.87)        # cool sky fill
DAY_SKY_STRENGTH = 0.55

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


def render_settings(scene, width, height, samples=128, transparent=False, seed=20260903):
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
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA" if transparent else "RGB"
    scene.render.image_settings.color_depth = "8"
    scene.render.image_settings.compression = 50
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


def add_daylight(scene):
    """The daylight condition. Returns (sun, world)."""
    sun_data = bpy.data.lights.new("window_sun", "SUN")
    sun_data.energy = DAY_STRENGTH
    sun_data.color = DAY_COLOR
    sun_data.angle = math.radians(DAY_ANGLE_DEG)
    sun = bpy.data.objects.new("window_sun", sun_data)
    scene.collection.objects.link(sun)
    sun.location = (0, 0, 2.0)
    # the sun sits at (azimuth, elevation) and shines toward the origin
    src = _sun_direction(DAY_AZIMUTH_DEG, DAY_ELEVATION_DEG)
    _aim(sun, (-src[0], -src[1], -src[2]))
    world = _world(scene, DAY_SKY, DAY_SKY_STRENGTH)
    return sun, world


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


def add_desk(scene, size_m=2.0):
    """The desk plane under everything (catches contact shadows)."""
    bpy.ops.mesh.primitive_plane_add(size=size_m, location=(0, 0, -0.0005))
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
                   fibre_scale=900.0, roughness=0.78, subsurface=0.012):
    """The base paper material. Fibre relief is a bump from layered noise; the printed rules
    (an image texture generated in Python) are multiplied over the base colour; yellowing warms
    the base toward the edges. tooth scales the relief. Returns the material."""
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

    # fibre mottle in the colour (very subtle)
    mottle = nodes.new("ShaderNodeTexNoise")
    mottle.inputs["Scale"].default_value = 160.0
    mottle.inputs["Detail"].default_value = 6.0
    mottle.inputs["Roughness"].default_value = 0.62
    links.new(texco.outputs["UV"], mottle.inputs["Vector"])
    mottle_ramp = nodes.new("ShaderNodeValToRGB")
    mottle_ramp.color_ramp.elements[0].position = 0.42
    mottle_ramp.color_ramp.elements[0].color = (0.955, 0.95, 0.94, 1)
    mottle_ramp.color_ramp.elements[1].position = 0.60
    mottle_ramp.color_ramp.elements[1].color = (1.0, 1.0, 1.0, 1)
    links.new(mottle.outputs["Fac"], mottle_ramp.inputs["Fac"])
    mottled = nodes.new("ShaderNodeMix")
    mottled.data_type = "RGBA"
    mottled.blend_type = "MULTIPLY"
    mottled.inputs["Factor"].default_value = 1.0
    links.new(colour_out, mottled.inputs[6])
    links.new(mottle_ramp.outputs["Color"], mottled.inputs[7])
    colour_out = mottled.outputs[2]

    if rules_image is not None:
        img = nodes.new("ShaderNodeTexImage")
        img.image = rules_image
        img.interpolation = "Cubic"
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
    fine.inputs["Scale"].default_value = fibre_scale
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
    m1 = nodes.new("ShaderNodeMath"); m1.operation = "MULTIPLY"; m1.inputs[1].default_value = 0.65
    m2 = nodes.new("ShaderNodeMath"); m2.operation = "MULTIPLY"; m2.inputs[1].default_value = 0.30
    m3 = nodes.new("ShaderNodeMath"); m3.operation = "MULTIPLY"; m3.inputs[1].default_value = 0.05
    links.new(fine.outputs["Fac"], m1.inputs[0])
    links.new(coarse.outputs["Fac"], m2.inputs[0])
    links.new(grain.outputs["Value"], m3.inputs[0])
    a1 = nodes.new("ShaderNodeMath"); a1.operation = "ADD"
    a2 = nodes.new("ShaderNodeMath"); a2.operation = "ADD"
    links.new(m1.outputs[0], a1.inputs[0]); links.new(m2.outputs[0], a1.inputs[1])
    links.new(a1.outputs[0], a2.inputs[0]); links.new(m3.outputs[0], a2.inputs[1])
    bump = nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.35 * tooth
    bump.inputs["Distance"].default_value = 0.00012
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
