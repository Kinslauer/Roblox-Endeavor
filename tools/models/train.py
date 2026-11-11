# The arrival, rebuilt for the realistic pass (2026-11-11): the Line 9 car, its moulded seats, the Whisper and the
# rider's poncho, all on the shared material library (tools/textures). Run:
#   blender -b --python tools/models/train.py [-- car pistol cloak door]
# -> out/Subway_Car.fbx, Subway_Door.fbx, Wpn_Whisper.fbx, Intro_Cloak.fbx, Intro_CloakStand.fbx, out/intro_scene.blend
#
# Blender axes: X across the car, Y along it, Z up; the FBX import makes Roblox X = -Blender X, Y = Z, Z = Y.
# Every object is "<Part>_<Material>" and gets world-scale box UVs (lib.uv_box), so the library textures repeat at
# one size on every model. The car keeps the old shell's footprint (Subway.lua's colliders and the Intro timeline
# depend on it): floor top z 0, 12.6 wide, 56 long, the door bay open at y -4..4 (9 high), end walls' inner face at y +-27.6.
#
# Seats (for the seated pose, tell the arrival thread if these move): seat cushion top z 1.5, front edge |x| 4.4,
# back of the pan |x| 5.8, backrest leaning 12 degrees back from |x| 5.85 at z 1.6; 8 seats per bench at a 2.125 pitch,
# benches y 7..24 and -24..-7 on both sides. Aisle between the seat fronts: 8.8 wide.
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
import bpy, bmesh
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
WANT = set(argv) or {"car", "door", "pistol", "cloak"}

PAL = {  # flat stand-ins; the game and the renders use the library textures
    "CarBody": (0.30, 0.31, 0.30), "CarLivery": (0.3, 0.05, 0.03), "CarPanel": (0.42, 0.44, 0.40), "CarFloor": (0.04, 0.04, 0.04),
    "Moquette": (0.03, 0.04, 0.08), "SeatShell": (0.05, 0.06, 0.07), "Stainless": (0.55, 0.56, 0.57), "Underframe": (0.04, 0.04, 0.04),
    "Gunmetal": (0.04, 0.04, 0.045), "Polymer": (0.02, 0.02, 0.025), "Waxcloth": (0.035, 0.038, 0.03), "HideLeather": (0.05, 0.03, 0.02),
    "CarTrim": (0.02, 0.024, 0.026), "Glass": (0.12, 0.16, 0.2), "Screen": (0.05, 0.31, 0.45), "Lightbar": (0.9, 0.95, 1.0),
}
T = lambda x, y, z: Matrix.Translation((x, y, z))
RX = lambda d: Matrix.Rotation(math.radians(d), 4, "X")
RY = lambda d: Matrix.Rotation(math.radians(d), 4, "Y")
RZ = lambda d: Matrix.Rotation(math.radians(d), 4, "Z")
S = lambda x, y, z: Matrix.Diagonal((x, y, z, 1))

def mat(n):
    return bpy.data.materials.get(n) or material(n, PAL[n], emission=PAL[n] if n == "Lightbar" else None)

class G:
    """Geometry for one object: add shapes into a bmesh, then make() it into a named, UV-mapped object."""
    def __init__(self):
        self.bm = bmesh.new()
    def box(self, size, M=Matrix.Identity(4), bev=0.0, seg=2):
        tmp = bmesh.new()
        bmesh.ops.create_cube(tmp, size=1.0, matrix=S(*size))
        if bev > 0:
            bmesh.ops.bevel(tmp, geom=list(tmp.edges) + list(tmp.verts), offset=min(bev, min(size) * 0.45), offset_type="OFFSET",
                            segments=seg, profile=0.5, affect="EDGES", clamp_overlap=True)
        bmesh.ops.transform(tmp, matrix=M, verts=tmp.verts)
        self._take(tmp)
        return self
    def cyl(self, r1, r2, depth, M=Matrix.Identity(4), seg=16, cap=True):
        tmp = bmesh.new()
        bmesh.ops.create_cone(tmp, cap_ends=cap, cap_tris=False, segments=seg, radius1=r1, radius2=r2, depth=depth, matrix=M)
        self._take(tmp)
        return self
    def torus(self, R, r, M=Matrix.Identity(4), seg=20, rseg=8):
        tmp = bmesh.new()
        rings = []
        for i in range(seg):
            a = 2 * math.pi * i / seg
            ring = []
            for j in range(rseg):
                b = 2 * math.pi * j / rseg
                ring.append(tmp.verts.new(((R + r * math.cos(b)) * math.cos(a), (R + r * math.cos(b)) * math.sin(a), r * math.sin(b))))
            rings.append(ring)
        for i in range(seg):
            for j in range(rseg):
                a, b = rings[i][j], rings[(i + 1) % seg][j]
                c, d = rings[(i + 1) % seg][(j + 1) % rseg], rings[i][(j + 1) % rseg]
                tmp.faces.new((a, b, c, d))
        bmesh.ops.transform(tmp, matrix=M, verts=tmp.verts)
        self._take(tmp)
        return self
    def sweep(self, profile, y0, y1, closed=False, M=Matrix.Identity(4), caps=False):
        """A 2D profile [(x, z)...] swept along Y from y0 to y1 (faces out to the profile's right-hand side)."""
        tmp = bmesh.new()
        a = [tmp.verts.new((x, y0, z)) for x, z in profile]
        b = [tmp.verts.new((x, y1, z)) for x, z in profile]
        n = len(profile)
        for i in range(n if closed else n - 1):
            j = (i + 1) % n
            tmp.faces.new((a[i], a[j], b[j], b[i]))
        if caps and closed:
            tmp.faces.new(list(reversed(a)))
            tmp.faces.new(b)
        bmesh.ops.transform(tmp, matrix=M, verts=tmp.verts)
        self._take(tmp)
        return self
    def poly(self, pts):
        tmp = bmesh.new()
        tmp.faces.new([tmp.verts.new(p) for p in pts])
        self._take(tmp)
        return self
    def strip(self, rows):
        """Rows of points of equal length -> a quad grid."""
        tmp = bmesh.new()
        vs = [[tmp.verts.new(p) for p in r] for r in rows]
        for k in range(len(vs) - 1):
            for i in range(len(vs[k]) - 1):
                tmp.faces.new((vs[k][i], vs[k][i + 1], vs[k + 1][i + 1], vs[k + 1][i]))
        self._take(tmp)
        return self
    def _take(self, tmp):
        me = bpy.data.meshes.new("tmp")
        tmp.to_mesh(me)
        tmp.free()
        self.bm.from_mesh(me)
        bpy.data.meshes.remove(me)
    def make(self, name, m, smooth=False, uv=True):
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=0.0004)
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        ob = obj_from_bmesh(name, self.bm, mat(m))
        if smooth:
            for p in ob.data.polygons:
                p.use_smooth = True
        if uv:
            uv_box(ob)
        return ob

