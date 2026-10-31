# Loot containers (server/Loot.lua): a supply crate (A olive, B dark vault with a glowing lock) 3x3x3 and a
# stash duffel 3 x 3 x 1.2 for remains, spoils and salvage. Origin at the bottom centre.
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
import bmesh
from mathutils import Matrix, Vector
PAL = {"Olive": (0.24, 0.27, 0.16), "Steel": (0.30, 0.31, 0.34), "DarkMetal": (0.14, 0.14, 0.16), "Neon": (0.05, 0.75, 0.95),
       "Canvas": (0.36, 0.38, 0.30), "Strap": (0.16, 0.13, 0.10), "Hazard": (0.85, 0.65, 0.1), "Rust": (0.36, 0.20, 0.12)}
def mat(n):
    import bpy
    return bpy.data.materials.get(n) or material(n, PAL[n])
T = lambda x, y, z: Matrix.Translation((x, y, z))
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
    export_fbx(os.path.join(OUT, f"Loot_{name}.fbx"), parts)
    render(os.path.join(OUT, f"Loot_{name}_preview.png"), parts, azimuth=0.8, elevation=0.45)
    print("BUILT", name)
reset(); export("Crate_A", [mesh("Box", "Olive", [((3.0, 3.0, 2.8), T(0, 0, 1.4))], jit=0.03),
                            mesh("Edges", "Steel", [((3.1, 0.25, 0.25), T(0, y, z)) for y in (-1.45, 1.45) for z in (0.15, 2.7)] + [((0.25, 3.1, 0.25), T(x, 0, z)) for x in (-1.45, 1.45) for z in (0.15, 2.7)]),
                            mesh("Stripe", "Hazard", [((3.1, 0.1, 0.4), T(0, -1.52, 1.4))]),
                            mesh("Latch", "DarkMetal", [((0.6, 0.2, 0.5), T(0, -1.58, 2.3))])])
reset(); export("Crate_B", [mesh("Box", "DarkMetal", [((3.4, 3.4, 3.2), T(0, 0, 1.6))], jit=0.02),
                            mesh("Frame", "Steel", [((3.5, 0.3, 3.3), T(0, y, 1.65)) for y in (-1.6, 1.6)] + [((0.3, 3.5, 3.3), T(x, 0, 1.65)) for x in (-1.6, 1.6)]),
                            mesh("Lock", "Neon", [], [(0.4, 0.2, T(0, -1.75, 1.8) @ Matrix.Rotation(math.radians(90), 4, "X"))]),
                            mesh("Seams", "Neon", [((2.6, 0.1, 0.08), T(0, -1.75, 0.6)), ((2.6, 0.1, 0.08), T(0, -1.75, 2.9))])])
reset(); export("Stash", [mesh("Bag", "Canvas", [((2.6, 1.6, 1.0), T(0, 0, 0.5) @ RZ(8)), ((1.2, 1.2, 0.7), T(0.9, 0.5, 0.75) @ RZ(-10))], jit=0.05),
                          mesh("Straps", "Strap", [((0.2, 1.7, 1.05), T(-0.7, 0, 0.5) @ RZ(8)), ((0.2, 1.7, 1.05), T(0.6, 0, 0.5) @ RZ(8)), ((1.6, 0.15, 0.15), T(0, 0.3, 1.15))]),
                          mesh("Scrap", "Rust", [((0.9, 0.3, 0.3), T(-1.2, 0.6, 0.15) @ RZ(30)), ((0.5, 0.5, 0.2), T(1.3, -0.7, 0.1))])])
print("LOOT DONE")
# Neural Net terminal shell 5 x 2.5 x 7: the body (the neon screen part with its text stays separate in-game)
reset(); export("Terminal", [mesh("Body", "DarkMetal", [((5.0, 2.5, 7.0), T(0, 0, 3.5))], jit=0.02),
                             mesh("Frame", "Steel", [((4.4, 0.2, 0.25), T(0, -1.3, 5.85)), ((4.4, 0.2, 0.25), T(0, -1.3, 2.55)), ((0.25, 0.2, 3.5), T(-2.15, -1.3, 4.2)), ((0.25, 0.2, 3.5), T(2.15, -1.3, 4.2))]),
                             mesh("Vents", "Strap", [((3.0, 0.1, 0.12), T(0, -1.3, z)) for z in (0.8, 1.1, 1.4)]),
                             mesh("Cable", "Rust", [], [(0.12, 1.6, T(2.0, 1.0, 0.8))]),
                             mesh("Pulse", "Neon", [((0.12, 0.1, 1.6), T(-2.3, -1.28, 4.2)), ((0.12, 0.1, 1.6), T(2.3, -1.28, 4.2))])])
print("TERMINAL DONE")
