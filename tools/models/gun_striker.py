# The striker-fired pistol: every part of the striker pistol parts chart Andy sent (2026-11-11), numbered as on that
# chart (33b = the front sight screw), built with gunparts.py. A polymer frame with a rail, a square slide, a striker
# instead of a hammer. Inches; Y forward, Z up, X right; bore on Z 0, breech face at Y 0.
# Options: barrel (4.0 compact, 4.5 full), grip (grip length below the frame), threaded, can, light.
import math
from mathutils import Vector, Matrix
from gunparts import Part, platform, suppressor, weapon_light, T, RX, RY, RZ, I4

TH = math.radians(22)                       # grip rake
OY, OZ = -1.15, -1.62

def GMf():
    return T(0, OY, OZ) @ RX(-22)

GM = GMf()

def g(u, v):
    return (OY + u * math.cos(TH) + v * math.sin(TH), OZ - u * math.sin(TH) + v * math.cos(TH))

VARIANTS = {
    "Striker19": dict(barrel=4.0, grip=2.7, chart=True, title="STRIKER-FIRED PISTOL  -  ALL 33 PARTS"),
    "Striker17": dict(barrel=4.5, grip=3.05),
    "StrikerWhisper": dict(barrel=4.5, grip=3.05, threaded=True, can=6.0, light=True),
}

