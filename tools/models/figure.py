# The figure library: one-piece, smoothly bending character bodies (Andy, 2026-11-12: "the ones right now look too
# blocky and disjointed"). Every character is sculpted here as continuous clothed surfaces and SKINNED: each vertex
# follows a blend of the limbs near it, so a bent elbow or knee folds like a sleeve instead of opening a gap between
# two solid blocks.
#
#   blender -b --python tools/models/figure.py -- <Name|all> [--stills] [--export]
#   -> out/Skin_<Name>.fbx (skinned meshes + 15 bones), out/Rig_<Name>.fbx (the invisible limbs), out/figure_<Name>_<view>.png
#
# How it fits the game. The old rigid 15-limb rigs (conduit.py, raider.py, enemies.py, station.py -> Rig_<Name>.fbx)
# stay: they are the skeleton, the hitboxes and the fallback, drawn invisible once a skin is on. A figure reads its
# proportions from that file (limb boxes -> joints), so the skin lines up with the rig it dresses and every existing
# animation fits. Bones are named after the limbs and sit at the limb boxes' centres; server/Rigs.lua lines the skin
# up with the rig, ties each bone to the limb nearest to it, and shared/Skin.lua makes each bone follow its limb
# every frame on the client. Because a bone only copies a limb's motion, nothing about the animations changes.
#
# Sculpting: soft garments are lofted solids (superellipse rings along the limbs) fused by voxel remesh and smoothed,
# then wrinkled and decimated; open garments (hood, coat skirt, collar) are lofted shells; hard kit (plates, visor,
# respirator, soles) keeps crisp edges and follows one bone. One MeshPart per "<Piece>_<Material>".
# Axes: Z up, the face looks along -Y, left limbs at -X (as in the rig scripts).
import bpy, bmesh, math, os, sys
from mathutils import Vector, Matrix, noise
from mathutils.bvhtree import BVHTree
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from lib import *

LIMBS = ["Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm",
         "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot"]
SIDES = (("Left", -1), ("Right", 1))
X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
V = lambda x, y, z: Vector((x, y, z))

def smoothstep(a, b, t):
    if a == b:
        return 0.0 if t < a else 1.0
    u = min(1.0, max(0.0, (t - a) / (b - a)))
    return u * u * (3 - 2 * u)

def keyed(keys, t):
    """keys: [(t, v0, v1, ...)] sorted; eased interpolation of the values at t."""
    if t <= keys[0][0]:
        return keys[0][1:]
    for a, b in zip(keys, keys[1:]):
        if t <= b[0]:
            u = smoothstep(a[0], b[0], t)
            return tuple(x + (y - x) * u for x, y in zip(a[1:], b[1:]))
    return keys[-1][1:]

# ---------------------------------------------------------------- the skeleton, read from the rigid rig
class Skeleton:
    def __init__(s, build, over=None):
        """build: the old blocky rig's measurements (studs): H height, shoulder = joint x, arm and leg = limb half
        widths, stance = hip joint x, depth = half depth of the hips."""
        over = over or {}
        # The old rigs have toy proportions (shoulders 45% of the height wide, a head a fifth of it, short legs). The
        # figure keeps each character's height and build but moves the joints to where a person's are; `over` lets a
        # character push a ratio (a Brute keeps more of his width).
        o = lambda k, d: over.get(k, d)
        H, old_sh, old_ar, old_lr, old_lx, old_hd = build["H"], build["shoulder"], build["arm"], build["leg"], build["stance"], build["depth"]
        s.height = s.z_top = H
        s.z_neck = H * (1 - o("head", 0.168))
        s.z_waist, s.z_hip = H * o("waist", 0.59), H * o("hip", 0.48)
        s.az = H * 0.064
        s.ar, s.lr = old_ar * o("arm", 0.68), old_lr * o("leg", 0.72)
        s.hd = old_hd * o("depth", 0.82)
        xs, lx = old_sh * o("shoulder", 0.65), old_lx * o("stance", 0.71)
        zs = s.z_neck - H * 0.037
        ze = zs - H * 0.178
        zw = ze - H * 0.152
        zt = zw - H * 0.094
        zk = H * 0.27
        flen, fy = H * 0.155, -H * 0.027
        s.sh, s.el, s.wr, s.tip, s.hp, s.kn, s.an, s.foot = {}, {}, {}, {}, {}, {}, {}, {}
        for side, sg in SIDES:
            s.sh[sg], s.el[sg], s.wr[sg], s.tip[sg] = V(sg * xs, 0, zs), V(sg * xs, 0, ze), V(sg * xs, 0, zw), V(sg * xs, 0, zt)
            s.hp[sg], s.kn[sg], s.an[sg] = V(sg * lx, 0, s.z_hip), V(sg * lx, 0, zk), V(sg * lx, fy, s.az)
            fw = s.lr * 0.62
            s.foot[sg] = (V(sg * lx - fw, fy - flen / 2, 0), V(sg * lx + fw, fy + flen / 2, s.az))
        s.hw = o("hw", xs - s.ar - 0.03)                                # chest half width (leaves the armpit open)
        s.hipw = lx + s.lr * 0.9                                        # hip half width
        s.hr = o("hr", (s.z_top - s.z_neck) * 0.37)                     # skull radius
        s.zc = s.z_neck + s.hr * 1.2                                    # skull centre height
        s.hs = (zw - zt) / 0.44                                         # hand scale
        # the limb boxes of the new proportions: the invisible rig is built from these (proxy()), and the bones sit
        # at their centres
        def lim(c, r, z0, z1, ry=None):
            return (V(c.x - r, c.y - (ry or r), z0), V(c.x + r, c.y + (ry or r), z1))
        nb = {"LowerTorso": lim(V(0, 0, 0), s.hipw, s.z_hip, s.z_waist, s.hd), "UpperTorso": lim(V(0, 0, 0), s.hw, s.z_waist, s.z_neck, s.hd * 1.05),
              "Head": lim(V(0, 0.02, 0), s.hr * 0.95, s.z_neck, s.z_top, s.hr * 1.05)}
        for side, sg in SIDES:
            nb[side + "UpperArm"] = lim(s.sh[sg], s.ar, ze, zs)
            nb[side + "LowerArm"] = lim(s.el[sg], s.ar * 0.86, zw, ze)
            nb[side + "Hand"] = lim(s.wr[sg], s.ar * 0.62, zt, zw, s.ar * 0.8)
            nb[side + "UpperLeg"] = lim(s.hp[sg], s.lr, zk, s.z_hip)
            nb[side + "LowerLeg"] = lim(s.kn[sg], s.lr * 0.8, s.az, zk)
            nb[side + "Foot"] = s.foot[sg]
        s.box = nb
        s.centre = {l: (nb[l][0] + nb[l][1]) / 2 for l in LIMBS}

    # ---- the torso as a function of height: half width, half depth, centre y
    def torso(s, z):
        W, D, zh, zw, zn = s.hw, s.hd, s.z_hip, s.z_waist, s.z_neck
        ut, nr = zn - zw, s.hr * 0.52
        zs = s.sh[1].z
        keys = [(zh - 0.24, s.hipw * 0.56, 0.66 * D, 0.0), (zh + 0.08, s.hipw, 0.98 * D, 0.01), (zw + 0.03, 0.84 * W, 0.90 * D, 0.0),
                (zw + 0.45 * (zs - zw), 0.95 * W, 1.04 * D, -0.02), (zw + 0.78 * (zs - zw), 1.0 * W, 1.08 * D, -0.03), (zs - 0.06, 0.9 * W, 0.92 * D, 0.0),
                (zs + 0.1, 0.52 * W, 0.70 * D, 0.03), (zs + 0.2, nr * 1.2, nr * 1.2, 0.03), (zn + 0.4, nr, nr, 0.02)]
        return keyed(keys, z)

    def torso_point(s, z, deg, off=0.0, n=2.5):
        """A point on the torso surface pushed out by off; deg 0 = the right side (+X), -90 = the front."""
        hw, hd, cy = s.torso(z)
        a = math.radians(deg)
        e = 2.0 / n
        ca, sa = math.cos(a), math.sin(a)
        p = V(math.copysign(abs(ca) ** e, ca) * hw, cy + math.copysign(abs(sa) ** e, sa) * hd, z)
        nrm = V(p.x / (hw * hw), (p.y - cy) / (hd * hd), 0).normalized()
        return p + nrm * off, nrm

    # ---- limb centre lines and radii
    def arm(s, sg, z):
        """centre, radius of the arm at height z (shoulder top .. wrist)."""
        sh, el, wr, ar = s.sh[sg], s.el[sg], s.wr[sg], s.ar
        if z >= el.z:
            t = (sh.z - z) / max(1e-6, sh.z - el.z)
            r = keyed([(0.0, 0.92), (0.22, 1.08), (0.62, 0.98), (1.0, 0.86)], t)[0] * ar
            return sh.lerp(el, min(1, max(0, t))), r
        t = (el.z - z) / max(1e-6, el.z - wr.z)
        r = keyed([(0.0, 0.86), (0.25, 0.92), (0.8, 0.70), (1.0, 0.62)], t)[0] * ar
        return el.lerp(wr, min(1, max(0, t))), r

    def leg(s, sg, z):
        hp, kn, an, lr = s.hp[sg], s.kn[sg], s.an[sg], s.lr
        ank = V(kn.x, kn.y, s.az)
        if z >= kn.z:
            t = (hp.z - z) / max(1e-6, hp.z - kn.z)
            r = keyed([(-0.3, 0.92), (0.0, 1.0), (0.2, 1.0), (0.65, 0.88), (1.0, 0.76)], t)[0] * lr
            return hp.lerp(kn, t), r, 0.0
        t = (kn.z - z) / max(1e-6, kn.z - ank.z)
        r, back = keyed([(0.0, 0.76, 0.0), (0.28, 0.80, 0.04), (0.85, 0.58, 0.0), (1.0, 0.55, 0.0)], t)
        return kn.lerp(ank, t), r * lr, back

    # ---- the 15 bones as segments for weighting: name -> (a, b, radius)
    def segments(s):
        seg = {}
        for side, sg in SIDES:
            seg[side + "UpperArm"] = (s.sh[sg], s.el[sg], s.ar)
            seg[side + "LowerArm"] = (s.el[sg], s.wr[sg], s.ar * 0.9)
            seg[side + "Hand"] = (s.wr[sg], s.tip[sg], s.ar * 0.8)
            seg[side + "UpperLeg"] = (s.hp[sg], s.kn[sg], s.lr)
            seg[side + "LowerLeg"] = (s.kn[sg], V(s.kn[sg].x, s.kn[sg].y, s.az), s.lr * 0.85)
            f = s.foot[sg]
            seg[side + "Foot"] = (V(s.kn[sg].x, f[1].y - 0.15, s.az * 0.45), V(s.kn[sg].x, f[0].y + 0.1, s.az * 0.4), s.az * 0.75)
        return seg

# ---------------------------------------------------------------- mesh building
def ring(c, ru, rv, n=2.0, seg=24, u=X, v=Y, a0=0.0, a1=2 * math.pi, closed=True):
    pts, e = [], 2.0 / n
    for i in range(seg if closed else seg + 1):
        a = a0 + (a1 - a0) * i / seg
        ca, sa = math.cos(a), math.sin(a)
        pts.append(c + u * (math.copysign(abs(ca) ** e, ca) * ru) + v * (math.copysign(abs(sa) ** e, sa) * rv))
    return pts

