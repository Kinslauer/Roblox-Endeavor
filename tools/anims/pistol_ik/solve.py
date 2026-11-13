# Solve pistol arm poses on the real Conduit body (joint data dumped from a real server) for a grip laid in the palm.
import numpy as np, math, json, sys

def T(p):
    m = np.eye(4); m[:3, 3] = p; return m
def Rm(rx, ry, rz):
    x, y, z = map(math.radians, (rx, ry, rz))
    Rx = np.array([[1, 0, 0], [0, math.cos(x), -math.sin(x)], [0, math.sin(x), math.cos(x)]])
    Ry = np.array([[math.cos(y), 0, math.sin(y)], [0, 1, 0], [-math.sin(y), 0, math.cos(y)]])
    Rz = np.array([[math.cos(z), -math.sin(z), 0], [math.sin(z), math.cos(z), 0], [0, 0, 1]])
    m = np.eye(4); m[:3, :3] = Rx @ Ry @ Rz; return m
def pose(v):
    v = list(v) + [0] * (6 - len(v))
    return T(v[3:6]) @ Rm(*v[:3])

JOINTS = {  # part1: (part0, C0 pos, C1 pos)
    "LowerTorso": ("Root", (0, 0, 0), (0, 0, 0)),
    "UpperTorso": ("LowerTorso", (0, 0.3267, 0), (0, -0.7187, 0)),
    "Head": ("UpperTorso", (0, 0.7187, 0.02), (0, -0.499, 0)),
    "RightUpperArm": ("UpperTorso", (0.858, 0.499, 0), (0, 0.5287, 0)),
    "RightLowerArm": ("RightUpperArm", (0, -0.5287, 0), (0, 0.4514, 0)),
    "RightHand": ("RightLowerArm", (0, -0.4514, 0), (0, 0.2792, 0)),
    "LeftUpperArm": ("UpperTorso", (-0.858, 0.499, 0), (0, 0.5287, 0)),
    "LeftLowerArm": ("LeftUpperArm", (0, -0.5287, 0), (0, 0.4514, 0)),
    "LeftHand": ("LeftLowerArm", (0, -0.4514, 0), (0, 0.2792, 0)),
}
ORDER = ["LowerTorso", "UpperTorso", "Head", "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperArm", "LeftLowerArm", "LeftHand"]

def fk(p):
    w = {"Root": np.eye(4)}
    for part in ORDER:
        p0, c0, c1 = JOINTS[part]
        w[part] = w[p0] @ T(c0) @ pose(p.get(part, (0, 0, 0))) @ np.linalg.inv(T(c1))
    return w

HAND_Y, S = 0.2792, ((0.5584 / 0.564) + (0.2783 / 0.2867)) / 2
PALM_HALF, PALM_Y, GAP = 0.046, -0.17, 0.004
TILT, RAKE = 16, 18

def grip_c0(gc, r):
    """hand part -> model origin, for a model whose barrel is +Y, top +Z, grip centre gc (scaled)."""
    t, a = math.radians(TILT), math.radians(RAKE)
    g = np.array([0, -math.sin(t), -math.cos(t)])
    b = a - t
    f = np.array([0, -math.cos(b), -math.sin(b)])
    u = (g - f * math.sin(a)) / math.cos(a); u /= np.linalg.norm(u)
    right = np.cross(f, u)
    R = np.eye(4); R[:3, 0], R[:3, 1], R[:3, 2] = right, f, u
    pc = np.array([-(PALM_HALF * S + GAP + r), HAND_Y + PALM_Y * S, 0])
    return T(pc) @ R @ T(-np.array(gc))

# the Whisper at scale 0.45: grips at model (0, -1.10, -0.862), barrel centre (0, -0.26, -0.282)
SCALE = float(sys.argv[2]) if len(sys.argv) > 2 else 0.45
GC = np.array([0, -1.10, -0.862]) * SCALE
R_GRIP = (0.2128 / 2 + 0.3817 / 2) / 2 * SCALE
BORE = np.array([0, 0, -0.282]) * SCALE
C0 = grip_c0(GC, R_GRIP)

def gun(w):
    m = w["RightHand"] @ C0
    return m  # model frame: +Y bore, +Z up, +X right
def gunbits(w):
    m = gun(w)
    fwd, up, right = m[:3, 1], m[:3, 2], m[:3, 0]
    grip = (m @ np.append(GC, 1))[:3]
    bore = (m @ np.append(BORE, 1))[:3]
    return fwd, up, right, grip, bore
def gaxis(fwd, up):
    a = math.radians(RAKE); return up * math.cos(a) + fwd * math.sin(a)

def left_palm(w):
    h = w["LeftHand"]
    pt = (h @ np.array([PALM_HALF * S, HAND_Y + PALM_Y * S, 0, 1]))[:3]
    return pt, h[:3, 0], h[:3, 1], h[:3, 2]

def unit(v): v = np.array(v, float); return v / np.linalg.norm(v)

def nelder(f, x0, step=8, iters=6000):
    n = len(x0); pts = [np.array(x0, float)]
    for i in range(n):
        p = np.array(x0, float); p[i] += step; pts.append(p)
    vals = [f(p) for p in pts]
    for _ in range(iters):
        o = np.argsort(vals); pts = [pts[i] for i in o]; vals = [vals[i] for i in o]
        c = np.mean(pts[:-1], axis=0)
        xr = c + (c - pts[-1]); fr = f(xr)
        if fr < vals[0]:
            xe = c + 2 * (c - pts[-1]); fe = f(xe)
            pts[-1], vals[-1] = (xe, fe) if fe < fr else (xr, fr)
        elif fr < vals[-2]:
            pts[-1], vals[-1] = xr, fr
        else:
            xc = c + 0.5 * (pts[-1] - c); fc = f(xc)
            if fc < vals[-1]:
                pts[-1], vals[-1] = xc, fc
            else:
                for i in range(1, len(pts)):
                    pts[i] = pts[0] + 0.5 * (pts[i] - pts[0]); vals[i] = f(pts[i])
    i = int(np.argmin(vals)); return pts[i], vals[i]

