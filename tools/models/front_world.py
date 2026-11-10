# The Front's open-world kit (src/war/server/Battlefield.lua, WarWorld): the barrows of calcified clone
# bodies, single calcified bodies, barbed-wire entanglements, a ruined factory chimney, a tall intact
# smokestack for the skyline, a sandbagged dugout entrance (the forward deploy points), an abandoned
# field gun, blasted tree stumps and a broken power pylon.
# Run: blender -b --python front_world.py -> out/FrontWorld_<Name>.fbx (+ previews)
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
import bmesh
from mathutils import Matrix, Vector

# Material names are the part-name suffixes Assets.Materials dresses (Calcified/CalcifiedDark are new).
PAL = {"Calcified": (0.70, 0.67, 0.60), "CalcifiedDark": (0.45, 0.42, 0.38), "Rust": (0.36, 0.20, 0.12),
       "DarkMetal": (0.14, 0.14, 0.16), "Steel": (0.30, 0.31, 0.34), "OldWood": (0.30, 0.24, 0.16),
       "Sandbag": (0.52, 0.46, 0.32), "Brick": (0.42, 0.24, 0.18), "BrickDark": (0.26, 0.16, 0.13),
       "Concrete": (0.45, 0.44, 0.41), "Olive": (0.24, 0.27, 0.16), "DeadBark": (0.27, 0.24, 0.22), "Char": (0.09, 0.08, 0.08),
       "Rubber": (0.06, 0.06, 0.06)}

def mat(n):
    import bpy
    return bpy.data.materials.get(n) or material(n, PAL[n])

def bpy_mesh_from(bm):
    import bpy
    me = bpy.data.meshes.new("tmp")
    bm.to_mesh(me)
    bm.free()
    return me

class Kit:
    """Collects primitive pieces per material, then merges each material into one mesh."""
    def __init__(self, seed=1):
        self.bms = {}
        self.rnd = random.Random(seed)
    def bm(self, m):
        if m not in self.bms: self.bms[m] = bmesh.new()
        return self.bms[m]
    def box(self, m, size, center, rot=(0, 0, 0)):
        R = Matrix.Rotation(rot[2], 4, "Z") @ Matrix.Rotation(rot[1], 4, "Y") @ Matrix.Rotation(rot[0], 4, "X")
        M = Matrix.Translation(Vector(center)) @ R @ Matrix.Diagonal((size[0], size[1], size[2], 1))
        bmesh.ops.create_cube(self.bm(m), size=1.0, matrix=M)
    def rod(self, m, a, b, r, r2=None, seg=8):
        """A cylinder from point a to point b (tapering to r2)."""
        a, b = Vector(a), Vector(b)
        d = b - a
        length = d.length
        if length < 1e-4: return
        q = Vector((0, 0, 1)).rotation_difference(d.normalized())
        M = Matrix.Translation((a + b) / 2) @ q.to_matrix().to_4x4()
        bmesh.ops.create_cone(self.bm(m), cap_ends=True, segments=seg, radius1=r, radius2=r2 if r2 is not None else r, depth=length, matrix=M)
    def ball(self, m, center, r, scale=(1, 1, 1), seg=10, rings=7):
        M = Matrix.Translation(Vector(center)) @ Matrix.Diagonal((scale[0], scale[1], scale[2], 1))
        bmesh.ops.create_uvsphere(self.bm(m), u_segments=seg, v_segments=rings, radius=r, matrix=M)
    def dome(self, m, center, r, scale=(1, 1, 1), seg=20, rings=10):
        """The upper half of a squashed sphere (flat base at center z)."""
        bm = bmesh.new()
        M = Matrix.Translation(Vector(center)) @ Matrix.Diagonal((scale[0], scale[1], scale[2], 1))
        bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=r, matrix=M)
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < center[2] - 0.01], context="VERTS")
        tmp = bpy_mesh_from(bm)
        self.bm(m).from_mesh(tmp)
    def limb(self, m, a, b, r):
        """A rounded limb: a rod with ball joints, the calcified bodies are built from these."""
        self.rod(m, a, b, r, r * 0.85, seg=8)
        self.ball(m, a, r, seg=8, rings=5)
        self.ball(m, b, r * 0.85, seg=8, rings=5)
    def build(self, name, jit=0.0, bev=None):
        parts = []
        for m, bm in self.bms.items():
            bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.001)
            ob = obj_from_bmesh(f"{name}{m}", bm, mat(m))
            if jit: jitter(ob, jit, seed=self.rnd.randint(1, 999))
            parts.append(ob)
        return parts

