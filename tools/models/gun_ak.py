# The Kalashnikov pattern rifle (AK-47 / AKM), from the parts library (gunparts.py). Inches; Y forward, Z up, X right;
# bore on Z 0; the receiver runs from Y -6.5 (rear trunnion) to Y 3.7 (the face of the front trunnion), where the
# barrel length is measured from.
# Components (see gunparts.COMPONENTS): Receiver = receiver, cover, stock, grip, magazine, carrier, rear sight;
# Barrel = barrel, handguards, gas tube and block, front sight, cleaning rod; Muzzle = the device on the threads.
# Options: barrel (inches), brake ("slant" AKM, "nut" AK-47), ribbed (AKM's stamped cover and magazine ribs).
import math
from gunparts import Part, platform, T, RX, RY, RZ, I4

OY, OZ = -2.55, -1.75                        # the top of the pistol grip: the model's origin
Y0, Y1 = -6.5, 3.7

NAMES = {1: "Receiver", 2: "Receiver cover", 3: "Rear trunnion", 4: "Front trunnion and rear sight block", 5: "Rear sight leaf",
         6: "Bolt carrier and piston", 7: "Charging handle", 8: "Bolt", 9: "Recoil spring and guide", 10: "Selector lever",
         11: "Trigger", 12: "Trigger guard", 13: "Magazine catch", 14: "Pistol grip", 15: "Grip screw", 16: "Buttstock",
         17: "Butt plate", 18: "Magazine", 19: "Barrel", 20: "Lower handguard", 21: "Upper handguard", 22: "Gas tube",
         23: "Gas block", 24: "Handguard retainer", 25: "Front sight block", 26: "Front sight post", 27: "Cleaning rod",
         28: "Muzzle device", 29: "Sling swivel", 30: "Hammer"}

VARIANTS = {
    "AK": dict(barrel=16.3, brake="slant", ribbed=True, chart=True, title="KALASHNIKOV PATTERN RIFLE  -  30 PARTS"),
    "AKShort": dict(barrel=12.4, brake="slant", ribbed=True),
    "AKLong": dict(barrel=23.2, brake="slant", ribbed=True),
    "AK47": dict(barrel=16.3, brake="nut", ribbed=False),
    "AK74": dict(chart=True, title="AK74", barrel=16.3, brake="74", ribbed=True, mag="74"),      # 5.45: a straighter plastic magazine, a long brake
}
# which component each moving group belongs to (gunparts.export_components)
COMPONENTS = {"Body": "Receiver", "Carrier": "Receiver", "Trigger": "Receiver", "Magazine": "Receiver", "Stock": "Receiver",
              "Barrel": "Barrel", "Muzzle": "Muzzle"}

def anchors(o):
    BL = o.get("barrel", 16.3)
    return {"Muzzle": (0, Y1 + BL - 0.6, 0), "Optic": (0, -2.6, 1.0), "Under": (0, Y1 + 3.4, -1.0), "MuzzleEnd": (0, Y1 + BL, 0)}

