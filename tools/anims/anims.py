# Endeavor animations, authored as keyframes in code and uploaded as Animation assets through Open Cloud
# (the Assets API takes a KeyframeSequence as .rbxmx; verified 2026-11-04).
#
#   python3 tools/anims/anims.py                 # writes tools/anims/out/<Name>.rbxmx + <Name>.png (stick-figure sheet)
#   ROBLOX_API_KEY=... python3 tools/anims/anims.py --upload [Name ...]   # uploads, prints "Name assetId"
#
# Joint space (R15, Roblox): X right, Y up, -Z forward. Rotations are degrees, applied as CFrame.Angles(x, y, z):
#   +X swings a hanging limb forward (hip flexion, arm raise); on the torso/head +X leans back.
#   +Y turns left (seen from above). +Z swings a hanging limb toward +X (the right): the left arm out is -Z,
#   the right arm out is +Z. A knee bends with -X on the LowerLeg; an elbow bends with +X on the LowerArm.
# A pose value is (rx, ry, rz) or (rx, ry, rz, tx, ty, tz); a part missing from a key is at rest (identity).
#
# Swing animations do not move the right arm: the client drives it along the traced arc (shared/Swings) and
# these key it to identity so idle/walk do not wobble it. Their timeline is fixed: wind-up 0 -> 0.4, strike
# 0.4 -> 0.6, recovery 0.6 -> 1.0; the client scales each phase to the server's Windup/Active/End.
import json, math, os, sys, time, urllib.request, uuid

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")

TREE = {  # part -> parent part (the Pose hierarchy)
    "LowerTorso": "HumanoidRootPart", "UpperTorso": "LowerTorso", "Head": "UpperTorso",
    "LeftUpperArm": "UpperTorso", "LeftLowerArm": "LeftUpperArm", "LeftHand": "LeftLowerArm",
    "RightUpperArm": "UpperTorso", "RightLowerArm": "RightUpperArm", "RightHand": "RightLowerArm",
    "LeftUpperLeg": "LowerTorso", "LeftLowerLeg": "LeftUpperLeg", "LeftFoot": "LeftLowerLeg",
    "RightUpperLeg": "LowerTorso", "RightLowerLeg": "RightUpperLeg", "RightFoot": "RightLowerLeg",
}
ORDER = ["LowerTorso", "UpperTorso", "Head", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm",
         "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot"]
RIGHT_ARM = ["RightUpperArm", "RightLowerArm", "RightHand"]

# easing for the segment that starts at a key (Enum.PoseEasingStyle / PoseEasingDirection)
STYLE = {"Linear": 0, "Constant": 1, "Elastic": 2, "Cubic": 3, "Bounce": 4, "CubicV2": 5}
DIR = {"In": 0, "Out": 1, "InOut": 2}

def mirror(p):
    """Left <-> right: swap part names, negate Y/Z rotations and X translation."""
    out = {}
    for name, v in p.items():
        other = "Right" + name[4:] if name.startswith("Left") else "Left" + name[5:] if name.startswith("Right") else name
        v = list(v) + [0] * (6 - len(v))
        out[other] = (v[0], -v[1], -v[2], -v[3], v[4], v[5])
    return out

def merge(*ps):
    out = {}
    for p in ps:
        out.update(p)
    return out

# ---------- shared stances ----------
STANCE = {  # fighting stance: knees soft, left foot forward, guard hand up, torso a little turned
    "LowerTorso": (0, -8, 0, 0, -0.18, 0), "UpperTorso": (-4, 4, 0), "Head": (2, 4, 0),
    "LeftUpperLeg": (16, 8, -4), "LeftLowerLeg": (-18, 0, 0), "LeftFoot": (4, 0, 0),
    "RightUpperLeg": (-6, 8, 6), "RightLowerLeg": (-16, 0, 0), "RightFoot": (12, 0, 0),
    "LeftUpperArm": (35, 0, -14), "LeftLowerArm": (55, 0, 0),
    "RightUpperArm": (18, 0, 10), "RightLowerArm": (30, 0, 0),
}
SWING_REST = merge(STANCE, {k: (0, 0, 0) for k in RIGHT_ARM})

def swing(coil, mid, end, heavy_drop=0.0):
    """A swing body: rest -> coil (wind-up) -> mid -> end (strike) -> rest."""
    return dict(length=1.0, loop=False, priority="Action", keys=[
        (0.0, SWING_REST, "CubicV2", "InOut"),
        (0.4, merge(SWING_REST, coil), "Cubic", "In"),
        (0.5, merge(SWING_REST, mid), "Linear", "InOut"),
        (0.6, merge(SWING_REST, end), "Cubic", "Out"),
        (0.75, merge(SWING_REST, end), "CubicV2", "InOut"),  # hold the follow-through a moment
        (1.0, SWING_REST, "Linear", "InOut"),
    ])

# forehand: coil to the right on the back leg, uncoil left stepping onto the front foot
SLASH_R = swing(
    coil={"LowerTorso": (0, -22, 0, 0.1, -0.22, 0.15), "UpperTorso": (6, -38, 4), "Head": (0, 40, 0),
          "RightUpperLeg": (-4, 14, 8), "RightLowerLeg": (-30, 0, 0), "RightFoot": (20, 0, 0),
          "LeftUpperLeg": (14, 14, -6), "LeftLowerLeg": (-8, 0, 0),
          "LeftUpperArm": (70, 30, -10), "LeftLowerArm": (35, 0, 0)},
    mid={"LowerTorso": (0, 0, 0, 0, -0.32, -0.25), "UpperTorso": (-8, 4, 0), "Head": (4, 0, 0),
         "LeftUpperLeg": (30, 6, -6), "LeftLowerLeg": (-28, 0, 0), "LeftFoot": (6, 0, 0),
         "RightUpperLeg": (-22, 6, 6), "RightLowerLeg": (-20, 0, 0), "RightFoot": (16, 0, 0),
         "LeftUpperArm": (20, 0, -30), "LeftLowerArm": (20, 0, 0)},
    end={"LowerTorso": (0, 24, 0, -0.1, -0.3, -0.4), "UpperTorso": (-14, 40, -4), "Head": (6, -44, 0),
         "LeftUpperLeg": (36, -14, -6), "LeftLowerLeg": (-30, 0, 0), "LeftFoot": (8, 0, 0),
         "RightUpperLeg": (-30, -10, 8), "RightLowerLeg": (-22, 0, 0), "RightFoot": (24, 0, 0),
         "LeftUpperArm": (-35, 0, -40), "LeftLowerArm": (30, 0, 0)},
)
# backhand: coil across the body to the left, unwind to the right
SLASH_L = swing(
    coil={"LowerTorso": (0, 20, 0, -0.1, -0.22, 0.1), "UpperTorso": (4, 36, -4), "Head": (0, -36, 0),
          "LeftUpperLeg": (10, -10, -6), "LeftLowerLeg": (-26, 0, 0),
          "RightUpperLeg": (-8, -8, 6), "RightLowerLeg": (-18, 0, 0), "RightFoot": (14, 0, 0),
          "LeftUpperArm": (-20, 0, -45), "LeftLowerArm": (25, 0, 0)},
    mid={"LowerTorso": (0, 0, 0, 0, -0.3, -0.22), "UpperTorso": (-8, -4, 0), "Head": (4, 0, 0),
         "LeftUpperLeg": (28, 4, -6), "LeftLowerLeg": (-26, 0, 0),
         "RightUpperLeg": (-20, 4, 6), "RightLowerLeg": (-22, 0, 0), "RightFoot": (16, 0, 0),
         "LeftUpperArm": (30, 0, -25), "LeftLowerArm": (40, 0, 0)},
    end={"LowerTorso": (0, -24, 0, 0.1, -0.28, -0.32), "UpperTorso": (-10, -42, 6), "Head": (4, 46, 0),
         "LeftUpperLeg": (30, 16, -6), "LeftLowerLeg": (-26, 0, 0),
         "RightUpperLeg": (-26, 14, 8), "RightLowerLeg": (-26, 0, 0), "RightFoot": (22, 0, 0),
         "LeftUpperArm": (55, 20, -10), "LeftLowerArm": (60, 0, 0)},
)
# overhead: rise and arch back, then drop the weight through the blow
OVERHEAD = swing(
    coil={"LowerTorso": (0, -10, 0, 0, -0.05, 0.15), "UpperTorso": (18, -12, 0), "Head": (-10, 10, 0),
          "LeftUpperLeg": (12, 4, -6), "LeftLowerLeg": (-6, 0, 0),
          "RightUpperLeg": (-10, 4, 6), "RightLowerLeg": (-10, 0, 0), "RightFoot": (14, 0, 0),
          "LeftUpperArm": (110, 0, -10), "LeftLowerArm": (30, 0, 0)},
    mid={"LowerTorso": (-6, 0, 0, 0, -0.35, -0.25), "UpperTorso": (-14, 0, 0), "Head": (10, 0, 0),
         "LeftUpperLeg": (32, 0, -6), "LeftLowerLeg": (-30, 0, 0),
         "RightUpperLeg": (-20, 0, 6), "RightLowerLeg": (-26, 0, 0), "RightFoot": (20, 0, 0),
         "LeftUpperArm": (40, 0, -20), "LeftLowerArm": (30, 0, 0)},
    end={"LowerTorso": (-10, 4, 0, 0, -0.6, -0.4), "UpperTorso": (-30, 6, 0), "Head": (24, 0, 0),
         "LeftUpperLeg": (48, 0, -6), "LeftLowerLeg": (-50, 0, 0), "LeftFoot": (6, 0, 0),
         "RightUpperLeg": (-24, 0, 6), "RightLowerLeg": (-40, 0, 0), "RightFoot": (30, 0, 0),
         "LeftUpperArm": (-20, 0, -30), "LeftLowerArm": (20, 0, 0)},
)
# diagonal: high on the right, through and down to the left hip
DIAGONAL = swing(
    coil={"LowerTorso": (0, -18, 0, 0.1, -0.15, 0.15), "UpperTorso": (14, -32, 8), "Head": (-6, 34, 0),
          "RightUpperLeg": (-6, 12, 8), "RightLowerLeg": (-24, 0, 0), "RightFoot": (18, 0, 0),
          "LeftUpperLeg": (14, 12, -6), "LeftLowerLeg": (-8, 0, 0),
          "LeftUpperArm": (90, 25, -10), "LeftLowerArm": (30, 0, 0)},
    mid={"LowerTorso": (-4, 2, 0, 0, -0.35, -0.25), "UpperTorso": (-10, 6, 0), "Head": (6, 0, 0),
         "LeftUpperLeg": (32, 4, -6), "LeftLowerLeg": (-30, 0, 0),
         "RightUpperLeg": (-22, 4, 6), "RightLowerLeg": (-24, 0, 0), "RightFoot": (18, 0, 0),
         "LeftUpperArm": (25, 0, -30), "LeftLowerArm": (25, 0, 0)},
    end={"LowerTorso": (-8, 22, 0, -0.1, -0.5, -0.4), "UpperTorso": (-26, 36, -10), "Head": (16, -38, 0),
         "LeftUpperLeg": (44, -12, -6), "LeftLowerLeg": (-44, 0, 0), "LeftFoot": (6, 0, 0),
         "RightUpperLeg": (-28, -10, 8), "RightLowerLeg": (-34, 0, 0), "RightFoot": (28, 0, 0),
         "LeftUpperArm": (-35, 0, -40), "LeftLowerArm": (25, 0, 0)},
)
# uppercut: sink low, then drive up through the legs
UPPERCUT = swing(
    coil={"LowerTorso": (0, -16, 0, 0, -0.55, 0.1), "UpperTorso": (-16, -20, 6), "Head": (12, 18, 0),
          "LeftUpperLeg": (34, 8, -6), "LeftLowerLeg": (-44, 0, 0), "LeftFoot": (8, 0, 0),
          "RightUpperLeg": (4, 8, 6), "RightLowerLeg": (-50, 0, 0), "RightFoot": (40, 0, 0),
          "LeftUpperArm": (50, 0, -12), "LeftLowerArm": (70, 0, 0)},
    mid={"LowerTorso": (0, 0, 0, 0, -0.15, -0.15), "UpperTorso": (2, 2, 0), "Head": (0, 0, 0),
         "LeftUpperLeg": (22, 4, -6), "LeftLowerLeg": (-16, 0, 0),
         "RightUpperLeg": (-14, 4, 6), "RightLowerLeg": (-14, 0, 0), "RightFoot": (14, 0, 0),
         "LeftUpperArm": (30, 0, -20), "LeftLowerArm": (40, 0, 0)},
    end={"LowerTorso": (4, 18, 0, 0, 0.05, -0.25), "UpperTorso": (16, 22, -6), "Head": (-14, -20, 0),
         "LeftUpperLeg": (16, -6, -6), "LeftLowerLeg": (-6, 0, 0),
         "RightUpperLeg": (-24, -6, 6), "RightLowerLeg": (-8, 0, 0), "RightFoot": (30, 0, 0),
         "LeftUpperArm": (-30, 0, -30), "LeftLowerArm": (30, 0, 0)},
)
# thrust: pull back on the rear leg, then lunge onto the front leg
THRUST = swing(
    coil={"LowerTorso": (0, -24, 0, 0, -0.25, 0.3), "UpperTorso": (6, -24, 0), "Head": (0, 40, 0),
          "RightUpperLeg": (-4, 18, 6), "RightLowerLeg": (-34, 0, 0), "RightFoot": (24, 0, 0),
          "LeftUpperLeg": (20, 18, -6), "LeftLowerLeg": (-6, 0, 0),
          "LeftUpperArm": (60, 30, -10), "LeftLowerArm": (20, 0, 0)},
    mid={"LowerTorso": (-6, -4, 0, 0, -0.45, -0.4), "UpperTorso": (-10, 4, 0), "Head": (8, 2, 0),
         "LeftUpperLeg": (44, 2, -6), "LeftLowerLeg": (-40, 0, 0), "LeftFoot": (4, 0, 0),
         "RightUpperLeg": (-30, 2, 6), "RightLowerLeg": (-14, 0, 0), "RightFoot": (24, 0, 0),
         "LeftUpperArm": (-10, 0, -30), "LeftLowerArm": (15, 0, 0)},
    end={"LowerTorso": (-12, 6, 0, 0, -0.65, -0.8), "UpperTorso": (-16, 10, 0), "Head": (16, -12, 0),
         "LeftUpperLeg": (60, 0, -6), "LeftLowerLeg": (-58, 0, 0), "LeftFoot": (2, 0, 0),
         "RightUpperLeg": (-38, 0, 6), "RightLowerLeg": (-10, 0, 0), "RightFoot": (30, 0, 0),
         "LeftUpperArm": (-40, 0, -30), "LeftLowerArm": (10, 0, 0)},
)
# jab: a short, sharp thrust from the guard
JAB = swing(
    coil={"LowerTorso": (0, -12, 0, 0, -0.22, 0.08), "UpperTorso": (2, -12, 0), "Head": (0, 14, 0),
          "RightLowerLeg": (-22, 0, 0), "LeftUpperArm": (60, 0, -16), "LeftLowerArm": (90, 0, 0)},
    mid={"LowerTorso": (0, 4, 0, 0, -0.24, -0.12), "UpperTorso": (-6, 10, 0), "Head": (2, -10, 0),
         "LeftUpperLeg": (22, 6, -6), "LeftLowerLeg": (-20, 0, 0),
         "LeftUpperArm": (55, 0, -16), "LeftLowerArm": (90, 0, 0)},
    end={"LowerTorso": (0, 12, 0, 0, -0.24, -0.2), "UpperTorso": (-8, 18, 0), "Head": (2, -18, 0),
         "LeftUpperLeg": (24, 2, -6), "LeftLowerLeg": (-22, 0, 0),
         "RightUpperLeg": (-14, 2, 6), "RightFoot": (18, 0, 0),
         "LeftUpperArm": (50, 0, -16), "LeftLowerArm": (95, 0, 0)},
)

