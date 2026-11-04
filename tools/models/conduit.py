# The Conduit: the player's body (StarterCharacter). Same 15-limb R15 system as the enemy rigs (server/Rigs.lua
# joints it): a long techwear coat (split skirt, high collar, shoulder plates), hood over a respirator with a
# wraparound visor, tapered sleeves and trousers, gloves with knuckles, armoured boots with knee guards, an
# armband, and the stack port at the nape (the upload socket). Materials ConduitJacket, ConduitTrim and
# ConduitVisor are recoloured per life by the server, so every reboot looks a little different.
#
# v2 (2026-11-04, "not satisfied with the character models"): sculpted instead of boxes: every shape is a
# bevelled, tapered box, a tapered elliptical cylinder or a squashed sphere. Extras named after a limb
# ("LowerTorsoCoat", "LeftLowerLegKnee") ride on that limb (server/Rigs.lua), so the coat moves with the hips
# and the knee guards with the shins. Limb meshes keep their old bounding boxes: Rigs puts each joint at the
# child limb's top centre.
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

# ---------- shape primitives: each builds in its own bmesh, then is appended to the part's mesh ----------
def _append(dst, src):
    me = bpy.data.meshes.new("tmp")
    src.to_mesh(me)
    src.free()
    dst.from_mesh(me)
    bpy.data.meshes.remove(me)

def tbox(size, center, top=(1, 1), bottom=(1, 1), bev=0.08, rot=None, shift_top=(0, 0)):
    """Bevelled box; the top/bottom faces scaled (taper) and the top slid by shift_top (lean)."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        sx, sy = top if v.co.z > 0 else bottom
        v.co.x *= size[0] * sx
        v.co.y *= size[1] * sy
        v.co.z *= size[2]
        if v.co.z > 0:
            v.co.x += shift_top[0]
            v.co.y += shift_top[1]
    if bev > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges) + list(bm.verts), offset=bev, offset_type="OFFSET", segments=2, profile=0.5, affect="EDGES", clamp_overlap=True)
    m = Matrix.Translation(Vector(center))
    if rot:
        m = m @ Matrix.Rotation(math.radians(rot[1]), 4, rot[0])
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
    return bm

def tcyl(r_bottom, r_top, depth, center, axis="Z", seg=16, sx=1.0, sy=1.0, bev=0.0):
    """Tapered elliptical cylinder (x radius * sx, y radius * sy) along axis."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r_bottom, radius2=r_top, depth=depth)
    for v in bm.verts:
        v.co.x *= sx
        v.co.y *= sy
    if bev > 0:
        rim = [e for e in bm.edges if not e.is_boundary and len(e.link_faces) == 2 and abs(e.link_faces[0].normal.dot(e.link_faces[1].normal)) < 0.5]
        if rim:
            bmesh.ops.bevel(bm, geom=rim, offset=bev, offset_type="OFFSET", segments=2, profile=0.5, affect="EDGES", clamp_overlap=True)
    m = Matrix.Translation(Vector(center))
    if axis == "X":
        m = m @ Matrix.Rotation(math.pi / 2, 4, "Y")
    elif axis == "Y":
        m = m @ Matrix.Rotation(math.pi / 2, 4, "X")
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
    return bm

