# Inventory icons: small models for items that have no world mesh (materials, consumables, ammo, packs).
# Origin at the centre, roughly 1 unit across, so the client can frame them in a ViewportFrame.
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
import bmesh
from mathutils import Matrix, Vector
PAL = {"Steel": (0.30, 0.31, 0.34), "DarkMetal": (0.14, 0.14, 0.16), "Rust": (0.36, 0.20, 0.12), "Copper": (0.72, 0.42, 0.2),
       "Cloth": (0.25, 0.23, 0.22), "Glass": (0.6, 0.8, 0.9), "Canvas": (0.36, 0.38, 0.30), "Strap": (0.16, 0.13, 0.10),
       "White": (0.85, 0.87, 0.88), "Red": (0.7, 0.12, 0.12), "Olive": (0.24, 0.27, 0.16), "ArcCoil": (0.1, 0.8, 1.0),
       "Neon": (0.05, 0.75, 0.95), "Hazard": (0.85, 0.65, 0.1), "SignGreen": (0.1, 0.45, 0.25), "Powder": (0.2, 0.2, 0.22)}
def mat(n):
    import bpy
    return bpy.data.materials.get(n) or material(n, PAL[n])
T = lambda x, y, z: Matrix.Translation((x, y, z))
RX = lambda d: Matrix.Rotation(math.radians(d), 4, "X")
RY = lambda d: Matrix.Rotation(math.radians(d), 4, "Y")
RZ = lambda d: Matrix.Rotation(math.radians(d), 4, "Z")
def mesh(name, m, boxes=(), cyls=(), jit=0.0, seed=1):
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
    export_fbx(os.path.join(OUT, f"Icon_{name}.fbx"), parts)
    render(os.path.join(OUT, f"Icon_{name}_preview.png"), parts, azimuth=0.8, elevation=0.5)
    print("BUILT", name)