def uv_cyl(ob, tile, radius=1.2):
    """Cylindrical UVs around Z (cloth): one seam at the back, so the weave does not break into blocks."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    uv = bm.loops.layers.uv.verify()
    for f in bm.faces:
        angs = [math.atan2(l.vert.co.x, l.vert.co.y) for l in f.loops]
        base = angs[0]
        for l, a in zip(f.loops, angs):
            if a - base > math.pi:
                a -= 2 * math.pi
            elif base - a > math.pi:
                a += 2 * math.pi
            l[uv].uv = (a * radius / tile, l.vert.co.z / tile)
    bm.to_mesh(ob.data)
    bm.free()

def tris(objs):
    return sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs)

def export(file, parts):
    os.makedirs(OUT, exist_ok=True)
    for p in parts:
        n = tris([p])
        assert n < 20000, f"{p.name} has {n} triangles (Roblox caps a mesh at 20k)"
    export_fbx(os.path.join(OUT, f"{file}.fbx"), parts)
    print("BUILT", file, len(parts), "parts", tris(parts), "tris")

def rrect(cx, cz, w, h, r, n=6):
    """A rounded rectangle in the (y, z) plane as a closed list of (y, z), counter-clockwise from the right."""
    pts = []
    for (ox, oz, a0) in ((w / 2 - r, h / 2 - r, 0), (-(w / 2 - r), h / 2 - r, 90), (-(w / 2 - r), -(h / 2 - r), 180), (w / 2 - r, -(h / 2 - r), 270)):
        for i in range(n + 1):
            a = math.radians(a0 + 90 * i / n)
            pts.append((cx + ox + r * math.cos(a), cz + oz + r * math.sin(a)))
    return pts

def window_tile(g, x, yc, z0, z1, w, hole, outward, depth=0.0):
    """A wall tile in the plane x (from y yc-w/2..yc+w/2, z z0..z1) with a rounded window hole; outward = +1/-1 is
    the side the face looks to. hole = (zc, hw, hh, r)."""
    zc, hw, hh, r = hole
    inner = rrect(yc, zc, hw, hh, r)
    outer = []
    for (y, z) in inner:  # project each hole point onto the tile's border along the ray from the hole centre
        dy, dz = y - yc, z - zc
        ty = (w / 2) / abs(dy) if abs(dy) > 1e-6 else 1e9
        tz = ((z1 - zc) if dz > 0 else (zc - z0)) / abs(dz) if abs(dz) > 1e-6 else 1e9
        t = min(ty, tz)
        outer.append((yc + dy * t, zc + dz * t))
    n = len(inner)
    tmp = bmesh.new()
    vi = [tmp.verts.new((x, y, z)) for y, z in inner]
    vo = [tmp.verts.new((x, y, z)) for y, z in outer]
    def side(p):  # which border edge a projected point sits on
        y, z = p
        if abs(y - (yc + w / 2)) < 1e-5: return 0
        if abs(z - z1) < 1e-5: return 1
        if abs(y - (yc - w / 2)) < 1e-5: return 2
        return 3
    corner = {(0, 1): (yc + w / 2, z1), (1, 2): (yc - w / 2, z1), (2, 3): (yc - w / 2, z0), (3, 0): (yc + w / 2, z0)}
    for i in range(n):
        j = (i + 1) % n
        si, sj = side(outer[i]), side(outer[j])
        if si != sj and (si, sj) in corner:   # the outline turns a corner of the tile between these two points
            c = tmp.verts.new((x, *corner[(si, sj)]))
            f = (vi[i], vi[j], vo[j], c, vo[i])
        else:
            f = (vi[i], vi[j], vo[j], vo[i])
        tmp.faces.new(f if outward > 0 else tuple(reversed(f)))
    if depth:  # the reveal: the hole's sides run back into the wall
        vd = [tmp.verts.new((x - outward * depth, y, z)) for y, z in inner]
        for i in range(n):
            j = (i + 1) % n
            f = (vi[j], vi[i], vd[i], vd[j])
            tmp.faces.new(f if outward > 0 else tuple(reversed(f)))
    g._take(tmp)

# =====================================================================================================
# The car's size (2026-11-11, Andy: "train car is too small"): 12.6 wide outside, 56 long, 10.9 high inside at the
# crown, doors 9 high. The centre line stays where Subway.lua had it, so the door side still meets the platform edge.
HALF, WI, LEN = 6.3, 6.0, 28.0          # outer skin, inner lining (half widths), half length
DX = WI - 4.2                            # how far everything that hangs off the wall moved out from the old 9-wide car
WIN = dict(z0=3.4, z1=7.9, zc=5.65, hw=3.0, hh=4.0, r=0.5)
DOOR_H, CEIL, ROOF = 9.0, 10.9, 12.1     # door opening, inside crown, outside crown

def build_car():
    reset()
    SEGS = ((-27.6, -4.0), (4.0, 27.6))
    lining, ceiling, floor, body, livery, trim, glass, seat_shell, moq, steel, under, screen, rubber = (G() for _ in range(13))
    X = lambda sx, d: sx * (d + DX)       # an old wall-relative x, moved out to the new wall

    for sx in (-1, 1):
        xi, xo = sx * WI, sx * HALF
        for (y0, y1) in SEGS:
            # inside: a cove into the floor, the lower wall, the window band, the curved upper wall into the ceiling
            low = [(sx * (WI - 0.22), 0.0), (sx * (WI - 0.12), 0.18), (xi, 0.45), (xi, WIN["z0"])]
            up = [(xi, WIN["z1"]), (sx * (WI - 0.05), 8.6), (sx * (WI - 0.3), 9.3), (sx * (WI - 0.8), 9.8)]
            for prof in (low, up):
                lining.sweep(prof if sx < 0 else list(reversed(prof)), y0, y1)
            n = int(round((y1 - y0) / 4.0))
            w = (y1 - y0) / n
            for k in range(n):
                yc = y0 + w * (k + 0.5)
                window_tile(lining, xi, yc, WIN["z0"], WIN["z1"], w, (WIN["zc"], WIN["hw"], WIN["hh"], WIN["r"]), -sx, depth=0.12)
                window_tile(body, xo, yc, WIN["z0"], WIN["z1"], w, (WIN["zc"], WIN["hw"] + 0.1, WIN["hh"] + 0.1, WIN["r"] + 0.05), sx)
                gasket = rrect(yc, WIN["zc"], WIN["hw"], WIN["hh"], WIN["r"])
                gasket = gasket + [gasket[0]]
                rubber.strip([[(sx * (WI - 0.12), y, z) for y, z in gasket], [(sx * (HALF - 0.1), y, z) for y, z in gasket]])
            glass.box((0.05, y1 - y0, WIN["z1"] - WIN["z0"]), T(sx * (HALF - 0.16), (y0 + y1) / 2, (WIN["z0"] + WIN["z1"]) / 2))
            # outside: lower skin with flutes, the red line under the windows, the band over them
            skin = [(sx * (HALF - 0.12), -0.85), (xo, -0.2), (xo, 2.75)]
            body.sweep(skin if sx > 0 else list(reversed(skin)), y0, y1)
            livery.sweep([(xo, 2.75), (xo, WIN["z0"])] if sx > 0 else [(xo, WIN["z0"]), (xo, 2.75)], y0, y1)
            y = y0 + 0.25
            while y < y1 - 0.2:
                body.box((0.06, 0.18, 2.8), T(sx * (HALF + 0.03), y, 1.0), bev=0.025)
                y += 0.55
            topband = [(xo, WIN["z1"]), (sx * (HALF - 0.03), 9.3), (sx * (HALF - 0.15), 9.85)]
            body.sweep(topband if sx > 0 else list(reversed(topband)), y0, y1)
            trim.box((0.12, y1 - y0, 0.1), T(sx * (HALF - 0.08), (y0 + y1) / 2, 9.9), bev=0.03)   # rain gutter
        # door bay surround: the head over the opening, frame posts, threshold
        lining.box((0.3, 8.0, 9.9 - DOOR_H), T(sx * (WI + 0.15), 0, (DOOR_H + 9.9) / 2))
        body.box((0.3, 8.0, 9.9 - DOOR_H), T(sx * (HALF - 0.1), 0, (DOOR_H + 9.9) / 2))
        for yy in (-4.1, 4.1):
            trim.box((0.42, 0.25, DOOR_H + 0.1), T(sx * (WI + 0.1), yy, (DOOR_H + 0.1) / 2), bev=0.05)
        trim.box((0.42, 8.4, 0.22), T(sx * (WI + 0.1), 0, DOOR_H + 0.1), bev=0.05)
        trim.box((0.5, 8.2, 0.08), T(sx * (WI + 0.05), 0, 0.04))
        steel.box((0.42, 8.0, 0.06), T(sx * (WI + 0.05), 0, 0.09), bev=0.02)
        # handrail over each side of the aisle, on brackets from the cove; hanging grab handles
        rail_x, rail_z = sx * (WI - 2.0), 7.9
        steel.cyl(0.075, 0.075, 54.0, T(rail_x, 0, rail_z) @ RX(90), seg=12)
        for y in range(-26, 27, 4):
            top = 10.1 - abs(rail_x) * 0.12
            steel.cyl(0.05, 0.05, top - rail_z, T(rail_x, y, (top + rail_z) / 2), seg=8)
            steel.cyl(0.14, 0.14, 0.06, T(rail_x, y, top), seg=12)
        for y in [v + 0.5 for v in range(-26, 26, 2)]:
            if abs(y) < 4.5:
                continue
            rubber.box((0.05, 0.22, 0.85), T(rail_x, y, rail_z - 0.4), bev=0.02)
            seat_shell.torus(0.26, 0.05, T(rail_x, y, rail_z - 1.05) @ RY(90), seg=16, rseg=6)
        # benches: 8 moulded seats each (cushion top z 1.5, front edge 3.4 from the wall), fabric inserts,
        # a cantilever rail, a heater skirt behind the legs
        for (b0, b1) in ((7.0, 24.0), (-24.0, -7.0)):
            pitch = (b1 - b0) / 8
            for k in range(8):
                yc = b0 + pitch * (k + 0.5)
                wy = pitch - 0.14
                f = sx
                old = [(2.6, 1.22), (2.55, 1.36), (2.62, 1.42), (3.0, 1.40), (3.85, 1.36), (4.0, 1.46),
                       (4.05, 1.62), (4.12, 2.4), (4.2, 3.3), (4.22, 3.6), (4.17, 3.72),
                       (4.05, 3.66), (3.98, 3.3), (3.9, 2.4), (3.84, 1.7), (3.7, 1.58), (3.0, 1.6), (2.75, 1.58), (2.62, 1.5)]
                prof = [(X(f, x), z) for x, z in old]
                if f > 0:
                    prof = list(reversed(prof))
                seat_shell.sweep(prof, yc - wy / 2, yc + wy / 2, closed=True, caps=True)
                moq.box((1.25, wy - 0.3, 0.14), T(X(f, 3.25), yc, 1.43) @ RY(-f * 2), bev=0.05, seg=3)
                moq.box((0.12, wy - 0.3, 1.55), T(X(f, 3.96), yc, 2.55) @ RY(-f * 12), bev=0.05, seg=3)
            ln = b1 - b0
            trim.box((0.3, ln, 0.18), T(X(sx, 3.95), (b0 + b1) / 2, 1.18), bev=0.04)
            for k in range(9):
                trim.box((1.2, 0.12, 0.12), T(X(sx, 3.5), b0 + ln * k / 8, 1.12), bev=0.03)
            lining.box((0.25, ln, 1.0), T(X(sx, 3.95), (b0 + b1) / 2, 0.55), bev=0.05)
            trim.box((0.06, ln - 0.6, 0.5), T(X(sx, 3.82), (b0 + b1) / 2, 0.55))
            for ye in (b0, b1):
                inward = 1 if ye == min(b0, b1) else -1
                glass.box((1.5, 0.05, 2.4), T(X(sx, 3.35), ye - inward * 0.05, 2.6))
                steel.cyl(0.065, 0.065, 2.5, T(X(sx, 2.55), ye - inward * 0.05, 2.6), seg=10)
                steel.cyl(0.065, 0.065, 1.6, T(X(sx, 3.35), ye - inward * 0.05, 3.82) @ RY(90), seg=10)
                steel.cyl(0.065, 0.065, 1.6, T(X(sx, 3.35), ye - inward * 0.05, 1.38) @ RY(90), seg=10)
                px = X(sx, 2.45)
                steel.cyl(0.085, 0.085, CEIL - 0.1, T(px, ye - inward * 0.2, (CEIL - 0.1) / 2), seg=12)   # floor-to-ceiling pole
                steel.cyl(0.16, 0.16, 0.08, T(px, ye - inward * 0.2, 0.04), seg=12)
    # ceiling: a shallow vault from the cove to a lighting channel down the middle
    vault = [(WI - 0.8, 9.8), (4.2, 10.4), (2.4, 10.75), (0.62, CEIL - 0.04)]
    ceiling.sweep(list(reversed(vault)), -27.6, 27.6)
    ceiling.sweep([(-x, z) for x, z in vault], -27.6, 27.6)
    trim.box((1.24, 55.2, 0.06), T(0, 0, CEIL - 0.02))
    for x in (-0.6, 0.6):
        trim.box((0.06, 55.2, 0.3), T(x, 0, CEIL - 0.17), bev=0.02)
    for y in range(-26, 27, 2):
        if all(abs(y - c) > 3.2 for c in (-16, 0, 16)):
            trim.box((1.1, 0.1, 0.06), T(0, y, CEIL - 0.3))
    for x in (-3.2, 3.2):
        for y in range(-24, 25, 6):
            trim.box((0.6, 3.2, 0.05), T(x, y, 10.52) @ RY(-math.copysign(11, x)))
    floor.box((2 * WI - 0.4, 55.2, 0.3), T(0, 0, -0.15))
    # ends: the wall round the gangway door, its window, the line display, a cabinet; outside the bellows and coupler
    for sy in (-1, 1):
        y = sy * 27.6
        for x0, x1 in ((-WI, -1.3), (1.3, WI)):
            lining.box((x1 - x0, 0.2, 9.9), T((x0 + x1) / 2, y + sy * 0.1, 4.95))
        lining.box((2.6, 0.2, CEIL - 7.0), T(0, y + sy * 0.1, (CEIL + 7.0) / 2))
        trim.box((2.9, 0.3, 0.2), T(0, y, 7.0), bev=0.04)
        for x in (-1.35, 1.35):
            trim.box((0.2, 0.3, 7.0), T(x, y, 3.5), bev=0.04)
        body.box((2.5, 0.12, 6.9), T(0, y + sy * 0.12, 3.45), bev=0.04)
        glass.box((1.2, 0.05, 1.8), T(0, y, 5.0))
        rubber.box((1.36, 0.1, 1.96), T(0, y + sy * 0.03, 5.0), bev=0.05)
        steel.box((0.12, 0.2, 0.9), T(0.95, y - sy * 0.06, 3.4), bev=0.04)
        trim.box((4.8, 0.3, 0.9), T(0, y - sy * 0.12, 8.2), bev=0.05)
        screen.box((4.4, 0.05, 0.6), T(0, y - sy * 0.29, 8.2))
        trim.box((1.0, 0.25, 1.6), T(4.6, y - sy * 0.1, 2.0), bev=0.04)
        livery.box((0.8, 0.05, 0.25), T(4.6, y - sy * 0.24, 2.6))
        for x0, x1 in ((-HALF, -1.6), (1.6, HALF)):
            body.box((x1 - x0, 0.3, 10.7), T((x0 + x1) / 2, sy * 27.85, 4.5))
        rubber.box((3.4, 0.5, 8.0), T(0, sy * 28.2, 3.9), bev=0.15, seg=3)
        under.box((1.0, 1.6, 0.8), T(0, sy * 28.6, -1.0), bev=0.1)
    # roof: the outer arch and its end caps, two A/C pods
    arch = [((HALF - 0.15) * math.cos(math.pi / 2 * i / 12), 9.85 + (ROOF - 9.85) * math.sin(math.pi / 2 * i / 12)) for i in range(13)]
    body.sweep(list(reversed(arch)), -28.0, 28.0)
    body.sweep([(-x, z) for x, z in arch], -28.0, 28.0)
    for sy in (-1, 1):
        cap = [(x, sy * 28.0, z) for x, z in arch] + [(-x, sy * 28.0, z) for x, z in reversed(arch)]
        body.poly(cap if sy > 0 else list(reversed(cap)))
        body.box((6.0, 7.0, 0.9), T(0, sy * 15.0, ROOF + 0.25), bev=0.2, seg=2)
        under.box((5.0, 5.0, 0.12), T(0, sy * 15.0, ROOF + 0.75))
        for k in range(5):
            trim.box((5.2, 0.12, 0.1), T(0, sy * 15.0 + (k - 2) * 1.0, ROOF + 0.73))
    # under the floor: frame, skirts, equipment boxes, two bogies (track gauge as before)
    under.box((2 * HALF - 0.6, 55.6, 0.5), T(0, 0, -0.55))
    for sx in (-1, 1):
        body.box((0.12, 40.0, 1.0), T(sx * (HALF - 0.2), 0, -1.1))
        under.box((2.2, 10.0, 1.3), T(sx * 3.4, -6.0, -1.45), bev=0.08)
        under.box((2.2, 6.0, 1.1), T(sx * 3.4, 6.0, -1.35), bev=0.08)
    for sy in (-1, 1):
        cy = sy * 18.5
        under.box((6.6, 8.6, 0.55), T(0, cy, -2.05), bev=0.1)
        under.box((1.5, 1.5, 0.9), T(0, cy, -1.2), bev=0.1)
        for sx in (-1, 1):
            for dy in (-2.9, 2.9):
                under.cyl(0.95, 0.95, 0.32, T(sx * 2.45, cy + dy, -2.45) @ RY(90), seg=24)
                under.cyl(0.5, 0.5, 0.42, T(sx * 2.45, cy + dy, -2.45) @ RY(90), seg=16)
                steel.cyl(1.0, 0.96, 0.08, T(sx * 2.29, cy + dy, -2.45) @ RY(90), seg=24, cap=False)
                under.box((0.7, 0.9, 0.7), T(sx * 3.0, cy + dy, -2.45), bev=0.08)
            for dy in (-1.2, 1.2):
                for k in range(5):
                    steel.torus(0.32, 0.06, T(sx * 3.0, cy + dy, -1.85 + k * 0.17), seg=12, rseg=5)
        under.cyl(0.18, 0.18, 6.0, T(0, cy - 2.9, -2.45) @ RY(90), seg=10)
        under.cyl(0.18, 0.18, 6.0, T(0, cy + 2.9, -2.45) @ RY(90), seg=10)
    parts = [
        lining.make("Lining", "CarPanel"), ceiling.make("Ceiling", "CarPanel"), floor.make("Floor", "CarFloor"),
        body.make("Skin", "CarBody"), livery.make("Stripe", "CarLivery"), trim.make("Trim", "CarTrim"),
        glass.make("Windows", "Glass", uv=False), seat_shell.make("Shells", "SeatShell"), moq.make("Cushions", "Moquette"),
        steel.make("Rails", "Stainless", smooth=True), under.make("Under", "Underframe"), screen.make("Display", "Screen", uv=False),
        rubber.make("Gaskets", "CarTrim"),
    ]
    final = []
    for p in parts:
        final.extend([p] if tris([p]) < 19000 else split_y(p))
    export("Subway_Car", final)
    return final


def split_y(ob, cuts=(-14.0, 0.0, 14.0)):
    """Splits an object into pieces by face centre Y (names get a letter: Lining A, B...)."""
    out = []
    edges = [-1e9, *cuts, 1e9]
    base, m = ob.name.rsplit("_", 1)
    for i in range(len(edges) - 1):
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        kill = [f for f in bm.faces if not (edges[i] <= f.calc_center_median().y < edges[i + 1])]
        bmesh.ops.delete(bm, geom=kill, context="FACES")
        if not bm.faces:
            bm.free()
            continue
        me = bpy.data.meshes.new(f"{base}{chr(65 + i)}")
        bm.to_mesh(me)
        bm.free()
        o = bpy.data.objects.new(f"{base}{chr(65 + i)}_{m}", me)
        me.materials.append(ob.data.materials[0])
        bpy.context.collection.objects.link(o)
        out.append(o)
    bpy.data.objects.remove(ob)
    return out

# =====================================================================================================
def build_door():
    """One sliding door leaf, 4 along Y, DOOR_H tall, 0.3 thick, centred, the same at both edges; the window high in it.
    The painted skin faces +X (Roblox -X): Subway.lua welds a copy to each door part, turned round on the platform side."""
    reset()
    skin, lining, glass, rubber, steel = G(), G(), G(), G(), G()
    hole = (5.9, 1.9, 3.0, 0.3)
    window_tile(skin, 0.15, 0, 0.0, DOOR_H, 4.0, hole, 1, depth=0.3)
    window_tile(lining, -0.15, 0, 0.0, DOOR_H, 4.0, hole, -1)
    rubber.box((0.32, 0.12, DOOR_H), T(0, 2.0 - 0.06, DOOR_H / 2))
    rubber.box((0.32, 4.0, 0.06), T(0, 0, 0.03))
    rubber.box((0.32, 4.0, 0.06), T(0, 0, DOOR_H - 0.03))
    rubber.box((0.32, 0.12, DOOR_H), T(0, -2.0 + 0.06, DOOR_H / 2))
    glass.box((0.05, 1.9, 3.0), T(0, 0, 5.9))
    parts = [skin.make("Leaf", "CarBody"), lining.make("Inner", "CarPanel"), rubber.make("Seal", "CarTrim"),
             glass.make("Pane", "Glass", uv=False)]
    export("Subway_Door", parts)
    return parts

# =====================================================================================================
def build_pistol():
    """The Whisper: grip at the origin running down -Y, barrel along +Z, top at +Y (the old convention; the rack
    moves the part whose name starts with "Slide")."""
    reset()
    slide, frame, grip, barrel, can, small = G(), G(), G(), G(), G(), G()
    # slide: a long block with a chamfered top, serrations at the rear, an ejection port, sights
    sp = [(-0.155, 0.55), (0.155, 0.55), (0.155, 0.76), (0.1, 0.85), (-0.1, 0.85), (-0.155, 0.76)]
    slide.sweep([(x, y) for x, y in sp], -0.27, 1.25, closed=True, caps=True, M=Matrix(((1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1))))
    for k in range(7):
        z = -0.2 + k * 0.055
        for sx in (-1, 1):
            slide.box((0.02, 0.18, 0.025), T(sx * 0.158, 0.66, z))
    slide.box((0.07, 0.07, 0.07), T(-0.07, 0.86, -0.2), bev=0.01)
    slide.box((0.07, 0.07, 0.07), T(0.07, 0.86, -0.2), bev=0.01)
    slide.box((0.05, 0.08, 0.06), T(0, 0.87, 1.17), bev=0.01)
    small.box((0.02, 0.02, 0.02), T(0, 0.915, 1.17))
    # frame: dust cover with a rail, trigger guard, the grip's top
    frame.box((0.28, 0.25, 1.3), T(0, 0.42, 0.52), bev=0.035)
    for k in range(4):
        frame.box((0.3, 0.04, 0.06), T(0, 0.3, 0.75 + k * 0.12))
    frame.torus(0.19, 0.035, T(0, 0.15, 0.33) @ RY(90) @ S(1.0, 1.25, 1.0), seg=18, rseg=6)
    frame.box((0.24, 0.12, 0.38), T(0, 0.25, -0.05), bev=0.04)
    # grip: angled, with a beavertail and finger swells; magazine base plate
    G2 = T(0, -0.15, -0.08) @ RX(12)
    grip.box((0.27, 0.9, 0.42), G2, bev=0.08, seg=3)
    grip.box((0.26, 0.1, 0.25), T(0, 0.38, -0.32) @ RX(-20), bev=0.04)
    small.box((0.3, 0.07, 0.46), T(0, -0.62, -0.18) @ RX(12), bev=0.025)
    small.box((0.04, 0.1, 0.05), T(0, 0.19, 0.4), bev=0.01)                 # trigger
    small.box((0.03, 0.06, 0.18), T(0.155, 0.5, 0.25), bev=0.01)            # slide stop
    # barrel and suppressor: knurled bands, a cap
    barrel.cyl(0.075, 0.075, 0.35, T(0, 0.7, 1.4), seg=16)
    can.cyl(0.155, 0.155, 1.1, T(0, 0.7, 2.05), seg=24)
    for z in (1.52, 1.62, 2.48, 2.58):
        can.cyl(0.165, 0.165, 0.06, T(0, 0.7, z), seg=24)
    can.cyl(0.155, 0.11, 0.06, T(0, 0.7, 2.63), seg=24)
    parts = [slide.make("Slide", "Gunmetal"), frame.make("Frame", "Polymer"), grip.make("Grip", "Polymer"),
             barrel.make("Barrel", "Gunmetal"), can.make("Can", "Gunmetal", smooth=True), small.make("Trigger", "Gunmetal")]
    export("Wpn_Whisper", parts)
    return parts

# =====================================================================================================
# The rider: proxy limbs on the Conduit's proportions, in the seated pose (the old Intro_Seated) and standing.
# Only used to drape the poncho (cloth simulation) and for the renders.
LN = dict(foot=0.42, lowerleg=1.0, upperleg=1.05, lowertorso=0.7, uppertorso=1.5, head=1.2, upperarm=1.0, lowerarm=0.95, hand=0.42)
WD = dict(torso=1.9, depth=1.0, head=1.2, arm=0.62, leg=0.78)

def capsule(g, a, b, r, seg=12):
    a, b = Vector(a), Vector(b)
    d = b - a
    q = d.to_track_quat("Z", "Y").to_matrix().to_4x4()
    g.cyl(r, r, d.length, Matrix.Translation((a + b) / 2) @ q, seg=seg)
    for p in (a, b):
        tmp = bmesh.new()
        bmesh.ops.create_uvsphere(tmp, u_segments=seg, v_segments=6, radius=r, matrix=Matrix.Translation(p))
        g._take(tmp)

def rider(seated, at=Matrix.Identity(4)):
    """Returns (objects, upper torso matrix). Feet on z 0 standing; seated: hips over the cushion, at = where the
    hip joint sits (facing -Y)."""
    body, head, boots, hands = G(), G(), G(), G()
    if seated:
        hip = Vector((0, 0, 0))
        lean = RX(-15)          # the torso leans forward (toward -Y)
        knee_y = -1.0
    else:
        hip = Vector((0, 0, LN["foot"] + LN["lowerleg"] + LN["upperleg"]))
        lean = RX(-2)
    up = lean.to_3x3() @ Vector((0, 0, 1))
    waist = hip + up * LN["lowertorso"]
    neck = waist + up * LN["uppertorso"]
    ut = Matrix.Translation(waist + up * LN["uppertorso"] / 2) @ lean
    body.box((WD["torso"] * 0.92, WD["depth"], LN["lowertorso"] + 0.1), Matrix.Translation(hip + up * 0.35) @ lean, bev=0.25)
    body.box((WD["torso"], WD["depth"] * 1.05, LN["uppertorso"]), ut, bev=0.3)
    hd = Matrix.Translation(neck + up * 0.6) @ lean @ RX(-10 if seated else 0)
    tmp = bmesh.new()
    bmesh.ops.create_uvsphere(tmp, u_segments=16, v_segments=10, radius=0.6, matrix=hd @ S(0.95, 1.0, 1.05))
    head._take(tmp)
    for s in (-1, 1):
        hx = s * WD["leg"] * 0.62
        h = hip + Vector((hx, 0, -0.1))
        if seated:
            k = h + Vector((0, knee_y, 0.05))
            a = k + Vector((0, -0.12, -LN["lowerleg"]))
        else:
            k = h + Vector((0, 0, -LN["upperleg"]))
            a = k + Vector((0, 0, -LN["lowerleg"]))
        capsule(body, h, k, WD["leg"] / 2)
        capsule(body, k, a, WD["leg"] * 0.45)
        boots.box((WD["leg"] * 0.95, WD["leg"] * 1.6, LN["foot"]), Matrix.Translation(a + Vector((0, -0.18, -LN["foot"] / 2 + 0.05))), bev=0.12)
        sh = neck + lean.to_3x3() @ Vector((s * (WD["torso"] / 2 + 0.2), 0, -0.25))
        if seated:   # forearms rest on the thighs, hands clasped between the knees
            el = sh + Vector((s * 0.15, -0.35, -0.9))
            wr = Vector((s * 0.2, -0.85, 0.5))
        else:
            el = sh + Vector((s * 0.1, 0.05, -LN["upperarm"]))
            wr = el + Vector((0, -0.08, -LN["lowerarm"]))
        capsule(body, sh, el, WD["arm"] / 2)
        capsule(body, el, wr, WD["arm"] * 0.44)
        hands.box((0.3, 0.38, 0.42), Matrix.Translation(wr + (wr - el).normalized() * 0.25), bev=0.1)
    objs = [body.make("Body", "HideLeather", smooth=True, uv=False), head.make("Head", "HideLeather", smooth=True, uv=False),
            boots.make("Boots", "HideLeather", uv=False), hands.make("Hands", "Polymer", uv=False)]
    for o in objs:
        o.matrix_world = at @ o.matrix_world
    return objs, at @ ut

def poncho_mesh(seg=64, rings=26, r_neck=0.6, r_out=3.9):
    """A closed circular poncho (a flat ring) and its pinned neck ring; laid flat at z 0 around the origin."""
    bm = bmesh.new()
    grid = []
    for k in range(rings + 1):
        u = k / rings
        r = r_neck + (r_out - r_neck) * (u ** 1.1)
        row = []
        for i in range(seg):
            a = 2 * math.pi * i / seg
            ry = r * (1.0 if math.sin(a) < 0 else 0.92)     # a little shorter at the back
            row.append(bm.verts.new((r * math.cos(a), ry * math.sin(a), 0)))
        grid.append(row)
    for k in range(rings):
        for i in range(seg):
            j = (i + 1) % seg
            bm.faces.new((grid[k][i], grid[k][j], grid[k + 1][j], grid[k + 1][i]))
    return bm, seg

def drape(seated):
    """Builds the rider and drops the poncho onto it with Blender's cloth solver; returns the cloth object
    expressed in the upper torso's frame (the game welds the cloak there), plus the hood."""
    reset()
    objs, ut = rider(seated)
    if seated:
        seatg = G()
        seatg.box((2.0, 1.6, 0.2), T(0, 0.15, -0.49))       # the cushion under the hips (the rider's hip joint at 0)
        seatg.box((2.0, 0.25, 2.4), T(0, 0.85, 0.8) @ RX(12))
        objs.append(seatg.make("SeatProxy", "SeatShell", uv=False))
    for o in objs:
        o.modifiers.new("Collision", "COLLISION")
        o.collision.thickness_outer = 0.06
        o.collision.cloth_friction = 8.0
    bm, seg = poncho_mesh()
    neck = ut @ Vector((0, 0, 0.75))
    me = bpy.data.meshes.new("Poncho")
    # lay it as a cone over the shoulders so it starts close to its rest shape
    for v in bm.verts:
        r = math.hypot(v.co.x, v.co.y)
        v.co.z = -max(0.0, r - 0.6) * 0.9
    bmesh.ops.transform(bm, matrix=Matrix.Translation(neck + Vector((0, 0, 0.12))) @ ut.to_3x3().to_4x4(), verts=bm.verts)
    bm.to_mesh(me)
    bm.free()
    cloth = bpy.data.objects.new("Poncho_Waxcloth", me)
    bpy.context.collection.objects.link(cloth)
    me.materials.append(mat("Waxcloth"))
    vg = cloth.vertex_groups.new(name="Pin")
    vg.add([i for i in range(seg)], 1.0, "REPLACE")
    mod = cloth.modifiers.new("Cloth", "CLOTH")
    st = mod.settings
    st.quality = 8
    st.mass = 0.4
    st.tension_stiffness = st.compression_stiffness = 25
    st.bending_stiffness = 0.6          # waxed canvas: stiffer than cotton, big folds
    st.air_damping = 1.0
    st.vertex_group_mass = "Pin"
    st.effector_weights.gravity = 1.0
    mod.collision_settings.use_self_collision = True
    mod.collision_settings.distance_min = 0.035
    mod.collision_settings.self_distance_min = 0.03
    scene = bpy.context.scene
    scene.frame_start, scene.frame_end = 1, 110
    mod.point_cache.frame_start, mod.point_cache.frame_end = 1, 110
    scene.gravity = (0, 0, -9.8)
    for f in range(1, 111):
        scene.frame_set(f)
    dg = bpy.context.evaluated_depsgraph_get()
    ev = cloth.evaluated_get(dg)
    baked = bpy.data.meshes.new_from_object(ev)
    out = bpy.data.objects.new("PonchoBaked", baked)
    bpy.context.collection.objects.link(out)
    out.matrix_world = cloth.matrix_world.copy()
    bpy.data.objects.remove(cloth)
    for o in [o for o in objs if o.name.startswith("SeatProxy")]:
        bpy.data.objects.remove(o)
        objs.remove(o)
    return out, objs, ut

