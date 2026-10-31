# The Front's firearms, held in the right hand. Modelled with the grip at the origin, barrel along
# Blender +Y (Roblox +Z), top along Blender +Z (Roblox +Y). Run: blender -b --python firearms.py
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
import bmesh
from mathutils import Matrix, Vector

PAL = {"Steel": (0.30, 0.31, 0.34), "DarkMetal": (0.14, 0.14, 0.16), "Wood": (0.42, 0.30, 0.17), "OldWood": (0.30, 0.24, 0.16),
       "Grip": (0.12, 0.11, 0.10), "Olive": (0.24, 0.27, 0.16), "Rust": (0.36, 0.20, 0.12)}
def mat(n):
    import bpy
    return bpy.data.materials.get(n) or material(n, PAL[n])
T = lambda x, y, z: Matrix.Translation((x, y, z))
RX = lambda d: Matrix.Rotation(math.radians(d), 4, "X")
def mesh(name, m, boxes=(), cyls=()):
    bm = bmesh.new()
    for size, M in boxes:
        bmesh.ops.create_cube(bm, size=1.0, matrix=M @ Matrix.Diagonal((size[0], size[1], size[2], 1)))
    for r, depth, M in cyls:  # along local Y
        bmesh.ops.create_cone(bm, cap_ends=True, segments=10, radius1=r, radius2=r, depth=depth, matrix=M @ RX(90))
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.001)
    return obj_from_bmesh(name, bm, mat(m))
def export(name, parts):
    export_fbx(os.path.join(OUT, f"Gun_{name}.fbx"), parts)
    render(os.path.join(OUT, f"Gun_{name}_preview.png"), parts, azimuth=0.9, elevation=0.4)
    print("BUILT", name)

# Common rifle recipe: receiver box above the grip, barrel forward, stock back, magazine below.
def rifle(name, barrel_len, stock_len, mag, wood, top_rail=False, bolt=False, long_handguard=False):
    metal, furniture = "DarkMetal", ("Wood" if wood == 1 else "OldWood" if wood == 2 else "Olive")
    parts = []
    parts.append(mesh("Receiver", metal, [((0.35, 2.2, 0.55), T(0, 0.6, 0.55))]))
    parts.append(mesh("Grip", "Grip", [((0.3, 0.45, 0.9), T(0, -0.1, -0.1) @ RX(-15))]))
    parts.append(mesh("Barrel", "Steel", [], [(0.07, barrel_len, T(0, 1.7 + barrel_len / 2, 0.72))]))
    parts.append(mesh("Handguard", furniture, [((0.34, 1.6 if not long_handguard else 2.4, 0.45), T(0, 2.5 if not long_handguard else 2.9, 0.6))]))
    parts.append(mesh("Stock", furniture, [((0.3, stock_len, 0.5), T(0, -0.5 - stock_len / 2, 0.5)), ((0.3, 0.5, 0.9), T(0, -0.5 - stock_len + 0.2, 0.25))]))
    if mag: parts.append(mesh("Mag", metal, [((0.28, 0.5, mag), T(0, 1.0, 0.55 - mag / 2 - 0.1) @ RX(-10))]))
    parts.append(mesh("Sights", "Steel", [((0.1, 0.1, 0.25), T(0, 1.5, 0.95)), ((0.1, 0.1, 0.25), T(0, 1.7 + barrel_len - 0.2, 0.9))]))
    if top_rail: parts.append(mesh("Carry", metal, [((0.2, 1.2, 0.2), T(0, 0.6, 0.95))]))
    if bolt: parts.append(mesh("Bolt", "Steel", [], [(0.06, 0.45, T(0.3, 0.3, 0.72) @ Matrix.Rotation(math.radians(90), 4, "Y"))]))
    return parts

reset(); export("AKM", rifle("AKM", 2.4, 1.6, 1.1, 1))
reset(); export("M16A1", rifle("M16A1", 2.8, 1.6, 0.9, 3, top_rail=True))
reset(); export("SKS", rifle("SKS", 2.9, 1.7, 0.45, 2, long_handguard=True))
reset(); export("M14", rifle("M14", 3.0, 1.8, 0.8, 2, long_handguard=True))
reset(); export("Mosin", rifle("Mosin", 3.6, 1.9, 0.0, 2, long_handguard=True, bolt=True))
def pistol(name, slide_len):
    return [mesh("Grip", "Grip", [((0.28, 0.45, 0.8), T(0, -0.05, -0.05) @ RX(-15))]),
            mesh("Slide", "DarkMetal", [((0.3, slide_len, 0.3), T(0, slide_len / 2 - 0.2, 0.5))]),
            mesh("Barrel", "Steel", [], [(0.05, 0.3, T(0, slide_len - 0.1, 0.5))]),
            mesh("Trigger", "Steel", [((0.08, 0.25, 0.25), T(0, 0.35, 0.2))])]
reset(); export("Makarov", pistol("Makarov", 1.1))
reset(); export("M1911", pistol("M1911", 1.4))
print("FIREARMS DONE")
