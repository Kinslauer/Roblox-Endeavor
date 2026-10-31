# Worn gear: armor pieces and cybernetics welded onto R15 limbs. Each model is centred on the limb it
# rides on (origin = limb centre), up = Blender Z, face = Blender -Y. Limb sizes assumed (studs):
# Head 1.2 cube, UpperTorso 2 x 1 x 1.6 (w, depth, h), UpperLeg 1 x 1 x 1.5, LowerArm 1 x 1 x 1.2.
# Run: blender -b --python worn.py -> out/Worn_<Id>.fbx
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
import bmesh
from mathutils import Matrix, Vector

PAL = {"Steel": (0.30, 0.31, 0.34), "DarkMetal": (0.14, 0.14, 0.16), "Rust": (0.36, 0.20, 0.12), "Plate": (0.38, 0.40, 0.44),
       "Strap": (0.16, 0.13, 0.10), "Cloth": (0.25, 0.23, 0.22), "Hood": (0.12, 0.11, 0.14), "Goggle": (1.0, 0.45, 0.15),
       "ArcCoil": (0.1, 0.8, 1.0), "Neon": (0.05, 0.75, 0.95), "Olive": (0.24, 0.27, 0.16), "Chrome": (0.75, 0.78, 0.82),
       "Visor": (0.9, 0.2, 0.2), "Canvas": (0.36, 0.38, 0.30), "WardenRed": (0.55, 0.08, 0.12)}
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
    export_fbx(os.path.join(OUT, f"Worn_{name}.fbx"), parts)
    render(os.path.join(OUT, f"Worn_{name}_preview.png"), parts, azimuth=0.8, elevation=0.4)
    print("BUILT", name)

H = 1.3  # helmet shell size (a little over the 1.2 head)
# ---- heads
reset(); export("ScavHelm", [mesh("Cap", "Cloth", [((H, H, 0.7), T(0, 0, 0.35))], jit=0.02),
                             mesh("Straps", "Strap", [((H + 0.05, 0.15, 0.25), T(0, 0, 0.1)), ((0.15, H + 0.05, 0.25), T(0, 0, 0.1))]),
                             mesh("Goggles", "Goggle", [((0.45, 0.2, 0.3), T(-0.3, -0.62, 0.15)), ((0.45, 0.2, 0.3), T(0.3, -0.62, 0.15))])])
reset(); export("PlatedHelm", [mesh("Shell", "Plate", [((H + 0.1, H + 0.1, 1.1), T(0, 0, 0.2)), ((H + 0.1, 0.3, 0.5), T(0, -0.55, -0.35))], jit=0.02),
                               mesh("Slit", "Visor", [((0.9, 0.1, 0.12), T(0, -0.72, 0.05))]),
                               mesh("Rivets", "DarkMetal", [((0.12, 0.12, 0.12), T(x, -0.7, 0.55)) for x in (-0.5, 0, 0.5)])])
reset(); export("ArcHood", [mesh("Hood", "Hood", [((H + 0.15, H + 0.15, 1.2), T(0, 0.05, 0.2)), ((H + 0.3, 0.6, 0.5), T(0, 0.4, -0.5))], jit=0.03),
                            mesh("Lines", "Neon", [((0.08, 0.6, 0.08), T(x, -0.1, 0.85)) for x in (-0.4, 0.4)] + [((0.9, 0.08, 0.08), T(0, -0.72, 0.5))])])
reset(); export("Helmet", [mesh("Shell", "Olive", [((H + 0.1, H + 0.1, 0.8), T(0, 0, 0.3)), ((H + 0.3, H + 0.3, 0.15), T(0, 0, -0.05))], jit=0.02),
                           mesh("Strap", "Strap", [((0.12, 0.12, 0.8), T(-0.6, 0, -0.4)), ((0.12, 0.12, 0.8), T(0.6, 0, -0.4))])])
