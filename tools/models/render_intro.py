# Stills of the arrival scene for review (Cycles on the CPU, no GPU needed), from the models train.py built and the
# library textures. Run after train.py:
#   blender -b --python tools/models/render_intro.py [-- shot ...]   -> tools/models/out/render_<shot>.png
# Shots: aisle, rider, length, outside, pistol, cloak. The lighting copies Subway.lua's car (three cold light boxes, a
# dark tunnel with warm lamps going by); Roblox's own renderer will differ, so these judge shape and surface, not mood.
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
import bpy
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
SHOTS = argv or ["aisle", "rider", "length", "outside", "pistol", "cloak"]
SAMPLES = 48

def append(blend, prefix=None):
    with bpy.data.libraries.load(blend) as (src, dst):
        dst.objects = [n for n in src.objects if prefix is None or n.startswith(prefix)]
    out = []
    for o in dst.objects:
        if o is not None:
            bpy.context.collection.objects.link(o)
            out.append(o)
    return out

def emissive(name, size, at, color=(0.85, 0.93, 1.0), strength=12.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=at)
    o = bpy.context.active_object
    o.name, o.scale = name, size
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Emission Color"].default_value = (*color, 1)
    b.inputs["Emission Strength"].default_value = strength
    b.inputs["Base Color"].default_value = (*color, 1)
    o.data.materials.append(m)
    return o

def light(kind, at, energy, color=(1, 1, 1), size=1.0, rot=(0, 0, 0)):
    d = bpy.data.lights.new("L", kind)
    d.energy, d.color = energy, color
    if kind == "AREA":
        d.size = size
    elif kind == "POINT":
        d.shadow_soft_size = size
    o = bpy.data.objects.new("L", d)
    o.location, o.rotation_euler = at, rot
    bpy.context.collection.objects.link(o)
    return o

def camera(at, look, lens=24):
    c = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    c.data.lens = lens
    c.location = at
    c.rotation_euler = (Vector(look) - Vector(at)).to_track_quat("-Z", "Y").to_euler()
    bpy.context.collection.objects.link(c)
    bpy.context.scene.camera = c
    return c

def glassify():
    for o in bpy.data.objects:
        if o.type == "MESH" and o.name.endswith("_Glass"):
            m = bpy.data.materials.new("GlassR")
            m.use_nodes = True
            b = m.node_tree.nodes["Principled BSDF"]
            b.inputs["Base Color"].default_value = (0.5, 0.6, 0.65, 1)
            b.inputs["Roughness"].default_value = 0.05
            b.inputs["Transmission Weight"].default_value = 0.92
            o.data.materials.clear()
            o.data.materials.append(m)
        if o.type == "MESH" and o.name.endswith("_Screen"):
            m = bpy.data.materials.new("ScreenR")
            m.use_nodes = True
            b = m.node_tree.nodes["Principled BSDF"]
            b.inputs["Base Color"].default_value = (0.02, 0.02, 0.02, 1)
            b.inputs["Emission Color"].default_value = (1.0, 0.45, 0.1, 1)
            b.inputs["Emission Strength"].default_value = 1.5
            o.data.materials.clear()
            o.data.materials.append(m)

def setup(size=(1280, 720)):
    s = bpy.context.scene
    s.render.engine = "CYCLES"
    s.cycles.device = "CPU"
    s.cycles.samples = SAMPLES
    s.cycles.use_denoising = True
    s.render.resolution_x, s.render.resolution_y = size
    s.view_settings.view_transform = "AgX"
    s.view_settings.look = "AgX - Medium High Contrast"
    w = bpy.data.worlds.new("W")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Color"].default_value = (0.004, 0.005, 0.006, 1)
    s.world = w

def render(name):
    p = os.path.join(OUT, f"render_{name}.png")
    bpy.context.scene.render.filepath = p
    bpy.ops.render.render(write_still=True)
    print("RENDERED", p)

def darken_head(objs):
    for o in objs:
        if o.name.startswith("Head"):
            m = bpy.data.materials.new("Shadow")
            m.use_nodes = True
            m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.01, 0.01, 0.012, 1)
            o.data.materials.clear()
            o.data.materials.append(m)

