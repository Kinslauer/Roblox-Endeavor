# The game's material library: tileable PBR texture sets (colour, normal, roughness, metalness), all made here
# from seeded noise so every model in the game shares one look. Run: python3 tools/textures/gen.py [Name ...]
# -> tools/textures/out/<Name>_{col,nrm,rgh,mtl}.png. Every texture tiles (all noise is periodic: FFT-filtered).
#
# How they reach the game: tools/textures/swatches.py (Blender) builds one small plane per material with these maps
# and uploads it as a Model; the FBX import turns the maps into a SurfaceAppearance, which server/SurfaceLibrary.lua
# copies into ReplicatedStorage.Surfaces at startup; Assets.Dress clones it onto every MeshPart whose name ends in
# that material ("Seat_Moquette"). Models get their UVs from tools/models/lib.py uv_box (world-scale box mapping),
# so a texture repeats every `Tile` studs (Assets.Surfaces[name].Tile, also used by Blender for the UVs).
#
# Normal maps are OpenGL style (+Y up), which is what Roblox and Blender both read.
import os, sys, math
import numpy as np
from PIL import Image

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")
N = 1024

def rng(seed):
    return np.random.default_rng(seed)

def band(seed, lo, hi, n=N):
    """Periodic noise with features between `lo` and `hi` pixels across, normalised to 0..1."""
    r = rng(seed)
    f = np.fft.fftfreq(n)
    fx, fy = np.meshgrid(f, f)
    k = np.sqrt(fx * fx + fy * fy) + 1e-9
    w = ((k > 1.0 / hi) & (k < 1.0 / lo)).astype(float) / k
    spec = np.fft.fft2(r.standard_normal((n, n))) * w
    a = np.real(np.fft.ifft2(spec))
    a -= a.min()
    return a / (a.max() + 1e-9)

def fbm(seed, coarse=256, octaves=5, n=N, gain=0.55):
    out, amp, total, size = np.zeros((n, n)), 1.0, 0.0, coarse
    for o in range(octaves):
        out += amp * band(seed + o * 7, size / 2, size, n)
        total += amp
        amp *= gain
        size /= 2
    return out / total

def stretched(seed, lo, hi, sx=1.0, sy=12.0, n=N):
    """Anisotropic periodic noise: streaks along X when sy > sx (brushed metal, rain streaks)."""
    r = rng(seed)
    f = np.fft.fftfreq(n)
    fx, fy = np.meshgrid(f, f)
    k = np.sqrt((fx * sx) ** 2 + (fy * sy) ** 2) + 1e-9
    w = ((k > 1.0 / hi) & (k < 1.0 / lo)).astype(float) / k
    a = np.real(np.fft.ifft2(np.fft.fft2(r.standard_normal((n, n))) * w))
    a -= a.min()
    return a / (a.max() + 1e-9)

def smooth(a, radius):
    """Periodic gaussian blur."""
    n = a.shape[0]
    f = np.fft.fftfreq(n)
    fx, fy = np.meshgrid(f, f)
    g = np.exp(-(fx * fx + fy * fy) * (2 * math.pi * radius) ** 2 / 2)
    return np.real(np.fft.ifft2(np.fft.fft2(a) * g))

def scratches(seed, count, length=(20, 160), width=1.0, n=N, angle=None, spread=math.pi):
    """Thin random line segments (wrapping), 0..1."""
    r = rng(seed)
    a = np.zeros((n, n))
    for _ in range(count):
        x, y = r.uniform(0, n, 2)
        ang = (angle if angle is not None else r.uniform(0, math.pi)) + r.uniform(-spread, spread) * 0.5 * (angle is not None)
        ln = r.uniform(*length)
        steps = int(ln * 1.5)
        t = np.linspace(0, ln, steps)
        bend = r.uniform(-0.002, 0.002)
        xs = (x + np.cos(ang + bend * t) * t).astype(int) % n
        ys = (y + np.sin(ang + bend * t) * t).astype(int) % n
        a[ys, xs] = np.maximum(a[ys, xs], r.uniform(0.4, 1.0))
    if width > 1:
        a = np.clip(smooth(a, width * 0.5) * width * 2.5, 0, 1)
    return a

