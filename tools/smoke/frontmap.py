# Draws the Front's generated open world from dumpfront.lua's output: shaded relief coloured by what shaped
# the ground (barrows bone-pale, mud, trenches, water, the glade green), sector grid and numbers, crests,
# dugouts, buildings and props. Usage: frontmap.py front.txt out.png
import sys, math
from PIL import Image, ImageDraw, ImageFont
lines = open(sys.argv[1]).read().splitlines()
i = next(k for k, l in enumerate(lines) if l.startswith("GRID"))
x0, z0, x1, z1, step, seed, S = map(int, lines[i].split()[1:])
rows = []
k = i + 1
while lines[k] != "END":
    rows.append([c.split(":") for c in lines[k].split()]); k += 1
H = [[float(c[0]) for c in r] for r in rows]
COL = {"Gr": (92, 80, 66), "Ba": (186, 178, 160), "Ed": (150, 144, 132), "Tr": (40, 32, 26), "Cr": (62, 52, 42), "Ca": (58, 48, 38),
       "Pa": (108, 104, 98), "Ro": (60, 58, 56), "Gl": (78, 128, 62)}
nz, nx = len(rows), len(rows[0])
SC = 4  # pixels per sample
img = Image.new("RGB", (nx * SC, nz * SC + 40), (20, 20, 22))
d = ImageDraw.Draw(img)
for zi in range(nz):
    for xi in range(nx):
        h, tag, water = rows[zi][xi]
        c = COL.get(tag, (100, 100, 100))
        hx = H[zi][min(xi + 1, nx - 1)] - H[zi][max(xi - 1, 0)]
        hz = H[min(zi + 1, nz - 1)][xi] - H[max(zi - 1, 0)][xi]
        shade = max(0.45, min(1.35, 1.0 + (-hx - hz) * 0.06 + (float(h) - 4) * 0.004))
        c = tuple(int(min(255, v * shade)) for v in c)
        if water:
            c = (52, 60, 54)
        d.rectangle([xi * SC, zi * SC, xi * SC + SC - 1, zi * SC + SC - 1], fill=c)
def px(x, z): return ((x - x0) / step * SC, (z - z0) / step * SC)
font = ImageFont.load_default()
PROP = {"Calcified": (230, 222, 205), "Barrow": (245, 240, 225), "Wire": (20, 20, 20), "Nest": (170, 150, 100), "Stump": (50, 40, 34),
        "DeadTree": (40, 32, 28), "Chimney": (150, 70, 50), "Pylon": (140, 90, 60), "Wreck": (30, 30, 30), "FieldGun": (80, 90, 50),
        "Dugout": (230, 200, 120), "LiveTree": (60, 200, 60), "Bush": (70, 170, 70), "Pine": (40, 120, 70), "Crate": (90, 100, 60),
        "Hedgehog": (110, 60, 40), "Rubble": (120, 116, 110)}
for l in lines[k:]:
    p = l.split()
    if not p: continue
    if p[0] == "PAD":
        x, z, r = float(p[1]), float(p[2]), float(p[3])
        a, b = px(x - r + 3, z - r + 3), px(x + r - 3, z + r - 3)
        d.rectangle([a, b], fill=(70, 62, 58), outline=(20, 20, 20))
    elif p[0] == "PROP":
        x, y = px(float(p[2]), float(p[3]))
        c = PROP.get(p[1], (255, 0, 255))
        r = 3 if p[1] in ("Barrow", "Dugout", "Chimney", "LiveTree") else 1
        d.ellipse([x - r, y - r, x + r, y + r], fill=c)
for l in lines[k:]:
    p = l.split()
    if p and p[0] == "SECTOR":
        idx, typ = p[1], p[2]
        cx, cz, kx, kz = map(float, p[3:7])
        a, b = px(cx - S / 2, cz - S / 2), px(cx + S / 2, cz + S / 2)
        d.rectangle([a, b], outline=(200, 190, 120))
        d.text((a[0] + 4, a[1] + 3), f"{idx} {typ}", fill=(255, 240, 160), font=font)
        x, y = px(kx, kz)
        d.ellipse([x - 4, y - 4, x + 4, y + 4], outline=(255, 220, 80), width=2)
        for fx, fz, col in ((float(p[7]), float(p[8]), (90, 130, 230)), (float(p[9]), float(p[10]), (230, 80, 80))):
            x, y = px(fx, fz); d.rectangle([x - 3, y - 3, x + 3, y + 3], fill=col)
    elif p and p[0] == "BASE":
        x, y = px(float(p[2]), float(p[3]))
        col = (90, 130, 230) if p[1] == "Union" else (230, 80, 80)
        d.rectangle([x - 8, y - 12, x + 8, y + 12], fill=col); d.text((x - 14, y + 14), p[1], fill=col, font=font)
d.text((8, nz * SC + 8), f"Generated top-down map of the Front (seed {seed}; not a Studio screenshot). 1 px = {step / SC:.0f} studs. Pale = barrows of calcified dead, gold rings = crests, squares = dugouts.", fill=(170, 170, 170), font=font)
img.save(sys.argv[2])
print("wrote", sys.argv[2], img.size)
