import sys; sys.argv = ["x"]
import math, numpy as np, json
import ik
from ik import solve, arm, gun_frame, hand_for, unit, GC, R_GRIP, gaxis, PALM_HALF, PALM_Y, HAND_Y, S
from solve import fk, gunbits, left_palm

def rnd(p):
    return {k: tuple(round(float(a)) for a in v[:3]) + tuple(round(float(a), 2) for a in list(v[3:6])) if len(v) > 3 and any(v[3:6]) else tuple(round(float(a)) for a in v[:3]) for k, v in p.items()}

def left_to(p, H):
    w0 = fk(p); q = dict(p); q.update(arm(w0["UpperTorso"], "Left", H)); return q

def palm_frame(X, Y, at):
    X = unit(X); Y = unit(Y - X * (Y @ X)); Z = np.cross(X, Y)
    H = np.eye(4); H[:3, 0], H[:3, 1], H[:3, 2] = X, Y, Z
    H[:3, 3] = at - H[:3, :3] @ np.array([PALM_HALF * S, HAND_Y + PALM_Y * S, 0]); return H

out = {}
out["aim"] = solve("aim", {"UpperTorso": (-2, -6, 0), "Head": (0, 6, 0)}, [0.15, 1.9, -1.95], [0, 0, -1], [0, 1, 0])
out["aim_b"] = solve("aim_b", {"UpperTorso": (-2, -6, 0), "Head": (0, 6, 0)}, [0.15, 1.91, -1.95], [0, 0, -1], [0, 1, 0])
# low ready: in front of the chest, muzzle forward and down
d = math.radians(20)
out["ready"] = solve("ready", {"UpperTorso": (0, 0, 0)}, [0.15, 0.85, -1.75], [0, -math.sin(d), -math.cos(d)], [0, math.cos(d), -math.sin(d)])
out["ready_b"] = solve("ready_b", {"UpperTorso": (0, 0, 0)}, [0.15, 0.87, -1.75], [0, -math.sin(d), -math.cos(d)], [0, math.cos(d), -math.sin(d)])
# reload: the gun up by the chest, muzzle up a little and turned in, canted so the well faces the left hand
f = unit([-0.25, 0.25, -0.93]); up = unit([0.45, 0.85, 0.2]); up = unit(up - f * (up @ f))
rl = solve("reload", {"UpperTorso": (0, 0, 0), "Head": (10, -10, 0)}, [0.3, 1.45, -1.05], f, up, left=False)
w = fk(rl); fw, u, r, grip, bore = gunbits(w); g = gaxis(fw, u)
base_mag = grip - g * 0.2   # the magazine's floor
out["reload"] = rl
out["reload_in"] = left_to(rl, palm_frame(g, fw, base_mag - g * 0.01))          # palm under the floor, fingers forward
out["reload_seat"] = left_to(rl, palm_frame(g, fw, base_mag + g * 0.05))       # driven home
# cover: back to the wall, the gun up by the right shoulder, muzzle up, the top of the gun toward the face
cf = unit([0, 1, -0.25]); cu = unit([-0.35, 0.25, 1]); cu = unit(cu - cf * (cu @ cf))
cov_base = {"LowerTorso": (0, 0, 0, 0, -0.12, 0.2), "UpperTorso": (5, 0, 0), "Head": (-4, 0, 0)}
out["cover"] = solve("cover", cov_base, [0.62, 1.2, -0.75], cf, cu, left=False)
# the intro's ready: one hand, the same low ready on its own turned torso
out["intro_ready"] = solve("intro_ready", {"UpperTorso": (-4, 8, 0), "Head": (2, -8, 0)}, [0.3, 0.85, -1.75], [0, -math.sin(d), -math.cos(d)], [0, math.cos(d), -math.sin(d)], left=False)
# rack over the top: palm down on the back of the slide, fingers over to the gun's right side
for name, base in (("rack_ready", out["ready"]), ("rack_intro", out["intro_ready"])):
    w = fk(base); fw, u, r, grip, bore = gunbits(w)
    rear = (w["RightHand"] @ ik.C0 @ np.array([0, -1.05 * 0.45, -0.12 * 0.45 + 0.03, 1]))[:3]
    out[name + "_over"] = left_to(base, palm_frame(-u, -r, rear))
    out[name + "_back"] = left_to(base, palm_frame(-u, -r, rear - fw * 0.22))
    out[name + "_off"] = left_to(base, palm_frame(-u + r * 0.3, -r, rear - fw * 0.42 + u * 0.12 - r * 0.15))
for k, v in out.items():
    print(k, rnd({a: b for a, b in v.items() if "Arm" in a or "Hand" in a}))
ik.sheet([(k, out[k]) for k in ("aim", "ready", "reload", "reload_in", "cover", "intro_ready", "rack_ready_over", "rack_ready_back")], "poses.png")
