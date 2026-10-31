# Conduit melee weapons + the arc pistol. Modelled along +Y (the blade/head points away from the
# grip) with the grip at the origin, so the game can weld the origin into a hand and point +Y
# forward. Run: blender -b --python weapons.py -> out/Wpn_<Id>.fbx
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
import bmesh
from mathutils import Matrix, Vector

PAL = {"Steel": (0.30, 0.31, 0.34), "Rust": (0.36, 0.20, 0.12), "Grip": (0.12, 0.11, 0.10), "Wood": (0.42, 0.30, 0.17),
       "ArcCoil": (0.1, 0.8, 1.0), "DarkMetal": (0.14, 0.14, 0.16), "Neon": (0.05, 0.75, 0.95), "Bandage": (0.66, 0.60, 0.50)}

def part(name, mat, boxes=(), cyls=()):
    bm = bmesh.new()
    for size, center in boxes:
        bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation(Vector(center)) @ Matrix.Diagonal((size[0], size[1], size[2], 1)))
    for radius, depth, center in cyls:  # along Y
        bmesh.ops.create_cone(bm, cap_ends=True, segments=8, radius1=radius, radius2=radius, depth=depth, matrix=Matrix.Translation(Vector(center)) @ Matrix.Rotation(math.pi / 2, 4, "X"))
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.001)
    ob = obj_from_bmesh(name, bm, material(mat, PAL[mat]))
    ob.name = f"{name}_{mat}"
    return ob

def export(wid, parts):
    export_fbx(os.path.join(OUT, f"Wpn_{wid}.fbx"), parts)
    render(os.path.join(OUT, f"Wpn_{wid}_preview.png"), parts, azimuth=0.9, elevation=0.5)
    print("BUILT", wid)

# grip spans y in [-0.6, 0.6]; business end extends +Y
reset(); export("PipeClub", [part("Grip", "Bandage", cyls=[(0.17, 1.3, (0, 0, 0))]), part("Shaft", "Rust", cyls=[(0.16, 3.2, (0, 2.2, 0))]), part("Head", "Steel", cyls=[(0.26, 0.9, (0, 3.9, 0))], boxes=[((0.5, 0.5, 0.3), (0, 3.6, 0))])])
reset(); export("RebarBlade", [part("Grip", "Bandage", cyls=[(0.14, 1.2, (0, 0, 0))]), part("Guard", "Rust", boxes=[((0.9, 0.25, 0.25), (0, 0.7, 0))]), part("Blade", "Steel", boxes=[((0.12, 3.6, 0.55), (0, 2.6, 0)), ((0.12, 0.9, 0.3), (0, 4.75, 0.1))]), part("Rebar", "Rust", cyls=[(0.07, 3.4, (0.1, 2.5, 0.2))])])
reset(); export("ShockBaton", [part("Grip", "Grip", cyls=[(0.16, 1.4, (0, 0, 0))]), part("Shaft", "DarkMetal", cyls=[(0.14, 2.6, (0, 1.95, 0))]), part("Coil", "ArcCoil", cyls=[(0.2, 0.25, (0, 1.4, 0)), (0.2, 0.25, (0, 2.0, 0)), (0.2, 0.25, (0, 2.6, 0))]), part("Tip", "Neon", cyls=[(0.1, 0.4, (0, 3.4, 0))])])
reset(); export("ScrapSpear", [part("Grip", "Bandage", cyls=[(0.13, 1.6, (0, 0, 0))]), part("Shaft", "Wood", cyls=[(0.12, 5.0, (0, 3.3, 0))]), part("Head", "Steel", boxes=[((0.1, 1.4, 0.5), (0, 6.4, 0)), ((0.3, 0.3, 0.3), (0, 5.8, 0))]), part("Binding", "Rust", cyls=[(0.16, 0.5, (0, 5.75, 0))])])
reset(); export("Sledge", [part("Grip", "Bandage", cyls=[(0.17, 1.6, (0, 0, 0))]), part("Shaft", "Wood", cyls=[(0.15, 3.6, (0, 2.6, 0))]), part("Head", "Steel", boxes=[((2.0, 0.9, 0.9), (0, 4.6, 0))]), part("Band", "Rust", boxes=[((2.1, 0.2, 1.0), (0, 4.6, 0))])])
reset(); export("ArcPistol", [part("Grip", "Grip", boxes=[((0.3, 1.0, 0.45), (0, -0.2, 0))]), part("Frame", "DarkMetal", boxes=[((0.35, 0.6, 1.5), (0, 0.5, 0.45))]), part("Barrel", "Steel", boxes=[((0.2, 0.2, 1.0), (0, 0.75, 1.5))]), part("Cell", "ArcCoil", boxes=[((0.2, 0.3, 0.6), (0, 0.85, 0.3))])])
# fists: nothing to draw
print("WEAPONS DONE")
