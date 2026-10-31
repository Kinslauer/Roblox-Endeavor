# District building kits. Each building is built straight into bmesh buffers, one per material,
# so a whole facade with 100+ windows exports as 4-6 MeshParts. Styles match City.Districts.
# Run: blender -b --python buildings.py  -> out/Bld_<Style>_<Size>_<A|C>.fbx
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
import bmesh
from mathutils import Matrix, Vector

STYLES = {
    # footprint (w,d), heights per size class, palette
    "Transit":   dict(w=50, d=50, heights=(16, 28, 40), body="Concrete", trim="Steel", neon="Neon", glass="GlassDark", win=(3.2, 4.2), floor=6.0, rows_skip=0),
    "Corp":      dict(w=68, d=68, heights=(44, 76, 108), body="Panel", trim="DarkMetal", neon="NeonPink", glass="GlassCorp", win=(5.4, 5.6), floor=7.0, rows_skip=0),
    "Sprawl":    dict(w=34, d=34, heights=(9, 15, 22), body="Brick", trim="Rust", neon="NeonAmber", glass="GlassDark", win=(2.4, 3.4), floor=5.0, rows_skip=0),
    "Blackout":  dict(w=50, d=50, heights=(22, 46, 70), body="DarkConcrete", trim="Rust", neon="NeonRed", glass="GlassDark", win=(3.0, 4.0), floor=6.0, rows_skip=0),
    "Outskirts": dict(w=20, d=20, heights=(7, 11, 16), body="Concrete", trim="Rust", neon=None, glass="GlassDark", win=(2.2, 2.6), floor=4.5, rows_skip=0),
}

class Builder:
    """Accumulates boxes into one bmesh per material."""
    def __init__(self):
        self.bms = {}
    def box(self, mat, size, center, rot_z=0.0):
        bm = self.bms.setdefault(mat, bmesh.new())
        m = Matrix.Translation(Vector(center)) @ Matrix.Rotation(rot_z, 4, "Z") @ Matrix.Diagonal((size[0], size[1], size[2], 1))
        bmesh.ops.create_cube(bm, size=1.0, matrix=m)
    def cyl(self, mat, radius, depth, center, segments=8, rot=None):
        bm = self.bms.setdefault(mat, bmesh.new())
        m = Matrix.Translation(Vector(center))
        if rot: m = m @ Matrix.Rotation(rot[1], 4, rot[0])
        bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=radius, radius2=radius, depth=depth, matrix=m)
    def objects(self, prefix):
        out = []
        for mat, bm in self.bms.items():
            bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.001)
            ob = obj_from_bmesh(f"{prefix}{mat}", bm, material(mat, PALETTE[mat]))
            out.append(ob)
        self.bms = {}
        return out

PALETTE = {
    "Concrete": (0.40, 0.40, 0.42), "DarkConcrete": (0.17, 0.17, 0.20), "Panel": (0.26, 0.27, 0.33), "Brick": (0.38, 0.24, 0.17),
    "Steel": (0.30, 0.31, 0.34), "DarkMetal": (0.14, 0.14, 0.16), "Rust": (0.36, 0.20, 0.12),
    "GlassDark": (0.08, 0.10, 0.14), "GlassCorp": (0.10, 0.18, 0.26), "GlassLit": (0.85, 0.75, 0.45),
    "Neon": (0.05, 0.75, 0.95), "NeonPink": (0.95, 0.20, 0.60), "NeonAmber": (1.0, 0.62, 0.15), "NeonRed": (1.0, 0.12, 0.12),
    "Rubble": (0.33, 0.32, 0.31), "Burnt": (0.12, 0.10, 0.09),
}

