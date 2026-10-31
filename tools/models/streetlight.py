# A ruined-city streetlight: leaning steel pole, bent arm, boxy sodium lamp head with a cracked
# lens, rust band at the base, a bolted footplate. Plus the chunks it breaks into.
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *

reset()
steel = material("Steel", (0.30, 0.31, 0.34), metallic=0.8, roughness=0.55)
rust = material("Rust", (0.36, 0.20, 0.12), metallic=0.3, roughness=0.9)
lens = material("Lens", (0.95, 0.85, 0.55), roughness=0.3, emission=(1.0, 0.85, 0.5))
housing = material("Housing", (0.18, 0.18, 0.2), metallic=0.6, roughness=0.5)

def build_intact():
    parts = []
    foot = cylinder("Footplate", 1.1, 0.25, rust, segments=8, location=(0, 0, 0.125))
    bevel(foot, 0.03)
    parts.append(foot)
    for i in range(4):
        a = i * math.pi / 2 + math.pi / 4
        bolt = cylinder(f"Bolt{i}", 0.09, 0.12, steel, segments=6, location=(math.cos(a) * 0.8, math.sin(a) * 0.8, 0.3))
        parts.append(bolt)
    base = cylinder("Base", 0.42, 1.2, rust, segments=12, location=(0, 0, 0.85), radius2=0.36)
    parts.append(base)
    pole = cylinder("Pole", 0.34, 11.0, steel, segments=12, location=(0, 0, 6.9), radius2=0.24)
    jitter(pole, 0.012, seed=3)
    parts.append(pole)
    # the arm: bent forward and slightly drooping, like it took a hit
    arm = cylinder("Arm", 0.2, 3.4, steel, segments=10, location=(1.45, 0, 12.55), radius2=0.16)
    arm.rotation_euler = (0, math.radians(78), 0)
    parts.append(arm)
    brace = cylinder("Brace", 0.1, 2.2, steel, segments=6, location=(0.75, 0, 11.75))
    brace.rotation_euler = (0, math.radians(40), 0)
    parts.append(brace)
    head = box("Head", (2.4, 1.1, 0.7), housing, location=(3.0, 0, 12.75))
    bevel(head, 0.08, 3)
    jitter(head, 0.015, seed=7)
    parts.append(head)
    hood = box("Hood", (2.6, 1.3, 0.12), housing, location=(3.0, 0, 13.15))
    bevel(hood, 0.03)
    parts.append(hood)
    glass = box("Lens", (2.0, 0.8, 0.14), lens, location=(3.0, 0, 12.38))
    parts.append(glass)
    for p in parts:
        apply_mods(p)
    return parts

intact = build_intact()
for o in intact:
    o.location.z -= 0  # footplate sits on z=0 (Roblox: on the ground)
export_fbx(os.path.join(OUT, "Streetlight.fbx"), intact)
render(os.path.join(OUT, "Streetlight_preview.png"), intact, elevation=0.25, azimuth=0.9)

# ---- chunks: two pole lengths and the lamp head, each its own file
reset()
steel = material("Steel", (0.30, 0.31, 0.34), metallic=0.8, roughness=0.55)
housing = material("Housing", (0.18, 0.18, 0.2), metallic=0.6, roughness=0.5)
lens = material("Lens", (0.95, 0.85, 0.55), roughness=0.3)
p1 = cylinder("PipeLong", 0.3, 6.0, steel, segments=12, location=(0, 0, 0), radius2=0.26)
jitter(p1, 0.03, seed=11)
p1.rotation_euler = (math.radians(90), 0, 0)
export_fbx(os.path.join(OUT, "Chunk_PipeLong.fbx"), [p1])
reset()
steel = material("Steel", (0.30, 0.31, 0.34), metallic=0.8, roughness=0.55)
p2 = cylinder("PipeShort", 0.3, 4.5, steel, segments=12, location=(0, 0, 0), radius2=0.24)
jitter(p2, 0.03, seed=12)
p2.rotation_euler = (math.radians(90), 0, 0)
export_fbx(os.path.join(OUT, "Chunk_PipeShort.fbx"), [p2])
reset()
housing = material("Housing", (0.18, 0.18, 0.2), metallic=0.6, roughness=0.5)
lens = material("Lens", (0.95, 0.85, 0.55), roughness=0.3)
h = box("HeadChunk", (2.4, 1.1, 0.7), housing)
bevel(h, 0.08, 3); jitter(h, 0.04, seed=13); apply_mods(h)
g = box("LensShard", (1.2, 0.7, 0.12), lens, location=(-0.3, 0, -0.38))
export_fbx(os.path.join(OUT, "Chunk_LampHead.fbx"), [h, g])
print("STREETLIGHT DONE")
