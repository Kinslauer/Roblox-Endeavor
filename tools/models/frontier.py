# The frontier kit (server/Frontier.lua chunk builders): trees, dead trees, rocks, a tent, a greenhouse
# dome and a solar tower. Origin at the bottom centre; 1 unit = 1 stud. Trees are ~12-16 studs tall, rocks
# ~6 (the game scales them with Model:ScaleTo).
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
import bmesh
from mathutils import Matrix, Vector
PAL = {"Bark": (0.30, 0.22, 0.15), "DeadBark": (0.28, 0.25, 0.22), "Needle": (0.16, 0.34, 0.18), "Leaf": (0.28, 0.48, 0.22),
       "LeafDark": (0.18, 0.36, 0.26), "Stone": (0.40, 0.39, 0.41), "StoneDark": (0.28, 0.27, 0.30), "Canvas": (0.36, 0.38, 0.30),
       "Strap": (0.16, 0.13, 0.10), "Frame": (0.85, 0.83, 0.78), "DomeGlass": (0.70, 0.90, 0.86), "SolarGlass": (0.10, 0.18, 0.35),
       "Concrete": (0.40, 0.40, 0.42)}
def mat(n):
    import bpy
    return bpy.data.materials.get(n) or material(n, PAL[n])
T = lambda x, y, z: Matrix.Translation((x, y, z))
RX = lambda d: Matrix.Rotation(math.radians(d), 4, "X")
RY = lambda d: Matrix.Rotation(math.radians(d), 4, "Y")
RZ = lambda d: Matrix.Rotation(math.radians(d), 4, "Z")
S = lambda x, y, z: Matrix.Diagonal((x, y, z, 1))

def mesh(name, m, boxes=(), cones=(), spheres=(), jit=0.0, seed=1, subdiv=1):
    bm = bmesh.new()
    for size, M in boxes:
        bmesh.ops.create_cube(bm, size=1.0, matrix=M @ S(*size))
    for r1, r2, depth, M in cones:
        bmesh.ops.create_cone(bm, cap_ends=True, segments=9, radius1=r1, radius2=r2, depth=depth, matrix=M)
    for r, M in spheres:
        bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=r, matrix=M)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.001)
    ob = obj_from_bmesh(name, bm, mat(m))
    if jit: jitter(ob, jit, seed)
    return ob

def export(name, parts, **kw):
    export_fbx(os.path.join(OUT, f"Frontier_{name}.fbx"), parts)
    render(os.path.join(OUT, f"Frontier_{name}_preview.png"), parts, azimuth=0.8, elevation=0.4, **kw)
    print("BUILT", name)

# ----- pines: a tapered trunk and three cone tiers
def pine(name, h, lean, seed):
    rnd = random.Random(seed)
    trunk = mesh("Trunk", "Bark", cones=[(0.75, 0.35, h * 0.7, T(0, 0, h * 0.35) @ RY(lean))], jit=0.04, seed=seed)
    tiers = []
    for i, (z, r) in enumerate(((h * 0.32, 4.2), (h * 0.55, 3.4), (h * 0.78, 2.4))):
        tiers.append((r + rnd.uniform(-0.3, 0.3), 0.2, h * 0.34, T(0, 0, z + h * 0.1) @ RZ(rnd.uniform(0, 40))))
    foliage = mesh("Needles", "Needle", cones=tiers, jit=0.12, seed=seed + 1)
    return [trunk, foliage]

# ----- broadleaf: a forked trunk and a lumpy canopy of overlapping icospheres
def broad(name, h, seed):
    rnd = random.Random(seed)
    trunk = mesh("Trunk", "Bark", cones=[(0.9, 0.5, h * 0.55, T(0, 0, h * 0.275)), (0.45, 0.25, h * 0.35, T(0.9, 0.3, h * 0.6) @ RY(28)), (0.4, 0.2, h * 0.3, T(-0.8, -0.4, h * 0.6) @ RX(25) @ RY(-24))], jit=0.05, seed=seed)
    lumps = [(h * 0.26, T(0, 0, h * 0.72))]
    for i in range(5):
        a = i / 5 * math.tau
        lumps.append((h * rnd.uniform(0.15, 0.2), T(math.cos(a) * h * 0.2, math.sin(a) * h * 0.2, h * rnd.uniform(0.6, 0.8))))
    canopy = mesh("Canopy", "Leaf" if seed % 2 else "LeafDark", spheres=lumps, jit=0.25, seed=seed + 2)
    return [trunk, canopy]