def facade(b, st, w, d, h, rng, lit_chance=0.18, start_floor=1):
    """Window grid on all four faces, floor bands, a parapet, a storefront on the front face."""
    ww, wh = st["win"]
    floor = st["floor"]
    floors = int(h // floor)
    for face in range(4):
        along = w if face in (0, 2) else d
        cols = max(1, int(along // (ww * 1.7)))
        pitch = along / cols
        for f in range(start_floor, floors):
            z = f * floor + floor * 0.55
            for c in range(cols):
                a = -along / 2 + pitch * (c + 0.5)
                mat = "GlassLit" if rng.random() < lit_chance else st["glass"]
                # window: a slab slightly proud of the wall so it reads at distance; frame around it
                if face == 0:   c3, size = (a, -d / 2 - 0.12, z), (ww, 0.25, wh)
                elif face == 2: c3, size = (a, d / 2 + 0.12, z), (ww, 0.25, wh)
                elif face == 1: c3, size = (w / 2 + 0.12, a, z), (0.25, ww, wh)
                else:           c3, size = (-w / 2 - 0.12, a, z), (0.25, ww, wh)
                b.box(mat, size, c3)
                frame = (size[0] + 0.4 if size[0] > 0.3 else 0.3, size[1] + 0.4 if size[1] > 0.3 else 0.3, wh + 0.4)
                b.box(st["trim"], frame, (c3[0], c3[1] + (0.05 if face == 0 else -0.05 if face == 2 else 0), c3[2]) if face in (0, 2) else (c3[0] + (-0.05 if face == 1 else 0.05), c3[1], c3[2]))
        # floor bands
        for f in range(start_floor, floors + 1):
            z = f * floor
            if face == 0: b.box(st["trim"], (w + 0.6, 0.5, 0.35), (0, -d / 2 - 0.1, z))
            elif face == 2: b.box(st["trim"], (w + 0.6, 0.5, 0.35), (0, d / 2 + 0.1, z))
    # parapet + roof slab
    b.box(st["body"], (w + 1.2, d + 1.2, 1.2), (0, 0, h + 0.6))
    b.box(st["trim"], (w + 1.6, 0.6, 2.2), (0, -d / 2 - 0.3, h + 1.6)); b.box(st["trim"], (w + 1.6, 0.6, 2.2), (0, d / 2 + 0.3, h + 1.6))
    b.box(st["trim"], (0.6, d + 1.6, 2.2), (-w / 2 - 0.3, 0, h + 1.6)); b.box(st["trim"], (0.6, d + 1.6, 2.2), (w / 2 + 0.3, 0, h + 1.6))
    # storefront on the ground floor of the front face: recessed dark glass + awning + sign
    sf_w = min(w * 0.7, 26)
    b.box("GlassDark", (sf_w, 0.4, floor * 1.6), (0, -d / 2 - 0.1, floor * 0.9))
    b.box(st["trim"], (sf_w + 1.5, 2.2, 0.4), (0, -d / 2 - 1.2, floor * 1.8))
    if st["neon"]:
        b.box(st["neon"], (sf_w * 0.8, 0.3, 0.7), (0, -d / 2 - 0.5, floor * 2.1))
        # a vertical sign on one corner
        b.box(st["neon"], (0.5, 1.6, min(h * 0.5, 22)), (w / 2 + 0.9, -d / 2 + 2.0, min(h * 0.5, 22) / 2 + floor * 2))
        b.box(st["trim"], (0.8, 2.0, min(h * 0.5, 22) + 0.6), (w / 2 + 0.9, -d / 2 + 2.0, min(h * 0.5, 22) / 2 + floor * 2))

def rooftop(b, st, w, d, h, rng):
    for _ in range(rng.randint(2, 4)):
        bw, bd, bh = rng.uniform(3, 7), rng.uniform(3, 7), rng.uniform(2, 4)
        b.box("DarkMetal", (bw, bd, bh), (rng.uniform(-w / 2 + 5, w / 2 - 5), rng.uniform(-d / 2 + 5, d / 2 - 5), h + 1.2 + bh / 2))
    # water tank or antenna
    if rng.random() < 0.5:
        b.cyl("Rust", 2.4, 4.5, (rng.uniform(-w / 4, w / 4), rng.uniform(-d / 4, d / 4), h + 1.2 + 2.25), 10)
    else:
        x, y = rng.uniform(-w / 4, w / 4), rng.uniform(-d / 4, d / 4)
        b.cyl("Steel", 0.25, 12, (x, y, h + 1.2 + 6), 6)
        b.box("Steel", (4, 0.2, 0.2), (x, y, h + 1.2 + 10))

def fire_escape(b, w, d, h, floor, start_floor=1):
    floors = int(h // floor)
    x = w / 2 + 1.5
    for f in range(start_floor, floors):
        z = f * floor
        b.box("Steel", (3.0, 6.0, 0.25), (x, 0, z))  # landing
        b.box("Steel", (0.15, 6.0, 1.1), (x + 1.4, 0, z + 0.6))  # rail
        b.box("Steel", (2.6, 0.3, floor * 0.9), (x, 2.5, z + floor * 0.45), rot_z=0)  # stair stringer (reads as a slope at distance)

def collapse(b, st, w, d, h, rng):
    """A collapsed version: a jagged stump a third to a half the height, exposed floor slabs, rubble."""
    hh = h * rng.uniform(0.3, 0.5)
    # body kept as four uneven wall fragments so the inside reads as open
    for face in range(4):
        keep = rng.uniform(0.4, 0.9)
        fh = hh * rng.uniform(0.6, 1.1)
        if face == 0:   b.box(st["body"], (w * keep, 1.5, fh), (rng.uniform(-w * (1 - keep) / 2, w * (1 - keep) / 2), -d / 2 + 0.75, fh / 2))
        elif face == 2: b.box(st["body"], (w * keep, 1.5, fh), (rng.uniform(-w * (1 - keep) / 2, w * (1 - keep) / 2), d / 2 - 0.75, fh / 2))
        elif face == 1: b.box(st["body"], (1.5, d * keep, fh), (w / 2 - 0.75, rng.uniform(-d * (1 - keep) / 2, d * (1 - keep) / 2), fh / 2))
        else:           b.box(st["body"], (1.5, d * keep, fh), (-w / 2 + 0.75, rng.uniform(-d * (1 - keep) / 2, d * (1 - keep) / 2), fh / 2))
    floor = st["floor"]
    for f in range(1, int(hh // floor) + 1):
        b.box("Rubble", (w * rng.uniform(0.5, 0.9), d * rng.uniform(0.5, 0.9), 0.8), (rng.uniform(-3, 3), rng.uniform(-3, 3), f * floor))
    for _ in range(rng.randint(6, 10)):
        s = rng.uniform(2, 6)
        b.box("Rubble", (s, s * rng.uniform(0.6, 1.4), s * 0.6), (rng.uniform(-w / 2 - 4, w / 2 + 4), rng.uniform(-d / 2 - 4, d / 2 + 4), s * 0.25), rot_z=rng.uniform(0, 3))
    for _ in range(rng.randint(3, 6)):
        b.cyl("Rust", 0.08, rng.uniform(3, 7), (rng.uniform(-w / 2, w / 2), rng.uniform(-d / 2, d / 2), hh * 0.6), 5, rot=("X", rng.uniform(0.6, 1.5)))
    if rng.random() < 0.6:
        b.box("Burnt", (w * 0.6, d * 0.6, 0.1), (0, 0, 0.05))

def build(style, size_idx, cond, seed):
    st = STYLES[style]
    rng = random.Random(seed)
    reset()
    b = Builder()
    w, d, h = st["w"], st["d"], st["heights"][size_idx]
    if cond == "A":
        b.box(st["body"], (w, d, h), (0, 0, h / 2))
        facade(b, st, w, d, h, rng)
        rooftop(b, st, w, d, h, rng)
        if style in ("Sprawl", "Blackout") and rng.random() < 0.7:
            fire_escape(b, w, d, h, st["floor"])
    else:
        collapse(b, st, w, d, h, rng)
    name = f"Bld_{style}_{size_idx}_{cond}"
    objs = b.objects(name + "_")
    # the loader reads "<Part>_<Material>": name objects so the material is the suffix
    for o in objs:
        o.name = f"{name}_{o.name.split('_')[-1]}"
    export_fbx(os.path.join(OUT, name + ".fbx"), objs)
    render(os.path.join(OUT, name + "_preview.png"), objs, azimuth=0.75, elevation=0.35)
    tris = sum(len(o.data.polygons) for o in objs)
    print("BUILT", name, "objects", len(objs), "faces", tris)

seed = 100
for style in STYLES:
    for size_idx in range(3):
        for cond in ("A", "C"):
            build(style, size_idx, cond, seed); seed += 1
print("BUILDINGS DONE")