# ---- chests (UpperTorso 2 wide, 1 deep, 1.6 tall)
reset(); export("ScrapVest", [mesh("Plates", "Rust", [((0.8, 0.15, 0.7), T(-0.5, -0.58, 0.2)), ((0.8, 0.15, 0.7), T(0.5, -0.58, 0.2)), ((1.6, 0.15, 0.5), T(0, -0.58, -0.45)), ((1.7, 0.15, 1.2), T(0, 0.58, 0))], jit=0.03),
                              mesh("Straps", "Strap", [((0.2, 1.2, 0.15), T(-0.6, 0, 0.75)), ((0.2, 1.2, 0.15), T(0.6, 0, 0.75)), ((2.1, 1.1, 0.2), T(0, 0, -0.65))])])
reset(); export("RiotPlate", [mesh("Plates", "Plate", [((2.1, 0.3, 1.5), T(0, -0.55, 0.05)), ((2.1, 0.3, 1.5), T(0, 0.55, 0.05)), ((0.4, 1.3, 1.5), T(-1.05, 0, 0.05)), ((0.4, 1.3, 1.5), T(1.05, 0, 0.05))], jit=0.02),
                              mesh("Collar", "DarkMetal", [((1.4, 1.2, 0.35), T(0, 0, 0.95))]),
                              mesh("Pads", "Plate", [((0.7, 1.1, 0.4), T(-1.35, 0, 0.75)), ((0.7, 1.1, 0.4), T(1.35, 0, 0.75))])])
reset(); export("ConduitHarness", [mesh("Straps", "Strap", [((0.25, 1.2, 1.7), T(-0.55, 0, 0) @ RY(12)), ((0.25, 1.2, 1.7), T(0.55, 0, 0) @ RY(-12)), ((2.1, 1.1, 0.25), T(0, 0, -0.5))]),
                                   mesh("Core", "ArcCoil", [], [(0.3, 0.2, T(0, -0.6, 0.2) @ RX(90))]),
                                   mesh("Lines", "Neon", [((0.06, 0.06, 1.2), T(-0.55, -0.6, 0)), ((0.06, 0.06, 1.2), T(0.55, -0.6, 0))]),
                                   mesh("Buckles", "Chrome", [((0.3, 0.1, 0.2), T(-0.55, -0.62, -0.5)), ((0.3, 0.1, 0.2), T(0.55, -0.62, -0.5))])])
reset(); export("FlakVest", [mesh("Vest", "Olive", [((2.1, 1.2, 1.5), T(0, 0, 0))], jit=0.03),
                             mesh("Pouches", "Canvas", [((0.5, 0.25, 0.5), T(x, -0.7, -0.35)) for x in (-0.6, 0, 0.6)]),
                             mesh("Collar", "Canvas", [((1.6, 1.1, 0.2), T(0, 0, 0.85))])])
reset(); export("SteelPlate", [mesh("Carrier", "Olive", [((2.15, 1.25, 1.5), T(0, 0, 0))], jit=0.02),
                               mesh("Plate", "Steel", [((1.5, 0.15, 1.1), T(0, -0.7, 0.1)), ((1.5, 0.15, 1.1), T(0, 0.7, 0.1))]),
                               mesh("Pouches", "Canvas", [((0.45, 0.3, 0.5), T(x, -0.8, -0.5)) for x in (-0.7, 0, 0.7)]),
                               mesh("Straps", "Strap", [((0.3, 1.3, 0.2), T(-0.7, 0, 0.8)), ((0.3, 1.3, 0.2), T(0.7, 0, 0.8))])])
# ---- legs (one UpperLeg 1 x 1 x 1.5; the same model goes on both legs)
reset(); export("ScrapGreaves", [mesh("Plates", "Rust", [((0.9, 0.15, 1.0), T(0, -0.55, 0)), ((0.3, 0.9, 0.8), T(-0.55, 0, -0.1))], jit=0.03),
                                 mesh("Straps", "Strap", [((1.1, 1.1, 0.15), T(0, 0, 0.5)), ((1.1, 1.1, 0.15), T(0, 0, -0.5))])])
