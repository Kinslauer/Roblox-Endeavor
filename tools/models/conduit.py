# The Conduit: the player's body (StarterCharacter). Same 15-limb R15 system as the enemy rigs (server/Rigs.lua
# joints it): techwear jacket with a high collar, hood over a respirator and a visor slit, cargo trousers,
# boots, gloves, an armband, and the stack port at the nape (the upload socket). Materials ConduitJacket,
# ConduitTrim and ConduitVisor are recoloured per life by the server, so every reboot looks a little different.
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
import bmesh
from mathutils import Matrix, Vector

PAL = {
    "ConduitJacket": (0.17, 0.18, 0.21), "ConduitTrim": (0.0, 0.85, 1.0), "ConduitVisor": (0.0, 0.85, 1.0),
    "Hood": (0.12, 0.12, 0.14), "Cloth": (0.16, 0.16, 0.17), "Boot": (0.08, 0.08, 0.08), "Strap": (0.10, 0.09, 0.09),
    "Plate": (0.28, 0.30, 0.33), "Rubber": (0.07, 0.07, 0.08), "Skin": (0.55, 0.42, 0.34), "Chrome": (0.55, 0.57, 0.62),
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
        bmesh.ops.create_cone(bm, cap_ends=True, segments=10, radius1=radius, radius2=radius, depth=depth, matrix=m)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.001)
    ob = obj_from_bmesh(name, bm, material(mat, PAL[mat]))
    ob.name = f"{name}_{mat}"
    return ob

# proportions close to a Roblox R15 avatar (about 5.3 studs), so tools, camera and doors feel normal.
# y = forward is -Y (the face); left limbs at -X (server/Rigs.lua swaps them if the import mirrors).
L = dict(foot=0.42, lowerleg=1.0, upperleg=1.05, lowertorso=0.7, uppertorso=1.5, head=1.2, upperarm=1.0, lowerarm=0.95, hand=0.42)
W = dict(torso=1.9, depth=1.0, head=1.2, arm=0.62, leg=0.78)
z_hip = L["foot"] + L["lowerleg"] + L["upperleg"]
z_waist = z_hip + L["lowertorso"]
z_neck = z_waist + L["uppertorso"]
parts = []

reset()
# torso: jacket body, high collar, chest rig, neon seams down the front, the stack port at the nape
parts.append(part("LowerTorso", "Cloth", [((W["torso"] * 0.92, W["depth"], L["lowertorso"]), (0, 0, z_hip + L["lowertorso"] / 2)),
                                           ((W["torso"] * 0.98, W["depth"] * 1.08, 0.2), (0, 0, z_hip + 0.55))]))  # belt
parts.append(part("UpperTorso", "ConduitJacket", [
    ((W["torso"], W["depth"] * 1.05, L["uppertorso"]), (0, 0, z_waist + L["uppertorso"] / 2)),
    ((W["torso"] * 1.08, W["depth"] * 1.12, 0.45), (0, 0, z_neck - 0.25)),                     # shoulder yoke
    ((W["torso"] * 0.62, W["depth"] * 0.95, 0.55), (0, 0.05, z_neck + 0.2)),                    # high collar
    ((0.55, 0.45, 1.0), (0.55, -W["depth"] * 0.5, z_waist + 0.75)),                             # jacket flap, right
]))
parts.append(part("ChestRig", "Strap", [((W["torso"] * 0.7, 0.18, 0.7), (0, -W["depth"] * 0.56, z_waist + 0.75)),
                                        ((0.22, 0.2, 1.5), (-0.45, -W["depth"] * 0.55, z_waist + 0.8))]))
parts.append(part("Seams", "ConduitTrim", [((0.08, 0.1, 1.3), (0.18, -W["depth"] * 0.56, z_waist + 0.8)),
                                           ((W["torso"] * 0.62, 0.1, 0.07), (0, -W["depth"] * 0.5, z_neck + 0.45))]))
