# Draws a top-down map of the generated world from dumpworld.lua's JSON. Usage: map.py world.json out.png [front|world]
# "world" draws the whole map (city + frontier) over the frontier's shaded heightmap (world.heights, written
# by the dump step next to the JSON); the default draws the city only.
import json, sys, os
from PIL import Image, ImageDraw, ImageFont
rows = json.load(open(sys.argv[1]))
FRONT = len(sys.argv) > 3 and sys.argv[3] == "front"
WORLD = len(sys.argv) > 3 and sys.argv[3] == "world"
S = 0.4 if WORLD else 0.9  # px per stud
PAD = 60
LIM = 1100 if WORLD else 900
xs = [r["x"] for r in rows if abs(r["x"]) < LIM]; zs = [r["z"] for r in rows if abs(r["z"]) < 2400 if not WORLD or True]
if WORLD:
    minx, maxx, minz, maxz = -1000, 1000, -1000, 2350
else:
    zs = [r["z"] for r in rows if abs(r["z"]) < 900]
    minx, maxx, minz, maxz = min(xs) - 40, max(xs) + 40, min(zs) - 40, max(zs) + 40
W, H = int((maxx - minx) * S) + PAD * 2, int((maxz - minz) * S) + PAD * 2
img = Image.new("RGB", (W, H), (14, 14, 18))
d = ImageDraw.Draw(img)
def px(x, z): return (PAD + (x - minx) * S, PAD + (z - minz) * S)
if WORLD and os.path.exists(sys.argv[1] + ".heights"):
    # shaded relief: valley floor dark green, slopes grey, peaks white; the city plateau asphalt
    hp = open(sys.argv[1] + ".heights").read().split("\n")
    hx0, hz0, step = [float(v) for v in hp[0].split()[1:]]
    grid = [[float(v) for v in line.split(",")] for line in hp[1:] if line and not line.startswith("HEIGHT")]
    for j, row in enumerate(grid):
        for i, h in enumerate(row):
            x, z = hx0 + i * step, hz0 + j * step
            if abs(x) <= 700 and abs(z) <= 700: col = (42, 44, 50)
            else:
                t = max(0.0, min(1.0, (h + 70) / 380))
                slope = 0
                if i + 1 < len(row) and j + 1 < len(grid): slope = abs(row[i + 1] - h) + abs(grid[j + 1][i] - h)
                if h > 250: col = (225, 225, 235)
                elif slope > 10: col = (int(80 + t * 90), int(78 + t * 90), int(82 + t * 90))
                elif z > 700: col = (int(30 + t * 60), int(70 + t * 90), int(30 + t * 60))
                else: col = (int(60 + t * 80), int(56 + t * 70), int(50 + t * 60))
            p = px(x, z)
            d.rectangle([p, (p[0] + step * S + 1, p[1] + step * S + 1)], fill=col)
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
    if abs(r["x"]) > LIM or (not WORLD and abs(r["z"]) > 900) or r["z"] > 2400 or r["z"] < -1100: continue
    f, n = r["f"], r["n"]
    if n in ("CityGround", "ArenaFloor", "Ground"): continue
    col = (r["r"], r["g"], r["b"])
    if f == "Frontier":
        if n == "Canopy": d.ellipse([px(r["x"] - r["sx"] / 2, r["z"] - r["sz"] / 2), px(r["x"] + r["sx"] / 2, r["z"] + r["sz"] / 2)], fill=col)
        elif n in ("Trunk", "DeadTrunk", "DeadBranch", "LampPole", "LampHead", "LampPost", "LampGlobe", "RailPost", "Rail", "GuyWire", "RoadLine"): pass
        elif n == "Rock": d.ellipse([px(r["x"] - r["sx"] / 2, r["z"] - r["sz"] / 2), px(r["x"] + r["sx"] / 2, r["z"] + r["sz"] / 2)], fill=(120, 118, 122))
        elif n == "ScarpRoad": rect(r, (70, 70, 78))
        elif n == "ValleyTrail" or n == "ReachPath": rect(r, (170, 150, 110))
        elif n == "Hedge": rect(r, (40, 90, 40))
        elif n == "Lootable" or r["label"]: rect(r, (230, 190, 60), (255, 255, 255))
        elif n in ("CheckpointPost", "CheckpointLight"): d.ellipse([px(r["x"] - 12, r["z"] - 12), px(r["x"] + 12, r["z"] + 12)], outline=(255, 150, 30), width=2)
        elif n == "SitePole": d.ellipse([px(r["x"] - 40, r["z"] - 40), px(r["x"] + 40, r["z"] + 40)], outline=(255, 80, 220), width=2)
        else: rect(r, col)
        continue
    if FRONT:
        if n == "Trench" or n == "TrenchFloor": rect(r, (45, 38, 30))
        elif n == "Sandbags": rect(r, (150, 135, 95))
        elif n == "Berm": rect(r, (80, 70, 50))
        elif n == "Wreck": rect(r, (70, 60, 55), (120, 100, 90))
        elif n.startswith("Stage"): rect(r, col, (40, 30, 25))
        elif r["m"] == "Structure": rect(r, col, (40, 30, 25))
        elif n.endswith("Base"): rect(r, (90, 95, 90), (200, 200, 200))
        elif n.endswith("Flag"): rect(r, col)
        elif n == "HillMarker": d.ellipse([px(r["x"]-80, r["z"]-80), px(r["x"]+80, r["z"]+80)], outline=(255, 220, 80), width=3)
        else: rect(r, col)
        continue
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
labels = {"UNION BASE": (-310, 0), "PACT BASE": (310, 0), "THE FRONT": (0, -300)} if FRONT else {"TRANSIT HUB": (0, -420), "CORP PLAZA": (420, 0), "THE SPRAWL": (-420, 0), "BLACKOUT ZONE": (0, 420), "THE PIT (arena)": (0, 0), "Test Armory": (0, 132)}
if WORLD:
    labels.update({"THE SCARP": (120, 745), "SWITCHBACKS": (-420, 860), "THE VALLEY": (-300, 1150), "VERDANT REACH": (0, 1550), "THE RIDGE": (560, 1900),
                   "Ridge Watch": (329, 1826), "Old Mine": (0, 2070), "Signal Mast": (-396, 1945), "Pump Station": (-399, 1515), "Crashed Dropship": (423, 1475), "Logging Camp": (-258, 1243), "Hunter's Shack": (244, 1258)})
for name, (x, z) in labels.items():
    p = px(x, z); d.text((p[0] - 60, p[1] - 12), name, fill=(255, 255, 255), font=font if ("Armory" not in name and not (WORLD and not name.isupper())) else small)
legend = ["brown blocks = structures (4 stages)", "dark strips = trenches, tan = sandbags", "yellow ring = the hill (hot sector)", "grey = faction bases"] if FRONT else ["tower (lighter = taller)", "neon signage / pylon", "lockup + breach door: brown Weak, grey Standard, blue Reinforced, red Sealed", "tan = breakable props", "gold = loot caches", "red gate = Blackout raid gate"]
y = 10
for t in legend:
    d.text((10, y), t, fill=(220, 220, 220), font=small); y += 18
d.text((10, H - 30), ("Generated top-down map of the Front (not a Studio screenshot). 1 px = %.1f studs" if FRONT else "Generated top-down map of the Conduit world (not a Studio screenshot). 1 px = %.1f studs") % (1 / S), fill=(160, 160, 160), font=small)
img.save(sys.argv[2])
print("wrote", sys.argv[2], W, H)
