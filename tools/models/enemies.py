# Brute, Shocker and Warden rigs: the same R15 limb system as the Raider with different builds.
# Left limbs at -X (Roblox handedness), feet on z=0, upright A-pose. Extras weld to the nearest limb.
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
import bmesh
from mathutils import Matrix, Vector

PAL = {
    "Hood": (0.16, 0.15, 0.17), "Jacket": (0.24, 0.20, 0.17), "Cloth": (0.20, 0.19, 0.18), "Bandage": (0.66, 0.60, 0.50),
    "Skin": (0.62, 0.48, 0.38), "Boot": (0.10, 0.09, 0.09), "Goggle": (1.0, 0.45, 0.15), "Rust": (0.36, 0.20, 0.12), "Strap": (0.12, 0.11, 0.10),
    "Plate": (0.28, 0.30, 0.33), "ArcCoil": (0.1, 0.8, 1.0), "Chrome": (0.55, 0.57, 0.62), "WardenRed": (0.55, 0.08, 0.14), "Visor": (1.0, 0.1, 0.1),
    "Coat": (0.13, 0.12, 0.15), "Rubber": (0.09, 0.09, 0.1),
}

def part(name, mat, boxes, cyls=()):
    bm = bmesh.new()
    for size, center in boxes:
        m = Matrix.Translation(Vector(center)) @ Matrix.Diagonal((size[0], size[1], size[2], 1))
        bmesh.ops.create_cube(bm, size=1.0, matrix=m)
    for radius, depth, center, axis in cyls:
        m = Matrix.Translation(Vector(center))
        if axis == "X": m = m @ Matrix.Rotation(math.pi / 2, 4, "Y")
        elif axis == "Y": m = m @ Matrix.Rotation(math.pi / 2, 4, "X")
        bmesh.ops.create_cone(bm, cap_ends=True, segments=8, radius1=radius, radius2=radius, depth=depth, matrix=m)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.001)
    ob = obj_from_bmesh(name, bm, material(mat, PAL[mat]))
    ob.name = f"{name}_{mat}"
    return ob

def body(L, w, mats, extras):
    """Generic 15-limb body. L = segment lengths, w = widths, mats = material per limb, extras = fn(z) list."""
    parts = []
    z_hip = L["foot"] + L["lowerleg"] + L["upperleg"]
    z_waist = z_hip + L["lowertorso"]
    z_neck = z_waist + L["uppertorso"]
    parts.append(part("LowerTorso", mats["lower"], [((w["torso"] * 0.95, w["depth"], L["lowertorso"]), (0, 0, z_hip + L["lowertorso"] / 2))]))
    parts.append(part("UpperTorso", mats["upper"], [((w["torso"], w["depth"] * 1.1, L["uppertorso"]), (0, 0, z_waist + L["uppertorso"] / 2)), ((w["torso"] * 1.15, w["depth"] * 1.2, 0.5), (0, 0, z_neck - 0.3))]))
    parts.append(part("Head", mats["head"], [((w["head"], w["head"], L["head"]), (0, 0, z_neck + L["head"] / 2))]))
    for side, sign in (("Left", -1), ("Right", 1)):
        x = sign * (w["torso"] / 2 + w["arm"] / 2 + 0.1)
        z_sh = z_neck - 0.25
        parts.append(part(f"{side}UpperArm", mats["upperarm"], [((w["arm"], w["arm"], L["upperarm"]), (x, 0, z_sh - L["upperarm"] / 2))]))
        z_el = z_sh - L["upperarm"]
        parts.append(part(f"{side}LowerArm", mats["lowerarm"], [((w["arm"] * 0.9, w["arm"] * 0.9, L["lowerarm"]), (x, 0, z_el - L["lowerarm"] / 2))]))
        z_wr = z_el - L["lowerarm"]
        parts.append(part(f"{side}Hand", mats["hand"], [((w["arm"] * 0.8, w["arm"] * 0.6, L["hand"]), (x, 0, z_wr - L["hand"] / 2))]))
        lx = sign * w["leg"] * 0.65
        parts.append(part(f"{side}UpperLeg", mats["leg"], [((w["leg"], w["leg"] * 1.05, L["upperleg"]), (lx, 0, z_hip - L["upperleg"] / 2))]))
        z_kn = z_hip - L["upperleg"]
        parts.append(part(f"{side}LowerLeg", mats["leg"], [((w["leg"] * 0.9, w["leg"] * 0.95, L["lowerleg"]), (lx, 0, z_kn - L["lowerleg"] / 2))]))
        parts.append(part(f"{side}Foot", mats["foot"], [((w["leg"], w["leg"] * 1.5, L["foot"]), (lx, -0.15, L["foot"] / 2))]))
    for fn in extras:
        parts.extend(fn(dict(hip=z_hip, waist=z_waist, neck=z_neck, head_top=z_neck + L["head"]), w))
    return parts, z_neck + L["head"]

def export(name, parts, height):
    export_fbx(os.path.join(OUT, f"Rig_{name}.fbx"), parts)
    render(os.path.join(OUT, f"Rig_{name}_preview.png"), parts, azimuth=0.55, elevation=0.15)
    print("BUILT", name, len(parts), "parts, height", round(height, 2))

