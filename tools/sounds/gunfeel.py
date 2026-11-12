# The gun's hand sounds (CLAUDE.md "The gun in the hand"): each step of the hands has its own sound, and a loud shot
# has the city answering it. Run: python3 gunfeel.py -> out/*.ogg (uses synth.py's helpers without re-making its sounds).
import ast, os, numpy as np
HERE = os.path.dirname(os.path.abspath(__file__))
tree = ast.parse(open(os.path.join(HERE, "synth.py")).read())
tree.body = [n for n in tree.body if isinstance(n, (ast.Import, ast.ImportFrom, ast.FunctionDef, ast.Assign))]
ns = {"__file__": os.path.join(HERE, "synth.py")}
exec(compile(tree, "synth.py", "exec"), ns)
globals().update({k: v for k, v in ns.items() if not k.startswith("__")})
os.makedirs(OUT, exist_ok=True)
def at(sec, x): return np.concatenate([np.zeros(int(sec * SR)), x])
def E(x, **k): return x * env(len(x), **k)
# a struck piece of metal: a few inharmonic partials that ring and die
def ring(sec, f, partials=(1.0, 2.76, 5.4, 8.9), decay=0.08, amps=(1, 0.6, 0.35, 0.2)):
    tt = t(sec); out = np.zeros(len(tt))
    for p, a in zip(partials, amps):
        out += a * np.sin(2 * np.pi * f * p * tt) * np.exp(-tt / (decay / (0.6 + p * 0.25)))
    return out
def click(sec=0.012, lo=1800, hi=9000): return E(bandpass(noise(sec), lo, hi), a=0.0005, d=sec)
def scrape(sec, lo, hi): return E(bandpass(noise(sec), lo, hi), a=sec * 0.3, d=sec * 0.7) * (0.7 + 0.3 * np.sin(2 * np.pi * 60 * t(sec)))
# a spent case on concrete: a bright tink and a second smaller bounce
save("brass_tink", mix(ring(0.35, 3100, decay=0.11) * 0.8, click() * 0.6, at(0.09, ring(0.25, 3150, decay=0.07) * 0.35)))
# the magazine catch pressed and the magazine stripped down the well
save("mag_out", mix(click(0.01, 2500, 9000) * 0.9, at(0.012, E(tone(0.05, 900, 600), a=0.001, d=0.04) * 0.3), at(0.03, scrape(0.14, 1200, 5000) * 0.5)))
# a magazine slid up the well and driven home: a short scrape, then a hard clack with a ring under it
save("mag_in", mix(scrape(0.1, 1000, 4500) * 0.35, at(0.1, click(0.014, 1500, 8000) * 1.0), at(0.1, E(tone(0.08, 260, 180), a=0.001, d=0.07) * 0.6),
                   at(0.1, ring(0.18, 1900, decay=0.05) * 0.3)))
# the slide or the bolt drawn to the rear: a long steel scrape over a spring, a knock at its stop
save("slide_back", mix(scrape(0.16, 1500, 7000) * 0.55, E(tone(0.16, 420, 520), a=0.02, d=0.14) * 0.08, at(0.15, click(0.012, 1200, 6000) * 0.7),
                       at(0.15, E(tone(0.06, 210, 160), a=0.001, d=0.05) * 0.4)))
# and let go: it slams home
save("slide_home", mix(scrape(0.05, 2000, 8000) * 0.3, at(0.045, click(0.016, 1000, 9000) * 1.0), at(0.045, E(tone(0.09, 190, 120), a=0.001, d=0.08) * 0.7),
                       at(0.045, ring(0.22, 1450, decay=0.06) * 0.35)))
# the action cycling on a shot, heard close by the shooter under the report
save("action_cycle", mix(click(0.008, 2500, 10000) * 0.8, at(0.035, click(0.012, 1500, 8000) * 0.9), at(0.035, ring(0.12, 2300, decay=0.03) * 0.25)))
# a magazine hitting the floor: a hollow clatter
save("mag_drop", mix(E(lowpass(noise(0.08), 1400), a=0.001, d=0.07) * 0.8, ring(0.3, 700, partials=(1.0, 2.3, 3.9), decay=0.08, amps=(1, 0.5, 0.3)) * 0.5,
                     at(0.12, E(lowpass(noise(0.05), 1800), a=0.001, d=0.04) * 0.4), at(0.12, ring(0.15, 760, partials=(1.0, 2.3), decay=0.05, amps=(1, 0.4)) * 0.2)))
# the city answering a loud shot: the report thrown back off the towers, low, late and long
def shot_tail(sec=2.6):
    tt = t(sec)
    body = lowpass(noise(sec), 700) * np.exp(-tt / 0.65) * 1.2
    slap = np.zeros(len(tt))
    for d, g in ((0.11, 0.6), (0.23, 0.45), (0.41, 0.3), (0.66, 0.18)):
        x = E(lowpass(noise(0.12), 1500), a=0.002, d=0.11) * g
        i = int(d * SR); slap[i:i + len(x)] += x[: len(slap) - i]
    rumble = lowpass(noise(sec), 160) * np.exp(-tt / 1.1) * 1.4
    return (body + slap + rumble) * env(len(tt), a=0.04, d=sec - 0.1, s=0.0, r=0.05)
save("shot_tail", shot_tail())
