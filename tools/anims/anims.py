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

def react(peak, settle=None, length=0.5):
    settle = settle or {k: tuple(a * 0.35 for a in v) for k, v in peak.items()}
    return dict(length=length, loop=False, priority="Action", keys=[
        (0.0, {}, "Cubic", "Out"),
        (length * 0.14, peak, "Cubic", "Out"),
        (length * 0.45, settle, "CubicV2", "InOut"),
        (length, {}, "Linear", "InOut"),
    ])

ARMS_FLUNG = {"LeftUpperArm": (30, 0, -35), "LeftLowerArm": (30, 0, 0), "RightUpperArm": (30, 0, 35), "RightLowerArm": (30, 0, 0)}
HIT_FRONT = react(merge(ARMS_FLUNG, {"LowerTorso": (8, 0, 0, 0, -0.1, 0.35), "UpperTorso": (20, 0, 0), "Head": (24, 0, 0),
                                     "LeftUpperLeg": (-6, 0, 0), "RightUpperLeg": (-10, 0, 0), "RightLowerLeg": (-16, 0, 0)}))
# struck on the right side: the body twists and folds to the left, away from the blow
HIT_RIGHT = react(merge(ARMS_FLUNG, {"LowerTorso": (4, 10, 6, -0.3, -0.1, 0.1), "UpperTorso": (8, 26, 14), "Head": (6, 24, 16),
                                     "RightUpperArm": (10, 0, 50), "LeftUpperLeg": (0, 0, -8), "RightUpperLeg": (0, 0, -6)}))
HIT_LEFT = react(mirror(HIT_RIGHT["keys"][1][1]))
HIT_HIGH = react(merge(ARMS_FLUNG, {"LowerTorso": (6, 0, 0, 0, -0.05, 0.25), "UpperTorso": (14, 0, 0), "Head": (38, 0, 0),
                                    "LeftUpperArm": (50, 0, -30), "RightUpperArm": (50, 0, 30)}))
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
RECOIL = react(merge({"LowerTorso": (6, -8, 0, 0, -0.2, 0.4), "UpperTorso": (14, -16, 0), "Head": (8, 10, 0),
                      "LeftUpperArm": (20, 0, -40), "RightUpperLeg": (-14, 0, 6), "RightLowerLeg": (-24, 0, 0)}), length=0.45)
GUARD = {"LowerTorso": (0, -6, 0, 0, -0.25, 0.05), "UpperTorso": (-8, 6, 0), "Head": (6, -4, 0),
         "LeftUpperLeg": (18, 6, -6), "LeftLowerLeg": (-24, 0, 0), "LeftFoot": (6, 0, 0),
         "RightUpperLeg": (-10, 6, 6), "RightLowerLeg": (-22, 0, 0), "RightFoot": (16, 0, 0),
         "LeftUpperArm": (80, -10, 30), "LeftLowerArm": (80, 0, 0), "LeftHand": (0, 0, 0),
         "RightUpperArm": (85, 10, -10), "RightLowerArm": (50, 0, 0), "RightHand": (-40, 0, 0)}
BLOCK = dict(length=1.6, loop=True, priority="Action", keys=[
    (0.0, GUARD, "CubicV2", "InOut"),
    (0.8, merge(GUARD, {"UpperTorso": (-6, 6, 0), "LowerTorso": (0, -6, 0, 0, -0.22, 0.05)}), "CubicV2", "InOut"),
    (1.6, GUARD, "Linear", "InOut"),
])
PARRY = dict(length=0.4, loop=False, priority="Action", keys=[
    (0.0, GUARD, "Cubic", "Out"),
    (0.07, merge(GUARD, {"UpperTorso": (-4, -14, 0), "RightUpperArm": (100, 20, 20), "RightLowerArm": (20, 0, 0),
                         "LeftUpperArm": (60, 0, -30), "LowerTorso": (0, -14, 0, 0, -0.3, -0.15)}), "CubicV2", "InOut"),
    (0.4, GUARD, "Linear", "InOut"),
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

ANIMS = {
    "Swing_SlashR": SLASH_R, "Swing_SlashL": SLASH_L, "Swing_Overhead": OVERHEAD, "Swing_Diagonal": DIAGONAL,
    "Swing_Uppercut": UPPERCUT, "Swing_Thrust": THRUST, "Swing_Jab": JAB,
    "Hit_Front": HIT_FRONT, "Hit_Left": HIT_LEFT, "Hit_Right": HIT_RIGHT, "Hit_High": HIT_HIGH,
    "Stagger": STAGGER, "Recoil": RECOIL, "Block": BLOCK, "Parry": PARRY,
    "Idle": IDLE, "Walk": WALK, "Run": RUN,
    "Step_Left": STEP_LEFT, "Step_Right": STEP_RIGHT, "Step_Back": STEP_BACK,
}
PRIORITY = {"Core": 1000, "Idle": 0, "Movement": 1, "Action": 2}

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
