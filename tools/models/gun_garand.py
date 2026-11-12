# The Garand pattern rifle: the M1 (en-bloc clip, eight rounds) and its box-magazine descendant, the M14. From the
# parts library (gunparts.py). Inches; Y forward, Z up, X right; bore on Z 0; the receiver runs from Y -4.6 to Y 1.6
# (the receiver ring's face), where the barrel length is measured from.
# Components: Receiver = receiver, bolt, operating rod handle, trigger group, the stock, the magazine;
# Barrel = barrel, front handguard, gas cylinder, front sight; Muzzle = gas cylinder lock / flash suppressor.
# Options: barrel (inches), mag (True = the M14's 20-round box), hider (the M14's slotted flash suppressor).
import math
from gunparts import Part, platform, T, RX, RY, RZ, I4

OY, OZ = -4.4, -1.55                         # the stock's wrist, where the hand closes: the model's origin
Y0, Y1 = -4.6, 1.6

NAMES = {1: "Receiver", 2: "Bolt", 3: "Operating rod", 4: "Rear sight", 5: "Trigger housing", 6: "Trigger guard",
         7: "Trigger", 8: "Safety", 9: "Stock", 10: "Butt plate", 11: "Rear handguard", 12: "Stock ferrule",
         13: "Clip latch", 14: "Magazine", 15: "Barrel", 16: "Front handguard", 17: "Lower band", 18: "Gas cylinder",
         19: "Front sight", 20: "Gas cylinder lock", 21: "Flash suppressor", 22: "Stacking swivel", 23: "Sling swivel",
         24: "Follower", 25: "Operating rod spring", 26: "Hammer"}

VARIANTS = {
    "Garand": dict(barrel=24.0, chart=True, title="GARAND PATTERN RIFLE  -  26 PARTS"),
    "GarandShort": dict(barrel=18.0),
    "GarandLong": dict(barrel=27.0),
    "M14": dict(barrel=22.0, mag=True, hider=True),
    "M14Short": dict(barrel=18.0, mag=True, hider=True),
    "M14Long": dict(barrel=26.0, mag=True, hider=True),
}
COMPONENTS = {"Body": "Receiver", "Carrier": "Receiver", "Trigger": "Receiver", "Magazine": "Receiver", "Stock": "Receiver",
              "Barrel": "Barrel", "Muzzle": "Muzzle"}

def anchors(o):
    BL = o.get("barrel", 24.0)
    return {"Muzzle": (0, Y1 + BL - 0.7, 0), "Optic": (0, -1.6, 0.85), "Under": (0, Y1 + 6.0, -1.25), "MuzzleEnd": (0, Y1 + BL, 0)}

