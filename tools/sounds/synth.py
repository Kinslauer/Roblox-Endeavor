# Procedural sound effects (numpy -> wav -> ogg via ffmpeg). No samples, no licences: every sound is
# noise, tones and envelopes shaped to read as what it is. Run: python3 synth.py -> out/*.ogg
import numpy as np, os, subprocess, wave
SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)

def t(sec): return np.arange(int(SR * sec)) / SR
def env(n, a=0.005, d=0.1, s=0.0, r=0.1, hold=0.0):
    """attack/decay/sustain/release envelope over n samples."""
    e = np.zeros(n); A, D, H, R = int(a * SR), int(d * SR), int(hold * SR), int(r * SR)
    i = 0
    e[i:i + A] = np.linspace(0, 1, A)[: n - i]; i += A
    e[i:i + D] = np.linspace(1, s, D)[: max(0, n - i)]; i += D
    e[i:i + H] = s; i += H
    e[i:i + R] = np.linspace(s, 0, R)[: max(0, n - i)]
    return e[:n]
def noise(sec): return rng.uniform(-1, 1, int(SR * sec))
def lowpass(x, cutoff):
    # one-pole IIR, cheap and good enough for whooshes and thuds
    rc = 1 / (2 * np.pi * cutoff); a = (1 / SR) / (rc + 1 / SR)
    y = np.zeros_like(x); acc = 0.0
    for i in range(len(x)):
        acc += a * (x[i] - acc); y[i] = acc
    return y
def highpass(x, cutoff): return x - lowpass(x, cutoff)
def bandpass(x, lo, hi): return highpass(lowpass(x, hi), lo)
def tone(sec, f0, f1=None, kind="sine"):
    tt = t(sec); f1 = f0 if f1 is None else f1
    ph = 2 * np.pi * np.cumsum(np.linspace(f0, f1, len(tt))) / SR
    return np.sin(ph) if kind == "sine" else np.sign(np.sin(ph)) * 0.6
def mix(*parts):
    n = max(len(p) for p in parts); out = np.zeros(n)
    for p in parts: out[: len(p)] += p
    return out
def norm(x, peak=0.9):
    m = np.max(np.abs(x)) or 1; return x / m * peak
