# The Raider: a scavenger in a hooded rag jacket, goggles, bandaged forearms, heavy boots.
# Built as R15 limb parts (one mesh each, upright A-pose, feet on z=0) so the game can joint them
# with Motor6Ds and play Roblox's standard R15 animations. Accessories (goggles, pouch) are extra
# parts the rig builder welds to their limb.
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
import bmesh
from mathutils import Matrix, Vector

PAL = {
    "Hood": (0.16, 0.15, 0.17), "Jacket": (0.24, 0.20, 0.17), "Cloth": (0.20, 0.19, 0.18), "Bandage": (0.66, 0.60, 0.50),
    "Skin": (0.62, 0.48, 0.38), "Boot": (0.10, 0.09, 0.09), "Goggle": (1.0, 0.45, 0.15), "Rust": (0.36, 0.20, 0.12), "Strap": (0.12, 0.11, 0.10),
}

def part(name, mat, boxes):
    """One limb = one mesh made of several boxes (size, center, optional z-rotation)."""
    bm = bmesh.new()
    for size, center, *rot in boxes:
        m = Matrix.Translation(Vector(center)) @ (Matrix.Rotation(rot[0], 4, "Y") if rot else Matrix.Identity(4)) @ Matrix.Diagonal((size[0], size[1], size[2], 1))
        bmesh.ops.create_cube(bm, size=1.0, matrix=m)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.001)
    ob = obj_from_bmesh(name, bm, material(mat, PAL[mat]))
    ob.name = f"{name}_{mat}"
    return ob

reset()
parts = []
# proportions (studs): feet on 0, hips ~2.4, shoulders ~4.3, head top ~5.9
L = dict(foot=0.45, lowerleg=1.0, upperleg=1.05, lowertorso=0.75, uppertorso=1.55, head=1.25, upperarm=1.05, lowerarm=0.95, hand=0.45)
z_hip = L["foot"] + L["lowerleg"] + L["upperleg"]
z_waist = z_hip + L["lowertorso"]
z_neck = z_waist + L["uppertorso"]

parts.append(part("LowerTorso", "Cloth", [((1.9, 1.0, L["lowertorso"]), (0, 0, z_hip + L["lowertorso"] / 2)), ((2.1, 1.15, 0.22), (0, 0, z_hip + 0.5))]))  # belt
parts.append(part("Pouch", "Rust", [((0.7, 0.45, 0.6), (0.75, -0.65, z_hip + 0.45))]))
parts.append(part("UpperTorso", "Jacket", [
    ((2.0, 1.1, L["uppertorso"]), (0, 0, z_waist + L["uppertorso"] / 2)),
    ((2.3, 1.3, 0.5), (0, 0, z_neck - 0.3)),                       # shoulder yoke
    ((0.5, 1.2, 1.3), (-0.55, -0.02, z_waist + 0.55)),              # jacket flaps hanging open
    ((0.5, 1.2, 1.3), (0.55, -0.02, z_waist + 0.55)),
    ((0.35, 0.3, 1.5), (0, -0.6, z_waist + 0.85)),                   # strap down the chest
]))
parts.append(part("Head", "Hood", [
    ((1.3, 1.3, L["head"]), (0, 0, z_neck + L["head"] / 2)),
    ((1.6, 1.5, 0.5), (0, 0.1, z_neck + L["head"] - 0.1)),           # hood crown
    ((1.6, 0.4, 0.9), (0, 0.75, z_neck + 0.6)),                      # hood back
    ((0.6, 0.6, 0.35), (0, -0.5, z_neck + 0.35)),                    # face mask
]))
parts.append(part("Goggles", "Goggle", [((0.9, 0.25, 0.3), (0, -0.72, z_neck + 0.85))]))
for side, sx in (("Left", -1), ("Right", 1)):
    x = sx * 1.3
    z_sh = z_neck - 0.25
    parts.append(part(f"{side}UpperArm", "Jacket", [((0.7, 0.7, L["upperarm"]), (x, 0, z_sh - L["upperarm"] / 2))]))
    z_el = z_sh - L["upperarm"]
    parts.append(part(f"{side}LowerArm", "Bandage", [((0.62, 0.62, L["lowerarm"]), (x, 0, z_el - L["lowerarm"] / 2)), ((0.7, 0.7, 0.18), (x, 0, z_el - 0.3)), ((0.7, 0.7, 0.18), (x, 0, z_el - 0.7))]))
    z_wr = z_el - L["lowerarm"]
    parts.append(part(f"{side}Hand", "Skin", [((0.55, 0.4, L["hand"]), (x, 0, z_wr - L["hand"] / 2))]))
    lx = sx * 0.5
    parts.append(part(f"{side}UpperLeg", "Cloth", [((0.8, 0.85, L["upperleg"]), (lx, 0, z_hip - L["upperleg"] / 2))]))
    z_kn = z_hip - L["upperleg"]
    parts.append(part(f"{side}LowerLeg", "Cloth", [((0.72, 0.78, L["lowerleg"]), (lx, 0, z_kn - L["lowerleg"] / 2))]))
    parts.append(part(f"{side}Foot", "Boot", [((0.8, 1.2, L["foot"]), (lx, -0.15, L["foot"] / 2)), ((0.85, 0.9, 0.5), (lx, 0.05, L["foot"] + 0.2))]))

export_fbx(os.path.join(OUT, "Rig_Raider.fbx"), parts)
render(os.path.join(OUT, "Rig_Raider_preview.png"), parts, azimuth=0.55, elevation=0.15)
print("RAIDER DONE", len(parts), "parts, height", z_neck + L["head"] + 0.2)
