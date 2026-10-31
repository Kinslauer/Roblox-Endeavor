# The street props of the Conduit city, each in up to three conditions: A intact, B worn, C wrecked.
# Rematerialization picks a condition at random, so the same corner never comes back quite the same.
# Run: blender -b --python props.py  -> out/<Prop>_<A|B|C>.fbx (+ previews)
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *

def mats():
    return dict(
        steel=material("Steel", (0.30, 0.31, 0.34), metallic=0.8, roughness=0.55),
        dark=material("DarkMetal", (0.16, 0.16, 0.18), metallic=0.6, roughness=0.5),
        rust=material("Rust", (0.36, 0.20, 0.12), metallic=0.3, roughness=0.9),
        wood=material("Wood", (0.42, 0.30, 0.17), roughness=0.85),
        oldwood=material("OldWood", (0.30, 0.24, 0.16), roughness=0.95),
        paint=material("Paint", (0.55, 0.16, 0.14), metallic=0.4, roughness=0.6),
        green=material("SignGreen", (0.10, 0.42, 0.22), metallic=0.3, roughness=0.5),
        white=material("SignWhite", (0.85, 0.85, 0.80), roughness=0.5),
        glass=material("Glass", (0.45, 0.65, 0.80), roughness=0.15, metallic=0.1),
        neon=material("Neon", (0.05, 0.75, 0.95), emission=(0.1, 0.9, 1.0)),
        pink=material("NeonPink", (0.95, 0.20, 0.60), emission=(1.0, 0.2, 0.6)),
        concrete=material("Concrete", (0.40, 0.40, 0.42), roughness=0.95),
        tyre=material("Tyre", (0.08, 0.08, 0.08), roughness=0.9),
        chain=material("Chainlink", (0.40, 0.42, 0.45), metallic=0.7, roughness=0.6),
        burnt=material("Burnt", (0.12, 0.10, 0.09), roughness=0.95),
        screen=material("Screen", (0.05, 0.30, 0.45), emission=(0.1, 0.6, 0.9)),
    )

def finish(name, parts, az=0.9, el=0.3):
    for p in parts:
        apply_mods(p)
    export_fbx(os.path.join(OUT, name + ".fbx"), parts)
    render(os.path.join(OUT, name + "_preview.png"), parts, azimuth=az, elevation=el)
    print("BUILT", name)

# ---------------- Crate: a riveted supply crate (A), a split one (B), a burst one (C)
def crate(cond):
    reset(); m = mats(); parts = []
    body = box("Body", (3, 3, 3), m["wood"] if cond != "C" else m["oldwood"], (0, 0, 1.5)); bevel(body, 0.06); jitter(body, 0.02 + 0.03 * (cond == "C"), 2); parts.append(body)
    for z in (0.35, 1.5, 2.65):
        band = box(f"Band{z}", (3.1, 3.1, 0.2), m["rust"] if cond != "A" else m["steel"], (0, 0, z)); parts.append(band)
    for x in (-1.0, 1.0):
        for y in (-1.56, 1.56):
            s = box(f"Slat{x}{y}", (0.5, 0.06, 2.6), m["wood"], (x, y, 1.5)); parts.append(s)
    if cond == "B":
        lid = box("Lid", (3.1, 3.1, 0.25), m["oldwood"], (0.4, 0.2, 3.2)); lid.rotation_euler = (math.radians(14), math.radians(-6), 0.1); parts.append(lid)
    if cond == "C":
        for i in range(4):
            pl = box(f"Plank{i}", (1.4, 0.3, 0.1), m["oldwood"], (random.uniform(-2, 2), random.uniform(-2, 2), 0.06)); pl.rotation_euler = (0, 0, random.uniform(0, 3)); parts.append(pl)
    finish(f"Crate_{cond}", parts)