def rider_at(seated=True):
    """The poncho, hood and proxy rider (in the upper torso's frame) placed on the west bench at y 12."""
    objs = append(os.path.join(OUT, "Intro_Cloak_scene.blend"))   # the live cloak is drawn as it was draped, on a standing body
    lean = Matrix.Rotation(math.radians(-15 if seated else -2), 4, "X")
    up = lean.to_3x3() @ Vector((0, 0, 1))
    if seated:
        ut = Matrix.Translation(up * 1.45) @ lean
        hip = Matrix.Translation((5.15, 12.0, 1.89)) @ Matrix.Rotation(math.radians(-90), 4, "Z")
    else:
        ut = Matrix.Translation(Vector((0, 0, 2.47)) + up * 1.45) @ lean
        hip = Matrix.Translation((0.0, 9.0, 0.0)) @ Matrix.Rotation(math.radians(0), 4, "Z")
    for o in objs:
        o.matrix_world = hip @ ut
    return objs  # the proxy head stands in for the Conduit's own hood and visor

def car_scene():
    reset()
    objs = append(os.path.join(OUT, "Subway_Car_scene.blend"))
    door = append(os.path.join(OUT, "Subway_Door_scene.blend"))
    # four leaves: the model is one leaf centred on y 0 with its seal at +y
    leaves = []
    base = door
    for i, (x, y, rz) in enumerate(((-6.15, 2.0, 180), (-6.15, -2.0, 0), (6.15, 2.0, 0), (6.15, -2.0, 180))):
        group = base if i == 0 else [o.copy() for o in base]
        for o in group:
            if i:
                bpy.context.collection.objects.link(o)
            o.matrix_world = Matrix.Translation((x, y, 0)) @ Matrix.Rotation(math.radians(rz), 4, "Z") @ Matrix.Rotation(math.radians(180 if x > 0 else 0), 4, "Z")
        leaves += group
    rider = rider_at(True)
    pbr_swap([o for o in bpy.data.objects if o.type == "MESH"])
    darken_head(rider)
    glassify()
    for y in (-16, 0, 16):  # Subway.lua's light boxes (0.8 x 6 at z 8.3..8.5) with the PointLights under them
        emissive("CarLight", (0.8, 6.0, 0.2), (0, y, 10.6))
        light("AREA", (0, y, 10.45), 320, (0.85, 0.93, 1.0), size=2.5, rot=(0, 0, 0))
    # the tunnel: dark concrete walls close to the glass, a few warm lamps
    for sx in (-1, 1):
        bpy.ops.mesh.primitive_cube_add(size=1, location=(sx * 7.2, 0, 3.5))
        w = bpy.context.active_object
        w.scale = (0.5, 120, 14)
        m = bpy.data.materials.new("Tunnel")
        m.use_nodes = True
        m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.03, 0.03, 0.032, 1)
        w.data.materials.append(m)
        for y in (-20, 10, 34):
            emissive("TunnelLamp", (0.2, 0.6, 0.3), (sx * 6.85, y, 7.5), (1.0, 0.7, 0.4), 30)
            light("POINT", (sx * 6.6, y, 7.4), 60, (1.0, 0.72, 0.45), 0.3)
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -3.4))
    return objs, rider

def outside_scene():
    reset()
    append(os.path.join(OUT, "Subway_Car_scene.blend"))
    door = append(os.path.join(OUT, "Subway_Door_scene.blend"))
    for o in door:
        o.matrix_world = Matrix.Translation((-6.15, 2.0, 0)) @ Matrix.Rotation(math.pi, 4, "Z")
    pbr_swap([o for o in bpy.data.objects if o.type == "MESH"])
    glassify()
    for y in (-16, 0, 16):
        emissive("CarLight", (0.8, 6.0, 0.2), (0, y, 10.6))
        light("AREA", (0, y, 10.45), 320, (0.85, 0.93, 1.0), size=2.5)
    # a platform on the door side (Blender -X) and its cold lamps
    bpy.ops.mesh.primitive_cube_add(size=1, location=(-17, 0, -3.0))
    p = bpy.context.active_object
    p.scale = (25, 92, 6)
    m = bpy.data.materials.new("Platform")
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.08, 0.08, 0.085, 1)
    m.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.8
    p.data.materials.append(m)
    bpy.ops.mesh.primitive_plane_add(size=300, location=(0, 0, -3.4))
    for y in (-30, 0, 22):
        emissive("PlatLamp", (4, 1.2, 0.5), (-21.5, y, 13.5), (0.8, 0.9, 1.0), 20)
        light("AREA", (-21.5, y, 13.2), 900, (0.8, 0.9, 1.0), size=4)

