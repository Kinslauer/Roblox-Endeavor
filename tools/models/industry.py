# The megacity's industrial kit (server/Megacity.lua): smokestack, storage tank, cooling tower, power pylon,
# blast furnace, junk pile and the Rootwork's giant tree. Origin at the bottom centre; 1 unit = 1 stud.
# Reference sizes (the game scales with Model:ScaleTo): stack 120 tall, tank r 12, cooling tower 100 tall,
# pylon 60, furnace 70, junk pile 50 across, tree ~80.
# Materials whose Assets.Materials entry says NoCollide (Lattice, Canopy, RootBark) do not collide in game,
# so a lattice or a canopy never becomes a solid hull you bump into.
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
import bmesh
from mathutils import Matrix, Vector

PAL = {"SootBrick": (0.23, 0.16, 0.14), "Red": (0.7, 0.12, 0.12), "White": (0.85, 0.87, 0.88), "DarkMetal": (0.16, 0.16, 0.18),
       "Steel": (0.31, 0.32, 0.35), "Rust": (0.38, 0.21, 0.13), "TankPaint": (0.62, 0.6, 0.55), "Cooling": (0.6, 0.58, 0.54),
       "Lattice": (0.34, 0.35, 0.38), "Insulator": (0.5, 0.3, 0.2), "Ember": (1.0, 0.45, 0.1), "Char": (0.11, 0.1, 0.1),
       "Paint": (0.55, 0.16, 0.14), "Bark": (0.3, 0.22, 0.15), "RootBark": (0.27, 0.2, 0.14), "Canopy": (0.26, 0.5, 0.22),
       "Moss": (0.27, 0.43, 0.2)}
def mat(n):
    import bpy
    return bpy.data.materials.get(n) or material(n, PAL[n])
T = lambda x, y, z: Matrix.Translation((x, y, z))
RX = lambda d: Matrix.Rotation(math.radians(d), 4, "X")
RY = lambda d: Matrix.Rotation(math.radians(d), 4, "Y")
RZ = lambda d: Matrix.Rotation(math.radians(d), 4, "Z")
S = lambda x, y, z: Matrix.Diagonal((x, y, z, 1))

def between(a, b):
    """Matrix placing a unit-Z primitive centred between a and b, Z along a->b; returns (matrix, length)."""
    a, b = Vector(a), Vector(b)
    d = b - a
    q = d.normalized().to_track_quat("Z", "Y")
    return Matrix.Translation((a + b) / 2) @ q.to_matrix().to_4x4(), d.length

def mesh(name, m, boxes=(), cones=(), spheres=(), bars=(), jit=0.0, seed=1, subdiv=1, segs=12):
    bm = bmesh.new()
    for size, M in boxes:
        bmesh.ops.create_cube(bm, size=1.0, matrix=M @ S(*size))
    for r1, r2, depth, M in cones:
        bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r1, radius2=r2, depth=depth, matrix=M)
    for r, M in spheres:
        bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=r, matrix=M)
    for a, b, w in bars:  # square bars from a to b, w thick
        M, L = between(a, b)
        bmesh.ops.create_cube(bm, size=1.0, matrix=M @ S(w, w, L))
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.001)
    ob = obj_from_bmesh(name, bm, mat(m))
    if jit: jitter(ob, jit, seed)
    return ob

