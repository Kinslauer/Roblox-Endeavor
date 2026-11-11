# The rifle: an AR-15 pattern carbine. The lower receiver parts (L1-L35) and the upper receiver parts (U1-U8) follow
# the two charts Andy sent (2026-11-11; "you can simplify the lower reciever"); B1-B10 are the rest of a rifle (barrel,
# barrel nut, handguard, gas block, muzzle device, bolt carrier, bolt, magazine, sights). Built with gunparts.py.
# Inches; Y forward, Z up, X right; bore on Z 0, the upper receiver's rear face at Y -3.75.
# Options: barrel (inches), rail (handguard length), can (suppressor length), light.
import math
from mathutils import Vector, Matrix
from gunparts import Part, platform, suppressor, weapon_light, T, RX, RY, RZ, I4

TH = math.radians(25)
OY, OZ = -1.75, -2.05
GM = T(0, OY, OZ) @ RX(-25)

def g(u, v):
    return (OY + u * math.cos(TH) + v * math.sin(TH), OZ - u * math.sin(TH) + v * math.cos(TH))

LOWER = {1: "Lower receiver", 2: "Buffer tube", 3: "Stock", 4: "Buffer spring", 5: "Buffer", 6: "End plate",
         7: "Castle nut", 8: "Pistol grip", 9: "Grip screw", 10: "Grip screw washer", 11: "Safety detent spring",
         12: "Safety detent", 13: "Trigger", 14: "Disconnector spring", 15: "Disconnector", 16: "Hammer",
         17: "Trigger spring", 18: "Hammer spring", 19: "Hammer and trigger pins", 20: "Safety selector",
         21: "Rear takedown pin", 22: "Front pivot pin", 23: "Takedown detent", 24: "Takedown detent spring",
         25: "Trigger guard", 26: "Trigger guard roll pin", 27: "Magazine catch", 28: "Magazine release button",
         29: "Magazine catch spring", 30: "Bolt catch", 31: "Bolt catch roll pin", 32: "Bolt catch plunger",
         33: "Bolt catch spring", 34: "Buffer retainer", 35: "Buffer retainer spring"}
UPPER = {1: "Upper receiver", 2: "Ejection port cover spring", 3: "Gas tube", 4: "Ejection port cover",
         5: "Forward assist spring", 6: "Forward assist", 7: "Charging handle", 8: "Forward assist roll pin"}
REST = {1: "Barrel", 2: "Barrel nut", 3: "Handguard", 4: "Gas block", 5: "Muzzle device", 6: "Bolt carrier",
        7: "Bolt", 8: "Magazine", 9: "Rear sight", 10: "Front sight"}

VARIANTS = {
    "Rifle16": dict(barrel=16.0, rail=10.0, chart=True, title="RIFLE  -  LOWER L1-L35, UPPER U1-U8, THE REST B1-B10"),
    "Rifle10": dict(barrel=10.5, rail=9.0, can=6.5, light=True),
    "Rifle20": dict(barrel=20.0, rail=13.0),
}