def react(peak, length=0.7):
    """A hit reaction: snaps to the peak, holds most of it (the hit-stun), then recovers."""
    def part(f):
        return {k: tuple(a * f for a in v) for k, v in peak.items()}
    return dict(length=length, loop=False, priority="Action", keys=[
        (0.0, {}, "Cubic", "Out"),
        (length * 0.09, peak, "CubicV2", "InOut"),
        (length * 0.32, part(0.8), "CubicV2", "InOut"),
        (length * 0.66, part(0.28), "CubicV2", "InOut"),
        (length, {}, "Linear", "InOut"),
    ])

# hit reactions (v2: "the reactions still fall short"): bigger, a step back to catch the weight, arms thrown,
# held through the hit-stun (the client stretches them to the stun the server applied)
ARMS_FLUNG = {"LeftUpperArm": (35, 0, -32), "LeftLowerArm": (45, 0, 0), "RightUpperArm": (35, 0, 32), "RightLowerArm": (45, 0, 0)}
CATCH = {"RightUpperLeg": (-32, 0, 6), "RightLowerLeg": (-40, 0, 0), "RightFoot": (24, 0, 0),
         "LeftUpperLeg": (14, 0, -4), "LeftLowerLeg": (-22, 0, 0)}
HIT_FRONT = react(merge(ARMS_FLUNG, CATCH, {"LowerTorso": (8, 0, 0, 0, -0.3, 0.75), "UpperTorso": (22, 0, 0), "Head": (22, 0, 0)}))
# struck on the right side: the body twists and folds to the left, away from the blow, stepping out
HIT_RIGHT = react(merge(ARMS_FLUNG, {"LowerTorso": (4, 16, 6, -0.6, -0.25, 0.2), "UpperTorso": (10, 32, 16), "Head": (8, 24, 16),
                                     "RightUpperArm": (20, 0, 55), "LeftUpperArm": (30, 0, -25),
                                     "LeftUpperLeg": (6, 0, -22), "LeftLowerLeg": (-20, 0, 0),
                                     "RightUpperLeg": (-6, 0, -6), "RightLowerLeg": (-34, 0, 0), "RightFoot": (20, 0, 0)}))
HIT_LEFT = react(mirror(HIT_RIGHT["keys"][1][1]))
HIT_HIGH = react(merge(ARMS_FLUNG, CATCH, {"LowerTorso": (6, 0, 0, 0, -0.2, 0.5), "UpperTorso": (16, 0, 0), "Head": (40, 0, 0),
                                           "LeftUpperArm": (60, 0, -30), "RightUpperArm": (60, 0, 30)}))
# a heavy blow: thrown back off the feet for a beat, two stumbling steps
HIT_HEAVY = dict(length=1.1, loop=False, priority="Action", keys=[
    (0.0, {}, "Cubic", "Out"),
    (0.08, merge(ARMS_FLUNG, {"LowerTorso": (12, 0, 0, 0, -0.25, 1.2), "UpperTorso": (26, 0, 0), "Head": (24, 0, 0),
                              "LeftUpperArm": (60, 0, -45), "RightUpperArm": (60, 0, 45),
                              "LeftUpperLeg": (14, 0, -6), "LeftLowerLeg": (-16, 0, 0), "RightUpperLeg": (-8, 0, 6), "RightLowerLeg": (-24, 0, 0)}), "CubicV2", "InOut"),
    (0.35, merge(ARMS_FLUNG, {"LowerTorso": (10, 0, 0, 0, -0.55, 0.6), "UpperTorso": (6, 0, 0), "Head": (10, 0, 0),
                              "RightUpperLeg": (-36, 0, 6), "RightLowerLeg": (-60, 0, 0), "RightFoot": (30, 0, 0),
                              "LeftUpperLeg": (30, 0, -6), "LeftLowerLeg": (-40, 0, 0)}), "CubicV2", "InOut"),
    (0.6, merge({"LowerTorso": (0, 0, 0, 0, -0.45, 0.2), "UpperTorso": (-20, 0, 0), "Head": (-4, 0, 0),
                 "LeftUpperLeg": (-24, 0, -6), "LeftLowerLeg": (-50, 0, 0), "LeftFoot": (26, 0, 0),
                 "RightUpperLeg": (30, 0, 6), "RightLowerLeg": (-36, 0, 0),
                 "LeftUpperArm": (20, 0, -30), "RightUpperArm": (20, 0, 30), "LeftLowerArm": (40, 0, 0), "RightLowerArm": (40, 0, 0)}), "CubicV2", "InOut"),
    (1.1, {}, "Linear", "InOut"),
])
STAGGER = dict(length=0.9, loop=False, priority="Action", keys=[  # guard broken: stumble back, arms out, catch the weight
    (0.0, {}, "Cubic", "Out"),
    (0.12, merge(ARMS_FLUNG, {"LowerTorso": (12, 6, 0, 0, -0.15, 0.6), "UpperTorso": (24, 8, 6), "Head": (26, 0, 0),
                              "LeftUpperArm": (40, 0, -60), "RightUpperArm": (40, 0, 60),
                              "LeftUpperLeg": (14, 0, -6), "RightUpperLeg": (-30, 0, 6), "RightLowerLeg": (-30, 0, 0)}), "CubicV2", "InOut"),
    (0.45, merge({"LowerTorso": (4, 4, 0, 0, -0.5, 0.5), "UpperTorso": (-18, 6, 0), "Head": (-6, 0, 0),
                  "LeftUpperLeg": (30, 0, -6), "LeftLowerLeg": (-40, 0, 0), "RightUpperLeg": (-6, 0, 6), "RightLowerLeg": (-60, 0, 0),
                  "RightFoot": (30, 0, 0), "LeftUpperArm": (20, 0, -30), "RightUpperArm": (20, 0, 30),
                  "LeftLowerArm": (40, 0, 0), "RightLowerArm": (40, 0, 0)}), "CubicV2", "InOut"),
    (0.9, {}, "Linear", "InOut"),
])
RECOIL = react({"LowerTorso": (6, -8, 0, 0, -0.2, 0.4), "UpperTorso": (14, -16, 0), "Head": (8, 10, 0),
                "LeftUpperArm": (20, 0, -40), "RightUpperLeg": (-14, 0, 6), "RightLowerLeg": (-24, 0, 0)}, length=0.45)
