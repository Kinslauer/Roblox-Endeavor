# The Front's first link (stasis tank, chute, barracks, simulation): synthesized like synth.py, which this
# borrows its helpers from (only its helper block runs). Run: python3 tools/sounds/synth_intro.py -> out/*.ogg
import os
here = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(here, "synth.py")).read()
exec(src[: src.index("# ---- Endeavor: melee")])

def seq(*parts):
    return np.concatenate(parts)
def silence(sec): return np.zeros(int(SR * sec))
def n(sec): return int(sec * SR)

# a sharp, wet inhale through fluid: a rising filtered rush with a gurgle under it, then a choke
gasp = mix(
    bandpass(noise(0.9), 500, 3800) * env(n(0.9), 0.35, 0.5, 0, 0.05) * (0.6 + 0.4 * np.abs(np.sin(t(0.9) * 31))),
    lowpass(noise(1.0), 260) * env(n(1.0), 0.05, 0.9) * (0.5 + 0.5 * np.abs(np.sin(t(1.0) * 17))) * 0.8,
    tone(0.5, 180, 320) * env(n(0.5), 0.2, 0.3) * 0.25,
)
save("tank_gasp", gasp)
# a heartbeat: lub-dub, low and muffled
def thump(f): return lowpass(tone(0.12, f, f * 0.6) * env(n(0.12), 0.003, 0.11), 300)
save("heartbeat", seq(thump(65), silence(0.09), thump(55) * 0.7, silence(0.2)))
# the memories syncing: a rising chord of tones with a hiss that swells to a white peak
rise = mix(*[tone(2.4, f, f * 2.2) * env(n(2.4), 1.8, 0.6) * a for f, a in ((110, 0.5), (165, 0.35), (220, 0.3), (330, 0.2))],
    highpass(noise(2.4), 3000) * env(n(2.4), 2.0, 0.4) * 0.4)
save("sync_rise", rise)
# and the settle: a long soft chord falling to rest
save("sync_settle", mix(*[tone(3.0, f * 1.5, f) * env(n(3.0), 0.02, 2.9) * a for f, a in ((220, 0.4), (277, 0.3), (330, 0.25))], lowpass(noise(2.0), 500) * env(n(2.0), 0.01, 1.9) * 0.2))
# the drain: gurgling suction falling in pitch, a pump under it
save("tank_drain", mix(
    lowpass(noise(5.5), 700) * env(n(5.5), 0.3, 5.0) * (0.4 + 0.6 * np.abs(np.sin(t(5.5) * (14 + 10 * np.sin(t(5.5) * 0.7))))),
    tone(5.5, 70, 40) * env(n(5.5), 0.5, 4.8) * 0.4,
    bandpass(noise(5.5), 1500, 4000) * env(n(5.5), 1.0, 4.4) * 0.15,
))
# cables letting go: a pneumatic hiss with three metal clacks
clack = mix(tone(0.12, 1700, 900) * env(n(0.12), 0.001, 0.1) * 0.6, bandpass(noise(0.08), 1500, 6000) * env(n(0.08), 0.001, 0.06))
save("unlatch", mix(highpass(noise(1.4), 2500) * env(n(1.4), 0.01, 1.3) * 0.5, seq(clack, silence(0.11), clack, silence(0.15), clack)))
# the hatch and the fall: a clunk, then wind rushing up a steel tube
save("chute_drop", mix(seq(lowpass(tone(0.2, 120, 60) * env(n(0.2), 0.002, 0.18), 400), silence(1.6)),
    seq(silence(0.15), bandpass(noise(1.6), 300, 2500) * env(n(1.6), 0.4, 1.2) * 0.8)))
# the simulation link: digital static that stutters and resolves into a tone
static = highpass(noise(2.0), 1200) * (rng.random(n(2.0)) < 0.5) * (0.5 + 0.5 * np.sign(np.sin(t(2.0) * 23)))
save("sim_link", mix(static * env(n(2.0), 0.05, 1.9) * 0.6, tone(2.0, 400, 1200) * env(n(2.0), 1.2, 0.8) * 0.3))
# a drill cleared: two clean ascending tones
save("sim_clear", seq(tone(0.12, 880) * env(n(0.12), 0.002, 0.11) * 0.5, tone(0.22, 1320) * env(n(0.22), 0.002, 0.21) * 0.5))
# a wireframe block shattering: glassy, bit-crushed
def crushed(x, steps=10): return np.round(x * steps) / steps
save("sim_break", mix(crushed(highpass(noise(0.35), 1800) * env(n(0.35), 0.001, 0.3)), *[tone(0.25, f, f * 0.7) * env(n(0.25), 0.001, 0.22) * 0.2 for f in (1900, 2800, 4100)]))
save("sim_break_soft", crushed(bandpass(noise(0.2), 1500, 6000) * env(n(0.2), 0.001, 0.18), 6) * 0.7)
# pulling up over a ledge: cloth and a grunt of effort
save("mantle", mix(bandpass(noise(0.35), 400, 2500) * env(n(0.35), 0.05, 0.28), lowpass(tone(0.25, 160, 110), 600) * env(n(0.25), 0.03, 0.2) * 0.4))