reset(); export("Scrap", [mesh("Bits", "Rust", [((0.9, 0.3, 0.1), T(0, 0, 0) @ RZ(20)), ((0.6, 0.25, 0.12), T(0.1, 0.1, 0.12) @ RZ(-35)), ((0.4, 0.4, 0.08), T(-0.2, -0.15, 0.2) @ RZ(60))], jit=0.03)])
reset(); export("Wire", [mesh("Coil", "Copper", [], [(0.45, 0.12, T(0, 0, 0.06 + i * 0.1)) for i in range(4)]), mesh("Core", "DarkMetal", [], [(0.3, 0.5, T(0, 0, 0.25))])])
reset(); export("Cloth", [mesh("Rag", "Cloth", [((0.9, 0.7, 0.12), T(0, 0, 0.06) @ RZ(15)), ((0.5, 0.6, 0.12), T(0.15, -0.1, 0.17) @ RZ(-25))], jit=0.04)])
reset(); export("Glass", [mesh("Shards", "Glass", [((0.5, 0.2, 0.05), T(-0.15, 0, 0.03) @ RZ(30)), ((0.35, 0.35, 0.05), T(0.2, 0.1, 0.03) @ RZ(-15)), ((0.25, 0.45, 0.05), T(0, -0.25, 0.03) @ RZ(70))])])
reset(); export("SheetMetal", [mesh("Sheet", "Steel", [((1.0, 0.7, 0.06), T(0, 0, 0.03)), ((1.0, 0.7, 0.06), T(0.05, 0.05, 0.1) @ RZ(6))], jit=0.02)])
reset(); export("Pipe", [mesh("Pipe", "Rust", [], [(0.12, 1.0, T(0, 0, 0.12) @ RY(90) @ RZ(0))]), mesh("Joint", "Steel", [], [(0.15, 0.2, T(0.35, 0, 0.12) @ RY(90))])])
reset(); export("Battery", [mesh("Cell", "DarkMetal", [((0.5, 0.3, 0.6), T(0, 0, 0.3))]), mesh("Terminals", "Copper", [((0.1, 0.1, 0.1), T(-0.12, 0, 0.65)), ((0.1, 0.1, 0.1), T(0.12, 0, 0.65))]), mesh("Label", "Hazard", [((0.52, 0.32, 0.15), T(0, 0, 0.3))])])
reset(); export("Powder", [mesh("Pouch", "Powder", [((0.6, 0.4, 0.5), T(0, 0, 0.25))], jit=0.05), mesh("Tie", "Strap", [((0.65, 0.45, 0.08), T(0, 0, 0.42))])])
reset(); export("SignPlating", [mesh("Plate", "SignGreen", [((1.0, 0.8, 0.06), T(0, 0, 0.03))]), mesh("Text", "White", [((0.7, 0.12, 0.07), T(0, 0.15, 0.04)), ((0.5, 0.12, 0.07), T(-0.1, -0.15, 0.04))])])
reset(); export("ArcCell", [mesh("Cell", "ArcCoil", [], [(0.15, 0.5, T(0, 0, 0.25))]), mesh("Caps", "Steel", [], [(0.17, 0.08, T(0, 0, 0.04)), (0.17, 0.08, T(0, 0, 0.46))])])
reset(); export("Medkit", [mesh("Case", "White", [((0.8, 0.5, 0.35), T(0, 0, 0.18))]), mesh("Cross", "Red", [((0.3, 0.1, 0.05), T(0, -0.26, 0.2)), ((0.1, 0.1, 0.3), T(0, -0.26, 0.2))]), mesh("Clasp", "Steel", [((0.15, 0.52, 0.08), T(0.25, 0, 0.3))])])
reset(); export("Ration", [mesh("Tin", "Olive", [], [(0.3, 0.35, T(0, 0, 0.18))]), mesh("Lid", "Steel", [], [(0.3, 0.04, T(0, 0, 0.37))]), mesh("Band", "Hazard", [((0.62, 0.62, 0.08), T(0, 0, 0.18))])])
reset(); export("PipeGrenade", [mesh("Body", "Rust", [], [(0.14, 0.7, T(0, 0, 0.35))]), mesh("Caps", "Steel", [], [(0.17, 0.1, T(0, 0, 0.05)), (0.17, 0.1, T(0, 0, 0.65))]), mesh("Fuse", "Strap", [], [(0.03, 0.25, T(0.05, 0, 0.8) @ RX(20))])])
reset(); export("BreachingCharge", [mesh("Block", "Olive", [((0.9, 0.5, 0.25), T(0, 0, 0.12))]), mesh("Timer", "Neon", [((0.2, 0.15, 0.05), T(0.2, 0, 0.27))]), mesh("Wires", "Copper", [((0.4, 0.04, 0.04), T(-0.15, 0.1, 0.27)), ((0.3, 0.04, 0.04), T(-0.15, -0.1, 0.27) @ RZ(15))])])
reset(); export("Satchel", [mesh("Bag", "Canvas", [((0.9, 0.4, 0.7), T(0, 0, 0.35))], jit=0.03), mesh("Flap", "Cloth", [((0.92, 0.42, 0.2), T(0, 0, 0.65))]), mesh("Strap", "Strap", [((0.1, 0.1, 0.6), T(-0.3, 0, 0.9)), ((0.1, 0.1, 0.6), T(0.3, 0, 0.9)), ((0.7, 0.1, 0.1), T(0, 0, 1.2))])])
reset(); export("Rucksack", [mesh("Bag", "Olive", [((0.9, 0.5, 1.0), T(0, 0, 0.5))], jit=0.03), mesh("Pocket", "Canvas", [((0.5, 0.2, 0.4), T(0, -0.33, 0.35))]), mesh("Straps", "Strap", [((0.12, 0.1, 0.9), T(-0.25, 0.3, 0.5)), ((0.12, 0.1, 0.9), T(0.25, 0.3, 0.5))])])
reset(); export("FramePack", [mesh("Frame", "Steel", [((0.1, 0.1, 1.3), T(-0.45, 0.3, 0.65)), ((0.1, 0.1, 1.3), T(0.45, 0.3, 0.65)), ((1.0, 0.1, 0.1), T(0, 0.3, 1.25)), ((1.0, 0.1, 0.1), T(0, 0.3, 0.1))]), mesh("Bag", "Olive", [((0.85, 0.5, 1.1), T(0, 0, 0.6))], jit=0.03), mesh("Roll", "Canvas", [], [(0.18, 0.9, T(0, 0, 1.3) @ RY(90))])])
print("ICONS DONE")