@platform("rifle", "Rifle", VARIANTS, origin=(0, OY, OZ))
def build(o):
    BL = o.get("barrel", 16.0)
    RL = o.get("rail", 10.0)
    P = []
    add = lambda p: (P.append(p), p)[1]
    def L(n, mat, group, ex, hidden=False, label=None):
        return add(Part(f"L{n}", LOWER[n], mat, group, explode=ex, hidden=hidden, label=label))
    def U(n, mat, group, ex, hidden=False, label=None):
        return add(Part(f"U{n}", UPPER[n], mat, group, explode=ex, hidden=hidden, label=label))
    def B(n, mat, group, ex, hidden=False, label=None):
        return add(Part(f"B{n}", REST[n], mat, group, explode=ex, hidden=hidden, label=label))
    Y0, Y1 = -3.75, 3.4                     # upper receiver rear and front

    # ---------------------------------------------------------------- upper receiver
    u = U(1, "Gunmetal", "Upper", (0, 0, 6))
    u.front([(-0.45, -0.62), (0.45, -0.62), (0.5, -0.2), (0.45, 0.35), (0.3, 0.55), (-0.3, 0.55), (-0.45, 0.35), (-0.5, -0.2)],
            Y1 - Y0, y=(Y0 + Y1) / 2, bev=0.04)
    u.span((-0.42, Y0, 0.55), (0.42, Y1, 0.92), bev=0.03)                  # the flat top rail
    for k in range(int((Y1 - Y0) / 0.394)):                                 # rail slots
        u.span((-0.5, Y0 + 0.2 + k * 0.394, 0.8), (0.5, Y0 + 0.4 + k * 0.394, 0.95), cut=True)
    u.cyl(0.62, 0.35, (0, Y1 - 0.15, 0), seg=28)                            # barrel extension threads boss
    u.span((0.2, -1.0, -0.38), (0.7, 1.7, 0.25), cut=True)                 # ejection port
    u.side([(-2.6, 0.0), (-1.8, 0.0), (-1.9, 0.35), (-2.5, 0.35)], 0.5, x=0.5, bev=0.06)    # forward assist housing
    u.span((-0.06, Y0 - 0.1, 0.35), (0.06, Y0 + 0.6, 0.6), cut=True)       # charging handle slot
    U(4, "Gunmetal", "Upper", None).span((0.47, -1.05, -0.4), (0.53, 1.75, 0.28), bev=0.02)
    U(2, "Gunmetal", "Upper", None, hidden=True).spring(0.04, 0.008, 2.6, 18, (0.45, 0.35, -0.42))
    fa = U(6, "Gunmetal", "Upper", None)
    fa.cyl(0.2, 0.7, (0.72, -2.55, 0.18), seg=16).cyl(0.26, 0.12, (0.72, -2.9, 0.18), seg=18)
    U(5, "Gunmetal", "Upper", None, hidden=True).spring(0.12, 0.02, 0.6, 7, (0.72, -2.3, 0.18))
    U(8, "Gunmetal", "Upper", None).rod(0.04, (0.55, -2.15, 0.45), (0.9, -2.15, 0.45), seg=8)
    ch = U(7, "Gunmetal", "Charging", (0, -4, 10.5))
    ch.span((-0.1, Y0 - 0.3, 0.38), (0.1, Y0 + 6.8, 0.52))
    ch.side([(Y0 - 0.65, 0.35), (Y0 - 0.25, 0.35), (Y0 - 0.25, 0.6), (Y0 - 0.65, 0.6)], 1.3, bev=0.06)
    U(3, "Gunmetal", "Barrel", (0, 6, 4.2), hidden=True).rod(0.08, (0, Y1 - 0.5, 0.55), (0, Y1 + RL * 0.75, 0.55), seg=8)

    # ---------------------------------------------------------------- barrel group
    b = B(1, "Gunmetal", "Barrel", (0, 6, 3.0))
    b.cyl(0.5, 0.6, (0, Y1 - 0.3, 0), seg=24)                               # barrel extension
    b.tube(0.42, 0.11, 2.0, (0, Y1 + 1.0, 0), seg=24)
    b.tube(0.36, 0.11, BL - 2.0, (0, Y1 + 2.0 + (BL - 2.0) / 2, 0), seg=24)
    b.cyl(0.3, 0.6, (0, Y1 + BL + 0.3, 0), seg=20)                          # muzzle threads
    B(2, "Gunmetal", "Barrel", (0, 4, 3.0)).cyl(0.68, 0.75, (0, Y1 + 0.38, 0), seg=28)
    gb = B(4, "Gunmetal", "Barrel", (0, 6, 1.6), hidden=RL > BL * 0.62)
    gb.span((-0.4, Y1 + RL * 0.75, -0.4), (0.4, Y1 + RL * 0.75 + 0.7, 0.68), bev=0.05)
    h = B(3, "Polymer", "Barrel", (0, 4, 0))
    sec = [(0.78 * math.cos(2 * math.pi * k / 8 + math.pi / 8), 0.78 * math.sin(2 * math.pi * k / 8 + math.pi / 8)) for k in range(8)]
    h.front(sec, RL, y=Y1 + 0.3 + RL / 2, bev=0.08)
    h.span((-0.42, Y1 + 0.3, 0.6), (0.42, Y1 + 0.3 + RL, 0.92), bev=0.03)   # its top rail, level with the receiver's
    for k in range(int(RL / 0.394)):
        h.span((-0.5, Y1 + 0.5 + k * 0.394, 0.8), (0.5, Y1 + 0.7 + k * 0.394, 0.95), cut=True)
    for k in range(int((RL - 1.2) / 1.6)):                                  # mounting slots on the sides and bottom
        for M in (I4, RY(90), RY(-90)):
            h.span((-0.12, Y1 + 1.0 + k * 1.6, -1.0), (0.12, Y1 + 2.2 + k * 1.6, -0.5), M=M, cut=True)
    h.cyl(0.66, RL + 1, (0, Y1 + 0.3 + RL / 2, 0), seg=24, cut=True)        # hollow
    md = B(5, "Gunmetal", "Muzzle", (0, 9, 3.0))
    md.cyl(0.4, 2.0, (0, Y1 + BL + 1.0, 0), seg=24)
    for k in range(5):
        a = 90 + 72 * k
        md.box((0.12, 1.3, 0.5), (0, 0, 0), M=T(0, Y1 + BL + 1.3, 0) @ RY(a) @ T(0, 0, 0.42), cut=True)   # prongs/ports
    md.cyl(0.2, 3, (0, Y1 + BL + 1.0, 0), seg=16, cut=True)
    bc = B(6, "Gunmetal", "Carrier", (0, -1, 8.8))
    bc.cyl(0.4, 4.6, (0, -1.3, 0.0), seg=20).span((-0.15, -1.6, 0.35), (0.15, 0.4, 0.55), bev=0.03)   # carrier, gas key
    bv = B(7, "Gunmetal", "Carrier", (0, 6, 8.8))
    bv.cyl(0.28, 1.4, (0, 1.6, 0.0), seg=18)
    for k in range(7):
        a = 2 * math.pi * k / 7
        bv.span((-0.06, 2.3, -0.06), (0.06, 2.45, 0.06), M=T(0.26 * math.cos(a), 0, 0.26 * math.sin(a)))
    B(9, "Gunmetal", "Upper", (0, -4.0, 6.0)).side(
        [(Y0 + 0.3, 0.92), (Y0 + 1.3, 0.92), (Y0 + 1.2, 1.35), (Y0 + 0.75, 1.75), (Y0 + 0.45, 1.75), (Y0 + 0.35, 1.3)], 0.6, bev=0.04).span(
        (-0.08, Y0 + 0.5, 1.45), (0.08, Y0 + 0.7, 1.9), cut=True)
    B(10, "Gunmetal", "Barrel", (0, 4, 1.2)).side(
        [(Y1 + RL - 0.6, 0.92), (Y1 + RL + 0.25, 0.92), (Y1 + RL + 0.15, 1.35), (Y1 + RL - 0.1, 1.85), (Y1 + RL - 0.35, 1.85),
         (Y1 + RL - 0.5, 1.35)], 0.6, bev=0.04)

    # ---------------------------------------------------------------- lower receiver
    lo = L(1, "Gunmetal", "Lower", (0, 0, 0))
    lo.side([(Y1 - 0.15, -0.62), (Y0 + 0.15, -0.62), (Y0 - 0.25, -0.2), (Y0 - 0.25, -1.3), (-2.2, -1.85), g(-0.6, 0.15),
             g(0.55, 0.15), (-0.2, -1.95), (0.25, -1.85), (0.3, -3.2), (0.25, -3.45), (3.2, -3.45), (3.25, -2.6),
             (3.6, -1.7), (Y1 + 0.2, -1.2), (Y1 + 0.35, -0.85)], 0.9, bev=0.05)
    lo.span((-0.5, 0.35, -3.6), (0.5, 3.05, -0.8), cut=True)               # magazine well
    lo.span((-0.25, -1.55, -2.0), (0.25, 0.2, -0.8), cut=True)              # fire control pocket under the trigger
    lo.cyl(0.58, 1.0, (0, Y0 - 0.4, -0.05), cut=True)                       # buffer tube thread
    for z in (-3.0, -2.6):                                                  # the magwell flare's grip ridges
        lo.span((0.43, 0.6, z), (0.47, 2.9, z + 0.06), cut=True)
        lo.span((-0.47, 0.6, z), (-0.43, 2.9, z + 0.06), cut=True)
    L(25, "Gunmetal", "Lower", None).span((-0.22, -1.5, -2.25), (0.22, 0.25, -2.12), bev=0.03).span(
        (-0.22, 0.1, -2.25), (0.22, 0.25, -1.85), bev=0.03)
    L(26, "Gunmetal", "Lower", None, hidden=True).rod(0.03, (-0.45, 0.17, -1.9), (0.45, 0.17, -1.9), seg=6)
    L(19, "Gunmetal", "Lower", None).rod(0.06, (-0.47, -1.05, -1.2), (0.47, -1.05, -1.2)).rod(
        0.06, (-0.47, -0.25, -1.45), (0.47, -0.25, -1.45))
    L(22, "Gunmetal", "Lower", None).rod(0.08, (-0.5, Y1 - 0.05, -0.75), (0.5, Y1 - 0.05, -0.75)).cyl(
        0.13, 0.05, (0.5, Y1 - 0.05, -0.75), axis="X", seg=14)
    L(21, "Gunmetal", "Lower", None).rod(0.08, (-0.5, Y0 + 0.2, -0.75), (0.5, Y0 + 0.2, -0.75)).cyl(
        0.13, 0.05, (0.5, Y0 + 0.2, -0.75), axis="X", seg=14)
    for k, y in enumerate((Y1 - 0.05, Y0 + 0.2)):
        L(23, "Gunmetal", "Lower", None, hidden=True, label="" if k else None).cyl(0.04, 0.2, (0, y + 0.2, -0.95), axis="Z", seg=6)
        L(24, "Gunmetal", "Lower", None, hidden=True, label="" if k else None).spring(0.035, 0.008, 0.3, 6, (0, y + 0.2, -1.2), axis="Z")
    se = L(20, "Gunmetal", "Lower", None)
    se.rod(0.1, (-0.55, -1.9, -1.25), (0.5, -1.9, -1.25))
    se.side([(-2.05, -1.12), (-1.45, -1.1), (-1.4, -1.25), (-1.95, -1.38)], 0.08, x=-0.55, bev=0.02)
    L(12, "Gunmetal", "Lower", None, hidden=True).cyl(0.035, 0.2, (0, -1.9, -1.5), axis="Z", seg=6)
    L(11, "Gunmetal", "Lower", None, hidden=True).spring(0.03, 0.007, 0.5, 9, (0, *g(0.0, -0.6)), axis="Z", M=I4)
    tr = L(13, "Gunmetal", "Trigger", None)
    tr.side([(-0.65, -1.35), (-0.2, -1.32), (-0.1, -1.5), (-0.2, -1.9), (-0.32, -1.92), (-0.36, -1.62), (-0.65, -1.5)], 0.25, bev=0.025)
    L(15, "Gunmetal", "Lower", None, hidden=True).side([(-0.6, -1.2), (-0.25, -1.15), (-0.25, -1.3), (-0.6, -1.35)], 0.12, bev=0.01)
    L(14, "Gunmetal", "Lower", None, hidden=True).spring(0.03, 0.006, 0.15, 4, (0, -0.45, -1.4), axis="Z")
    L(16, "Gunmetal", "Lower", None, hidden=True).side(
        [(-1.3, -1.35), (-0.85, -1.35), (-0.8, -0.95), (-1.0, -0.62), (-1.25, -0.62), (-1.3, -1.0)], 0.3, bev=0.02)
    L(17, "Gunmetal", "Lower", None, hidden=True).spring(0.08, 0.012, 0.4, 3, (0, -0.25, -1.45), axis="X")
    L(18, "Gunmetal", "Lower", None, hidden=True).spring(0.1, 0.012, 0.42, 3, (0, -1.05, -1.2), axis="X")
    mc = L(27, "Gunmetal", "Lower", None, hidden=True)
    mc.span((-0.5, 0.15, -1.75), (0.45, 0.32, -1.55))
    L(28, "Gunmetal", "Lower", None).cyl(0.17, 0.18, (0.52, 0.22, -1.65), axis="X", seg=18)
    L(29, "Gunmetal", "Lower", None, hidden=True).spring(0.12, 0.015, 0.4, 6, (0.32, 0.22, -1.65), axis="X")
    bk = L(30, "Gunmetal", "Lower", None)
    bk.side([(-0.05, -0.62), (0.25, -0.62), (0.3, -1.4), (0.05, -1.45), (-0.02, -1.0)], 0.07, x=-0.5, bev=0.015)
    L(31, "Gunmetal", "Lower", None).rod(0.035, (-0.5, 0.1, -0.85), (-0.3, 0.1, -0.85), seg=6)
    L(32, "Gunmetal", "Lower", None, hidden=True).cyl(0.04, 0.2, (-0.38, 0.15, -1.3), axis="Z", seg=6)
    L(33, "Gunmetal", "Lower", None, hidden=True).spring(0.035, 0.008, 0.25, 5, (-0.38, 0.15, -1.5), axis="Z")
    L(34, "Gunmetal", "Lower", None, hidden=True).cyl(0.07, 0.4, (0, Y0 - 0.35, -0.68), axis="Z", seg=8)
    L(35, "Gunmetal", "Lower", None, hidden=True).spring(0.06, 0.01, 0.35, 6, (0, Y0 - 0.35, -1.05), axis="Z")
    gr = L(8, "Polymer", "Lower", (0, -1.0, -3.0))
    gr.side([(-0.55, 0.1), (0.6, 0.1), (0.62, -0.4), (0.7, -0.75), (0.6, -1.15), (0.68, -1.55), (0.62, -2.05), (0.66, -2.6),
             (0.55, -3.1), (-0.5, -3.15), (-0.75, -2.7), (-0.72, -1.2), (-0.7, 0.0)], 0.82, bev=0.12, M=GM)
    for k in range(10):
        for sx in (-1, 1):
            gr.span((sx * 0.41 - 0.03, -0.75, -0.5 - k * 0.24), (sx * 0.41 + 0.03, 0.75, -0.45 - k * 0.24), M=GM, cut=True)
    L(9, "Gunmetal", "Lower", None).rod(0.07, (0, *g(0.0, -2.9)), (0, *g(0.0, -3.2)), seg=10)
    L(10, "Gunmetal", "Lower", None, hidden=True).tube(0.09, 0.05, 0.03, (0, *g(0.0, -2.88)), axis="Z", seg=10)

    # ---------------------------------------------------------------- buffer tube and stock
    bt = L(2, "Gunmetal", "Stock", (0, -3.0, 0))
    bt.cyl(0.58, 7.2, (0, Y0 - 0.25 - 3.6, -0.05), seg=28)
    bt.span((-0.2, Y0 - 7.4, -0.75), (0.2, Y0 - 0.6, -0.45))               # the stock's position rail under it
    L(7, "Gunmetal", "Stock", (0, -1.6, 0)).tube(0.72, 0.55, 0.3, (0, Y0 - 0.45, -0.05), seg=28)
    L(6, "Gunmetal", "Stock", (0, -0.8, 0)).span((-0.62, Y0 - 0.35, -0.75), (0.62, Y0 - 0.25, 0.6), bev=0.03)
    L(5, "Gunmetal", "Stock", None, hidden=True).cyl(0.48, 3.2, (0, Y0 - 3.0, -0.05), seg=16)
    L(4, "Gunmetal", "Stock", None, hidden=True).spring(0.42, 0.04, 6.4, 22, (0, Y0 - 4.2, -0.05))
    st = L(3, "Polymer", "Stock", (0, -6, -0.3))
    s0 = Y0 - 4.0
    st.side([(s0, 0.65), (s0 - 4.6, 0.75), (s0 - 5.4, 0.85), (s0 - 5.6, -2.9), (s0 - 5.0, -2.95), (s0 - 4.4, -1.4),
             (s0 - 1.6, -0.95), (s0, -0.9)], 1.25, bev=0.15)
    st.cyl(0.6, 12, (0, s0 - 3, -0.05), seg=24, cut=True)                   # the bore for the buffer tube
    st.span((-0.7, s0 - 5.7, -2.95), (0.7, s0 - 5.35, 0.9), bev=0.05)       # rubber butt pad

    # ---------------------------------------------------------------- magazine
    mg = B(8, "Gunmetal", "Magazine", (0, 1.0, -4.0))
    front, back = [], []
    for k in range(9):
        t = k / 8
        a = math.radians(14 * t)
        drop = 6.2 * t
        front.append((3.0 + drop * math.sin(a) * 0.9, -1.0 - drop * math.cos(a * 0.5)))
        back.append((0.4 + drop * math.sin(a) * 1.25, -1.0 - drop * math.cos(a * 0.5) - 0.05 * t))
    mg.side(front + back[::-1], 0.84, bev=0.06)
    for k in range(4):
        mg.span((0.4, 0.9 + k * 0.6 + 0.2 * k * k * 0.0, -3.0 - k * 0.2), (0.46, 2.4 + k * 0.6, -2.85 - k * 0.2), cut=True)
    mg.side([(back[-1][0] - 0.1, back[-1][1] - 0.02), (front[-1][0] + 0.1, front[-1][1] + 0.05),
             (front[-1][0] + 0.12, front[-1][1] - 0.15), (back[-1][0] - 0.12, back[-1][1] - 0.2)], 0.95, bev=0.04)

    if o.get("can"):
        P.append(suppressor("S1", Y1 + BL + 2.0, 0, length=o["can"], r=0.78))
    if o.get("light"):
        lt = weapon_light("L99", Y1 + RL - 0.2, -0.78)
        P.extend(lt)
    return P