def ball(r, center, scale=(1, 1, 1), seg=16, rings=10, cut_below=None):
    """Squashed sphere; cut_below drops vertices under that local z (a dome)."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=r)
    if cut_below is not None:
        for v in bm.verts:
            if v.co.z < cut_below:
                v.co.z = cut_below
    for v in bm.verts:
        v.co.x *= scale[0]; v.co.y *= scale[1]; v.co.z *= scale[2]
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
    bmesh.ops.transform(bm, matrix=Matrix.Translation(Vector(center)), verts=bm.verts)
    return bm

def part(name, mat, shapes):
    bm = bmesh.new()
    for s in shapes:
        _append(bm, s)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
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
z_head = z_neck + L["head"] / 2
F = -1  # forward along -Y
parts = []

reset()
# ---------- torso ----------
# chest: broad at the shoulders, tapering to the waist, a little forward lean to the chest plate
parts.append(part("UpperTorso", "ConduitJacket", [
    tbox((W["torso"] * 0.98, W["depth"] * 0.98, L["uppertorso"]), (0, 0, z_waist + L["uppertorso"] / 2), top=(1.0, 1.0), bottom=(0.74, 0.86), bev=0.2),
    tbox((W["torso"] * 0.7, 0.2, 0.9), (0, F * W["depth"] * 0.46, z_waist + 0.85), top=(1.0, 1), bottom=(0.85, 1), bev=0.07),  # coat lapels
    tcyl(0.5, 0.56, 0.5, (0, 0.06, z_neck + 0.12), seg=18, sy=0.92, bev=0.05),                                             # high collar
]))
parts.append(part("UpperTorsoRig", "Strap", [
    tbox((W["torso"] * 0.52, 0.16, 0.4), (0, F * W["depth"] * 0.5, z_waist + 0.4), bev=0.05),                 # chest rig pouches
    tbox((0.16, 0.14, 1.55), (-0.42, F * W["depth"] * 0.52, z_waist + 0.78), rot=("Y", 18), bev=0.04),          # bandolier
    tbox((0.16, 0.14, 1.55), (0.0, W["depth"] * 0.5, z_waist + 0.78), rot=("Y", -18), bev=0.04),                 # strap over the back
]))
parts.append(part("UpperTorsoPlate", "Plate", [
    tbox((W["torso"] * 0.56, 0.14, 0.62), (0, F * W["depth"] * 0.5, z_neck - 0.45), top=(1.0, 1), bottom=(0.8, 1), bev=0.06),
]))
parts.append(part("UpperTorsoSeams", "ConduitTrim", [
    tbox((0.06, 0.06, 1.25), (0.2, F * W["depth"] * 0.53, z_waist + 0.75), bev=0.0),
    tbox((0.06, 0.06, 1.25), (-0.2, F * W["depth"] * 0.53, z_waist + 0.75), bev=0.0),
    tcyl(0.53, 0.53, 0.05, (0, 0.06, z_neck + 0.37), seg=18, sy=0.92),                                          # collar rim light
]))
parts.append(part("UpperTorsoPort", "Chrome", [tcyl(0.22, 0.22, 0.1, (0, W["depth"] * 0.5, z_neck - 0.12), axis="Y", seg=16, bev=0.02)]))
parts.append(part("UpperTorsoPortCore", "ConduitTrim", [tcyl(0.13, 0.13, 0.14, (0, W["depth"] * 0.52, z_neck - 0.12), axis="Y", seg=12)]))
# hips: trousers' seat, belt with a buckle and a hip pouch
parts.append(part("LowerTorso", "Cloth", [
    tbox((W["torso"] * 0.86, W["depth"] * 0.92, L["lowertorso"]), (0, 0, z_hip + L["lowertorso"] / 2), top=(1.0, 1.0), bottom=(0.92, 0.95), bev=0.14),
]))
parts.append(part("LowerTorsoBelt", "Strap", [
    tbox((W["torso"] * 0.9, W["depth"] * 0.98, 0.18), (0, 0, z_hip + 0.5), bev=0.04),
    tbox((0.36, 0.42, 0.34), (0.72, 0.05, z_hip + 0.3), bev=0.06),                                              # hip pouch
]))
parts.append(part("LowerTorsoBuckle", "Chrome", [tbox((0.26, 0.06, 0.16), (0, F * W["depth"] * 0.5, z_hip + 0.5), bev=0.02)]))
# the coat skirt: split at the front, longer at the back, flaring out at the hem
skirt = []
for sx in (-1, 1):
    skirt.append(tbox((0.72, 0.1, 1.05), (sx * 0.5, F * W["depth"] * 0.46, z_hip - 0.28), top=(1, 1), bottom=(1.12, 1), bev=0.03, shift_top=(-sx * 0.04, 0)))
    skirt.append(tbox((0.1, 0.92, 1.1), (sx * W["torso"] * 0.45, 0.02, z_hip - 0.3), top=(1, 1), bottom=(1, 1.12), bev=0.03, shift_top=(-sx * 0.05, 0)))
skirt.append(tbox((W["torso"] * 0.88, 0.1, 1.25), (0, W["depth"] * 0.47, z_hip - 0.38), top=(1, 1), bottom=(1.12, 1), bev=0.03, shift_top=(0, -0.06)))
parts.append(part("LowerTorsoCoat", "ConduitJacket", skirt))
parts.append(part("LowerTorsoHem", "ConduitTrim", [tbox((W["torso"] * 0.96, 0.12, 0.05), (0, W["depth"] * 0.48, z_hip - 0.98), bev=0.0)]))

# ---------- head: hood over a respirator, wraparound visor ----------
parts.append(part("Head", "Hood", [
    ball(0.5, (0, 0, z_head + 0.02), scale=(1.0, 1.08, 1.18), seg=18, rings=12),                                 # skull
    ball(0.6, (0, 0.08, z_head + 0.1), scale=(1.0, 1.06, 0.95), seg=18, rings=12, cut_below=-0.25),              # hood shell
    tbox((0.95, 0.5, 0.55), (0, 0.24, z_neck + 0.28), top=(1.05, 1), bottom=(0.9, 0.9), bev=0.12),               # hood drape at the nape
]))
parts.append(part("HeadRespirator", "Rubber", [
    tcyl(0.2, 0.15, 0.22, (0, F * 0.55, z_neck + 0.32), axis="Y", seg=16, sx=1.35, sy=0.85),
    tcyl(0.09, 0.09, 0.14, (-0.27, F * 0.52, z_neck + 0.27), axis="X", seg=12),
    tcyl(0.09, 0.09, 0.14, (0.27, F * 0.52, z_neck + 0.27), axis="X", seg=12),
]))
parts.append(part("HeadFilters", "Chrome", [
    tcyl(0.07, 0.07, 0.05, (-0.36, F * 0.52, z_neck + 0.27), axis="X", seg=10),
    tcyl(0.07, 0.07, 0.05, (0.36, F * 0.52, z_neck + 0.27), axis="X", seg=10),
]))
visor = []
for a in (-55, -33, -11, 11, 33, 55):  # facets bent around the face into one band
    r = math.radians(a)
    visor.append(tbox((0.21, 0.06, 0.13), (math.sin(r) * 0.54, F * math.cos(r) * 0.54, z_head + 0.1), bev=0.0, rot=("Z", -a)))
parts.append(part("HeadVisor", "ConduitVisor", visor))

# ---------- arms: tapered sleeves, shoulder plates, gloves with knuckles ----------
for side, sign in (("Left", -1), ("Right", 1)):
    x = sign * (W["torso"] / 2 + W["arm"] / 2 + 0.06)
    z_sh = z_neck - 0.22
    z_el = z_sh - L["upperarm"]
    z_wr = z_el - L["lowerarm"]
    parts.append(part(f"{side}UpperArm", "ConduitJacket", [
        tcyl(0.27, 0.31, L["upperarm"] - 0.2, (x, 0, z_sh - L["upperarm"] / 2 - 0.1), seg=16, sy=0.95),
        ball(0.33, (x, 0, z_sh - 0.3), scale=(1.0, 0.95, 0.9), seg=16, rings=10),                                 # deltoid
    ]))
    parts.append(part(f"{side}UpperArmPlate", "Plate", [
        ball(0.37, (x + sign * 0.03, 0, z_sh - 0.12), scale=(1.0, 1.0, 0.5), seg=18, rings=10, cut_below=-0.06),
        ball(0.36, (x + sign * 0.06, 0, z_sh - 0.3), scale=(1.0, 0.98, 0.42), seg=18, rings=10, cut_below=-0.06),
    ]))
    parts.append(part(f"{side}LowerArm", "ConduitJacket", [
        tcyl(0.23, 0.28, L["lowerarm"] - 0.1, (x, 0, z_el - L["lowerarm"] / 2 + 0.03), seg=16, sy=0.92),
        ball(0.27, (x, 0, z_el - 0.08), scale=(1, 0.95, 0.7), seg=14, rings=8),                                    # elbow
    ]))
    parts.append(part(f"{side}LowerArmCuff", "Strap", [tcyl(0.27, 0.27, 0.16, (x, 0, z_wr + 0.14), seg=16, sy=0.95, bev=0.03)]))
    parts.append(part(f"{side}Hand", "Rubber", [
        tbox((0.36, 0.3, L["hand"] * 0.75), (x, 0, z_wr - L["hand"] * 0.33), bottom=(0.95, 0.9), bev=0.08),
        tbox((0.34, 0.24, 0.14), (x, F * 0.04, z_wr - L["hand"] + 0.07), bev=0.05),                                 # curled fingers
        tbox((0.1, 0.12, 0.24), (x - sign * 0.2, F * 0.08, z_wr - 0.18), bev=0.03, rot=("Y", sign * 20)),          # thumb
    ]))
    parts.append(part(f"{side}HandKnuckles", "Plate", [tbox((0.34, 0.08, 0.12), (x, F * 0.16, z_wr - L["hand"] * 0.62), bev=0.025)]))
    if side == "Right":
        parts.append(part("RightLowerArmPlate", "Plate", [tbox((0.46, 0.3, 0.6), (x, F * 0.18, z_el - 0.48), top=(1, 1), bottom=(0.85, 0.9), bev=0.06)]))
    else:
        parts.append(part("LeftUpperArmBand", "ConduitTrim", [tcyl(0.325, 0.325, 0.09, (x, 0, z_sh - 0.62), seg=16, sy=0.97)]))

    # ---------- legs: tapered trousers, thigh pocket, knee guards, armoured boots ----------
    lx = sign * W["leg"] * 0.62
    z_kn = z_hip - L["upperleg"]
    parts.append(part(f"{side}UpperLeg", "Cloth", [
        tcyl(0.33, 0.41, L["upperleg"], (lx, 0, z_hip - L["upperleg"] / 2), seg=16, sy=1.02),
    ]))
    parts.append(part(f"{side}UpperLegPocket", "Strap", [tbox((0.16, 0.44, 0.42), (lx + sign * 0.38, 0, z_hip - 0.58), bev=0.05)]))
    parts.append(part(f"{side}LowerLeg", "Cloth", [
        tcyl(0.27, 0.33, L["lowerleg"], (lx, 0, z_kn - L["lowerleg"] / 2), seg=16, sy=1.04),
    ]))
    parts.append(part(f"{side}LowerLegKnee", "Plate", [
        ball(0.2, (lx, F * 0.3, z_kn - 0.1), scale=(1.0, 0.5, 1.15), seg=14, rings=8),
    ]))
    parts.append(part(f"{side}LowerLegBoot", "Boot", [
        tcyl(0.31, 0.34, 0.46, (lx, 0, L["foot"] + 0.21), seg=16, sy=1.06),
    ]))
    parts.append(part(f"{side}Foot", "Boot", [
        tbox((W["leg"] * 0.82, W["leg"] * 1.3, L["foot"] * 0.62), (lx, F * 0.14, L["foot"] * 0.42), top=(0.92, 0.85), bev=0.1),
        tbox((W["leg"] * 0.86, W["leg"] * 1.38, L["foot"] * 0.3), (lx, F * 0.15, L["foot"] * 0.15), bev=0.05),  # sole
    ]))
    parts.append(part(f"{side}FootCap", "Plate", [tbox((W["leg"] * 0.7, 0.3, 0.2), (lx, F * 0.58, L["foot"] * 0.42), bev=0.06)]))

h = z_neck + L["head"]
export_fbx(os.path.join(OUT, "Rig_Conduit.fbx"), parts)
render(os.path.join(OUT, "Rig_Conduit_preview.png"), parts, azimuth=0.55, elevation=0.15)
render(os.path.join(OUT, "Rig_Conduit_back.png"), parts, azimuth=3.6, elevation=0.15)
print("BUILT Conduit", len(parts), "parts, height", round(h, 2))
