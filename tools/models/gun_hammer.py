# The hammer-fired pistol: every part of the 1911A1 parts chart Andy sent (2026-11-11), numbered as on that chart,
# built with gunparts.py. Inches; Y forward, Z up, X right; bore on Z 0, breech face at Y 0.
# Options: barrel (length, 5.0 Government, 4.25 Commander), rail (a railed dust cover), threaded (barrel thread and
# no bushing collar), can (suppressor length), light, ring (a ring hammer instead of the spur).
import math
from mathutils import Vector, Matrix
from gunparts import Part, platform, suppressor, weapon_light, T, RX, RY, RZ, I4

TH = math.radians(18)                       # grip rake
OY, OZ = -1.253, -1.606                     # the grip axis' top (front strap meets the trigger guard at g(0.95, 0))
GM = T(0, OY, OZ) @ RX(-18)                 # grip-local (x, u forward, v up) -> gun space

def g(u, v):
    return (OY + u * math.cos(TH) + v * math.sin(TH), OZ - u * math.sin(TH) + v * math.cos(TH))

VARIANTS = {
    "Hammer1911": dict(barrel=5.0, chart=True, title="HAMMER-FIRED PISTOL  -  ALL 49 PARTS"),
    "HammerCommander": dict(barrel=4.25, ring=True),
    "Whisper": dict(barrel=5.0, rail=True, threaded=True, can=6.0, light=True, ring=False, chart=True,
                    title="THE WHISPER  -  HAMMER-FIRED, RAILED, THREADED, SUPPRESSOR AND LIGHT"),
    "HammerRail": dict(barrel=5.0, rail=True, light=True),
}