def make_hood(seated):
    """A deep cowl over the head, open at the face, the brow pulled forward and down (in the torso's frame)."""
    hood = G()
    hd = RX(-10 if seated else 0)
    tmp = bmesh.new()
    bmesh.ops.create_uvsphere(tmp, u_segments=28, v_segments=16, radius=1.0)
    cut = []
    for v in tmp.verts:
        x, y, z = v.co
        if y < -0.6 and z > -0.65 and z < 0.3 and abs(x) < 0.55:   # the face opening
            cut.append(v)
        elif z < -0.55 and y < 0.2:                          # under the chin
            cut.append(v)
    bmesh.ops.delete(tmp, geom=cut, context="VERTS")
    for v in tmp.verts:
        x, y, z = v.co
        if y < 0 and z > 0.1:                                # the brow peak overhangs the face
            v.co.y -= 0.45 * (z - 0.1) * (-y)
            v.co.z -= 0.12 * (z - 0.1) * (-y)
        if abs(x) > 0.5 and y < -0.3:                        # the sides close round the cheeks
            v.co.y -= 0.12
        if y > 0.3:                                          # the cowl falls back behind the head
            v.co.z -= 0.25 * (y - 0.3) * (1 - z) * 0.5
    bmesh.ops.transform(tmp, matrix=hd @ T(0, 0.08, 1.42) @ S(0.86, 1.02, 0.98), verts=tmp.verts)
    hood._take(tmp)
    ob = hood.make("Hood", "Waxcloth", smooth=True, uv=False)
    uv_cyl(ob, TILE["Waxcloth"], 0.9)
    return ob

