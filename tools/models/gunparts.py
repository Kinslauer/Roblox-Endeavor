# The gun parts library (2026-11-11, Andy: "make every part listed here, and we will combine them in different ways to
# make a striker fired, hammer operated, and revolver handguns ... an Ar15 ... for a rifle parallel").
#
# Every part of every platform is defined once, in INCHES, in its ASSEMBLED place, with the number it has on the
# platform's parts chart and an explode offset for the exploded view. From that one definition this file makes:
#   - the exploded still (numbered, like a parts chart) and the assembled still, for review;
#   - the game model: parts merged per moving group and material ("<Group>_<Material>", e.g. Slide_Gunmetal), parts
#     that cannot be seen from outside left out (springs, pins and plungers inside the gun).
# Platforms live in gun_<platform>.py and register a builder: hammer (1911 pattern), striker, revolver, rifle (AR-15
# pattern). A variant is a platform plus options (barrel length, suppressor, light, rail ...).
#
# Axes: Y forward (the bore), Z up, X to the gun's right. Bore axis on Z 0. Inches until export, then K studs per inch.
# Export: handguns go out in the "Pistol" grip convention (Blender barrel +Z, top +Y, the grip top at the origin; the
# same as pistol_kit.py), rifles in the "Rifle" convention (firearms.py: barrel +Y, top +Z, the grip at the origin).
#
# Run: blender -b --python tools/models/gunparts.py -- <platform|all> [variant ...] [--stills] [--export]
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
import bpy, bmesh
from mathutils import Matrix, Vector

K = 0.19                                     # studs per inch: a 1911 comes out 1.6 studs long, an AR carbine ~6.5
PAL = {"Gunmetal": (0.05, 0.05, 0.055), "Polymer": (0.025, 0.025, 0.03), "GlassDark": (0.08, 0.1, 0.13),
       "HideLeather": (0.2, 0.12, 0.07)}

T = lambda x, y, z: Matrix.Translation((x, y, z))
RX = lambda d: Matrix.Rotation(math.radians(d), 4, "X")
RY = lambda d: Matrix.Rotation(math.radians(d), 4, "Y")
RZ = lambda d: Matrix.Rotation(math.radians(d), 4, "Z")
S = lambda x, y, z: Matrix.Diagonal((x, y, z, 1))
I4 = Matrix.Identity(4)

def mat(n):
    return bpy.data.materials.get(n) or material(n, PAL[n], metallic=0.8 if n == "Gunmetal" else 0.0,
                                                  roughness=0.08 if n == "GlassDark" else 0.45)

def _axis_frame(axis):
    """A matrix turning a shape built along local Z onto the given axis."""
    return {"Z": I4, "Y": RX(-90), "X": RY(90)}[axis]

