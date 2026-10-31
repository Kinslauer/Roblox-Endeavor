# GPU-free preview renderer: rasterizes an OBJ (with per-object material colours from the MTL)
# into a PNG with flat shading and a ground shadow. Usage: preview.py model.obj out.png
import sys, math, os
from PIL import Image, ImageDraw

def load(path):
    mats, cur, verts, faces = {}, (0.6, 0.6, 0.6), [], []
    mtl = os.path.splitext(path)[0] + ".mtl"
    if os.path.exists(mtl):
        name = None
        for line in open(mtl):
            t = line.split()
            if not t: continue
            if t[0] == "newmtl": name = t[1]
            elif t[0] == "Kd" and name: mats[name] = tuple(float(x) for x in t[1:4])
    for line in open(path):
        t = line.split()
        if not t: continue
        if t[0] == "v": verts.append(tuple(float(x) for x in t[1:4]))
        elif t[0] == "usemtl": cur = mats.get(t[1], cur)
        elif t[0] == "f":
            idx = [int(p.split("/")[0]) - 1 for p in t[1:]]
            for i in range(1, len(idx) - 1):
                faces.append((idx[0], idx[i], idx[i + 1], cur))
    return verts, faces

def render(obj, out, size=(900, 700), azimuth=0.9, elevation=0.28):
    verts, faces = load(obj)
    xs = [v[0] for v in verts]; ys = [v[1] for v in verts]; zs = [v[2] for v in verts]
    cx, cy, cz = (min(xs)+max(xs))/2, (min(ys)+max(ys))/2, (min(zs)+max(zs))/2
    extent = max(max(xs)-min(xs), max(ys)-min(ys), max(zs)-min(zs)) or 1
    # camera: OBJ from Blender is Y-up here (exporter set so). look at center from azimuth/elevation
    cam = (cx + math.cos(azimuth) * extent * 1.7, cy + extent * elevation * 1.7 + (max(ys)-cy) * 0.3, cz + math.sin(azimuth) * extent * 1.7)
    fwd = (cx - cam[0], cy - cam[1], cz - cam[2]); fl = math.sqrt(sum(a*a for a in fwd)); fwd = tuple(a/fl for a in fwd)
    up = (0, 1, 0)
    right = (fwd[1]*up[2]-fwd[2]*up[1], fwd[2]*up[0]-fwd[0]*up[2], fwd[0]*up[1]-fwd[1]*up[0]); rl = math.sqrt(sum(a*a for a in right)); right = tuple(a/rl for a in right)
    cup = (right[1]*fwd[2]-right[2]*fwd[1], right[2]*fwd[0]-right[0]*fwd[2], right[0]*fwd[1]-right[1]*fwd[0])
    W, H = size; f = 1.4 * H
    def project(v):
        d = (v[0]-cam[0], v[1]-cam[1], v[2]-cam[2])
        x = sum(a*b for a, b in zip(d, right)); y = sum(a*b for a, b in zip(d, cup)); z = sum(a*b for a, b in zip(d, fwd))
        if z < 0.05: z = 0.05
        return (W/2 + f * x / z, H/2 - f * y / z, z)
    light = (0.4, 0.8, 0.45); ll = math.sqrt(sum(a*a for a in light)); light = tuple(a/ll for a in light)
    img = Image.new("RGB", size, (26, 28, 34)); d = ImageDraw.Draw(img)
    # ground shadow: project faces flattened to the floor plane
    floor = min(ys)
    tris = []
    for a, b, c, col in faces:
        va, vb, vc = verts[a], verts[b], verts[c]
        n = ((vb[1]-va[1])*(vc[2]-va[2])-(vb[2]-va[2])*(vc[1]-va[1]), (vb[2]-va[2])*(vc[0]-va[0])-(vb[0]-va[0])*(vc[2]-va[2]), (vb[0]-va[0])*(vc[1]-va[1])-(vb[1]-va[1])*(vc[0]-va[0]))
        nl = math.sqrt(sum(x*x for x in n)) or 1; n = tuple(x/nl for x in n)
        shade = 0.35 + 0.65 * max(0, sum(x*y for x, y in zip(n, light)))
        pa, pb, pc = project(va), project(vb), project(vc)
        depth = (pa[2]+pb[2]+pc[2])/3
        tris.append((depth, [(pa[0], pa[1]), (pb[0], pb[1]), (pc[0], pc[1])], tuple(int(255*min(1, c*shade)) for c in col)))
        sa, sb, sc = project((va[0], floor, va[2])), project((vb[0], floor, vb[2])), project((vc[0], floor, vc[2]))
        d.polygon([(sa[0], sa[1]), (sb[0], sb[1]), (sc[0], sc[1])], fill=(16, 17, 21))
    tris.sort(key=lambda t: -t[0])
    for _, pts, col in tris:
        d.polygon(pts, fill=col)
    d.text((10, H - 22), os.path.basename(obj) + "  (software preview, flat shading)", fill=(150, 150, 160))
    img.save(out)
    print("wrote", out, "faces", len(faces))

if __name__ == "__main__":
    render(sys.argv[1], sys.argv[2])