# The live cloak (2026-11-11, Andy: "There should be a cloth physics simulation on the cloak. that way it conforms
# over the character and what he carries"). One skinned mesh: the poncho as it hangs from a standing body, plus the
# hood, bound to a grid of bones that src/client/Cloth.lua moves as cloth particles every frame. Bones "R<row>C<col>":
# row 0 is the neck ring (pinned to the torso), rows 1-4 lie on rings ROWS[1..4] of the poncho; columns every
# COL_STEP segments round it. "Hood" carries the hood and stays with the torso. Bones have no parents, so the client
# can move each one on its own.
ROWS = (0, 6, 12, 19, 26)
COL_STEP = 4

def build_cloak():
    seg = 64
    cols = seg // COL_STEP
    cloth, body, ut = drape(False)
    inv = ut.inverted()
    cloth.data.transform(inv @ cloth.matrix_world)
    cloth.matrix_world = Matrix.Identity(4)
    bm = bmesh.new()
    bm.from_mesh(cloth.data)
    bmesh.ops.smooth_vert(bm, verts=bm.verts, factor=0.35, use_axis_x=True, use_axis_y=True, use_axis_z=True)
    bm.to_mesh(cloth.data)
    bm.free()
    co = [v.co.copy() for v in cloth.data.vertices]          # vertex k*seg + i = ring k, segment i
    cloth.name = "Cloak_Waxcloth"
    # weights: bilinear between the two bone rows and the two bone columns around each vertex
    groups = {}
    def vg(name):
        if name not in groups:
            groups[name] = cloth.vertex_groups.new(name=name)
        return groups[name]
    for r in range(len(ROWS)):
        for c in range(cols):
            vg(f"R{r}C{c}")
    for k in range(ROWS[-1] + 1):
        a = max(j for j in range(len(ROWS)) if ROWS[j] <= k)
        a = min(a, len(ROWS) - 2)
        t = (k - ROWS[a]) / (ROWS[a + 1] - ROWS[a])
        for i in range(seg):
            c0 = i // COL_STEP
            u = (i % COL_STEP) / COL_STEP
            c1 = (c0 + 1) % cols
            idx = k * seg + i
            for (rr, cc, w) in ((a, c0, (1 - t) * (1 - u)), (a, c1, (1 - t) * u), (a + 1, c0, t * (1 - u)), (a + 1, c1, t * u)):
                if w > 1e-4:
                    vg(f"R{rr}C{cc}").add([idx], w, "ADD")
    sol = cloth.modifiers.new("Solid", "SOLIDIFY")
    sol.thickness, sol.offset = 0.05, 1.0
    apply_mods(cloth)
    for p in cloth.data.polygons:
        p.use_smooth = True
    uv_cyl(cloth, TILE["Waxcloth"], 1.6)
    hood = make_hood(False)
    sh = hood.modifiers.new("Solid", "SOLIDIFY")
    sh.thickness = 0.04
    apply_mods(hood)
    hood.vertex_groups.new(name="Hood").add(list(range(len(hood.data.vertices))), 1.0, "REPLACE")
    bpy.ops.object.select_all(action="DESELECT")
    hood.select_set(True)
    cloth.select_set(True)
    bpy.context.view_layer.objects.active = cloth
    bpy.ops.object.join()
    cloth.name = "Cloak_Waxcloth"
    # the bones: heads where their vertex sits on the draped poncho, tails a short way down
    arm_data = bpy.data.armatures.new("CloakRig")
    arm = bpy.data.objects.new("CloakRig", arm_data)
    bpy.context.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for r, k in enumerate(ROWS):
        for c in range(cols):
            p = co[k * seg + c * COL_STEP]
            b = arm_data.edit_bones.new(f"R{r}C{c}")
            b.head, b.tail = p, p + Vector((0, 0, -0.25))
    b = arm_data.edit_bones.new("Hood")
    b.head, b.tail = Vector((0, 0.08, 1.42)), Vector((0, 0.08, 1.9))
    bpy.ops.object.mode_set(mode="OBJECT")
    cloth.parent = arm
    mod = cloth.modifiers.new("Rig", "ARMATURE")
    mod.object = arm
    n = tris([cloth])
    assert n < 20000, n
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    cloth.select_set(True)
    arm.select_set(True)
    bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, "Intro_Cloak.fbx"), use_selection=True, apply_unit_scale=True,
        global_scale=0.01, bake_space_transform=False, axis_forward="-Z", axis_up="Y", object_types={"MESH", "ARMATURE"},
        add_leaf_bones=False, use_armature_deform_only=True, mesh_smooth_type="FACE")
    print("BUILT Intro_Cloak", len(arm_data.bones), "bones", n, "tris")
    for o in body:
        o.data.transform(inv)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "Intro_Cloak_scene.blend"))

if __name__ == "__main__":
    if "car" in WANT:
        build_car()
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "Subway_Car_scene.blend"))
    if "door" in WANT:
        build_door()
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "Subway_Door_scene.blend"))
    if "pistol" in WANT:
        build_pistol()
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "Wpn_Whisper_scene.blend"))
    if "cloak" in WANT:
        build_cloak()
    print("TRAIN DONE")