reset(); export("ServoGreaves", [mesh("Frame", "DarkMetal", [((1.1, 1.1, 0.25), T(0, 0, 0.6)), ((1.1, 1.1, 0.25), T(0, 0, -0.6)), ((0.2, 0.2, 1.4), T(-0.55, -0.4, 0)), ((0.2, 0.2, 1.4), T(0.55, -0.4, 0))]),
                                 mesh("Piston", "Chrome", [], [(0.08, 1.2, T(0, -0.6, 0))]),
                                 mesh("Light", "Neon", [((0.3, 0.08, 0.1), T(0, -0.58, 0.62))])])
reset(); export("PlatedGreaves", [mesh("Plates", "Plate", [((1.15, 0.25, 1.4), T(0, -0.5, 0)), ((0.25, 1.0, 1.4), T(-0.55, 0, 0)), ((0.25, 1.0, 1.4), T(0.55, 0, 0))], jit=0.02),
                                  mesh("Knee", "DarkMetal", [((0.8, 0.3, 0.4), T(0, -0.62, -0.75))])])
# ---- cybernetics: optics on the head, arm pieces on the left lower arm, cores on the upper back
reset(); export("ReflexOptic", [mesh("Band", "DarkMetal", [((H, 0.1, 0.15), T(0, -0.62, 0.15)), ((0.1, 0.7, 0.15), T(-0.62, -0.3, 0.15))]),
                                mesh("Lens", "Goggle", [], [(0.17, 0.15, T(-0.3, -0.7, 0.15) @ RX(90))])])
reset(); export("TargetingLens", [mesh("Mount", "Chrome", [((0.25, 0.3, 0.3), T(0.45, -0.6, 0.2)), ((0.1, 0.5, 0.1), T(0.62, -0.3, 0.2))]),
                                  mesh("Lens", "Neon", [], [(0.14, 0.2, T(0.3, -0.72, 0.2) @ RX(90))])])
reset(); export("ServoArm", [mesh("Shell", "Chrome", [((1.1, 1.1, 1.1), T(0, 0, 0.05))], jit=0.01),
                             mesh("Joints", "DarkMetal", [((1.15, 1.15, 0.15), T(0, 0, 0.6)), ((1.15, 1.15, 0.15), T(0, 0, -0.5))]),
                             mesh("Piston", "Steel", [], [(0.07, 1.0, T(-0.56, 0, 0.05))])])
reset(); export("ArcGauntlet", [mesh("Shell", "DarkMetal", [((1.1, 1.1, 1.1), T(0, 0, 0.05))]),
                                mesh("Coils", "ArcCoil", [], [(0.6, 0.12, T(0, 0, z)) for z in (-0.25, 0.05, 0.35)]),
                                mesh("Fins", "Steel", [((0.1, 1.3, 0.6), T(-0.5, 0, 0.1)), ((0.1, 1.3, 0.6), T(0.5, 0, 0.1))])])
reset(); export("NeuralCore", [mesh("Unit", "DarkMetal", [((0.8, 0.3, 0.8), T(0, 0.62, 0.3))]),
                               mesh("Core", "Neon", [], [(0.2, 0.15, T(0, 0.8, 0.3) @ RX(90))]),
                               mesh("Cables", "Chrome", [((0.08, 0.3, 0.6), T(x, 0.6, 0.75) @ RX(-20)) for x in (-0.25, 0.25)])])
reset(); export("OverclockCore", [mesh("Unit", "Steel", [((0.9, 0.35, 0.9), T(0, 0.62, 0.25))]),
                                  mesh("Vents", "DarkMetal", [((0.7, 0.1, 0.08), T(0, 0.82, z)) for z in (0.0, 0.2, 0.4)]),
                                  mesh("Glow", "WardenRed", [], [(0.22, 0.15, T(0, 0.82, -0.1) @ RX(90))])])
print("WORN DONE")
