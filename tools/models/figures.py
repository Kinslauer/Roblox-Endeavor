# Every character built on the figure library (figure.py). Colours are the final look (sRGB 0..1): the fabrics and
# the plate are neutral textures that the game tints (Assets.Skins[name].Tints mirrors the tints given here).
from figure import *

# The old rigs' measurements (see Skeleton): the figure library re-proportions them.
BUILDS = {
    "Conduit": dict(H=5.94, shoulder=1.32, arm=0.33, leg=0.41, stance=0.48, depth=0.46),
    "Raider": dict(H=6.2, shoulder=1.3, arm=0.35, leg=0.4, stance=0.5, depth=0.57),
    "Brute": dict(H=7.65, shoulder=2.25, arm=0.55, leg=0.55, stance=0.71, depth=0.85),
    "Shocker": dict(H=6.0, shoulder=1.3, arm=0.3, leg=0.34, stance=0.44, depth=0.48),
    "Warden": dict(H=8.9, shoulder=2.4, arm=0.6, leg=0.6, stance=0.78, depth=0.9),
    "Sentry": dict(H=6.03, shoulder=1.41, arm=0.33, leg=0.4, stance=0.5, depth=0.53),
}

@figure("Conduit", build=BUILDS["Conduit"])
def conduit(f):
    """The player: long hooded techwear coat, respirator, wraparound visor, plates at chest, shoulders and knees."""
    sk = f.sk
    JK, DARK, PLATE = (0.17, 0.18, 0.21), (0.10, 0.10, 0.115), (0.30, 0.31, 0.34)
    GLOW = (0.0, 0.85, 1.0)
    LEATHER = (0.62, 0.58, 0.55)
    f.trousers("Twill", tint=(0.13, 0.13, 0.145))
    f.boots("HideLeather", shaft=0.5, tint=LEATHER)
    f.jacket("Techcloth", tint=JK, sleeve="elbow")
    f.skirt("Techcloth", tint=JK, length=1.3)
    f.collar("Techcloth", tint=JK, height=0.34)
    f.forearms("Twill", tint=DARK)
    f.gloves("HideLeather", tint=LEATHER)
    f.head_core()
    f.hood("Techcloth", tint=DARK)
    f.respirator()
    f.visor(glow=GLOW)
    f.torso_plate(tint=PLATE)
    for side, sg in SIDES:
        f.pauldron(sg, tint=PLATE)
        f.knee(sg, tint=PLATE)
        f.band("LowerArm", sg, sk.wr[sg].z + 0.2, "HideLeather", height=0.1, off=0.05, piece="Straps", tint=LEATHER)
    f.limb_plate("LowerArm", 1, z0=sk.wr[1].z + 0.32, z1=sk.el[1].z - 0.12, mid=-60, half=75, piece="LowerArmPlates", tint=PLATE)
    f.belt(tint=LEATHER)
    f.strap("HideLeather", sk.z_neck - 0.32, -128, sk.z_waist + 0.02, -38, off=0.085, tint=LEATHER)
    f.strap("HideLeather", sk.z_neck - 0.32, 128, sk.z_waist + 0.02, 38, off=0.085, tint=LEATHER)
    for deg in (-112, -90, -68):
        f.pouch("HideLeather", sk.z_waist + 0.26, deg, size=(0.2, 0.1, 0.22), tint=LEATHER)
    f.pouch("HideLeather", sk.z_hip + 0.2, 0, size=(0.34, 0.14, 0.34), bone="LowerTorso", tint=LEATHER)
    for deg in (-60, -120):
        f.seam("ConduitTrim", deg, sk.z_waist + 0.12, sk.z_neck - 0.42, glow=GLOW)
    f.band("UpperArm", -1, sk.sh[-1].z - 0.68, "ConduitTrim", glow=GLOW, off=0.06)
    p, nrm = sk.torso_point(sk.z_neck - 0.34, 90, 0.07)
    f.disc("Stainless", p, nrm, 0.2, 0.07)
    f.disc("ConduitTrim", p + nrm * 0.05, nrm, 0.11, 0.04, piece="Trim", glow=GLOW)