parts.append(part("StackPort", "ConduitTrim", [], cyls=[(0.16, 0.12, (0, W["depth"] * 0.56, z_neck + 0.05), "Y")]))
parts.append(part("PortRing", "Chrome", [], cyls=[(0.24, 0.08, (0, W["depth"] * 0.55, z_neck + 0.05), "Y")]))
# head: hood over a respirator, visor slit
parts.append(part("Head", "Hood", [
    ((W["head"], W["head"], L["head"]), (0, 0, z_neck + L["head"] / 2)),
    ((W["head"] * 1.18, W["head"] * 1.1, 0.45), (0, 0.08, z_neck + L["head"] - 0.05)),         # hood crown
    ((W["head"] * 1.15, 0.35, 0.95), (0, W["head"] * 0.55, z_neck + 0.55)),                   # hood back
]))
parts.append(part("Respirator", "Rubber", [((0.75, 0.35, 0.45), (0, -W["head"] * 0.55, z_neck + 0.32))],
                  cyls=[(0.13, 0.25, (-0.32, -W["head"] * 0.62, z_neck + 0.28), "Y"), (0.13, 0.25, (0.32, -W["head"] * 0.62, z_neck + 0.28), "Y")]))
parts.append(part("Visor", "ConduitVisor", [((W["head"] * 0.82, 0.12, 0.2), (0, -W["head"] * 0.52, z_neck + 0.78))]))
# arms: jacket sleeves, gloves, a plate on the right forearm, an armband on the left
for side, sign in (("Left", -1), ("Right", 1)):
    x = sign * (W["torso"] / 2 + W["arm"] / 2 + 0.06)
    z_sh = z_neck - 0.22
    parts.append(part(f"{side}UpperArm", "ConduitJacket", [((W["arm"], W["arm"], L["upperarm"]), (x, 0, z_sh - L["upperarm"] / 2))]))
    z_el = z_sh - L["upperarm"]
    parts.append(part(f"{side}LowerArm", "ConduitJacket", [((W["arm"] * 0.92, W["arm"] * 0.92, L["lowerarm"]), (x, 0, z_el - L["lowerarm"] / 2)),
                                                           ((W["arm"] * 0.98, W["arm"] * 0.98, 0.16), (x, 0, z_el - L["lowerarm"] + 0.12))]))  # cuff
    z_wr = z_el - L["lowerarm"]
    parts.append(part(f"{side}Hand", "Rubber", [((W["arm"] * 0.82, W["arm"] * 0.62, L["hand"]), (x, 0, z_wr - L["hand"] / 2))]))
    if side == "Right":
        parts.append(part("ForearmPlate", "Plate", [((W["arm"] * 1.02, W["arm"] * 0.5, 0.55), (x, -W["arm"] * 0.3, z_el - 0.45))]))
    else:
        parts.append(part("Armband", "ConduitTrim", [((W["arm"] * 1.04, W["arm"] * 1.04, 0.1), (x, 0, z_sh - 0.35))]))
    # legs: cargo trousers with a thigh pocket, boots
    lx = sign * W["leg"] * 0.62
    parts.append(part(f"{side}UpperLeg", "Cloth", [((W["leg"], W["leg"] * 1.02, L["upperleg"]), (lx, 0, z_hip - L["upperleg"] / 2))]))
    parts.append(part(f"{side}Pocket", "Strap", [((0.2, W["leg"] * 0.62, 0.45), (lx + sign * W["leg"] * 0.55, 0, z_hip - 0.55))]))
    z_kn = z_hip - L["upperleg"]
    parts.append(part(f"{side}LowerLeg", "Cloth", [((W["leg"] * 0.9, W["leg"] * 0.94, L["lowerleg"]), (lx, 0, z_kn - L["lowerleg"] / 2)),
                                                    ((W["leg"] * 0.95, W["leg"] * 0.99, 0.38), (lx, 0, L["foot"] + 0.19))]))  # boot shaft
    parts.append(part(f"{side}Foot", "Boot", [((W["leg"] * 0.98, W["leg"] * 1.45, L["foot"]), (lx, -0.12, L["foot"] / 2))]))

h = z_neck + L["head"]
export_fbx(os.path.join(OUT, "Rig_Conduit.fbx"), parts)
render(os.path.join(OUT, "Rig_Conduit_preview.png"), parts, azimuth=0.55, elevation=0.15)
render(os.path.join(OUT, "Rig_Conduit_back.png"), parts, azimuth=3.6, elevation=0.15)
print("BUILT Conduit", len(parts), "parts, height", round(h, 2))
