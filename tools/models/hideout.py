# Hideout modules (src/server/Hideouts.lua): the three tiers of bench, the vault, bunks, generator,
# turret, forge and medbay. Each fits the footprint of the box it replaces, origin at the bottom
# centre, facing -Y (toward the gate). Run: blender -b --python hideout.py -> out/Hide_<Name>.fbx
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
import bmesh
from mathutils import Matrix, Vector

PAL = {"Steel": (0.30, 0.31, 0.34), "DarkMetal": (0.14, 0.14, 0.16), "Rust": (0.36, 0.20, 0.12), "OldWood": (0.30, 0.24, 0.16),
       "Wood": (0.42, 0.30, 0.17), "Neon": (0.05, 0.75, 0.95), "ArcCoil": (0.1, 0.8, 1.0), "Chrome": (0.75, 0.78, 0.82),
       "Brick": (0.45, 0.27, 0.20), "Concrete": (0.45, 0.45, 0.47), "Canvas": (0.36, 0.38, 0.30), "Mattress": (0.55, 0.50, 0.42),
       "Yellow": (0.70, 0.60, 0.15), "White": (0.85, 0.87, 0.88), "Ember": (1.0, 0.45, 0.1), "Screen": (0.05, 0.3, 0.45), "Red": (0.7, 0.12, 0.12)}
def mat(n):
    import bpy
    return bpy.data.materials.get(n) or material(n, PAL[n])

T = lambda x, y, z: Matrix.Translation((x, y, z))
RX = lambda d: Matrix.Rotation(math.radians(d), 4, "X")
RY = lambda d: Matrix.Rotation(math.radians(d), 4, "Y")
RZ = lambda d: Matrix.Rotation(math.radians(d), 4, "Z")

def mesh(name, m, boxes=(), cyls=(), jit=0.0, seed=1):
    """boxes: (size, matrix); cyls: (radius, depth, matrix) along local Z."""
    bm = bmesh.new()
    for size, M in boxes:
        bmesh.ops.create_cube(bm, size=1.0, matrix=M @ Matrix.Diagonal((size[0], size[1], size[2], 1)))
    for r, depth, M in cyls:
        bmesh.ops.create_cone(bm, cap_ends=True, segments=10, radius1=r, radius2=r, depth=depth, matrix=M)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.001)
    ob = obj_from_bmesh(name, bm, mat(m))
    if jit: jitter(ob, jit, seed)
    return ob

def export(name, parts):
    export_fbx(os.path.join(OUT, f"Hide_{name}.fbx"), parts)
    render(os.path.join(OUT, f"Hide_{name}_preview.png"), parts, azimuth=0.8, elevation=0.45)
    print("BUILT", name)

