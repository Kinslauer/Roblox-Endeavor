# Accessories any long gun can take, each on its own origin so the game can put it on any gun (gunparts.py):
#   Suppressor, Compensator: the origin is the start of the muzzle threads, the bore runs +Y.
#   ScopePSO (side-rail 4x), ScopeColt (3x): the origin is under the mount, on the receiver's top.
#   Foregrip: the origin is its top, under the handguard.
import math
from gunparts import Part, platform, suppressor, T, RX, RY, RZ, I4

VARIANTS = {"Suppressor": dict(kind="can"), "Compensator": dict(kind="comp"), "ScopePSO": dict(kind="scope", length=6.2, bell=0.62),
            "ScopeColt": dict(kind="scope", length=5.4, bell=0.5, low=True), "Foregrip": dict(kind="grip")}
COMPONENTS = {"Acc": "Acc", "AccLens": "Acc"}

def anchors(o):
    return {}

@platform("acc", "Rifle", VARIANTS, origin=(0, 0, 0))
def build(o):
    k = o["kind"]
    if k == "can":
        p = suppressor("A1", 0.0, 0.0, length=7.0, r=0.72, group="Acc")
        return [p]
    if k == "comp":
        p = Part("A2", "Compensator", "Gunmetal", "Acc", explode=(0, 0, 0))
        p.tube(0.44, 0.17, 2.4, (0, 1.2, 0), seg=20)
        for i in range(3):
            for sx in (-1, 1):
                p.box((0.5, 0.32, 0.5), (sx * 0.4, 0.75 + i * 0.6, 0.12), cut=True)       # side ports
        p.box((0.3, 1.6, 0.5), (0, 1.3, 0.42), cut=True)                                   # the top slot
        return [p]
    if k == "scope":
        L, bell = o["length"], o["bell"]
        up = 0.75 if o.get("low") else 1.0
        body = Part("A3", "Scope", "Gunmetal", "Acc", explode=(0, 0, 0))
        body.cyl(0.42, L - 2.2, (0, 0, up), seg=24)
        body.cyl(0.42, 1.1, (0, L / 2 - 0.55, up), seg=24, r2=bell)                        # objective bell
        body.cyl(bell * 0.92, 1.1, (0, -L / 2 + 0.55, up), seg=24, r2=0.42)                # eyepiece
        body.cyl(0.2, 0.3, (0, 0.2, up + 0.5), axis="Z", seg=14)                           # elevation drum
        body.cyl(0.2, 0.3, (0.5, 0.2, up), axis="X", seg=14)                               # windage drum
        for y in (-0.9, 0.9):                                                              # rings and legs
            body.tube(0.5, 0.4, 0.35, (0, y, up), seg=20)
            body.span((-0.22, y - 0.17, 0.0), (0.22, y + 0.17, up - 0.38), bev=0.03)
        body.span((-0.3, -1.3, 0.0), (0.3, 1.3, 0.14), bev=0.03)                           # the base
        lens = Part("A3a", "Lens", "GlassDark", "AccLens", explode=(0, 0, 0), label="")
        lens.cyl(bell * 0.9, 0.05, (0, L / 2 - 0.05, up), seg=24)
        lens.cyl(bell * 0.8, 0.05, (0, -L / 2 + 0.05, up), seg=24)
        return [body, lens]
    p = Part("A4", "Foregrip", "Polymer", "Acc", explode=(0, 0, 0))
    p.span((-0.35, -0.7, -0.3), (0.35, 0.7, 0.0), bev=0.05)
    p.side([(-0.45, -0.25), (0.45, -0.25), (0.4, -1.6), (0.48, -2.9), (0.38, -3.3), (-0.38, -3.3), (-0.5, -2.9), (-0.42, -1.6)], 0.85, bev=0.16)
    return [p]