def export(name, parts, az=0.9, el=0.5):
    export_fbx(os.path.join(OUT, f"FrontWorld_{name}.fbx"), parts)
    render(os.path.join(OUT, f"FrontWorld_{name}_preview.png"), parts, azimuth=az, elevation=el)
    print("BUILT", name)

# ---------- a calcified clone body (the pieces barrows are made of) ----------
def body(k, origin, yaw, pose, m="Calcified", scale=1.0, sink=0.0):
    """pose: 'prone' (face down, arms forward), 'curled', 'reach' (kneeling, one arm up), 'sprawl'."""
    ox, oy, oz = origin
    cy, sy = math.cos(yaw), math.sin(yaw)
    def P(x, y, z):
        x, y, z = x * scale, y * scale, z * scale - sink
        return (ox + x * cy - y * sy, oy + x * sy + y * cy, oz + z)
    r = 0.32 * scale
    if pose == "prone":
        k.limb(m, P(0, -0.9, 0.45), P(0, 0.9, 0.5), r * 1.6)          # torso
        k.ball(m, P(0, 1.55, 0.5), 0.42 * scale, (1, 1.1, 0.95))       # head
        k.limb(m, P(-0.45, 0.8, 0.4), P(-0.7, 2.4, 0.3), r)            # arms forward
        k.limb(m, P(0.45, 0.8, 0.4), P(0.9, 2.2, 0.3), r)
        k.limb(m, P(-0.3, -0.9, 0.35), P(-0.5, -2.7, 0.3), r * 1.1)    # legs
        k.limb(m, P(0.3, -0.9, 0.35), P(0.6, -2.6, 0.3), r * 1.1)
    elif pose == "curled":
        k.limb(m, P(0, -0.6, 0.6), P(0, 0.7, 0.7), r * 1.7)
        k.ball(m, P(0, 1.3, 0.55), 0.42 * scale)
        k.limb(m, P(-0.3, -0.6, 0.5), P(-0.4, 0.4, 0.3), r * 1.1)      # knees drawn up
        k.limb(m, P(-0.4, 0.4, 0.3), P(-0.4, -0.6, 0.1), r)
        k.limb(m, P(0.3, 0.6, 0.6), P(0.5, 1.2, 0.9), r)                # arm over the head
    elif pose == "reach":
        k.limb(m, P(0, 0, 0.3), P(0, 0.2, 1.8), r * 1.6)                # kneeling torso
        k.ball(m, P(0, 0.35, 2.45), 0.42 * scale)
        k.limb(m, P(0.45, 0.2, 1.7), P(0.75, 1.3, 2.6), r * 0.8)        # upper arm reaching forward
        k.limb(m, P(0.75, 1.3, 2.6), P(0.9, 2.2, 3.0), r * 0.7)         # forearm
        k.box(m, (0.45, 0.5, 0.14), P(0.95, 2.55, 3.1), (0.3, 0, yaw))  # open hand
        for f in (-0.15, 0, 0.15):
            k.rod(m, P(0.95 + f, 2.7, 3.12), P(0.97 + f * 1.4, 3.05, 3.2), 0.06 * scale, seg=4)
        k.limb(m, P(-0.45, 0.2, 1.6), P(-0.7, 0.9, 0.6), r)
        k.limb(m, P(-0.3, 0, 0.3), P(-0.4, 1.2, 0.0), r * 1.1)
        k.limb(m, P(0.3, 0, 0.3), P(0.4, -1.0, 0.0), r * 1.1)
    else:  # sprawl, on the back
        k.limb(m, P(0, -0.9, 0.4), P(0, 0.9, 0.45), r * 1.6)
        k.ball(m, P(0, 1.5, 0.6), 0.42 * scale)
        k.limb(m, P(-0.5, 0.8, 0.4), P(-2.0, 1.4, 0.35), r)
        k.limb(m, P(0.5, 0.8, 0.4), P(1.7, 0.2, 0.35), r)
        k.limb(m, P(-0.3, -0.9, 0.35), P(-1.0, -2.6, 0.3), r * 1.1)
        k.limb(m, P(0.3, -0.9, 0.35), P(0.5, -2.7, 0.3), r * 1.1)
    # the helmet stays on: a dome over the head, darker
    hx, hy, hz = P(0, 1.55 if pose in ("prone", "sprawl") else (1.3 if pose == "curled" else 0.35), 0.75 if pose != "reach" else 2.7)
    k.ball("CalcifiedDark", (hx, hy, hz), 0.5 * scale, (1, 1, 0.6), seg=10, rings=5)