@platform("hammer", "Pistol", VARIANTS, origin=(0, OY, OZ))
def build(o):
    BL = o.get("barrel", 5.0)
    front = BL + 0.2                         # slide nose
    dust = BL - 0.55                         # end of the frame's dust cover
    rail = o.get("rail", False)
    P = []
    add = lambda p: (P.append(p), p)[1]

    # ---------------------------------------------------------------- slide group
    s = add(Part(42, "Slide", "Gunmetal", "Slide", explode=(0, 0, 7.6)))
    s.side([(-2.30, -0.36), (dust + 0.05, -0.36), (dust + 0.05, -0.98), (front, -0.98), (front, 0.60), (-2.30, 0.60)],
           0.92, bev=0.05)
    for sx in (-1, 1):                                       # the top edges: wide chamfers, as the slide is rounded over
        s.box((0.34, 20, 0.34), (0, 0, 0), M=T(sx * 0.46, 2, 0.60) @ RY(45), cut=True)
    s.span((-0.33, -1.95, -1.1), (0.33, front + 1, 0.33), cut=True)         # hollow inside (barrel, spring)
    s.cyl(0.36, 1.0, (0, front, 0), cut=True)                               # bushing seat
    s.cyl(0.25, 1.0, (0, front, -0.62), cut=True)                           # recoil plug seat
    s.span((0.12, -0.45, 0.02), (0.6, 0.78, 0.44), cut=True)               # ejection port (right)
    for k in range(10):                                                     # rear cocking serrations
        for sx in (-1, 1):
            s.span((sx * 0.46 - 0.04, -2.12 + k * 0.085, -0.28), (sx * 0.46 + 0.04, -2.08 + k * 0.085, 0.36), cut=True)
    s.span((-0.5, 0.15, -0.4), (-0.4, 0.5, -0.22), cut=True)                # slide stop notch (left)
    add(Part(12, "Front sight", "Gunmetal", "Slide", explode=(0, 0.72, 9.4))).side(
        [(front - 0.45, 0.58), (front - 0.12, 0.58), (front - 0.18, 0.78), (front - 0.38, 0.78)], 0.12, bev=0.015)
    rs = add(Part(33, "Rear sight", "Gunmetal", "Slide", explode=(0, -0.72, 9.4)))
    rs.side([(-2.22, 0.58), (-1.8, 0.58), (-1.88, 0.80), (-2.2, 0.80)], 0.62, bev=0.02)
    rs.span((-0.06, -2.4, 0.68), (0.06, -1.6, 0.9), cut=True)
    ex = add(Part(8, "Extractor", "Gunmetal", "Slide", explode=None))
    ex.cyl(0.07, 2.2, (0.24, -1.15, 0.22))
    ex.span((0.14, -0.12, 0.08), (0.30, 0.0, 0.24), bev=0.01)               # the claw
    add(Part(9, "Firing pin", "Gunmetal", "Slide", hidden=True, explode=None)).cyl(0.05, 2.0, (0, -1.25, 0)).cyl(
        0.09, 0.4, (0, -2.05, 0))
    add(Part(10, "Firing pin spring", "Gunmetal", "Slide", hidden=True, explode=None)).spring(
        0.09, 0.015, 1.2, 11, (0, -1.5, 0))
    add(Part(11, "Firing pin stop", "Gunmetal", "Slide", explode=None)).span(
        (-0.30, -2.34, -0.25), (0.30, -2.28, 0.42), bev=0.015)

    # ---------------------------------------------------------------- barrel group
    b = add(Part(1, "Barrel", "Gunmetal", "Barrel", explode=(0, 2.7, 3.6)))
    blen = BL + (0.55 if o.get("threaded") else 0.0)
    b.tube(0.29, 0.2, blen, (0, blen / 2, 0), seg=28)
    b.span((-0.30, 0.0, 0.0), (0.30, 0.85, 0.33), bev=0.04)                 # chamber hood
    for y in (0.95, 1.2):                                                   # locking lugs
        b.span((-0.22, y, 0.2), (0.22, y + 0.12, 0.4), bev=0.02)
    b.side([(0.12, -0.25), (0.62, -0.25), (0.55, -0.5), (0.3, -0.52)], 0.3, bev=0.02)   # lower lug
    if o.get("threaded"):
        for k in range(8):
            b.cyl(0.31, 0.03, (0, BL + 0.06 + k * 0.06, 0), seg=28)
    b.smooth = False
    add(Part(3, "Barrel link", "Gunmetal", "Barrel", hidden=True, explode=None)).rod(
        0.07, (0, 0.42, -0.42), (0, 0.45, -0.72), seg=8)
    add(Part(4, "Barrel link pin", "Gunmetal", "Barrel", hidden=True, explode=None)).rod(
        0.035, (-0.16, 0.42, -0.42), (0.16, 0.42, -0.42), seg=8)
    if not o.get("threaded"):
        bu = add(Part(2, "Barrel bushing", "Gunmetal", "Slide", explode=(0, 4.68, 3.6)))
        bu.tube(0.36, 0.29, 0.42, (0, front - 0.17, 0), seg=28)
        bu.span((-0.12, front - 0.38, -0.4), (0.12, front - 0.1, -0.3), bev=0.02)
    else:
        add(Part(2, "Barrel bushing", "Gunmetal", "Slide", explode=(0, 4.68, 3.6))).tube(0.36, 0.30, 0.3, (0, front - 0.12, 0), seg=28)
    pl = add(Part(30, "Recoil spring plug", "Gunmetal", "Slide", explode=(0, 5.4, 1.62)))
    pl.tube(0.24, 0.12, 0.42, (0, front - 0.17, -0.62), seg=20)
    pl.cyl(0.24, 0.04, (0, front - 0.0, -0.62), seg=20)
    add(Part(35, "Recoil spring", "Gunmetal", "Frame", hidden=True, explode=(0, 1.8, 2.2))).spring(
        0.2, 0.035, dust - 0.45, 15, (0, 0.6 + (dust - 0.45) / 2, -0.62))
    gd = add(Part(36, "Recoil spring guide", "Gunmetal", "Frame", hidden=True, explode=None))
    gd.cyl(0.08, 1.1, (0, 1.1, -0.62)).cyl(0.26, 0.08, (0, 0.55, -0.62), seg=20)
    gd.span((-0.1, 0.45, -0.95), (0.1, 0.6, -0.6))

    # ---------------------------------------------------------------- frame
    f = add(Part(34, "Frame", "Gunmetal", "Frame", explode=(0, 0, 0)))
    dz = -1.25 if rail else -0.98
    outline = [(dust, -0.36), (-2.30, -0.36), (-2.30, -0.95), g(-0.66, -0.05), g(-0.66, -3.0), g(0.95, -3.0), g(0.95, 0),
               (-0.2, -1.97), (1.55, -1.97), (1.85, -1.87), (1.97, -1.55), (1.92, dz), (dust, dz)]
    f.side(outline, 0.86, bev=0.04)
    f.side([(-0.25, -1.0), (1.62, -1.0), (1.74, -1.2), (1.72, -1.7), (1.55, -1.81), (-0.12, -1.81), (-0.32, -1.62)], 2,
           cut=True)                                                        # trigger guard opening
    f.span((0.2, -0.3, -2.1), (0.6, 2.1, -1.0), cut=True)                  # the guard is a narrow loop
    f.span((-0.6, -0.3, -2.1), (-0.2, 2.1, -1.0), cut=True)
    f.box((0.62, 1.32, 3.4), (0, -0.02, -1.95), M=GM, cut=True)             # magazine well
    f.cyl(0.25, dust + 0.5, (0, (dust + 0.5) / 2 + 0.3, -0.62), cut=True)  # recoil spring tunnel in the dust cover
    f.span((-0.12, -2.4, -0.9), (0.12, -1.9, -0.3), cut=True)               # hammer slot
    if rail:
        for k in range(4):                                                  # cross slots in the rail
            f.span((-0.6, dust - 1.6 + k * 0.38, dz - 0.05), (0.6, dust - 1.45 + k * 0.38, dz + 0.1), cut=True)
        for sx in (-1, 1):                                                  # the rail's dovetail grooves
            f.span((sx * 0.43 - 0.06, 1.95, dz + 0.12), (sx * 0.43 + 0.06, dust + 0.1, dz + 0.24), cut=True)
    add(Part(6, "Ejector", "Gunmetal", "Frame", hidden=True, explode=None)).span(
        (-0.32, -1.9, -0.36), (-0.14, -0.9, -0.14), bev=0.02)
    add(Part(7, "Ejector pin", "Gunmetal", "Frame", hidden=True, explode=None)).rod(
        0.03, (-0.43, -1.55, -0.5), (0.43, -1.55, -0.5), seg=6)

    # ---------------------------------------------------------------- hammer group
    hm = add(Part(14, "Hammer", "Gunmetal", "Hammer", explode=(0, -3.6, 2.88)))
    if o.get("ring"):
        hm.side([(-2.0, -0.85), (-2.0, -0.5), (-2.25, -0.2), (-2.55, 0.12), (-2.85, 0.18), (-2.95, -0.05),
                 (-2.7, -0.35), (-2.45, -0.62), (-2.35, -0.92)], 0.30, bev=0.025)
        hm.cyl(0.12, 1.0, (0, -2.72, 0.0), axis="X", cut=True)
    else:
        hm.side([(-2.0, -0.85), (-2.0, -0.5), (-2.2, -0.2), (-2.45, 0.12), (-2.78, 0.34), (-2.94, 0.28), (-2.86, 0.08),
                 (-2.56, -0.25), (-2.45, -0.6), (-2.35, -0.92)], 0.30, bev=0.025)
        for k in range(4):                                                  # spur checkering
            hm.span((-0.2, -2.9 + k * 0.05, 0.05 + k * 0.06), (0.2, -2.88 + k * 0.05, 0.4), cut=True)
    add(Part(15, "Hammer pin", "Gunmetal", "Frame", explode=None)).rod(0.06, (-0.45, -2.2, -0.68), (0.45, -2.2, -0.68))
    add(Part(16, "Hammer strut", "Gunmetal", "Frame", hidden=True, explode=None)).rod(
        0.04, (0, -2.25, -0.92), (0, *g(-0.82, -1.35)), seg=8)
    add(Part(17, "Hammer strut pin", "Gunmetal", "Frame", hidden=True, explode=None)).rod(
        0.025, (-0.12, -2.25, -0.88), (0.12, -2.25, -0.88), seg=6)
    sr = add(Part(39, "Sear", "Gunmetal", "Frame", hidden=True, explode=None))
    sr.side([(-1.98, -0.88), (-1.62, -0.85), (-1.6, -0.62), (-1.78, -0.6), (-1.98, -0.7)], 0.14, bev=0.01)
    add(Part(40, "Sear pin", "Gunmetal", "Frame", explode=None)).rod(0.05, (-0.45, -1.72, -0.76), (0.45, -1.72, -0.76))
    add(Part(5, "Disconnector", "Gunmetal", "Frame", hidden=True, explode=None)).side(
        [(-1.85, -1.25), (-1.65, -1.25), (-1.62, -0.48), (-1.8, -0.45)], 0.1, bev=0.01)
    sp = add(Part(41, "Sear spring", "Gunmetal", "Frame", hidden=True, explode=None))
    for x in (-0.12, 0.0, 0.12):
        sp.span((x - 0.05, -0.72, -1.5), (x + 0.05, -0.68, -0.25), M=GM)

    # ---------------------------------------------------------------- grip: safety, housing, mainspring, stocks
    gs = add(Part(13, "Grip safety", "Gunmetal", "Frame", explode=(0, -3.6, 0.36)))
    gs.side([(-2.30, -0.38), (-2.80, -0.42), (-2.94, -0.56), (-2.82, -0.76), g(-0.97, -0.1), g(-0.98, -1.25),
             g(-0.66, -1.25), g(-0.66, -0.05), (-2.30, -0.95)], 0.74, bev=0.05)
    mh = add(Part(27, "Mainspring housing", "Gunmetal", "Frame", explode=(0, -3.96, -2.16)))
    mh.side([(-0.66, -1.27), (-1.0, -1.3), (-1.06, -2.0), (-1.02, -2.7), (-0.97, -3.0), (-0.66, -3.0)], 0.74, bev=0.05, M=GM)
    for k in range(12):                                                     # checkering grooves
        mh.span((-0.4, -1.12, -1.45 - k * 0.12), (0.4, -1.0, -1.42 - k * 0.12), M=GM, cut=True)
    add(Part(24, "Mainspring", "Gunmetal", "Frame", hidden=True, explode=None)).spring(
        0.12, 0.025, 1.1, 10, (0, -0.82, -1.95), axis="Z", M=GM)
    add(Part(25, "Mainspring cap", "Gunmetal", "Frame", hidden=True, explode=None)).cyl(
        0.12, 0.12, (0, -0.82, -1.36), axis="Z", M=GM)
    add(Part(26, "Mainspring cap pin", "Gunmetal", "Frame", hidden=True, explode=None)).rod(
        0.025, (-0.12, *g(-0.82, -2.6)), (0.12, *g(-0.82, -2.6)), seg=6)
    add(Part(28, "Mainspring housing pin", "Gunmetal", "Frame", explode=None)).rod(
        0.05, (-0.43, *g(-0.82, -2.8)), (0.43, *g(-0.82, -2.8)))
    add(Part(29, "Mainspring housing pin retainer", "Gunmetal", "Frame", hidden=True, explode=None)).rod(
        0.04, (0, *g(-0.82, -2.7)), (0, *g(-0.82, -2.95)), seg=6)
    for num, sx, name in ((45, -1, "Stock, left hand"), (46, 1, "Stock, right hand")):
        st = add(Part(num, name, "Polymer", "Grips", explode=(0, 3.0, -3.0) if sx > 0 else (0, 6.5, -3.0)))
        st.side([(-0.6, -0.28), (0.72, -0.28), (0.82, -0.5), (0.82, -2.65), (0.7, -2.85), (-0.5, -2.85), (-0.62, -2.6)],
                0.13, x=sx * 0.495, bev=0.04, M=GM)
        for a in (35, -35):                                                 # checkering: two sets of crossed grooves
            for k in range(-9, 10):
                st.box((0.07, 5.0, 0.035), (0, 0, 0), M=GM @ T(sx * 0.565, 0.1, -1.55) @ RX(a) @ T(0, 0, k * 0.15), cut=True)
        for (u, v) in ((0.25, -0.55), (0.25, -2.55)):
            st.cyl(0.11, 0.3, (sx * 0.5, u, v), axis="X", M=GM, cut=True)   # screw counterbores
            add(Part(47, "Stock screw", "Gunmetal", "Frame", explode=None,
                     label="" if (sx < 0 or v < -1) else None)).cyl(0.1, 0.06, (sx * 0.55, u, v), axis="X", M=GM, seg=14)
            add(Part(48, "Screw bushing", "Gunmetal", "Frame", hidden=True, explode=None,
                     label="" if (sx < 0 or v < -1) else None)).cyl(0.07, 0.12, (sx * 0.43, u, v), axis="X", M=GM, seg=10)

    # ---------------------------------------------------------------- magazine, catch
    mg = add(Part(18, "Magazine assembly", "Gunmetal", "Magazine", explode=(0, -0.54, -6.48)))
    mg.box((0.58, 1.26, 3.0), (0, -0.02, -1.62), M=GM, bev=0.06)
    mg.span((-0.2, -0.6, -0.25), (0.2, 0.6, 0.1), M=GM, cut=True)          # feed lips open at the top
    mg.box((0.68, 1.5, 0.14), (0, 0.05, -3.07), M=GM, bev=0.05)            # base plate
    add(Part(22, "Magazine follower", "Gunmetal", "Magazine", hidden=True, explode=None)).box(
        (0.42, 1.1, 0.14), (0, 0, -0.32), M=GM, bev=0.03)
    add(Part(23, "Magazine spring", "Gunmetal", "Magazine", hidden=True, explode=None)).spring(
        0.2, 0.025, 2.5, 7, (0, -0.02, -1.7), axis="Z", M=GM @ Matrix.Diagonal((1, 2.4, 1, 1)))
    mc = add(Part(19, "Magazine catch", "Gunmetal", "Frame", explode=None))
    mc.cyl(0.12, 0.85, (-0.12, -0.55, -1.32), axis="X", seg=16).cyl(0.17, 0.12, (-0.5, -0.55, -1.32), axis="X", seg=20)
    add(Part(20, "Magazine catch lock", "Gunmetal", "Frame", hidden=True, explode=None)).span(
        (0.2, -0.62, -1.4), (0.4, -0.48, -1.24))
    add(Part(21, "Magazine catch spring", "Gunmetal", "Frame", hidden=True, explode=None)).spring(
        0.07, 0.015, 0.45, 8, (0.15, -0.55, -1.32), axis="X")

    # ---------------------------------------------------------------- controls on the left, the plunger tube
    add(Part(32, "Plunger tube", "Gunmetal", "Frame", explode=None)).cyl(0.1, 0.95, (-0.5, -1.25, -0.6), seg=14)
    add(Part(31, "Plunger spring", "Gunmetal", "Frame", hidden=True, explode=None)).spring(
        0.06, 0.012, 0.6, 9, (-0.5, -1.25, -0.6))
    add(Part(38, "Safety lock plunger", "Gunmetal", "Frame", hidden=True, explode=None)).cyl(
        0.06, 0.25, (-0.5, -1.62, -0.6), seg=10)
    add(Part(44, "Slide stop plunger", "Gunmetal", "Frame", hidden=True, explode=None)).cyl(
        0.06, 0.25, (-0.5, -0.86, -0.6), seg=10)
    sf = add(Part(37, "Safety lock", "Gunmetal", "Frame", explode=(0, -0.36, 2.34)))
    sf.side([(-2.38, -0.42), (-1.9, -0.42), (-1.45, -0.52), (-1.38, -0.66), (-1.9, -0.76), (-2.38, -0.88)], 0.08, x=-0.5,
            bev=0.02)
    sf.rod(0.07, (-0.5, -2.15, -0.64), (0.3, -2.15, -0.64))
    ss = add(Part(43, "Slide stop", "Gunmetal", "Frame", explode=(0, 5.8, 1.0)))
    ss.side([(0.65, -0.42), (0.3, -0.38), (-0.45, -0.46), (-0.62, -0.58), (-0.5, -0.74), (0.3, -0.78), (0.65, -0.8)], 0.08,
            x=-0.5, bev=0.02)
    ss.rod(0.07, (-0.5, 0.45, -0.70), (0.5, 0.45, -0.70))

    # ---------------------------------------------------------------- trigger
    tr = add(Part(49, "Trigger", "Gunmetal", "Trigger", explode=(0, 7.5, -0.6)))
    tr.side([(0.52, -1.02), (0.78, -1.02), (0.82, -1.3), (0.74, -1.62), (0.6, -1.6), (0.56, -1.3)], 0.36, bev=0.03)
    for k in range(5):
        tr.span((-0.3, 0.76, -1.12 - k * 0.1), (0.3, 0.86, -1.09 - k * 0.1), cut=True)
    for sx in (-1, 1):                                                      # the bow round the magazine well
        tr.span((sx * 0.34 - 0.03, -1.65, -1.12), (sx * 0.34 + 0.03, 0.6, -1.02))
    tr.span((-0.34, -1.68, -1.12), (0.34, -1.6, -1.02))

    # ---------------------------------------------------------------- muzzle and rail extras
    if o.get("can"):
        P.append(suppressor("S1", BL + 0.2, 0, length=o["can"]))
    if o.get("light") and rail:
        P.extend(weapon_light("L1", dust + 0.25, dz))
    return P