def _basics(f, jacket, trousers, boots=(0.62, 0.58, 0.55), boot_mat="HideLeather"):
    f.detail = 0.7
    f.trousers("Twill", tint=trousers)
    f.boots(boot_mat, shaft=0.5 * f.S, tint=boots)
    f.jacket("Techcloth", tint=jacket, sleeve="elbow")

@figure("Raider", build=BUILDS["Raider"])
def raider(f):
    """A scavenger: hooded rag jacket, goggles, a cloth over the face, wrapped forearms and fists, one scrap pauldron."""
    sk, S = f.sk, f.S
    JK, RUST, LEATHER = (0.25, 0.20, 0.16), (0.42, 0.24, 0.15), (0.6, 0.55, 0.5)
    _basics(f, JK, (0.2, 0.19, 0.18))
    f.forearms("Gauze", wraps=True)
    f.gloves("Gauze", cuff=0.0)
    f.head_core()
    f.hood("Techcloth", tint=(0.16, 0.15, 0.17), drape=1.05)
    f.face_wrap("Gauze", tint=(0.5, 0.46, 0.38))
    f.goggles()
    f.pauldron(-1, tint=RUST, scale=1.1, layers=2, piece="Scrap")
    f.belt(tint=LEATHER)
    f.strap("HideLeather", sk.sh[1].z - 0.1, -128, sk.z_waist + 0.02, -38, off=0.085, tint=LEATHER)
    f.strap("HideLeather", sk.sh[1].z - 0.1, 128, sk.z_waist + 0.02, 38, off=0.085, tint=LEATHER)
    f.pouch("HideLeather", sk.z_hip + 0.2, 180, size=(0.36, 0.16, 0.36), bone="LowerTorso", tint=LEATHER)
    f.pouch("HideLeather", sk.z_waist + 0.3, -75, size=(0.24, 0.11, 0.28), tint=LEATHER)
    for side, sg in SIDES:
        f.band("LowerLeg", sg, sk.az + 0.55 * S, "HideLeather", height=0.09, off=0.07, piece="Straps", tint=LEATHER)

@figure("Brute", build=BUILDS["Brute"], over=dict(shoulder=0.74, arm=0.82, leg=0.82, depth=0.9, head=0.14))
def brute(f):
    """Huge: scrap plate over the chest and arms, a steel collar, pipes up the back, a slit helmet, wrapped fists."""
    sk, S = f.sk, f.S
    PLATE, RUST, LEATHER = (0.3, 0.31, 0.33), (0.4, 0.23, 0.14), (0.55, 0.5, 0.46)
    zs = sk.sh[1].z
    _basics(f, (0.24, 0.20, 0.17), (0.2, 0.19, 0.18))
    f.forearms("Gauze", wraps=True)
    f.gloves("Gauze", cuff=0.0)
    f.head_core()
    f.helmet("PlateSteel", tint=PLATE, cover=0.8, grow=1.2)
    f.visor("Visor", half=48, height=0.1 * S, drop=0.02, glow=(1.0, 0.1, 0.1), r=1.24)
    f.collar("PlateSteel", tint=RUST, height=0.3 * S, open_deg=0, g=0.16, piece="Collar")
    f.torso_plate(tint=PLATE, z0=sk.z_waist + 0.25 * S, z1=zs - 0.05, half=50, thick=0.09)
    f.torso_plate(tint=RUST, z0=sk.z_hip + 0.45 * S, z1=sk.z_waist + 0.3 * S, half=36, thick=0.07, off=0.1, piece="Scrap")
    f.torso_plate(tint=PLATE, z0=sk.z_waist + 0.4 * S, z1=zs - 0.1, half=44, thick=0.08, front=False)
    f.pauldron(-1, tint=PLATE, scale=1.25, layers=2)
    for side, sg in SIDES:
        f.limb_plate("UpperArm", sg, z0=sk.el[sg].z + 0.2 * S, z1=zs - 0.45 * S, mid=(0 if sg > 0 else 180), half=110, tint=(PLATE if sg > 0 else RUST), thick=0.07, piece=("Plates" if sg > 0 else "Scrap"))
        f.knee(sg, tint=PLATE)
        f.limb_plate("LowerLeg", sg, z0=sk.az + 0.5 * S, z1=sk.kn[sg].z - 0.3 * S, mid=-90, half=75, tint=RUST, thick=0.06, piece="Scrap")
    f.belt(tint=LEATHER, height=0.24 * S, off=0.09)
    for sx in (-1, 1):
        p, nrm = sk.torso_point(sk.z_waist + 0.2 * S, 90 + sx * 28, 0.2)
        f.cyl("Pipes", "PlateSteel", p, p + V(0, 0.05, 2.1 * S), 0.13 * S, "UpperTorso", tint=RUST)