@platform("ak", "Rifle", VARIANTS, origin=(0, OY, OZ))
def build(o):
    BL = o.get("barrel", 16.3)
    P = []
    def part(n, mat, group, ex, hidden=False, label=None):
        p = Part(n, NAMES[n], mat, group, explode=ex, hidden=hidden, label=label)
        P.append(p)
        return p

    # ---------------------------------------------------------------- receiver
    r = part(1, "Gunmetal", "Body", (0, 0, 0))
    r.side([(Y0, -1.7), (Y1, -1.7), (Y1, 0.28), (Y0, 0.28)], 1.3, bev=0.05)
    r.span((-0.48, 0.45, -1.9), (0.48, 3.45, -0.6), cut=True)               # magazine well
    for sx in (-1, 1):                                                       # the dimple over the magazine well
        r.span((sx * 0.66 - 0.03, 1.0, -1.1), (sx * 0.66 + 0.03, 2.4, -0.55), cut=True)
    for y in (-0.9, -1.75, -0.2):                                            # axis pins and rivets
        r.rod(0.07, (-0.67, y, -0.95), (0.67, y, -0.95), seg=8)
    part(3, "Gunmetal", "Body", (0, -2.5, 0)).span((-0.62, Y0 - 0.05, -1.65), (0.62, Y0 + 1.1, 0.25), bev=0.04)
    c = part(2, "Gunmetal", "Body", (0, 0, 4.2))
    c.front([(-0.66, 0.2), (0.66, 0.2), (0.66, 0.62), (0.45, 0.95), (-0.45, 0.95), (-0.66, 0.62)], 7.5, y=Y0 + 0.1 + 3.75, bev=0.05)
    if o.get("ribbed", True):                                                # the stamped cover's cross ribs
        for k in range(4):
            c.span((-0.5, -5.2 + k * 1.5, 0.93), (0.5, -5.0 + k * 1.5, 0.99), bev=0.02)
    c.span((0.6, -0.9, 0.2), (0.75, 1.2, 0.6), cut=True)                     # the charging handle's slot
    t = part(4, "Gunmetal", "Body", (0, 2.5, 2.2))
    t.side([(1.1, 0.2), (Y1 + 0.25, 0.2), (Y1 + 0.25, 0.75), (Y1 - 0.2, 1.02), (1.1, 1.02)], 1.1, bev=0.05)
    part(5, "Gunmetal", "Body", (0, 2.5, 4.0)).side(
        [(1.35, 1.02), (Y1 - 0.1, 1.0), (Y1 - 0.1, 1.12), (1.6, 1.22), (1.35, 1.42)], 0.5, bev=0.02).span(
        (-0.07, 1.3, 1.25), (0.07, 1.5, 1.5), cut=True)
    s = part(10, "Gunmetal", "Body", None)                                   # selector: the long stamped lever on the right
    s.side([(-3.3, -0.25), (0.2, -0.55), (0.25, -0.85), (-0.6, -0.9), (-3.3, -0.5)], 0.06, x=0.69, bev=0.015)
    s.span((0.66, -0.05, -0.95), (0.9, 0.25, -0.75), bev=0.03)

    # ---------------------------------------------------------------- carrier group
    bc = part(6, "Gunmetal", "Carrier", (0, 0, 7.0))
    bc.span((-0.42, -3.6, 0.22), (0.42, 1.1, 0.8), bev=0.06)
    bc.cyl(0.24, 8.0, (0, 1.1 + 4.0, 0.72), seg=14)                          # the piston rod, inside the gas tube
    h = part(7, "Gunmetal", "Carrier", (2.0, 0, 7.0))
    h.span((0.4, 0.15, 0.3), (1.25, 0.6, 0.55), bev=0.06)
    h.cyl(0.2, 0.5, (1.3, 0.38, 0.42), axis="X", seg=14)
    part(8, "Gunmetal", "Carrier", (0, 3, 7.0), hidden=True).cyl(0.35, 2.6, (0, 0.4, 0.0), seg=14)
    part(9, "Gunmetal", "Carrier", None, hidden=True).spring(0.2, 0.03, 6.0, 24, (0, -3.2, 0.5))
    part(30, "Gunmetal", "Body", None, hidden=True).side([(-1.6, -1.3), (-1.1, -1.3), (-1.0, -0.4), (-1.5, -0.3)], 0.4, bev=0.02)

    # ---------------------------------------------------------------- trigger, guard, grip
    part(11, "Gunmetal", "Trigger", None).side(
        [(-0.95, -1.7), (-0.55, -1.7), (-0.42, -1.95), (-0.5, -2.45), (-0.62, -2.5), (-0.72, -2.1), (-0.95, -1.9)], 0.24, bev=0.025)
    g = part(12, "Gunmetal", "Body", (0, 0, -2.2))
    g.span((-0.3, -1.95, -2.85), (0.3, 0.3, -2.75), bev=0.03)
    g.span((-0.3, 0.18, -2.85), (0.3, 0.3, -1.7), bev=0.03)
    part(13, "Gunmetal", "Body", None).side([(0.3, -1.7), (0.55, -1.7), (0.5, -2.6), (0.2, -2.95), (0.12, -2.8), (0.32, -2.5)], 0.3, bev=0.03)
    GM = T(0, OY, OZ) @ RX(-16)
    gr = part(14, "Polymer" if o.get("ribbed", True) else "Wood", "Body", (0, -1.5, -3.2))
    gr.side([(-0.55, 0.12), (0.6, 0.12), (0.66, -0.6), (0.58, -1.6), (0.66, -2.9), (0.5, -3.55), (-0.55, -3.6), (-0.72, -3.0),
             (-0.66, -0.4)], 0.95, bev=0.14, M=GM)
    part(15, "Gunmetal", "Body", None, hidden=True).rod(0.08, (0, OY, OZ - 0.3), (0, OY - 0.9, OZ - 3.4), seg=8)

    # ---------------------------------------------------------------- stock
    st = part(16, "Wood", "Stock", (0, -5.0, 0))
    st.side([(Y0 + 0.9, 0.2), (Y0 - 1.0, 0.25), (Y0 - 9.2, -0.75), (Y0 - 9.3, -5.0), (Y0 - 8.2, -5.05), (Y0 - 2.4, -1.75),
             (Y0 + 0.9, -1.6)], 1.25, bev=0.2)
    part(17, "Gunmetal", "Stock", (0, -8.0, 0)).span((-0.66, Y0 - 9.5, -5.08), (0.66, Y0 - 9.25, -0.7), bev=0.06)
    part(29, "Gunmetal", "Stock", None).tube(0.32, 0.26, 0.12, (-0.68, Y0 - 6.5, -2.6), axis="X", seg=14)

    # ---------------------------------------------------------------- magazine: thirty rounds on a curve
    m74 = o.get("mag") == "74"
    mg = part(18, "Polymer" if m74 else "Gunmetal", "Magazine", (0, 1.0, -5.0))
    front, back = [], []
    R = 21.0 if m74 else 11.0                                                # the curve's radius; its centre lies ahead
    for k in range(11):
        th = (0.29 if m74 else 0.55) * k / 10
        by, bz = 0.45 + R * (1 - math.cos(th)), -1.15 - R * math.sin(th)
        back.append((by, bz))
        front.append((by + 2.85 * math.cos(th), bz + 2.85 * math.sin(th)))
    mg.side(front + back[::-1], 0.9, bev=0.06)
    if o.get("ribbed", True) and not m74:
        for k in (3, 5, 7):
            (bx, bz), (fx, fz) = back[k], front[k]
            for sx in (-1, 1):
                mg.rod(0.05, (sx * 0.46, bx + 0.25, bz), (sx * 0.46, fx - 0.25, fz), seg=6)
    mg.side([(back[-1][0] - 0.1, back[-1][1] + 0.1), (front[-1][0] + 0.12, front[-1][1] + 0.12),
             (front[-1][0] + 0.1, front[-1][1] - 0.12), (back[-1][0] - 0.15, back[-1][1] - 0.14)], 1.0, bev=0.04)
    mg.span((-0.2, front[0][0] - 0.1, -1.35), (0.2, front[0][0] + 0.25, -1.1), bev=0.03)    # the front lug

    # ---------------------------------------------------------------- barrel group
    b = part(19, "Gunmetal", "Barrel", (0, 9, 2.0))
    b.tube(0.36, 0.15, 1.0, (0, Y1 + 0.5, 0), seg=24)
    b.tube(0.3, 0.15, BL - 1.0, (0, Y1 + 1.0 + (BL - 1.0) / 2, 0), seg=24)
    HG0, HG1 = Y1 + 0.3, Y1 + 6.2                                            # handguards
    lh = part(20, "Wood", "Barrel", (0, 6, -1.6))
    lh.front([(-0.72, 0.1), (-0.72, -0.5), (-0.5, -0.95), (0.5, -0.95), (0.72, -0.5), (0.72, 0.1)], HG1 - HG0, y=(HG0 + HG1) / 2, bev=0.1)
    for sx in (-1, 1):                                                       # the palm swell
        lh.span((sx * 0.7 - 0.12, HG0 + 1.2, -0.62), (sx * 0.7 + 0.12, HG1 - 0.9, -0.2), bev=0.1)
    uh = part(21, "Wood", "Barrel", (0, 6, 4.4))
    uh.front([(-0.55, 0.3), (0.55, 0.3), (0.62, 0.8), (0.4, 1.22), (-0.4, 1.22), (-0.62, 0.8)], 4.9, y=HG0 + 0.6 + 2.45, bev=0.1)
    GB = Y1 + 7.6                                                            # gas block
    gt = part(22, "Gunmetal", "Barrel", (0, 6, 3.2))
    gt.tube(0.3, 0.25, GB - HG0 - 0.1, (0, (HG0 + GB) / 2, 0.72), seg=18)
    gb = part(23, "Gunmetal", "Barrel", (0, 9, 3.4))
    gb.side([(GB - 0.2, 0.25), (GB + 1.3, 0.25), (GB + 1.3, 0.5), (GB + 0.5, 1.05), (GB - 0.2, 1.05)], 0.66, bev=0.05)
    gb.cyl(0.4, 1.3, (0, GB + 0.55, 0), seg=18)
    hr = part(24, "Gunmetal", "Barrel", (0, 9, -1.6))
    hr.span((-0.6, HG1 - 0.05, -0.85), (0.6, HG1 + 0.4, 0.4), bev=0.05)
    FS = Y1 + BL - 2.6                                                       # front sight block
    fs = part(25, "Gunmetal", "Barrel", (0, 12, 3.4))
    fs.cyl(0.4, 1.3, (0, FS + 0.65, 0), seg=18)
    fs.side([(FS + 0.1, 0.3), (FS + 1.2, 0.3), (FS + 0.95, 1.2), (FS + 0.35, 1.2)], 0.4, bev=0.04)
    for sx in (-1, 1):                                                       # the sight's protecting ears
        fs.side([(FS + 0.3, 1.15), (FS + 1.0, 1.15), (FS + 0.85, 1.85), (FS + 0.45, 1.85)], 0.09, x=sx * 0.3, bev=0.02)
    part(26, "Gunmetal", "Barrel", None).cyl(0.05, 0.6, (0, FS + 0.65, 1.45), axis="Z", seg=8)
    part(27, "Gunmetal", "Barrel", (0, 9, -2.6)).rod(0.09, (0, HG1 + 0.3, -0.52), (0, Y1 + BL - 0.4, -0.52), seg=8)

    # ---------------------------------------------------------------- muzzle device (on the threads, Y1 + BL - 0.6)
    MZ = Y1 + BL - 0.6
    md = part(28, "Gunmetal", "Muzzle", (0, 15, 2.0))
    if o.get("brake") == "74":                                               # the long two-chamber brake
        md.tube(0.34, 0.16, 0.9, (0, MZ + 0.45, 0), seg=18)
        md.tube(0.44, 0.17, 2.3, (0, MZ + 2.0, 0), seg=20)
        md.span((-0.6, MZ + 1.2, -0.13), (0.6, MZ + 2.0, 0.13), cut=True)     # the side ports
        md.span((-0.13, MZ + 2.3, 0.1), (0.13, MZ + 2.9, 0.6), cut=True)      # the top vents
    elif o.get("brake", "slant") == "slant":
        md.side([(MZ, -0.36), (MZ + 0.95, -0.36), (MZ + 1.45, 0.2), (MZ + 1.2, 0.36), (MZ, 0.36)], 0.72, bev=0.06, M=T(0, 0, 0))
        md.cyl(0.17, 3.0, (0, MZ + 0.8, 0), seg=12, cut=True)
    else:
        md.tube(0.36, 0.16, 0.7, (0, MZ + 0.35, 0), seg=18)
    return P
