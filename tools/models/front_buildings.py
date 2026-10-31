# The Front's staged buildings: two footprints (Farmhouse 18x16x9, Hall 24x20x12), each with the four
# stages Battlefield swaps through (1 intact -> 2 damaged -> 3 ruined -> 4 rubble). Origin at the
# footprint centre on the ground; walls run along X (width) and Y (depth), height is Z.
# Run: blender -b --python front_buildings.py -> out/FrontBld_<Kit>_<stage>.fbx
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
import bmesh
from mathutils import Matrix, Vector

PAL = {"Brick": (0.45, 0.27, 0.20), "SootBrick": (0.22, 0.16, 0.14), "OldWood": (0.30, 0.24, 0.16), "Rubble": (0.38, 0.35, 0.32),
       "Plaster": (0.62, 0.58, 0.50), "Char": (0.09, 0.08, 0.08)}
def mat(n):
    import bpy
    return bpy.data.materials.get(n) or material(n, PAL[n])

def mesh(name, m, pieces, jit=0.0, seed=1):
    """pieces: list of (size, matrix) boxes merged into one object."""
    bm = bmesh.new()
    for size, M in pieces:
        bmesh.ops.create_cube(bm, size=1.0, matrix=M @ Matrix.Diagonal((size[0], size[1], size[2], 1)))
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.001)
    ob = obj_from_bmesh(name, bm, mat(m))
    if jit: jitter(ob, jit, seed)
    return ob

T = lambda x, y, z: Matrix.Translation((x, y, z))
RZ = lambda deg: Matrix.Rotation(math.radians(deg), 4, "Z")

def wall(L, H, t, windows=2, door=False, top=1.0, frac=1.0):
    """Boxes for a wall running along local X (-L/2..L/2), thickness along Y, height 0..H*top.
    `frac` keeps only the left part of the wall (a collapsed remainder)."""
    out = []
    H2 = H * top
    keep = L * frac
    x0 = -L / 2
    def seg(xa, xb, za, zb):
        xb = min(xb, x0 + keep)
        if xb - xa < 0.2 or zb - za < 0.2: return
        out.append(((xb - xa, t, zb - za), T((xa + xb) / 2, 0, (za + zb) / 2)))
    # openings: windows at evenly spaced slots, a door in the middle slot if asked
    slots = windows + (1 if door else 0)
    pitch = L / (slots + 1)
    cursor = x0
    for i in range(slots):
        cx = x0 + pitch * (i + 1)
        is_door = door and i == slots // 2
        ow = 3.0 if is_door else 2.4
        seg(cursor, cx - ow / 2, 0, H2)                        # pier
        if is_door:
            seg(cx - ow / 2, cx + ow / 2, min(6.0, H2 * 0.75), H2)   # lintel over door
        else:
            seg(cx - ow / 2, cx + ow / 2, 0, min(2.5, H2 * 0.3))     # sill
            seg(cx - ow / 2, cx + ow / 2, min(5.2, H2 * 0.7), H2)    # lintel
        cursor = cx + ow / 2
    seg(cursor, L / 2, 0, H2)
    return out

def place(pieces, M):
    return [(s, M @ m) for s, m in pieces]

def sides(W, D):
    return {"front": T(0, -D / 2, 0), "back": T(0, D / 2, 0) @ RZ(180), "left": T(-W / 2, 0, 0) @ RZ(90), "right": T(W / 2, 0, 0) @ RZ(-90)}

def rubble(cx, cy, radius, count, zmax, seed):
    rnd = random.Random(seed)
    out = []
    for _ in range(count):
        a, r = rnd.uniform(0, math.tau), radius * math.sqrt(rnd.random())
        s = (rnd.uniform(0.8, 2.6), rnd.uniform(0.8, 2.2), rnd.uniform(0.5, 1.4))
        z = rnd.uniform(0, zmax) * (1 - r / radius)
        out.append((s, T(cx + r * math.cos(a), cy + r * math.sin(a), z + s[2] / 2) @ RZ(rnd.uniform(0, 90)) @ Matrix.Rotation(rnd.uniform(-0.3, 0.3), 4, "X")))
    return out