def save(name, x):
    x = norm(x); path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes((x * 32767).astype(np.int16).tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", path, "-c:a", "libvorbis", "-q:a", "4", os.path.join(OUT, name + ".ogg")], check=True)
    os.remove(path); print("made", name)

# ---- Endeavor: melee
def whoosh(sec, lo, hi, swell=0.4):
    n = noise(sec); x = bandpass(n, lo, hi)
    e = env(len(x), a=sec * swell, d=sec * (1 - swell), s=0, r=0.01)
    return x * e
save("swing_light", whoosh(0.22, 600, 2500))
save("swing_heavy", mix(whoosh(0.4, 200, 1200, 0.5), lowpass(noise(0.4), 300) * env(int(0.4 * SR), 0.15, 0.2) * 0.5))
save("hit_flesh", mix(lowpass(noise(0.18), 500) * env(int(0.18 * SR), 0.002, 0.12), tone(0.12, 140, 60) * env(int(0.12 * SR), 0.001, 0.1) * 0.8))
save("hit_clang", mix(*[tone(0.35, f) * env(int(0.35 * SR), 0.001, 0.3) * a for f, a in ((2100, 0.5), (3350, 0.3), (5200, 0.2), (820, 0.4))], highpass(noise(0.05), 3000) * env(int(0.05 * SR), 0.001, 0.04)))
save("block_thud", mix(lowpass(noise(0.15), 900) * env(int(0.15 * SR), 0.002, 0.12), tone(0.1, 220, 120) * env(int(0.1 * SR), 0.001, 0.08) * 0.6))
save("guard_break", mix(tone(0.5, 180, 40) * env(int(0.5 * SR), 0.002, 0.45), bandpass(noise(0.3), 300, 3000) * env(int(0.3 * SR), 0.002, 0.25) * 0.7, tone(0.3, 1400, 700) * env(int(0.3 * SR), 0.001, 0.25) * 0.3))
save("black_flash", mix(tone(0.9, 60, 30) * env(int(0.9 * SR), 0.001, 0.8), lowpass(noise(0.7), 1500) * env(int(0.7 * SR), 0.001, 0.5), highpass(noise(0.25), 4000) * env(int(0.25 * SR), 0.001, 0.2) * 0.6, tone(0.4, 3000, 200) * env(int(0.4 * SR), 0.001, 0.35) * 0.4))
save("flicker_tick", mix(tone(0.08, 1800, 2600) * env(int(0.08 * SR), 0.001, 0.07), highpass(noise(0.04), 5000) * env(int(0.04 * SR), 0.001, 0.03) * 0.5))
save("catch", mix(lowpass(noise(0.12), 1200) * env(int(0.12 * SR), 0.001, 0.1), tone(0.15, 900, 300) * env(int(0.15 * SR), 0.001, 0.12) * 0.5))
save("devour", mix(tone(1.2, 90, 200) * env(int(1.2 * SR), 0.3, 0.8), bandpass(noise(1.2), 200, 900) * env(int(1.2 * SR), 0.4, 0.7) * 0.6, tone(1.0, 400, 1600) * env(int(1.0 * SR), 0.5, 0.45) * 0.25))
# ---- Endeavor: destruction
crunch = lambda sec, lo, hi: bandpass(noise(sec), lo, hi) * (env(int(sec * SR), 0.002, sec * 0.9) * (0.5 + 0.5 * np.abs(np.sin(t(sec) * 90))))
save("break_wood", mix(crunch(0.45, 300, 2500), tone(0.3, 180, 90) * env(int(0.3 * SR), 0.001, 0.25) * 0.5))
save("break_metal", mix(crunch(0.5, 500, 4000) * 0.6, *[tone(0.5, f) * env(int(0.5 * SR), 0.001, 0.4) * a for f, a in ((1500, 0.4), (2300, 0.3), (640, 0.4))]))
save("break_glass", mix(highpass(noise(0.4), 3000) * (env(int(0.4 * SR), 0.001, 0.35) * (0.4 + 0.6 * np.abs(np.sin(t(0.4) * 400)))), *[tone(0.25, f) * env(int(0.25 * SR), 0.001, 0.2) * 0.2 for f in (4200, 6100, 7800)]))
save("explosion", mix(tone(1.5, 50, 25) * env(int(1.5 * SR), 0.002, 1.3), lowpass(noise(1.4), 800) * env(int(1.4 * SR), 0.002, 1.1), bandpass(noise(0.5), 1000, 5000) * env(int(0.5 * SR), 0.001, 0.4) * 0.5))
save("collapse", mix(lowpass(noise(2.0), 250) * env(int(2.0 * SR), 0.1, 1.7), crunch(1.6, 200, 1500) * 0.6))
# ---- Front: firearms
def shot(sec, body_f, crack=True):
    parts = [tone(sec, body_f, body_f * 0.4) * env(int(sec * SR), 0.001, sec * 0.9), lowpass(noise(sec), 1200) * env(int(sec * SR), 0.001, sec * 0.6)]
    if crack: parts.append(highpass(noise(0.03), 2500) * env(int(0.03 * SR), 0.0005, 0.025) * 1.2)
    return mix(*parts)
save("shot_rifle", shot(0.45, 160))
save("shot_pistol", shot(0.25, 260))
save("shot_mg", shot(0.3, 130))
save("shot_distant", lowpass(shot(0.6, 90, crack=False), 500))
save("dry_click", mix(highpass(noise(0.02), 2000) * env(int(0.02 * SR), 0.0005, 0.015), tone(0.04, 1200, 600) * env(int(0.04 * SR), 0.001, 0.03) * 0.5))
save("rack", mix(tone(0.08, 900, 500) * env(int(0.08 * SR), 0.001, 0.06), bandpass(noise(0.06), 1500, 5000) * env(int(0.06 * SR), 0.001, 0.05), np.concatenate([np.zeros(int(0.12 * SR)), tone(0.1, 700, 400) * env(int(0.1 * SR), 0.001, 0.08)])))
save("impact_dirt", lowpass(noise(0.12), 700) * env(int(0.12 * SR), 0.001, 0.1))
save("impact_flesh", mix(lowpass(noise(0.1), 400) * env(int(0.1 * SR), 0.001, 0.08), tone(0.08, 120, 60) * env(int(0.08 * SR), 0.001, 0.07) * 0.6))
save("dig", mix(lowpass(noise(0.3), 500) * env(int(0.3 * SR), 0.01, 0.25) * (0.6 + 0.4 * np.abs(np.sin(t(0.3) * 40))), tone(0.1, 300, 150) * env(int(0.1 * SR), 0.001, 0.08) * 0.3))
save("artillery_whistle", tone(2.2, 2400, 900) * env(int(2.2 * SR), 0.3, 1.8, 0.2, 0.1) * 0.6 + bandpass(noise(2.2), 1500, 4000) * env(int(2.2 * SR), 0.5, 1.6) * 0.3)
print("SOUNDS DONE")

# ---- ambient beds: seamless loops (the tail is crossfaded into the head)
def loopable(x, fade=1.0):
    n = int(fade * SR); head, tail = x[:n].copy(), x[-n:].copy()
    ramp = np.linspace(0, 1, n)
    x = x[:-n]; x[:n] = head * ramp + tail * (1 - ramp)
    return x
def ambient_city(sec=24.0):
    hum = tone(sec, 55) * 0.5 + tone(sec, 110) * 0.25 + tone(sec, 164) * 0.1
    slow = 0.7 + 0.3 * np.sin(t(sec) * 0.37) * np.sin(t(sec) * 0.11)
    wind = lowpass(noise(sec), 400) * (0.6 + 0.4 * np.sin(t(sec) * 0.23 + 1.0))
    crackle = highpass(noise(sec), 6000) * (rng.random(int(sec * SR)) < 0.0004) * 6
    return loopable(hum * slow + wind * 0.8 + lowpass(crackle, 8000) * 0.5, 2.0)
def ambient_wind(sec=24.0):
    gust = 0.5 + 0.5 * np.abs(np.sin(t(sec) * 0.19) * np.sin(t(sec) * 0.07 + 0.4))
    return loopable(bandpass(noise(sec), 150, 1200) * gust + lowpass(noise(sec), 200) * 0.4, 2.0)
def ambient_front(sec=30.0):
    base = ambient_wind(sec + 2.0)[: int(sec * SR)]
    for _ in range(14):  # distant guns and the odd shell, rolled off
        at = int(rng.uniform(0.5, sec - 1.5) * SR)
        s = lowpass(shot(0.7, 70, crack=False), 350) * rng.uniform(0.2, 0.6)
        base[at: at + len(s)] += s[: len(base) - at]
    return loopable(base, 2.0)
save("amb_city", ambient_city())
save("amb_wind", ambient_wind())
save("amb_front", ambient_front())
print("AMBIENT DONE")