@platform("garand", "Rifle", VARIANTS, origin=(0, OY, OZ))
def build(o):
    BL = o.get("barrel", 24.0)
    box = o.get("mag", False)
    P = []
    def part(n, mat, group, ex, hidden=False, label=None):
        p = Part(n, NAMES[n], mat, group, explode=ex, hidden=hidden, label=label)
        P.append(p)
        return p

    # ---------------------------------------------------------------- receiver and what rides on it
    r = part(1, "Gunmetal", "Body", (0, 0, 2.5))
    r.side([(Y0, -0.75), (Y1, -0.75), (Y1, 0.55), (0.2, 0.6), (-2.9, 0.5), (-3.3, 0.85), (Y0, 0.85)], 1.25, bev=0.06)
    r.span((-0.42, -2.7, 0.1), (0.42, 0.3, 0.9), cut=True)                  # the open top the clip or the bolt shows through
    r.cyl(0.62, 0.7, (0, Y1 - 0.1, 0), seg=24)                               # the receiver ring
    b = part(2, "Gunmetal", "Carrier", (0, 0, 5.5))
    b.cyl(0.4, 3.2, (0, -1.1, 0.12), seg=18)
    b.span((0.3, -0.2, 0.0), (0.75, 0.25, 0.25), bev=0.04)                   # the bolt's right lug, in the rod's cam
    op = part(3, "Gunmetal", "Carrier", (2.5, 2, 2.5))
    op.span((0.62, -0.6, -0.1), (0.8, 9.0, 0.22), bev=0.04)                  # the long rod along the right side
    op.side([(-0.75, 0.05), (-0.2, 0.05), (-0.25, 0.5), (-0.7, 0.5)], 0.5, x=1.0, bev=0.08)    # its handle
    rs = part(4, "Gunmetal", "Body", (0, -2, 5.0))
    rs.side([(Y0 + 0.15, 0.85), (Y0 + 1.3, 0.85), (Y0 + 1.2, 1.25), (Y0 + 0.85, 1.6), (Y0 + 0.5, 1.6), (Y0 + 0.25, 1.25)], 0.9, bev=0.05)
    rs.span((-0.07, Y0 + 0.4, 1.3), (0.07, Y0 + 1.0, 1.7), cut=True)
    for sx in (-1, 1):
        rs.cyl(0.22, 0.14, (sx * 0.55, Y0 + 0.75, 1.1), axis="X", seg=16)    # windage and elevation knobs
    part(26, "Gunmetal", "Body", None, hidden=True).side([(-3.6, -1.3), (-3.1, -1.3), (-3.0, -0.6), (-3.5, -0.5)], 0.4, bev=0.02)

    # ---------------------------------------------------------------- trigger group
    th = part(5, "Gunmetal", "Body", (0, 0, -3.0))
    th.side([(-4.3, -0.75), (-0.2, -0.75), (-0.2, -1.75), (-1.2, -1.95), (-4.3, -1.75)], 0.8, bev=0.04)
    tg = part(6, "Gunmetal", "Body", (0, 0, -4.2))
    tg.span((-0.3, -3.6, -2.75), (0.3, -1.2, -2.65), bev=0.03)
    tg.span((-0.3, -1.32, -2.75), (0.3, -1.2, -1.9), bev=0.03)
    tg.span((-0.3, -3.6, -2.75), (0.3, -3.48, -1.9), bev=0.03)
    part(7, "Gunmetal", "Trigger", None).side(
        [(-2.7, -1.75), (-2.3, -1.75), (-2.15, -2.0), (-2.25, -2.45), (-2.38, -2.5), (-2.48, -2.1), (-2.7, -1.95)], 0.24, bev=0.025)
    part(8, "Gunmetal", "Body", None).side([(-1.75, -1.95), (-1.5, -1.95), (-1.4, -2.55), (-1.6, -2.6)], 0.2, bev=0.03)

    # ---------------------------------------------------------------- stock: one long piece of walnut
    ST1 = Y1 + 7.6
    st = part(9, "Wood", "Stock", (0, -3.0, -1.5))
    st.side([(ST1, -0.2), (ST1, -1.2), (0.5, -1.55), (-1.2, -1.7), (-4.2, -1.6), (-5.6, -2.5), (-6.6, -2.7), (-16.6, -4.7),
             (-17.0, -4.6), (-17.2, -0.9), (-16.9, -0.75), (-9.0, -0.1), (-6.4, 0.2), (-5.2, 0.1), (Y0 + 0.2, -0.3)], 1.5, bev=0.25)
    st.span((-0.63, Y0 + 0.1, -0.8), (0.63, Y1 + 0.2, 1.0), cut=True)        # the receiver's bed
    st.span((-0.41, -4.4, -2.2), (0.41, -0.1, -0.5), cut=True)               # the trigger housing's mortise
    st.cyl(0.5, 9.0, (0, Y1 + 4.0, 0.0), cut=True)                           # the barrel channel
    part(10, "Gunmetal", "Stock", (0, -6.0, -1.5)).span((-0.72, -17.4, -4.75), (0.72, -17.15, -0.85), bev=0.07)
    part(23, "Gunmetal", "Stock", None).tube(0.34, 0.27, 0.12, (0, -13.0, -4.15), axis="X", seg=14)
    rh = part(11, "Wood", "Stock", (0, 3.0, 3.6))
    rh.front([(-0.7, -0.15), (0.7, -0.15), (0.72, 0.3), (0.45, 0.72), (-0.45, 0.72), (-0.72, 0.3)], 5.4, y=Y1 + 0.5 + 2.7, bev=0.12)
    part(12, "Gunmetal", "Stock", (0, 7.0, -1.5)).tube(0.82, 0.5, 0.35, (0, ST1 + 0.05, -0.55), seg=20)
    part(22, "Gunmetal", "Stock", None).tube(0.28, 0.22, 0.1, (0, ST1 + 0.3, -1.4), axis="X", seg=12)

    # ---------------------------------------------------------------- feed: the M1's clip stays inside; the M14's box hangs below
    if box:
        mg = part(14, "Gunmetal", "Magazine", (0, 0.5, -5.5))
        mg.side([(-2.75, -1.6), (0.15, -1.6), (0.6, -5.6), (-2.45, -5.9)], 0.95, bev=0.07)
        for k in range(3):
            for sx in (-1, 1):
                mg.rod(0.045, (sx * 0.49, -2.5 + k * 0.9, -1.9), (sx * 0.49, -2.2 + k * 0.9, -5.6), seg=6)
        mg.side([(-2.5, -5.85), (0.65, -5.55), (0.68, -5.75), (-2.52, -6.08)], 1.05, bev=0.04)
    else:
        part(14, "Gunmetal", "Magazine", (0, 0.5, 4.0), hidden=False).span((-0.38, -2.5, 0.0), (0.38, 0.1, 0.5), bev=0.05)   # the clip's top
        part(24, "Gunmetal", "Body", None, hidden=True).span((-0.35, -2.4, -0.6), (0.35, 0.0, -0.45))
    part(13, "Gunmetal", "Body", None).span((-0.74, -1.3, -0.35), (-0.62, -0.5, 0.05), bev=0.03)

    # ---------------------------------------------------------------- barrel group
    br = part(15, "Gunmetal", "Barrel", (0, 10, 1.5))
    br.tube(0.45, 0.15, 3.0, (0, Y1 + 1.5, 0), seg=24)
    br.tube(0.33, 0.15, BL - 3.0, (0, Y1 + 3.0 + (BL - 3.0) / 2, 0), seg=24)
    GC0 = Y1 + BL - 6.2                                                      # gas cylinder: under the barrel at the front
    HG0, HG1 = Y1 + 6.2, GC0 - 0.2
    if HG1 - HG0 > 1.0:
        fh = part(16, "Wood", "Barrel", (0, 10, 3.6))
        fh.front([(-0.62, -0.75), (0.62, -0.75), (0.68, 0.2), (0.42, 0.66), (-0.42, 0.66), (-0.68, 0.2)], HG1 - HG0, y=(HG0 + HG1) / 2, bev=0.12)
        fh.cyl(0.36, 60, (0, 0, 0), cut=True)
    part(17, "Gunmetal", "Barrel", (0, 8, 1.5)).tube(0.78, 0.4, 0.4, (0, HG0 - 0.15, -0.05), seg=20)
    gc = part(18, "Gunmetal", "Barrel", (0, 13, -1.5))
    gc.cyl(0.36, 5.4, (0, GC0 + 2.7, -0.78), seg=18)
    gc.span((-0.2, GC0, -0.6), (0.2, GC0 + 5.4, 0.0), bev=0.03)
    gc.tube(0.45, 0.3, 1.0, (0, GC0 + 4.9, 0), seg=18)
    fs = part(19, "Gunmetal", "Barrel", (0, 15, 3.4))
    FS = Y1 + BL - 1.7
    fs.side([(FS, 0.3), (FS + 0.9, 0.3), (FS + 0.8, 0.75), (FS + 0.1, 0.75)], 0.75, bev=0.04)
    fs.span((-0.04, FS + 0.25, 0.75), (0.04, FS + 0.65, 1.3), bev=0.01)
    for sx in (-1, 1):
        fs.side([(FS + 0.05, 0.7), (FS + 0.85, 0.7), (FS + 0.75, 1.35), (FS + 0.6, 1.45), (FS + 0.15, 1.2)], 0.08, x=sx * 0.33, bev=0.02)
    part(25, "Gunmetal", "Barrel", None, hidden=True).spring(0.2, 0.03, 8.0, 30, (0, Y1 + 5.0, -0.75))

    # ---------------------------------------------------------------- muzzle device (from Y1 + BL - 0.7)
    MZ = Y1 + BL - 0.7
    if o.get("hider"):
        md = part(21, "Gunmetal", "Muzzle", (0, 18, 1.5))
        md.tube(0.42, 0.17, 3.2, (0, MZ + 1.6, 0), seg=20)
        md.cyl(0.36, 0.5, (0, MZ + 0.25, -0.78), seg=14)                     # the bayonet lug's ring
        for k in range(5):
            md.box((0.13, 2.0, 0.6), (0, 0, 0), M=T(0, MZ + 1.9, 0) @ RY(72 * k) @ T(0, 0, 0.4), cut=True)
    else:
        md = part(20, "Gunmetal", "Muzzle", (0, 18, 1.5))
        md.tube(0.42, 0.17, 0.7, (0, MZ + 0.35, 0), seg=20)
        md.cyl(0.4, 0.6, (0, MZ + 0.3, -0.78), seg=16)
        md.span((-0.2, MZ, -0.7), (0.2, MZ + 0.6, -0.1), bev=0.03)
    return P