@figure("Shocker", build=BUILDS["Shocker"])
def shocker(f):
    """Lean, in a long dark coat with rubber gauntlets; an arc coil pack on the back, lit lines, a narrow visor."""
    sk, S = f.sk, f.S
    COAT, ARC, PLATE = (0.13, 0.12, 0.16), (0.1, 0.8, 1.0), (0.26, 0.27, 0.3)
    zs = sk.sh[1].z
    _basics(f, COAT, (0.1, 0.1, 0.11))
    f.skirt("Techcloth", tint=COAT, length=1.55)
    f.collar("Techcloth", tint=COAT, height=0.36)
    f.forearms("Polymer", g=0.045)
    f.gloves("Polymer", cuff=0.3)
    f.head_core()
    f.hood("Techcloth", tint=(0.08, 0.08, 0.1))
    f.respirator(cans=False)
    f.visor("ArcCoil", half=44, height=0.09, drop=0.1, glow=ARC)
    f.belt(tint=(0.5, 0.5, 0.5))
    # the coil pack: a housing on the back, two coils rising from it, lit bars across it
    back, nrm = sk.torso_point(sk.z_waist + 0.65, 90, 0.07)
    f.box("Pack", "PlateSteel", (0.95, 0.42, 1.15), back + V(0, 0.2, 0), "UpperTorso", bev=0.06, tint=PLATE)
    for sx in (-1, 1):
        f.cyl("Pack", "PlateSteel", back + V(sx * 0.27, 0.26, 0.5), back + V(sx * 0.27, 0.26, 1.25), 0.14, "UpperTorso", tint=PLATE)
        f.cyl("Glow", "ArcCoil", back + V(sx * 0.27, 0.26, 1.25), back + V(sx * 0.27, 0.26, 1.36), 0.1, "UpperTorso", glow=ARC)
    for dz in (-0.3, 0.1):
        f.box("Glow", "ArcCoil", (0.8, 0.06, 0.12), back + V(0, 0.42, dz), "UpperTorso", bev=0.0, glow=ARC)
    for dz in (0.45, 0.62):
        f.band("UpperArm", -1, zs - dz, "ArcCoil", glow=ARC, off=0.06, height=0.06, piece="Glow")
    f.strap("HideLeather", zs - 0.1, -120, sk.z_waist + 0.3, -150, off=0.08, tint=(0.5, 0.5, 0.5))
    f.strap("HideLeather", zs - 0.1, -60, sk.z_waist + 0.3, -30, off=0.08, tint=(0.5, 0.5, 0.5))

