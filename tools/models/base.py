# The Front's faction bases: a concrete bunker with a sandbagged entrance, a flagpole and a locker
# terminal. Footprint 40 x 60 (x by depth), origin at the bottom centre, entrance toward +Y (the front).
# Run: blender -b --python base.py -> out/Base_<Name>.fbx
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
import bmesh
from mathutils import Matrix, Vector

PAL = {"Concrete": (0.45, 0.45, 0.47), "DarkConcrete": (0.22, 0.22, 0.25), "DarkMetal": (0.14, 0.14, 0.16), "Steel": (0.30, 0.31, 0.34),
       "Sandbag": (0.52, 0.46, 0.32), "Rust": (0.36, 0.20, 0.12), "Screen": (0.05, 0.3, 0.45), "Flag": (0.8, 0.8, 0.8), "OldWood": (0.30, 0.24, 0.16)}
def mat(n):
    import bpy
    return bpy.data.materials.get(n) or material(n, PAL[n])
T = lambda x, y, z: Matrix.Translation((x, y, z))
RX = lambda d: Matrix.Rotation(math.radians(d), 4, "X")
RZ = lambda d: Matrix.Rotation(math.radians(d), 4, "Z")
def mesh(name, m, boxes=(), cyls=(), jit=0.0, seed=1):
    bm = bmesh.new()
    for size, M in boxes:
        bmesh.ops.create_cube(bm, size=1.0, matrix=M @ Matrix.Diagonal((size[0], size[1], size[2], 1)))
    for r, depth, M in cyls:
        bmesh.ops.create_cone(bm, cap_ends=True, segments=12, radius1=r, radius2=r, depth=depth, matrix=M)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.001)
    ob = obj_from_bmesh(name, bm, mat(m))
    if jit: jitter(ob, jit, seed)
    return ob
def export(name, parts):
    export_fbx(os.path.join(OUT, f"Base_{name}.fbx"), parts)
    render(os.path.join(OUT, f"Base_{name}_preview.png"), parts, azimuth=0.7, elevation=0.5)
    print("BUILT", name)

# Bunker shell 40 x 60 x 12: thick walls, slit windows at the front, a wide doorway, roof slab with a lip
reset()
W, D, H, t = 40, 60, 12, 2.0
walls = [((W, t, H), T(0, D / 2, H / 2)), ((t, D, H), T(-W / 2 + t / 2, 0, H / 2)), ((t, D, H), T(W / 2 - t / 2, 0, H / 2))]
# front wall with a 10-wide doorway and slits
fy = -D / 2 + t / 2
walls += [((13, t, H), T(-13.5, fy, H / 2)), ((13, t, H), T(13.5, fy, H / 2)), ((10, t, 3), T(0, fy, H - 1.5))]
export("Bunker", [mesh("Walls", "Concrete", walls, jit=0.05),
                  mesh("Roof", "DarkConcrete", [((W + 2, D + 2, 1.2), T(0, 0, H + 0.6)), ((W + 2, 1.0, 1.5), T(0, -D / 2 - 0.5, H + 1.9)), ((W + 2, 1.0, 1.5), T(0, D / 2 + 0.5, H + 1.9))]),
                  mesh("Slits", "DarkMetal", [((3.0, t + 0.2, 0.8), T(x, fy, 7.5)) for x in (-15, -9, 9, 15)]),
                  mesh("Floor", "DarkConcrete", [((W - 2 * t, D - 2 * t, 0.3), T(0, 0, 0.15))]),
                  mesh("Bags", "Sandbag", [((6.0, 1.3, 2.0), T(-9, -D / 2 - 2.5, 1.0)), ((6.0, 1.3, 2.0), T(9, -D / 2 - 2.5, 1.0))], jit=0.06)])
# Flagpole 1 x 1 x 22 with a flag (coloured by faction material in-game)
reset()
export("Flag", [mesh("Pole", "Steel", [], [(0.15, 22, T(0, 0, 11))]),
                mesh("Base", "DarkConcrete", [((2.0, 2.0, 0.6), T(0, 0, 0.3))]),
                mesh("Cloth", "Flag", [((5.0, 0.08, 3.0), T(2.6, 0, 20) @ RZ(0))], jit=0.08)])
# Locker terminal 4 x 2 x 6: steel cabinet with a screen (the recruit app opens here)
reset()
export("Locker", [mesh("Cabinet", "DarkMetal", [((4.0, 2.0, 6.0), T(0, 0, 3))]),
                  mesh("Doors", "Steel", [((1.8, 0.1, 5.2), T(-1.0, -1.05, 3.0)), ((1.8, 0.1, 5.2), T(1.0, -1.05, 3.0))]),
                  mesh("Screen", "Screen", [((2.4, 0.1, 1.2), T(0, -1.1, 5.0))]),
                  mesh("Handles", "Rust", [((0.15, 0.2, 0.8), T(-0.2, -1.15, 3.0)), ((0.15, 0.2, 0.8), T(0.2, -1.15, 3.0))])])
print("BASE DONE")
