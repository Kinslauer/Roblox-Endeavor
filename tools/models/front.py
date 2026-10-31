# The Front's battlefield props: sandbag nests, the low sandbags soldiers stack, burnt trucks,
# tank traps and ammo crates. Footprints match the generated boxes they replace in
# src/war/server/Battlefield.lua. Run: blender -b --python front.py -> out/Front_<Name>.fbx
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
import bmesh
from mathutils import Matrix, Vector

PAL = {"Sandbag": (0.52, 0.46, 0.32), "SandbagDark": (0.40, 0.34, 0.22), "Rust": (0.36, 0.20, 0.12), "Char": (0.09, 0.08, 0.08),
       "DarkMetal": (0.14, 0.14, 0.16), "Steel": (0.30, 0.31, 0.34), "OldWood": (0.30, 0.24, 0.16), "Rubber": (0.06, 0.06, 0.06),
       "Olive": (0.24, 0.27, 0.16)}
def mat(n):
    # reset() wipes materials between props, so look one up by name each time
    import bpy
    return bpy.data.materials.get(n) or material(n, PAL[n])

def merged(name, m, pieces):
    """pieces: list of (kind, args) where kind is 'box' (size, center, yaw) or 'cyl' (r, depth, center, axis)."""
    bm = bmesh.new()
    for kind, a in pieces:
        if kind == "box":
            size, center, yaw = a
            M = Matrix.Translation(Vector(center)) @ Matrix.Rotation(yaw, 4, "Z") @ Matrix.Diagonal((size[0], size[1], size[2], 1))
            bmesh.ops.create_cube(bm, size=1.0, matrix=M)
        else:
            r, depth, center, axis = a
            rot = {"Z": Matrix.Identity(4), "X": Matrix.Rotation(math.pi / 2, 4, "Y"), "Y": Matrix.Rotation(math.pi / 2, 4, "X")}[axis]
            bmesh.ops.create_cone(bm, cap_ends=True, segments=10, radius1=r, radius2=r, depth=depth, matrix=Matrix.Translation(Vector(center)) @ rot)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.001)
    return obj_from_bmesh(name, bm, mat(m))

def bags(name, length, rows, seed, shade_every=3, torn=False):
    """A wall of sandbags along X, bottom at z=0, built from flattened boxes with a little jitter."""
    rnd = random.Random(seed)
    light, dark = [], []
    n = max(2, int(length / 1.25))
    bl = length / n
    for row in range(rows):
        off = (bl / 2) if row % 2 else 0
        for i in range(n + (1 if row % 2 else 0)):
            x = -length / 2 + off + i * bl
            if x - bl / 2 < -length / 2 - 0.01 or x + bl / 2 > length / 2 + 0.01: continue
            if torn and row == rows - 1 and rnd.random() < 0.4: continue
            z = 0.33 + row * 0.62
            piece = ("box", ((bl * 0.98, 1.3 + rnd.uniform(-0.1, 0.1), 0.64), (x, rnd.uniform(-0.06, 0.06), z), rnd.uniform(-0.08, 0.08)))
            (dark if (i + row) % shade_every == 0 else light).append(piece)
    parts = [merged(name + "Bags", "Sandbag", light)]
    if dark: parts.append(merged(name + "Worn", "SandbagDark", dark))
    for p in parts: bevel(p, 0.08, 2); apply_mods(p)
    return parts

def export(name, parts):
    export_fbx(os.path.join(OUT, f"Front_{name}.fbx"), parts)
    render(os.path.join(OUT, f"Front_{name}_preview.png"), parts, azimuth=0.9, elevation=0.5)
    print("BUILT", name)

