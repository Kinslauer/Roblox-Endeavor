import sys; sys.argv=["x"]
import io, contextlib, math, numpy as np, ik
res = []
for torso, xs, left in (({"UpperTorso": (0, 0, 0)}, 0.15, True), ({"UpperTorso": (-4, 8, 0), "Head": (2, -8, 0)}, 0.3, False)):
    best = None
    for pitch in (20, 25, 30, 35):
        d = math.radians(pitch)
        for y in (0.85, 0.95, 1.05, 1.15):
            for z in (-1.3, -1.45, -1.6, -1.75):
                with contextlib.redirect_stdout(io.StringIO()):
                    p = ik.solve("r", torso, [xs, y, z], [0, -math.sin(d), -math.cos(d)], [0, math.cos(d), -math.sin(d)], left=left)
                h = p["RightHand"]; c = h[0]**2 + 2*h[1]**2 + h[2]**2 + (0.4*(p["LeftHand"][0]**2+p["LeftHand"][2]**2) if left else 0) - 30*pitch
                if best is None or c < best[0]: best = (c, pitch, y, z, {k: tuple(round(float(a)) for a in v[:3]) for k, v in p.items()})
    print(best)