def lathe(name, m, profile, segs=28):
    """Solid of revolution: profile = closed list of (r, z) points, spun round Z."""
    bm = bmesh.new()
    rings = []
    for i in range(segs):
        a = i / segs * math.tau
        rings.append([bm.verts.new((r * math.cos(a), r * math.sin(a), z)) for r, z in profile])
    n = len(profile)
    for i in range(segs):
        A, B = rings[i], rings[(i + 1) % segs]
        for k in range(n):
            bm.faces.new((A[k], A[(k + 1) % n], B[(k + 1) % n], B[k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return obj_from_bmesh(name, bm, mat(m))

def export(name, parts):
    export_fbx(os.path.join(OUT, f"Industry_{name}.fbx"), parts)
    render(os.path.join(OUT, f"Industry_{name}_preview.png"), parts)
    print("BUILT", name)

# ----- smokestack: 120 tall, tapered brick, warning bands, a rim, ladder and two platforms
def smokestack():
    h = 120
    body = mesh("Stack", "SootBrick", cones=[(7.5, 5.2, h, T(0, 0, h / 2))], segs=20, jit=0.05)
    base = mesh("Plinth", "DarkMetal", boxes=[((19, 19, 5), T(0, 0, 2.5))])
    bands = mesh("BandR", "Red", cones=[(5.55, 5.5, 4, T(0, 0, h - 6)), (5.75, 5.7, 4, T(0, 0, h - 22))], segs=20)
    white = mesh("BandW", "White", cones=[(5.65, 5.6, 4, T(0, 0, h - 14))], segs=20)
    rim = mesh("Rim", "DarkMetal", cones=[(6.2, 6.0, 2, T(0, 0, h))], segs=20)
    ladder = mesh("Ladder", "Steel", bars=[((0.8, -7.4, 2), (0.8, -5.4, h - 2), 0.25), ((-0.8, -7.4, 2), (-0.8, -5.4, h - 2), 0.25)]
                  + [((0.8, -7.4 + 2.0 * z / h, z), (-0.8, -7.4 + 2.0 * z / h, z), 0.18) for z in range(4, h - 2, 3)])
    plats = mesh("Platform", "Steel", cones=[(9.2, 9.2, 0.5, T(0, 0, h * 0.45)), (8.0, 8.0, 0.5, T(0, 0, h * 0.85))], segs=20)
    return [body, base, bands, white, rim, ladder, plats]

# ----- storage tank: r 12, 18 tall, shallow dome, a band, a ladder, a railing ring on top
def tank():
    shell = mesh("Shell", "TankPaint", cones=[(12, 12, 18, T(0, 0, 9))], segs=28, jit=0.04)
    dome = mesh("Dome", "TankPaint", spheres=[(12, T(0, 0, 18) @ S(1, 1, 0.22))], subdiv=3)
    band = mesh("Band", "Rust", cones=[(12.15, 12.15, 1.2, T(0, 0, 4)), (12.15, 12.15, 1.2, T(0, 0, 13))], segs=28)
    ladder = mesh("Ladder", "Steel", bars=[((12.4, 0.7, 0), (12.4, 0.7, 19), 0.25), ((12.4, -0.7, 0), (12.4, -0.7, 19), 0.25)]
                  + [((12.4, 0.7, z), (12.4, -0.7, z), 0.18) for z in range(1, 19, 2)])
    posts = []
    for i in range(16):
        a = i / 16 * math.tau
        posts.append(((math.cos(a) * 11.6, math.sin(a) * 11.6, 18.5), (math.cos(a) * 11.6, math.sin(a) * 11.6, 21.5), 0.2))
    rail = mesh("Rail", "Steel", bars=posts, cones=[(11.7, 11.7, 0.25, T(0, 0, 21.5))], segs=24)
    return [shell, dome, band, ladder, rail]

# ----- cooling tower: a hollow hyperboloid shell on a ring of raking legs, 100 tall
def cooling():
    h, rb, rw, rt = 100, 34, 22, 25
    def r_at(z):
        t = z / h
        throat = 0.72
        if t < throat:
            return rw + (rb - rw) * ((throat - t) / throat) ** 1.7
        return rw + (rt - rw) * ((t - throat) / (1 - throat)) ** 1.6
    zs = [10 + (h - 10) * i / 16 for i in range(17)]
    outer = [(r_at(z), z) for z in zs]
    inner = [(r_at(z) - 1.2, z) for z in reversed(zs)]
    shell = lathe("Shell", "Cooling", outer + inner, segs=32)
    legs = []
    for i in range(24):
        a = i / 24 * math.tau
        b = a + math.tau / 24
        top = (math.cos(a) * (r_at(10) - 0.6), math.sin(a) * (r_at(10) - 0.6), 10.2)
        foot = (math.cos(b) * (rb + 1.5), math.sin(b) * (rb + 1.5), 0)
        foot2 = (math.cos(a - math.tau / 24) * (rb + 1.5), math.sin(a - math.tau / 24) * (rb + 1.5), 0)
        legs += [(foot, top, 1.0), (foot2, top, 1.0)]
    leg = mesh("Legs", "Cooling", bars=legs)
    basin = lathe("Basin", "Char", [(rb + 3, 0), (rb + 3, 1.5), (rb + 2, 1.5), (rb + 2, 0.2)], segs=32)
    return [shell, leg, basin]

# ----- power pylon: a lattice tower 60 tall with two crossarms and hanging insulators
def pylon():
    h = 60
    def leg_at(sx, sy, z):
        w = 6.0 + (1.3 - 6.0) * (z / h)
        return (sx * w, sy * w, z)
    bars = []
    corners = [(1, 1), (1, -1), (-1, -1), (-1, 1)]
    for sx, sy in corners:
        bars.append((leg_at(sx, sy, 0), leg_at(sx, sy, h), 0.6))
    levels = [0, 8, 16, 24, 32, 40, 48, 56, h]
    for i in range(len(levels) - 1):
        z0, z1 = levels[i], levels[i + 1]
        for k in range(4):
            (ax, ay), (bx, by) = corners[k], corners[(k + 1) % 4]
            bars.append((leg_at(ax, ay, z0), leg_at(bx, by, z1), 0.3))
            bars.append((leg_at(bx, by, z0), leg_at(ax, ay, z1), 0.3))
            bars.append((leg_at(ax, ay, z1), leg_at(bx, by, z1), 0.35))
    for z, half in ((h * 0.7, 13), (h * 0.88, 10)):
        w = leg_at(1, 1, z)[0]
        for s in (-1, 1):
            bars.append(((0, s * w, z), (0, s * half, z), 0.5))
            bars.append(((0, s * w, z + 3), (0, s * half, z), 0.3))
            bars.append(((w, s * w, z), (0, s * half, z), 0.3))
            bars.append(((-w, s * w, z), (0, s * half, z), 0.3))
    bars.append(((0, 0, h), (0, 0, h + 6), 0.5))
    frame = mesh("Frame", "Lattice", bars=bars)
    ins = []
    for z, half in ((h * 0.7, 13), (h * 0.88, 10)):
        for s in (-1, 1):
            ins.append((0.5, 0.5, 3.5, T(0, s * (half - 0.5), z - 1.8)))
    insul = mesh("Insulators", "Insulator", cones=ins, segs=8)
    pad = mesh("Footings", "Cooling", boxes=[((2.5, 2.5, 1.2), T(sx * 6, sy * 6, 0.6)) for sx, sy in corners])
    return [frame, insul, pad]

# ----- blast furnace: 70 tall, brick-lined shell, bustle main, three downcomers, three domed hot-blast stoves
def furnace():
    h = 70
    base = mesh("Hearth", "SootBrick", cones=[(14, 13, 12, T(0, 0, 6))], segs=20)
    body = lathe("Shaft", "Rust", [(0, 12), (12, 12), (12.5, 22), (10.5, 46), (7, 54), (0, 54)], segs=24)
    top = mesh("Top", "DarkMetal", cones=[(6.5, 4.5, 8, T(0, 0, 58)), (3.5, 3.0, 8, T(0, 0, 66))], segs=16)
    bustle = []
    for i in range(16):
        a, b = i / 16 * math.tau, (i + 1) / 16 * math.tau
        bustle.append(((math.cos(a) * 15.5, math.sin(a) * 15.5, 20), (math.cos(b) * 15.5, math.sin(b) * 15.5, 20), 1.6))
        if i % 2 == 0:
            bustle.append(((math.cos(a) * 15.5, math.sin(a) * 15.5, 20), (math.cos(a) * 12.4, math.sin(a) * 12.4, 14), 0.8))
    pipes = []
    for k in range(3):
        a = k / 3 * math.tau + 0.4
        pipes.append(((0, 0, 64), (math.cos(a) * 9, math.sin(a) * 9, 72), 2.0))
        pipes.append(((math.cos(a) * 9, math.sin(a) * 9, 72), (math.cos(a) * 28, math.sin(a) * 28, 8), 2.2))
    main = mesh("Mains", "Rust", bars=bustle + pipes)
    stoves = []
    for k in range(3):
        x = 30 + k * 11
        stoves += [(5, 5, 36, T(x, -18, 18))]
    stove = mesh("Stoves", "SootBrick", cones=stoves, segs=16)
    caps = mesh("StoveDomes", "DarkMetal", spheres=[(5, T(30 + k * 11, -18, 36) @ S(1, 1, 0.7)) for k in range(3)], subdiv=2)
    tap = mesh("Taphole", "Ember", boxes=[((4, 1, 3), T(0, -13.6, 3))])
    house = mesh("CastHouse", "DarkMetal", boxes=[((26, 18, 10), T(0, -24, 5)), ((28, 20, 1), T(0, -24, 10.5))])
    return [base, body, top, main, stove, caps, tap, house]

# ----- junk pile: a mound of crushed scrap with car shells, beams and drums poking out, 50 across
def junk(seed):
    rnd = random.Random(seed)
    mound = mesh("Mound", "Rust", spheres=[(25, S(1, 0.9, 0.36))] + [(rnd.uniform(9, 14), T(rnd.uniform(-14, 14), rnd.uniform(-12, 12), rnd.uniform(2, 6)) @ S(1, 1, 0.6)) for _ in range(5)], subdiv=2, jit=1.2, seed=seed)
    cars, beams, drums = [], [], []
    for i in range(12):
        a, r = rnd.uniform(0, math.tau), rnd.uniform(3, 20)
        z = 9.5 * (1 - (r / 25) ** 2) + rnd.uniform(0.5, 2)
        M = T(math.cos(a) * r, math.sin(a) * r, z) @ RZ(rnd.uniform(0, 360)) @ RX(rnd.uniform(-35, 35)) @ RY(rnd.uniform(-25, 25))
        if i % 3 == 0:
            beams.append(((0.8, 0.8, rnd.uniform(10, 18)), M @ RX(60)))
        elif i % 3 == 1:
            cars.append(((4.2, 9, 2.6), M))
        else:
            drums.append((1.3, 1.3, 3.2, M))
    a = mesh("Shells", "Paint", boxes=cars, jit=0.15, seed=seed + 1)
    b = mesh("Beams", "Rust", boxes=beams)
    c = mesh("Drums", "Steel", cones=drums, segs=10)
    return [mound, a, b, c]

# ----- the giant tree: older than the city. Trunk (collides), roots and branches (pass through), canopy
def giant(seed):
    rnd = random.Random(seed)
    trunk = mesh("Trunk", "Bark", cones=[(10, 7, 14, T(0, 0, 7)), (7, 5, 40, T(0.5, 0, 34) @ RY(3)), (5, 3.2, 26, T(2, 0, 66) @ RY(6))], segs=14, jit=0.5, seed=seed)
    roots, limbs, lumps = [], [], []
    for k in range(8):
        a = k / 8 * math.tau + rnd.uniform(-0.2, 0.2)
        L = rnd.uniform(22, 34)
        roots.append(((math.cos(a) * 5, math.sin(a) * 5, 8), (math.cos(a) * L, math.sin(a) * L, -1), rnd.uniform(2.2, 3.4)))
    for k in range(6):
        a = k / 6 * math.tau + rnd.uniform(-0.3, 0.3)
        z = rnd.uniform(44, 70)
        L = rnd.uniform(22, 32)
        end = (math.cos(a) * L, math.sin(a) * L, z + rnd.uniform(8, 16))
        limbs.append(((1.5, 0, z), end, rnd.uniform(1.6, 2.4)))
        lumps.append((rnd.uniform(13, 18), T(*end) @ S(1, 1, 0.65)))
    lumps.append((24, T(3, 0, 86) @ S(1, 1, 0.6)))
    lumps.append((18, T(-8, 6, 78) @ S(1, 1, 0.6)))
    root = mesh("Roots", "RootBark", bars=roots + limbs, jit=0.3, seed=seed + 1)
    canopy = mesh("Crown", "Canopy", spheres=lumps, subdiv=2, jit=1.6, seed=seed + 2)
    moss = mesh("Moss", "Moss", spheres=[(10.5, T(0, 0, 2) @ S(1.4, 1.4, 0.25))], subdiv=2, jit=0.4, seed=seed + 3)
    return [trunk, root, canopy, moss]

reset(); export("Smokestack", smokestack())
reset(); export("Tank", tank())
reset(); export("CoolingTower", cooling())
reset(); export("Pylon", pylon())
reset(); export("BlastFurnace", furnace())
reset(); export("JunkPile", junk(5))
reset(); export("GiantTree", giant(12))
print("INDUSTRY DONE")