def skin_rings(rings, closed=True, cap=True):
    bm = bmesh.new()
    rows = [[bm.verts.new(p) for p in r] for r in rings]
    m = len(rows[0])
    for a, b in zip(rows, rows[1:]):
        for i in (range(m) if closed else range(m - 1)):
            j = (i + 1) % m
            bm.faces.new((a[i], a[j], b[j], b[i]))
    if cap and closed:
        bm.faces.new(rows[0])
        bm.faces.new(rows[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm

def tube(stations, n=2.0, seg=24, u=X, v=Y, dome=(1.0, 1.0)):
    """A closed solid through stations [(centre, ru, rv)], with rounded ends (dome = how far each end bulges)."""
    st = list(stations)
    out = []
    def cap(i0, i1, k):
        c, ru, rv = st[i0]
        d = (c - st[i1][0])
        d = d.normalized() if d.length > 1e-6 else u.cross(v)
        r = min(ru, rv) * k
        return [(c + d * (r * math.sin(math.radians(t))), ru * math.cos(math.radians(t)), rv * math.cos(math.radians(t))) for t in (30, 58, 80)]
    if dome[0] > 0:
        out += reversed(cap(0, 1, dome[0]))
    out += st
    if dome[1] > 0:
        out += cap(len(st) - 1, len(st) - 2, dome[1])
    return skin_rings([ring(c, ru, rv, n, seg, u, v) for c, ru, rv in out])

def box_bm(size, at, bev=0.03, rot=None):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    if bev > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bev, offset_type="OFFSET", segments=2, profile=0.5, affect="EDGES", clamp_overlap=True)
    m = Matrix.Translation(Vector(at))
    if rot is not None:
        m = m @ rot
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
    return bm

def ball_bm(r, at, scale=(1, 1, 1), seg=20, rings=12, cut_below=None):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=r)
    if cut_below is not None:
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, 0, cut_below), plane_no=(0, 0, -1), clear_outer=True)
        edges = [e for e in bm.edges if e.is_boundary]
        if edges:
            bmesh.ops.holes_fill(bm, edges=edges)
    bmesh.ops.scale(bm, vec=Vector(scale), verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector(at), verts=bm.verts)
    return bm

def to_object(name, bm):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    return ob

def activate(ob):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob

def modify(ob, kind, **kw):
    m = ob.modifiers.new(kind, kind)
    for k, v in kw.items():
        setattr(m, k, v)
    activate(ob)
    bpy.ops.object.modifier_apply(modifier=m.name)

def tri_count(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)

def decimate(ob, tris):
    n = tri_count(ob)
    if n > tris:
        modify(ob, "DECIMATE", ratio=tris / n)

def smooth_shade(ob, sharp=None):
    for p in ob.data.polygons:
        p.use_smooth = True
    if sharp is not None:
        modify(ob, "EDGE_SPLIT", split_angle=math.radians(sharp))

def fuse(name, bms, voxel=0.03, smooth=5, factor=0.5, cut=None):
    """Voxel-union the solids into one continuous skin, optionally cut holes, then relax it."""
    bm = bmesh.new()
    for b in bms:
        me = bpy.data.meshes.new("t")
        b.to_mesh(me)
        bm.from_mesh(me)
        bpy.data.meshes.remove(me)
    ob = to_object(name, bm)
    bm.free()
    ob.data.remesh_voxel_size = voxel
    ob.data.remesh_voxel_adaptivity = 0.0
    activate(ob)
    bpy.ops.object.voxel_remesh()
    for c in cut or []:
        co = to_object("cut", c)
        m = ob.modifiers.new("b", "BOOLEAN")
        m.operation, m.object, m.solver = "DIFFERENCE", co, "EXACT"
        activate(ob)
        bpy.ops.object.modifier_apply(modifier=m.name)
        bpy.data.objects.remove(co)
    if smooth:
        modify(ob, "SMOOTH", factor=factor, iterations=smooth)
    return ob

def wrinkle(ob, amp=0.012, freq=(2.2, 2.2, 6.0), folds=(), seed=0.0):
    """Cloth: broad soft folds everywhere (running round the body), deeper ones bunched at the listed joints
    [(point, radius, amplitude)]."""
    me = ob.data
    for v in me.vertices:
        p = v.co
        q = V(p.x * freq[0] + seed, p.y * freq[1] - seed, p.z * freq[2])
        d = noise.noise(q) * amp + noise.noise(q * 2.3) * amp * 0.4
        for c, r, a in folds:
            k = math.exp(-((p - c).length / r) ** 2)
            if k > 0.02:
                d += k * a * math.sin((p.z - c.z) * 20.0 + noise.noise(V(p.x * 3, p.y * 3, seed)) * 2.5)
        v.co = p + v.normal * d

def shell(name, rings, closed=True, thick=0.045, sub=1, outward=1.0):
    """An open garment from rings of points (hood, skirt, collar): subdivided, given thickness."""
    bm = skin_rings(rings, closed=closed, cap=False)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.002)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = to_object(name, bm)
    bm.free()
    if sub:
        modify(ob, "SUBSURF", levels=sub, render_levels=sub)
    modify(ob, "SOLIDIFY", thickness=thick, offset=outward)
    return ob

def patch(name, fn, u0, u1, v0, v1, nu=10, nv=6, thick=0.04, sub=1, bevel=0.012):
    """A plate or strap lying on a surface: fn(u, v) -> point; a grid, thickened, with soft edges."""
    rings = [[fn(u0 + (u1 - u0) * i / nu, v0 + (v1 - v0) * j / nv) for i in range(nu + 1)] for j in range(nv + 1)]
    bm = skin_rings(rings, closed=False, cap=False)
    ob = to_object(name, bm)
    bm.free()
    modify(ob, "SOLIDIFY", thickness=thick, offset=1.0)
    if bevel:
        modify(ob, "BEVEL", width=bevel, segments=2, limit_method="ANGLE", angle_limit=math.radians(50))
    return ob

# ---------------------------------------------------------------- weights
def seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(1e-9, ab.length_squared)))
    return (p - (a + ab * t)).length

class Weigher:
    S = 3.0  # sharpness of the blend between neighbouring bones

    def __init__(s, sk):
        s.sk, s.seg = sk, sk.segments()

    def torso(s, p):
        sk, rz = s.sk, 0.3
        hw, hd, cy = sk.torso(min(sk.z_neck, max(sk.z_hip - 0.2, p.z)))
        q2 = (p.x / hw) ** 2 + ((p.y - cy) / hd) ** 2
        q2 = max(q2, 0.6)
        d = {
            "LowerTorso": q2 + (max(0, p.z - sk.z_waist) / rz) ** 2,
            "UpperTorso": q2 + (max(0, sk.z_waist - p.z) / rz) ** 2 + (max(0, p.z - sk.z_neck) / 0.22) ** 2,
            "Head": 1.0 + (max(0, sk.z_neck + 0.12 - p.z) / 0.2) ** 2,
        }
        w = {k: math.exp(-s.S * v) for k, v in d.items()}
        for side, sg in SIDES:
            a, b, r = s.seg[side + "UpperArm"]
            near = math.exp(-((p - a).length / (2.0 * r)) ** 2)
            w[side + "UpperArm"] = math.exp(-s.S * (seg_dist(p, a, b) / r) ** 2) * near
            a, b, r = s.seg[side + "UpperLeg"]
            near = math.exp(-((p - a).length / (2.0 * r)) ** 2)
            w[side + "UpperLeg"] = math.exp(-s.S * (seg_dist(p, a, b) / r) ** 2) * near
        return w

    def chain(s, p, names, root=None):
        w = {}
        for nme in names:
            a, b, r = s.seg[nme]
            w[nme] = math.exp(-s.S * (seg_dist(p, a, b) / r) ** 2)
        if root:
            nme, a, b, r = root
            w[nme] = math.exp(-s.S * (seg_dist(p, a, b) / r) ** 2)
        return w

    def of(s, chain, p):
        sk = s.sk
        kind = chain[0]
        if kind == "bone":
            return {chain[1]: 1.0}
        if kind == "torso":
            return s.torso(p)
        if kind == "arm":
            sg = chain[1]
            side = "Left" if sg < 0 else "Right"
            a = sk.sh[sg]
            return s.chain(p, [side + "UpperArm", side + "LowerArm", side + "Hand"], ("UpperTorso", a, a + V(-sg * 0.6, 0, -0.05), sk.ar))
        if kind == "leg":
            sg = chain[1]
            side = "Left" if sg < 0 else "Right"
            a = sk.hp[sg]
            return s.chain(p, [side + "UpperLeg", side + "LowerLeg", side + "Foot"], ("LowerTorso", a + V(0, 0, 0.12), a + V(0, 0, 0.6), sk.lr))
        if kind == "head":   # hoods and collars: the head, easing into the shoulders
            t = smoothstep(sk.z_neck - 0.12, sk.z_neck + 0.28, p.z)
            return {"Head": t, "UpperTorso": 1 - t}
        if kind == "skirt":  # a coat's skirt: hangs from the hips, each side swings part of the way with its leg
            top, length = chain[1], chain[2]
            t = min(1.0, max(0.0, (top - p.z) / length))
            side = max(-1.0, min(1.0, p.x / (sk.hw * 0.45)))
            k = 0.9 * t ** 0.7
            return {"LowerTorso": 1 - k, "LeftUpperLeg": k * (0.5 - 0.5 * side), "RightUpperLeg": k * (0.5 + 0.5 * side)}
        if kind == "cape":   # hangs from the shoulders down the back; below the waist it sways like a skirt
            zw = sk.z_waist
            if p.z >= zw:
                t = smoothstep(zw, zw + 0.4, p.z)
                return {"UpperTorso": t, "LowerTorso": 1 - t}
            return s.of(("skirt", zw, chain[1]), p)
        raise ValueError(kind)

    def apply(s, ob, sources, smooth=2):
        """sources: [(BVHTree or None, chain)]: each vertex takes the chain of the source surface nearest to it."""
        me = ob.data
        W = []
        for v in me.vertices:
            if len(sources) == 1:
                ch = sources[0][1]
            else:
                best, ch = 1e9, None
                for tree, c in sources:
                    hit = tree.find_nearest(v.co)
                    if hit[0] is not None and hit[3] < best:
                        best, ch = hit[3], c
            W.append(s.of(ch, v.co))
        if smooth and not all(c[0] == "bone" for _, c in sources):
            nb = [[] for _ in me.vertices]
            for e in me.edges:
                a, b = e.vertices
                nb[a].append(b)
                nb[b].append(a)
            for _ in range(smooth):
                out = []
                for i, w in enumerate(W):
                    acc = {k: v * 0.5 for k, v in w.items()}
                    if nb[i]:
                        f = 0.5 / len(nb[i])
                        for j in nb[i]:
                            for k, v in W[j].items():
                                acc[k] = acc.get(k, 0.0) + v * f
                    else:
                        acc = dict(w)
                    out.append(acc)
                W = out
        groups = {}
        for i, w in enumerate(W):
            top = sorted(w.items(), key=lambda kv: -kv[1])[:4]
            top = [(k, v) for k, v in top if v > 0.02 * top[0][1]]
            tot = sum(v for _, v in top)
            for k, v in top:
                if k not in groups:
                    groups[k] = ob.vertex_groups.new(name=k)
                groups[k].add([i], v / tot, "REPLACE")

def tree_of(bm):
    c = bm.copy()
    bmesh.ops.triangulate(c, faces=c.faces)
    t = BVHTree.FromBMesh(c)
    c.free()
    return t

# Tints are the final colour (sRGB). The neutral textures have these mean brightnesses (linear), so the multiplier
# that gives the wanted colour is colour / base; Assets.Surfaces[name].Base carries the same numbers for the game.
BASE = {"Techcloth": 0.42, "Twill": 0.36, "PlateSteel": 0.40, "Gauze": 0.45}
def lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
def still_tint(material_name, tint):
    base = BASE.get(material_name)
    return [lin(c) / base for c in tint] if base else [lin(c) for c in tint]