# ---------------- Barrel: rusted drum (A), dented with leak stain (B), burst open (C)
def barrel(cond):
    reset(); m = mats(); parts = []
    drum = cylinder("Drum", 1.25, 3.5, m["paint"] if cond == "A" else m["rust"], 16, (0, 0, 1.75)); jitter(drum, 0.02 + 0.05 * (cond != "A"), 4); parts.append(drum)
    for z in (0.9, 1.75, 2.6):
        ring = cylinder(f"Ring{z}", 1.32, 0.18, m["steel"], 16, (0, 0, z)); parts.append(ring)
    if cond == "C":
        drum.scale = (1, 1, 0.55); drum.location.z = 0.95
        lid = cylinder("Lid", 1.2, 0.1, m["rust"], 16, (1.6, 0.4, 0.06)); lid.rotation_euler = (0, 0.3, 0.2); parts.append(lid)
        for i in range(3):
            shard = box(f"Shard{i}", (0.9, 0.4, 0.08), m["rust"], (random.uniform(-2, 2), random.uniform(-2, 2), 0.05)); shard.rotation_euler = (0, 0, random.uniform(0, 3)); parts.append(shard)
    if cond != "A":
        stain = cylinder("Stain", 1.9, 0.03, m["burnt"], 12, (0.5, -0.3, 0.015)); parts.append(stain)
    finish(f"Barrel_{cond}", parts)

# ---------------- Street sign: post + green plate (A), bent post (B), plate hanging by one bolt (C)
def sign(cond):
    reset(); m = mats(); parts = []
    post = cylinder("Post", 0.16, 8, m["steel"] if cond == "A" else m["rust"], 8, (0, 0, 4)); parts.append(post)
    if cond == "B": post.rotation_euler = (math.radians(9), 0, 0)
    plate = box("Plate", (3.2, 0.12, 1.6), m["green"], (0, 0.2, 7.4)); parts.append(plate)
    text = box("Text", (2.4, 0.03, 0.5), m["white"], (0, 0.28, 7.4)); parts.append(text)
    if cond == "C": plate.rotation_euler = (0, math.radians(-28), math.radians(10)); plate.location = (0.8, 0.2, 6.9); text.rotation_euler = plate.rotation_euler; text.location = (0.85, 0.28, 6.9)
    if cond != "A":
        plate2 = box("Plate2", (1.8, 0.12, 0.6), m["white"], (0, 0.2, 5.6)); plate2.rotation_euler = (0, 0, math.radians(-12 if cond == "C" else 3)); parts.append(plate2)
    finish(f"StreetSign_{cond}", parts)

# ---------------- Fence panel: chain-link in a pipe frame (A), sagging with a hole (B), collapsed (C)
def fence(cond):
    reset(); m = mats(); parts = []
    for x in (-3, 3):
        post = cylinder(f"Post{x}", 0.18, 5.2, m["steel"] if cond == "A" else m["rust"], 8, (x, 0, 2.6)); parts.append(post)
    top = cylinder("TopRail", 0.12, 6.2, m["steel"], 8, (0, 0, 5.0)); top.rotation_euler = (0, math.radians(90), 0); parts.append(top)
    mesh = box("Mesh", (5.8, 0.05, 4.6), m["chain"], (0, 0, 2.5)); parts.append(mesh)
    if cond == "B":
        mesh.scale = (0.92, 1, 0.9); mesh.rotation_euler = (math.radians(8), 0, math.radians(4)); mesh.location = (0.1, 0.15, 2.3)
        hole = box("Curl", (1.2, 0.3, 1.0), m["chain"], (-1.4, 0.3, 1.4)); hole.rotation_euler = (0.4, 0.5, 0.2); parts.append(hole)
    if cond == "C":
        mesh.rotation_euler = (math.radians(70), 0, math.radians(6)); mesh.location = (0.3, 1.6, 0.9)
        top.location = (0.2, 1.9, 0.6); top.rotation_euler = (0.2, math.radians(90), 0.1)
        parts[0].rotation_euler = (math.radians(30), 0, 0); parts[1].rotation_euler = (math.radians(-12), 0, 0)
    finish(f"FencePanel_{cond}", parts)

