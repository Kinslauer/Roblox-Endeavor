# Story 002 evidence — Readable swing: windup telegraph, flick cue, swing, recovery

**Date**: 2026-10-25 · **Build**: branch `claude/combat-feel`, Studio place `Conduit.rbxlx`
**Method**: Studio MCP. Scripts pushed into the place; Play; remotes fired from the Client datamodel; arm angle sampled every 0.1 s (UpperTorso→RightUpperArm relative pitch); screenshots captured.

## Measured timeline — Sledge heavy (server payload `windup=0.6 active=0.2 finish=1.4`)

| t (s) | arm pitch | cue | phase |
|---|---|---|---|
| 0.1 | −25° | ramping | windup |
| 0.2 | −66° | ramping | windup |
| 0.3 | −111° | ramping | windup |
| 0.4 | −141° | **open** (flipped red at 0.32 s = 0.6 − `Config.Flicker.Window` 0.28) | windup |
| 0.5 | −155° | open | windup |
| 0.6 | 177° (wrap) | open | strike begins at exactly `windup` |
| 0.7 | 33° | open | strike |
| 0.8 | 29° | removed at `windup+active` | recovery |
| 1.0–1.4 | 15° → −2° | — | recovery to rest by `finish` |

Rest pitch before the swing: −9° (walk/idle pose, left untouched).

| AC | Result | Notes |
|---|---|---|
| 1. `Swing` payload `{label, windup, active, finish, weapon, hyperarmor}` | PASS | Received on client: `label=Heavy windup=0.6 active=0.2 finish=1.4 weapon=Sledge` |
| 2. Arm winds back over `windup`, strikes over `active`, returns by `finish`; degrades on rigs without a shoulder joint | PASS | Table above. Works on the AnimationConstraint rig the avatar actually loaded with (no Motor6Ds present); Motor6D path kept for other rigs. No-arm rigs fall back to a body flash |
| 3. Glow peaks `Window` before impact; Zone widens | PASS / Zone NOT ASSESSED | Flip at 0.32 s measured. Zone multiplier is applied in code (`ZoneWindowMult`) but not exercised live |
| 4. Heavy visually distinct | PASS | Heavy = overhead wind-up (`Pose {-175,0,8}`, see `windup-overhead.jpg`), light = side wind-up, different glow colour |
| 5. `AnimationId` slot overrides the tween | PASS (by construction) | `playAnimationSlot` path; no uploaded animation available to test |
| 6. Feint cancels | PASS (by construction) | `Feint` handler blends arm back over 0.1 s; not measured live this run |
| 7. Stun cancels | PASS (by construction) | Server now emits `CombatEvent "Stun"`; handler cancels |
| 8. Owner parries by reading the windup 3/5 | NOT ASSESSED | Needs the project owner at the keyboard + an attacking enemy (Enemy v2) or a second client |

## Screenshots

- `windup-overhead.jpg` — staged still: the pose/cue the module produces at t≈0.45 s of a Sledge heavy (held for the capture because the tool's capture latency exceeds the 0.6 s windup).
- `windup-side.jpg` — staged still of the earlier side wind-up pose (superseded for Heavy; kept as the Light reference).

## Engine findings worth keeping
- Character rigs in this Studio build load with **AnimationConstraint** joints, not Motor6D, and `C0` is read-only from the client. Procedural posing must write `Transform` in `RunService.Stepped`; `SwingAnimator` does exactly that and handles both joint types.
- The Studio MCP `execute_luau` VM caches `require`d modules across calls; test handlers by index with care (use the last registered handler).

**Sign-off**: project owner, 2026-10-25 — playtested in Studio, "the attack works".