@figure("Warden", build=BUILDS["Warden"], over=dict(shoulder=0.7, arm=0.76, leg=0.78, head=0.145, depth=0.86))
def warden(f):
    """Towering: bright plate over a red coat, a crested helm with one red slit, a cape, pistons at the thighs."""
    sk, S = f.sk, f.S
    RED, CHROME, DARK = (0.5, 0.07, 0.12), (0.5, 0.52, 0.56), (0.2, 0.2, 0.22)
    zs = sk.sh[1].z
    f.detail = 0.8
    f.trousers("Twill", tint=RED)
    f.boots("PlateSteel", shaft=0.75 * S, tint=CHROME)
    f.jacket("Techcloth", tint=RED, sleeve="elbow")
    f.skirt("Techcloth", tint=RED, length=1.5 * S, flare=0.3)
    f.forearms("Twill", tint=DARK)
    f.gloves("PlateSteel", tint=DARK, cuff=0.3 * S)
    f.head_core()
    f.helmet("PlateSteel", tint=CHROME, cover=0.95, grow=1.22)
    f.visor("Visor", half=52, height=0.09 * S, drop=0.0, glow=(1.0, 0.1, 0.1), r=1.26)
    f.box("Helmet", "PlateSteel", (0.12 * S, 0.95 * S, 0.5 * S), V(0, 0.08 * S, sk.zc + sk.hr * 1.2), "Head", bev=0.04, tint=CHROME)
    f.torso_plate(tint=CHROME, z0=sk.z_waist + 0.15 * S, z1=zs + 0.02, half=58, thick=0.1, off=0.09)
    f.torso_plate(tint=CHROME, z0=sk.z_waist + 0.15 * S, z1=zs + 0.02, half=58, thick=0.1, off=0.09, front=False)
    f.torso_plate(tint=DARK, z0=sk.z_hip + 0.5 * S, z1=sk.z_waist + 0.2 * S, half=40, thick=0.08, off=0.11, piece="Tasset")
    p, nrm = sk.torso_point(sk.z_waist + 0.75 * (zs - sk.z_waist), -90, 0.2)
    f.disc("Visor", p, nrm, 0.2 * S, 0.06, piece="Core", glow=(1.0, 0.1, 0.1))
    for side, sg in SIDES:
        f.pauldron(sg, tint=CHROME, scale=1.35, layers=2)
        out = 0 if sg > 0 else 180
        f.limb_plate("UpperArm", sg, z0=sk.el[sg].z + 0.15 * S, z1=zs - 0.75 * S, mid=out, half=120, tint=CHROME, thick=0.08)
        f.limb_plate("LowerArm", sg, z0=sk.wr[sg].z + 0.15 * S, z1=sk.el[sg].z - 0.1 * S, mid=out, half=150, tint=CHROME, thick=0.08, piece="LowerArmPlates")
        f.limb_plate("UpperLeg", sg, z0=sk.kn[sg].z + 0.25 * S, z1=sk.z_hip - 0.2 * S, mid=-90, half=80, tint=CHROME, thick=0.08)
        f.limb_plate("LowerLeg", sg, z0=sk.az + 0.75 * S, z1=sk.kn[sg].z - 0.28 * S, mid=-90, half=95, tint=CHROME, thick=0.08)
        f.knee(sg, tint=CHROME)
        hp = sk.hp[sg]
        f.cyl("Pistons", "Stainless", hp + V(sg * (sk.lr + 0.16), 0.12, -0.25 * S), hp + V(sg * (sk.lr + 0.1), 0.12, -1.55 * S), 0.09 * S, side + "UpperLeg")
    f.belt(tint=DARK, height=0.26 * S, off=0.1, buckle="Stainless")
    f.cape("Techcloth", tint=RED, length=4.6 * S / 1.5)

