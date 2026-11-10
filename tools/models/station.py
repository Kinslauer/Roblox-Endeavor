# The arrival: the Whisper (suppressed pistol with a separate slide), the rider's cloak, the Line 9 train car
# shell and the Sentry rig. Run: blender -b --python station.py -> out/Wpn_Whisper.fbx, Intro_Cloak.fbx,
# Subway_Car.fbx, Rig_Sentry.fbx
#
# Axes: Roblox X = -Blender X, Roblox Y = Blender Z, Roblox Z = Blender Y (the FBX import mirrors X).
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
import bmesh
from mathutils import Matrix, Vector

PAL = {
    "Steel": (0.30, 0.31, 0.34), "DarkMetal": (0.14, 0.14, 0.16), "Grip": (0.12, 0.11, 0.10), "Rust": (0.36, 0.20, 0.12),
    "Cloth": (0.20, 0.19, 0.18), "Coat": (0.13, 0.12, 0.15), "Chrome": (0.55, 0.57, 0.62), "Strap": (0.12, 0.11, 0.10),
    "Plate": (0.28, 0.30, 0.33), "Glass": (0.47, 0.67, 0.80), "Paint": (0.55, 0.16, 0.14), "SignWhite": (0.85, 0.85, 0.8),
    "Screen": (0.05, 0.31, 0.45), "Tyre": (0.09, 0.09, 0.09), "Jacket": (0.24, 0.20, 0.17), "Boot": (0.10, 0.09, 0.09),
    "Goggle": (1.0, 0.45, 0.15), "Hood": (0.16, 0.15, 0.17), "Housing": (0.18, 0.18, 0.2),
}
T = lambda x, y, z: Matrix.Translation((x, y, z))
RX = lambda d: Matrix.Rotation(math.radians(d), 4, "X")
RY = lambda d: Matrix.Rotation(math.radians(d), 4, "Y")

def mat(n):
    import bpy
    return bpy.data.materials.get(n) or material(n, PAL[n])

def mesh(name, m, boxes=(), cyls=(), fn=None, bev=0.0):
    """boxes: (size, matrix); cyls: (r1, r2, depth, matrix, segments) along local Z; fn(bm) adds anything else."""
    bm = bmesh.new()
    for size, M in boxes:
        bmesh.ops.create_cube(bm, size=1.0, matrix=M @ Matrix.Diagonal((size[0], size[1], size[2], 1)))
    for r1, r2, depth, M, seg in cyls:
        bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r1, radius2=r2, depth=depth, matrix=M)
    if fn:
        fn(bm)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
    ob = obj_from_bmesh(name, bm, mat(m))
    if bev:
        bevel(ob, bev, 2)
        apply_mods(ob)
    return ob

def export(file, parts, az=0.9, el=0.4):
    export_fbx(os.path.join(OUT, f"{file}.fbx"), parts)
    render(os.path.join(OUT, f"{file}_preview.png"), parts, azimuth=az, elevation=el)
    print("BUILT", file, len(parts), "parts")

# ---------- Whisper: grip at the origin running down -Y, barrel along +Z, top of the gun at +Y ----------
reset()
export("Wpn_Whisper", [
    mesh("Grip", "Grip", [((0.27, 0.95, 0.42), T(0, -0.18, -0.06) @ RX(12))], bev=0.04),
    mesh("Frame", "DarkMetal", [((0.29, 0.26, 1.35), T(0, 0.42, 0.5)), ((0.08, 0.3, 0.06), T(0, 0.18, 0.62)), ((0.08, 0.06, 0.42), T(0, 0.05, 0.43))], bev=0.02),
    mesh("Slide", "Steel", [((0.31, 0.3, 1.5), T(0, 0.7, 0.48)), ((0.06, 0.07, 0.1), T(0, 0.88, -0.18)), ((0.05, 0.07, 0.06), T(0, 0.88, 1.15))], bev=0.03),
    mesh("Barrel", "DarkMetal", cyls=[(0.07, 0.07, 0.3, T(0, 0.7, 1.33), 10)]),
    mesh("Can", "Housing", cyls=[(0.15, 0.15, 1.15, T(0, 0.7, 2.0), 12), (0.16, 0.16, 0.08, T(0, 0.7, 1.5), 12), (0.16, 0.16, 0.08, T(0, 0.7, 2.5), 12)]),
    mesh("Trigger", "Steel", [((0.06, 0.2, 0.05), T(0, 0.17, 0.42))]),
], az=0.3, el=0.2)