RIGHT_VARS = [("RightUpperArm", 0), ("RightUpperArm", 1), ("RightUpperArm", 2), ("RightLowerArm", 0), ("RightLowerArm", 1),
              ("RightHand", 0), ("RightHand", 1), ("RightHand", 2)]
LEFT_VARS = [(n.replace("Right", "Left"), i) for n, i in RIGHT_VARS]

def build(base, vars, x):
    p = {k: list(v) + [0] * (6 - len(v)) for k, v in base.items()}
    for (part, i), val in zip(vars, x):
        p.setdefault(part, [0] * 6)[i] = val
    return p

def solve_right(base, x0, grip_at, fwd_at, up_at=None, wgrip=40, wdir=400, wup=60, reg=0.0004):
    fwd_at = unit(fwd_at)
    def cost(x):
        p = build(base, RIGHT_VARS, x)
        w = fk(p)
        fwd, up, right, grip, bore = gunbits(w)
        c = wdir * (1 - fwd @ fwd_at) + wgrip * np.sum((grip - grip_at) ** 2)
        if up_at is not None:
            c += wup * (1 - up @ unit(up_at))
        # a natural wrist: little bend, the elbow a hinge that only bends forward
        c += reg * (x[5] ** 2 + x[6] ** 2 * 2 + x[7] ** 2) + reg * 0.3 * (x[4] ** 2)
        c += 0.05 * max(0, -x[3]) ** 2 + 0.05 * max(0, x[3] - 150) ** 2
        return c
    best = None
    for k in range(6):
        start = np.array(x0, float) + (np.random.RandomState(k).randn(len(x0)) * 15 if k else 0)
        x, v = nelder(cost, start)
        x, v = nelder(cost, x, step=2)
        if best is None or v < best[1]:
            best = (x, v)
    return best

def solve_left(base, x0, cost_extra, reg=0.0004):
    def cost(x):
        p = build(base, LEFT_VARS, x)
        w = fk(p)
        c = cost_extra(w)
        c += reg * (x[5] ** 2 + x[6] ** 2 * 2 + x[7] ** 2) + reg * 0.3 * (x[4] ** 2)
        c += 0.05 * max(0, -x[3]) ** 2 + 0.05 * max(0, x[3] - 150) ** 2
        return c
    best = None
    for k in range(6):
        start = np.array(x0, float) + (np.random.RandomState(10 + k).randn(len(x0)) * 15 if k else 0)
        x, v = nelder(cost, start)
        x, v = nelder(cost, x, step=2)
        if best is None or v < best[1]:
            best = (x, v)
    return best

def support(w, tight=1.0):
    """the off hand wrapped over the firing hand: palm against the left of the grip, fingers down it, thumb forward"""
    fwd, up, right, grip, bore = gunbits(w)
    g = gaxis(fwd, up)
    want = grip - right * (R_GRIP + 0.085) - g * 0.03 + fwd * 0.03
    pt, X, Y, Z = left_palm(w)
    return 60 * np.sum((pt - want) ** 2) + 30 * (1 - X @ right) + 30 * (1 - Y @ g)

def report(name, p):
    w = fk(p)
    fwd, up, right, grip, bore = gunbits(w)
    out = {"fwd": fwd.round(3).tolist(), "up": up.round(3).tolist(), "grip": grip.round(3).tolist(), "bore": bore.round(3).tolist()}
    pt, X, Y, Z = left_palm(w)
    out["left_palm"] = pt.round(3).tolist(); out["left_X"] = X.round(2).tolist(); out["left_fingers"] = (-Y).round(2).tolist()
    print(name, json.dumps(out))
    print("   ", {k: [round(float(a), 1) for a in v[:3]] for k, v in p.items() if "Arm" in k or "Hand" in k})

def fmt(p):
    keys = ["UpperTorso", "Head", "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperArm", "LeftLowerArm", "LeftHand"]
    return "{" + ", ".join('"%s": (%s)' % (k, ", ".join("%g" % round(float(a)) for a in p[k][:3])) for k in keys if k in p) + "}"

if __name__ == "__main__":
    which = sys.argv[1] if len(sys.argv) > 1 else "all"
    results = {}
    # Aim: two hands, the gun at chin height in front of the face, bore dead ahead and level, upright
    if which in ("all", "aim"):
        base = {"UpperTorso": (-2, -6, 0), "Head": (0, 6, 0)}
        xr, v = solve_right(base, [88, 0, -28, 10, 0, 0, 0, 0], grip_at=np.array([0.22, 1.9, -1.6]), fwd_at=(0, 0, -1), up_at=(0, 1, 0))
        p = build(base, RIGHT_VARS, xr)
        xl, v2 = solve_left(p, [84, 0, 44, 10, 0, 0, 0, 0], support)
        p = build(p, LEFT_VARS, xl)
        report("AIM %.4f %.4f" % (v, v2), p); results["aim"] = p
    print(json.dumps({k: {a: [round(float(x), 1) for x in b] for a, b in v.items()} for k, v in results.items()}))