@figure("Sentry", build=BUILDS["Sentry"])
def sentry(f):
    """Transit security: dark uniform, plate vest front and back, a brimmed helmet with an amber strip, bracers and shin guards."""
    sk, S = f.sk, f.S
    COAT, PLATE, HELM, LEATHER, AMBER = (0.13, 0.12, 0.15), (0.28, 0.30, 0.33), (0.14, 0.14, 0.16), (0.3, 0.3, 0.3), (1.0, 0.45, 0.15)
    zs = sk.sh[1].z
    _basics(f, COAT, (0.2, 0.19, 0.18), boots=(0.3, 0.3, 0.3))
    f.forearms("Twill", tint=COAT)
    f.gloves("HideLeather", tint=LEATHER)
    f.head_core()
    f.helmet("PlateSteel", tint=HELM, cover=0.35, brim=0.1, grow=1.2)
    f.respirator(cans=False)
    f.visor("Goggle", half=56, height=0.11, drop=0.02, glow=AMBER, r=1.12)
    f.torso_plate(tint=PLATE, z0=sk.z_waist + 0.12, z1=zs - 0.08, half=52, thick=0.07)
    f.torso_plate(tint=PLATE, z0=sk.z_waist + 0.12, z1=zs - 0.08, half=52, thick=0.07, front=False)
    for sx in (-1, 1):
        f.strap("HideLeather", zs + 0.0, -90 + sx * 38, zs - 0.02, 90 - sx * 38, off=0.1, width=0.16, tint=LEATHER, steps=8)
    for deg in (-116, -90, -64):
        f.pouch("HideLeather", sk.z_waist + 0.02, deg, size=(0.22, 0.1, 0.24), off=0.09, tint=LEATHER)
    p, nrm = sk.torso_point(zs - 0.4, -62, 0.15)
    f.box("Badge", "SignWhite", (0.24, 0.03, 0.09), p, "UpperTorso", bev=0.0)
    p, nrm = sk.torso_point(zs - 0.32, -122, 0.2)
    f.box("Radio", "Polymer", (0.17, 0.12, 0.34), p, "UpperTorso", bev=0.03)
    f.cyl("Radio", "Polymer", p + V(-0.04, 0, 0.15), p + V(-0.04, 0, 0.55), 0.015, "UpperTorso", seg=6)
    f.belt(tint=LEATHER)
    f.pouch("HideLeather", sk.z_hip + 0.22, 0, size=(0.3, 0.14, 0.3), bone="LowerTorso", tint=LEATHER)
    f.pouch("HideLeather", sk.z_hip + 0.22, 180, size=(0.26, 0.14, 0.28), bone="LowerTorso", tint=LEATHER)
    for side, sg in SIDES:
        out = 0 if sg > 0 else 180
        f.pauldron(sg, tint=PLATE)
        f.limb_plate("LowerArm", sg, z0=sk.wr[sg].z + 0.2, z1=sk.el[sg].z - 0.15, mid=out, half=120, tint=PLATE, piece="LowerArmPlates")
        f.limb_plate("LowerLeg", sg, z0=sk.az + 0.5, z1=sk.kn[sg].z - 0.25, mid=-90, half=80, tint=PLATE)
        f.knee(sg, tint=PLATE)

# ---- The Front: the recruits of both sides. Tank-grown clones, so one body and no faces: the Union's wear dust
# goggles and a scarf, the Pact's a gas mask. Helmet, flak vest and plates are pieces of the body that the game shows
# only when the recruit owns them (Assets.Skins[..].Gear), so issued gear fits the body exactly.
BUILDS["Soldier"] = dict(H=6.0, shoulder=1.38, arm=0.34, leg=0.41, stance=0.5, depth=0.52)
LAY = Matrix.Rotation(math.radians(90), 4, "X")   # face down, head toward -Y
FALLEN = {"Head": [("Z", 55)], "UpperTorso": [("Z", 8)], "RightUpperArm": [("Y", -148)], "RightLowerArm": [("Y", -24)],
          "LeftUpperArm": [("Y", 52)], "LeftLowerArm": [("Y", 38)], "LeftUpperLeg": [("Y", 20)], "LeftLowerLeg": [("Y", -30)],
          "RightUpperLeg": [("Y", -7)], "RightLowerLeg": [("X", 14)]}
CRAWL = {"Head": [("X", 18)], "RightUpperArm": [("Y", -168)], "LeftUpperArm": [("Y", 96)], "LeftLowerArm": [("Y", 70)],
         "LeftUpperLeg": [("Y", 46)], "LeftLowerLeg": [("Y", -78)], "RightUpperLeg": [("Y", -4)]}