# ---------------------------------------------------------------- a figure = pieces on a skeleton
class Figure:
    def __init__(s, name, build, over=None):
        s.name = name
        reset()
        s.sk = Skeleton(build, over)
        s.w = Weigher(s.sk)
        s.pieces = {}     # "<Piece>_<Material>" -> [objects]
        s.tints = {}      # piece name -> (r, g, b) multiplied over the texture (the game does the same)
        s.glow = {}       # piece name -> emission colour for the stills
        s.detail = 1.0    # triangle budget multiplier (enemies are seen from further away, and in numbers)
        s.S = s.sk.height / 5.94   # size against the Conduit, for kit given in studs

    def add(s, piece, material_name, ob, sources, smooth=2, tint=None, sharp=None, glow=None, tile=None):
        s.w.apply(ob, sources, smooth)
        smooth_shade(ob, sharp)
        key = f"{piece}_{material_name}"
        ob.name = key
        uv_box(ob, tile or TILE.get(material_name, 2.0))
        s.pieces.setdefault(key, []).append(ob)
        if tint:
            assert s.tints.get(key, tint) == tint, f"{key}: one piece takes one tint; give the differently coloured part its own piece name"
            s.tints[key] = tint
        if glow:
            s.glow[key] = glow
        return ob

    def blob(s, piece, material_name, solids, voxel=0.03, smooth=5, tris=3000, wr=None, cut=None, tint=None, weight_smooth=3):
        """solids: [(bmesh, chain)] fused into one continuous garment."""
        sources = [(tree_of(b), c) for b, c in solids]
        ob = fuse(piece, [b for b, _ in solids], voxel, smooth, cut=cut)
        for b, _ in solids:
            b.free()
        if wr:
            wrinkle(ob, **wr)
        decimate(ob, int(tris * s.detail))
        return s.add(piece, material_name, ob, sources, weight_smooth, tint)

    # ---- solids of the body, inflated by `g` (a garment's thickness over the body)
    def torso_solid(s, z0, z1, g=0.0, n=2.5, step=0.07, dome=(0.5, 0.5)):
        st, z = [], z0
        while z < z1 + 1e-6:
            hw, hd, cy = s.sk.torso(z)
            st.append((V(0, cy, z), hw + g, hd + g))
            z += step
        return tube(st, n=n, seg=40, dome=dome)

    def arm_solid(s, sg, z0, z1, g=0.0, step=0.08, dome=(0.8, 0.4), flare=0.0):
        """From height z0 down to z1."""
        st, z = [], z0
        while z > z1 - 1e-6:
            c, r = s.sk.arm(sg, z)
            f = flare * smoothstep(z1 + 0.25, z1, z)
            st.append((c, r + g + f, (r + g + f) * 0.96))
            z -= step
        return tube(st, n=2.0, seg=22, dome=dome)

    def leg_solid(s, sg, z0, z1, g=0.0, step=0.09, dome=(0.5, 0.3), flare=0.0):
        st, z = [], z0
        while z > z1 - 1e-6:
            c, r, back = s.sk.leg(sg, z)
            f = flare * smoothstep(z1 + 0.3, z1, z)
            st.append((c + V(0, back, 0), r + g + f, (r + g + f) * 1.04 + back * 0.5))
            z -= step
        return tube(st, n=2.1, seg=24, dome=dome)

    def shoulder_solids(s, g=0.0):
        """The slope from the neck out over each shoulder joint, so chest and arm are one surface."""
        sk, out = s.sk, []
        for side, sg in SIDES:
            sh = sk.sh[sg]
            a = V(sg * sk.hw * 0.3, 0.03, sh.z + 0.02)
            b = V(sh.x - sg * sk.ar * 0.1, 0.0, sh.z - sk.ar * 0.95)
            st = [(a.lerp(b, t), (0.5 + 0.55 * t) * sk.ar + g, (0.72 + 0.1 * t) * sk.hd + g) for t in (0, 0.33, 0.66, 1.0)]
            out.append((tube(st, n=2.0, seg=18, u=Z, v=Y, dome=(0.3, 0.9)), ("torso",)))
        return out

    def hand_solids(s, sg, g=0.0):
        sk = s.sk
        wr, hs = sk.wr[sg], sk.hs
        zs = (wr.z - sk.tip[sg].z) / 0.42
        P = lambda x, y, z: wr + V(-sg * x * hs, y * hs, z * zs)   # +x = toward the body
        out = [tube([(P(0, 0, 0.03), 0.105 * hs + g, 0.125 * hs + g), (P(0, -0.01, -0.11), 0.095 * hs + g, 0.165 * hs + g),
                     (P(0.01, -0.01, -0.22), 0.08 * hs + g, 0.165 * hs + g)], n=3.0, seg=16, dome=(0.2, 0.5))]
        for y, ln in ((-0.125, 0.17), (-0.045, 0.2), (0.035, 0.19), (0.11, 0.155)):
            r = 0.043 * hs + g
            out.append(tube([(P(0.01, y, -0.18), r, r), (P(0.03, y, -0.2 - ln * 0.55), r * 0.95, r * 0.95),
                             (P(0.085, y, -0.2 - ln * 0.95), r * 0.82, r * 0.82)], seg=10, dome=(0.3, 1.0)))
        r = 0.05 * hs + g
        out.append(tube([(P(0.02, -0.12, -0.04), r, r), (P(0.05, -0.215, -0.14), r * 0.92, r * 0.92), (P(0.08, -0.235, -0.235), r * 0.8, r * 0.8)], seg=10, dome=(0.3, 1.0)))
        return out

    def boot_solids(s, sg, shaft=0.5, g=0.0):
        """The boot's upper: the foot from heel to toe and a shaft up the calf."""
        sk = s.sk
        lo, hi = sk.foot[sg]
        cx, top = sk.kn[sg].x, sk.az
        fw = (hi.x - lo.x) / 2 + g
        heel, toe, st = hi.y, lo.y, 0.07
        ank_y = sk.kn[sg].y
        def sec(y, wk, h):
            return (V(cx, y, st + h / 2 - 0.02), fw * wk, h / 2 + g)
        foot = tube([sec(heel - 0.05, 0.72, top * 0.8), sec(ank_y + 0.12, 0.9, top * 1.02), sec(ank_y - 0.22, 1.0, top * 0.88),
                     sec(toe + 0.3, 1.0, top * 0.66), sec(toe + 0.08, 0.86, top * 0.5)], n=2.6, seg=22, u=X, v=Z, dome=(0.5, 0.8))
        stt, z = [], top + shaft
        while z > top * 0.55:
            c, r, back = sk.leg(sg, max(z, top))
            stt.append((V(cx, c.y + back + 0.01, z), r + 0.03 + g, (r + 0.03 + g) * 1.05))
            z -= 0.1
        return [foot, tube(stt, n=2.1, seg=22, dome=(0.15, 0.3))]

    def sole(s, sg, thick=0.08):
        sk = s.sk
        lo, hi = sk.foot[sg]
        cx = sk.kn[sg].x
        fw = (hi.x - lo.x) / 2 * 1.07
        c = V(cx, (lo.y + hi.y) / 2, 0)
        half = (hi.y - lo.y) / 2 * 1.0
        bm = skin_rings([ring(c + Z * z, fw * k, half * k2, 3.0, 28) for z, k, k2 in ((0, 0.97, 0.985), (0.02, 1.0, 1.0), (thick, 1.0, 1.0), (thick + 0.02, 0.95, 0.97))])
        # the toe is narrower than the ball of the foot, the heel narrower still
        for v in bm.verts:
            t = (v.co.y - lo.y) / (hi.y - lo.y)
            k = keyed([(0.0, 0.8), (0.3, 1.0), (0.6, 0.92), (1.0, 0.78)], t)[0]
            v.co.x = cx + (v.co.x - cx) * k
        return bm

    # ---- surfaces to lay plates and straps on
    def on_torso(s, off):
        return lambda deg, z: s.sk.torso_point(z, deg, off)[0]

    def on_arm(s, sg, off):
        def fn(deg, z):
            c, r = s.sk.arm(sg, z)
            a = math.radians(deg)
            return c + V(math.cos(a), math.sin(a) * 0.96, 0) * (r + off)
        return fn

    def on_leg(s, sg, off):
        def fn(deg, z):
            c, r, back = s.sk.leg(sg, z)
            a = math.radians(deg)
            return c + V(0, back, 0) + V(math.cos(a), math.sin(a) * 1.04, 0) * (r + off)
        return fn

    # ---------------------------------------------------------- garments
    def trousers(s, mat="Twill", tint=None, g=0.035, tris=2800):
        sk = s.sk
        solids = [(s.torso_solid(sk.z_hip - 0.24, sk.z_waist + 0.1, g, dome=(0.6, 0.2)), ("torso",))]
        folds = []
        for side, sg in SIDES:
            solids.append((s.leg_solid(sg, sk.hp[sg].z + 0.1, sk.az + 0.22, g), ("leg", sg)))
            folds += [(sk.kn[sg] + V(0, 0.12, 0.0), 0.3, 0.014), (V(sk.kn[sg].x, 0, sk.az + 0.5), 0.25, 0.016), (sk.hp[sg] + V(0, -0.2, -0.1), 0.3, 0.01)]
        return s.blob("Trousers", mat, solids, voxel=0.032, tris=tris, wr=dict(amp=0.014, freq=(5.0, 5.0, 1.8), folds=folds, seed=1.7), tint=tint)

    def boots(s, mat="HideLeather", tint=None, shaft=0.5, tris=1900, g=0.0):
        solids = []
        for side, sg in SIDES:
            solids += [(b, ("leg", sg)) for b in s.boot_solids(sg, shaft, g)]
        ob = s.blob("Boots", mat, solids, voxel=0.028, smooth=4, tris=tris, wr=dict(amp=0.005, freq=(4, 4, 9)), tint=tint)
        for side, sg in SIDES:
            so = to_object("Sole", s.sole(sg))
            s.add("Soles", "Polymer", so, [(None, ("bone", side + "Foot"))], sharp=40)
        return ob

    def jacket(s, mat="Techcloth", tint=None, g=0.038, bottom=None, sleeve="elbow", tris=4000, collar=0.0, piece="Coat", cap=0.8):
        """Torso and sleeves as one garment. sleeve: "elbow" stops just past the elbow, "wrist" runs to the cuff,
        "cap" stops at mid upper arm."""
        sk = s.sk
        bottom = sk.z_hip + 0.12 if bottom is None else bottom
        solids = [(s.torso_solid(bottom, sk.z_neck + (0.05 if collar <= 0 else collar), g, dome=(0.2, 0.25)), ("torso",))]
        solids += s.shoulder_solids(g)
        folds = []
        for side, sg in SIDES:
            end = {"elbow": sk.el[sg].z - 0.16, "wrist": sk.wr[sg].z + 0.05, "cap": (sk.sh[sg].z + sk.el[sg].z) / 2}[sleeve]
            solids.append((s.arm_solid(sg, sk.sh[sg].z - 0.02, end, g, flare=0.025, dome=(cap, 0.4)), ("arm", sg)))
            folds += [(sk.el[sg] + V(0, 0.05, 0.05), 0.26, 0.015), (sk.sh[sg] + V(-sg * 0.3, 0, -0.35), 0.3, 0.014)]
        return s.blob(piece, mat, solids, voxel=0.032, tris=tris, wr=dict(amp=0.016, freq=(4.5, 4.5, 1.6), folds=folds, seed=0.4), tint=tint)

    def skirt(s, mat="Techcloth", tint=None, length=1.0, flare=0.16, split=3.0, g=0.07, piece="Coat", back_longer=0.15):
        """The coat's skirt: an open shell from the waist, split down the front."""
        sk = s.sk
        top = sk.z_hip + 0.2
        rings, n = [], 6
        a0, a1 = math.radians(-90 + split), math.radians(270 - split)
        for i in range(n + 1):
            t = i / n
            pts = []
            for j in range(41):
                a = a0 + (a1 - a0) * j / 40
                deg = math.degrees(a)
                back = 0.5 + 0.5 * math.sin(a)                              # 0 at the front, 1 at the back
                z = top - t * (length + back_longer * back)
                hw, hd, cy = sk.torso(max(z, sk.z_hip + 0.08))
                f = g + flare * t * t + 0.02 * math.sin(j * 1.9 + i) * t      # the hem waves a little
                e = 2.0 / 2.4
                ca, sa = math.cos(a), math.sin(a)
                pts.append(V(math.copysign(abs(ca) ** e, ca) * (hw + f), cy + math.copysign(abs(sa) ** e, sa) * (hd + f * 1.1), z))
            rings.append(pts)
        ob = shell("Skirt", rings, closed=False, thick=0.04, sub=1)
        decimate(ob, 1500)
        return s.add(piece, mat, ob, [(None, ("skirt", top, length))], tint=tint)

    def collar(s, mat="Techcloth", tint=None, height=0.3, open_deg=28.0, g=0.07, piece="Coat"):
        sk = s.sk
        rings = []
        a0, a1 = math.radians(-90 + open_deg), math.radians(270 - open_deg)
        for t in (0, 0.5, 1.0):
            z = sk.z_neck - 0.06 + height * t
            hw, hd, cy = sk.torso(sk.z_neck + 0.02)
            k = 1.0 + 0.12 * t
            rings.append(ring(V(0, cy + 0.02, z), (hw * 0.82 + g) * k, (hd * 0.9 + g) * k, 2.0, 28, a0=a0, a1=a1, closed=False))
        ob = shell("Collar", rings, closed=False, thick=0.04, sub=1)
        decimate(ob, 400)
        return s.add(piece, mat, ob, [(None, ("head",))], tint=tint)

    def forearms(s, mat="Twill", tint=None, g=0.03, tris=1300, wraps=False, split=False):
        if split:   # one piece a side ("LowerArmL", "LowerArmR"), so a limb can be swapped for a cybernetic one
            for side, sg in SIDES:
                sk = s.sk
                solid = [(s.arm_solid(sg, sk.el[sg].z + 0.14, sk.wr[sg].z - 0.02, g, dome=(0.3, 0.2)), ("arm", sg))]
                s.blob("LowerArm" + side[0], mat, solid, voxel=0.026, smooth=4, tris=tris // 2,
                       wr=dict(amp=0.009, folds=[(sk.el[sg] + V(0, 0, -0.2), 0.3, 0.012)], seed=2.2), tint=tint)
            return None
        sk = s.sk
        solids, folds = [], []
        for side, sg in SIDES:
            solids.append((s.arm_solid(sg, sk.el[sg].z + 0.14, sk.wr[sg].z - 0.02, g, dome=(0.3, 0.2)), ("arm", sg)))
            folds.append((sk.el[sg] + V(0, 0, -0.2), 0.3, 0.012))
        wr = dict(amp=0.004, freq=(1, 1, 30), folds=[], seed=2.0) if wraps else dict(amp=0.009, folds=folds, seed=2.2)
        ob = s.blob("LowerArms", mat, solids, voxel=0.026, smooth=4, tris=tris, wr=wr, tint=tint)
        return ob

    def gloves(s, mat="HideLeather", tint=None, g=0.012, cuff=0.2, tris=2000, piece="Hands", split=False):
        sk = s.sk
        if split:   # "GloveL", "GloveR"
            for side, sg in SIDES:
                solids = [(b, ("arm", sg)) for b in s.hand_solids(sg, g)]
                st = []
                for z in (sk.wr[sg].z - 0.03, sk.wr[sg].z + cuff * 0.5, sk.wr[sg].z + cuff):
                    c, r = sk.arm(sg, z)
                    st.append((c, r + 0.05, (r + 0.05) * 0.96))
                solids.append((tube(st, seg=18, dome=(0.2, 0.15)), ("arm", sg)))
                s.blob("Glove" + side[0], mat, solids, voxel=0.014, smooth=3, tris=tris // 2, tint=tint, weight_smooth=1)
            return None
        solids = []
        for side, sg in SIDES:
            solids += [(b, ("arm", sg)) for b in s.hand_solids(sg, g)]
            if cuff > 0:
                st = []
                for z in (sk.wr[sg].z - 0.03, sk.wr[sg].z + cuff * 0.5, sk.wr[sg].z + cuff):
                    c, r = sk.arm(sg, z)
                    st.append((c, r + 0.05, (r + 0.05) * 0.96))
                solids.append((tube(st, seg=18, dome=(0.2, 0.15)), ("arm", sg)))
        return s.blob(piece, mat, solids, voxel=0.014, smooth=3, tris=tris, tint=tint, weight_smooth=1)

    def head_core(s, mat="Twill", tint=(0.13, 0.13, 0.14), jaw=True):
        """The head under the hood or helmet: a balaclava'd skull with a jaw and a neck."""
        sk = s.sk
        hr, zc = sk.hr, sk.zc
        solids = [(ball_bm(hr, (0, 0.03, zc), (0.92, 1.05, 1.1)), ("bone", "Head"))]
        if jaw:
            solids.append((ball_bm(hr * 0.7, (0, -hr * 0.22, zc - hr * 0.62), (0.9, 1.0, 0.95)), ("bone", "Head")))
        nr = hr * 0.52
        solids.append((tube([(V(0, 0.03, sk.z_neck - 0.12), nr * 1.2, nr * 1.2), (V(0, 0.03, zc - hr * 0.5), nr, nr)], seg=16, dome=(0.2, 0.2)), ("head",)))
        return s.blob("Head", mat, solids, voxel=0.03, smooth=4, tris=900, tint=tint)

    def hood(s, mat="Techcloth", tint=None, piece="Hood", drape=1.0, peak=1.0, open_face=1.0):
        """A hood with a face opening, draped onto the shoulders."""
        sk = s.sk
        k, zn = sk.hr / 0.48, sk.z_neck
        dz = sk.zc - 0.59 * k - zn                                        # lift the hood with the skull
        keys = [  # height above the neck, rx, ry, cy, half-opening (degrees)
            (-0.10, 0.70 * drape, 0.58 * drape, 0.06, 30), (0.08, 0.52, 0.50, 0.07, 40), (0.30, 0.56, 0.58, 0.07, 58 * open_face),
            (0.60, 0.61, 0.66, 0.06, 66 * open_face), (0.90, 0.60, 0.66, 0.03, 56 * open_face), (1.10, 0.53, 0.60, -0.02 * peak, 30 * open_face),
            (1.22, 0.40, 0.46, -0.03 * peak, 0), (1.30, 0.2, 0.24, 0.0, 0), (1.325, 0.03, 0.03, 0.02, 0)]
        rings = []
        for h, rx, ry, cy, op in keys:
            a0, a1 = math.radians(-90 + op), math.radians(270 - op)
            z = zn + (h * k + dz if h > 0.08 else h)
            rings.append(ring(V(0, cy * k, z), rx * k, ry * k, 2.0, 36, a0=a0, a1=a1, closed=False))
        ob = shell("Hood", rings, closed=False, thick=0.05, sub=1)
        wrinkle(ob, amp=0.012, freq=(3, 3, 4), seed=3.1)
        decimate(ob, 1900)
        return s.add(piece, mat, ob, [(None, ("head",))], tint=tint)

    def helmet(s, mat="PlateSteel", tint=None, piece="Helmet", brim=0.0, cover=0.25, grow=1.16):
        """A hard shell over the skull, down to `cover` (share of the skull radius) below its centre."""
        sk = s.sk
        hr, zc = sk.hr * grow, sk.zc
        bm = ball_bm(hr, (0, 0.03, zc), (0.95, 1.07, 1.08), seg=28, rings=16, cut_below=-hr * cover)
        if brim > 0:
            b2 = skin_rings([ring(V(0, 0.03, zc - hr * cover * 1.08 + dz), hr * 0.95 * k, hr * 1.07 * k, 2.0, 28) for dz, k in ((0.0, 1.0), (0.0, 1.0 + brim), (0.05, 1.0 + brim), (0.07, 1.0))])
            me = bpy.data.meshes.new("t")
            b2.to_mesh(me)
            bm.from_mesh(me)
        ob = to_object("Helmet", bm)
        return s.add(piece, mat, ob, [(None, ("bone", "Head"))], tint=tint, sharp=50)

    def visor(s, mat="ConduitVisor", piece="Visor", half=62.0, height=0.15, drop=0.08, glow=(0.0, 0.85, 1.0), r=1.1, tint=None):
        """A band across the eyes, bent round the face."""
        sk = s.sk
        hr, zc = sk.hr, sk.zc
        def fn(deg, z):
            a = math.radians(deg)
            return V(math.cos(a) * hr * 0.94 * r, 0.03 + math.sin(a) * hr * 1.06 * r, z)
        ob = patch("Visor", fn, -90 - half, -90 + half, zc + drop - height / 2, zc + drop + height / 2, nu=16, nv=2, thick=0.035, bevel=0.01)
        return s.add(piece, mat, ob, [(None, ("bone", "Head"))], sharp=50, glow=glow, tint=tint)

    def respirator(s, mat="Polymer", piece="Mask", cans=True, fittings="Fittings"):
        """A half mask over nose and mouth with a filter canister on each cheek."""
        sk = s.sk
        hr, zc = sk.hr, sk.zc
        k = hr / 0.48
        z = zc - 0.27 * k
        snout = tube([(V(0, -hr * 0.62, z + 0.03), 0.30 * k, 0.25 * k), (V(0, -hr * 0.98, z), 0.25 * k, 0.2 * k), (V(0, -hr * 1.22, z - 0.02), 0.16 * k, 0.13 * k)],
                     n=2.6, seg=20, u=X, v=Z, dome=(0.0, 0.35))
        ob = to_object("Mask", snout)
        modify(ob, "SUBSURF", levels=1, render_levels=1)
        s.add(piece, mat, ob, [(None, ("bone", "Head"))], sharp=60)
        if cans:
            for sg in (-1, 1):
                c = V(sg * 0.27 * k, -hr * 0.9, z - 0.03)
                d = V(sg * 0.9, -0.35, -0.1).normalized()
                u = d.cross(Z).normalized()
                v = d.cross(u)
                can = skin_rings([ring(c + d * t, 0.105 * k * q, 0.105 * k * q, 2.0, 16, u, v) for t, q in ((0, 0.9), (0.02, 1.0), (0.13 * k, 1.0), (0.15 * k, 0.9))])
                s.add(piece, mat, to_object("Can", can), [(None, ("bone", "Head"))], sharp=40)
                cap = skin_rings([ring(c + d * (0.15 * k + t), 0.08 * k, 0.08 * k, 2.0, 14, u, v) for t in (0, 0.03 * k)])
                s.add(fittings, "Stainless", to_object("Cap", cap), [(None, ("bone", "Head"))], sharp=40)
        return ob

    def goggles(s, mat="Goggle", glow=(1.0, 0.45, 0.15), piece="Goggles", strap="HideLeather", z=0.08, strap_piece="Straps"):
        sk = s.sk
        hr, zc = sk.hr, sk.zc
        k = hr / 0.48
        for sg in (-1, 1):
            c = V(sg * 0.2 * k, -hr * 1.0, zc + z * k)
            d = V(sg * 0.25, -1, 0).normalized()
            u = d.cross(Z).normalized()
            rim = skin_rings([ring(c + d * t, 0.16 * k * q, 0.14 * k * q, 2.4, 18, u, Z) for t, q in ((-0.06, 1.0), (0.07 * k, 1.0), (0.09 * k, 0.86))])
            s.add("GoggleRims", "Polymer", to_object("Rim", rim), [(None, ("bone", "Head"))], sharp=40)
            lens = skin_rings([ring(c + d * (0.085 * k + t), 0.125 * k, 0.105 * k, 2.4, 18, u, Z) for t in (0, 0.02)])
            s.add(piece, mat, to_object("Lens", lens), [(None, ("bone", "Head"))], sharp=40, glow=glow)
        def fn(deg, z):
            a = math.radians(deg)
            return V(math.cos(a) * hr * 0.96, 0.03 + math.sin(a) * hr * 1.09, z)
        band = patch("Strap", fn, -60, 240, zc + (z - 0.05) * k, zc + (z + 0.05) * k, nu=24, nv=1, thick=0.025, bevel=0.0)
        s.add(strap_piece, strap, band, [(None, ("bone", "Head"))], sharp=50)

    def face_wrap(s, mat="Gauze", tint=None, piece="Wrap"):
        """Cloth wound over nose, mouth and neck."""
        sk = s.sk
        hr, zc = sk.hr, sk.zc
        st = [(V(0, 0.0, sk.z_neck - 0.05), hr * 0.78, hr * 0.74), (V(0, -0.02, zc - hr * 0.75), hr * 0.80, hr * 0.92), (V(0, -0.03, zc - hr * 0.1), hr * 0.97, hr * 1.12)]
        ob = fuse("Wrap", [tube(st, seg=24, dome=(0.2, 0.25))], voxel=0.03, smooth=3)
        wrinkle(ob, amp=0.012, freq=(1.5, 1.5, 22), seed=5.0)
        decimate(ob, 700)
        return s.add(piece, mat, ob, [(None, ("head",))], tint=tint)

    def belt(s, mat="HideLeather", z=None, height=0.17, off=0.075, buckle="Stainless", piece="Straps", tint=None):
        sk = s.sk
        z = sk.z_hip + 0.42 if z is None else z
        ob = patch("Belt", s.on_torso(off), -90, 270, z, z + height, nu=40, nv=1, thick=0.035, bevel=0.008)
        s.add(piece, mat, ob, [(None, ("torso",))], tint=tint, sharp=50)
        if buckle:
            p, nrm = sk.torso_point(z + height / 2, -90, off + 0.04)
            s.add("Fittings", buckle, to_object("Buckle", box_bm((0.26, 0.05, height * 1.05), p, 0.015)), [(None, ("bone", "LowerTorso"))], sharp=40)

    def strap(s, mat, z0, deg0, z1, deg1, width=0.15, off=0.07, piece="Straps", steps=14, tint=None, thick=0.03):
        """A strap across the torso from (z0, deg0) to (z1, deg1)."""
        sk = s.sk
        def fn(u, v):
            z = z0 + (z1 - z0) * u
            return sk.torso_point(z + v * width * 0.8, deg0 + (deg1 - deg0) * u + v * width * 12, off)[0]
        ob = patch("Strap", fn, 0, 1, -0.5, 0.5, nu=steps, nv=1, thick=thick, bevel=0.006)
        return s.add(piece, mat, ob, [(None, ("torso",))], tint=tint, sharp=50)

    def cape(s, mat="Techcloth", tint=None, length=3.0, half=62.0, off=0.14, piece="Cape"):
        """A cape down the back from the shoulders."""
        sk = s.sk
        top = sk.sh[1].z + 0.02
        def fn(deg, t):
            z = top - t * length
            flare = 0.25 * t * t
            p, nrm = sk.torso_point(max(z, sk.z_hip + 0.08), 90 + (deg - 90) * (1 + 0.25 * t), off + flare)
            return V(p.x, p.y, z)
        ob = patch("Cape", fn, 90 - half, 90 + half, 0.0, 1.0, nu=14, nv=10, thick=0.04, bevel=0.0)
        wrinkle(ob, amp=0.03, freq=(3.0, 3.0, 0.8), seed=7.0)
        return s.add(piece, mat, ob, [(None, ("cape", length - (top - sk.z_waist)))], tint=tint)

    def pouch(s, mat, z, deg, size=(0.26, 0.12, 0.3), off=0.06, bone="UpperTorso", piece="Pouches", tint=None):
        p, nrm = s.sk.torso_point(z, deg, off + size[1] / 2)
        rot = Matrix.Rotation(math.atan2(nrm.y, nrm.x) + math.pi / 2, 4, "Z")
        ob = to_object("Pouch", box_bm(size, p, 0.035, rot))
        s.add(piece, mat, ob, [(None, ("bone", bone))], tint=tint, sharp=45)
        lid = to_object("Lid", box_bm((size[0] * 1.06, size[1] * 1.15, size[2] * 0.42), p + V(0, 0, size[2] * 0.33), 0.03, rot))
        return s.add(piece, mat, lid, [(None, ("bone", bone))], tint=tint, sharp=45)

    def torso_plate(s, mat="PlateSteel", z0=None, z1=None, half=38.0, front=True, off=0.075, thick=0.06, piece="Plates", tint=None, nv=6):
        sk = s.sk
        z0 = sk.z_neck - 0.85 if z0 is None else z0
        z1 = sk.z_neck - 0.22 if z1 is None else z1
        mid = -90 if front else 90
        def fn(deg, z):
            taper = 1.0 - 0.25 * smoothstep(z1, z0, z)      # narrower toward the bottom
            return sk.torso_point(z, mid + (deg - mid) * taper, off)[0]
        ob = patch("Plate", fn, mid - half, mid + half, z0, z1, nu=12, nv=nv, thick=thick, bevel=0.018)
        return s.add(piece, mat, ob, [(None, ("bone", "UpperTorso"))], tint=tint, sharp=45)

    def pauldron(s, sg, mat="PlateSteel", piece="Plates", scale=1.0, tint=None, layers=1):
        sk = s.sk
        side = "Left" if sg < 0 else "Right"
        sh, ar = sk.sh[sg], sk.ar
        for i in range(layers):
            r = ar * (1.34 - 0.06 * i) * scale
            c = V(sh.x + sg * (0.03 + 0.04 * i), 0, sh.z - ar * (0.55 + 0.52 * i))
            bm = ball_bm(r, c, (1.0, 1.02, 0.62), seg=22, rings=12, cut_below=-r * 0.12)
            inner = ball_bm(r - 0.05, c + V(0, 0, -0.02), (1.0, 1.02, 0.62), seg=22, rings=12, cut_below=-r * 0.2)
            ob = to_object("Pauldron", bm)
            co = to_object("cut", inner)
            m = ob.modifiers.new("b", "BOOLEAN")
            m.operation, m.object, m.solver = "DIFFERENCE", co, "EXACT"
            activate(ob)
            bpy.ops.object.modifier_apply(modifier=m.name)
            bpy.data.objects.remove(co)
            s.add(piece, mat, ob, [(None, ("bone", side + "UpperArm"))], tint=tint, sharp=45)

    def limb_plate(s, kind, sg, mat="PlateSteel", z0=0.0, z1=0.0, mid=-90.0, half=70.0, off=0.05, thick=0.05, piece="Plates", tint=None):
        """A curved plate on an arm or a leg between heights z0 < z1; kind: LowerArm, UpperArm, LowerLeg, UpperLeg."""
        side = "Left" if sg < 0 else "Right"
        fn = s.on_arm(sg, off) if "Arm" in kind else s.on_leg(sg, off)
        ob = patch("Plate", fn, mid - half, mid + half, z0, z1, nu=10, nv=4, thick=thick, bevel=0.014)
        return s.add(piece, mat, ob, [(None, ("bone", side + kind))], tint=tint, sharp=45)

    def knee(s, sg, mat="PlateSteel", piece="Plates", tint=None):
        sk = s.sk
        side = "Left" if sg < 0 else "Right"
        kn, lr = sk.kn[sg], sk.lr
        c = V(kn.x, kn.y - lr * 0.72, kn.z - 0.1)
        ob = to_object("Knee", ball_bm(lr * 0.58, c, (1.0, 0.5, 1.2), seg=18, rings=10))
        return s.add(piece, mat, ob, [(None, ("bone", side + "LowerLeg"))], tint=tint, sharp=50)

    def band(s, kind, sg, z, mat, height=0.09, off=0.055, piece="Trim", glow=None, tint=None, thick=0.02):
        """A ring round a limb (armband, cuff, boot strap)."""
        side = "Left" if sg < 0 else "Right"
        fn = s.on_arm(sg, off) if "Arm" in kind else s.on_leg(sg, off)
        ob = patch("Band", fn, 0, 360, z, z + height, nu=20, nv=1, thick=thick, bevel=0.0)
        return s.add(piece, mat, ob, [(None, ("bone", side + kind))], glow=glow, tint=tint, sharp=50)

    def seam(s, mat, deg, z0, z1, width=0.05, off=0.062, piece="Trim", glow=None, thick=0.015):
        """A thin line down the torso (a lit seam, piping)."""
        sk = s.sk
        def fn(u, z):
            p, nrm = sk.torso_point(z, deg, off)
            tan = V(-nrm.y, nrm.x, 0)
            return p + tan * u
        ob = patch("Seam", fn, -width / 2, width / 2, z0, z1, nu=1, nv=10, thick=thick, bevel=0.0)
        return s.add(piece, mat, ob, [(None, ("torso",))], glow=glow, sharp=50)

    def disc(s, mat, at, normal, r, depth=0.06, bone="UpperTorso", piece="Fittings", glow=None, seg=18):
        d = Vector(normal).normalized()
        u = d.cross(Z).normalized() if abs(d.z) < 0.9 else X
        v = d.cross(u)
        bm = skin_rings([ring(Vector(at) + d * t, r * k, r * k, 2.0, seg, u, v) for t, k in ((-0.02, 1.0), (depth * 0.7, 1.0), (depth, 0.85))])
        return s.add(piece, mat, to_object("Disc", bm), [(None, ("bone", bone))], glow=glow, sharp=40)

    def box(s, piece, mat, size, at, bone, bev=0.03, rot=None, tint=None, glow=None):
        return s.add(piece, mat, to_object(piece, box_bm(size, at, bev, rot)), [(None, ("bone", bone))], tint=tint, glow=glow, sharp=45)

    def cyl(s, piece, mat, a, b, r, bone, seg=14, tint=None, glow=None, r2=None):
        a, b = Vector(a), Vector(b)
        d = (b - a).normalized()
        u = d.cross(Z).normalized() if abs(d.z) < 0.9 else X
        v = d.cross(u)
        r2 = r if r2 is None else r2
        bm = skin_rings([ring(a, r * 0.9, r * 0.9, 2.0, seg, u, v), ring(a + d * 0.02, r, r, 2.0, seg, u, v), ring(b - d * 0.02, r2, r2, 2.0, seg, u, v), ring(b, r2 * 0.9, r2 * 0.9, 2.0, seg, u, v)])
        return s.add(piece, mat, to_object(piece, bm), [(None, ("bone", bone))], tint=tint, glow=glow, sharp=40)

    # ---------------------------------------------------------- finishing: join, rig, export, stills
    # ---- the layered recruit: a bare body cut into regions, clothes and kit over it, limbs that can be swapped
    def body(s, mat="Flesh", tint=None, tris=5600):
        """The bare body: one fused surface (so nothing is disjointed), then cut into Head, Torso, ArmL/R, HandL/R,
        LegL/R, FootL/R. Every piece keeps the fused surface's normals and weights, so the cuts do not show, and
        the game can hide what clothing covers or what a cybernetic limb replaces."""
        sk = s.sk
        hr, zc = sk.hr, sk.zc
        solids = [(s.torso_solid(sk.z_hip - 0.26, sk.z_neck + 0.02, 0.0, dome=(0.6, 0.3)), ("torso",))]
        solids += s.shoulder_solids(0.0)
        for side, sg in SIDES:
            sh, ar = sk.sh[sg], sk.ar
            solids.append((s.arm_solid(sg, sh.z - 0.14, sk.wr[sg].z - 0.03, 0.0, dome=(0.55, 0.3)), ("arm", sg)))
            solids.append((s.trap_solid(sg), ("torso",)))
            solids += [(b, ("arm", sg)) for b in s.hand_solids(sg, 0.0)]
            solids.append((s.leg_solid(sg, sk.hp[sg].z + 0.1, sk.az - 0.02, 0.0), ("leg", sg)))
            solids.append((s.boot_solids(sg, 0.12, -0.018)[0], ("leg", sg)))
        # the head: skull, jaw, neck, a brow, a nose, ears; hollows where the eyes sit
        solids.append((ball_bm(hr, (0, 0.03, zc), (0.9, 1.04, 1.1)), ("bone", "Head")))
        solids.append((ball_bm(hr * 0.7, (0, -hr * 0.24, zc - hr * 0.6), (0.88, 1.0, 0.95)), ("bone", "Head")))
        nr = hr * 0.6
        solids.append((tube([(V(0, 0.03, sk.z_neck - 0.14), nr * 1.3, nr * 1.2), (V(0, 0.03, zc - hr * 0.5), nr, nr)], seg=16, dome=(0.2, 0.2)), ("head",)))
        solids.append((ball_bm(hr * 0.36, (0, -hr * 0.8, zc + hr * 0.2), (1.7, 0.5, 0.34)), ("bone", "Head")))              # brow
        solids.append((tube([(V(0, -hr * 0.98, zc + hr * 0.1), hr * 0.1, hr * 0.12), (V(0, -hr * 1.2, zc - hr * 0.22), hr * 0.15, hr * 0.13),
                             (V(0, -hr * 1.06, zc - hr * 0.3), hr * 0.13, hr * 0.08)], seg=10, u=X, v=Y, dome=(0.5, 0.8)), ("bone", "Head")))  # nose
        for sg in (-1, 1):
            solids.append((ball_bm(hr * 0.3, (sg * hr * 0.9, 0.06, zc - hr * 0.08), (0.35, 0.75, 1.1)), ("bone", "Head")))   # ear
        eyes = [ball_bm(hr * 0.2, (sg * hr * 0.36, -hr * 1.04, zc + hr * 0.02), (1.25, 0.6, 0.7)) for sg in (-1, 1)]
        ob = s.blob("Body", mat, solids, voxel=0.026, smooth=5, tris=tris, cut=eyes, tint=tint, weight_smooth=3)
        key = f"Body_{mat}"
        s.pieces.pop(key)
        s.tints.pop(key, None)
        # cut along the region borders, then hand each face to its region
        xa = sk.sh[1].x - sk.ar * 1.02
        zn, zl, zw_, zf = sk.z_neck - 0.1, sk.z_hip - 0.3, sk.wr[1].z, sk.az + 0.1
        def region(c):
            if abs(c.x) > (xa if c.z > zl else xa + 0.03) and c.z > zl - 0.6:
                side = "L" if c.x < 0 else "R"
                return ("Hand" if c.z < zw_ else "Arm") + side
            if c.z > zn:
                return "Head"
            if c.z > zl:
                return "Torso"
            return ("Foot" if c.z < zf else "Leg") + ("L" if c.x < 0 else "R")
        cuts = [(V(0, 0, zn), Z, lambda c: abs(c.x) < xa), (V(xa, 0, 0), X, lambda c: c.z > zl), (V(-xa, 0, 0), X, lambda c: c.z > zl),
                (V(0, 0, zw_), Z, lambda c: abs(c.x) > xa), (V(0, 0, zl), Z, lambda c: abs(c.x) < xa), (V(0, 0, zf), Z, lambda c: abs(c.x) < xa)]
        return s.cut_regions(ob, mat, cuts, region, tint, "Torso")

    def cut_regions(s, ob, mat, cuts, region, tint, main):
        """Cuts a registered-then-popped garment along planes [(point, normal, which faces)] and hands each face to
        the piece region(centre) names. The pieces keep the whole surface's normals, so the cuts do not show."""
        me = ob.data
        bm = bmesh.new()
        bm.from_mesh(me)
        for co, no, keep in cuts:
            geom = [f for f in bm.faces if keep(f.calc_center_median())]
            geom = list({e for f in geom for e in f.edges} | {v for f in geom for v in f.verts} | set(geom))
            bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-5, plane_co=co, plane_no=no)
        bm.to_mesh(me)
        bm.free()
        me.update()
        me.normals_split_custom_set_from_vertices([v.normal[:] for v in me.vertices])
        names = sorted({region(poly.center) for poly in me.polygons})
        made = []
        for name in names:
            if name == main:
                continue
            activate(ob)
            bpy.ops.object.mode_set(mode="EDIT")
            bpy.ops.mesh.select_mode(type="FACE")
            bpy.ops.mesh.select_all(action="DESELECT")
            bpy.ops.object.mode_set(mode="OBJECT")
            for poly in ob.data.polygons:
                poly.select = region(poly.center) == name
            bpy.ops.object.mode_set(mode="EDIT")
            bpy.ops.mesh.separate(type="SELECTED")
            bpy.ops.object.mode_set(mode="OBJECT")
            new = [o for o in bpy.context.selected_objects if o is not ob][0]
            made.append((name, new))
        made.append((main, ob))
        for name, o in made:
            k = f"{name}_{mat}"
            o.name = k
            s.pieces.setdefault(k, []).append(o)
            if tint:
                s.tints[k] = tint
        return [o for _, o in made]

    def split_legs(s):
        """Cuts the trousers into Trousers (the seat), TrouserL and TrouserR, and the boots and soles into a piece a
        side, so one leg can be swapped for a cybernetic one."""
        sk = s.sk
        zl = sk.z_hip - 0.3
        for key in [k for k in list(s.pieces) if k.split("_")[0] in ("Trousers", "Boots", "Soles")]:
            piece, mat = key.split("_")
            obs = s.pieces.pop(key)
            tint = s.tints.pop(key, None)
            if len(obs) > 1:
                bpy.ops.object.select_all(action="DESELECT")
                for o in obs:
                    o.select_set(True)
                bpy.context.view_layer.objects.active = obs[0]
                bpy.ops.object.join()
            if piece == "Trousers":
                s.cut_regions(obs[0], mat, [(V(0, 0, zl), Z, lambda c: True)], lambda c: "Trousers" if c.z > zl else ("TrouserL" if c.x < 0 else "TrouserR"), tint, "Trousers")
            else:
                one = piece[:-1]
                s.cut_regions(obs[0], mat, [], lambda c: one + ("L" if c.x < 0 else "R"), tint, one + "L")

    def trap_solid(s, sg, g=0.0):
        """The muscle from the neck out to the point of the shoulder, so the arm does not sit on the body like a peg."""
        sk = s.sk
        sh, ar = sk.sh[sg], sk.ar
        a, b = V(sg * sk.hw * 0.22, 0.04, sk.z_neck - 0.02), V(sh.x - sg * ar * 0.25, 0.0, sh.z - ar * 0.45)
        st = [(a.lerp(b, t), (0.42 + 0.5 * t) * ar + g, (0.6 + 0.32 * t) * sk.hd + g) for t in (0, 0.33, 0.66, 1.0)]
        return tube(st, n=2.0, seg=18, u=Z, v=Y, dome=(0.3, 0.9))

    def under(s, mat="Gauze", tint=None):
        """What a clone wears in the tank: a wrap round the hips."""
        sk = s.sk
        solids = [(s.torso_solid(sk.z_hip - 0.27, sk.z_hip + 0.36, 0.014, dome=(0.6, 0.05)), ("torso",))]
        for side, sg in SIDES:
            solids.append((s.leg_solid(sg, sk.hp[sg].z + 0.05, sk.hp[sg].z - 0.42, 0.014, dome=(0.3, 0.05)), ("leg", sg)))
        return s.blob("Under", mat, solids, voxel=0.028, smooth=4, tris=700, tint=tint)

    def singlet(s, mat="Twill", tint=None, g=0.026, tris=1800):
        """A sleeveless undershirt: the torso and the slope of the shoulders, no sleeves."""
        sk = s.sk
        solids = [(s.torso_solid(sk.z_hip + 0.08, sk.z_neck - 0.02, g, dome=(0.2, 0.25)), ("torso",))]
        solids += s.shoulder_solids(g * 0.6)
        solids += [(s.trap_solid(sg, g * 0.8), ("torso",)) for sg in (-1, 1)]
        ob = s.blob("Singlet", mat, solids, voxel=0.03, tris=tris, wr=dict(amp=0.01, freq=(4.5, 4.5, 1.6), seed=0.9), tint=tint)
        # open armholes exactly where the body's arms begin
        xa = sk.sh[1].x - sk.ar * 1.02
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        for sg in (-1, 1):
            geom = list(bm.verts) + list(bm.edges) + list(bm.faces)
            bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-5, plane_co=V(sg * xa, 0, 0), plane_no=V(sg, 0, 0), clear_outer=True)
        bm.to_mesh(ob.data)
        bm.free()
        return ob

    def anchor(s):
        """One hidden speck per bone, so every layer uploaded from this figure carries all 15 bones (an importer
        drops a bone that moves nothing) and can be lined up with the rig."""
        for l in LIMBS:
            c = s.sk.centre[l]
            bm = bmesh.new()
            vs = [bm.verts.new(c + d) for d in (V(0, 0, 0), V(0.01, 0, 0), V(0, 0, 0.01))]
            bm.faces.new(vs)
            s.add("Anchor", "Proxy", to_object("Anchor", bm), [(None, ("bone", l))])

    def cyber_arm(s, sg, tint=(0.22, 0.23, 0.25)):
        """A cybernetic arm in place of the flesh one: ball joints at shoulder, elbow and wrist, struts with a plate
        and a piston between them, a steel hand. Rigid pieces, each on one bone."""
        sk = s.sk
        side = "Left" if sg < 0 else "Right"
        p, j = "CyArm" + side[0], "CyArmJoints" + side[0]
        sh, el, wr, ar = sk.sh[sg], sk.el[sg], sk.wr[sg], sk.ar
        out = 0 if sg > 0 else 180
        s.add(j, "Stainless", to_object("J", ball_bm(ar * 1.05, sh + V(0, 0, -ar * 0.5))), [(None, ("bone", side + "UpperArm"))], sharp=50)
        s.cyl(p, "PlateSteel", sh + V(0, 0, -ar * 0.9), el + V(0, 0, ar * 0.4), ar * 0.62, side + "UpperArm", tint=tint, r2=ar * 0.5)
        s.limb_plate("UpperArm", sg, z0=el.z + 0.28, z1=sh.z - 0.3, mid=out, half=95, off=0.02, thick=0.05, piece=p, tint=tint)
        s.cyl(j, "Stainless", sh + V(-sg * ar * 0.5, ar * 0.5, -ar * 1.2), el + V(-sg * ar * 0.4, ar * 0.45, ar * 0.5), ar * 0.14, side + "UpperArm")
        s.add(j, "Stainless", to_object("J", ball_bm(ar * 0.78, el)), [(None, ("bone", side + "LowerArm"))], sharp=50)
        s.cyl(p, "PlateSteel", el + V(0, 0, -ar * 0.4), wr + V(0, 0, ar * 0.3), ar * 0.6, side + "LowerArm", tint=tint, r2=ar * 0.42)
        s.limb_plate("LowerArm", sg, z0=wr.z + 0.2, z1=el.z - 0.22, mid=out, half=110, off=0.0, thick=0.05, piece=p, tint=tint)
        s.cyl(j, "Stainless", el + V(0, -ar * 0.5, -ar * 0.7), wr + V(0, -ar * 0.38, ar * 0.5), ar * 0.12, side + "LowerArm")
        s.add(j, "Stainless", to_object("J", ball_bm(ar * 0.5, wr)), [(None, ("bone", side + "Hand"))], sharp=50)
        s.blob(p + "Hand", "PlateSteel", [(b, ("bone", side + "Hand")) for b in s.hand_solids(sg, 0.004)], voxel=0.014, smooth=2, tris=700, tint=tint, weight_smooth=0)

    def cyber_leg(s, sg, tint=(0.22, 0.23, 0.25)):
        """A cybernetic leg in place of the flesh one."""
        sk = s.sk
        side = "Left" if sg < 0 else "Right"
        p, j = "CyLeg" + side[0], "CyLegJoints" + side[0]
        hp, kn, an, lr = sk.hp[sg], sk.kn[sg], sk.an[sg], sk.lr
        s.add(j, "Stainless", to_object("J", ball_bm(lr * 0.95, hp + V(0, 0, -lr * 0.6))), [(None, ("bone", side + "UpperLeg"))], sharp=50)
        s.cyl(p, "PlateSteel", hp + V(0, 0, -lr * 1.0), kn + V(0, 0, lr * 0.4), lr * 0.66, side + "UpperLeg", tint=tint, r2=lr * 0.5)
        s.limb_plate("UpperLeg", sg, z0=kn.z + 0.3, z1=hp.z - 0.35, mid=-90, half=80, off=-0.04, thick=0.06, piece=p, tint=tint)
        s.cyl(j, "Stainless", hp + V(sg * lr * 0.2, lr * 0.6, -lr * 1.2), kn + V(sg * lr * 0.2, lr * 0.5, lr * 0.5), lr * 0.13, side + "UpperLeg")
        s.add(j, "Stainless", to_object("J", ball_bm(lr * 0.72, kn)), [(None, ("bone", side + "LowerLeg"))], sharp=50)
        s.cyl(p, "PlateSteel", kn + V(0, 0, -lr * 0.4), an + V(0, 0.02, lr * 0.3), lr * 0.56, side + "LowerLeg", tint=tint, r2=lr * 0.36)
        s.limb_plate("LowerLeg", sg, z0=sk.az + 0.35, z1=kn.z - 0.3, mid=-90, half=100, off=-0.03, thick=0.05, piece=p, tint=tint)
        s.cyl(j, "Stainless", kn + V(0, lr * 0.5, -lr * 0.6), an + V(0, lr * 0.45, lr * 0.5), lr * 0.11, side + "LowerLeg")
        s.add(j, "Stainless", to_object("J", ball_bm(lr * 0.42, an + V(0, 0.02, 0.02))), [(None, ("bone", side + "Foot"))], sharp=50)
        s.blob(p + "Foot", "PlateSteel", [(s.boot_solids(sg, 0.1, 0.0)[0], ("bone", side + "Foot"))], voxel=0.024, smooth=2, tris=320, tint=tint, weight_smooth=0)

    def heavy_armor(s, tint=(0.24, 0.26, 0.22), dark=(0.13, 0.14, 0.13)):
        """A large armour set over the whole body: cuirass front and back, gorget, layered shoulders, tassets, plates
        on every limb, and a closed helm. Each plate rides one bone, so the set bends where the body bends."""
        sk, S = s.sk, s.S
        zs = sk.sh[1].z
        p = "Heavy"
        for front in (True, False):
            s.torso_plate("PlateSteel", tint=tint, z0=sk.z_waist + 0.08, z1=zs + 0.02, half=62, thick=0.11, off=0.17, front=front, piece=p)
            s.torso_plate("PlateSteel", tint=dark, z0=sk.z_hip + 0.2, z1=sk.z_waist + 0.14, half=56, thick=0.08, off=0.19, front=front, piece=p + "Skirt")
        s.collar("PlateSteel", tint=dark, height=0.26, open_deg=0, g=0.2, piece=p + "Skirt")
        for side, sg in SIDES:
            out = 0 if sg > 0 else 180
            s.pauldron(sg, tint=tint, scale=1.45, layers=2, piece=p)
            s.limb_plate("UpperArm", sg, z0=sk.el[sg].z + 0.12, z1=zs - 0.7, mid=out, half=125, off=0.1, thick=0.07, piece=p, tint=tint)
            s.limb_plate("LowerArm", sg, z0=sk.wr[sg].z + 0.12, z1=sk.el[sg].z - 0.1, mid=out, half=150, off=0.1, thick=0.07, piece=p, tint=tint)
            s.limb_plate("UpperLeg", sg, z0=sk.kn[sg].z + 0.25, z1=sk.z_hip - 0.25, mid=-90, half=105, off=0.1, thick=0.08, piece=p, tint=tint)
            s.limb_plate("UpperLeg", sg, z0=sk.kn[sg].z + 0.5, z1=sk.z_hip - 0.05, mid=out, half=50, off=0.12, thick=0.07, piece=p + "Skirt", tint=dark)
            s.limb_plate("LowerLeg", sg, z0=sk.az + 0.3, z1=sk.kn[sg].z - 0.26, mid=-90, half=125, off=0.1, thick=0.08, piece=p, tint=tint)
            s.knee(sg, tint=tint, piece=p)
        s.helmet("PlateSteel", tint=tint, cover=0.92, grow=1.3, piece=p + "Helm")
        s.visor("GlassDark", half=46, height=0.09, drop=0.0, glow=None, r=1.36, piece=p + "Visor")

    def finish(s):
        """Joins each piece's objects, builds the armature and binds everything to it."""
        objs = []
        for key, obs in s.pieces.items():
            if len(obs) > 1:
                bpy.ops.object.select_all(action="DESELECT")
                for o in obs:
                    o.select_set(True)
                bpy.context.view_layer.objects.active = obs[0]
                bpy.ops.object.join()
            ob = obs[0]
            ob.name = key
            ob.data.materials.clear()
            ob.data.materials.append(material(key.rsplit("_", 1)[-1], (0.5, 0.5, 0.5)))
            n = tri_count(ob)
            assert n < 20000, (key, n)
            objs.append(ob)
        s.objects = objs
        ad = bpy.data.armatures.new(f"{s.name}Rig")
        arm = bpy.data.objects.new(f"{s.name}Rig", ad)
        bpy.context.collection.objects.link(arm)
        bpy.context.view_layer.objects.active = arm
        bpy.ops.object.mode_set(mode="EDIT")
        for l in LIMBS:
            b = ad.edit_bones.new(l)
            b.head, b.tail = s.sk.centre[l], s.sk.centre[l] + V(0, 0, 0.2)
        bpy.ops.object.mode_set(mode="OBJECT")
        for ob in objs:
            ob.parent = arm
            m = ob.modifiers.new("Rig", "ARMATURE")
            m.object = arm
        s.armature = arm
        return objs

    def proxy(s):
        """The invisible rig for this figure: 15 plain limbs whose boxes put every joint where the skin bends
        (server/Rigs.lua joints a limb at its top centre). They are the hitboxes, what worn gear welds to, and the
        pieces a violent death scatters. -> out/Rig_<Name>.fbx (replaces the old blocky rig of the same name)."""
        obs = []
        for l in LIMBS:
            lo, hi = s.sk.box[l]
            c = (lo + hi) / 2
            rx, ry = (hi.x - lo.x) / 2, (hi.y - lo.y) / 2
            n = 3.0 if ("Torso" in l or "Foot" in l) else 2.2
            k = 0.82 if "Torso" not in l and "Foot" not in l and "Head" not in l else 0.9
            bm = skin_rings([ring(V(c.x, c.y, z), rx * q, ry * q, n, 14) for z, q in ((lo.z, k), (lo.z + (hi.z - lo.z) * 0.3, 1.0), (hi.z - (hi.z - lo.z) * 0.3, 1.0), (hi.z, k))])
            ob = to_object(f"{l}_Proxy", bm)
            bm.free()
            for p in ob.data.polygons:
                p.use_smooth = True
            ob.data.materials.append(material("Proxy", (0.1, 0.1, 0.11)))
            obs.append(ob)
        export_fbx(os.path.join(OUT, f"Rig_{s.name}.fbx"), obs)
        for ob in obs:
            bpy.data.objects.remove(ob)
        print("BUILT Rig", s.name, "height", round(s.sk.height, 2), flush=True)

    def export(s, layer=None, pieces=None):
        """layer + pieces: only the pieces whose name (before the material) is listed, as out/Skin_<layer>.fbx."""
        if layer:
            keep = [o for o in s.objects if o.name.rsplit("_", 1)[0] in pieces]
            assert keep, layer
            bpy.ops.object.select_all(action="DESELECT")
            for o in keep:
                o.select_set(True)
            s.armature.select_set(True)
            path = os.path.join(OUT, f"Skin_{layer}.fbx")
            bpy.ops.export_scene.fbx(filepath=path, use_selection=True, apply_unit_scale=True, global_scale=0.01, bake_space_transform=False,
                                     axis_forward="-Z", axis_up="Y", object_types={"MESH", "ARMATURE"}, add_leaf_bones=False,
                                     use_armature_deform_only=False, mesh_smooth_type="FACE")
            def c255(t):
                return "Color3.fromRGB(%d, %d, %d)" % tuple(round(c * 255) for c in t)
            print("LUA", layer, "Tints = { " + ", ".join(f"{o.name} = {c255(s.tints[o.name])}" for o in keep if o.name in s.tints) + " }", flush=True)
            print("BUILT Skin", layer, len(keep), "pieces", sum(tri_count(o) for o in keep), "tris:", ", ".join(f"{o.name} {tri_count(o)}" for o in keep), flush=True)
            return path
        bpy.ops.object.select_all(action="DESELECT")
        for o in s.objects:
            o.select_set(True)
        s.armature.select_set(True)
        path = os.path.join(OUT, f"Skin_{s.name}.fbx")
        bpy.ops.export_scene.fbx(filepath=path, use_selection=True, apply_unit_scale=True, global_scale=0.01, bake_space_transform=False,
                                 axis_forward="-Z", axis_up="Y", object_types={"MESH", "ARMATURE"}, add_leaf_bones=False,
                                 use_armature_deform_only=False, mesh_smooth_type="FACE")
        def c255(t):
            return "Color3.fromRGB(%d, %d, %d)" % tuple(round(c * 255) for c in t)
        print("LUA", s.name, "Tints = { " + ", ".join(f"{k} = {c255(v)}" for k, v in s.tints.items()) + " }", flush=True)
        total = sum(tri_count(o) for o in s.objects)
        print("BUILT Skin", s.name, len(s.objects), "pieces", total, "tris:", ", ".join(f"{o.name} {tri_count(o)}" for o in s.objects), flush=True)
        return path

    def static(s, name, angles, tris=2600, turn=None, fused=None, skip=()):
        """A posed, unskinned copy for bodies that never move (the dead): out/<name>.fbx. `turn` lays the figure
        down (a Matrix); it is then dropped onto the ground at the origin. fused = a material name: every piece
        is melted into one mesh of that material (the calcified dead). Otherwise pieces keep their names, so the
        game dresses and tints them like the living body. skip = piece names left out."""
        s.pose(angles)
        dg = bpy.context.evaluated_depsgraph_get()
        made = []
        for ob in s.objects:
            key = ob.name[4:] if ob.name.startswith("src_") else ob.name
            if key.split("_")[0] in skip or key.startswith("Anchor"):
                continue
            ob.name = "src_" + key
            me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
            me.transform((turn or Matrix.Identity(4)) @ ob.matrix_world)
            o2 = bpy.data.objects.new(key, me)
            bpy.context.collection.objects.link(o2)
            made.append(o2)
        lo = min(min((v.co.z for v in o.data.vertices)) for o in made)
        xs = [v.co.x for o in made for v in o.data.vertices]
        ys = [v.co.y for o in made for v in o.data.vertices]
        shift = Matrix.Translation(V(-(min(xs) + max(xs)) / 2, -(min(ys) + max(ys)) / 2, -lo))
        for o in made:
            o.data.transform(shift)
        total = sum(tri_count(o) for o in made)
        if fused:
            bpy.ops.object.select_all(action="DESELECT")
            for o in made:
                o.select_set(True)
            bpy.context.view_layer.objects.active = made[0]
            bpy.ops.object.join()
            ob = made[0]
            modify(ob, "REMESH", mode="VOXEL", voxel_size=0.07)
            modify(ob, "SMOOTH", factor=0.6, iterations=4)
            decimate(ob, tris)
            smooth_shade(ob)
            ob.name = f"Body_{fused}"
            ob.data.materials.clear()
            ob.data.materials.append(material(fused, (0.7, 0.67, 0.6)))
            made = [ob]
        else:
            for o in made:
                n = tri_count(o)
                if n > 60:
                    decimate(o, max(40, int(n * tris / total)))
        export_fbx(os.path.join(OUT, f"{name}.fbx"), made)
        print("BUILT Static", name, len(made), "parts", sum(tri_count(o) for o in made), "tris", flush=True)
        for o in made:
            bpy.data.objects.remove(o)
        s.pose({})

    # joints for posing the stills: limb -> (parent, pivot)
    def pivots(s):
        sk = s.sk
        pv = {"LowerTorso": (None, V(0, 0, sk.z_hip)), "UpperTorso": ("LowerTorso", V(0, 0, sk.z_waist)), "Head": ("UpperTorso", V(0, 0, sk.z_neck))}
        for side, sg in SIDES:
            pv[side + "UpperArm"] = ("UpperTorso", sk.sh[sg])
            pv[side + "LowerArm"] = (side + "UpperArm", sk.el[sg])
            pv[side + "Hand"] = (side + "LowerArm", sk.wr[sg])
            pv[side + "UpperLeg"] = ("LowerTorso", sk.hp[sg])
            pv[side + "LowerLeg"] = (side + "UpperLeg", sk.kn[sg])
            pv[side + "Foot"] = (side + "LowerLeg", sk.an[sg])
        return pv

    def pose(s, angles):
        """angles: limb -> [(axis, degrees)] about its joint, in world axes (X: + swings the limb backward,
        Y: + raises it out to the figure's left)."""
        pv = s.pivots()
        world = {}
        def solve(l):
            if l in world:
                return world[l]
            parent, pivot = pv[l]
            m = solve(parent) if parent else Matrix.Identity(4)
            r = Matrix.Identity(4)
            for ax, deg in angles.get(l, []):
                r = r @ Matrix.Rotation(math.radians(deg), 4, ax)
            world[l] = m @ Matrix.Translation(pivot) @ r @ Matrix.Translation(-pivot)
            return world[l]
        for l in LIMBS:
            solve(l)
        for pb in s.armature.pose.bones:
            if pb.name in world:
                pb.matrix = world[pb.name] @ pb.bone.matrix_local
            bpy.context.view_layer.update()

    def materials_for_stills(s):
        for ob in s.objects:
            name = ob.name.rsplit("_", 1)[-1]
            m = bpy.data.materials.new("Still_" + ob.name)
            m.use_nodes = True
            nt = m.node_tree
            b = nt.nodes["Principled BSDF"]
            tint = s.tints.get(ob.name)
            if ob.name in s.glow:
                c = s.glow[ob.name]
                b.inputs["Base Color"].default_value = (*c, 1)
                b.inputs["Emission Color"].default_value = (*c, 1)
                b.inputs["Emission Strength"].default_value = 6.0
            elif os.path.exists(os.path.join(TEX, f"{name}_col.png")):
                def tex(kind, noncolor=True):
                    n = nt.nodes.new("ShaderNodeTexImage")
                    n.image = bpy.data.images.load(os.path.join(TEX, f"{name}_{kind}.png"), check_existing=True)
                    if noncolor:
                        n.image.colorspace_settings.name = "Non-Color"
                    return n
                col = tex("col", False).outputs["Color"]
                if tint:
                    mx = nt.nodes.new("ShaderNodeMix")
                    mx.data_type, mx.blend_type = "RGBA", "MULTIPLY"
                    mx.inputs["Factor"].default_value = 1.0
                    nt.links.new(col, mx.inputs[6])
                    mx.inputs[7].default_value = (*still_tint(name, tint), 1)
                    col = mx.outputs[2]
                nt.links.new(col, b.inputs["Base Color"])
                nt.links.new(tex("rgh").outputs["Color"], b.inputs["Roughness"])
                nt.links.new(tex("mtl").outputs["Color"], b.inputs["Metallic"])
                nm = nt.nodes.new("ShaderNodeNormalMap")
                nt.links.new(tex("nrm").outputs["Color"], nm.inputs["Color"])
                nt.links.new(nm.outputs["Normal"], b.inputs["Normal"])
            else:
                b.inputs["Base Color"].default_value = (*[lin(c) for c in (tint or (0.3, 0.3, 0.3))], 1)
            ob.data.materials.clear()
            ob.data.materials.append(m)

    def stills(s, views=("front", "back", "action"), size=(900, 1200), samples=40, action=None, look=None, show=None):
        """look + show: render only the pieces listed (a layered figure in one state), as figure_<Name>_<look>_<view>."""
        if not getattr(s, "_still_mats", False):
            s.materials_for_stills()
            s._still_mats = True
        for o in s.objects:
            o.hide_render = bool(show is not None and o.name.rsplit("_", 1)[0] not in show) or o.name.startswith("Anchor")
        sc = bpy.context.scene
        sc.render.engine = "CYCLES"
        sc.cycles.device, sc.cycles.samples, sc.cycles.use_denoising = "CPU", samples, True
        sc.render.resolution_x, sc.render.resolution_y = size
        sc.view_settings.view_transform = "AgX"
        sc.view_settings.look = "AgX - Medium High Contrast"
        h = s.sk.height
        if not getattr(s, "_stage", None):
            w = bpy.data.worlds.new("W")
            w.use_nodes = True
            w.node_tree.nodes["Background"].inputs["Color"].default_value = (0.045, 0.05, 0.058, 1)
            sc.world = w
            h = s.sk.height
            bpy.ops.mesh.primitive_plane_add(size=60)
            floor = bpy.context.active_object
            fm = bpy.data.materials.new("Floor")
            fm.use_nodes = True
            fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.05, 0.052, 0.056, 1)
            fm.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.55
            floor.data.materials.append(fm)
            def lamp(at, energy, color, sz):
                d = bpy.data.lights.new("L", "AREA")
                d.energy, d.color, d.size = energy, color, sz
                o = bpy.data.objects.new("L", d)
                bpy.context.collection.objects.link(o)
                o.location = at
                o.rotation_euler = (V(0, 0, h * 0.55) - Vector(at)).to_track_quat("-Z", "Y").to_euler()
                return o
            k = h / 5.9
            lamps = [lamp((5 * k, -7 * k, h * 1.5), 2100 * k * k, (1.0, 0.95, 0.9), 5 * k), lamp((-7 * k, -3 * k, h * 0.7), 500 * k * k, (0.75, 0.86, 1.0), 6 * k),
                     lamp((-2 * k, 8 * k, h * 1.3), 1500 * k * k, (0.85, 0.93, 1.0), 4 * k)]
            cd = bpy.data.cameras.new("Cam")
            cam = bpy.data.objects.new("Cam", cd)
            bpy.context.collection.objects.link(cam)
            sc.camera = cam
            cd.lens = 70
            s._stage = (lamps, cam)
        lamps, cam = s._stage
        shots = {"front": (0.5, -1.0), "back": (-0.55, 1.0), "action": (0.75, -1.0), "side": (1.0, -0.05)}
        out = []
        for view in views:
            s.pose(action if (view == "action" and action) else {})
            ax, ay = shots[view]
            d = V(ax, ay, 0).normalized()
            for i, l in enumerate(lamps):
                if view == "back":
                    l.location = V(-l.location.x, -l.location.y, l.location.z) if not getattr(l, "flipped", False) else l.location
                    l.rotation_euler = (V(0, 0, h * 0.55) - l.location).to_track_quat("-Z", "Y").to_euler()
            cam.location = V(0, 0, h * 0.52) + d * (h * 2.25) + V(0, 0, h * 0.1)
            cam.rotation_euler = (V(0, 0, h * 0.5) - cam.location).to_track_quat("-Z", "Y").to_euler()
            p = os.path.join(OUT, f"figure_{s.name}_{look + '_' if look else ''}{view}.png")
            sc.render.filepath = p
            bpy.ops.render.render(write_still=True)
            if view == "back":
                for l in lamps:
                    l.location = V(-l.location.x, -l.location.y, l.location.z)
                    l.rotation_euler = (V(0, 0, h * 0.55) - l.location).to_track_quat("-Z", "Y").to_euler()
            out.append(p)
            print("RENDERED", p, flush=True)
        s.pose({})
        return out