# the guard (v2): body only; the client holds the weapon across the front, braced by the off hand, and turns
# it toward the incoming blade (the arms are keyed to rest so nothing underneath moves them)
ARMS_FREE = {k: (0, 0, 0) for k in ("LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand")}
GUARD = merge(ARMS_FREE, {"LowerTorso": (0, -6, 0, 0, -0.28, 0.05), "UpperTorso": (-8, 6, 0), "Head": (6, -4, 0),
         "LeftUpperLeg": (18, 6, -6), "LeftLowerLeg": (-26, 0, 0), "LeftFoot": (8, 0, 0),
         "RightUpperLeg": (-10, 6, 6), "RightLowerLeg": (-24, 0, 0), "RightFoot": (16, 0, 0)})
BLOCK = dict(length=1.6, loop=True, priority="Action", keys=[
    (0.0, GUARD, "CubicV2", "InOut"),
    (0.8, merge(GUARD, {"UpperTorso": (-6, 6, 0), "LowerTorso": (0, -6, 0, 0, -0.25, 0.05)}), "CubicV2", "InOut"),
    (1.6, GUARD, "Linear", "InOut"),
])
# a parry: the body turns into the deflection and drives forward (the client sweeps the weapon outward)
PARRY = dict(length=0.4, loop=False, priority="Action", keys=[
    (0.0, GUARD, "Cubic", "Out"),
    (0.07, merge(GUARD, {"UpperTorso": (-12, -18, 0), "LowerTorso": (0, -14, 0, 0, -0.32, -0.25), "Head": (4, 14, 0),
                         "LeftUpperLeg": (28, 6, -6), "LeftLowerLeg": (-30, 0, 0)}), "CubicV2", "InOut"),
    (0.4, GUARD, "Linear", "InOut"),
])
# guarding a hit: the guard is driven back into the body, the legs absorb it
BLOCK_HIT = dict(length=0.35, loop=False, priority="Action", keys=[
    (0.0, GUARD, "Cubic", "Out"),
    (0.06, merge(GUARD, {"UpperTorso": (10, 6, 0), "LowerTorso": (4, -6, 0, 0, -0.4, 0.35), "Head": (10, -4, 0),
                         "RightUpperLeg": (-18, 6, 6), "RightLowerLeg": (-36, 0, 0)}), "CubicV2", "InOut"),
    (0.35, GUARD, "Linear", "InOut"),
])

# idle fighting stance with breathing and a slow weight shift
IDLE = dict(length=2.4, loop=True, priority="Idle", keys=[
    (0.0, STANCE, "CubicV2", "InOut"),
    (1.2, merge(STANCE, {"LowerTorso": (0, -6, 0, 0, -0.21, 0), "UpperTorso": (-2, 4, 0), "Head": (0, 6, 0),
                         "LeftUpperArm": (37, 0, -14), "RightUpperArm": (20, 0, 10)}), "CubicV2", "InOut"),
    (2.4, STANCE, "Linear", "InOut"),
])

def cycle(length, stride, knee, tuck, arm, elbow, lean, bob, twist):
    """Run/walk cycle: left contact, passing, right contact, passing."""
    contact = {"LowerTorso": (0, twist, 0, 0, -bob, 0), "UpperTorso": (-lean, -twist * 1.6, 0), "Head": (lean * 0.6, twist * 0.6, 0),
               "LeftUpperLeg": (stride, 0, 0), "LeftLowerLeg": (-knee, 0, 0), "LeftFoot": (-8, 0, 0),
               "RightUpperLeg": (-stride * 0.8, 0, 0), "RightLowerLeg": (-knee * 1.6, 0, 0), "RightFoot": (20, 0, 0),
               "RightUpperArm": (arm, 0, 6), "RightLowerArm": (elbow * 1.3, 0, 0),
               "LeftUpperArm": (-arm * 0.8, 0, -6), "LeftLowerArm": (elbow * 0.7, 0, 0)}
    passing = {"LowerTorso": (0, 0, 0, 0, bob * 0.6, 0), "UpperTorso": (-lean, 0, 0), "Head": (lean * 0.6, 0, 0),
               "LeftUpperLeg": (-stride * 0.15, 0, 0), "LeftLowerLeg": (-knee * 0.8, 0, 0),
               "RightUpperLeg": (stride * 0.45, 0, 0), "RightLowerLeg": (-tuck, 0, 0), "RightFoot": (-10, 0, 0),
               "RightUpperArm": (arm * 0.1, 0, 6), "RightLowerArm": (elbow, 0, 0),
               "LeftUpperArm": (arm * 0.1, 0, -6), "LeftLowerArm": (elbow, 0, 0)}
    return dict(length=length, loop=True, priority="Movement", keys=[
        (0.0, contact, "CubicV2", "InOut"),
        (length * 0.25, passing, "CubicV2", "InOut"),
        (length * 0.5, mirror(contact), "CubicV2", "InOut"),
        (length * 0.75, mirror(passing), "CubicV2", "InOut"),
        (length, contact, "Linear", "InOut"),
    ])

RUN = cycle(0.5, stride=50, knee=16, tuck=100, arm=55, elbow=75, lean=15, bob=0.2, twist=9)  # ~11.5 studs/s at speed 1
WALK = cycle(0.9, stride=30, knee=8, tuck=55, arm=26, elbow=22, lean=4, bob=0.1, twist=5)  # ~4.5 studs/s at speed 1

# the armoured dash (Q to the side or back when not in light gear): a heavy push off one leg, guard kept up,
# the body sinking under the weight and catching itself
def step(peak):
    return dict(length=0.5, loop=False, priority="Action", keys=[
        (0.0, merge(STANCE, {}), "Cubic", "Out"),
        (0.12, merge(STANCE, peak), "CubicV2", "InOut"),
        (0.32, merge(STANCE, {k: tuple(a * 0.6 for a in v) for k, v in peak.items()}), "CubicV2", "InOut"),
        (0.5, STANCE, "Linear", "InOut"),
    ])
STEP_RIGHT = step({"LowerTorso": (0, -6, -8, 0, -0.42, 0), "UpperTorso": (-8, 6, -6), "Head": (4, -4, 6),
                   "RightUpperLeg": (14, 0, 26), "RightLowerLeg": (-30, 0, 0), "RightFoot": (8, 0, -10),
                   "LeftUpperLeg": (4, 0, 10), "LeftLowerLeg": (-40, 0, 0), "LeftFoot": (20, 0, 6),
                   "LeftUpperArm": (55, 0, -20), "LeftLowerArm": (70, 0, 0), "RightUpperArm": (30, 0, 25), "RightLowerArm": (40, 0, 0)})
STEP_LEFT = step(mirror(STEP_RIGHT["keys"][1][1]))
STEP_BACK = step({"LowerTorso": (8, -4, 0, 0, -0.45, 0.2), "UpperTorso": (-16, 4, 0), "Head": (10, 0, 0),
                  "LeftUpperLeg": (34, 4, -6), "LeftLowerLeg": (-24, 0, 0), "LeftFoot": (-6, 0, 0),
                  "RightUpperLeg": (-26, 4, 6), "RightLowerLeg": (-50, 0, 0), "RightFoot": (34, 0, 0),
                  "LeftUpperArm": (60, 0, -18), "LeftLowerArm": (70, 0, 0), "RightUpperArm": (35, 0, 15), "RightLowerArm": (45, 0, 0)})

# ---------- stealth (2026-11-10): crouch, takedowns, a body on the floor ----------
# Crouch: the hips drop about a stud with the feet still on the floor (thigh 60 forward, knee 120 back).
CROUCH = {"LowerTorso": (0, -6, 0, 0, -1.0, 0), "UpperTorso": (-26, 4, 0), "Head": (20, 2, 0),
          "LeftUpperLeg": (70, 6, -4), "LeftLowerLeg": (-115, 0, 0), "LeftFoot": (10, 0, 0),
          "RightUpperLeg": (35, 6, 6), "RightLowerLeg": (-115, 0, 0), "RightFoot": (42, 0, 0),
          "LeftUpperArm": (42, 0, -12), "LeftLowerArm": (60, 0, 0), "RightUpperArm": (30, 0, 10), "RightLowerArm": (45, 0, 0)}
CROUCH_IDLE = dict(length=2.8, loop=True, priority="Idle", keys=[
    (0.0, CROUCH, "CubicV2", "InOut"),
    (1.4, merge(CROUCH, {"LowerTorso": (0, -4, 0, 0, -1.04, 0), "UpperTorso": (-24, 2, 0), "Head": (20, 8, 0)}), "CubicV2", "InOut"),
    (2.8, CROUCH, "Linear", "InOut"),
])
def crouch_cycle(length):
    low = {"UpperTorso": (-30, 0, 0), "Head": (24, 0, 0)}
    contact = merge(low, {"LowerTorso": (0, 5, 0, 0, -1.0, 0), "UpperTorso": (-30, -8, 0),
                          "LeftUpperLeg": (85, 0, 0), "LeftLowerLeg": (-110, 0, 0), "LeftFoot": (16, 0, 0),
                          "RightUpperLeg": (25, 0, 0), "RightLowerLeg": (-110, 0, 0), "RightFoot": (50, 0, 0),
                          "RightUpperArm": (40, 0, 8), "RightLowerArm": (60, 0, 0), "LeftUpperArm": (10, 0, -10), "LeftLowerArm": (50, 0, 0)})
    passing = merge(low, {"LowerTorso": (0, 0, 0, 0, -0.94, 0),
                          "LeftUpperLeg": (60, 0, 0), "LeftLowerLeg": (-118, 0, 0), "LeftFoot": (30, 0, 0),
                          "RightUpperLeg": (78, 0, 0), "RightLowerLeg": (-140, 0, 0), "RightFoot": (20, 0, 0),
                          "RightUpperArm": (26, 0, 8), "RightLowerArm": (55, 0, 0), "LeftUpperArm": (26, 0, -8), "LeftLowerArm": (55, 0, 0)})
    return dict(length=length, loop=True, priority="Movement", keys=[
        (0.0, contact, "CubicV2", "InOut"), (length * 0.25, passing, "CubicV2", "InOut"),
        (length * 0.5, mirror(contact), "CubicV2", "InOut"), (length * 0.75, mirror(passing), "CubicV2", "InOut"),
        (length, contact, "Linear", "InOut"),
    ])
CROUCH_WALK = crouch_cycle(1.0)

# Takedowns: 1.6 s of action (the client plays them at 1.6 / the server's seconds), then the end pose is held
# until the server lays the body down. The attacker starts where server/Stealth.lua puts it: 1.5 studs behind
# (Rear), on top (Drop), or facing the guard's back with the fuse box / rail / drop beyond it (Slam).
def held(keys, hold=0.9):
    t, pose = keys[-1][0], keys[-1][1]
    return dict(length=t + hold, loop=False, priority="Action", keys=keys + [(t + hold, pose, "Linear", "InOut")])