@platform("striker", "Pistol", VARIANTS, origin=(0, OY, OZ))
def build(o):
    BL = o.get("barrel", 4.0)
    GL = o.get("grip", 2.7)
    front = BL + 0.35
    P = []
    add = lambda p: (P.append(p), p)[1]

    # ---------------------------------------------------------------- slide and what rides in it
    s = add(Part(1, "Slide", "Gunmetal", "Slide", explode=(0, 0, 7.0)))
    dust = BL - 0.35                         # the frame's dust cover ends here; the slide nose comes down in front of it
    s.side([(-2.25, -0.42), (dust + 0.03, -0.42), (dust + 0.03, -1.0), (front, -1.0), (front, 0.30), (front - 0.3, 0.62),
            (-2.25, 0.62)], 1.0, bev=0.07)
    s.span((-0.36, -1.7, -0.5), (0.36, front + 1, 0.36), cut=True)          # hollow
    s.cyl(0.29, 1.0, (0, front, 0), cut=True)                               # muzzle
    s.cyl(0.2, 1.0, (0, front, -0.62), cut=True)                            # spring hole
    s.span((0.0, -0.35, 0.12), (0.6, 0.95, 0.8), cut=True)                  # ejection port: top right
    for k in range(9):                                                      # rear serrations
        for sx in (-1, 1):
            s.span((sx * 0.5 - 0.04, -2.05 + k * 0.1, -0.35), (sx * 0.5 + 0.04, -2.0 + k * 0.1, 0.5), cut=True)
    add(Part(15, "Rear sight", "Gunmetal", "Slide", explode=(0, -0.8, 8.6))).side(
        [(-2.1, 0.6), (-1.7, 0.6), (-1.78, 0.8), (-2.08, 0.8)], 0.55, bev=0.02).span(
        (-0.07, -2.3, 0.7), (0.07, -1.5, 0.9), cut=True)
    add(Part(33, "Front sight", "Gunmetal", "Slide", explode=(0, 0.8, 8.6))).side(
        [(front - 0.55, 0.6), (front - 0.3, 0.6), (front - 0.34, 0.78), (front - 0.52, 0.78)], 0.13, bev=0.02)
    add(Part("33b", "Front sight screw", "Gunmetal", "Slide", hidden=True, explode=None)).cyl(
        0.05, 0.25, (0, front - 0.42, 0.5), axis="Z", seg=8)
    add(Part(14, "Slide cover plate", "Polymer", "Slide", explode=(0, -1.8, 6.0))).span(
        (-0.4, -2.3, -0.3), (0.4, -2.24, 0.45), bev=0.02)
    add(Part(10, "Extractor", "Gunmetal", "Slide", explode=(0, -2.5, 5.0))).span(
        (0.46, -0.7, -0.02), (0.53, 0.05, 0.22), bev=0.02)
    add(Part(11, "Extractor plunger", "Gunmetal", "Slide", hidden=True, explode=None)).cyl(0.04, 0.35, (0.38, -0.9, 0.3), seg=8)
    add(Part(12, "Extractor plunger spring", "Gunmetal", "Slide", hidden=True, explode=None)).spring(
        0.035, 0.008, 0.3, 7, (0.38, -1.25, 0.3))
    add(Part(13, "Spring-loaded bearing", "Gunmetal", "Slide", hidden=True, explode=None)).cyl(0.05, 0.2, (0.38, -1.5, 0.3), seg=8)
    sk = add(Part(4, "Firing pin", "Gunmetal", "Slide", hidden=True, explode=None))
    sk.cyl(0.05, 1.7, (0, -1.15, 0)).span((-0.04, -1.6, -0.25), (0.04, -1.45, 0.0))     # striker with its lug
    add(Part(5, "Spacer sleeve", "Polymer", "Slide", hidden=True, explode=None)).tube(0.09, 0.06, 0.9, (0, -1.6, 0), seg=12)
    add(Part(6, "Firing pin spring", "Gunmetal", "Slide", hidden=True, explode=None)).spring(0.08, 0.012, 0.9, 12, (0, -1.6, 0))
    for k, y in enumerate((-2.07, -1.13)):
        add(Part(7, "Spring cup", "Polymer", "Slide", hidden=True, explode=None, label="" if k else None)).cyl(
            0.1, 0.06, (0, y, 0), seg=12)
    add(Part(8, "Firing pin safety", "Gunmetal", "Slide", hidden=True, explode=None)).cyl(0.06, 0.25, (0, -0.35, -0.28), axis="Z", seg=10)
    add(Part(9, "Firing pin safety spring", "Gunmetal", "Slide", hidden=True, explode=None)).spring(
        0.05, 0.01, 0.2, 5, (0, -0.35, -0.08), axis="Z")

    # ---------------------------------------------------------------- barrel, recoil spring
    b = add(Part(2, "Barrel", "Gunmetal", "Barrel", explode=(0, 1.6, 4.4)))
    blen = BL + (0.5 if o.get("threaded") else 0.25)
    b.tube(0.27, 0.18, blen, (0, blen / 2, 0), seg=28)
    b.span((-0.34, 0.0, -0.1), (0.34, 1.15, 0.44), bev=0.04)                # the square chamber block (shows in the port)
    b.side([(0.45, -0.25), (1.25, -0.25), (1.15, -0.62), (0.75, -0.62)], 0.42, bev=0.03)    # cam lug
    if o.get("threaded"):
        for k in range(8):
            b.cyl(0.29, 0.03, (0, BL + 0.28 + k * 0.06, 0), seg=28)
    r = add(Part(3, "Recoil spring assembly", "Gunmetal", "Frame", hidden=True, explode=(0, 1.4, 3.3)))
    rl = BL - 0.2
    r.cyl(0.06, rl, (0, 0.5 + rl / 2, -0.62)).cyl(0.22, 0.1, (0, 0.5, -0.62), seg=18)
    r.spring(0.17, 0.03, rl - 0.2, 14, (0, 0.6 + (rl - 0.2) / 2, -0.62))

    # ---------------------------------------------------------------- frame
    f = add(Part(16, "Frame", "Polymer", "Frame", explode=(0, 0, 0)))
    dz = -1.1
    outline = [(dust, -0.42), (-2.2, -0.42), (-2.3, -0.62), (-2.55, -0.7), (-2.5, -0.95), g(-0.85, 0.0), g(-0.9, -GL),
               g(0.95, -GL), g(1.0, -GL + 0.4), g(0.92, -0.2), g(0.95, 0), (0.0, -2.0), (1.75, -2.0), (2.05, -1.9),
               (2.1, -1.5), (2.05, dz), (dust, dz)]
    f.side(outline, 0.98, bev=0.06)
    f.side([(0.0, -1.05), (1.8, -1.05), (1.92, -1.25), (1.9, -1.72), (1.72, -1.84), (0.12, -1.84), (-0.1, -1.6)], 2,
           cut=True)                                                        # trigger guard opening
    f.span((0.22, 0.0, -2.2), (0.7, 2.3, -1.1), cut=True)                  # the guard narrower than the frame
    f.span((-0.7, 0.0, -2.2), (-0.22, 2.3, -1.1), cut=True)
    f.box((0.82, 1.3, GL + 1.0), (0, 0.02, -GL / 2 - 0.35), M=GM, cut=True)   # magazine well
    for k in range(3):                                                      # rail cross slots
        f.span((-0.6, dust - 1.45 + k * 0.42, dz - 0.05), (0.6, dust - 1.28 + k * 0.42, dz + 0.1), cut=True)
    for sx in (-1, 1):
        f.span((sx * 0.49 - 0.06, 2.15, dz + 0.13), (sx * 0.49 + 0.06, dust + 0.1, dz + 0.25), cut=True)
        for k in range(7):                                                  # grip texture: shallow horizontal ribs
            f.span((sx * 0.49 - 0.025, -0.9, -0.6 - k * 0.32), (sx * 0.49 + 0.025, 0.9, -0.5 - k * 0.32), M=GM, cut=True)
    f.span((-0.12, -0.7, -0.62), (0.12, -0.2, -0.2), cut=True)              # trigger bar channel (seen from above)
    rail = add(Part(21, "Locking block", "Gunmetal", "Frame", explode=(0, 5.6, 0.9)))
    rail.side([(0.55, -0.42), (1.3, -0.42), (1.3, -0.8), (0.55, -0.8)], 0.7, bev=0.03)
    add(Part(20, "Slide lock", "Gunmetal", "Frame", explode=(0, 4.2, 1.6))).span(
        (-0.56, 0.5, -0.78), (0.56, 0.72, -0.58), bev=0.02)
    add(Part(19, "Slide lock spring", "Gunmetal", "Frame", hidden=True, explode=None)).side(
        [(0.75, -0.6), (0.85, -0.6), (0.85, -0.95), (0.75, -0.95)], 0.5, bev=0.01)
    ss = add(Part(26, "Slide stop lever", "Gunmetal", "Frame", explode=None))
    ss.side([(-0.95, -0.52), (0.55, -0.52), (0.55, -0.62), (-0.55, -0.66), (-0.75, -0.78), (-0.95, -0.7)], 0.06, x=-0.52, bev=0.015)
    for num, y, z in ((27, -0.2, -0.82), (28, -1.95, -0.9)):
        add(Part(num, "Trigger pin" if num == 27 else "Mechanism housing pin", "Gunmetal", "Frame", explode=None)).rod(
            0.045, (-0.51, y, z), (0.51, y, z), seg=10)

    # ---------------------------------------------------------------- the trigger group
    th = add(Part(22, "Trigger mechanism housing with ejector", "Gunmetal", "Frame", hidden=True, explode=(0, -3.2, 1.6)))
    th.side([(-2.2, -0.42), (-1.25, -0.42), (-1.25, -0.6), (-1.6, -0.62), (-1.6, -1.15), (-2.2, -1.15)], 0.36, bev=0.02)
    th.span((-0.3, -1.25, -0.42), (-0.16, -0.65, -0.2), bev=0.01)          # ejector
    add(Part(23, "Connector", "Gunmetal", "Frame", hidden=True, explode=None)).side(
        [(-1.95, -0.65), (-1.7, -0.65), (-1.7, -1.0), (-1.95, -0.85)], 0.04, x=0.2, bev=0.005)
    add(Part(24, "Trigger spring", "Gunmetal", "Frame", hidden=True, explode=None)).spring(
        0.04, 0.008, 0.45, 9, (0.12, -1.0, -0.75))
    tr = add(Part(25, "Trigger with trigger bar", "Polymer", "Trigger", explode=(0, 4.8, -1.0)))
    tr.side([(0.55, -1.05), (0.82, -1.05), (0.86, -1.35), (0.78, -1.7), (0.64, -1.68), (0.62, -1.35)], 0.3, bev=0.03)
    tr.span((-0.03, 0.68, -1.55), (0.03, 0.76, -1.15))                      # the safety blade in the shoe
    tr.span((-0.04, -1.75, -0.78), (0.04, 0.62, -0.68))                     # the bar, back to the housing
    tr.span((-0.04, -1.75, -0.95), (0.04, -1.6, -0.68))

    # ---------------------------------------------------------------- magazine and catch
    mt = add(Part(32, "Magazine tube", "Polymer", "Magazine", explode=(0, -0.4, -6.0)))
    mt.box((0.8, 1.26, GL + 0.3), (0, 0.02, -GL / 2 - 0.05), M=GM, bev=0.08)
    mt.span((-0.25, -0.6, -0.35), (0.25, 0.62, 0.3), M=GM, cut=True)       # feed lips
    add(Part(31, "Magazine floorplate", "Polymer", "Magazine", explode=(0, -0.4, -8.0))).box(
        (0.92, 1.42, 0.16), (0, 0.06, -GL - 0.12), M=GM, bev=0.05)
    add(Part(29, "Follower", "Polymer", "Magazine", hidden=True, explode=None)).box((0.6, 1.1, 0.2), (0, 0, -0.42), M=GM, bev=0.04)
    add(Part(30, "Magazine spring", "Gunmetal", "Magazine", hidden=True, explode=None)).spring(
        0.26, 0.025, GL, 6, (0, 0, -GL / 2 - 0.3), axis="Z", M=GM @ Matrix.Diagonal((1, 1.9, 1, 1)))
    mc = add(Part(18, "Magazine catch", "Polymer", "Frame", explode=(0, 1.8, -1.6)))
    mc.span((-0.53, -0.35, -1.42), (0.53, -0.12, -1.18), bev=0.03)
    add(Part(17, "Magazine catch spring", "Gunmetal", "Frame", hidden=True, explode=None)).rod(
        0.02, (0.0, -0.3, -1.2), (0.0, -0.75, -0.9), seg=6)

    if o.get("can"):
        P.append(suppressor("S1", BL + 0.35, 0, length=o["can"]))
    if o.get("light"):
        P.extend(weapon_light("L1", dust + 0.2, dz))
    return P
