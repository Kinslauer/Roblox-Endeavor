# The revolver: a swing-out, double-action six-shot revolver, every part numbered (Andy's charts had no revolver, so
# this list is the usual one for the type), built with gunparts.py. Inches; Y forward, Z up, X right; bore on Z 0,
# the cylinder's front face at Y 0, the cylinder turning on an axis 0.52 below the bore.
# Options: barrel (2, 4, 6 inches), grip (grip length), lug ("full" or "half" ejector shroud), can, light (none fit).
import math
from mathutils import Vector, Matrix
from gunparts import Part, platform, suppressor, T, RX, RY, RZ, I4

TH = math.radians(20)
OY, OZ = -2.06, -1.51
GM = T(0, OY, OZ) @ RX(-20)
CZ = -0.52                                   # cylinder axis
CR = 0.72                                    # cylinder radius
CY0, CY1 = -1.66, -0.04                      # cylinder rear and front faces

def g(u, v):
    return (OY + u * math.cos(TH) + v * math.sin(TH), OZ - u * math.sin(TH) + v * math.cos(TH))

TITLES = ["Frame", "Barrel", "Cylinder", "Crane", "Ejector rod", "Extractor star", "Center pin", "Center pin spring",
          "Ejector spring", "Cylinder release", "Bolt", "Bolt plunger and spring", "Hammer", "Hammer nose", "Hammer stud",
          "Trigger", "Trigger stud", "Hand", "Rebound slide", "Rebound slide spring", "Mainspring", "Strain screw",
          "Side plate", "Side plate screw", "Stock, left hand", "Stock, right hand", "Stock screw", "Front sight",
          "Rear sight", "Crane lock screw", "Sear", "Thumbpiece nut"]

VARIANTS = {
    "Revolver4": dict(barrel=4.0, grip=2.8, lug="half", chart=True, title="REVOLVER  -  ALL 32 PARTS"),
    "Revolver2": dict(barrel=2.0, grip=2.1, lug="half"),
    "Revolver6": dict(barrel=6.0, grip=2.8, lug="full"),
}