REACH = {"UpperTorso": [("X", -14), ("Z", -10)], "Head": [("X", 24)], "RightUpperArm": [("X", -152), ("Y", -8)], "RightLowerArm": [("X", -22)],
         "LeftUpperArm": [("X", 12), ("Y", 10)], "LeftLowerArm": [("X", -30)], "LeftUpperLeg": [("X", -8)], "RightUpperLeg": [("X", -2)],
         "LeftLowerLeg": [("X", 98)], "RightLowerLeg": [("X", 92)], "LeftFoot": [("X", 40)], "RightFoot": [("X", 40)]}
GEAR = ("Helmet", "Vest", "Plates")

def _soldier_gear(f, helm_tint, vest_tint, plate_tint, cover, brim):
    sk = f.sk
    zs = sk.sh[1].z
    f.helmet("PlateSteel", tint=helm_tint, cover=cover, brim=brim, grow=1.2)
    for front in (True, False):
        f.torso_plate("Twill", tint=vest_tint, z0=sk.z_waist + 0.02, z1=zs - 0.02, half=66, thick=0.06, off=0.09, front=front, piece="Vest")
        f.torso_plate("PlateSteel", tint=plate_tint, z0=sk.z_waist + 0.2, z1=zs - 0.22, half=38, thick=0.05, off=0.16, front=front, piece="Plates")
    for sx in (-1, 1):
        f.strap("Twill", zs + 0.02, -90 + sx * 36, zs + 0.0, 90 - sx * 36, off=0.115, width=0.3, tint=vest_tint, steps=8, piece="Vest", thick=0.05)

# The recruit is built in layers (Andy, 2026-11-12: "They need to be able to be stripped of all gear, so the base
# clothing layer should look more bare ... basic battle attire acquired after leaving the tank and entering the
# barracks. They also need rigging for cybernetics and large armor sets"):
#   Recruit   the bare clone body in regions, the tank wrap, and the battle attire (undershirt, trousers, boots, armband)
#   UnionKit / PactKit   everything a recruit can be stripped of: coat, face wear, webbing, helmet, vest, plates
#   CyberLimbs   an arm and a leg a side that take the place of the flesh ones
#   HeavyArmor   a large armour set over the whole body
# Each layer is its own skinned upload on the same 15 bones; the game shows and hides pieces (Assets.Skins[..].Groups
# and .Covers). BASE / the kit lists name the pieces of each layer.
BODY = ["Head", "Torso", "ArmL", "ArmR", "HandL", "HandR", "LegL", "LegR", "FootL", "FootR"]
ATTIRE = ["Singlet", "Trousers", "TrouserL", "TrouserR", "BootL", "BootR", "SoleL", "SoleR", "Armband"]
BASE = BODY + ["Under"] + ATTIRE
UNION_KIT = ["Coat", "LowerArmL", "LowerArmR", "GloveL", "GloveR", "Wrap", "GoggleRims", "Goggles", "GoggleStrap", "Webbing", "Fittings", "Canteen"]
PACT_KIT = ["Coat", "LowerArmL", "LowerArmR", "GloveL", "GloveR", "Mask", "MaskFittings", "Visor", "Straps", "Pouches", "Fittings", "Bedroll"]
ARMOUR = ["Helmet", "Vest", "Plates"]
CYBER = [p + sd for sd in "LR" for p in ("CyArm", "CyArmJoints", "CyLeg", "CyLegJoints")] + ["CyArmLHand", "CyArmRHand", "CyLegLFoot", "CyLegRFoot"]
HEAVY = ["Heavy", "HeavySkirt", "HeavyHelm", "HeavyVisor"]
FLESH = (0.66, 0.60, 0.57)