# Rear (reworked 2026-11-11 after "it looked like i grabbed the side of the enemy's body instead of their neck"):
# the server stands the attacker 1.5 behind, square to the guard's back. The left upper arm comes up and forward
# with a quarter roll (ry -85) so the elbow folds the forearm ACROSS the throat (toward +X), not upward; the right
# hand comes in behind the head. Chest to back, about 0.9 apart, then the attacker kneels and lets him fall forward.
TAKEDOWN_REAR = dict(length=1.6, loop=False, priority="Action", keys=[
    (0.0, STANCE, "Cubic", "Out"),
    (0.22, {"LowerTorso": (0, 0, 0, 0, -0.12, -0.6), "UpperTorso": (-8, 0, 0), "Head": (4, 0, 0),
            "LeftUpperArm": (112, -85, 0), "LeftLowerArm": (95, 0, 0), "RightUpperArm": (120, 70, 0), "RightLowerArm": (100, 0, 0),
            "LeftUpperLeg": (26, 0, -4), "LeftLowerLeg": (-24, 0, 0), "RightUpperLeg": (-18, 0, 4), "RightLowerLeg": (-16, 0, 0), "RightFoot": (16, 0, 0)}, "CubicV2", "InOut"),
    (0.7, {"LowerTorso": (2, 0, 0, 0, -0.2, -0.62), "UpperTorso": (0, 5, 0), "Head": (-4, -6, 0),
           "LeftUpperArm": (104, -92, 0), "LeftLowerArm": (100, 0, 0), "RightUpperArm": (118, 74, 0), "RightLowerArm": (104, 0, 0),
           "LeftUpperLeg": (22, 0, -6), "LeftLowerLeg": (-32, 0, 0), "RightUpperLeg": (-10, 0, 6), "RightLowerLeg": (-28, 0, 0), "RightFoot": (14, 0, 0)}, "CubicV2", "InOut"),
    (1.25, {"LowerTorso": (0, 0, 0, 0, -0.95, -0.35), "UpperTorso": (-26, 4, 0), "Head": (16, 0, 0),
            "LeftUpperArm": (78, -60, 0), "LeftLowerArm": (80, 0, 0), "RightUpperArm": (70, 40, 0), "RightLowerArm": (60, 0, 0),
            "LeftUpperLeg": (72, 0, -4), "LeftLowerLeg": (-115, 0, 0), "RightUpperLeg": (34, 0, 4), "RightLowerLeg": (-115, 0, 0), "RightFoot": (40, 0, 0)}, "CubicV2", "InOut"),
    (1.6, CROUCH, "Linear", "InOut"),
])
# How a body lies (limbs only). Every victim animation ends in it with the hips turned face down on the floor
# (LowerTorso -90, 2.1 down, F forward); at that moment the server turns the root itself face down at the same
# spot and the client swaps to "Downed" with no fade, so nothing snaps.
_DOWN = {"UpperTorso": (4, 0, 6), "Head": (6, 52, 0),
         "LeftUpperArm": (150, 0, -34), "LeftLowerArm": (62, 0, 0), "RightUpperArm": (-8, 0, 24), "RightLowerArm": (24, 0, 0),
         "LeftUpperLeg": (-4, 0, -14), "LeftLowerLeg": (-10, 0, 0), "RightUpperLeg": (24, 0, 22), "RightLowerLeg": (-58, 0, 0), "RightFoot": (30, 0, 0), "LeftFoot": (40, 0, 0)}
def fallen(forward, side=0):
    return merge(_DOWN, {"LowerTorso": (-90, 0, 0, side, -2.1, -forward)})
TAKEDOWN_REAR_VICTIM = held([
    (0.0, {}, "Cubic", "Out"),
    (0.24, {"LowerTorso": (3, 0, 0, 0, -0.05, 0.1), "UpperTorso": (5, 0, 0), "Head": (14, 0, 0),
            "LeftUpperArm": (95, 0, 20), "LeftLowerArm": (125, 0, 0), "RightUpperArm": (95, 0, -20), "RightLowerArm": (125, 0, 0)}, "CubicV2", "InOut"),
    (0.5, {"LowerTorso": (5, 4, 0, 0.05, -0.15, 0.15), "UpperTorso": (7, -8, 0), "Head": (12, 12, 0),
           "LeftUpperArm": (100, 0, 26), "LeftLowerArm": (130, 0, 0), "RightUpperArm": (88, 0, -14), "RightLowerArm": (120, 0, 0),
           "LeftUpperLeg": (36, 0, -8), "LeftLowerLeg": (-46, 0, 0), "RightUpperLeg": (-8, 0, 8), "RightLowerLeg": (-20, 0, 0)}, "CubicV2", "InOut"),
    (0.8, {"LowerTorso": (5, -4, 0, -0.05, -0.25, 0.15), "UpperTorso": (6, 8, 0), "Head": (6, -10, 0),
           "LeftUpperArm": (70, 0, 10), "LeftLowerArm": (110, 0, 0), "RightUpperArm": (50, 0, -8), "RightLowerArm": (80, 0, 0),
           "LeftUpperLeg": (0, 0, -8), "LeftLowerLeg": (-30, 0, 0), "RightUpperLeg": (32, 0, 8), "RightLowerLeg": (-56, 0, 0)}, "CubicV2", "InOut"),
    (1.25, {"LowerTorso": (-8, 0, 0, 0, -1.3, 0.1), "UpperTorso": (-14, 0, 6), "Head": (-30, 0, 10),
            "LeftUpperArm": (12, 0, -10), "LeftLowerArm": (20, 0, 0), "RightUpperArm": (12, 0, 10), "RightLowerArm": (20, 0, 0),
            "LeftUpperLeg": (60, 0, -10), "LeftLowerLeg": (-135, 0, 0), "RightUpperLeg": (60, 0, 10), "RightLowerLeg": (-135, 0, 0), "LeftFoot": (40, 0, 0), "RightFoot": (40, 0, 0)}, "Cubic", "In"),
    (1.6, fallen(0.9), "Linear", "InOut"),
])
TAKEDOWN_DROP = dict(length=1.6, loop=False, priority="Action", keys=[
    (0.0, {"LowerTorso": (0, 0, 0, 0, 0.4, 0.9), "UpperTorso": (-20, 0, 0), "Head": (26, 0, 0),
           "LeftUpperLeg": (60, 0, -10), "LeftLowerLeg": (-80, 0, 0), "RightUpperLeg": (20, 0, 10), "RightLowerLeg": (-70, 0, 0),
           "LeftUpperArm": (40, 0, -60), "LeftLowerArm": (30, 0, 0), "RightUpperArm": (150, 0, 20), "RightLowerArm": (80, 0, 0)}, "Cubic", "In"),
    (0.16, {"LowerTorso": (0, 0, 0, 0, -1.25, 0.9), "UpperTorso": (-38, -10, 0), "Head": (30, 0, 0),
            "LeftUpperLeg": (95, 0, -14), "LeftLowerLeg": (-125, 0, 0), "RightUpperLeg": (30, 0, 12), "RightLowerLeg": (-125, 0, 0), "RightFoot": (40, 0, 0),
            "LeftUpperArm": (50, 0, -30), "LeftLowerArm": (40, 0, 0), "RightUpperArm": (40, 0, -6), "RightLowerArm": (14, 0, 0)}, "CubicV2", "InOut"),
    (0.9, {"LowerTorso": (0, 0, 0, 0, -1.15, 0.9), "UpperTorso": (-30, -4, 0), "Head": (26, 0, 0),
           "LeftUpperLeg": (90, 0, -14), "LeftLowerLeg": (-122, 0, 0), "RightUpperLeg": (30, 0, 12), "RightLowerLeg": (-122, 0, 0), "RightFoot": (40, 0, 0),
           "LeftUpperArm": (44, 0, -20), "LeftLowerArm": (50, 0, 0), "RightUpperArm": (36, 0, 0), "RightLowerArm": (30, 0, 0)}, "CubicV2", "InOut"),
    (1.6, CROUCH, "Linear", "InOut"),
])
TAKEDOWN_DROP_VICTIM = held([
    (0.0, {"Head": (20, 0, 0)}, "Cubic", "In"),
    (0.16, {"LowerTorso": (-70, 0, 0, 0, -1.9, -0.7), "UpperTorso": (-12, 0, 0), "Head": (28, 0, 0),
            "LeftUpperArm": (150, 0, -30), "LeftLowerArm": (30, 0, 0), "RightUpperArm": (150, 0, 30), "RightLowerArm": (30, 0, 0),
            "LeftUpperLeg": (40, 0, -12), "LeftLowerLeg": (-60, 0, 0), "RightUpperLeg": (20, 0, 12), "RightLowerLeg": (-40, 0, 0)}, "CubicV2", "InOut"),
    (0.5, fallen(0.8), "Linear", "InOut"),
    (1.6, fallen(0.8), "Linear", "InOut"),
])
TAKEDOWN_SLAM = dict(length=1.6, loop=False, priority="Action", keys=[
    (0.0, STANCE, "Cubic", "Out"),
    (0.28, {"LowerTorso": (0, 0, 0, 0, -0.25, -0.6), "UpperTorso": (-6, 0, 0),
            "LeftUpperArm": (80, 0, 8), "LeftLowerArm": (60, 0, 0), "RightUpperArm": (80, 0, -8), "RightLowerArm": (60, 0, 0),
            "LeftUpperLeg": (26, 0, -4), "LeftLowerLeg": (-26, 0, 0), "RightUpperLeg": (-16, 0, 4), "RightLowerLeg": (-16, 0, 0)}, "Cubic", "In"),
    (0.5, {"LowerTorso": (0, 0, 0, 0, -0.4, -1.3), "UpperTorso": (-30, 0, 0), "Head": (22, 0, 0),
           "LeftUpperArm": (112, 0, 4), "LeftLowerArm": (8, 0, 0), "RightUpperArm": (112, 0, -4), "RightLowerArm": (8, 0, 0),
           "LeftUpperLeg": (48, 0, -4), "LeftLowerLeg": (-40, 0, 0), "RightUpperLeg": (-34, 0, 4), "RightLowerLeg": (-10, 0, 0), "RightFoot": (30, 0, 0)}, "CubicV2", "InOut"),
    (0.95, {"LowerTorso": (0, 0, 0, 0, -0.35, -1.1), "UpperTorso": (-18, 0, 0), "Head": (14, 0, 0),
            "LeftUpperArm": (70, 0, -6), "LeftLowerArm": (30, 0, 0), "RightUpperArm": (70, 0, 6), "RightLowerArm": (30, 0, 0),
            "LeftUpperLeg": (40, 0, -4), "LeftLowerLeg": (-36, 0, 0), "RightUpperLeg": (-26, 0, 4), "RightLowerLeg": (-14, 0, 0), "RightFoot": (24, 0, 0)}, "CubicV2", "InOut"),
    (1.6, STANCE, "Linear", "InOut"),
])
_JOLT = {"LowerTorso": (-8, 0, 0, 0, -0.3, -1.7), "UpperTorso": (24, 0, 0), "Head": (30, 0, 0),
         "LeftUpperArm": (40, 0, -70), "LeftLowerArm": (70, 0, 0), "RightUpperArm": (40, 0, 70), "RightLowerArm": (70, 0, 0),
         "LeftUpperLeg": (20, 0, -10), "LeftLowerLeg": (-30, 0, 0), "RightUpperLeg": (-10, 0, 10), "RightLowerLeg": (-40, 0, 0)}