# ----- dead tree: a bare trunk with three broken limbs
def dead(seed):
    rnd = random.Random(seed)
    cones = [(0.7, 0.25, 11, T(0, 0, 5.5) @ RY(rnd.uniform(-6, 6)))]
    for i in range(3):
        a = rnd.uniform(0, 360)
        cones.append((0.28, 0.08, rnd.uniform(3, 5), T(0, 0, rnd.uniform(5, 9)) @ RZ(a) @ RY(rnd.uniform(40, 75)) @ T(0, 0, 2)))
    return [mesh("Trunk", "DeadBark", cones=cones, jit=0.06, seed=seed)]

# ----- rocks: a flattened, jittered icosphere with a darker base
def rock(seed, sx, sy, sz):
    body = mesh("Rock", "Stone", spheres=[(3.0, S(sx, sy, sz) @ T(0, 0, 0.9))], jit=0.45, seed=seed)
    base = mesh("Base", "StoneDark", spheres=[(2.6, S(sx * 1.1, sy * 1.1, 0.5) @ T(0, 0, 0.6))], jit=0.3, seed=seed + 1)
    return [body, base]

# ----- tent: canvas ridge tent 7 x 6, 4.4 high, open front
def tent():
    canvas = mesh("Canvas", "Canvas", boxes=[((5.2, 7.2, 0.25), T(1.95, 0, 2.2) @ RY(58)), ((5.2, 7.2, 0.25), T(-1.95, 0, 2.2) @ RY(-58)), ((4.6, 0.2, 3.8), T(0, -3.0, 2.0))], jit=0.05)
    poles = mesh("Poles", "Strap", cones=[(0.12, 0.12, 4.6, T(0, 2.9, 2.3)), (0.12, 0.12, 4.6, T(0, -2.9, 2.3)), (0.1, 0.1, 7.4, T(0, 0, 4.5) @ RX(90))])
    pegs = mesh("Pegs", "Strap", boxes=[((0.3, 0.3, 0.8), T(x, y, 0.3)) for x in (-3.9, 3.9) for y in (-2.2, 2.2)])
    return [canvas, poles, pegs]

# ----- greenhouse dome: glass hemisphere r 10 on a ring base, with white ribs
def dome():
    glass = mesh("Glass", "DomeGlass", spheres=[(10.0, T(0, 0, 0.6))], subdiv=2)
    ribs = []
    for i in range(6):
        ribs.append((0.18, 0.18, 20.4, T(0, 0, 0.6) @ RZ(i * 30) @ RX(90)))
    frame = mesh("Ribs", "Frame", cones=ribs)
    ring = mesh("Ring", "Concrete", cones=[(10.6, 10.6, 0.8, T(0, 0, 0.4))])
    door = mesh("Door", "Frame", boxes=[((2.6, 0.3, 4.2), T(0, -10.0, 2.1))])
    return [glass, frame, ring, door]

# ----- solar tower: a mast with a tilted panel and a brace
def tower():
    mast = mesh("Mast", "Frame", cones=[(0.6, 0.45, 26, T(0, 0, 13))], jit=0.0)
    head = mesh("Head", "Frame", boxes=[((13, 1.0, 0.5), T(0, 0, 26.2) @ RX(-28)), ((0.5, 1.2, 3.0), T(0, 0, 25.0))])
    panel = mesh("Panel", "SolarGlass", boxes=[((12.4, 8.4, 0.25), T(0, 1.2, 26.9) @ RX(-28))])
    cells = mesh("Cells", "Frame", boxes=[((12.5, 0.12, 0.3), T(0, 1.2 + k * 1.3, 26.9 + k * 0.7) @ RX(-28)) for k in (-2, -1, 0, 1, 2)])
    foot = mesh("Foot", "Concrete", boxes=[((3.0, 3.0, 0.8), T(0, 0, 0.4))])
    return [mast, head, panel, cells, foot]

reset(); export("PineA", pine("PineA", 15, 2, 11))
reset(); export("PineB", pine("PineB", 12, -3, 23))
reset(); export("BroadA", broad("BroadA", 13, 31))
reset(); export("BroadB", broad("BroadB", 11, 42))
reset(); export("Dead", dead(7))
reset(); export("RockA", rock(3, 1.0, 0.8, 0.7))
reset(); export("RockB", rock(5, 1.3, 0.9, 0.5))
reset(); export("RockC", rock(9, 0.8, 1.2, 0.9))
reset(); export("Tent", tent())
reset(); export("Dome", dome())
reset(); export("Tower", tower())
print("FRONTIER DONE")