# ---------------- Vending machine: lit (A), dark with cracked front (B), tipped over and gutted (C)
def vending(cond):
    reset(); m = mats(); parts = []
    body = box("Body", (3.5, 3, 7), m["dark"] if cond != "C" else m["burnt"], (0, 0, 3.5)); bevel(body, 0.08, 3); jitter(body, 0.02 + 0.04 * (cond == "C"), 5); parts.append(body)
    front = box("Front", (2.6, 0.15, 4.2), m["glass"] if cond != "C" else m["burnt"], (0, -1.5, 4.1)); parts.append(front)
    strip = box("Strip", (3.0, 0.1, 0.5), m["neon"] if cond == "A" else m["dark"], (0, -1.55, 6.5)); parts.append(strip)
    slot = box("Slot", (1.6, 0.2, 0.5), m["steel"], (0.3, -1.55, 1.2)); parts.append(slot)
    for i in range(3):
        shelf = box(f"Shelf{i}", (2.4, 0.5, 0.06), m["steel"], (0, -1.3, 2.4 + i * 1.1)); parts.append(shelf)
    if cond == "B":
        crack = box("Crack", (0.08, 0.2, 2.6), m["white"], (0.4, -1.58, 4.3)); crack.rotation_euler = (0, 0, 0.3); parts.append(crack)
    if cond == "C":
        for p in parts:
            p.rotation_euler = (0, math.radians(-82), 0); p.location = (p.location.z - 0.5, p.location.y, 1.5 + (-p.location.x) * 0.0)
        body.location = (3.0, 0, 1.6); front.location = (3.4, -1.5, 3.0); strip.location = (6.0, -1.55, 1.6); slot.location = (0.7, -1.55, 1.6)
    finish(f"VendingMachine_{cond}", parts, az=0.6)

# ---------------- Terminal: a street kiosk (A), screen dead (B), ripped open with wires (C)
def terminal(cond):
    reset(); m = mats(); parts = []
    body = box("Body", (2, 1.2, 4.5), m["dark"], (0, 0, 2.25)); bevel(body, 0.06); jitter(body, 0.015 + 0.03 * (cond == "C"), 6); parts.append(body)
    screen = box("Screen", (1.5, 0.08, 1.0), m["screen"] if cond == "A" else (m["glass"] if cond == "B" else m["burnt"]), (0, -0.64, 3.5)); parts.append(screen)
    pad = box("Pad", (1.2, 0.1, 0.5), m["steel"], (0, -0.66, 2.3)); pad.rotation_euler = (math.radians(-30), 0, 0); parts.append(pad)
    base = box("Base", (2.3, 1.5, 0.3), m["concrete"], (0, 0, 0.15)); parts.append(base)
    if cond == "C":
        door = box("Door", (1.6, 0.08, 2.2), m["dark"], (-1.3, -0.9, 1.6)); door.rotation_euler = (0, 0, math.radians(65)); parts.append(door)
        for i in range(4):
            wire = cylinder(f"Wire{i}", 0.05, 1.4, m["paint"] if i % 2 else m["neon"], 6, (random.uniform(-0.4, 0.4), -0.7, random.uniform(1.0, 2.2))); wire.rotation_euler = (random.uniform(0.5, 1.4), random.uniform(-0.5, 0.5), 0); parts.append(wire)
    finish(f"Terminal_{cond}", parts)

