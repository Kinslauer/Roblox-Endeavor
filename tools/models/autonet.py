# The Autonet 6 x 3 x 3 (x, y, height): a surgical table with restraint arms, a tool rack and a red lamp.
# Origin at the bottom centre, facing -Y. Run: blender -b --python autonet.py -> out/Hide_Autonet.fbx
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
import bmesh
from mathutils import Matrix
PAL = {"Chrome": (0.75, 0.78, 0.82), "DarkMetal": (0.14, 0.14, 0.16), "Steel": (0.30, 0.31, 0.34), "Strap": (0.16, 0.13, 0.10), "Red": (0.7, 0.12, 0.12), "WardenRed": (0.55, 0.08, 0.12)}
def mat(n):
    import bpy
    return bpy.data.materials.get(n) or material(n, PAL[n])
T = lambda x, y, z: Matrix.Translation((x, y, z))
RX = lambda d: Matrix.Rotation(math.radians(d), 4, "X")
def mesh(name, m, boxes=()):
    bm = bmesh.new()
    for size, M in boxes:
        bmesh.ops.create_cube(bm, size=1.0, matrix=M @ Matrix.Diagonal((size[0], size[1], size[2], 1)))
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.001)
    return obj_from_bmesh(name, bm, mat(m))
reset()
parts = [mesh("Slab", "Chrome", [((5.6, 2.2, 0.3), T(0, 0, 1.6))]),
         mesh("Base", "DarkMetal", [((5.0, 1.8, 1.4), T(0, 0, 0.7)), ((1.2, 1.2, 0.3), T(0, 0, 0.15))]),
         mesh("Arms", "Steel", [((0.2, 0.2, 2.2), T(-1.8, 1.3, 2.4) @ RX(-25)), ((0.2, 0.2, 2.2), T(1.8, 1.3, 2.4) @ RX(-25)), ((0.3, 0.3, 1.8), T(0, -1.3, 1.9) @ RX(30))]),
         mesh("Tools", "Chrome", [((0.12, 0.12, 0.7), T(-1.0 + i * 0.5, -1.35, 3.1)) for i in range(5)]),
         mesh("Straps", "Strap", [((0.5, 2.4, 0.08), T(-1.4, 0, 1.8)), ((0.5, 2.4, 0.08), T(1.4, 0, 1.8))]),
         mesh("Lamp", "WardenRed", [((0.6, 0.6, 0.15), T(0, 0, 3.6))]),
         mesh("Stand", "DarkMetal", [((0.1, 0.1, 2.0), T(2.6, 1.2, 1.0)), ((2.8, 0.1, 0.1), T(1.3, 1.2, 3.55))])]
export_fbx(os.path.join(OUT, "Hide_Autonet.fbx"), parts)
render(os.path.join(OUT, "Hide_Autonet_preview.png"), parts, azimuth=0.8, elevation=0.45)
print("BUILT Autonet")