# an action pose for the stills: a stride with one arm raised and bent, to show how the joints fold
ACTION = {
    "UpperTorso": [("Z", 10), ("X", -5)], "Head": [("Z", -12)],
    "RightUpperArm": [("X", -58), ("Y", -6)], "RightLowerArm": [("X", -80)],
    "LeftUpperArm": [("X", 28), ("Y", 8)], "LeftLowerArm": [("X", -28)],
    "LeftUpperLeg": [("X", -42)], "LeftLowerLeg": [("X", 62)],
    "RightUpperLeg": [("X", 20)], "RightLowerLeg": [("X", 14)],
}

FIGURES = {}
def figure(name, **kw):
    def deco(fn):
        FIGURES[name] = (fn, kw)
        return fn
    return deco

def run(argv):
    sys.modules.setdefault("figure", sys.modules[__name__])
    import figures  # noqa: registers every character
    want = [a for a in argv if not a.startswith("--")]
    names = list(FIGURES) if (not want or want == ["all"]) else want
    for name in names:
        fn, kw = FIGURES[name]
        f = Figure(name, kw["build"], kw.get("over"))
        fn(f)
        f.finish()
        if "--export" in argv:
            if kw.get("layers"):
                for layer, pieces in kw["layers"].items():
                    f.export(layer, set(pieces) | {"Anchor"})
            else:
                f.export()
            f.proxy()
        if "--stills" in argv and kw.get("looks"):
            for look, (show, views) in kw["looks"].items():
                f.stills(views=views, action=ACTION, samples=24 if "--quick" in argv else 40, look=look, show=show)
        elif "--stills" in argv:
            views = ("front", "back", "action") if "--quick" not in argv else ("front", "action")
            f.stills(views=views, action=ACTION, samples=24 if "--quick" in argv else 40)
        if "--export" in argv and kw.get("statics"):
            for sname, spec in kw["statics"].items():
                f.static(sname, **spec)
        if "--blend" in argv:
            bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, f"Skin_{name}.blend"))

if __name__ == "__main__":
    run(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