# ---- benches 6 x 2.5 x 3 (x, y, height)
def bench(tier):
    parts = []
    if tier == 1:  # tinkerer: planks on two crates, a vise, a lamp on a stick
        parts.append(mesh("Top", "OldWood", [((6.0, 2.4, 0.3), T(0, 0, 2.45))], jit=0.03))
        parts.append(mesh("Crates", "Wood", [((1.6, 1.8, 2.3), T(-2.0, 0, 1.15)), ((1.6, 1.8, 2.3), T(2.0, 0, 1.15))]))
        parts.append(mesh("Vise", "Rust", [((0.8, 0.5, 0.6), T(1.2, -0.9, 2.9)), ((0.2, 1.2, 0.2), T(1.2, -0.9, 2.9))]))
        parts.append(mesh("Lamp", "Neon", [((0.5, 0.3, 0.2), T(-1.8, 0.8, 3.8))]))
        parts.append(mesh("Stick", "DarkMetal", [((0.1, 0.1, 1.3), T(-1.8, 0.9, 3.1))]))
    elif tier == 2:  # workshop: steel bench, drawers, tool board, two lamps
        parts.append(mesh("Top", "Steel", [((6.0, 2.4, 0.25), T(0, 0, 2.5))]))
        parts.append(mesh("Frame", "DarkMetal", [((5.6, 2.0, 2.3), T(0, 0.1, 1.15)), ((6.0, 0.3, 3.4), T(0, 1.2, 4.2))]))
        parts.append(mesh("Drawers", "Rust", [((1.4, 0.1, 0.5), T(-1.8, -0.95, 0.9 + k * 0.7)) for k in range(3)] + [((1.4, 0.1, 0.5), T(1.8, -0.95, 0.9 + k * 0.7)) for k in range(3)]))
        parts.append(mesh("Tools", "Chrome", [((0.15, 0.1, 1.2), T(-2.2 + k * 0.7, 1.0, 4.0 + (k % 2) * 0.4)) for k in range(7)]))
        parts.append(mesh("Lamp", "Neon", [((1.8, 0.3, 0.15), T(-1.6, 0.9, 5.7)), ((1.8, 0.3, 0.15), T(1.6, 0.9, 5.7))]))
    else:  # foundry: heavy chrome bench with screens and a coil
        parts.append(mesh("Top", "Chrome", [((6.0, 2.5, 0.3), T(0, 0, 2.55))]))
        parts.append(mesh("Frame", "DarkMetal", [((5.8, 2.2, 2.4), T(0, 0, 1.2)), ((6.0, 0.4, 4.0), T(0, 1.2, 4.5)), ((0.6, 0.6, 1.2), T(2.3, 0, 3.3))]))
        parts.append(mesh("Screens", "Screen", [((1.8, 0.1, 1.2), T(-1.7, 0.95, 4.4)), ((1.8, 0.1, 1.2), T(0.4, 0.95, 4.4))]))
        parts.append(mesh("Coil", "ArcCoil", [], [(0.5, 0.3, T(2.3, 0, 3.95 + k * 0.35)) for k in range(3)]))
        parts.append(mesh("Trim", "Neon", [((6.0, 0.1, 0.1), T(0, -1.25, 2.4))]))
    return parts
for t in (1, 2, 3):
    reset(); export(f"Bench_{t}", bench(t))

# ---- vault 5 x 4 x 5: steel box, door with wheel and hinges
reset()
export("Vault", [mesh("Body", "DarkMetal", [((5.0, 4.0, 5.0), T(0, 0, 2.5))]),
                 mesh("Door", "Steel", [((3.4, 0.3, 3.8), T(0, -2.05, 2.2))]),
                 mesh("Wheel", "Chrome", [((0.25, 0.3, 1.6), T(0.4, -2.3, 2.3)), ((1.6, 0.3, 0.25), T(0.4, -2.3, 2.3))], [(0.8, 0.2, T(0.4, -2.3, 2.3) @ RX(90))]),
                 mesh("Hinges", "Rust", [((0.3, 0.4, 0.6), T(-1.6, -2.2, 1.2)), ((0.3, 0.4, 0.6), T(-1.6, -2.2, 3.4))]),
                 mesh("Light", "Red", [((0.3, 0.1, 0.3), T(1.5, -2.25, 4.3))])])

# ---- bunks 8 x 4 x 3: two double-tier frames
reset()
frame, beds, blankets = [], [], []
for bx in (-2.0, 2.0):
    for z in (0.9, 2.3):
        beds.append(((3.6, 3.6, 0.4), T(bx, 0, z)))
        blankets.append(((3.2, 2.0, 0.15), T(bx, 0.6, z + 0.27)))
    for cx in (-1.85, 1.85):
        for cy in (-1.85, 1.85):
            frame.append(((0.2, 0.2, 3.0), T(bx + cx, cy, 1.5)))
export("Bunks", [mesh("Frame", "DarkMetal", frame), mesh("Mattress", "Mattress", beds), mesh("Blanket", "Canvas", blankets, jit=0.02)])

