# The handgun kit (2026-11-11, Andy: "strip the model into its components, a trigger, a frame, a hammer, slide,
# supressor, barrel, and weapon light, then we can create several variations"). Each component has a few shapes;
# a variant is one pick per slot. The look follows a long-slide, hammer-fired .45 service pistol of the 1990s
# (squared trigger guard, exposed hammer, a threaded barrel, a big can and a boxy light/laser module).
#
# Run: blender -b --python tools/models/pistol_kit.py [-- Variant ...]  -> out/Wpn_<Variant>.fbx, out/Wpn_<Variant>_scene.blend
#
# Axes (the Pistol grip convention, unchanged): the grip's top at the origin running down -Y, the barrel along +Z,
# the top of the gun at +Y, width on X. The FBX import makes that Roblox: barrel +Y, top +Z.
# Part names: every component is its own MeshPart "<Slot>_<Material>", so the game can move one: the client racks the
# part whose name starts with "Slide" and can cock the one starting with "Hammer".
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
import bpy, bmesh
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []

PAL = {"Gunmetal": (0.04, 0.04, 0.045), "Polymer": (0.02, 0.02, 0.025), "GlassDark": (0.08, 0.1, 0.13)}
T = lambda x, y, z: Matrix.Translation((x, y, z))
RX = lambda d: Matrix.Rotation(math.radians(d), 4, "X")
RZ = lambda d: Matrix.Rotation(math.radians(d), 4, "Z")
S = lambda x, y, z: Matrix.Diagonal((x, y, z, 1))

def mat(n):
    return bpy.data.materials.get(n) or material(n, PAL[n], roughness=0.08 if n == "GlassDark" else 0.6)

class G:
    def __init__(self):
        self.bm = bmesh.new()
    def _take(self, tmp):
        me = bpy.data.meshes.new("tmp")
        tmp.to_mesh(me)
        tmp.free()
        self.bm.from_mesh(me)
        bpy.data.meshes.remove(me)
    def side(self, outline, width, x=0.0, bev=0.03, M=Matrix.Identity(4)):
        """A side-view silhouette [(z, y)...] (counter-clockwise seen from +X) extruded across X, edges bevelled."""
        tmp = bmesh.new()
        vs = [tmp.verts.new((x - width / 2, y, z)) for z, y in outline]
        f = tmp.faces.new(vs)
        r = bmesh.ops.extrude_face_region(tmp, geom=[f])
        moved = [e for e in r["geom"] if isinstance(e, bmesh.types.BMVert)]
        bmesh.ops.translate(tmp, vec=(width, 0, 0), verts=moved)
        bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
        if bev > 0:
            bmesh.ops.bevel(tmp, geom=list(tmp.edges), offset=bev, offset_type="OFFSET", segments=2, profile=0.5,
                            affect="EDGES", clamp_overlap=True)
        bmesh.ops.transform(tmp, matrix=M, verts=tmp.verts)
        self._take(tmp)
        return self
    def box(self, size, M, bev=0.0):
        tmp = bmesh.new()
        bmesh.ops.create_cube(tmp, size=1.0, matrix=S(*size))
        if bev > 0:
            bmesh.ops.bevel(tmp, geom=list(tmp.edges), offset=min(bev, min(size) * 0.45), offset_type="OFFSET", segments=2,
                            profile=0.5, affect="EDGES", clamp_overlap=True)
        bmesh.ops.transform(tmp, matrix=M, verts=tmp.verts)
        self._take(tmp)
        return self
    def cyl(self, r1, r2, depth, M, seg=24):
        tmp = bmesh.new()
        bmesh.ops.create_cone(tmp, cap_ends=True, cap_tris=False, segments=seg, radius1=r1, radius2=r2, depth=depth, matrix=M)
        self._take(tmp)
        return self
    def make(self, name, m, smooth=False):
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=0.0003)
        ob = obj_from_bmesh(name, self.bm, mat(m))
        if smooth:
            for p in ob.data.polygons:
                p.use_smooth = True
        if m in TILE:
            uv_box(ob)
        return ob

BORE_Y = 0.66            # barrel axis height
# ---------------------------------------------------------------- frames
def rake(outline, top=0.2, k=0.28):
    """Shear a grip outline back below its top, so the grip leans the way a hand holds it."""
    return [(z + (y - top) * k if y < top else z, y) for z, y in outline]

def guard(g, front):
    """The trigger guard: a U hanging from the frame's underside, a flat front with a hook for the off-hand finger."""
    g.side([(front - 0.1, 0.33), (front, 0.33), (front, 0.07), (front + 0.04, 0.0), (front, -0.05), (front - 0.08, -0.07),
            (0.02, -0.07), (0.01, 0.02), (front - 0.14, 0.02), (front - 0.1, 0.07)], 0.17, bev=0.014)