# ---------------- Car wreck: stripped sedan (A), burnt-out (B), crushed and overturned (C)
def car(cond):
    reset(); m = mats(); parts = []
    body_mat = m["paint"] if cond == "A" else m["burnt"]
    body = box("Body", (6, 12, 2.3), body_mat, (0, 0, 1.6)); bevel(body, 0.25, 3); jitter(body, 0.06 if cond != "A" else 0.02, 8); parts.append(body)
    cabin = box("Cabin", (5, 5.5, 1.8), body_mat, (0, -0.8, 3.6)); bevel(cabin, 0.3, 3); jitter(cabin, 0.05, 9); parts.append(cabin)
    if cond != "C":
        for x, y in ((-2.6, 3.8), (2.6, 3.8), (-2.6, -3.8), (2.6, -3.8)):
            w = cylinder(f"Wheel{x}{y}", 1.1, 0.8, m["tyre"], 12, (x, y, 1.0)); w.rotation_euler = (0, math.radians(90), 0); parts.append(w)
    else:
        body.rotation_euler = (0, math.radians(165), 0); body.location = (0, 0, 2.2); cabin.rotation_euler = (0, math.radians(165), 0); cabin.location = (0.3, -0.8, 0.9); cabin.scale = (1, 1, 0.55)
        for x, y in ((-2.6, 3.8), (2.6, -3.8)):
            w = cylinder(f"Wheel{x}{y}", 1.1, 0.8, m["tyre"], 12, (x, y, 3.3)); w.rotation_euler = (0, math.radians(90), 0); parts.append(w)
    if cond == "A":
        win = box("Windows", (5.1, 5.6, 1.0), m["glass"], (0, -0.8, 3.8)); parts.append(win)
    finish(f"CarWreck_{cond}", parts, az=0.7, el=0.4)

# ---------------- Slab: a concrete road slab (A), cracked with rebar (B), broken in two (C)
def slab(cond):
    reset(); m = mats(); parts = []
    if cond != "C":
        s = box("Slab", (6, 4, 1.2), m["concrete"], (0, 0, 0.6)); bevel(s, 0.1); jitter(s, 0.03 + 0.03 * (cond == "B"), 10); parts.append(s)
    else:
        a = box("SlabA", (3.2, 4, 1.2), m["concrete"], (-1.6, 0, 0.6)); a.rotation_euler = (0, math.radians(6), 0.05); jitter(a, 0.05, 11); parts.append(a)
        b = box("SlabB", (2.6, 4, 1.2), m["concrete"], (1.8, 0.3, 0.5)); b.rotation_euler = (0, math.radians(-9), -0.1); jitter(b, 0.05, 12); parts.append(b)
    if cond != "A":
        for i in range(3):
            r = cylinder(f"Rebar{i}", 0.06, 2.2, m["rust"], 6, (random.uniform(-2, 2), random.uniform(-1.5, 1.5), 1.3)); r.rotation_euler = (random.uniform(0.8, 1.6), 0, random.uniform(0, 3)); parts.append(r)
    finish(f"Slab_{cond}", parts, el=0.5)

# ---------------- Window pane: lit neon-framed (A), dark (B), shattered frame (C)
def window(cond):
    reset(); m = mats(); parts = []
    frame = box("Frame", (6.2, 0.3, 6.2), m["dark"], (0, 0, 3.1)); parts.append(frame)
    if cond != "C":
        glass = box("Glass", (5.6, 0.12, 5.6), m["glass"], (0, 0, 3.1)); parts.append(glass)
    else:
        for i in range(5):
            sh = box(f"Shard{i}", (random.uniform(0.6, 1.6), 0.1, random.uniform(0.6, 1.8)), m["glass"], (random.uniform(-2.2, 2.2), 0, random.uniform(0.8, 5.4))); sh.rotation_euler = (0, random.uniform(-0.6, 0.6), 0); parts.append(sh)
    bar = box("Mullion", (0.2, 0.34, 5.6), m["dark"], (0, 0, 3.1)); parts.append(bar)
    bar2 = box("Transom", (5.6, 0.34, 0.2), m["dark"], (0, 0, 3.1)); parts.append(bar2)
    if cond == "A":
        glow = box("NeonEdge", (6.4, 0.1, 0.15), m["pink"], (0, -0.2, 6.3)); parts.append(glow)
    finish(f"WindowPane_{cond}", parts, az=0.4, el=0.2)

random.seed(7)
for fn in (crate, barrel, sign, fence, vending, terminal, car, slab, window):
    for cond in ("A", "B", "C"):
        fn(cond)
print("PROPS DONE")