# ---- generator 4 x 3 x 3: block, tank, exhaust, cable
reset()
export("Generator", [mesh("Block", "Yellow", [((2.6, 2.4, 1.8), T(-0.5, 0, 1.2))], jit=0.02),
                     mesh("Tank", "DarkMetal", [], [(0.7, 2.4, T(1.3, 0, 1.0) @ RY(90)), (0.7, 2.4, T(1.3, 0, 2.3) @ RY(90))]),
                     mesh("Exhaust", "Rust", [], [(0.18, 1.4, T(-1.2, 0.6, 2.6))]),
                     mesh("Base", "Steel", [((4.0, 3.0, 0.3), T(0, 0, 0.15))]),
                     mesh("Lamp", "Neon", [((0.4, 0.1, 0.4), T(-0.5, -1.25, 1.6))])])

# ---- turret 2 x 2 x 4: tripod, column, twin barrels, sensor
reset()
legs = [((0.25, 0.25, 1.6), T(0.7 * math.cos(a), 0.7 * math.sin(a), 0.75) @ RZ(math.degrees(a)) @ RY(28)) for a in (math.radians(d) for d in (90, 210, 330))]
export("Turret", [mesh("Legs", "DarkMetal", legs),
                  mesh("Column", "Steel", [], [(0.35, 2.0, T(0, 0, 1.9))]),
                  mesh("Head", "DarkMetal", [((1.2, 1.2, 0.8), T(0, 0, 3.2))]),
                  mesh("Barrels", "Steel", [], [(0.12, 1.6, T(-0.3, -0.9, 3.25) @ RX(90)), (0.12, 1.6, T(0.3, -0.9, 3.25) @ RX(90))]),
                  mesh("Eye", "ArcCoil", [((0.5, 0.1, 0.25), T(0, -0.62, 3.5))])])

# ---- forge 5 x 5 x 4: brick hearth, hood and chimney, embers, anvil
reset()
export("Forge", [mesh("Hearth", "Brick", [((3.6, 3.0, 2.2), T(-0.5, 0.8, 1.1))], jit=0.03),
                 mesh("Hood", "DarkMetal", [((3.8, 3.2, 0.3), T(-0.5, 0.8, 3.1)), ((1.0, 1.0, 1.5), T(-0.5, 1.5, 3.9))]),
                 mesh("Embers", "Ember", [((2.4, 1.8, 0.2), T(-0.5, 0.4, 2.3))]),
                 mesh("Anvil", "Steel", [((1.6, 0.6, 0.5), T(1.7, -1.4, 1.35)), ((0.7, 0.5, 1.1), T(1.7, -1.4, 0.55))]),
                 mesh("Stump", "OldWood", [], [(0.45, 1.0, T(1.7, -1.4, 0.5))])])

# ---- medbay 5 x 3 x 3: cot, cabinet with cross, IV stand
reset()
export("Medbay", [mesh("Cot", "White", [((3.6, 1.6, 0.3), T(-0.5, 0.4, 1.0))]),
                  mesh("CotLegs", "Steel", [((0.15, 0.15, 1.0), T(-0.5 + sx * 1.6, 0.4 + sy * 0.6, 0.5)) for sx in (-1, 1) for sy in (-1, 1)]),
                  mesh("Sheet", "Canvas", [((3.2, 1.3, 0.12), T(-0.5, 0.4, 1.2))]),
                  mesh("Cabinet", "White", [((1.2, 0.8, 3.0), T(1.9, 0.6, 1.5))]),
                  mesh("Cross", "Red", [((0.6, 0.1, 0.18), T(1.9, 0.17, 2.3)), ((0.18, 0.1, 0.6), T(1.9, 0.17, 2.3))]),
                  mesh("IV", "Chrome", [((0.08, 0.08, 2.8), T(-2.2, -0.8, 1.4)), ((0.3, 0.3, 0.8), T(-2.2, -0.8, 2.9))], [(0.3, 0.05, T(-2.2, -0.8, 0.05))])])
print("HIDEOUT DONE")
