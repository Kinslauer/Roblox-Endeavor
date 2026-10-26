# Story 006: Keyframed attack combos + the Magoi polish pass (camera, bar, trails, dust, stances, hitstop, palette, prompts, nameplates)

> **Epic**: Combat Feel
> **Status**: Implemented, both passes (live-verified 2026-10-26; owner playtest pending)
> **Layer**: Presentation only
> **Type**: Visual/Feel
> **Estimate**: L
> **Last Updated**: 2026-10-26

## Context

**Owner (2026-10-26 11:25)**: "work on that [the Magoi polish order], and improved attack animations like the ones in
those three games; the simplest attack combo should come from the spear, and even then it's a multi-thrust and swipe."
**Reference**: `design/references/magoi-look-and-feel.md` (polish order items 1–3). **GDD**: `design/gdd/combat.md`
(Visual/Audio Requirements), `design/gdd/weapons.md` (attack chains).

**ADR Governing Implementation**: ADR-0004 (presentation layer, data slots). Timing still comes from the server's
`Swing` payload; nothing here changes an outcome.

---

## What was built

### Keyframed combos (`Presentation.Swings`, `client/SwingAnimator.lua`)
A swing is now a list of **Keys** on the whole upper body — right and left shoulder angles, a waist **Lean** (pitch) and
**Twist** (yaw), and a body **Dip** (the R15 Root joint sinks the torso) — at three phases: `Wind` (held at the end
of the windup), optional `Mid` keys inside the active frames (`Frac` 0..1), and `Strike`. The animator builds one
timeline per channel (start → Wind over `windup`, Sine; Wind → Mid → Strike over `active`, Quart; Strike → stance over
the recovery, Sine; guns hold at the strike for `HoldAfter`), and samples it every `Stepped`. Legacy `Pose / Swing /
Lean` entries still work (they become Wind + Strike). Every melee combo step has its own entry, keyed by the server's
combo index:

| Family | 1 | 2 | 3 | 4 | Heavy |
|---|---|---|---|---|---|
| **Spear** (the simplest) | thrust: wind right, drive forward, lean in | low thrust: a mid key, the body dips 0.3 | **swipe**: wound 40° right, sweeps to 40° left | — | lunge: dip 0.5, lean −25 |
| Blade (RebarBlade) | diagonal cut | rising reverse cut (mid key) | flat cut across (mid key) | overhead spin finisher, dip | overhead, dust |
| Blunt (PipeClub) | right-to-left swing | backhand (mid key) | overhead, dust | — | the big chop |
| Baton | jab | backhand (mid key) | overhead crack | — | braced crack |
| Fists | jab | cross (left arm) | hook (mid key) | uppercut, dip | haymaker |
| Hammer (Sledge) | flat sweep (mid key) | overhead, dust | — | — | slam: dip 0.6, dust 1.6 |

### Trails and dust
- `WeaponView.AddTrail`: every procedural melee weapon gets a `Trail` from grip to tip, off by default. SwingAnimator
  turns it on from just before the active frames to just after; `Trail` seconds of life per entry (longer on heavies),
  white for lights, amber for heavies (`Presentation.Swings.TrailColor / TrailHeavyColor`).
- `WorldFX.Dust(position, scale)`: a tan particle burst at the feet on **Dodge** (0.5), **EnemyStep** (0.7), a launched
  body's **Land** (1.1), and under any swing entry with `Dust` (heavies, overheads, the spear's swipe).

### Camera and HUD
- `Presentation.Aim.Melee = { Distance 15, ShoulderOffset (0.9, 1.4, 0) }` / `Ranged = { 9, (1.75, 0.5, 0) }`:
  `Aim.lua` applies the preset when the weapon type changes (pins the zoom for one frame, then lets the player scroll).
- One bottom-centre composite (`Hud.lua`): a 4 px charge strip, health (left) | stamina (right), a 5 px posture strip
  under them, the three skill slots directly below. Level and flick labels sit above the bar.

## Acceptance Criteria

- [x] Every melee combo step and heavy resolves to a keyed entry with a Wind and a Strike (smoke: 19 steps).
- [x] The spear's three are two thrusts and a swipe, each a distinct keyed swing (smoke).
- [x] Live: a spear combo drives shoulders, twist (−36..+49°), lean (−25..+12°) and dip (0.66 studs on the heavy).
- [x] Live: the Sledge's trail enables for the active frames of a light and a heavy (29 frames, white then amber,
      0.28 s life on the heavy); three dust puffs for a light sweep, a heavy and a dodge.
- [x] Live: the composite bar and hotbar sit bottom-centre at the designed offsets.
- [ ] Owner playtest: the spear combo reads as thrust, thrust, swipe; a heavy reads before it lands.
- [ ] Owner playtest: the far camera makes a two-enemy fight readable without losing the parry window.

### Second pass (same day, owner: "finish the list")
- **Idle stances** for every weapon (`Presentation.Weapons[id].Stance`): one-handed weapons hang low and a little
  forward with the off hand half-raised; fists keep a loose guard (live: club idle R 18° / L 30°).
- **Landing settle** (`Presentation.Swings.Settle`, `SwingAnimator.Settle`): the body dips 0.35 studs on `Landed`
  and rises over 0.28 s, under any swing (live: 0.42 peak after a jump). Every tracked character, not just yours.
- **Hitstop for the body** (`Presentation.Impacts[kind].Freeze`, `SwingAnimator.Freeze`): on Hit / Parry /
  GuardBreak / BlackFlash the attacker's and victim's swing poses hold their current frame for Freeze seconds
  (x `HeavyFreezeMult` on heavy hits), then carry on; the camera's FOV punch is x `HeavyHitstopMult` on heavies and
  longer on parries. Live: a club hit held the shoulder at −38° for 3 frames.
- **Palette** (`District.NeonDim = 0.7`): every neon part and its light in the generated districts is dimmed 30 %
  except the safe ring (its colour is information). Live: lamp heads 0.7 x their config colour.
- **Prompts** (`client/Prompts.lua`, `Presentation.Prompts`): every ProximityPrompt is `Style = Custom` and drawn as
  a small dark badge with the key letter, action + object text beside it at 45 % until the key is held (badge fills
  amber over the hold). Touch / gamepad still work (the badge is a button).
- **Nameplates** (`client/Nameplates.lua`, `Presentation.Nameplates`): Roblox's over-head name is off for players,
  combatants and contacts; a 12 px plate sits lower-left at hip height (white / red-ish enemies / cyan contacts) and
  fades from 30 to 70 studs. Health bars untouched. Live: 27 plates, 24 combatants' default names off.

## Follow-ups
- Uploaded animations per combo index (`AnimationId` in any `Keys` entry still wins).
- The prompt badge could not be eyeballed live (the Play client camera does not render under the MCP bridge):
  check it first in the playtest.
- Idle *animations* (a weight shift, a breathing sway) on top of the stances once an animation set exists.