def spots(seed, count, radius=(2, 10), n=N):
    """Round soft dots (wrapping), 0..1; stamped locally so thousands stay cheap."""
    r = rng(seed)
    a = np.zeros((n, n))
    for _ in range(count):
        x, y = r.uniform(0, n, 2)
        rad = r.uniform(*radius)
        k = int(math.ceil(rad)) + 1
        ys = np.arange(int(y) - k, int(y) + k + 1)
        xs = np.arange(int(x) - k, int(x) + k + 1)
        dy, dx = np.meshgrid(ys - y, xs - x, indexing="ij")
        d = np.clip(1 - np.sqrt(dx * dx + dy * dy) / rad, 0, 1)
        iy, ix = np.ix_(ys % n, xs % n)
        a[iy, ix] = np.maximum(a[iy, ix], d)
    return a

def normal_from(height, strength):
    gy, gx = np.gradient(height)
    # wrap the edges so the normal map tiles too
    gx[:, 0] = (height[:, 1] - height[:, -1]) / 2
    gx[:, -1] = (height[:, 0] - height[:, -2]) / 2
    gy[0, :] = (height[1, :] - height[-1, :]) / 2
    gy[-1, :] = (height[0, :] - height[-2, :]) / 2
    nx, ny, nz = -gx * strength, gy * strength, np.ones_like(height)  # OpenGL: +Y up (image rows go down)
    l = np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.stack([nx / l, ny / l, nz / l], -1) * 0.5 + 0.5

def mix(a, b, t):
    t = np.asarray(t)[..., None] if np.ndim(t) == 2 else t
    return np.asarray(a) * (1 - t) + np.asarray(b) * t

def rgb(c, n=N):
    return np.broadcast_to(np.array(c, float), (n, n, 3)).copy()

def save(name, col, height, strength, rough, metal):
    os.makedirs(OUT, exist_ok=True)
    def img(a, path, mode):
        a = np.clip(a, 0, 1)
        Image.fromarray((a * 255 + 0.5).astype(np.uint8), mode).save(os.path.join(OUT, path))
    srgb = np.where(col <= 0.0031308, col * 12.92, 1.055 * np.power(np.clip(col, 0, 1), 1 / 2.4) - 0.055)  # linear -> sRGB
    img(srgb, f"{name}_col.png", "RGB")
    img(normal_from(height, strength), f"{name}_nrm.png", "RGB")
    img(np.broadcast_to(rough, col.shape[:2]), f"{name}_rgh.png", "L")
    img(np.broadcast_to(metal, col.shape[:2]), f"{name}_mtl.png", "L")
    print("TEXTURE", name)

# ---------- the materials (colours are linear) ----------
def CarBody():
    """Painted steel, the train's skin: a dull warm grey with grime settling in streaks, chips down to bare metal."""
    grime = fbm(11, 512) * 0.6 + stretched(12, 8, 400, 1, 10) * 0.4
    chips = (spots(13, 90, (1.5, 6)) > 0.35) * (band(14, 40, 200) > 0.55)
    scr = scratches(15, 260, (10, 90))
    paint = rgb((0.30, 0.31, 0.30)) * (0.85 + 0.25 * fbm(16, 128)[..., None])
    col = mix(paint, rgb((0.10, 0.09, 0.08)), np.clip(grime - 0.45, 0, 1) * 1.4)
    bare = rgb((0.42, 0.42, 0.43))
    wear = np.clip(chips + scr * 0.8, 0, 1)
    col = mix(col, bare, wear)
    height = fbm(17, 64, 3) * 0.4 - wear * 0.8
    rough = 0.48 + grime * 0.25 - wear * 0.2
    return col, height, 2.0, rough, wear * 0.9

def CarPanel():
    """The cabin's laminate wall panels: a pale grey-green with fine fleck, hand smudges and old tape marks."""
    fleck = band(21, 1, 3)
    smudge = fbm(22, 300)
    tape = (band(23, 60, 300) > 0.82).astype(float)
    base = rgb((0.42, 0.44, 0.40)) * (0.94 + 0.08 * fleck[..., None])
    col = mix(base, rgb((0.20, 0.19, 0.16)), np.clip(smudge - 0.55, 0, 1) * 1.6)
    col = mix(col, rgb((0.36, 0.33, 0.24)), tape * 0.35)
    scr = scratches(24, 120, (8, 50))
    col = mix(col, rgb((0.55, 0.57, 0.54)), scr * 0.4)
    height = fleck * 0.15 - scr * 0.4
    rough = 0.55 + smudge * 0.15 - tape * 0.1
    return col, height, 1.5, rough, 0.0

