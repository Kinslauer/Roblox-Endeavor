# Draws a top-down map of the generated world from dumpworld.lua's JSON. Usage: map.py world.json out.png
import json, sys
from PIL import Image, ImageDraw, ImageFont
rows = json.load(open(sys.argv[1]))
S = 0.9  # px per stud
PAD = 60
xs = [r["x"] for r in rows if abs(r["x"]) < 900]; zs = [r["z"] for r in rows if abs(r["z"]) < 900]
minx, maxx, minz, maxz = min(xs) - 40, max(xs) + 40, min(zs) - 40, max(zs) + 40
W, H = int((maxx - minx) * S) + PAD * 2, int((maxz - minz) * S) + PAD * 2
img = Image.new("RGB", (W, H), (14, 14, 18))
d = ImageDraw.Draw(img)
def px(x, z): return (PAD + (x - minx) * S, PAD + (z - minz) * S)
def rect(r, fill, outline=None):
    hx, hz = r["sx"] / 2, r["sz"] / 2
    # rotate footprint by the part's yaw (from its look vector)
    import math
    ang = math.atan2(r["lx"], r["lz"])
    cs, sn = math.cos(ang), math.sin(ang)
    pts = []
    for ox, oz in ((-hx, -hz), (hx, -hz), (hx, hz), (-hx, hz)):
        rx, rz = ox * cs - oz * sn, ox * sn + oz * cs
        pts.append(px(r["x"] + rx, r["z"] + rz))
    d.polygon(pts, fill=fill, outline=outline)
order = {"City": 0, "Arena": 1, "RaidArena": 1, "Destruction": 2, "RaidGate": 3, "Gore": 4}
rows.sort(key=lambda r: (order.get(r["f"], 5), r["y"]))
for r in rows:
    if abs(r["x"]) > 900 or abs(r["z"]) > 900: continue
    f, n = r["f"], r["n"]
    if n in ("CityGround", "ArenaFloor"): continue
    col = (r["r"], r["g"], r["b"])
    if r["neon"]:
        rect(r, col)
    elif f == "City":
        shade = min(255, 60 + int(r["sy"] * 1.2))
        if n == "Tower": rect(r, (shade // 2 + col[0] // 3, shade // 2 + col[1] // 3, shade // 2 + col[2] // 3), (90, 90, 110))
        elif n.startswith("Lockup"): rect(r, (120, 110, 60), (200, 180, 90))
        elif n == "Lootable" or r["label"]: rect(r, (230, 190, 60))
        else: rect(r, col)
    elif f == "Destruction":
        if r["tier"]:
            tcol = {"Weak": (170, 120, 60), "Standard": (150, 150, 170), "Reinforced": (90, 110, 200), "Sealed": (240, 60, 60)}[r["tier"]]
            rect(r, tcol, (255, 255, 255))
        elif r["prop"]: rect(r, (170, 150, 110))
        else: rect(r, col)
    elif f == "RaidGate": rect(r, (255, 40, 40), (255, 200, 200))
    elif f == "Arena": rect(r, col if n != "Wall" else (80, 80, 95))
    else: rect(r, col)
# labels
try: font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 22); small = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 14)
except Exception: font = small = ImageFont.load_default()
for name, (x, z) in {"TRANSIT HUB": (0, -420), "CORP PLAZA": (420, 0), "THE SPRAWL": (-420, 0), "BLACKOUT ZONE": (0, 420), "THE PIT (arena)": (0, 0), "Test Armory": (0, 132)}.items():
    p = px(x, z); d.text((p[0] - 60, p[1] - 12), name, fill=(255, 255, 255), font=font if "Armory" not in name else small)
legend = ["tower (lighter = taller)", "neon signage / pylon", "lockup + breach door: brown Weak, grey Standard, blue Reinforced, red Sealed", "tan = breakable props", "gold = loot caches", "red gate = Blackout raid gate"]
y = 10
for t in legend:
    d.text((10, y), t, fill=(220, 220, 220), font=small); y += 18
d.text((10, H - 30), "Generated top-down map of the Conduit world (not a Studio screenshot). 1 px = %.1f studs" % (1 / S), fill=(160, 160, 160), font=small)
img.save(sys.argv[2])
print("wrote", sys.argv[2], W, H)