# ---------- Brute: huge, armored with scrap plates, a steel collar, bare bandaged fists
reset()
L = dict(foot=0.55, lowerleg=1.3, upperleg=1.4, lowertorso=1.0, uppertorso=2.2, head=1.2, upperarm=1.5, lowerarm=1.3, hand=0.7)
W = dict(torso=3.2, depth=1.7, head=1.4, arm=1.1, leg=1.1)
M = dict(lower="Cloth", upper="Jacket", head="Hood", upperarm="Plate", lowerarm="Bandage", hand="Skin", leg="Cloth", foot="Boot")
def brute_extras(z, w):
    return [
        part("ChestPlate", "Plate", [((w["torso"] * 0.9, 0.3, 1.6), (0, -w["depth"] * 0.6, z["waist"] + 1.1)), ((w["torso"] * 0.6, 0.3, 0.9), (0, -w["depth"] * 0.6 - 0.05, z["waist"] + 2.2))]),
        part("Collar", "Rust", [((w["torso"] * 0.7, w["depth"] * 0.9, 0.35), (0, 0, z["neck"] - 0.05))]),
        part("Pauldron", "Plate", [((1.5, 1.5, 0.5), (-(w["torso"] / 2 + 0.6), 0, z["neck"] - 0.1))]),
        part("Pipes", "Rust", [], cyls=[(0.12, 1.6, (w["torso"] / 2 + 0.3, 0.5, z["waist"] + 1.2), "Z")]),
        part("Visor", "Visor", [((0.9, 0.2, 0.25), (0, -w["head"] / 2 - 0.08, z["neck"] + 0.75))]),
    ]
parts, h = body(L, W, M, [brute_extras]); export("Brute", parts, h)

# ---------- Shocker: lean, long coat, rubber gloves, an arc coil pack on the back, glowing lines
reset()
L = dict(foot=0.4, lowerleg=1.1, upperleg=1.15, lowertorso=0.7, uppertorso=1.5, head=1.15, upperarm=1.1, lowerarm=1.05, hand=0.45)
W = dict(torso=1.8, depth=0.95, head=1.15, arm=0.6, leg=0.68)
M = dict(lower="Coat", upper="Coat", head="Hood", upperarm="Coat", lowerarm="Rubber", hand="Rubber", leg="Coat", foot="Boot")
def shocker_extras(z, w):
    return [
        part("CoilPack", "Plate", [((1.4, 0.7, 1.6), (0, w["depth"] * 0.75, z["waist"] + 0.8))], cyls=[(0.25, 1.2, (-0.35, w["depth"] * 0.75 + 0.2, z["waist"] + 1.9), "Z"), (0.25, 1.2, (0.35, w["depth"] * 0.75 + 0.2, z["waist"] + 1.9), "Z")]),
        part("CoilGlow", "ArcCoil", [((1.3, 0.12, 0.25), (0, w["depth"] * 0.75 + 0.42, z["waist"] + 0.5)), ((1.3, 0.12, 0.25), (0, w["depth"] * 0.75 + 0.42, z["waist"] + 1.1))]),
        part("ArmLine", "ArcCoil", [((0.12, 0.12, 0.9), (-(w["torso"] / 2 + w["arm"] / 2 + 0.1) - w["arm"] * 0.46, 0, z["neck"] - 0.25 - 0.55))]),
        part("Visor", "ArcCoil", [((0.8, 0.2, 0.2), (0, -w["head"] / 2 - 0.08, z["neck"] + 0.7))]),
    ]
parts, h = body(L, W, M, [shocker_extras]); export("Shocker", parts, h)

# ---------- Warden: towering, chrome plates over a red coat, a visor slit, a crest, hydraulic legs
reset()
L = dict(foot=0.6, lowerleg=1.6, upperleg=1.7, lowertorso=1.1, uppertorso=2.5, head=1.4, upperarm=1.7, lowerarm=1.5, hand=0.75)
W = dict(torso=3.4, depth=1.8, head=1.5, arm=1.2, leg=1.2)
M = dict(lower="WardenRed", upper="Chrome", head="Chrome", upperarm="Chrome", lowerarm="Plate", hand="Plate", leg="WardenRed", foot="Chrome")
def warden_extras(z, w):
    return [
        part("Crest", "Chrome", [((0.3, 1.4, 0.8), (0, 0.1, z["head_top"] + 0.3))]),
        part("Visor", "Visor", [((1.2, 0.2, 0.2), (0, -w["head"] / 2 - 0.08, z["neck"] + 0.85))]),
        part("Cape", "WardenRed", [((w["torso"] * 0.9, 0.2, 3.6), (0, w["depth"] * 0.65, z["neck"] - 2.0))]),
        part("Pauldrons", "Chrome", [((1.7, 1.7, 0.6), (-(w["torso"] / 2 + 0.7), 0, z["neck"] - 0.1)), ((1.7, 1.7, 0.6), ((w["torso"] / 2 + 0.7), 0, z["neck"] - 0.1))]),
        part("Hydraulics", "Plate", [], cyls=[(0.15, 1.4, (-w["leg"] * 0.65 - 0.5, 0.3, z["hip"] - 1.0), "Z"), (0.15, 1.4, (w["leg"] * 0.65 + 0.5, 0.3, z["hip"] - 1.0), "Z")]),
        part("CoreGlow", "Visor", [((0.6, 0.15, 0.6), (0, -w["depth"] * 0.56, z["waist"] + 1.3))]),
    ]
parts, h = body(L, W, M, [warden_extras]); export("Warden", parts, h)
print("ENEMIES DONE")
