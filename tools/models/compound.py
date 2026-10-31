# Hideout walls/gate and the raid arena pieces. Wall panels tile along the generated collider parts
# (which turn invisible), so physics stays exactly what it was. Origin: bottom centre, panels run along X.
# Run: blender -b --python compound.py -> out/Cmp_<Name>.fbx
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
import bmesh
from mathutils import Matrix, Vector

PAL = {"Steel": (0.30, 0.31, 0.34), "DarkMetal": (0.14, 0.14, 0.16), "Rust": (0.36, 0.20, 0.12), "Panel": (0.28, 0.29, 0.31),
       "Concrete": (0.45, 0.45, 0.47), "DarkConcrete": (0.22, 0.22, 0.25), "NeonRed": (1.0, 0.12, 0.12), "Neon": (0.05, 0.75, 0.95),
       "Chainlink": (0.5, 0.5, 0.52), "Hazard": (0.85, 0.65, 0.1)}
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
    export_fbx(os.path.join(OUT, f"Cmp_{name}.fbx"), parts)
    render(os.path.join(OUT, f"Cmp_{name}_preview.png"), parts, azimuth=0.8, elevation=0.4)
    print("BUILT", name)

# Hideout wall panel 10 x 1.5 x 9: scrap sheets bolted between two posts, a hazard stripe, razor coil on top
reset()
sheets = [((4.7, 0.25, 4.2), T(-2.5 + i * 5, 0.35 * (1 if i else -1), 2.3 + j * 4.3) @ RZ(0)) for i in range(2) for j in range(2)]
export("WallPanel", [mesh("Sheets", "Panel", sheets, jit=0.05),
                     mesh("Posts", "DarkMetal", [((0.6, 1.2, 9.0), T(-5, 0, 4.5)), ((0.6, 1.2, 9.0), T(5, 0, 4.5)), ((10.0, 0.5, 0.5), T(0, 0, 8.6))]),
                     mesh("Stripe", "Hazard", [((10.0, 0.15, 0.6), T(0, -0.75, 1.0))]),
                     mesh("Coil", "Chainlink", [], [(0.45, 9.4, T(0, 0, 9.3) @ RY(90))])])
# Hideout gate frame 12 x 1.5 x 10: posts either side of the 8-wide opening, lintel with lamp
reset()
export("GateFrame", [mesh("Posts", "DarkMetal", [((1.6, 1.6, 10.0), T(-4.8, 0, 5)), ((1.6, 1.6, 10.0), T(4.8, 0, 5)), ((12.0, 1.6, 1.2), T(0, 0, 9.6))]),
                     mesh("Plates", "Rust", [((1.8, 1.8, 0.4), T(-4.8, 0, 0.2)), ((1.8, 1.8, 0.4), T(4.8, 0, 0.2))]),
                     mesh("Lamp", "Neon", [((3.0, 0.3, 0.3), T(0, -0.9, 9.2))])])
# Raid arena wall segment 22 x 3 x 28: dark concrete slab with ribs and a red strip
reset()
export("ArenaWall", [mesh("Slab", "DarkConcrete", [((22.0, 2.4, 28.0), T(0, 0, 14))], jit=0.04),
                     mesh("Ribs", "DarkMetal", [((1.0, 3.0, 28.0), T(-11 + 5.5 * i, 0, 14)) for i in range(5)]),
                     mesh("Strip", "NeonRed", [((22.0, 0.2, 0.4), T(0, -1.55, 20))])])
# Raid arena pillar 6 x 6 x 14: steel column with a red crown band
reset()
export("ArenaPillar", [mesh("Column", "DarkMetal", [((5.0, 5.0, 14.0), T(0, 0, 7))]),
                       mesh("Base", "Steel", [((6.0, 6.0, 1.0), T(0, 0, 0.5)), ((6.0, 6.0, 0.8), T(0, 0, 13.6))]),
                       mesh("Band", "NeonRed", [((6.3, 6.3, 0.5), T(0, 0, 7.2))])])
# Raid gate 14 x 2 x 16: an arch of dark metal with a red glow seam (the portal part stays separate)
reset()
export("RaidGate", [mesh("Arch", "DarkMetal", [((2.0, 2.0, 16.0), T(-6, 0, 8)), ((2.0, 2.0, 16.0), T(6, 0, 8)), ((14.0, 2.0, 2.0), T(0, 0, 15))]),
                    mesh("Seam", "NeonRed", [((0.4, 2.2, 14.0), T(-6, 0, 7.5)), ((0.4, 2.2, 14.0), T(6, 0, 7.5)), ((12.0, 2.2, 0.4), T(0, 0, 14.2))]),
                    mesh("Cables", "Rust", [((0.3, 0.3, 6.0), T(-7.2, 0.5, 3) @ RY(8)), ((0.3, 0.3, 6.0), T(7.2, -0.5, 3) @ RY(-8))])])
print("COMPOUND DONE")