class Part:
    """One part. Shape methods add solids (inches); cut_* methods add cutters subtracted when the part is made.
    num: chart number (int or str); group: the moving group in the game model; hidden: left out of the game model."""
    def __init__(self, num, name, material, group, explode=(0, 0, 0), hidden=False, label=None):
        self.num, self.name, self.material, self.group = num, name, material, group
        # explode None: the part goes to the tray row under the exploded view (small parts, pins, springs)
        self.tray = explode is None
        self.explode, self.hidden, self.label = Vector(explode or (0, 0, 0)), hidden, label
        self.bm = bmesh.new()
        self.cutters = []
        self.smooth = False

    # ---- internals
    def _take(self, tmp, cut=False):
        if cut:
            self.cutters.append(tmp)
        else:
            me = bpy.data.meshes.new("tmp")
            tmp.to_mesh(me)
            tmp.free()
            self.bm.from_mesh(me)
            bpy.data.meshes.remove(me)
        return self

    def _prism(self, pts, depth, to3d, bev, M, cut):
        """pts in a 2D plane; to3d(u, v, w) -> (x, y, z); extruded over w in [-depth/2, depth/2]."""
        tmp = bmesh.new()
        vs = [tmp.verts.new(to3d(u, v, -depth / 2)) for u, v in pts]
        f = tmp.faces.new(vs)
        r = bmesh.ops.extrude_face_region(tmp, geom=[f])
        moved = [e for e in r["geom"] if isinstance(e, bmesh.types.BMVert)]
        d = Vector(to3d(0, 0, depth / 2)) - Vector(to3d(0, 0, -depth / 2))
        bmesh.ops.translate(tmp, vec=d, verts=moved)
        bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
        if bev > 0 and not cut:
            bmesh.ops.bevel(tmp, geom=list(tmp.edges), offset=bev, offset_type="OFFSET", segments=2, profile=0.5,
                            affect="EDGES", clamp_overlap=True)
        bmesh.ops.transform(tmp, matrix=M, verts=tmp.verts)
        return self._take(tmp, cut)

    # ---- solids
    def side(self, pts, width, x=0.0, bev=0.02, M=I4, cut=False):
        """Side silhouette [(y, z)], extruded across X (width), centred on x."""
        return self._prism(pts, width, lambda u, v, w: (x + w, u, v), bev, M, cut)

    def plan(self, pts, height, z=0.0, bev=0.02, M=I4, cut=False):
        """Top-down outline [(x, y)], extruded up and down Z (height), centred on z."""
        return self._prism(pts, height, lambda u, v, w: (u, v, z + w), bev, M, cut)

    def front(self, pts, length, y=0.0, bev=0.02, M=I4, cut=False):
        """Cross-section [(x, z)] seen from the muzzle, extruded along Y (length), centred on y."""
        return self._prism(pts, length, lambda u, v, w: (u, y + w, v), bev, M, cut)

    def box(self, size, at, bev=0.0, M=I4, cut=False):
        tmp = bmesh.new()
        bmesh.ops.create_cube(tmp, size=1.0, matrix=S(*size))
        if bev > 0 and not cut:
            bmesh.ops.bevel(tmp, geom=list(tmp.edges), offset=min(bev, min(size) * 0.45), offset_type="OFFSET",
                            segments=2, profile=0.5, affect="EDGES", clamp_overlap=True)
        bmesh.ops.transform(tmp, matrix=M @ T(*at), verts=tmp.verts)
        return self._take(tmp, cut)

    def span(self, lo, hi, bev=0.0, M=I4, cut=False):
        """A box between two corners."""
        lo, hi = Vector(lo), Vector(hi)
        return self.box(tuple(hi - lo), tuple((lo + hi) / 2), bev, M, cut)

    def cyl(self, r, length, at, axis="Y", seg=20, r2=None, M=I4, cut=False):
        tmp = bmesh.new()
        bmesh.ops.create_cone(tmp, cap_ends=True, cap_tris=False, segments=seg, radius1=r,
                              radius2=r if r2 is None else r2, depth=length, matrix=M @ T(*at) @ _axis_frame(axis))
        return self._take(tmp, cut)

    def tube(self, ro, ri, length, at, axis="Y", seg=24, M=I4):
        """A hollow cylinder (bore, bushing, ring)."""
        tmp = bmesh.new()
        F = M @ T(*at) @ _axis_frame(axis)
        rings = []
        for z, r in ((-length / 2, ro), (length / 2, ro), (length / 2, ri), (-length / 2, ri)):
            rings.append([tmp.verts.new(F @ Vector((r * math.cos(2 * math.pi * i / seg), r * math.sin(2 * math.pi * i / seg), z)))
                          for i in range(seg)])
        for a in range(4):
            A, B = rings[a], rings[(a + 1) % 4]
            for i in range(seg):
                j = (i + 1) % seg
                tmp.faces.new((A[i], A[j], B[j], B[i]))
        bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
        return self._take(tmp)

    def ball(self, r, at, M=I4, seg=12):
        tmp = bmesh.new()
        bmesh.ops.create_uvsphere(tmp, u_segments=seg, v_segments=max(6, seg // 2), radius=r, matrix=M @ T(*at))
        return self._take(tmp)

    def spring(self, r, wire, length, turns, at, axis="Y", M=I4, seg=6, per_turn=12):
        """A coil spring: a tube of radius `wire` swept along a helix of radius r."""
        tmp = bmesh.new()
        F = M @ T(*at) @ _axis_frame(axis)
        n = max(2, int(turns * per_turn))
        rings = []
        for k in range(n + 1):
            t = k / n
            a = 2 * math.pi * turns * t
            c = Vector((r * math.cos(a), r * math.sin(a), -length / 2 + length * t))
            tang = Vector((-r * math.sin(a) * 2 * math.pi * turns, r * math.cos(a) * 2 * math.pi * turns, length)).normalized()
            nrm = Vector((math.cos(a), math.sin(a), 0))
            bin_ = tang.cross(nrm)
            rings.append([tmp.verts.new(F @ (c + wire * (math.cos(2 * math.pi * i / seg) * nrm + math.sin(2 * math.pi * i / seg) * bin_)))
                          for i in range(seg)])
        for k in range(n):
            for i in range(seg):
                j = (i + 1) % seg
                tmp.faces.new((rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]))
        tmp.faces.new(rings[0][::-1])
        tmp.faces.new(rings[-1])
        bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
        return self._take(tmp)

    def rod(self, r, a, b, seg=10):
        """A pin or rod from point a to point b."""
        a, b = Vector(a), Vector(b)
        d = b - a
        q = d.to_track_quat("Z", "Y").to_matrix().to_4x4()
        tmp = bmesh.new()
        bmesh.ops.create_cone(tmp, cap_ends=True, cap_tris=False, segments=seg, radius1=r, radius2=r, depth=d.length,
                              matrix=Matrix.Translation((a + b) / 2) @ q)
        return self._take(tmp)

    # ---- make
    def make(self):
        if os.environ.get("GUN_DEBUG"):
            print("MAKE", self.num, self.name, len(self.cutters), flush=True)
        ob = obj_from_bmesh(self.name, self.bm, mat(self.material))
        ob.name = f"P{self.num}_{self.name}"
        for i, c in enumerate(self.cutters):
            me = bpy.data.meshes.new("cut")
            c.to_mesh(me)
            c.free()
            co = bpy.data.objects.new(f"cut{i}", me)
            bpy.context.collection.objects.link(co)
            m = ob.modifiers.new(f"b{i}", "BOOLEAN")
            m.operation, m.object, m.solver = "DIFFERENCE", co, "EXACT"
            m.use_self, m.use_hole_tolerant = True, True      # parts are several overlapping solids
        if self.cutters:
            apply_mods(ob)
            for o in [o for o in bpy.data.objects if o.name.startswith("cut")]:
                bpy.data.objects.remove(o)
        ob.data.transform(S(K, K, K))
        if self.smooth:
            for p in ob.data.polygons:
                p.use_smooth = True
        ob["num"], ob["group"], ob["hidden"] = str(self.num), self.group, self.hidden
        ob["label"] = str(self.num) if self.label is None else self.label
        ob["explode"] = tuple(self.explode * K)
        ob["tray"] = self.tray
        return ob

# ---------------------------------------------------------------- platform registry
PLATFORMS = {}

def platform(name, kind, variants, origin):
    """kind: "Pistol" or "Rifle" (the grip convention); origin: the inch point that becomes the model origin;
    variants: {variant: options}. The decorated builder takes options and returns [Part]."""
    def wrap(fn):
        PLATFORMS[name] = dict(build=fn, kind=kind, variants=variants, origin=Vector(origin))
        return fn
    return wrap

# ---------------------------------------------------------------- shared accessories (any platform)
def suppressor(num, at_y, bore_z, length=6.5, r=0.7, group="Suppressor"):
    p = Part(num, "Suppressor", "Gunmetal", group, explode=(0, length * 0.5, 0.6))
    p.cyl(r * 0.88, 0.25, (0, at_y + 0.125, bore_z), seg=32)
    for k in range(7):
        p.cyl(r + 0.03, 0.08, (0, at_y + 0.35 + k * 0.15, bore_z), seg=32)
    body = length - 1.6
    p.cyl(r, body, (0, at_y + 1.35 + body / 2, bore_z), seg=32)
    p.cyl(r, 0.3, (0, at_y + length - 0.15, bore_z), seg=32, r2=r * 0.85)
    p.cyl(0.18, 0.05, (0, at_y + length + 0.02, bore_z), seg=16)
    p.smooth = True
    return p

def weapon_light(num, front_y, rail_z, length=2.4, group="Light"):
    """A boxy light module on a rail: housing, paddle switch, lens."""
    y1, y0 = front_y, front_y - length
    h = Part(num, "Light", "Polymer", group, explode=(0, 0.8, -1.2))
    h.side([(y0, rail_z), (y1, rail_z), (y1, rail_z - 1.25), (y1 - 0.35, rail_z - 1.45), (y0 + 0.3, rail_z - 1.45),
            (y0, rail_z - 1.1)], 1.35, bev=0.1)
    h.span((0.55, y0 - 0.45, rail_z - 0.9), (0.75, y0 + 0.2, rail_z - 0.45), bev=0.04)     # paddle switch
    h.span((-0.55, y0 + 0.2, rail_z - 0.25), (0.55, y0 + 0.6, rail_z + 0.05), bev=0.03)     # rail clamp
    lens = Part(f"{num}a", "Lens", "GlassDark", group + "Lens", explode=(0, 0.8, -1.2), label="")
    lens.cyl(0.42, 0.06, (0.15, y1 + 0.03, rail_z - 0.65), seg=24)
    lens.cyl(0.14, 0.06, (-0.42, y1 + 0.03, rail_z - 0.35), seg=12)
    return [h, lens]

# ---------------------------------------------------------------- building
def build_parts(platform_name, opts):
    reset()
    P = PLATFORMS[platform_name]
    parts = P["build"](opts)
    objs = [p.make() for p in parts]
    return objs

def to_game(objs, kind, origin):
    """Merge the visible parts into one mesh per (group, material); move the origin; turn to the grip convention."""
    merged = {}
    for o in objs:
        if o["hidden"]:
            continue
        key = f"{o['group']}_{o.data.materials[0].name}"
        merged.setdefault(key, []).append(o)
    out = []
    conv = (RY(180) @ RX(-90)) if kind == "Pistol" else I4       # barrel +Y top +Z  ->  barrel +Z top +Y
    shift = T(*(-origin * K))
    for key, group in merged.items():
        bm = bmesh.new()
        for o in group:
            me = o.data.copy()
            me.transform(conv @ shift)
            bm.from_mesh(me)
            bpy.data.meshes.remove(me)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0002)
        mname = key.rsplit("_", 1)[1]
        ob = obj_from_bmesh(key, bm, mat(mname))
        ob.name = key
        smooth = any(len(o.data.polygons) and o.data.polygons[0].use_smooth for o in group)
        if mname in TILE:
            uv_box(ob)
        out.append(ob)
    return out