# ---------- the cloak: origin at the Conduit's UpperTorso centre (neck at z +0.75), forward is -Y ----------
reset()
def shroud(z0, z1, r0, r1, seg=28, fold=0.07, seed=3, front_lift=0.0):
    """An open elliptical tube from (z0, radii r0) up to (z1, radii r1) with soft folds, faces on both sides."""
    def build(bm):
        rnd = random.Random(seed)
        rings = 6
        grid = []
        for k in range(rings + 1):
            u = k / rings
            z = z0 + (z1 - z0) * u
            ring = []
            for i in range(seg):
                a = 2 * math.pi * i / seg
                wave = (1 - u) * fold * (1 if i % 2 == 0 else -1) + (1 - u) * rnd.uniform(-0.03, 0.03)
                rx = r0[0] + (r1[0] - r0[0]) * u + wave
                ry = r0[1] + (r1[1] - r0[1]) * u + wave
                lift = front_lift * (1 - u) * max(0.0, -math.sin(a))  # shorter at the front (-Y)
                ring.append(bm.verts.new((rx * math.cos(a), ry * math.sin(a), z + lift)))
            grid.append(ring)
        for k in range(rings):
            for i in range(seg):
                j = (i + 1) % seg
                a, b, c, d = grid[k][i], grid[k][j], grid[k + 1][j], grid[k + 1][i]
                bm.faces.new((a, b, c, d))
        # the inside, a little smaller, so the cloak is not see-through from below
        inner = []
        for ring in grid:
            inner.append([bm.verts.new((v.co.x * 0.97, v.co.y * 0.97, v.co.z)) for v in ring])
        for k in range(rings):
            for i in range(seg):
                j = (i + 1) % seg
                bm.faces.new((inner[k][j], inner[k][i], inner[k + 1][i], inner[k + 1][j]))
    return build
export("Intro_Cloak", [
    mesh("Shroud", "Cloth", fn=shroud(-2.55, 0.5, (2.05, 1.25), (1.72, 0.82), front_lift=0.5)),
    mesh("Mantle", "Coat", fn=shroud(0.05, 0.95, (1.95, 1.0), (0.62, 0.6), seg=28, fold=0.04, seed=5)),
    mesh("Hem", "Strap", fn=shroud(-2.6, -2.42, (2.08, 1.28), (2.05, 1.25), fold=0.07, seed=3, front_lift=0.5)),
    mesh("Clasp", "Chrome", [((0.34, 0.1, 0.2), T(0, -0.86, 0.42))], cyls=[(0.1, 0.1, 0.08, T(-0.3, -0.84, 0.44) @ RX(90), 8), (0.1, 0.1, 0.08, T(0.3, -0.84, 0.44) @ RX(90), 8)]),
], az=-1.0, el=0.25)

# ---------- the train car: floor top at z 0, 9 wide (x), 56 long (y), roof to 9.2, wheels down to -3.4 ----------
reset()
HALF, LEN = 4.5, 28.0
def arch(y0, y1, inner=False):
    """The roof: a shallow arch from wall top (z 8.0) to the crown (z 9.2), swept along Y."""
    def build(bm):
        n = 8
        pts = []
        for i in range(n + 1):
            a = math.pi * i / n
            pts.append((HALF * math.cos(a), 8.0 + 1.2 * math.sin(a)))
        lo = [(x * 0.93, z - 0.28) for x, z in pts]
        for i in range(n):
            (x0, z0), (x1, z1) = pts[i], pts[i + 1]
            (a0, b0), (a1, b1) = lo[i], lo[i + 1]
            v = [bm.verts.new(p) for p in ((x0, y0, z0), (x1, y0, z1), (x1, y1, z1), (x0, y1, z0))]
            bm.faces.new(v)                                    # outside
            w = [bm.verts.new(p) for p in ((a0, y1, b0), (a1, y1, b1), (a1, y0, b1), (a0, y0, b0))]
            bm.faces.new(w)                                    # ceiling
        for y, flip in ((y0, False), (y1, True)):               # end caps
            ring = [bm.verts.new((x, y, z)) for x, z in pts] + [bm.verts.new((x, y, z)) for x, z in reversed(lo)]
            bm.faces.new(ring if flip else list(reversed(ring)))
    return build