TAKEDOWN_SLAM_VICTIM = held([
    (0.0, {}, "Cubic", "Out"),
    (0.28, {"LowerTorso": (4, 0, 0, 0, 0, 0.1), "UpperTorso": (12, 0, 0), "Head": (16, 20, 0),
            "LeftUpperArm": (30, 0, -40), "LeftLowerArm": (60, 0, 0), "RightUpperArm": (30, 0, 40), "RightLowerArm": (60, 0, 0)}, "Cubic", "In"),
    (0.5, {"LowerTorso": (-28, 0, 0, 0, -0.3, -1.6), "UpperTorso": (-30, 0, 0), "Head": (10, 0, 0),
           "LeftUpperArm": (110, 0, -10), "LeftLowerArm": (30, 0, 0), "RightUpperArm": (110, 0, 10), "RightLowerArm": (30, 0, 0),
           "LeftUpperLeg": (40, 0, -6), "LeftLowerLeg": (-30, 0, 0), "RightUpperLeg": (-20, 0, 6), "RightLowerLeg": (-30, 0, 0)}, "Linear", "InOut"),
    (0.58, _JOLT, "Linear", "InOut"),
    (0.7, merge(_JOLT, {"UpperTorso": (10, 10, 0), "Head": (10, -16, 0), "LeftUpperArm": (60, 0, -50), "RightUpperArm": (20, 0, 80)}), "Linear", "InOut"),
    (0.82, merge(_JOLT, {"UpperTorso": (26, -10, 0), "Head": (34, 14, 0), "LeftUpperArm": (20, 0, -84), "RightUpperArm": (60, 0, 50)}), "Linear", "InOut"),
    (0.95, merge(_JOLT, {"UpperTorso": (8, 0, 0), "Head": (4, 0, 0)}), "CubicV2", "InOut"),
    (1.6, fallen(0.6), "Linear", "InOut"),
])
# a body on the floor (the server has turned the whole rig face down; the limbs lie where they fell)
DOWNED = dict(length=2.0, loop=True, priority="Action", keys=[(0.0, _DOWN, "Linear", "InOut"), (2.0, _DOWN, "Linear", "InOut")])

# ---------- the train (client/Intro.lua): seated on the bench under a cloak, up, cloak off, pistol out, slide racked ----------
# The root stands in front of the seat at standing height (car-local (-3.75, 3, 12)); sitting is the hips 1.4 back
# and 0.88 down from it. On the one-piece Conduit (figures.py: hip joint 0.33 under the root, thigh 0.295 thick,
# thigh 1.25 long, knee to sole 1.60) that rests the thigh's underside on the cushion (top y 1.5) with the soles on
# the floor; the old 1.11 sank the new, longer-legged body 0.23 into the seat.
_SEAT = {"LowerTorso": (0, 0, 0, 0, -0.88, 1.4), "UpperTorso": (-14, 0, 0), "Head": (-24, 0, 0),
         "LeftUpperLeg": (82, 0, -8), "LeftLowerLeg": (-82, 0, 0), "RightUpperLeg": (82, 0, 8), "RightLowerLeg": (-82, 0, 0),
         "LeftUpperArm": (36, 0, 8), "LeftLowerArm": (52, 0, 0), "RightUpperArm": (36, 0, -8), "RightLowerArm": (52, 0, 0)}
INTRO_SEATED = dict(length=3.2, loop=True, priority="Action", keys=[  # the car rocks him a little
    (0.0, _SEAT, "CubicV2", "InOut"),
    (0.8, merge(_SEAT, {"UpperTorso": (-14, 0, 2.5), "Head": (-24, 0, -2)}), "CubicV2", "InOut"),
    (1.6, merge(_SEAT, {"UpperTorso": (-15, 0, 0), "Head": (-23, 0, 0)}), "CubicV2", "InOut"),
    (2.4, merge(_SEAT, {"UpperTorso": (-14, 0, -2.5), "Head": (-24, 0, 2)}), "CubicV2", "InOut"),
    (3.2, _SEAT, "Linear", "InOut"),
])
_UP = {"LowerTorso": (0, 0, 0), "UpperTorso": (-2, 0, 0), "Head": (-10, 0, 0),
       "LeftUpperLeg": (4, 0, -5), "LeftLowerLeg": (-6, 0, 0), "RightUpperLeg": (-2, 0, 5), "RightLowerLeg": (-4, 0, 0),
       "LeftUpperArm": (4, 0, -6), "LeftLowerArm": (12, 0, 0), "LeftHand": (0, 0, 0), "RightUpperArm": (4, 0, 6), "RightLowerArm": (12, 0, 0), "RightHand": (0, 0, 0)}
INTRO_STAND = dict(length=9.0, loop=False, priority="Action", keys=[
    (0.0, _SEAT, "CubicV2", "InOut"),
    (0.45, merge(_SEAT, {"LowerTorso": (0, 0, 0, 0, -1.05, 1.25), "UpperTorso": (-38, 0, 0), "Head": (-6, 0, 0),
                         "LeftUpperArm": (20, 0, 6), "LeftLowerArm": (70, 0, 0), "RightUpperArm": (20, 0, -6), "RightLowerArm": (70, 0, 0)}), "CubicV2", "InOut"),
    (1.0, merge(_UP, {"LowerTorso": (0, 0, 0, 0, -0.3, 0.45), "UpperTorso": (-22, 0, 0), "Head": (0, 0, 0),
                      "LeftUpperLeg": (48, 0, -6), "LeftLowerLeg": (-56, 0, 0), "RightUpperLeg": (30, 0, 6), "RightLowerLeg": (-50, 0, 0)}), "CubicV2", "InOut"),
    (1.5, _UP, "CubicV2", "InOut"),
    (2.3, merge(_UP, {"Head": (6, 0, 0)}), "Linear", "InOut"),                      # the head comes up
    (9.0, merge(_UP, {"Head": (6, 0, 0)}), "Linear", "InOut"),
])
INTRO_CLOAK = dict(length=1.9, loop=False, priority="Action2", keys=[
    (0.0, {"UpperTorso": (-2, 0, 0), "RightUpperArm": (4, 0, 6), "RightLowerArm": (12, 0, 0)}, "CubicV2", "InOut"),
    (0.4, {"UpperTorso": (-6, 14, 0), "Head": (4, 10, 0), "RightUpperArm": (72, 0, -62), "RightLowerArm": (118, 0, 0)}, "Cubic", "In"),  # hand to the clasp
    (0.55, {"UpperTorso": (-4, 4, 0), "Head": (4, 0, 0), "RightUpperArm": (84, 0, -10), "RightLowerArm": (60, 0, 0)}, "Linear", "InOut"),
    (0.75, {"UpperTorso": (4, -34, -4), "Head": (4, 26, 0), "LowerTorso": (0, -10, 0), "RightUpperArm": (62, 0, 96), "RightLowerArm": (10, 0, 0),
            "LeftUpperArm": (-10, 0, -22), "LeftLowerArm": (20, 0, 0)}, "CubicV2", "InOut"),                                   # thrown wide
    (1.15, {"UpperTorso": (2, -22, -2), "Head": (4, 18, 0), "LowerTorso": (0, -6, 0), "RightUpperArm": (10, 0, 70), "RightLowerArm": (16, 0, 0),
            "LeftUpperArm": (-4, 0, -14), "LeftLowerArm": (16, 0, 0)}, "CubicV2", "InOut"),
    (1.9, {"UpperTorso": (-2, 0, 0), "Head": (6, 0, 0), "RightUpperArm": (4, 0, 6), "RightLowerArm": (12, 0, 0), "LeftUpperArm": (4, 0, -6), "LeftLowerArm": (12, 0, 0)}, "Linear", "InOut"),
])
# The pistol is held by its grip (common/HeldWeapons.HandgunGrip); the arm angles from here down to Cover_Idle were
# solved by inverse kinematics on the real Conduit body for that grip (2026-11-13): change them together.
_READY = {"RightUpperArm": (39, 16, 0), "RightLowerArm": (72, -8, 0), "RightHand": (-36, -9, 21), "UpperTorso": (-4, 8, 0), "Head": (2, -8, 0)}
INTRO_DRAW = dict(length=6.0, loop=False, priority="Action2", keys=[
    (0.0, {"RightUpperArm": (4, 0, 6), "RightLowerArm": (12, 0, 0)}, "CubicV2", "InOut"),
    (0.36, {"RightUpperArm": (-24, 0, 12), "RightLowerArm": (38, 0, 0), "UpperTorso": (-4, -10, -3), "Head": (-10, -16, 0)}, "Cubic", "In"),  # to the holster
    (0.5, {"RightUpperArm": (-30, 0, 14), "RightLowerArm": (80, 0, 0), "UpperTorso": (-2, -8, -2), "Head": (-6, -12, 0)}, "CubicV2", "InOut"),  # clears it
    (0.85, _READY, "CubicV2", "InOut"),                                                                                                  # up in front of the chest
    (6.0, _READY, "Linear", "InOut"),
])
_OVER = {"LeftUpperArm": (105, -29, 40), "LeftLowerArm": (1, -36, 0), "LeftHand": (61, 2, 18), "Head": (-10, -8, 0)}
INTRO_RACK = dict(length=1.3, loop=False, priority="Action3", keys=[
    (0.0, {"LeftUpperArm": (4, 0, -6), "LeftLowerArm": (12, 0, 0)}, "CubicV2", "InOut"),
    (0.42, _OVER, "Cubic", "In"),                                                                         # the hand comes over the slide
    (0.55, merge(_OVER, {"LeftUpperArm": (107, -27, 42), "LeftLowerArm": (1, -36, 0), "LeftHand": (58, 2, 18)}), "Cubic", "Out"),     # back
    (0.66, merge(_OVER, {"LeftUpperArm": (91, -43, 28), "LeftLowerArm": (49, -16, 0), "LeftHand": (33, 3, 20)}), "CubicV2", "InOut"),   # let go: it runs home
    (1.3, {"LeftUpperArm": (4, 0, -6), "LeftLowerArm": (12, 0, 0), "Head": (6, 0, 0)}, "Linear", "InOut"),
])