def _recruit_base(f, cloth, boot, band):
    """What every recruit is under its kit. Both sides share these meshes; the game tints the cloth by side."""
    f.detail = 0.8
    f.body("Flesh", tint=FLESH)
    f.under("Gauze", tint=(0.52, 0.5, 0.44))
    f.singlet("Twill", tint=tuple(c * 0.8 for c in cloth))
    f.trousers("Twill", tint=cloth)
    f.boots("HideLeather", shaft=0.55, tint=boot, g=0.03)
    f.split_legs()
    f.band("UpperArm", -1, f.sk.sh[1].z - 0.62, "Twill", tint=band, off=0.03, height=0.16, piece="Armband")
    f.anchor()

def _shown(*groups):
    return set(sum(groups, []))

@figure("Union", build=BUILDS["Soldier"],
        layers={"Recruit": BASE, "UnionKit": UNION_KIT + ARMOUR},
        looks={"bare": (_shown(BODY, ["Under"]), ("front", "back")),
               "attire": (_shown(["Head", "ArmL", "ArmR", "HandL", "HandR"], ATTIRE), ("front", "action")),
               "kit": (_shown(["Head"], ATTIRE, UNION_KIT, ARMOUR) - {"Singlet"}, ("front", "back"))},
        statics={"Fallen_Union": dict(angles=FALLEN, turn=LAY, tris=4200)})
def union(f):
    """The Union recruit's kit over the base: short olive field jacket, canvas webbing with pouches and a canteen, a
    scarf over the face, dust goggles; a brimmed steel helmet, flak vest and plates."""
    sk, S = f.sk, f.S
    OLIVE, DARK, WEB, BOOT, BLUE = (0.25, 0.28, 0.18), (0.16, 0.18, 0.13), (0.50, 0.46, 0.33), (0.2, 0.19, 0.18), (0.20, 0.36, 0.72)
    zs = sk.sh[1].z
    _recruit_base(f, OLIVE, BOOT, BLUE)
    f.jacket("Twill", tint=OLIVE, sleeve="elbow", cap=0.4)
    f.skirt("Twill", tint=OLIVE, length=0.42, flare=0.07, back_longer=0.0)
    f.collar("Twill", tint=OLIVE, height=0.16)
    f.forearms("Twill", tint=OLIVE, split=True)
    f.gloves("HideLeather", tint=BOOT, split=True)
    f.face_wrap("Gauze", tint=(0.46, 0.44, 0.34))
    f.goggles("GlassDark", glow=None, z=-0.04, strap_piece="GoggleStrap")
    f.belt("Twill", tint=WEB, piece="Webbing")
    for sx in (-1, 1):
        f.strap("Twill", zs - 0.06, -90 + sx * 36, sk.z_waist + 0.02, -90 + sx * 30, off=0.085, width=0.13, tint=WEB, piece="Webbing")
        f.strap("Twill", zs - 0.06, 90 - sx * 36, sk.z_waist + 0.02, 90 - sx * 12, off=0.085, width=0.13, tint=WEB, piece="Webbing")
    for deg in (-128, -106, -74, -52):
        f.pouch("Twill", sk.z_hip + 0.4, deg, size=(0.24, 0.13, 0.3), off=0.1, bone="LowerTorso", tint=WEB, piece="Webbing")
    p, nrm = sk.torso_point(sk.z_hip + 0.3, 62, 0.2)
    f.cyl("Canteen", "Twill", p + V(0, 0, -0.2), p + V(0, 0, 0.2), 0.17, "LowerTorso", tint=DARK)
    f.pouch("Twill", sk.z_hip + 0.3, 118, size=(0.34, 0.16, 0.34), off=0.1, bone="LowerTorso", tint=WEB, piece="Webbing")
    _soldier_gear(f, (0.23, 0.26, 0.17), DARK, (0.3, 0.31, 0.3), cover=-0.3, brim=0.08)