def tris(objs):
    return sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs)

def export_game(name, objs):
    for o in objs:
        n = tris([o])
        assert n < 20000, f"{o.name}: {n} tris"
    export_fbx(os.path.join(OUT, f"Gun_{name}.fbx"), objs)
    print("EXPORTED", name, len(objs), "parts", tris(objs), "tris", [o.name for o in objs])

# ---------------------------------------------------------------- stills
def _cam(at, look, ortho=None, lens=50):
    cam = bpy.data.cameras.new("Cam")
    if ortho:
        cam.type, cam.ortho_scale = "ORTHO", ortho
    else:
        cam.lens = lens
    co = bpy.data.objects.new("Cam", cam)
    bpy.context.collection.objects.link(co)
    co.location = at
    co.rotation_euler = (Vector(look) - Vector(at)).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = co
    return co

def _light(at, look, energy, size=4.0, color=(1, 1, 1)):
    ld = bpy.data.lights.new("L", "AREA")
    ld.energy, ld.size, ld.color = energy, size, color
    lo = bpy.data.objects.new("L", ld)
    bpy.context.collection.objects.link(lo)
    lo.location = at
    lo.rotation_euler = (Vector(look) - Vector(at)).to_track_quat("-Z", "Y").to_euler()

def _label(text, at, size):
    cu = bpy.data.curves.new("lbl", "FONT")
    cu.body, cu.size, cu.align_x, cu.align_y = text, size, "CENTER", "CENTER"
    ob = bpy.data.objects.new("lbl", cu)
    bpy.context.collection.objects.link(ob)
    ob.location = at
    ob.rotation_euler = (math.radians(90), 0, math.radians(90))      # faces +X, reads along +Y
    m = bpy.data.materials.get("Ink") or material("Ink", (0.02, 0.02, 0.025))
    ob.data.materials.append(m)
    return ob