def studio(objs, at, look, lens=50, energy=(400, 150, 300)):
    w = bpy.context.scene.world
    w.node_tree.nodes["Background"].inputs["Color"].default_value = (0.02, 0.022, 0.025, 1)
    k = light("AREA", (at[0] + 2, at[1] - 1, at[2] + 3), energy[0], (1.0, 0.95, 0.9), size=3)
    k.rotation_euler = (Vector(look) - k.location).to_track_quat("-Z", "Y").to_euler()
    f = light("AREA", (at[0] - 3, at[1] + 1, at[2] + 1), energy[1], (0.8, 0.9, 1.0), size=4)
    f.rotation_euler = (Vector(look) - f.location).to_track_quat("-Z", "Y").to_euler()
    r = light("AREA", (look[0] - 1, look[1] + 4, look[2] + 3), energy[2], (0.9, 0.95, 1.0), size=2)
    r.rotation_euler = (Vector(look) - r.location).to_track_quat("-Z", "Y").to_euler()
    camera(at, look, lens)

if __name__ == "__main__":
    car_shots = [s for s in SHOTS if s in ("aisle", "rider", "length")]
    if car_shots:
        car_scene()
        setup()
        shots = {
            "aisle": ((-4.2, 1.0, 5.6), (4.6, 13.5, 3.0), 20),
            "rider": ((0.8, 8.0, 4.2), (4.8, 12.2, 3.4), 28),
            "length": ((0.0, -26.5, 6.2), (0.0, 18.0, 4.2), 18),
        }
        for s in car_shots:
            camera(*shots[s][:2], shots[s][2])
            render(s)
    if "outside" in SHOTS:
        outside_scene()
        setup()
        camera((-17.0, -26.0, 4.5), (-3.0, 4.0, 3.0), 24)
        render("outside")
    if "pistol" in SHOTS:
        reset()
        for o in append(os.path.join(OUT, "Wpn_Whisper_scene.blend")):
            o.matrix_world = Matrix.Rotation(math.radians(90), 4, "X") @ o.matrix_world   # barrel along +Y, top up
        pbr_swap([o for o in bpy.data.objects if o.type == "MESH"])
        setup((1280, 720))
        studio(None, (3.2, -2.6, 1.5), (0, -0.9, 0.55), lens=45)
        render("pistol")
    if "kit" in SHOTS:
        # The four pistol variants, one above the other, seen from the right side.
        reset()
        for i, v in enumerate(["Whisper", "WhisperBare", "WhisperCompact", "WhisperLight"]):
            for o in append(os.path.join(OUT, f"Wpn_{v}_scene.blend")):
                o.matrix_world = Matrix.Translation((0, 0, -2.2 * i)) @ Matrix.Rotation(math.radians(90), 4, "X") @ o.matrix_world
        pbr_swap([o for o in bpy.data.objects if o.type == "MESH"])
        setup((1000, 1500))
        studio(None, (13.5, -1.2, -3.3), (0, -1.2, -3.3), lens=50, energy=(2200, 700, 1400))
        render("kit")
    if "pistol_q" in SHOTS:
        reset()
        for o in append(os.path.join(OUT, "Wpn_Whisper_scene.blend")):
            o.matrix_world = Matrix.Rotation(math.radians(90), 4, "X") @ o.matrix_world
        pbr_swap([o for o in bpy.data.objects if o.type == "MESH"])
        setup((1280, 720))
        studio(None, (-2.9, 1.6, 1.3), (0, -0.9, 0.45), lens=38, energy=(700, 250, 500))
        render("pistol_q")
    if "cloak" in SHOTS:
        reset()
        objs = rider_at(False)
        for o in objs:
            o.matrix_world = Matrix.Translation((0, 0, 0)) @ o.matrix_world
        pbr_swap([o for o in bpy.data.objects if o.type == "MESH"])
        darken_head(objs)
        setup((900, 1100))
        bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 9.0, 0))
        studio(None, (-4.5, 1.5, 4.6), (0, 9.0, 3.0), lens=35, energy=(900, 300, 700))
        render("cloak")