@platform("revolver", "Pistol", VARIANTS, origin=(0, OY, OZ))
def build(o):
    BL = o.get("barrel", 4.0)
    GL = o.get("grip", 2.8)
    P = []
    add = lambda p: (P.append(p), p)[1]
    def part(n, mat, group, ex, hidden=False, label=None):
        return add(Part(n, TITLES[n - 1], mat, group, explode=ex, hidden=hidden, label=label))

    # ---------------------------------------------------------------- frame
    f = part(1, "Gunmetal", "Frame", (0, 0, 0))
    outline = [(0.42, 0.55), (-2.0, 0.55), (-2.35, 0.42), (-2.8, -0.2), (-2.82, -0.9), g(-0.72, 0.0), g(-0.72, -GL + 0.25),
               g(-0.5, -GL), g(0.42, -GL), g(0.6, -GL + 0.3), g(0.62, 0.0), (-1.38, -2.32), (-0.2, -2.32), (0.18, -2.1),
               (0.28, -1.7), (0.3, -1.45), (0.42, -1.05)]
    f.side(outline, 0.98, bev=0.14)
    f.side([(CY0 - 0.03, CZ - CR - 0.06), (CY1 + 0.03, CZ - CR - 0.06), (CY1 + 0.03, 0.3), (CY0 - 0.03, 0.3)], 3, cut=True)
    f.side([(-1.2, -1.55), (-0.15, -1.55), (0.05, -1.75), (0.0, -2.08), (-0.25, -2.18), (-1.15, -2.18), (-1.32, -1.9)], 3,
           cut=True)                                                        # trigger guard opening
    f.span((0.18, -1.4, -2.5), (0.7, 0.4, -1.52), cut=True)                # the guard narrower than the frame
    f.span((-0.7, -1.4, -2.5), (-0.18, 0.4, -1.52), cut=True)
    f.span((-0.17, -3.0, -1.0), (0.17, -1.95, 0.8), cut=True)              # hammer slot
    f.span((-0.08, -1.0, -2.0), (0.08, -0.55, -1.4), cut=True)             # trigger slot
    f.cyl(0.1, 1.0, (0, 0.3, CZ), cut=True)                                 # crane hole in the frame front
    f.span((-0.08, -2.1, 0.4), (0.08, -1.7, 0.7), cut=True)                # rear sight groove in the top strap
    sp = part(23, "Gunmetal", "Frame", (0, -2.6, -3.0))
    sp.side([(-2.55, -0.35), (-1.75, -0.35), (-1.4, -0.9), (-1.45, -1.5), (-2.2, -1.5), g(-0.55, -0.3), (-2.6, -1.0)], 0.04,
            x=0.515, bev=0.01)
    for k, (y, z) in enumerate(((-2.35, -0.55), (-1.6, -1.3), (-2.25, -1.3))):
        part(24, "Gunmetal", "Frame", None, label="" if k else None).cyl(0.07, 0.05, (0.545, y, z), axis="X", seg=12)

    # ---------------------------------------------------------------- barrel
    b = part(2, "Gunmetal", "Barrel", (0, 2.0, 2.6))
    b.cyl(0.36, 0.42, (0, 0.21, 0), seg=24)                                 # shank in the frame
    b.tube(0.3, 0.18, BL, (0, BL / 2, 0), seg=28)
    b.span((-0.16, 0.0, 0.2), (0.16, BL, 0.42), bev=0.04)                  # top rib
    lug0 = 0.42 if o.get("lug") == "full" else max(0.42, BL - 1.4)
    b.side([(lug0, -0.15), (BL, -0.15), (BL, -0.62), (BL - 0.2, -0.78), (lug0 + 0.25, -0.78), (lug0, -0.62)], 0.42, bev=0.06)
    if o.get("lug") != "full":                                              # a full lug hides the rod's tip inside
        b.cyl(0.08, 1.6, (0, lug0, CZ), cut=True)                           # ejector rod seat in the lug's rear
    part(28, "Gunmetal", "Barrel", (0, 2.6, 3.8)).side(
        [(BL - 0.7, 0.38), (BL - 0.05, 0.38), (BL - 0.08, 0.64), (BL - 0.25, 0.64)], 0.12, bev=0.015)

    # ---------------------------------------------------------------- cylinder, crane, ejector
    c = part(3, "Gunmetal", "Cylinder", (0, -0.6, 2.4))
    c.cyl(CR, CY1 - CY0, (0, (CY0 + CY1) / 2, CZ), seg=48)
    for k in range(6):
        a = math.radians(90 + 60 * k)
        cx, cz = 0.52 * math.cos(a), CZ + 0.52 * math.sin(a)
        c.cyl(0.19, 2.0, (cx, (CY0 + CY1) / 2, cz), seg=16, cut=True)       # chambers
        a2 = a + math.radians(30)
        fx, fz = 0.83 * math.cos(a2), CZ + 0.83 * math.sin(a2)
        c.cyl(0.17, 1.0, (fx, (CY0 + CY1) / 2 + 0.12, fz), seg=14, cut=True)  # flutes
        c.box((0.12, 0.25, 0.12), (0, 0, 0), M=T(0, CY0 + 0.45, CZ) @ RY(-math.degrees(a)) @ T(CR, 0, 0), cut=True)  # bolt notches
    c.cyl(0.15, 3.0, (0, (CY0 + CY1) / 2, CZ), seg=16, cut=True)            # centre bore
    ex = part(6, "Gunmetal", "Cylinder", (0, -1.7, 2.4))
    ex.cyl(0.45, 0.06, (0, CY0 - 0.02, CZ), seg=24)
    for k in range(6):
        a = math.radians(90 + 60 * k)
        ex.cyl(0.19, 0.2, (0.52 * math.cos(a), CY0 - 0.02, CZ + 0.52 * math.sin(a)), seg=16, cut=True)
    er = part(5, "Gunmetal", "Cylinder", (0, 2.4, 1.2))
    rod_end = BL - 0.1 if o.get("lug") == "full" else lug0 + 0.05
    er.cyl(0.075, rod_end - CY0, (0, (CY0 + rod_end) / 2, CZ), seg=12)
    er.cyl(0.11, 0.3, (0, rod_end - 0.15, CZ), seg=16)
    part(7, "Gunmetal", "Cylinder", None, hidden=True).cyl(0.05, 1.9, (0, -0.7, CZ), seg=8)
    part(8, "Gunmetal", "Cylinder", None, hidden=True).spring(0.06, 0.01, 0.7, 10, (0, -0.4, CZ))
    part(9, "Gunmetal", "Cylinder", None, hidden=True).spring(0.12, 0.015, 1.0, 9, (0, -0.85, CZ))
    cr = part(4, "Gunmetal", "Cylinder", (0, 1.4, 1.2))
    cr.tube(0.14, 0.08, 0.3, (0, 0.13, CZ), seg=16)
    cr.side([(0.0, CZ - 0.05), (0.3, CZ - 0.05), (0.3, -1.38), (0.0, -1.38)], 0.22, x=-0.32, bev=0.02)
    cr.cyl(0.08, 0.36, (-0.32, 0.12, -1.3), axis="Y", seg=10)                 # crane arm's pivot barrel
    part(30, "Gunmetal", "Frame", None).cyl(0.08, 0.05, (0.53, 0.2, -1.2), axis="X", seg=12)

    # ---------------------------------------------------------------- lockwork
    h = part(13, "Gunmetal", "Hammer", (0, -2.8, 0.6))
    h.side([(-1.98, -1.0), (-1.98, 0.38), (-2.15, 0.52), (-2.6, 0.62), (-2.95, 0.72), (-3.05, 0.6), (-2.85, 0.42),
            (-2.62, 0.2), (-2.55, -0.6), (-2.3, -1.05)], 0.32, bev=0.03)
    for k in range(5):
        h.span((-0.2, -3.0 + k * 0.08, 0.5), (0.2, -2.98 + k * 0.08, 0.9), cut=True)
    part(14, "Gunmetal", "Hammer", None).cyl(0.04, 0.18, (0, -1.92, 0.0), seg=8)
    part(15, "Gunmetal", "Frame", None).rod(0.06, (-0.5, -2.3, -0.75), (0.53, -2.3, -0.75))
    part(31, "Gunmetal", "Hammer", None, hidden=True).side(
        [(-2.05, -0.95), (-1.9, -0.95), (-1.9, -0.75), (-2.05, -0.75)], 0.1, bev=0.01)
    t = part(16, "Gunmetal", "Trigger", (0, 2.4, -1.4))
    t.side([(-1.05, -1.4), (-0.6, -1.4), (-0.42, -1.6), (-0.35, -1.85), (-0.42, -2.12), (-0.58, -2.12), (-0.62, -1.88),
            (-0.72, -1.7), (-1.0, -1.62)], 0.28, bev=0.04)
    part(17, "Gunmetal", "Frame", None).rod(0.05, (-0.5, -0.95, -1.5), (0.53, -0.95, -1.5))
    part(18, "Gunmetal", "Frame", None, hidden=True).side(
        [(-1.9, -0.95), (-1.8, -0.95), (-1.75, CZ - 0.2), (-1.85, CZ - 0.15)], 0.08, x=0.18, bev=0.01)
    part(11, "Gunmetal", "Frame", None, hidden=True).span((-0.07, -1.25, -1.35), (0.07, -0.95, -1.2), bev=0.01)
    part(12, "Gunmetal", "Frame", None, hidden=True).spring(0.04, 0.01, 0.3, 6, (0, -1.1, -1.45), axis="Z")
    part(19, "Gunmetal", "Frame", None, hidden=True).span((-0.1, -1.95, -1.55), (0.1, -1.2, -1.4), bev=0.01)
    part(20, "Gunmetal", "Frame", None, hidden=True).spring(0.06, 0.012, 0.6, 9, (0, -1.6, -1.48))
    part(21, "Gunmetal", "Frame", None, hidden=True).span((-0.15, 0.25, -GL + 0.2), (0.15, 0.3, -0.3), M=GM)
    part(22, "Gunmetal", "Frame", None).rod(0.06, (0, *g(0.68, -GL + 0.4)), (0, *g(0.82, -GL + 0.45)))

    # ---------------------------------------------------------------- controls, sights, grips
    cl = part(10, "Gunmetal", "Frame", (0, -1.2, 1.0))
    cl.side([(-2.42, -0.15), (-1.9, -0.15), (-1.88, -0.42), (-2.42, -0.45)], 0.1, x=-0.56, bev=0.02)
    for k in range(5):
        cl.span((-0.65, -2.35 + k * 0.1, -0.5), (-0.6, -2.32 + k * 0.1, -0.1), cut=True)
    part(32, "Gunmetal", "Frame", None).cyl(0.07, 0.06, (-0.62, -2.15, -0.3), axis="X", seg=10)
    rs = part(29, "Gunmetal", "Frame", (0, -0.8, 3.4))
    rs.span((-0.15, -2.1, 0.5), (0.15, -1.7, 0.66), bev=0.02).span((-0.04, -2.2, 0.58), (0.04, -1.6, 0.7), cut=True)
    for n, sx in ((25, -1), (26, 1)):
        st = part(n, "Polymer", "Grips", (0, 2.6, -3.2) if sx > 0 else (0, 5.8, -3.2))
        st.side([(-0.6, 0.05), (0.55, 0.05), (0.78, -0.5), (0.8, -GL + 0.6), (0.62, -GL - 0.02), (0.2, -GL - 0.12),
                 (-0.45, -GL - 0.05), (-0.8, -GL + 0.45), (-0.86, -0.6)], 0.3, x=sx * 0.4, bev=0.12, M=GM)
        for a in (35, -35):
            for k in range(-8, 9):
                st.box((0.08, 5.0, 0.035), (0, 0, 0), M=GM @ T(sx * 0.57, 0.0, -GL / 2) @ RX(a) @ T(0, 0, k * 0.15), cut=True)
    part(27, "Gunmetal", "Grips", None).rod(0.05, (-0.52, *g(0.0, -GL / 2)), (0.52, *g(0.0, -GL / 2)))

    if o.get("can"):
        P.append(suppressor("S1", BL, 0, length=o["can"]))
    return P
