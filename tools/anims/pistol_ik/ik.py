# Analytic arm IK on the real Conduit body for a pistol laid in the palm (see solve.py for the body and the grip).
import numpy as np, math, json, sys
from solve import fk, pose, T, Rm, C0, GC, BORE, R_GRIP, gaxis, unit, PALM_HALF, PALM_Y, HAND_Y, S, RAKE, gunbits, left_palm

L1, L2 = 1.0574, 0.9028

def euler(R):
    y = math.asin(max(-1, min(1, R[0, 2])))
    x = math.atan2(-R[1, 2], R[2, 2]); z = math.atan2(-R[0, 1], R[0, 0])
    return [math.degrees(x), math.degrees(y), math.degrees(z)]

def gun_frame(grip_at, fwd, up):
    fwd = unit(fwd); up = unit(up - fwd * (up @ fwd)); right = np.cross(fwd, up)
    G = np.eye(4); G[:3, 0], G[:3, 1], G[:3, 2] = right, fwd, up
    G[:3, 3] = grip_at - G[:3, :3] @ GC
    return G

def arm(torso, side, H, swivels=range(-180, 180, 3), wrist_w=1.0, prefer=None):
    """joint angles for an arm whose hand part ends at world frame H. side 'Right'/'Left'."""
    sx = 0.858 if side == "Right" else -0.858
    Sh = (torso @ np.array([sx, 0.499, 0, 1]))[:3]
    W = (H @ np.array([0, 0.2792, 0, 1]))[:3]
    d = W - Sh; dist = np.linalg.norm(d)
    if dist > L1 + L2 - 1e-4:
        W = Sh + d / dist * (L1 + L2 - 1e-4); dist = L1 + L2 - 1e-4
    dn = d / dist
    # elbow circle
    a = (L1 ** 2 - L2 ** 2 + dist ** 2) / (2 * dist); h = math.sqrt(max(0, L1 ** 2 - a ** 2))
    c = Sh + dn * a
    ref = unit(np.cross(dn, [0, 1, 0]) if abs(dn[1]) < 0.95 else np.cross(dn, [1, 0, 0]))
    ref2 = np.cross(dn, ref)
    best = None
    for sw in swivels:
        t = math.radians(sw)
        E = c + h * (ref * math.cos(t) + ref2 * math.sin(t))
        Yu = unit(Sh - E); fdir = unit(W - E)
        Zu = -(fdir - Yu * (fdir @ Yu)); n = np.linalg.norm(Zu)
        if n < 1e-6:
            continue
        Zu /= n; Xu = np.cross(Yu, Zu)
        U = np.eye(4); U[:3, 0], U[:3, 1], U[:3, 2] = Xu, Yu, Zu
        # the upper arm relative to the torso's shoulder frame (C0 has no turn; C1 too)
        Ru = (np.linalg.inv(torso[:3, :3]) @ U[:3, :3])
        ua = euler(Ru)
        cosb = max(-1, min(1, (-fdir) @ Yu * -1))
        bend = math.degrees(math.acos(max(-1, min(1, Yu @ (-fdir) * -1)))) if False else math.degrees(math.acos(max(-1, min(1, (E - Sh) @ fdir / L1 * 1.0 / 1.0 * 1))))
        # elbow flexion = angle between the upper arm's down direction and the forearm
        bend = math.degrees(math.acos(max(-1, min(1, unit(E - Sh) @ fdir))))
        Rl0 = U[:3, :3] @ Rm(bend, 0, 0)[:3, :3]
        # forearm twist: pick it so the wrist bends least
        bestw = None
        for tw in range(-120, 121, 4):
            Rl = Rl0 @ Rm(0, tw, 0)[:3, :3]
            Rh = Rl.T @ H[:3, :3]
            wa = euler(Rh)
            cost = (wa[0] ** 2 + 2 * wa[1] ** 2 + wa[2] ** 2) * wrist_w + 0.3 * tw ** 2
            if bestw is None or cost < bestw[0]:
                bestw = (cost, tw, wa)
        # an elbow that points down and out reads as natural
        down = unit(E - c) @ np.array([0, -1, 0])
        out = unit(E - c) @ np.array([1 if side == "Right" else -1, 0, 0])
        cost = bestw[0] - 6000 * down - 2500 * out + 0.05 * (ua[0] ** 2 * 0 + ua[1] ** 2 + ua[2] ** 2 * 0.3)
        if prefer is not None:
            cost += 2 * sum((a1 - b1) ** 2 for a1, b1 in zip(ua, prefer))
        if best is None or cost < best[0]:
            best = (cost, sw, ua, bend, bestw[1], bestw[2])
    cost, sw, ua, bend, tw, wa = best
    arm.cost = cost
    return {side + "UpperArm": (ua[0], ua[1], ua[2]), side + "LowerArm": (bend, tw, 0), side + "Hand": tuple(wa)}

def support_frame(G, psi=0):
    fwd, up, right = G[:3, 1], G[:3, 2], G[:3, 0]
    grip = (G @ np.append(GC, 1))[:3]
    g = gaxis(fwd, up)
    want = grip - right * (R_GRIP + 0.085) - g * 0.03 + fwd * 0.02
    X = unit(right + up * 0.35); Y0 = unit(g - X * (g @ X)); Z0 = np.cross(X, Y0)
    t = math.radians(psi); Y = Y0 * math.cos(t) + Z0 * math.sin(t); Z = np.cross(X, Y)
    H = np.eye(4); H[:3, 0], H[:3, 1], H[:3, 2] = X, Y, Z
    H[:3, 3] = want - H[:3, :3] @ np.array([PALM_HALF * S, HAND_Y + PALM_Y * S, 0])
    return H

def hand_for(G):
    return G @ np.linalg.inv(C0)

def solve(name, base, grip_at, fwd, up, left=True, **kw):
    w0 = fk(base)
    G = gun_frame(np.array(grip_at, float), np.array(fwd, float), np.array(up, float))
    p = dict(base)
    p.update(arm(w0["UpperTorso"], "Right", hand_for(G), **kw))
    if left:
        best = None
        for psi in range(-30, 61, 5):
            q = arm(w0["UpperTorso"], "Left", support_frame(G, psi))
            if best is None or arm.cost < best[0]:
                best = (arm.cost, psi, q)
        p.update(best[2])
        psi = best[1]
        print("    psi", psi)
    w = fk(p)
    f, u, r, grip, bore = gunbits(w)
    err = {"fwd": f.round(3).tolist(), "grip_err": round(float(np.linalg.norm(grip - np.array(grip_at))), 3), "bore": bore.round(2).tolist()}
    if left:
        pt, X, Y, Z = left_palm(w)
        Hs = support_frame(G, psi)
        err["left_err"] = round(float(np.linalg.norm(pt - (Hs @ np.array([PALM_HALF * S, HAND_Y + PALM_Y * S, 0, 1]))[:3])), 3)
    print(name, json.dumps(err))
    print("   ", {k: tuple(round(float(a)) for a in v[:3]) for k, v in p.items()})
    return p

if __name__ == "__main__":
    for z in (-1.95,):
        solve("aim z%.2f" % z, {"UpperTorso": (-2, -6, 0), "Head": (0, 6, 0)}, [0.15, 1.9, z], [0, 0, -1], [0, 1, 0])

def sheet(poses, path):
    from draw import figure
    from PIL import Image
    imgs = [figure(p, n) for n, p in poses]
    out = Image.new("RGB", (imgs[0].width, imgs[0].height * len(imgs)))
    for i, im in enumerate(imgs): out.paste(im, (0, i * im.height))
    out.save(path)
