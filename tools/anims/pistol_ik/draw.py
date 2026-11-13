import numpy as np
from PIL import Image, ImageDraw
from solve import fk, gunbits, C0, GC, BORE
def P(w, part, local):
    return (w[part] @ np.append(np.array(local, float), 1))[:3]
def figure(p, label=""):
    w = fk(p)
    lines = []
    for side, col in (("Right", (255, 150, 90)), ("Left", (90, 200, 255))):
        sx = 0.858 if side == "Right" else -0.858
        sh = P(w, "UpperTorso", (sx, 0.499, 0)); el = P(w, side + "UpperArm", (0, -0.5287, 0))
        wr = P(w, side + "LowerArm", (0, -0.4514, 0)); tip = P(w, side + "Hand", (0, -0.28, 0)); th = P(w, side + "Hand", (0, 0, -0.17))
        lines += [(sh, el, col), (el, wr, col), (wr, tip, col), (wr, th, (240, 240, 90))]
    lines += [(P(w, "UpperTorso", (-0.858, 0.499, 0)), P(w, "UpperTorso", (0.858, 0.499, 0)), (220, 220, 230)),
              (P(w, "LowerTorso", (0, 0, 0)), P(w, "UpperTorso", (0, 0.72, 0)), (220, 220, 230)),
              (P(w, "Head", (0, -0.5, 0)), P(w, "Head", (0, 0.5, 0)), (220, 220, 230)),
              (P(w, "Head", (0, 0.1, 0)), P(w, "Head", (0, 0.1, -0.45)), (160, 160, 160))]
    g = w["RightHand"] @ C0
    def M(v): return (g @ np.append(np.array(v, float) * 0.45, 1))[:3]
    # the gun: slide top line, grip line, bore
    lines += [(M((0, -1.25, -0.15)), M((0, 0.3, -0.15)), (120, 255, 120)), (M((0, -1.25, -0.15)), M((0, -1.3, -1.15)), (120, 255, 120)),
              (M((0, -0.95, -0.55)), M((0, -1.0, -1.1)), (60, 160, 60)), (M((0, 0.3, -0.28)), M((0, 2.5, -0.28)), (255, 60, 60))]
    W, H = 260, 300
    img = Image.new("RGB", (W * 3, H), (24, 26, 32)); d = ImageDraw.Draw(img)
    views = [(lambda v: (v[0], v[1])), (lambda v: (-v[2], v[1])), (lambda v: (v[0], -v[2]))]
    names = ["front", "side", "top"]
    for i, f in enumerate(views):
        ox, oy = W * i + W / 2, H * 0.55
        for a, b, c in lines:
            pa, pb = f(a), f(b)
            d.line([(ox + pa[0] * 60, oy - (pa[1] - 1.2) * 60 if i < 2 else oy - pa[1] * 60), (ox + pb[0] * 60, oy - (pb[1] - 1.2) * 60 if i < 2 else oy - pb[1] * 60)], fill=c, width=3)
        d.text((W * i + 4, 4), label + " " + names[i], fill=(200, 200, 200))
    return img