# ---------- Metal Gear handling (2026-11-11): prone, the pistol, hands up, CQC, the wall ----------
# Prone: the root stays at standing height (the humanoid is not resized); the hips drop 2.25 and the body turns
# face down, shifted back 0.8 so the body's middle is over the root. Elbows under the shoulders, head up.
PRONE = {"LowerTorso": (-84, 0, 0, 0, -2.25, 0.8), "UpperTorso": (14, 0, 0), "Head": (58, 0, 0),
         "LeftUpperArm": (75, 0, -10), "LeftLowerArm": (85, 0, 0), "RightUpperArm": (75, 0, 10), "RightLowerArm": (85, 0, 0),
         "LeftUpperLeg": (-4, 0, -9), "LeftLowerLeg": (-4, 0, 0), "LeftFoot": (48, 0, 0),
         "RightUpperLeg": (-4, 0, 9), "RightLowerLeg": (-4, 0, 0), "RightFoot": (48, 0, 0)}
PRONE_IDLE = dict(length=3.0, loop=True, priority="Idle", keys=[
    (0.0, PRONE, "CubicV2", "InOut"),
    (1.5, merge(PRONE, {"UpperTorso": (16, 0, 0), "Head": (56, 6, 0)}), "CubicV2", "InOut"),
    (3.0, PRONE, "Linear", "InOut"),
])
_CRAWL = merge(PRONE, {"LowerTorso": (-84, 0, 5, 0, -2.25, 0.8), "UpperTorso": (12, -6, 0), "Head": (58, 4, 0),
                       "LeftUpperArm": (112, 0, -14), "LeftLowerArm": (48, 0, 0), "RightUpperArm": (58, 0, 12), "RightLowerArm": (100, 0, 0),
                       "RightUpperLeg": (46, 0, 34), "RightLowerLeg": (-78, 0, 0), "LeftUpperLeg": (-6, 0, -6), "LeftLowerLeg": (-2, 0, 0)})
PRONE_CRAWL = dict(length=1.2, loop=True, priority="Movement", keys=[
    (0.0, _CRAWL, "CubicV2", "InOut"), (0.3, PRONE, "CubicV2", "InOut"),
    (0.6, mirror(_CRAWL), "CubicV2", "InOut"), (0.9, PRONE, "CubicV2", "InOut"), (1.2, _CRAWL, "Linear", "InOut"),
])
def prone_roll(sign):
    tuck = {"UpperTorso": (4, 0, 0), "Head": (30, 0, 0), "LeftUpperArm": (165, 0, -6), "LeftLowerArm": (20, 0, 0),
            "RightUpperArm": (165, 0, 6), "RightLowerArm": (20, 0, 0), "LeftUpperLeg": (0, 0, -3), "RightUpperLeg": (0, 0, 3)}
    keys = []
    for i in range(5):
        keys.append((0.1 * i, merge(tuck, {"LowerTorso": (-84, sign * 90 * i, 0, 0, -2.25, 0.8)}), "Linear", "InOut"))
    return dict(length=0.4, loop=False, priority="Action", keys=keys)
PRONE_ROLL_L, PRONE_ROLL_R = prone_roll(-1), prone_roll(1)

# The pistol, arms only (the legs and body are whatever the stance is doing).
_P_READY = {"RightUpperArm": (53, 21, -13), "RightLowerArm": (44, -12, 0), "RightHand": (-24, -6, 24),
            "LeftUpperArm": (70, -15, 22), "LeftLowerArm": (15, 40, 0), "LeftHand": (-44, 14, -24)}
PISTOL_READY = dict(length=2.4, loop=True, priority="Action", keys=[   # low ready: both hands, arms long, muzzle 20 degrees down
    (0.0, _P_READY, "CubicV2", "InOut"),
    (1.2, merge(_P_READY, {"RightLowerArm": (46, -12, 0), "RightHand": (-25, -6, 24), "LeftUpperArm": (69, -16, 22), "LeftLowerArm": (18, 40, 0)}), "CubicV2", "InOut"),
    (2.4, _P_READY, "Linear", "InOut"),
])
# aimed: the grip at chin height 1.95 ahead, the bore level and dead ahead, the off hand wrapped over the firing hand
_AIM = {"UpperTorso": (-2, -6, 0), "Head": (0, 6, 0), "RightUpperArm": (104, 11, -23), "RightLowerArm": (8, -12, 0), "RightHand": (-17, -4, 18),
        "LeftUpperArm": (99, -7, 17), "LeftLowerArm": (19, 36, 0), "LeftHand": (-56, 19, -30)}
AIM_PISTOL = dict(length=2.0, loop=True, priority="Action2", keys=[
    (0.0, _AIM, "CubicV2", "InOut"), (1.0, merge(_AIM, {"RightUpperArm": (105, 10, -23), "RightLowerArm": (6, -12, 0), "RightHand": (-16, -4, 18)}), "CubicV2", "InOut"), (2.0, _AIM, "Linear", "InOut"),
])
# the reload: the gun up by the chest, turned in and canted so the well faces the off hand
_P_RELOAD = {"RightUpperArm": (32, 24, -8), "RightLowerArm": (117, -20, 0), "RightHand": (-35, -10, 24), "Head": (10, -10, 0)}
RELOAD_PISTOL = dict(length=1.5, loop=False, priority="Action3", keys=[
    (0.0, _P_READY, "CubicV2", "InOut"),
    (0.25, merge(_P_RELOAD, {"LeftUpperArm": (-8, 0, -8), "LeftLowerArm": (46, 0, 0), "LeftHand": (0, 0, 0)}), "CubicV2", "InOut"),   # hand to the belt
    (0.6, merge(_P_RELOAD, {"LeftUpperArm": (-12, 0, -10), "LeftLowerArm": (30, 0, 0), "LeftHand": (0, 0, 0)}), "CubicV2", "InOut"),
    (0.9, merge(_P_RELOAD, {"LeftUpperArm": (95, -75, 31), "LeftLowerArm": (73, -120, 0), "LeftHand": (-60, -6, -84)}), "Cubic", "In"),  # palm under the magazine
    (1.05, merge(_P_RELOAD, {"LeftUpperArm": (99, -74, 33), "LeftLowerArm": (72, -120, 0), "LeftHand": (-59, -6, -83), "Head": (8, -8, 0)}), "CubicV2", "InOut"),  # driven home
    (1.5, _P_READY, "Linear", "InOut"),
])
# A long gun in two hands (owner, 2026-11-12: the 5.56 carbine, the AK-47, the Garand). The right hand has the
# grip, the left hand the handguard. The angles were solved by forward kinematics on the skinned body (shoulders
# 0.86 out) for common/HeldWeapons GRIPS.Shoulder, which is the same solve: with _AIM_RIFLE the bore is level and
# dead ahead, the butt in the right shoulder. Change the grip and these together.
_RIFLE_READY = {"UpperTorso": (-2, -16, 0), "Head": (0, 14, 0), "RightUpperArm": (-20, 44, 29), "RightLowerArm": (127, 0, 0), "RightHand": (0, 0, 0),
                "LeftUpperArm": (24, -22, 16), "LeftLowerArm": (82, 0, 0)}
RIFLE_READY = dict(length=2.6, loop=True, priority="Action", keys=[   # muzzle down and a little left, across the chest
    (0.0, _RIFLE_READY, "CubicV2", "InOut"),
    (1.3, merge(_RIFLE_READY, {"RightUpperArm": (-19, 44, 29), "LeftUpperArm": (25, -22, 16)}), "CubicV2", "InOut"),
    (2.6, _RIFLE_READY, "Linear", "InOut"),
])
_AIM_RIFLE = {"UpperTorso": (-2, -24, 0), "Head": (0, 22, 0), "RightUpperArm": (18, 44, 3), "RightLowerArm": (120, 0, 0), "RightHand": (0, 0, 0),
              "LeftUpperArm": (50, -35, -2), "LeftLowerArm": (80, 0, 0)}
AIM_RIFLE = dict(length=2.2, loop=True, priority="Action2", keys=[
    (0.0, _AIM_RIFLE, "CubicV2", "InOut"), (1.1, merge(_AIM_RIFLE, {"LeftUpperArm": (51, -35, -2)}), "CubicV2", "InOut"), (2.2, _AIM_RIFLE, "Linear", "InOut"),
])
_RELOAD_R = {"UpperTorso": (-2, -16, 0), "Head": (12, 10, 0), "RightUpperArm": (-16, 42, 28), "RightLowerArm": (125, 0, 0), "RightHand": (25, 0, -2)}  # muzzle up a little, the well turned in
RELOAD_RIFLE = dict(length=2.2, loop=False, priority="Action3", keys=[
    (0.0, _RIFLE_READY, "CubicV2", "InOut"),
    (0.3, merge(_RELOAD_R, {"LeftUpperArm": (11, -29, 20), "LeftLowerArm": (88, 0, 0)}), "CubicV2", "InOut"),   # hand to the magazine
    (0.55, merge(_RELOAD_R, {"LeftUpperArm": (0, -20, 14), "LeftLowerArm": (70, 0, 0)}), "CubicV2", "InOut"),   # it comes out and down
    (0.95, merge(_RELOAD_R, {"LeftUpperArm": (-8, 0, 16), "LeftLowerArm": (112, 0, 0)}), "CubicV2", "InOut"),   # to the pouch on the chest
    (1.4, merge(_RELOAD_R, {"LeftUpperArm": (6, -24, 18), "LeftLowerArm": (78, 0, 0)}), "Cubic", "In"),         # the fresh one comes up under the well
    (1.6, merge(_RELOAD_R, {"LeftUpperArm": (11, -29, 20), "LeftLowerArm": (90, 0, 0)}), "CubicV2", "InOut"),   # and is driven home
    (1.85, merge(_RELOAD_R, {"LeftUpperArm": (33, -26, 14), "LeftLowerArm": (94, 0, 0), "RightHand": (12, 0, 0)}), "CubicV2", "InOut"),
    (2.2, _RIFLE_READY, "Linear", "InOut"),
])
# Hands up (a guard with a gun on him): upper arms straight out, forearms straight up. (90, 0, -90) is the left
# arm out to the side rolled so the elbow folds upward.
_UP_HANDS = {"UpperTorso": (4, 0, 0), "Head": (-6, 0, 0), "LeftUpperArm": (90, 0, -90), "LeftLowerArm": (88, 0, 0),
             "RightUpperArm": (90, 0, 90), "RightLowerArm": (88, 0, 0), "LeftUpperLeg": (4, 0, -6), "RightUpperLeg": (4, 0, 6)}