VIEW = Vector((1.0, 0.42, 0.5)).normalized()        # the stills look from the right, a little in front and above

def _bounds(objs):
    bpy.context.view_layer.update()
    pts = [o.matrix_world @ Vector(v) for o in objs for v in o.bound_box]
    lo = Vector((min(p[i] for p in pts) for i in range(3)))
    hi = Vector((max(p[i] for p in pts) for i in range(3)))
    return lo, hi

def _frame(cam, objs, size, pad=1.12):
    """Point the orthographic camera along VIEW at the objects and size it to hold them."""
    lo, hi = _bounds(objs)
    c = (lo + hi) / 2
    cam.location = c + VIEW * 40
    cam.rotation_euler = (-VIEW).to_track_quat("-Z", "Y").to_euler()
    bpy.context.view_layer.update()
    inv = cam.matrix_world.inverted()
    pts = [inv @ (o.matrix_world @ Vector(v)) for o in objs for v in o.bound_box]
    w = max(p.x for p in pts) - min(p.x for p in pts)
    h = max(p.y for p in pts) - min(p.y for p in pts)
    cx = (max(p.x for p in pts) + min(p.x for p in pts)) / 2
    cy = (max(p.y for p in pts) + min(p.y for p in pts)) / 2
    cam.location = cam.matrix_world @ Vector((cx, cy, 0))
    cam.data.ortho_scale = max(w, h * size[0] / size[1]) * pad
    bpy.context.view_layer.update()

