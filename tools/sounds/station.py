# The arrival's sounds: the train, the cloak, takedowns, sparks, a whistle, the suppressed shot.
# Run: python3 station.py -> out/*.ogg (uses synth.py's helpers without re-making its sounds).
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

# the car at speed: a low body rumble, wheel clacks in pairs over the rail joints, a faint motor whine
def train_loop(sec=9.6):
    tt = t(sec)
    rumble = lowpass(noise(sec), 110) * 2.2 * (0.8 + 0.2 * np.sin(2 * np.pi * 0.7 * tt)) + tone(sec, 46) * 0.25 + tone(sec, 92) * 0.1
    hiss = bandpass(noise(sec), 700, 2600) * 0.05 * (0.7 + 0.3 * np.sin(2 * np.pi * 0.31 * tt))
    whine = tone(sec, 410) * 0.02 + tone(sec, 618) * 0.012
    clacks = np.zeros(len(tt))
    k = 0.0
    while k < sec - 0.5:
        for off in (0.0, 0.17):
            c = mix(E(lowpass(noise(0.07), 1600), a=0.001, d=0.06), E(tone(0.09, 150, 80), a=0.001, d=0.08) * 0.9) * 0.55
            i = int((k + off) * SR)
            clacks[i:i + len(c)] += c[: len(clacks) - i]
        k += 1.2
    return loopable(rumble + hiss + whine + clacks, 1.0)
save("train_loop", train_loop())
# brakes: a steel squeal that falls and stutters, air let go at the end
def train_brake(sec=3.6):
    tt = t(sec)
    wob = 1 + 0.012 * np.sin(2 * np.pi * 7 * tt)
    def squeal(f0, f1):
        ph = 2 * np.pi * np.cumsum(np.linspace(f0, f1, len(tt)) * wob) / SR
        return np.sin(ph)
    sq = (squeal(2900, 2100) * 0.5 + squeal(4350, 3200) * 0.25 + squeal(1450, 1050) * 0.2) * env(len(tt), a=0.5, d=2.4, s=0.0, r=0.1)
    grind = bandpass(noise(sec), 300, 1800) * 0.35 * env(len(tt), a=0.3, d=2.8, s=0.0, r=0.1)
    air = at(2.7, E(highpass(noise(0.8), 2500), a=0.02, d=0.75) * 0.5)
    thump = at(2.6, E(tone(0.3, 70, 40), a=0.002, d=0.28) * 0.7)
    return mix(sq, grind, air, thump)
save("train_brake", train_brake())
# heavy cloth pulled off and thrown: a whoosh with a flutter in it
x = whoosh(0.7, 180, 1500, 0.3)
save("cloak_whoosh", mix(x * (0.65 + 0.35 * np.sin(2 * np.pi * 21 * t(0.7))), at(0.1, E(lowpass(noise(0.3), 500), a=0.03, d=0.25) * 0.5)))
# a takedown: a grab, a muffled blow, the body let down
save("takedown", mix(E(bandpass(noise(0.12), 400, 2200), a=0.01, d=0.1) * 0.35, at(0.14, E(lowpass(noise(0.16), 420), a=0.002, d=0.14)), at(0.14, E(tone(0.14, 110, 55), a=0.001, d=0.12) * 0.8),
                     at(0.4, E(lowpass(noise(0.35), 700), a=0.05, d=0.28) * 0.3)))
# a fuse box or the live rail: a hard buzz with crackle
def sparks(sec=0.9):
    tt = t(sec)
    buzz = np.sign(np.sin(2 * np.pi * 100 * tt)) * 0.35 * (np.sin(2 * np.pi * 13 * tt) > -0.3)
    gate = (rng.uniform(0, 1, len(tt)) > 0.985).astype(float)
    crack = highpass(np.convolve(gate, np.exp(-np.arange(400) / 60.0), mode="same") * noise(sec), 2200) * 1.4
    return (lowpass(buzz, 3000) + crack) * env(len(tt), a=0.002, d=0.55, s=0.3, r=0.3)
save("sparks", sparks())
# two notes through the teeth
def whistle():
    a = E(tone(0.16, 2050, 2500), a=0.02, d=0.13, s=0.6, r=0.02)
    b = E(tone(0.24, 2500, 1900), a=0.02, d=0.2, s=0.4, r=0.03)
    w = np.concatenate([a, np.zeros(int(0.03 * SR)), b])
    return w + bandpass(noise(len(w) / SR), 1800, 4200)[: len(w)] * 0.12 * (np.abs(w) > 0.01)
save("whistle", whistle())
# the Whisper: the action cycling is louder than the round
save("shot_quiet", mix(E(lowpass(noise(0.14), 900), a=0.001, d=0.12) * 0.9, E(tone(0.1, 190, 90), a=0.001, d=0.09) * 0.6, E(bandpass(noise(0.2), 1200, 4200), a=0.004, d=0.18) * 0.25,
                       at(0.045, E(tone(0.03, 1500, 900), a=0.0005, d=0.025) * 0.5), at(0.05, E(highpass(noise(0.025), 3000), a=0.0005, d=0.02) * 0.45)))
print("STATION SOUNDS DONE")