walls, glass, trim, posts, seats, rails, under, wheels, stripe, signs, screens = [], [], [], [], [], [], [], [], [], [], []
for sx in (-1, 1):
    x = sx * (HALF - 0.15)
    for y0, y1 in ((-LEN, -4.0), (4.0, LEN)):                   # the door bay (y -4..4) is open on both sides
        mid, ln = (y0 + y1) / 2, y1 - y0
        walls.append(((0.3, ln, 3.4), T(x, mid, 1.7)))           # lower panel
        walls.append(((0.3, ln, 1.4), T(x, mid, 7.3)))           # band over the windows
        stripe.append(((0.34, ln, 0.35), T(x, mid, 2.9)))
        glass.append(((0.08, ln, 3.2), T(x, mid, 5.0)))
        k = 0
        y = y0
        while y <= y1 + 0.01:                                    # window posts
            posts.append(((0.36, 0.5, 3.2), T(x, y + (0.25 if y == y0 else -0.25 if y > y1 - 0.01 else 0), 5.0)))
            y += 4.0
            k += 1
        signs.append(((0.06, ln - 3, 0.7), T(sx * (HALF - 0.34), mid, 7.3)))  # advert strip inside
    walls.append(((0.3, 8.0, 0.6), T(x, 0, 7.7)))                # door head
    trim.append(((0.4, 0.3, 7.5), T(x, -4.15, 3.75)))            # door frames
    trim.append(((0.4, 0.3, 7.5), T(x, 4.15, 3.75)))
    for y0, y1 in ((-24.0, -7.0), (7.0, 24.0)):                  # benches: seat top at 1.2
        mid, ln = (y0 + y1) / 2, y1 - y0
        bx = sx * (HALF - 1.05)
        seats.append(((1.5, ln, 0.35), T(bx, mid, 1.03)))
        seats.append(((0.3, ln, 1.5), T(sx * (HALF - 0.45), mid, 2.0) @ RY(sx * -8)))
        under.append(((1.3, ln - 0.6, 0.85), T(bx - sx * 0.05, mid, 0.43)))
        for ye in (y0, y1):                                      # bench end screens and their poles
            trim.append(((1.6, 0.12, 2.6), T(bx, ye, 1.9)))
            rails.append((0.09, 0.09, 7.9, T(sx * (HALF - 1.85), ye, 3.95), 8))
    rails.append((0.07, 0.07, 46.0, T(sx * 2.3, 0, 7.0) @ RX(90), 8))  # overhead handrail
    for y in range(-22, 23, 2):                                  # hanging loops
        if abs(y) > 5:
            posts.append(((0.06, 0.25, 0.9), T(sx * 2.3, y, 6.5)))
    under.append(((0.5, 50.0, 1.0), T(sx * 4.1, 0, -1.1)))       # skirt
for sy in (-1, 1):
    y = sy * (LEN - 0.2)
    for sx in (-1, 1):
        walls.append(((3.0, 0.4, 8.2), T(sx * 3.0, y, 4.1)))     # end wall either side of the gangway door
    walls.append(((3.0, 0.4, 1.2), T(0, y, 7.6)))
    trim.append(((3.0, 0.3, 7.0), T(0, y, 3.5)))                 # the gangway door
    glass.append(((1.6, 0.34, 2.4), T(0, y, 5.0)))
    screens.append(((4.4, 0.1, 0.6), T(0, sy * (LEN - 0.45), 7.75)))  # the line display
    under.append(((7.0, 9.0, 1.3), T(0, sy * 18.0, -2.0)))       # bogies
    for wy in (-3.0, 3.0):
        for sx in (-1, 1):
            wheels.append((0.95, 0.95, 0.5, T(sx * 2.5, sy * 18.0 + wy, -2.45) @ RY(90), 14))
    under.append(((1.2, 1.6, 0.9), T(0, sy * (LEN + 0.5), -1.0)))  # couplers