def stills(name, objs, title, size=(1600, 1000)):
    """The assembled gun and the exploded chart (numbered; small parts laid out in rows underneath)."""
    s = bpy.context.scene
    s.render.engine = "CYCLES"
    s.cycles.device, s.cycles.samples, s.cycles.use_denoising = "CPU", 32, True
    s.render.resolution_x, s.render.resolution_y = size
    s.view_settings.view_transform, s.view_settings.look = "AgX", "AgX - Base Contrast"
    w = bpy.data.worlds.new("W")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Color"].default_value = (0.62, 0.63, 0.65, 1)
    s.world = w
    pbr_swap(objs)
    cam = _cam((0, 0, 0), (0, 0, -1), ortho=1)
    lo, hi = _bounds(objs)
    c = (lo + hi) / 2
    _light(c + Vector((6, -3, 7)), c, 1200)
    _light(c + Vector((5, 6, -1)), c, 300, color=(0.85, 0.9, 1.0))
    _light(c + Vector((-4, 0, 6)), c, 400)
    _frame(cam, objs, size, 1.1)
    s.render.filepath = os.path.join(OUT, f"chart_{name}_assembled.png")
    bpy.ops.render.render(write_still=True)
    print("RENDERED", s.render.filepath)
    # exploded: the main parts by their offsets, the tray in rows below
    main = [o for o in objs if not o["tray"]]
    tray = sorted([o for o in objs if o["tray"]], key=lambda o: (len(o["num"]), o["num"]))
    for o in main:
        o.location = Vector(o["explode"])
    lo, hi = _bounds(main)
    gap = 0.12
    wide = (hi.y - lo.y) * 0.45                     # the tray is wider than the gun, so the chart fills the frame
    lo.y, hi.y = lo.y - wide, hi.y + wide
    y, z, row_h = lo.y, lo.z - 0.25, 0.0
    for o in tray:
        olo, ohi = _bounds([o])
        o.location = Vector((0, 0, 0))
        olo, ohi = _bounds([o])
        wy, hz = ohi.y - olo.y, ohi.z - olo.z
        if y + wy > hi.y and y > lo.y:
            y, z, row_h = lo.y, z - row_h - 0.22, 0.0
        o.location = Vector((-(olo.x + ohi.x) / 2, y - olo.y, z - ohi.z))
        y += wy + gap + 0.22
        row_h = max(row_h, hz)
    _frame(cam, objs, size, 1.16)
    up = cam.matrix_world.to_3x3() @ Vector((0, 1, 0))
    tsize = cam.data.ortho_scale * 0.018
    for o in objs:
        if o["label"]:
            plo, phi = _bounds([o])
            inv = cam.matrix_world.inverted()
            pts = [inv @ (o.matrix_world @ Vector(v)) for v in o.bound_box]
            top = max(p.y for p in pts)
            mid = (plo + phi) / 2
            mc = inv @ mid
            at = cam.matrix_world @ Vector((mc.x, top + tsize * 0.9, -2))      # in front of everything
            lb = _label(o["label"], at, tsize)
            lb.rotation_euler = cam.rotation_euler
    lo, hi = _bounds(objs)
    inv = cam.matrix_world.inverted()
    tl = cam.matrix_world @ Vector((-cam.data.ortho_scale * 0.47, -cam.data.ortho_scale * size[1] / size[0] * 0.46, -1))
    lb = _label(title, tl, tsize * 1.5)
    lb.data.align_x = "LEFT"
    lb.rotation_euler = cam.rotation_euler
    s.render.filepath = os.path.join(OUT, f"chart_{name}_exploded.png")
    bpy.ops.render.render(write_still=True)
    print("RENDERED", s.render.filepath)

