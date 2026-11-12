# The first-person hands (owner, 2026-11-12: "i think we need fingers"). One upload holds every piece of a hand
# as its own MeshPart: the palm (with the wrist that fills the sleeve), the thumb's mound, and three joints for each
# of the five digits, in three surfaces (bare Flesh, HideLeather gloves, PlateSteel for a cybernetic arm). Nothing is
# skinned: the game places every piece each frame from joint angles (src/war/client/Fingers.lua), so the fingers can
# close on whatever the hand holds.
#
#   blender -b --python tools/models/hands.py            # -> out/ViewHands.fbx, out/ViewHands.json, out/ViewHands.png
#   python3 tools/models/upload.py ViewHands out/ViewHands.fbx   # id -> Assets.FrontBodies.Hands
#   python3 tools/models/hands_lua.py                     # out/ViewHands.json -> src/shared/HandParts.lua
#
# The hand's own frame (Roblox axes, the same as the R15 hand part): the wrist at the origin, the fingers toward -Y,
# the thumb on the -Z side, the palm facing -X on a right hand (+X on a left). Every piece is the same seen from
# either side (X) so one set serves both hands. Blender (x, y, z) = Roblox (x, z, y).
import bpy, bmesh, json, math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lib
from figure import tube, ball_bm, to_object, smooth_shade
from mathutils import Vector

V = Vector
X, Y = V((1, 0, 0)), V((0, 1, 0))

# ---- the design (studs). Lengths of the three joints of each digit, from the knuckle out; radius at each joint's
# base; where the knuckle sits in the hand's frame (Roblox axes).
DIGITS = {
    "Index":  dict(pieces=["I1", "I2", "I3"], root=(0, -0.300, -0.108), lengths=[0.130, 0.080, 0.066], radius=[0.036, 0.033, 0.030]),
    "Middle": dict(pieces=["M1", "M2", "M3"], root=(0, -0.306, -0.036), lengths=[0.142, 0.090, 0.070], radius=[0.037, 0.034, 0.031]),
    "Ring":   dict(pieces=["R1", "R2", "R3"], root=(0, -0.298, 0.036), lengths=[0.132, 0.084, 0.066], radius=[0.035, 0.032, 0.029]),
    "Pinky":  dict(pieces=["P1", "P2", "P3"], root=(0, -0.276, 0.104), lengths=[0.100, 0.062, 0.056], radius=[0.031, 0.028, 0.026]),
    "Thumb":  dict(pieces=["T1", "T2", "T3"], root=(-0.012, -0.070, -0.105), lengths=[0.120, 0.100, 0.084], radius=[0.045, 0.039, 0.035]),
}
THENAR = dict(at=(-0.03, -0.115, -0.085), r=0.062, scale=(0.75, 1.5, 1.0))   # Roblox axes; the mound under the thumb
MATERIALS = {"Flesh": 0.0, "HideLeather": 0.007, "PlateSteel": 0.005}       # surface -> how much thicker than the bare hand
PALM_HALF = 0.046   # half the palm's thickness at its middle (the game puts the palm's face on what it holds)


def phalanx(length, r0, r1, g, last):
    # along Blender -Z from the joint; a little flatter than wide, a pad under the last joint
    st = [(V((0, 0, 0)), (r0 + g) * 0.93, r0 + g),
          (V((0, 0, -length * 0.55)), ((r0 + r1) / 2 + g) * (0.98 if last else 0.9), (r0 + r1) / 2 * 0.97 + g),
          (V((0, 0, -length)), (r1 + g) * 0.9, (r1 + g) * 0.95)]
    return tube(st, n=2.3, seg=12, u=X, v=Y, dome=(1.0, 1.0 if last else 0.9))


def palm(g):
    # stations down Blender Z (= Roblox Y): the cuff inside the sleeve, the wrist, the heel, the knuckles
    st = [(V((0, 0, 0.17)), 0.120 + g, 0.132 + g), (V((0, 0, 0.07)), 0.098 + g, 0.122 + g), (V((0, 0, 0.0)), 0.064 + g, 0.110 + g),
          (V((0, 0, -0.10)), 0.052 + g, 0.134 + g), (V((0, 0, -0.22)), PALM_HALF + g, 0.146 + g), (V((0, 0, -0.30)), 0.040 + g, 0.142 + g)]
    return tube(st, n=2.8, seg=20, u=X, v=Y, dome=(0.25, 0.5))


def centre_rbx(ob):
    xs = [v.co.x for v in ob.data.vertices]
    ys = [v.co.y for v in ob.data.vertices]
    zs = [v.co.z for v in ob.data.vertices]
    c = ((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, (min(zs) + max(zs)) / 2)
    size = (max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs))
    return [round(c[0], 5), round(c[2], 5), round(c[1], 5)], [round(size[0], 5), round(size[2], 5), round(size[1], 5)]


def main():
    lib.reset()
    objs, centres, sizes = [], {}, {}
    slot = 0
    for mat_name, g in MATERIALS.items():
        mat = lib.material(mat_name, (0.6, 0.5, 0.45))
        made = {"Palm": palm(g)}
        t = THENAR
        made["Thenar"] = ball_bm(t["r"] + g, (0, 0, 0), scale=(t["scale"][0], t["scale"][2], t["scale"][1]), seg=14, rings=9)
        for d in DIGITS.values():
            for i, piece in enumerate(d["pieces"]):
                r0 = d["radius"][i]
                r1 = d["radius"][i + 1] if i < 2 else r0 * 0.88
                made[piece] = phalanx(d["lengths"][i], r0, r1, g, i == 2)
        for piece, bm in made.items():
            ob = to_object(f"{piece}_{mat_name}", bm)
            bm.free()
            ob.data.materials.append(mat)
            smooth_shade(ob)
            lib.uv_box(ob)
            if mat_name == "Flesh":
                centres[piece], sizes[piece] = centre_rbx(ob)
            # each piece in its own place on a sheet, so the upload shows them apart (the game places them itself)
            for v in ob.data.vertices:
                v.co += V((slot % 17 * 0.4, list(MATERIALS).index(mat_name) * 0.8, 0))
            slot += 1
            objs.append(ob)
    os.makedirs(lib.OUT, exist_ok=True)
    lib.export_fbx(os.path.join(lib.OUT, "ViewHands.fbx"), objs)
    spec = {"Digits": {k: {kk: vv for kk, vv in d.items()} for k, d in DIGITS.items()}, "Thenar": list(THENAR["at"]),
            "Centres": centres, "Sizes": sizes, "PalmHalf": PALM_HALF, "Thicker": MATERIALS}
    with open(os.path.join(lib.OUT, "ViewHands.json"), "w") as f:
        json.dump(spec, f, indent=1)
    print("ViewHands:", len(objs), "pieces,", sum(len(o.data.polygons) for o in objs), "faces")


main()