# Sandbag nest 6 x 2 x 1.5 (Battlefield "Sandbags"): three rows, A fresh / B torn and sagging
reset(); export("Sandbags_A", bags("Nest", 6.0, 3, 1))
reset(); export("Sandbags_B", bags("Nest", 6.0, 3, 2, shade_every=2, torn=True))
# Low sandbags 5 x 1.6 x 1.4 (what a soldier stacks with V): two rows
reset(); export("LowSandbags", bags("Low", 5.0, 2, 3))
# Burnt truck 7 x 4 x 14 along Y: chassis, cab, bed with ribs, six wheels. A = wreck, B = gutted hulk on rims
def truck(gutted):
    body = []
    body.append(("box", ((6.2, 13.0, 0.8), (0, 0, 1.4), 0)))  # chassis
    body.append(("box", ((6.4, 4.6, 3.2), (0, 4.4, 3.4), 0)))  # cab
    body.append(("box", ((6.0, 1.6, 1.2), (0, 2.1, 2.4), 0)))  # hood step
    if not gutted:
        body.append(("box", ((6.6, 8.0, 0.4), (0, -2.8, 2.0), 0)))  # bed floor
        for side in (-1, 1): body.append(("box", ((0.3, 8.0, 1.6), (side * 3.2, -2.8, 2.9), 0)))
        for k in range(4): body.append(("box", ((6.6, 0.3, 1.8), (0, -6.6 + k * 2.5, 2.9), 0)))  # ribs
    else:
        body.append(("box", ((6.6, 8.0, 0.4), (0, -2.8, 1.9), 0.0)))
        for k in range(3): body.append(("box", ((0.3, 6.0, 1.4), (-3.1 + k * 3.0, -2.6, 2.6), 0.15)))
    parts = [merged("Hull", "Char" if gutted else "Rust", body)]
    parts.append(merged("Grille", "DarkMetal", [("box", ((5.6, 0.3, 2.2), (0, 6.75, 3.2), 0)), ("box", ((5.8, 0.4, 0.5), (0, 6.5, 1.9), 0))]))
    wheels = []
    for y in (4.6, -1.6, -4.2):
        for side in (-1, 1):
            wheels.append(("cyl", (1.3 if not gutted else 0.8, 0.9, (side * 3.3, y, 1.3 if not gutted else 0.8), "X")))
    parts.append(merged("Wheels", "Rubber" if not gutted else "Rust", wheels))
    for p in parts: jitter(p, 0.05, seed=7 if gutted else 5)
    return parts
reset(); export("Truck_A", truck(False))
reset(); export("Truck_B", truck(True))
# Tank trap: three 5-stud I-beams crossed, 4 x 4 x 4
reset()
bm = bmesh.new()
for rot in (Matrix.Identity(4), Matrix.Rotation(math.pi / 2, 4, "Y"), Matrix.Rotation(math.pi / 2, 4, "Z")):
    for s, dz in (((4.6, 0.5, 0.2), 0.35), ((4.6, 0.2, 0.5), 0), ((4.6, 0.5, 0.2), -0.35)):
        M = Matrix.Translation((0, 0, 1.9)) @ Matrix.Rotation(math.radians(35), 4, "Z") @ rot @ Matrix.Translation((0, 0, dz)) @ Matrix.Diagonal((s[0], s[1], s[2], 1))
        bmesh.ops.create_cube(bm, size=1.0, matrix=M)
trap = obj_from_bmesh("Beams", bm, mat("Rust")); jitter(trap, 0.03)
export("Hedgehog", [trap])
# Ammo crate 2 x 1.2 x 1.4 (x, y, height): olive box, wood slats, steel strap
reset()
crate = [merged("Box", "Olive", [("box", ((2.0, 1.2, 1.3), (0, 0, 0.65), 0))]),
         merged("Slats", "OldWood", [("box", ((2.1, 0.12, 1.1), (0, side * 0.6, 0.65), 0)) for side in (-1, 1)]),
         merged("Straps", "Steel", [("box", ((0.25, 1.3, 1.4), (x, 0, 0.7), 0)) for x in (-0.7, 0.7)])]
bevel(crate[0], 0.05, 2); apply_mods(crate[0])
export("AmmoCrate", crate)
print("FRONT DONE")