POSES = ["prone", "curled", "reach", "sprawl"]

# Calcified_A: one fallen clone, prone, ~6 long. Calcified_B: kneeling with an arm raised, ~3.5 tall.
reset(); k = Kit(3); body(k, (0, 0, 0), 0, "prone"); k.rod("Rust", (1.4, 1.6, 0.3), (2.4, -1.4, 0.25), 0.09); export("Calcified_A", k.build("Body", 0.03))
reset(); k = Kit(4); body(k, (0, 0, 0), 0, "reach"); export("Calcified_B", k.build("Body", 0.03))

# Barrows: a mound fused out of dozens of bodies, the calcite filling the gaps. A ~ 18 x 18 x 6, B ~ 26 x 14 x 5 (a ridge piece).
def barrow(seed, rx, ry, height, n):
    k = Kit(seed)
    rnd = k.rnd
    k.dome("CalcifiedDark", (0, 0, 0), 1.0, (rx, ry, height), seg=22, rings=12)  # the fused core
    for i in range(5):  # lumps: older bodies under the newer ones
        a = rnd.uniform(0, math.tau); t = rnd.uniform(0.2, 0.7)
        k.dome("Calcified", (math.cos(a) * rx * t, math.sin(a) * ry * t, -0.2), 1.0, (rx * 0.35, ry * 0.35, height * rnd.uniform(0.5, 0.8)), seg=12, rings=6)
    for i in range(n):
        a = rnd.uniform(0, math.tau)
        t = math.sqrt(rnd.uniform(0.05, 1.0))
        x, y = math.cos(a) * rx * t * 0.95, math.sin(a) * ry * t * 0.95
        z = height * math.sqrt(max(0.0, 1 - t * t)) - 0.4
        body(k, (x, y, z), rnd.uniform(0, math.tau), rnd.choice(POSES), scale=rnd.uniform(0.85, 1.1), sink=rnd.uniform(0.2, 0.7))
    for i in range(n // 5):  # rifles and stakes sticking out of it
        a = rnd.uniform(0, math.tau); t = rnd.uniform(0.2, 0.8)
        x, y = math.cos(a) * rx * t, math.sin(a) * ry * t
        z = height * math.sqrt(max(0.0, 1 - t * t))
        k.rod("Rust", (x, y, z - 0.5), (x + rnd.uniform(-1, 1), y + rnd.uniform(-1, 1), z + rnd.uniform(1.5, 2.8)), 0.08)
    return k.build("Barrow", 0.05)
reset(); export("Barrow_A", barrow(11, 9, 9, 6, 44))
reset(); export("Barrow_B", barrow(12, 13, 7, 5, 50), az=0.5)

# Barbed-wire entanglement, 10 long: iron screw pickets and a sagging coil between them.
def wire(seed):
    k = Kit(seed)
    rnd = k.rnd
    for x in (-4.6, -1.5, 1.6, 4.6):
        lean = rnd.uniform(-0.15, 0.15)
        k.rod("Rust", (x, 0, 0), (x + lean, lean * 0.5, 3.0), 0.07, 0.05, seg=6)
        k.box("Rust", (0.05, 0.6, 0.05), (x + lean, lean * 0.5, 2.6))
    # the coil: a helix of short straight segments, slack in places
    prev = None
    turns, radius = 22, 0.9
    steps = turns * 8
    for s in range(steps + 1):
        t = s / steps
        ang = t * turns * math.tau
        x = -5 + 10 * t
        sag = 0.25 * math.sin(t * math.pi * 3) + rnd.uniform(-0.05, 0.05)
        p = (x, math.cos(ang) * radius, 1.05 + math.sin(ang) * radius - sag)
        if prev: k.rod("DarkMetal", prev, p, 0.03, seg=4)
        prev = p
    # two straight strands at the top
    for z in (2.2, 2.8):
        k.rod("DarkMetal", (-4.6, 0, z), (4.6, 0, z - 0.1), 0.03, seg=4)
    return k.build("Wire")
reset(); export("Wire", wire(21))

# Ruined factory chimney: square brick stack, 8 x 8 base, broken off at ~26 with a jagged top.
def chimney(seed, h, broken):
    k = Kit(seed)
    rnd = k.rnd
    k.box("Concrete", (9, 9, 1.6), (0, 0, 0.8))
    rows = int(h / 1.0)
    for i in range(rows):
        z = 1.6 + i + 0.5
        w = 7.2 - i * (2.4 / rows)
        if broken and i > rows - 6:
            # jagged: wall chunks missing near the top
            for side in range(4):
                if rnd.random() < 0.35 + (i - (rows - 6)) * 0.1: continue
                a = side * math.pi / 2
                cx, cy = math.cos(a) * (w / 2 - 0.4), math.sin(a) * (w / 2 - 0.4)
                k.box("Brick" if i % 3 else "BrickDark", (0.8 if side % 2 == 0 else w, w if side % 2 == 0 else 0.8, 1.0), (cx, cy, z))
        else:
            for side in range(4):
                a = side * math.pi / 2
                cx, cy = math.cos(a) * (w / 2 - 0.4), math.sin(a) * (w / 2 - 0.4)
                k.box("BrickDark" if i % 7 == 0 else "Brick", (0.8 if side % 2 == 0 else w, w if side % 2 == 0 else 0.8, 1.0), (cx, cy, z))
    if not broken:
        for z in (h * 0.5, h * 0.8, h + 1.0):  # steel bands and a lip
            w = 7.2 - (z / h) * 2.4 + 0.4
            k.box("Rust", (w, w, 0.5), (0, 0, z))
    return k.build("Stack")
reset(); export("Chimney", chimney(31, 26, True), el=0.25)
reset(); export("Smokestack", chimney(32, 40, False), el=0.25)

# Dugout entrance: sandbag walls, a timber frame and a log roof over a dark doorway going down. 10 x 8 x 4.5.
def dugout(seed):
    k = Kit(seed)
    rnd = k.rnd
    for side in (-1, 1):
        for row in range(4):
            for i in range(5):
                k.box("Sandbag", (1.3, 0.75, 0.6), (side * (2.6 + (row % 2) * 0.1), -3.2 + i * 1.35 + (row % 2) * 0.5, 0.3 + row * 0.6), (0, 0, rnd.uniform(-0.1, 0.1)))
    for row in range(3):  # back wall
        for i in range(5):
            k.box("Sandbag", (1.3, 0.75, 0.6), (-2.4 + i * 1.2, 3.4, 0.3 + row * 0.6), (0, 0, math.pi / 2 + rnd.uniform(-0.1, 0.1)))
    for x in (-1.6, 1.6):  # door frame
        k.box("OldWood", (0.4, 0.4, 2.6), (x, -3.4, 1.3))
    k.box("OldWood", (3.8, 0.45, 0.4), (0, -3.4, 2.65))
    for i in range(8):  # log roof
        k.rod("OldWood", (-3.4, -3.6 + i * 0.95, 2.6 + rnd.uniform(-0.05, 0.05)), (3.4, -3.6 + i * 0.95, 2.6), 0.24, seg=7)
    k.box("Steel", (6.5, 7.5, 0.1), (0, -0.2, 2.95), (0.03, 0, 0))  # corrugated sheet on top
    for i in range(10):
        k.box("Sandbag", (1.3, 0.75, 0.55), (rnd.uniform(-2.6, 2.6), rnd.uniform(-2.8, 3.0), 3.2), (0, 0, rnd.uniform(0, math.pi)))
    k.box("Char", (2.8, 0.2, 2.4), (0, -3.0, 1.2))  # the doorway (dark, going down)
    k.box("Char", (2.8, 5.6, 0.2), (0, 0, 0.05), (-0.25, 0, 0))  # stairs going down
    return k.build("Dugout", 0.02)
reset(); export("Dugout", dugout(41), az=-2.3)

# Abandoned field gun (static wreck): split trail, two spoked wheels, shield, barrel pointing up. ~6 x 8 x 3.5.
def fieldgun(seed):
    k = Kit(seed)
    k.box("Olive", (3.2, 0.25, 2.0), (0, 1.2, 1.7), (0.15, 0, 0))   # shield
    k.box("Olive", (1.2, 1.6, 0.8), (0, 0.4, 1.4))                    # cradle
    k.rod("DarkMetal", (0, 0.4, 1.5), (0, 4.8, 2.9), 0.22, 0.16, seg=10)  # barrel
    k.rod("DarkMetal", (0, 4.6, 2.85), (0, 5.0, 2.97), 0.28, 0.28, seg=10)
    for side in (-1, 1):
        k.rod("Olive", (side * 0.4, 0.2, 1.0), (side * 1.4, -4.2, 0.2), 0.16, seg=6)  # trails
        k.box("Olive", (0.6, 0.4, 0.2), (side * 1.45, -4.3, 0.12))
        k.rod("Rubber", (side * 1.45, 0.4, 1.0), (side * 1.75, 0.4, 1.0), 1.0, seg=14)  # wheel rim
        k.rod("Rust", (side * 1.5, 0.4, 1.0), (side * 1.7, 0.4, 1.0), 0.22, seg=8)
        for s in range(6):
            a = s * math.pi / 3
            k.rod("OldWood", (side * 1.6, 0.4, 1.0), (side * 1.6, 0.4 + math.cos(a) * 0.9, 1.0 + math.sin(a) * 0.9), 0.06, seg=4)
    k.rod("Rust", (-1.6, 0.4, 1.0), (1.6, 0.4, 1.0), 0.12, seg=6)
    return k.build("Gun", 0.02)
reset(); export("FieldGun", fieldgun(51))

# Blasted stumps: a splintered trunk 1.6 wide, A ~3.5 tall, B ~7 tall with one broken bough.
def stump(seed, h):
    k = Kit(seed)
    rnd = k.rnd
    k.rod("DeadBark", (0, 0, -0.3), (0, 0, h * 0.7), 0.8, 0.6, seg=9)
    for i in range(7):  # splinters around the break
        a = i * math.tau / 7 + rnd.uniform(-0.2, 0.2)
        k.rod("DeadBark", (math.cos(a) * 0.45, math.sin(a) * 0.45, h * 0.65), (math.cos(a) * 0.6, math.sin(a) * 0.6, h * rnd.uniform(0.75, 1.0)), 0.16, 0.02, seg=4)
    for i in range(4):  # roots
        a = i * math.tau / 4 + 0.4
        k.rod("DeadBark", (0, 0, 0.4), (math.cos(a) * 1.8, math.sin(a) * 1.8, -0.2), 0.35, 0.12, seg=6)
    if h > 5:
        k.rod("DeadBark", (0, 0, h * 0.5), (1.8, 0.4, h * 0.75), 0.22, 0.08, seg=6)
    k.rod("Char", (0, 0, h * 0.69), (0, 0, h * 0.72), 0.62, seg=9)
    return k.build("Stump", 0.03)
reset(); export("Stump_A", stump(61, 3.5))
reset(); export("Stump_B", stump(62, 7.0))

# Broken power pylon: a lattice tower 30 tall, one leg sheared, leaning; the planet's grid, dead.
def pylon(seed):
    k = Kit(seed)
    h = 30.0
    def leg(x, y, z):  # taper toward the top
        f = 1 - z / h * 0.75
        return (x * f, y * f, z)
    corners = [(-3, -3), (3, -3), (3, 3), (-3, 3)]
    levels = [0, 6, 12, 18, 24, 30]
    for i in range(len(levels) - 1):
        z0, z1 = levels[i], levels[i + 1]
        for c in range(4):
            a, b = corners[c], corners[(c + 1) % 4]
            if i == 0 and c == 1: continue  # the sheared leg's bracing is gone
            k.rod("Rust", leg(a[0], a[1], z0), leg(a[0], a[1], z1), 0.15, seg=5)
            k.rod("Steel", leg(a[0], a[1], z0), leg(b[0], b[1], z1), 0.07, seg=4)
            k.rod("Steel", leg(b[0], b[1], z0), leg(a[0], a[1], z1), 0.07, seg=4)
            k.rod("Steel", leg(a[0], a[1], z1), leg(b[0], b[1], z1), 0.07, seg=4)
    for z, w in ((20, 9), (26, 7)):  # cross arms with dangling insulators
        k.box("Rust", (w * 2, 0.3, 0.3), (0, 0, z))
        for x in (-w + 0.5, w - 0.5):
            k.rod("DarkMetal", (x, 0, z), (x, 0, z - 1.4), 0.12, seg=5)
    return k.build("Pylon")
reset(); export("Pylon", pylon(71), el=0.2)
print("FRONT WORLD DONE")