def grip(g, bottom, width):
    g.side(rake([(-0.36, 0.22), (0.04, 0.22), (0.07, 0.05), (0.05, -0.10), (0.08, -0.24), (0.05, bottom * 0.6),
                 (0.07, bottom * 0.8), (0.04, bottom + 0.04), (-0.02, bottom), (-0.40, bottom), (-0.44, bottom + 0.08),
                 (-0.46, -0.30), (-0.44, 0.0), (-0.46, 0.12)]), width, bev=0.05)
    g.side(rake([(0.06, bottom + 0.02), (0.06, bottom - 0.04), (-0.44, bottom - 0.04), (-0.44, bottom + 0.02)]),
           width + 0.03, bev=0.015)                              # magazine base plate

def frame_service(g):
    """Full-size polymer frame: dust cover with rail slots, a squared trigger guard with a hooked front, a thick raked
    grip."""
    # the frame body above the grip and in front of it (side view: z forward, y up)
    g.side([(-0.42, 0.52), (-0.42, 0.30), (-0.28, 0.20), (0.02, 0.20), (0.06, 0.30), (1.12, 0.30), (1.16, 0.36),
            (1.16, 0.52)], 0.27, bev=0.025)
    grip(g, -0.66, 0.30)
    guard(g, 0.72)
    for k in range(4):                                       # the rail's cross slots under the dust cover
        g.box((0.29, 0.03, 0.05), T(0, 0.30, 0.82 + k * 0.08))
    g.box((0.04, 0.05, 0.16), T(0.15, 0.40, -0.2), bev=0.01)   # decocker / safety lever
    g.box((0.04, 0.05, 0.16), T(-0.15, 0.40, -0.2), bev=0.01)
    g.box((0.04, 0.06, 0.08), T(0.15, 0.36, 0.1), bev=0.01)    # magazine release behind the guard

def frame_compact(g):
    g.side([(-0.42, 0.52), (-0.42, 0.30), (-0.28, 0.20), (0.02, 0.20), (0.06, 0.30), (0.82, 0.30), (0.86, 0.36),
            (0.86, 0.52)], 0.26, bev=0.025)
    grip(g, -0.50, 0.28)
    guard(g, 0.66)

FRAMES = {"Service": frame_service, "Compact": frame_compact}
FRAME_FRONT = {"Service": 1.16, "Compact": 0.86}

# ---------------------------------------------------------------- slides
def slide(g, length):
    """Flat-sided slide, the top chamfered, the nose rounded down, rear cocking grooves, an ejection port, sights."""
    z0, z1 = -0.44, -0.44 + length
    prof = [(z0, 0.52), (z1 - 0.06, 0.52), (z1, 0.56), (z1, 0.74), (z1 - 0.05, 0.80), (z0 + 0.02, 0.80), (z0, 0.76)]
    g.side(prof, 0.28, bev=0.02)
    g.side([(z0 + 0.06, 0.78), (z1 - 0.1, 0.78), (z1 - 0.12, 0.84), (z0 + 0.08, 0.84)], 0.18, bev=0.02)   # top flat
    for k in range(8):
        for sx in (-1, 1):
            g.box((0.02, 0.2, 0.022), T(sx * 0.141, 0.66, z0 + 0.08 + k * 0.045))
    g.box((0.07, 0.07, 0.06), T(-0.055, 0.87, z0 + 0.1), bev=0.012)      # rear sight
    g.box((0.07, 0.07, 0.06), T(0.055, 0.87, z0 + 0.1), bev=0.012)
    g.box((0.04, 0.07, 0.06), T(0, 0.87, z1 - 0.1), bev=0.012)           # front sight
    g.box((0.03, 0.12, 0.34), T(0.141, 0.70, 0.2))                        # ejection port rim (the barrel shows inside)

SLIDES = {"Long": 1.62, "Short": 1.30}

# ---------------------------------------------------------------- barrels, hammers, triggers
def barrel(g, length, threaded):
    g.cyl(0.075, 0.075, length, T(0, BORE_Y, length / 2 - 0.3), seg=20)
    g.box((0.13, 0.1, 0.32), T(0, 0.70, 0.2), bev=0.01)                  # the chamber in the port
    if threaded:
        for k in range(5):
            g.cyl(0.082, 0.082, 0.025, T(0, BORE_Y, length - 0.3 + 0.02 + k * 0.045), seg=20)
        g.cyl(0.075, 0.075, 0.24, T(0, BORE_Y, length - 0.3 + 0.12), seg=20)