def roof(W, D, H, frac=1.0, rafters=True):
    """A shallow gable: two slabs meeting at a ridge along X, rafters under them. frac keeps the -X part."""
    out, wood = [], []
    rise = D * 0.18
    slope = math.atan2(rise, D / 2)
    span = math.hypot(rise, D / 2) + 0.6
    Wk = W * frac
    xc = -W / 2 + Wk / 2
    for side in (-1, 1):
        M = T(xc, side * D / 4, H + rise / 2) @ Matrix.Rotation(-side * slope, 4, "X")
        out.append(((Wk + 1.0, span, 0.5), M))
    if rafters:
        n = max(2, int(Wk / 3))
        for i in range(n):
            x = -W / 2 + (i + 0.5) * (Wk / n)
            wood.append(((0.4, D + 0.4, 0.5), T(x, 0, H - 0.3)))
    return out, wood

def stage(kit, W, D, H, n):
    S = sides(W, D)
    t = 1.0
    brick, soot, wood, rub, plaster = [], [], [], [], []
    if n == 1:
        brick += place(wall(W, H, t, 2, door=True), S["front"])
        brick += place(wall(W, H, t, 2), S["back"])
        brick += place(wall(D, H, t, 1), S["left"])
        brick += place(wall(D, H, t, 1), S["right"])
        r, w = roof(W, D, H)
        wood += r + w
        brick.append(((2.2, 2.2, 3.5), T(W * 0.3, D * 0.2, H + 1.2)))   # chimney
        plaster.append(((W - 2 * t, D - 2 * t, 0.3), T(0, 0, 0.15)))     # floor
    elif n == 2:
        brick += place(wall(W, H, t, 2, door=True), S["front"])
        brick += place(wall(W, H, t, 2, top=0.75, frac=0.6), S["back"])
        brick += place(wall(D, H, t, 1), S["right"])
        soot += place(wall(D, H, t, 1, top=0.55, frac=0.7), S["left"])
        r, w = roof(W, D, H, frac=0.55)
        wood += r + w
        rub += rubble(W * 0.2, D * 0.35, D * 0.3, 14, 1.6, 2)
        rub += rubble(-W * 0.35, -D * 0.1, D * 0.2, 8, 1.2, 3)
        plaster.append(((W - 2 * t, D - 2 * t, 0.3), T(0, 0, 0.15)))
    elif n == 3:
        soot += place(wall(W, H, t, 2, door=True, top=0.5, frac=0.8), S["front"])
        soot += place(wall(D, H, t, 1, top=0.4, frac=0.6), S["right"])
        brick += place(wall(W, H, t, 2, top=0.3, frac=0.35), S["back"])
        wood.append(((W * 0.4, 0.5, 0.4), T(-W * 0.1, D * 0.1, 0.5) @ RZ(25)))   # fallen rafter
        rub += rubble(0, 0, min(W, D) * 0.4, 26, 2.2, 4)
        plaster.append(((W - 2 * t, D - 2 * t, 0.3), T(0, 0, 0.15)))
    else:
        rub += rubble(0, 0, min(W, D) * 0.42, 34, 2.8, 5)
        soot.append(((W * 0.45, 2.2, 1.0), T(-W * 0.15, -D * 0.3, 0.9) @ RZ(12) @ Matrix.Rotation(0.15, 4, "Y")))
        wood.append(((W * 0.35, 0.5, 0.4), T(W * 0.15, D * 0.15, 1.6) @ RZ(-30) @ Matrix.Rotation(-0.2, 4, "Y")))
        plaster.append(((W - 2 * t, D - 2 * t, 0.3), T(0, 0, 0.15)))
    parts = []
    for name, m, pieces, jit in (("Brick", "Brick", brick, 0.03), ("Soot", "SootBrick", soot, 0.05), ("Wood", "OldWood", wood, 0.02), ("Rubble", "Rubble", rub, 0.06), ("Floor", "Plaster", plaster, 0)):
        if pieces: parts.append(mesh(name, m, pieces, jit, seed=n * 7 + len(name)))
    return parts

KITS = {"Farmhouse": (18, 16, 9), "Hall": (24, 20, 12)}
for kit, (W, D, H) in KITS.items():
    for n in range(1, 5):
        reset()
        parts = stage(kit, W, D, H, n)
        export_fbx(os.path.join(OUT, f"FrontBld_{kit}_{n}.fbx"), parts)
        render(os.path.join(OUT, f"FrontBld_{kit}_{n}_preview.png"), parts, azimuth=0.7, elevation=0.45)
        print("BUILT", kit, n)
print("FRONT BUILDINGS DONE")