under.append(((8.6, 55.0, 0.5), T(0, 0, -0.85)))
under.append(((3.0, 12.0, 1.4), T(0, 0, -1.8)))                  # equipment box
export("Subway_Car", [
    mesh("Walls", "Steel", walls),
    mesh("Roof", "Steel", fn=arch(-LEN, LEN)),
    mesh("RoofVents", "DarkMetal", [((2.0, 5.0, 0.4), T(0, y, 9.3)) for y in (-18, 0, 18)]),
    mesh("Floor", "Plate", [((8.7, 55.6, 0.3), T(0, 0, -0.15))]),
    mesh("Stripe", "Paint", stripe),
    mesh("Windows", "Glass", glass),
    mesh("Posts", "DarkMetal", posts),
    mesh("Trim", "DarkMetal", trim),
    mesh("Seats", "Jacket", seats, bev=0.06),
    mesh("SeatBase", "Housing", [b for b in under[:0]] + [u for u in under if u[0][2] == 0.85]),
    mesh("Rails", "Chrome", cyls=rails),
    mesh("Under", "DarkMetal", [u for u in under if u[0][2] != 0.85]),
    mesh("Wheels", "Rust", cyls=wheels),
    mesh("Adverts", "SignWhite", signs),
    mesh("Display", "Screen", screens),
], az=0.55, el=0.3)

# ---------- the Sentry: transit security. R15 limb meshes like the other rigs (left limbs at -X, feet on z 0) ----------
reset()
def limb(name, m, boxes, cyls=(), bev=0.06):
    return mesh(name, m, [(s, T(*c)) for s, c in boxes], [(r, r, d, T(*c) @ (RY(90) if ax == "X" else RX(90) if ax == "Y" else Matrix.Identity(4)), 10) for r, d, c, ax in cyls], bev=bev)
L = dict(foot=0.45, lowerleg=1.05, upperleg=1.1, lowertorso=0.75, uppertorso=1.6, head=1.2, upperarm=1.05, lowerarm=1.0, hand=0.45)
W = dict(torso=2.0, depth=1.05, head=1.15, arm=0.66, leg=0.8)
z_hip = L["foot"] + L["lowerleg"] + L["upperleg"]; z_waist = z_hip + L["lowertorso"]; z_neck = z_waist + L["uppertorso"]
F = -1
parts = [
    limb("LowerTorso", "Coat", [((W["torso"] * 0.92, W["depth"], L["lowertorso"]), (0, 0, z_hip + L["lowertorso"] / 2))]),
    limb("UpperTorso", "Coat", [((W["torso"], W["depth"] * 1.05, L["uppertorso"]), (0, 0, z_waist + L["uppertorso"] / 2))]),
    limb("Head", "Hood", [((W["head"] * 0.9, W["head"] * 0.95, L["head"] * 0.9), (0, 0, z_neck + L["head"] * 0.45))], bev=0.2),
]
for side, s in (("Left", -1), ("Right", 1)):
    x = s * (W["torso"] / 2 + W["arm"] / 2 + 0.08)
    z_sh = z_neck - 0.2; z_el = z_sh - L["upperarm"]; z_wr = z_el - L["lowerarm"]
    lx = s * W["leg"] * 0.62
    z_kn = z_hip - L["upperleg"]
    parts += [
        limb(f"{side}UpperArm", "Coat", [((W["arm"], W["arm"], L["upperarm"]), (x, 0, z_sh - L["upperarm"] / 2))]),
        limb(f"{side}LowerArm", "Coat", [((W["arm"] * 0.9, W["arm"] * 0.9, L["lowerarm"]), (x, 0, z_el - L["lowerarm"] / 2))]),
        limb(f"{side}Hand", "Grip", [((W["arm"] * 0.8, W["arm"] * 0.62, L["hand"]), (x, 0, z_wr - L["hand"] / 2))]),
        limb(f"{side}UpperLeg", "Cloth", [((W["leg"], W["leg"] * 1.05, L["upperleg"]), (lx, 0, z_hip - L["upperleg"] / 2))]),
        limb(f"{side}LowerLeg", "Cloth", [((W["leg"] * 0.9, W["leg"] * 0.95, L["lowerleg"]), (lx, 0, z_kn - L["lowerleg"] / 2))]),
        limb(f"{side}Foot", "Boot", [((W["leg"], W["leg"] * 1.55, L["foot"]), (lx, F * 0.15, L["foot"] / 2))]),
        limb(f"{side}UpperArmPauldron", "Plate", [((W["arm"] * 1.25, W["arm"] * 1.3, 0.5), (x + s * 0.05, 0, z_sh - 0.2))], bev=0.1),
        limb(f"{side}LowerArmBracer", "Plate", [((W["arm"] * 1.05, W["arm"] * 1.05, 0.6), (x, 0, z_el - 0.55))]),
        limb(f"{side}LowerLegGuard", "Plate", [((W["leg"] * 0.8, 0.2, 0.8), (lx, F * W["leg"] * 0.5, z_kn - 0.5)), ((W["leg"] * 0.7, 0.3, 0.3), (lx, F * W["leg"] * 0.55, z_kn + 0.02))]),
    ]