def hammer_spur(g):
    """A round-spur hammer standing out of the frame's back, cocked a little."""
    g.side([(-0.40, 0.52), (-0.46, 0.66), (-0.54, 0.78), (-0.6, 0.80), (-0.62, 0.74), (-0.56, 0.66), (-0.5, 0.52)], 0.12, bev=0.02)
    for k in range(4):
        g.box((0.13, 0.015, 0.02), T(0, 0.70 + k * 0.025, -0.575 + k * 0.012))

def hammer_bobbed(g):
    g.side([(-0.40, 0.52), (-0.46, 0.64), (-0.52, 0.66), (-0.52, 0.52)], 0.12, bev=0.02)

HAMMERS = {"Spur": hammer_spur, "Bobbed": hammer_bobbed}

def trigger(g):
    g.side([(0.30, 0.31), (0.36, 0.20), (0.38, 0.10), (0.35, 0.04), (0.31, 0.06), (0.32, 0.12), (0.26, 0.24)], 0.07, bev=0.01)

# ---------------------------------------------------------------- muzzle devices and lights
def can(g, length, radius, start):
    """A suppressor: a knurled rear collar, a smooth tube, a stepped end cap with the bore."""
    g.cyl(radius * 0.9, radius, 0.06, T(0, BORE_Y, start + 0.03), seg=28)
    for k in range(6):
        g.cyl(radius + 0.012, radius + 0.012, 0.025, T(0, BORE_Y, start + 0.09 + k * 0.04), seg=28)
    g.cyl(radius, radius, length - 0.4, T(0, BORE_Y, start + 0.32 + (length - 0.4) / 2), seg=28)
    g.cyl(radius, radius * 0.86, 0.08, T(0, BORE_Y, start + length - 0.04), seg=28)
    g.cyl(0.04, 0.04, 0.02, T(0, BORE_Y, start + length + 0.001), seg=12)

def light_module(g, lens, front):
    """A boxy light/laser module on the rail: a housing, two windows, a paddle switch at the trigger guard."""
    z1 = front + 0.08
    g.side([(0.80, 0.31), (z1, 0.31), (z1, 0.05), (z1 - 0.08, -0.01), (0.86, -0.01), (0.80, 0.06)], 0.30, bev=0.03)
    g.box((0.05, 0.08, 0.16), T(0.15, 0.13, 0.80), bev=0.015)             # the switch paddle, reachable from the guard
    lens.cyl(0.075, 0.075, 0.02, T(0.05, 0.14, z1 + 0.005), seg=20)
    lens.cyl(0.03, 0.03, 0.02, T(-0.09, 0.22, z1 + 0.005), seg=12)

# ---------------------------------------------------------------- variants
VARIANTS = {
    # the Whisper: the arrival's pistol (Assets.Weapons.Whisper)
    "Whisper": dict(frame="Service", slide="Long", hammer="Spur", can=(1.55, 0.18), light=True),
    "WhisperBare": dict(frame="Service", slide="Long", hammer="Spur", can=None, light=False),
    "WhisperCompact": dict(frame="Compact", slide="Short", hammer="Bobbed", can=(1.1, 0.15), light=False),
    "WhisperLight": dict(frame="Service", slide="Long", hammer="Bobbed", can=None, light=True),
}

def build(name, v):
    reset()
    fr, sl, ba, hm, tr, mz, li, le = (G() for _ in range(8))
    FRAMES[v["frame"]](fr)
    length = SLIDES[v["slide"]]
    slide(sl, length)
    muzzle = -0.44 + length
    barrel(ba, muzzle + 0.3 + (0.14 if v["can"] else 0.02), bool(v["can"]))
    HAMMERS[v["hammer"]](hm)
    trigger(tr)
    parts = [fr.make("Frame", "Polymer"), sl.make("Slide", "Gunmetal"), ba.make("Barrel", "Gunmetal", smooth=True),
             hm.make("Hammer", "Gunmetal"), tr.make("Trigger", "Gunmetal")]
    if v["can"]:
        can(mz, v["can"][0], v["can"][1], muzzle + 0.12)
        parts.append(mz.make("Suppressor", "Gunmetal", smooth=True))
    if v["light"]:
        light_module(li, le, FRAME_FRONT[v["frame"]])
        parts.append(li.make("Light", "Polymer"))
        parts.append(le.make("LightLens", "GlassDark"))
    os.makedirs(OUT, exist_ok=True)
    export_fbx(os.path.join(OUT, f"Wpn_{name}.fbx"), parts)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, f"Wpn_{name}_scene.blend"))
    print("BUILT", name, len(parts), "parts", sum(len(p.data.polygons) for p in parts), "faces")

if __name__ == "__main__":
    for name in (argv or VARIANTS):
        build(name, VARIANTS[name])