HANDS_UP = dict(length=1.6, loop=True, priority="Action", keys=[
    (0.0, _UP_HANDS, "CubicV2", "InOut"),
    (0.8, merge(_UP_HANDS, {"LeftLowerArm": (84, 0, 0), "RightLowerArm": (92, 0, 0), "Head": (-6, 5, 0)}), "CubicV2", "InOut"),
    (1.6, _UP_HANDS, "Linear", "InOut"),
])
# The throw, face to face 1.5 apart: catch him, turn left, and he goes down past your left side (his right):
# the server lays him 1.4 ahead and 1.3 to his right of where he stood.
TAKEDOWN_THROW = dict(length=1.6, loop=False, priority="Action", keys=[
    (0.0, STANCE, "Cubic", "Out"),
    (0.25, {"LowerTorso": (0, 0, 0, 0, -0.15, -0.45), "UpperTorso": (-10, 0, 0), "LeftUpperArm": (82, 0, 12), "LeftLowerArm": (40, 0, 0), "RightUpperArm": (76, 0, -12), "RightLowerArm": (46, 0, 0),
            "LeftUpperLeg": (28, 0, -4), "LeftLowerLeg": (-26, 0, 0), "RightUpperLeg": (-18, 0, 4), "RightLowerLeg": (-16, 0, 0)}, "CubicV2", "InOut"),
    (0.6, {"LowerTorso": (0, 22, 0, 0, -0.25, -0.25), "UpperTorso": (-12, 48, 0), "Head": (4, -20, 0), "LeftUpperArm": (60, 0, -20), "LeftLowerArm": (60, 0, 0), "RightUpperArm": (84, 0, -30), "RightLowerArm": (30, 0, 0),
           "LeftUpperLeg": (20, 10, -8), "LeftLowerLeg": (-30, 0, 0), "RightUpperLeg": (-10, 0, 6), "RightLowerLeg": (-28, 0, 0)}, "Cubic", "In"),
    (1.0, {"LowerTorso": (0, 26, 0, 0, -0.55, -0.15), "UpperTorso": (-38, 62, 0), "Head": (14, -24, 0), "LeftUpperArm": (30, 0, -10), "LeftLowerArm": (20, 0, 0), "RightUpperArm": (52, 0, -24), "RightLowerArm": (12, 0, 0),
           "LeftUpperLeg": (48, 10, -8), "LeftLowerLeg": (-70, 0, 0), "RightUpperLeg": (4, 0, 6), "RightLowerLeg": (-50, 0, 0)}, "CubicV2", "InOut"),
    (1.6, STANCE, "Linear", "InOut"),
])
TAKEDOWN_THROW_VICTIM = held([
    (0.0, {}, "Cubic", "Out"),
    (0.25, {"LowerTorso": (-8, 0, 0, 0, -0.05, -0.25), "UpperTorso": (-10, 0, 0), "Head": (14, 0, 0), "LeftUpperArm": (50, 0, -30), "LeftLowerArm": (50, 0, 0), "RightUpperArm": (70, 0, 10), "RightLowerArm": (30, 0, 0)}, "Cubic", "In"),
    (0.6, {"LowerTorso": (-48, -30, 0, 0.7, -0.7, -0.9), "UpperTorso": (-16, -10, 0), "Head": (10, 20, 0), "LeftUpperArm": (120, 0, -50), "LeftLowerArm": (30, 0, 0), "RightUpperArm": (100, 0, 20), "RightLowerArm": (20, 0, 0),
           "LeftUpperLeg": (-30, 0, -10), "LeftLowerLeg": (-40, 0, 0), "RightUpperLeg": (20, 0, 10), "RightLowerLeg": (-60, 0, 0)}, "Linear", "InOut"),
    (1.0, fallen(1.4, 1.3), "Linear", "InOut"),
    (1.6, fallen(1.4, 1.3), "Linear", "InOut"),
])
# Out of the neck hold: a shove in the back and he goes down on his face 1.4 ahead.
_HOLD_ARMS = {"UpperTorso": (0, 5, 0), "LeftUpperArm": (104, -92, 0), "LeftLowerArm": (100, 0, 0), "RightUpperArm": (118, 74, 0), "RightLowerArm": (104, 0, 0)}
TAKEDOWN_SHOVE = dict(length=1.6, loop=False, priority="Action", keys=[
    (0.0, _HOLD_ARMS, "Cubic", "In"),
    (0.3, {"LowerTorso": (0, 0, 0, 0, -0.1, -0.3), "UpperTorso": (-16, 0, 0), "LeftUpperArm": (92, 0, 8), "LeftLowerArm": (6, 0, 0), "RightUpperArm": (92, 0, -8), "RightLowerArm": (6, 0, 0),
           "LeftUpperLeg": (30, 0, -4), "LeftLowerLeg": (-24, 0, 0), "RightUpperLeg": (-20, 0, 4), "RightLowerLeg": (-10, 0, 0)}, "CubicV2", "InOut"),
    (0.9, {"LowerTorso": (0, 0, 0, 0, -0.05, -0.1), "UpperTorso": (-6, 0, 0), "LeftUpperArm": (40, 0, -8), "LeftLowerArm": (40, 0, 0), "RightUpperArm": (40, 0, 8), "RightLowerArm": (40, 0, 0)}, "CubicV2", "InOut"),
    (1.6, STANCE, "Linear", "InOut"),
])
TAKEDOWN_SHOVE_VICTIM = held([
    (0.0, {"LowerTorso": (5, 0, 0, 0, -0.15, 0.1), "UpperTorso": (7, 0, 0), "Head": (12, 0, 0)}, "Cubic", "In"),
    (0.3, {"LowerTorso": (-22, 0, 0, 0, -0.15, -0.5), "UpperTorso": (-10, 0, 0), "Head": (20, 0, 0), "LeftUpperArm": (60, 0, -50), "LeftLowerArm": (30, 0, 0), "RightUpperArm": (80, 0, 40), "RightLowerArm": (20, 0, 0),
           "LeftUpperLeg": (50, 0, -6), "LeftLowerLeg": (-40, 0, 0), "RightUpperLeg": (-20, 0, 6), "RightLowerLeg": (-30, 0, 0)}, "Linear", "InOut"),
    (0.65, {"LowerTorso": (-62, 0, 0, 0, -1.2, -1.1), "UpperTorso": (-10, 0, 0), "Head": (24, 0, 0), "LeftUpperArm": (130, 0, -30), "LeftLowerArm": (40, 0, 0), "RightUpperArm": (130, 0, 30), "RightLowerArm": (40, 0, 0),
            "LeftUpperLeg": (20, 0, -8), "LeftLowerLeg": (-70, 0, 0), "RightUpperLeg": (-10, 0, 8), "RightLowerLeg": (-40, 0, 0)}, "Cubic", "In"),
    (1.0, fallen(1.4), "Linear", "InOut"),
    (1.6, fallen(1.4), "Linear", "InOut"),
])
# The neck hold while you walk him (arms and chest only: your legs walk). He is 0.95 in front of you.
HOLD = dict(length=2.0, loop=True, priority="Action", keys=[
    (0.0, _HOLD_ARMS, "CubicV2", "InOut"), (1.0, merge(_HOLD_ARMS, {"UpperTorso": (2, 3, 0), "LeftLowerArm": (104, 0, 0)}), "CubicV2", "InOut"), (2.0, _HOLD_ARMS, "Linear", "InOut"),
])
_HELD = {"LowerTorso": (5, 0, 0, 0, -0.15, 0.1), "UpperTorso": (7, 0, 0), "Head": (12, 0, 0),
         "LeftUpperArm": (100, 0, 24), "LeftLowerArm": (128, 0, 0), "RightUpperArm": (96, 0, -22), "RightLowerArm": (124, 0, 0),
         "LeftUpperLeg": (22, 0, -6), "LeftLowerLeg": (-34, 0, 0), "RightUpperLeg": (-8, 0, 6), "RightLowerLeg": (-22, 0, 0)}
HELD = dict(length=1.0, loop=True, priority="Action", keys=[   # dragged backwards on his heels, pulling at the arm
    (0.0, _HELD, "CubicV2", "InOut"),
    (0.5, merge(_HELD, {"LowerTorso": (5, 4, 0, 0.04, -0.2, 0.1), "UpperTorso": (8, -6, 0), "Head": (10, 8, 0),
                        "LeftUpperLeg": (-8, 0, -6), "LeftLowerLeg": (-22, 0, 0), "RightUpperLeg": (22, 0, 6), "RightLowerLeg": (-34, 0, 0)}), "CubicV2", "InOut"),
    (1.0, _HELD, "Linear", "InOut"),
])
# A body over the right shoulder (arms and chest only).
_CARRY = {"UpperTorso": (-8, 0, -4), "Head": (4, 8, 0), "RightUpperArm": (150, 0, 12), "RightLowerArm": (64, 0, 0), "LeftUpperArm": (24, 0, -10), "LeftLowerArm": (34, 0, 0)}
CARRY = dict(length=2.0, loop=True, priority="Action", keys=[
    (0.0, _CARRY, "CubicV2", "InOut"), (1.0, merge(_CARRY, {"UpperTorso": (-9, 0, -3)}), "CubicV2", "InOut"), (2.0, _CARRY, "Linear", "InOut"),
])
# Back to a wall, the pistol up by the right shoulder.
_COVER = {"LowerTorso": (0, 0, 0, 0, -0.12, 0.2), "UpperTorso": (5, 0, 0), "Head": (-4, 0, 0),
          "RightUpperArm": (13, 15, 7), "RightLowerArm": (116, 20, 0), "RightHand": (20, 8, 24), "LeftUpperArm": (6, 0, -10), "LeftLowerArm": (24, 0, 0),
          "LeftUpperLeg": (14, 0, -6), "LeftLowerLeg": (-22, 0, 0), "RightUpperLeg": (10, 0, 6), "RightLowerLeg": (-18, 0, 0)}
COVER_IDLE = dict(length=2.6, loop=True, priority="Action", keys=[
    (0.0, _COVER, "CubicV2", "InOut"), (1.3, merge(_COVER, {"UpperTorso": (6, 0, 0), "Head": (-4, 6, 0)}), "CubicV2", "InOut"), (2.6, _COVER, "Linear", "InOut"),
])

ANIMS = {
    "Prone_Idle": PRONE_IDLE, "Prone_Crawl": PRONE_CRAWL, "Prone_RollL": PRONE_ROLL_L, "Prone_RollR": PRONE_ROLL_R,
    "Rifle_Ready": RIFLE_READY, "Aim_Rifle": AIM_RIFLE, "Reload_Rifle": RELOAD_RIFLE,
    "Pistol_Ready": PISTOL_READY, "Aim_Pistol": AIM_PISTOL, "Reload_Pistol": RELOAD_PISTOL, "HandsUp": HANDS_UP,
    "Takedown_Throw": TAKEDOWN_THROW, "Takedown_ThrowVictim": TAKEDOWN_THROW_VICTIM, "Takedown_Shove": TAKEDOWN_SHOVE,
    "Takedown_ShoveVictim": TAKEDOWN_SHOVE_VICTIM, "Hold": HOLD, "Held": HELD, "Carry": CARRY, "Cover_Idle": COVER_IDLE,
    "Swing_SlashR": SLASH_R, "Swing_SlashL": SLASH_L, "Swing_Overhead": OVERHEAD, "Swing_Diagonal": DIAGONAL,
    "Swing_Uppercut": UPPERCUT, "Swing_Thrust": THRUST, "Swing_Jab": JAB,
    "Hit_Front": HIT_FRONT, "Hit_Left": HIT_LEFT, "Hit_Right": HIT_RIGHT, "Hit_High": HIT_HIGH,
    "Stagger": STAGGER, "Recoil": RECOIL, "Block": BLOCK, "Parry": PARRY, "Hit_Heavy": HIT_HEAVY, "Block_Hit": BLOCK_HIT,
    "Idle": IDLE, "Walk": WALK, "Run": RUN,
    "Step_Left": STEP_LEFT, "Step_Right": STEP_RIGHT, "Step_Back": STEP_BACK,
    "Crouch_Idle": CROUCH_IDLE, "Crouch_Walk": CROUCH_WALK, "Downed": DOWNED,
    "Takedown_Rear": TAKEDOWN_REAR, "Takedown_RearVictim": TAKEDOWN_REAR_VICTIM, "Takedown_Drop": TAKEDOWN_DROP,
    "Takedown_DropVictim": TAKEDOWN_DROP_VICTIM, "Takedown_Slam": TAKEDOWN_SLAM, "Takedown_SlamVictim": TAKEDOWN_SLAM_VICTIM,
    "Intro_Seated": INTRO_SEATED, "Intro_Stand": INTRO_STAND, "Intro_CloakToss": INTRO_CLOAK, "Intro_Draw": INTRO_DRAW, "Intro_Rack": INTRO_RACK,
}
PRIORITY = {"Core": 1000, "Idle": 0, "Movement": 1, "Action": 2, "Action2": 3, "Action3": 4}