# ---------------------------------------------------------------- main
def run(argv):
    import importlib
    sys.modules.setdefault("gunparts", sys.modules[__name__])
    for mod in ("gun_hammer", "gun_striker", "gun_revolver", "gun_rifle"):
        if os.path.exists(os.path.join(os.path.dirname(os.path.abspath(__file__)), mod + ".py")):
            importlib.import_module(mod)
    flags = {a for a in argv if a.startswith("--")}
    names = [a for a in argv if not a.startswith("--")]
    plats = list(PLATFORMS) if not names or names[0] == "all" else [names[0]]
    want = set(names[1:])
    for pl in plats:
        P = PLATFORMS[pl]
        for vname, opts in P["variants"].items():
            if want and vname not in want:
                continue
            if "--stills" in flags and opts.get("chart"):
                objs = build_parts(pl, opts)
                print("PARTS", vname, len(objs), "parts", tris(objs), "tris")
                stills(vname, objs, opts.get("title", vname))
            if "--export" in flags:
                objs = build_parts(pl, opts)
                game = to_game(objs, P["kind"], P["origin"])
                for o in objs:
                    bpy.data.objects.remove(o)
                export_game(vname, game)
                bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, f"Gun_{vname}_scene.blend"))

if __name__ == "__main__":
    run(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