parts += [
    limb("UpperTorsoVest", "Plate", [((W["torso"] * 0.92, 0.22, 1.25), (0, F * W["depth"] * 0.56, z_waist + 0.85)), ((W["torso"] * 0.92, 0.22, 1.3), (0, W["depth"] * 0.56, z_waist + 0.85)),
                                      ((0.3, W["depth"] * 1.2, 0.2), (-0.62, 0, z_neck - 0.02)), ((0.3, W["depth"] * 1.2, 0.2), (0.62, 0, z_neck - 0.02))], bev=0.07),
    limb("UpperTorsoPouches", "Strap", [((0.4, 0.22, 0.45), (-0.5, F * W["depth"] * 0.68, z_waist + 0.45)), ((0.4, 0.22, 0.45), (0.0, F * W["depth"] * 0.68, z_waist + 0.45)), ((0.4, 0.22, 0.45), (0.5, F * W["depth"] * 0.68, z_waist + 0.45))]),
    limb("UpperTorsoBadge", "SignWhite", [((0.5, 0.05, 0.16), (0.4, F * W["depth"] * 0.68, z_waist + 1.25))], bev=0),
    limb("UpperTorsoRadio", "Housing", [((0.3, 0.25, 0.6), (-0.7, F * W["depth"] * 0.62, z_neck - 0.35))], [(0.03, 0.6, (-0.78, F * W["depth"] * 0.62, z_neck + 0.2), "Z")]),
    limb("LowerTorsoBelt", "Strap", [((W["torso"] * 0.96, W["depth"] * 1.05, 0.2), (0, 0, z_hip + 0.55)), ((0.35, 0.3, 0.5), (0.95, 0, z_hip + 0.3)), ((0.3, 0.3, 0.45), (-0.95, 0.1, z_hip + 0.3))]),
    # helmet: a shell over the head, a brim, a chin guard and one amber visor strip
    limb("HeadHelmet", "DarkMetal", [((W["head"] * 1.08, W["head"] * 1.14, 0.62), (0, 0.02, z_neck + 0.93)), ((W["head"] * 1.1, 0.3, 0.5), (0, W["head"] * 0.5, z_neck + 0.5)),
                                      ((0.16, W["head"] * 1.0, 0.6), (-W["head"] * 0.5, 0.05, z_neck + 0.5)), ((0.16, W["head"] * 1.0, 0.6), (W["head"] * 0.5, 0.05, z_neck + 0.5))], bev=0.12),
    limb("HeadChin", "Plate", [((W["head"] * 0.8, 0.2, 0.32), (0, F * W["head"] * 0.48, z_neck + 0.2))]),
    limb("HeadVisor", "Goggle", [((W["head"] * 0.86, 0.1, 0.16), (0, F * W["head"] * 0.5, z_neck + 0.62))], bev=0),
]
export("Rig_Sentry", parts, az=-1.0, el=0.15)
print("STATION DONE")