def CarFloor():
    """Studded rubber flooring, worn smooth and dusty along the walkway."""
    n = N
    yy, xx = np.mgrid[0:n, 0:n]
    cell = 64
    cx = (xx % cell) - cell / 2
    cy = (yy % cell) - cell / 2
    d = np.sqrt(cx * cx + cy * cy)
    stud = np.clip((20 - d) / 3, 0, 1)
    wear = fbm(31, 400)
    dust = np.clip(fbm(32, 200) - 0.4, 0, 1)
    col = rgb((0.035, 0.037, 0.04)) * (0.8 + 0.4 * band(33, 2, 8)[..., None]) * (1 + 0.5 * stud[..., None])
    col = mix(col, rgb((0.11, 0.10, 0.09)), dust * 1.2 * (1 - stud))
    col = mix(col, rgb((0.07, 0.07, 0.07)), stud * wear * 0.6)
    height = stud * (1 - wear * 0.4) + band(34, 1, 4) * 0.05
    rough = 0.75 - stud * wear * 0.3 + dust * 0.2
    return col, height, 6.0, rough, 0.0

def Moquette():
    """Transit seat fabric: a dense wool weave in deep blue with a stepped amber-and-teal pattern, faded and pilled."""
    n = N
    yy, xx = np.mgrid[0:n, 0:n]
    weave = (np.sin(xx * math.pi / 2) * np.sin(yy * math.pi / 2)) * 0.5 + 0.5
    u, v = (xx % 128) / 128, (yy % 128) / 128
    diamond = np.abs(u - 0.5) + np.abs(v - 0.5)
    ring = np.floor(diamond * 10)
    line = (np.abs(diamond * 10 - ring - 0.5) > 0.36)
    dots = ((xx // 8 + yy // 8) % 2 == 0) & (diamond < 0.18)
    pat = np.where(line & (ring % 3 == 0), 2, np.where(line | dots, 1, 0))
    c0, c1, c2 = np.array((0.018, 0.024, 0.06)), np.array((0.02, 0.07, 0.075)), np.array((0.16, 0.09, 0.025))
    col = np.select([pat[..., None] == 0, pat[..., None] == 1], [rgb(c0), rgb(c1)], rgb(c2))
    fade = fbm(41, 300)
    col = mix(col, rgb((0.10, 0.10, 0.11)), np.clip(fade - 0.5, 0, 1) * 0.9)
    pill = band(42, 1, 3)
    col *= (0.75 + 0.45 * weave * (0.7 + 0.3 * pill))[..., None]
    height = weave * 0.6 + pill * 0.3
    return col, height, 3.0, 0.92, 0.0

def SeatShell():
    """The moulded seat shells: glass-fibre in a dark slate, glossy where it is untouched, scuffed matt on the edges."""
    scuff = np.clip(fbm(51, 200) - 0.5, 0, 1) * 2
    scr = scratches(52, 400, (6, 40))
    col = rgb((0.05, 0.06, 0.07)) * (0.9 + 0.2 * band(53, 2, 6)[..., None])
    col = mix(col, rgb((0.13, 0.13, 0.13)), np.clip(scuff * 0.5 + scr * 0.6, 0, 1))
    height = band(54, 30, 200) * 0.2 - scr * 0.5
    rough = 0.28 + scuff * 0.35 + scr * 0.3
    return col, height, 2.0, rough, 0.0

def Stainless():
    """Brushed stainless for the grab poles and handrails: streaks along the tube, hand-polished in places."""
    brush = stretched(61, 1, 30, 1, 30)
    polish = fbm(62, 300)
    col = rgb((0.55, 0.56, 0.57)) * (0.85 + 0.25 * brush[..., None])
    col = mix(col, rgb((0.32, 0.31, 0.30)), np.clip(0.45 - polish, 0, 1) * 1.2)
    height = brush * 0.3
    rough = 0.32 + (1 - polish) * 0.18 - brush * 0.08
    return col, height, 1.0, rough, 1.0

def Underframe():
    """Bogies, couplers and everything under the floor: black steel under oily dust, rust bleeding at the seams."""
    rust = np.clip(fbm(71, 300) - 0.55, 0, 1) * 2.5
    oil = np.clip(fbm(72, 150) - 0.5, 0, 1) * 2
    col = rgb((0.04, 0.04, 0.04)) * (0.8 + 0.4 * band(73, 2, 10)[..., None])
    col = mix(col, rgb((0.18, 0.07, 0.025)), np.clip(rust, 0, 1))
    col = mix(col, rgb((0.11, 0.10, 0.08)), np.clip(fbm(74, 60) - 0.5, 0, 1) * 1.5)
    height = fbm(75, 80) * 0.5 + rust * 0.5
    rough = 0.6 + rust * 0.3 - oil * 0.35
    metal = np.clip(0.6 - rust * 0.8, 0, 1)
    return col, height, 3.0, rough, metal

def Gunmetal():
    """Phosphate-finished steel for the pistol's slide and barrel: dark grey-black, worn bright on the high edges."""
    grain = band(81, 1, 3)
    wear = np.clip(scratches(82, 220, (5, 40)) + (fbm(83, 120) > 0.72) * 0.4, 0, 1)
    col = rgb((0.04, 0.042, 0.045)) * (0.85 + 0.3 * grain[..., None])
    col = mix(col, rgb((0.30, 0.30, 0.31)), wear * 0.6)
    height = grain * 0.2 - wear * 0.3
    rough = 0.5 - wear * 0.2 + grain * 0.1
    return col, height, 1.5, rough, 0.75 + wear * 0.25

def Polymer():
    """The pistol frame and grip: black polymer, stippled, gone grey and shiny where the hand sits."""
    stip = spots(91, 26000, (1.2, 2.6))
    shine = fbm(92, 300)
    col = rgb((0.022, 0.022, 0.024)) * (0.85 + 0.3 * stip[..., None])
    col = mix(col, rgb((0.06, 0.06, 0.065)), np.clip(shine - 0.5, 0, 1))
    height = stip
    rough = 0.72 - stip * 0.1 - np.clip(shine - 0.5, 0, 1) * 0.3
    return col, height, 4.0, rough, 0.0

def Waxcloth():
    """The rider's poncho: waxed cotton in a near-black olive, a tight twill, waxy sheen in the creases, salt and dust."""
    n = N
    yy, xx = np.mgrid[0:n, 0:n]
    twill = np.sin((xx + yy) * math.pi / 3) * 0.5 + 0.5
    thread = band(101, 1, 2)
    mottle = fbm(102, 200)
    dust = np.clip(fbm(103, 400) - 0.55, 0, 1) * 2
    col = rgb((0.035, 0.038, 0.030)) * (0.8 + 0.3 * mottle[..., None] + 0.15 * twill[..., None])
    col = mix(col, rgb((0.13, 0.12, 0.10)), dust * 0.7)
    height = twill * 0.5 + thread * 0.4 + mottle * 0.4
    rough = 0.55 + dust * 0.3 - (mottle > 0.6) * 0.18 + thread * 0.1
    return col, height, 3.0, rough, 0.0

def HideLeather():
    """Straps, holster and the hood's binding: brown-black leather, grained, cracked and lighter where it bends."""
    grain = 1 - np.clip(np.abs(band(111, 4, 16) - 0.5) * 8, 0, 1)
    crack = np.clip(1 - np.abs(band(112, 20, 80) - 0.5) * 30, 0, 1)
    col = rgb((0.05, 0.03, 0.02)) * (0.8 + 0.4 * fbm(113, 150)[..., None])
    col = mix(col, rgb((0.14, 0.09, 0.05)), crack * 0.6)
    height = -grain * 0.4 - crack * 0.6
    rough = 0.55 + grain * 0.15 + crack * 0.2
    return col, height, 3.0, rough, 0.0

def CarTrim():
    """Black powder-coated steel for door frames, window posts and fittings: faintly orange-peel, chipped at the edges."""
    peel = band(121, 3, 12)
    chips = (spots(122, 70, (1, 4)) > 0.4).astype(float)
    col = rgb((0.022, 0.024, 0.026)) * (0.9 + 0.2 * peel[..., None])
    col = mix(col, rgb((0.35, 0.35, 0.36)), chips)
    height = peel * 0.2 - chips
    rough = 0.42 + peel * 0.1 - chips * 0.1
    return col, height, 1.5, rough, chips

def CarLivery():
    """The line colour on the train's flanks: the same worn paint as CarBody, in a faded signal red."""
    col, height, strength, rough, metal = CarBody()
    tint = np.array((0.30, 0.045, 0.03)) / np.array((0.30, 0.31, 0.30))
    col = col * tint * 0.9 + col * 0.1
    return col, height, strength, rough, metal

# ---- characters (tools/models/figure.py). The fabrics and the plate are pale and neutral on purpose: the game tints
# them per character (SurfaceAppearance.Color multiplies the colour map), so one texture dresses everybody.
def Techcloth():
    """Jackets and coats: a tight synthetic plain weave, rubbed paler on the high spots."""
    n = N
    yy, xx = np.mgrid[0:n, 0:n]
    weave = (np.sin(xx * math.pi / 2) * np.sin(yy * math.pi / 2)) * 0.5 + 0.5
    rip = np.maximum((xx % 16 < 2), (yy % 16 < 2)).astype(float)
    mottle = fbm(131, 300)
    rub = np.clip(fbm(132, 180) - 0.58, 0, 1) * 2.2
    col = rgb((0.42, 0.42, 0.42)) * (0.82 + 0.22 * mottle[..., None] + 0.08 * weave[..., None])
    col = mix(col, rgb((0.62, 0.62, 0.60)), rub * 0.5)
    height = weave * 0.4 + mottle * 0.6
    rough = 0.62 + weave * 0.08 - rub * 0.12
    return col, height, 2.6, rough, 0.0

def Twill(seed=141):
    """Trousers and undersleeves: heavy cotton twill, the diagonal rib plain to see, dusty in the folds."""
    n = N
    yy, xx = np.mgrid[0:n, 0:n]
    rib = np.sin((xx + yy) * math.pi / 4) * 0.5 + 0.5
    thread = band(seed, 1, 3)
    mottle = fbm(seed + 1, 260)
    dust = np.clip(fbm(seed + 2, 420) - 0.56, 0, 1) * 2
    col = rgb((0.36, 0.36, 0.37)) * (0.78 + 0.26 * mottle[..., None] + 0.14 * rib[..., None])
    col = mix(col, rgb((0.55, 0.52, 0.47)), dust * 0.55)
    height = rib * 0.6 + thread * 0.35 + mottle * 0.4
    rough = 0.74 + thread * 0.08 + dust * 0.1
    return col, height, 3.0, rough, 0.0

def Gauze():
    """Wrappings round forearms, fists and faces: overlapping bands of loose-woven cloth, stained."""
    n = N
    yy, xx = np.mgrid[0:n, 0:n]
    lean = (yy + xx * 0.125 + 14 * np.sin(xx * 2 * math.pi / n * 2)) % 128        # the wrap climbs a little as it goes round
    edge = np.clip(1 - lean / 14.0, 0, 1)                                           # shadowed overlap at each band's edge
    lift = np.clip(lean / 128.0, 0, 1)
    weave = (np.sin(xx * math.pi / 3) * np.sin(yy * math.pi / 3)) * 0.5 + 0.5
    stain = np.clip(fbm(151, 300) - 0.5, 0, 1) * 2
    col = rgb((0.50, 0.46, 0.38)) * (0.8 + 0.2 * weave[..., None] + 0.12 * lift[..., None])
    col = mix(col, rgb((0.20, 0.13, 0.08)), stain * 0.7)
    col = col * (1 - 0.55 * edge[..., None])
    height = lift * 0.9 + weave * 0.25 - edge * 0.6
    rough = 0.86 - stain * 0.1
    return col, height, 3.2, rough, 0.0

def PlateSteel():
    """Armour plate: steel under worn paint, chipped to bright metal along scratches and at knocks."""
    grain = band(161, 2, 6)
    wear = np.clip(scratches(162, 260, (10, 90), width=1.2) * 0.9 + (spots(163, 160, (2, 9)) > 0.35) * 0.9 + (fbm(164, 200) > 0.7) * 0.5, 0, 1)
    grime = np.clip(fbm(165, 380) - 0.5, 0, 1) * 2
    col = rgb((0.40, 0.40, 0.41)) * (0.85 + 0.25 * grain[..., None])
    col = mix(col, rgb((0.16, 0.14, 0.12)), grime * 0.6)
    col = mix(col, rgb((0.72, 0.72, 0.74)), wear * 0.85)
    height = grain * 0.2 - wear * 0.55
    rough = 0.55 + grime * 0.25 - wear * 0.25
    return col, height, 2.0, rough, wear * 0.9 + 0.1

MATERIALS = [CarBody, CarLivery, CarPanel, CarFloor, Moquette, SeatShell, Stainless, Underframe, Gunmetal, Polymer, Waxcloth, HideLeather, CarTrim,
             Techcloth, Twill, Gauze, PlateSteel]

if __name__ == "__main__":
    want = set(sys.argv[1:])
    for fn in MATERIALS:
        if want and fn.__name__ not in want:
            continue
        save(fn.__name__, *fn())