# ---------- maths ----------
def rot(rx, ry, rz):
    """CFrame.Angles(rx, ry, rz) rotation matrix (= Rx * Ry * Rz), degrees."""
    x, y, z = math.radians(rx), math.radians(ry), math.radians(rz)
    cx, sx, cy, sy, cz, sz = math.cos(x), math.sin(x), math.cos(y), math.sin(y), math.cos(z), math.sin(z)
    Rx = [[1, 0, 0], [0, cx, -sx], [0, sx, cx]]
    Ry = [[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]]
    Rz = [[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]]
    return mm(mm(Rx, Ry), Rz)

def mm(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]

def mv(a, v):
    return [sum(a[i][k] * v[k] for k in range(3)) for i in range(3)]

def full(v):
    v = list(v) + [0] * (6 - len(v))
    return v

# ---------- rbxmx ----------
def cf_xml(v):
    v = full(v)
    R = rot(v[0], v[1], v[2])
    return ("<CoordinateFrame name=\"CFrame\"><X>%g</X><Y>%g</Y><Z>%g</Z>" % (v[3], v[4], v[5]) +
            "".join("<R%d%d>%.6f</R%d%d>" % (i, j, R[i][j], i, j) for i in range(3) for j in range(3)) + "</CoordinateFrame>")

def write_rbxmx(name, a, path):
    ref = [0]
    def nref():
        ref[0] += 1
        return "RBX%d" % ref[0]
    used = set()
    for _, pose, _, _ in a["keys"]:
        used.update(pose.keys())
    if name.startswith("Swing_"):
        used.update(RIGHT_ARM)
    def needed(part):  # a part is written if it or a descendant is keyed
        return part in used or any(needed(c) for c, p in TREE.items() if p == part)
    out = ['<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
           'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">',
           '<Item class="KeyframeSequence" referent="%s"><Properties><string name="Name">%s</string><bool name="Loop">%s</bool>'
           '<token name="Priority">%d</token></Properties>' % (nref(), name, "true" if a["loop"] else "false", PRIORITY[a["priority"]])]
    for t, pose, style, direction in a["keys"]:
        out.append('<Item class="Keyframe" referent="%s"><Properties><string name="Name">Keyframe</string><float name="Time">%g</float></Properties>' % (nref(), t))
        def emit(part):
            keyed = part in used
            v = pose.get(part, (0, 0, 0))
            out.append('<Item class="Pose" referent="%s"><Properties><string name="Name">%s</string><float name="Weight">%g</float>'
                       '<token name="EasingStyle">%d</token><token name="EasingDirection">%d</token>%s</Properties>'
                       % (nref(), part, 1 if keyed else 0, STYLE[style], DIR[direction], cf_xml(v)))
            for c in [c for c in ORDER if TREE[c] == part and needed(c)]:
                emit(c)
            out.append("</Item>")
        out.append('<Item class="Pose" referent="%s"><Properties><string name="Name">HumanoidRootPart</string><float name="Weight">0</float>%s</Properties>' % (nref(), cf_xml((0, 0, 0))))
        emit("LowerTorso")
        out.append("</Item></Item>")
    out.append("</Item></roblox>")
    open(path, "w").write("\n".join(out))

# ---------- stick-figure preview (forward kinematics on the Conduit's proportions) ----------
JOINT_AT = {  # where each part's joint to its parent sits at rest (studs, root at the LowerTorso centre)
    "LowerTorso": (0, 0, 0), "UpperTorso": (0, 0.35, 0), "Head": (0, 1.85, 0),
    "LeftUpperArm": (-1.31, 1.63, 0), "LeftLowerArm": (-1.31, 0.63, 0), "LeftHand": (-1.31, -0.32, 0),
    "RightUpperArm": (1.31, 1.63, 0), "RightLowerArm": (1.31, 0.63, 0), "RightHand": (1.31, -0.32, 0),
    "LeftUpperLeg": (-0.48, -0.35, 0), "LeftLowerLeg": (-0.48, -1.4, 0), "LeftFoot": (-0.48, -2.4, 0),
    "RightUpperLeg": (0.48, -0.35, 0), "RightLowerLeg": (0.48, -1.4, 0), "RightFoot": (0.48, -2.4, 0),
}
TIP = {"Head": (0, 3.05, 0), "LeftHand": (-1.31, -0.74, 0), "RightHand": (1.31, -0.74, 0),
       "LeftFoot": (-0.48, -2.82, -0.6), "RightFoot": (0.48, -2.82, -0.6), "UpperTorso": (0, 1.85, 0)}

def fk(pose):
    world = {"HumanoidRootPart": ([[1, 0, 0], [0, 1, 0], [0, 0, 1]], [0, 0, 0])}
    for part in ORDER:
        pr, pp = world[TREE[part]]
        j = JOINT_AT[part]
        pj = JOINT_AT.get(TREE[part], (0, 0, 0))
        v = full(pose.get(part, (0, 0, 0)))
        origin = [a + b for a, b in zip(mv(pr, [j[i] - pj[i] + v[3 + i] for i in range(3)]), pp)]
        world[part] = (mm(pr, rot(v[0], v[1], v[2])), origin)
    pts = {}
    for part in ORDER:
        R, o = world[part]
        j = JOINT_AT[part]
        pts[part] = o
        if part in TIP:
            t = TIP[part]
            pts[part + "_tip"] = [a + b for a, b in zip(mv(R, [t[i] - j[i] for i in range(3)]), o)]
    return pts

BONES = [("LowerTorso", "UpperTorso"), ("UpperTorso", "UpperTorso_tip"), ("UpperTorso_tip", "Head_tip"),
         ("LeftUpperArm", "LeftLowerArm"), ("LeftLowerArm", "LeftHand"), ("LeftHand", "LeftHand_tip"),
         ("RightUpperArm", "RightLowerArm"), ("RightLowerArm", "RightHand"), ("RightHand", "RightHand_tip"),
         ("LeftUpperLeg", "LeftLowerLeg"), ("LeftLowerLeg", "LeftFoot"), ("LeftFoot", "LeftFoot_tip"),
         ("RightUpperLeg", "RightLowerLeg"), ("RightLowerLeg", "RightFoot"), ("RightFoot", "RightFoot_tip"),
         ("LeftUpperLeg", "RightUpperLeg"), ("LeftUpperArm", "RightUpperArm")]

def sheet(name, a, path):
    from PIL import Image, ImageDraw
    keys = a["keys"]
    W, H = 150, 190
    img = Image.new("RGB", (W * len(keys), H * 2), (24, 26, 32))
    d = ImageDraw.Draw(img)
    for i, (t, pose, _, _) in enumerate(keys):
        pts = fk(pose)
        for row, (axis, label) in enumerate(((0, "front"), (2, "side"))):
            ox, oy = W * i + W / 2, H * row + H * 0.52
            def P(p):
                h = p[axis] if axis == 0 else -p[2]  # side view: forward (-Z) to the right
                return (ox + h * 22, oy - p[1] * 22)
            for a1, b1 in BONES:
                if a1 in pts and b1 in pts:
                    col = (90, 200, 255) if ("Left" in a1 or "Left" in b1) and not ("Right" in a1) else (255, 150, 90) if "Right" in a1 or "Right" in b1 else (220, 220, 230)
                    d.line([P(pts[a1]), P(pts[b1])], fill=col, width=3)
            d.line([(W * i + 10, oy + 2.82 * 22), (W * i + W - 10, oy + 2.82 * 22)], fill=(60, 60, 70))
            d.text((W * i + 4, H * row + 4), "%s t=%.2f %s" % (name if i == 0 and row == 0 else "", t, label), fill=(170, 170, 180))
    img.save(path)

# ---------- upload ----------
def upload(name, path):
    key = os.environ["ROBLOX_API_KEY"]
    b = "----rbx" + uuid.uuid4().hex
    meta = json.dumps({"assetType": "Animation", "displayName": "Endeavor_" + name, "description": "Endeavor animation (tools/anims)",
                       "creationContext": {"creator": {"userId": "3155619052"}}})
    body = (f"--{b}\r\nContent-Disposition: form-data; name=\"request\"\r\nContent-Type: application/json\r\n\r\n{meta}\r\n"
            f"--{b}\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"{name}.rbxmx\"\r\nContent-Type: model/x-rbxm\r\n\r\n").encode() \
        + open(path, "rb").read() + f"\r\n--{b}--\r\n".encode()
    def req(method, url, data=None, ctype=None):
        r = urllib.request.Request(url, data=data, method=method, headers={"x-api-key": key, **({"Content-Type": ctype} if ctype else {})})
        try:
            with urllib.request.urlopen(r, timeout=180) as x:
                return x.status, json.loads(x.read().decode() or "{}")
        except urllib.error.HTTPError as e:
            return e.code, e.read().decode()
    code, op = req("POST", "https://apis.roblox.com/assets/v1/assets", body, f"multipart/form-data; boundary={b}")
    if code != 200:
        return None, f"{code} {op}"
    opid = op.get("operationId") or op.get("path", "").split("/")[-1]
    for _ in range(60):
        time.sleep(2)
        code, st = req("GET", f"https://apis.roblox.com/assets/v1/operations/{opid}")
        if isinstance(st, dict) and st.get("done"):
            r = st.get("response", {})
            return r.get("assetId"), r.get("moderationResult", {}).get("moderationState")
    return None, "timed out"

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    names = args or list(ANIMS)
    for name in names:
        a = ANIMS[name]
        path = os.path.join(OUT, name + ".rbxmx")
        write_rbxmx(name, a, path)
        sheet(name, a, os.path.join(OUT, name + ".png"))
        if "--upload" in sys.argv:
            asset, state = upload(name, path)
            print(name, asset, state)
        else:
            print("wrote", name)