@figure("Pact", build=BUILDS["Soldier"],
        layers={"PactKit": PACT_KIT + ARMOUR},
        looks={"attire": (_shown(["Head", "ArmL", "ArmR", "HandL", "HandR"], ATTIRE), ("front",)),
               "kit": (_shown(["Head"], ATTIRE, PACT_KIT, ARMOUR) - {"Singlet"}, ("front", "back"))},
        statics={"Fallen_Pact": dict(angles=FALLEN, turn=LAY, tris=4200)})
def pact(f):
    """The Pact recruit's kit over the base: a long belted greatcoat with a high collar, a cross strap and a bedroll,
    a gas mask with one dark eye band; a deep steel helmet, flak vest and plates."""
    sk, S = f.sk, f.S
    COAT, LEATHER, BOOT, RED = (0.44, 0.38, 0.28), (0.34, 0.24, 0.17), (0.15, 0.14, 0.14), (0.70, 0.16, 0.14)
    zs = sk.sh[1].z
    _recruit_base(f, (0.3, 0.27, 0.22), BOOT, RED)
    f.jacket("Twill", tint=COAT, sleeve="elbow", cap=0.4)
    f.skirt("Twill", tint=COAT, length=1.5, flare=0.2)
    f.collar("Twill", tint=COAT, height=0.3)
    f.forearms("Twill", tint=COAT, split=True)
    f.gloves("HideLeather", tint=LEATHER, split=True)
    f.respirator(cans=True, fittings="MaskFittings")
    f.visor("GlassDark", half=50, height=0.13, drop=0.02, glow=None, r=1.08)
    f.belt("HideLeather", tint=LEATHER, height=0.2)
    f.strap("HideLeather", zs - 0.02, -128, sk.z_waist + 0.05, -40, off=0.085, tint=LEATHER)
    f.strap("HideLeather", zs - 0.02, 128, sk.z_waist + 0.05, 40, off=0.085, tint=LEATHER)
    for deg in (-122, -58):
        f.pouch("HideLeather", sk.z_hip + 0.36, deg, size=(0.34, 0.14, 0.3), off=0.1, bone="LowerTorso", tint=LEATHER)
    back, nrm = sk.torso_point(sk.z_waist + 0.2, 90, 0.2)
    f.cyl("Bedroll", "Twill", back + V(-0.55, 0.02, 0), back + V(0.55, 0.02, 0), 0.19, "UpperTorso", tint=(0.3, 0.31, 0.26))
    _soldier_gear(f, (0.26, 0.25, 0.22), (0.24, 0.22, 0.19), (0.27, 0.27, 0.28), cover=-0.18, brim=0.0)
    f.box("Helmet", "PlateSteel", (0.06, 0.62, 0.1), V(0, 0.06, sk.zc + sk.hr * 1.2), "Head", bev=0.03, tint=(0.26, 0.25, 0.22))

@figure("Augment", build=BUILDS["Soldier"],
        layers={"CyberLimbs": CYBER, "HeavyArmor": HEAVY},
        looks={"cyber": (_shown(["Head", "Torso", "ArmR", "HandR", "LegL", "FootL", "Under"], ["CyArmL", "CyArmJointsL", "CyArmLHand", "CyLegR", "CyLegJointsR", "CyLegRFoot"]), ("front", "action")),
               "cyber_attire": (_shown(["Head", "ArmR", "HandR"], ["Singlet", "Trousers", "TrouserL", "BootL", "SoleL", "Armband"], ["CyArmL", "CyArmJointsL", "CyArmLHand", "CyLegR", "CyLegJointsR", "CyLegRFoot"]), ("front",)),
               "heavy": (_shown(["Head", "ArmL", "ArmR", "HandL", "HandR"], ATTIRE, HEAVY), ("front", "back", "action"))})
def augment(f):
    """The base recruit with both add-on layers: cybernetic arms and legs, and the large armour set."""
    _recruit_base(f, (0.25, 0.28, 0.18), (0.2, 0.19, 0.18), (0.20, 0.36, 0.72))
    for side, sg in SIDES:
        f.cyber_arm(sg)
        f.cyber_leg(sg)
    f.heavy_armor()
