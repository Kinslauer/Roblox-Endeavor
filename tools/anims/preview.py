# Renders animation poses on the real one-piece body, so a pose can be judged before it is uploaded.
#   blender -b tools/models/out/Skin_Conduit.blend --python tools/anims/preview.py -- OUTDIR Name[@t,t,...] ...
# (the .blend is written by tools/models/figures.py). Each frame is drawn from the front quarter and from the side;
# without times, every key of the animation is drawn. The joints are where src/common/Rigs.lua puts them: the top
# centre of each limb box (the bottom for the upper torso and the head).
import bpy, sys, os, math
from mathutils import Matrix, Vector
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "models"))
import anims
from figure import Skeleton
import figures

args = sys.argv[sys.argv.index("--") + 1:]
OUT, wanted = args[0], args[1:]
os.makedirs(OUT, exist_ok=True)
BUILD = os.environ.get("BUILD", "Conduit")
sk = Skeleton(figures.BUILDS[BUILD])
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")

# Roblox (x, y, z) = Blender (x, z, y)
def toR(v):
    return Vector((v.x, v.z, v.y))
M = Matrix(((1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
centre, joint = {}, {}
for l in anims.ORDER:
    lo, hi = sk.box[l]
    c = (lo + hi) / 2
    centre[l] = toR(c)
    z = lo.z if l in ("UpperTorso", "Head") else hi.z
    joint[l] = toR(Vector((c.x, c.y, z)))
joint["LowerTorso"] = centre["LowerTorso"]

def cf(v):
    v = anims.full(v)
    R = Matrix(anims.rot(v[0], v[1], v[2])).to_4x4()
    return Matrix.Translation(Vector(v[3:6])) @ R

def world(pose, root=None):
    """limb -> the 4x4 that moves it from rest (Roblox space)."""
    out = {"HumanoidRootPart": root or Matrix.Identity(4)}
    for l in anims.ORDER:
        J = Matrix.Translation(joint[l])
        out[l] = out[anims.TREE[l]] @ J @ cf(pose.get(l, (0, 0, 0))) @ J.inverted()
    return out

# ---- the swing's arms, as client/ArmIK.lua and Main's swingPose solve them (kept in step by hand)
SHAPES = {"SlashR": [(0, 85, 12), (0.5, 0, 2), (1, -75, -12)], "SlashL": [(0, -70, 6), (0.5, 0, 0), (1, 80, -10)],
          "Overhead": [(0, 8, 85), (0.45, 4, 25), (1, 0, -50)], "Diagonal": [(0, 70, 70), (0.5, 10, 12), (1, -55, -45)],
          "Uppercut": [(0, 15, -55), (1, 0, 60)], "Thrust": [(0, 0, 0), (1, 0, 0)], "Jab": [(0, -4, 4), (1, 0, 2)]}
ROOT = Vector((0, 3.178, 0))
SCALE = (2.178 + 1.2) / 3.0
def angles(shape, u):
    e = max(0, min(1, u)); e = e * e * (3 - 2 * e)
    k = SHAPES[shape]
    for a_, b_ in zip(k, k[1:]):
        if e <= b_[0]:
            f = (e - a_[0]) / max(b_[0] - a_[0], 1e-6)
            return a_[1] + (b_[1] - a_[1]) * f, a_[2] + (b_[2] - a_[2]) * f
    return k[-1][1], k[-1][2]
def lerp(a_, b_, f):
    return a_ + (b_ - a_) * f
def swing_target(shape, t, heavy=False, rng=6.5):
    """t on the body animation's timeline (0.4 wind-up, 0.2 strike, 0.4 recovery) -> hand, aim (root space)."""
    sy, sp = angles(shape, 0); my, mp = angles(shape, 0.5); ey, ep = angles(shape, 1)
    chamber = 0.5 if shape in ("Thrust", "Jab") else 0.66
    RY, RP = 12, -75
    if t < 0.4:
        w = 1 - (1 - t / 0.4) ** 3
        coil = 0.42 if heavy else 0.3
        cy, cp = sy + (sy - my) * coil, sp + (sp - mp) * coil
        yaw, pitch, pull = lerp(RY, cy, w), lerp(RP, cp, w), lerp(0.92, chamber, w)
    elif t < 0.6:
        u = (t - 0.4) / 0.2
        yaw, pitch = angles(shape, u)
        o = min(1, u / 0.55); pull = lerp(chamber, 1, o * o * (3 - 2 * o))
    else:
        r = (t - 0.6) / 0.4
        over = math.sin(min(r * 2, 1) * math.pi / 2) * (0.34 if heavy else 0.24)
        fy, fp = ey + (ey - my) * over, ep + (ep - mp) * over
        back = max(0, min(1, (r - 0.35) / 0.65)); back = back * back * (3 - 2 * back)
        yaw, pitch, pull = lerp(fy, RY, back), lerp(fp, RP, back), lerp(1, 0.9, back)
    y, p_ = math.radians(yaw), math.radians(pitch)
    d = Vector((math.sin(y) * math.cos(p_), math.sin(p_), -math.cos(y) * math.cos(p_)))
    sh = Vector((1.0, 1.25, 0)) * SCALE
    hand = sh + d * (2.1 * SCALE * pull)
    tip = sh + d * max(rng * SCALE, 2.1 * SCALE + 1)
    return hand, (tip - hand).normalized(), tip

def ik_elbow(S, G, a_, b_, pole):
    to = G - S
    d = to.length
    dr = to / d
    d = max(abs(a_ - b_) + 0.03, min((a_ + b_) * 0.985, d))
    cosA = max(-1, min(1, (a_ * a_ + d * d - b_ * b_) / (2 * a_ * d)))
    side = pole - dr * pole.dot(dr)
    side.normalize()
    return S + dr * (a_ * cosA) + side * (a_ * math.sqrt(1 - cosA * cosA)), S + dr * d

def mat(origin, x, y, z):
    m = Matrix.Identity(4)
    for i in range(3):
        m[i][0], m[i][1], m[i][2], m[i][3] = x[i], y[i], z[i], origin[i]
    return m

def arm_ik(W, side, grip, aim, pole=None, off=None):
    """Overrides W[side arm limbs] so the palm is at grip (root space) and the weapon runs along aim."""
    sg = 1 if side == "Right" else -1
    torso = W["UpperTorso"]
    S = torso @ joint[side + "UpperArm"]
    a_ = (joint[side + "LowerArm"] - joint[side + "UpperArm"]).length
    b_ = (joint[side + "Hand"] - joint[side + "LowerArm"]).length
    G = ROOT + grip
    pole = pole or Vector((0.55 * sg, -0.7, 0.45))
    off = off or Vector((0, -0.22, 0))
    Wt = G
    for _ in range(2):
        E, reached = ik_elbow(S, Wt, a_, b_, pole)
        fore = (reached - E).normalized()
        up = -(E - S).normalized()
        z = -(fore - up * fore.dot(up)); z.normalize()
        ux = up.cross(z)
        upper = mat(S, ux, up, z)
        lower = mat(E, ux, -fore, ux.cross(-fore))
        if aim is not None:
            x = ux - aim * ux.dot(aim); x.normalize()
            hand = mat(reached, x, (-aim).cross(x), -aim)
        else:
            hand = lower.copy(); hand.translation = reached
        Wt = G - hand.to_3x3() @ off
    W[side + "UpperArm"] = upper @ Matrix.Translation(-joint[side + "UpperArm"])
    W[side + "LowerArm"] = lower @ Matrix.Translation(-joint[side + "LowerArm"])
    W[side + "Hand"] = hand @ Matrix.Translation(-joint[side + "Hand"])
    return (S - G).length > (a_ + b_) * 1.04

def ease(u):
    return u * u * (3 - 2 * u)

def sample(a, t):
    keys = a["keys"]
    if t <= keys[0][0]:
        return keys[0][1]
    for (t0, p0, _, _), (t1, p1, _, _) in zip(keys, keys[1:]):
        if t <= t1:
            u = ease((t - t0) / max(1e-6, t1 - t0))
            out = {}
            for k in set(p0) | set(p1):
                a0, a1 = anims.full(p0.get(k, (0, 0, 0))), anims.full(p1.get(k, (0, 0, 0)))
                out[k] = tuple(x + (y - x) * u for x, y in zip(a0, a1))
            return out
    return keys[-1][1]

rod = None
def weapon(a_, b_):
    """A plain rod from a_ to b_ (Roblox space) standing in for the held weapon."""
    global rod
    if rod is None:
        bpy.ops.mesh.primitive_cylinder_add(radius=0.07, depth=1, vertices=10)
        rod = bpy.context.object
        m = bpy.data.materials.new("Rod"); m.diffuse_color = (0.9, 0.35, 0.1, 1); m.use_nodes = True
        m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.9, 0.35, 0.1, 1)
        m.node_tree.nodes["Principled BSDF"].inputs["Emission Color"].default_value = (0.9, 0.35, 0.1, 1)
        m.node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = 1.5
        rod.data.materials.append(m)
    if a_ is None:
        rod.hide_render = True
        return
    rod.hide_render = False
    pa, pb = Vector((a_.x, a_.z, a_.y)), Vector((b_.x, b_.z, b_.y))
    rod.location = (pa + pb) / 2
    rod.scale = (1, 1, (pb - pa).length)
    rod.rotation_euler = (pb - pa).to_track_quat("Z", "Y").to_euler()

def apply(pose, base=None, swing=None):
    if base:
        pose = anims.merge(base, pose)
    W = world(pose)
    weapon(None, None)
    if swing:
        shape, t, heavy, two = swing
        hand, aim, tip = swing_target(shape, t, heavy)
        arm_ik(W, "Right", hand, aim)
        if two:
            arm_ik(W, "Left", hand + aim * (two * SCALE), None)
        weapon(ROOT + hand - aim * 0.5, ROOT + tip)
    for pb in arm.pose.bones:
        if pb.name in W:
            pb.matrix = (M @ W[pb.name] @ M) @ pb.bone.matrix_local
            bpy.context.view_layer.update()

sc = bpy.context.scene
sc.render.engine = "CYCLES"
sc.cycles.device = "CPU"
sc.cycles.samples = int(os.environ.get("SAMPLES", 6))
sc.cycles.use_denoising = False
sc.cycles.max_bounces = 1
sc.render.resolution_x, sc.render.resolution_y = int(os.environ.get("W", 300)), int(os.environ.get("H", 400))
sc.render.film_transparent = False
cam = next(o for o in bpy.data.objects if o.type == "CAMERA")
sc.camera = cam
cam.data.type = "ORTHO"
cam.data.ortho_scale = float(os.environ.get("SCALE", 9.5))
def view(az, el=8):
    a, e = math.radians(az), math.radians(el)
    d = Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))
    target = Vector((0, 0, sk.height * 0.5))
    cam.location = target + d * 30
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()

BASES = {"idle": "Idle", "crouch": "Crouch_Idle"}
for w in wanted:
    name, _, ts = w.partition("@")
    name, _, basename = name.partition("+")       # Name+Idle draws the animation over another's first key
    opt = os.environ.get("SWING")                 # SWING=heavy|light[,two-hand offset]: the arms a Swing_ gets in game
    a = anims.ANIMS[name]
    base = anims.ANIMS[basename]["keys"][0][1] if basename else None
    times = [float(t) for t in ts.split(",")] if ts else [k[0] for k in a["keys"]]
    for i, t in enumerate(times):
        swing = None
        if opt and name.startswith("Swing_"):
            o = opt.split(",")
            swing = (name[6:], t / a["length"], o[0] == "heavy", float(o[1]) if len(o) > 1 else None)
        apply(sample(a, t), base, swing)
        for vn, az in (("a", 35), ("b", 90), ("c", 180)):
            if vn == "c" and not os.environ.get("BACK"):
                continue
            view(az)
            sc.render.filepath = os.path.join(OUT, "%s_%02d_%s.png" % (name, i, vn))
            bpy.ops.render.render(write_still=True)
    print("DREW", name, times, flush=True)
