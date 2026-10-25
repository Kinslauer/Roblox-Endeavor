# Story 002: Readable swing — windup telegraph, flick cue, swing, recovery

> **Epic**: Combat Feel
> **Status**: Ready
> **Layer**: Presentation (+ Core: `Swing` payload)
> **Type**: Visual/Feel
> **Estimate**: L
> **Last Updated**: 2026-10-25

## Context

**GDD**: `design/gdd/combat.md` (Attacks, Parry), `design/gdd/flicker.md` (Timing), `design/gdd/weapons.md`
**Requirement**: TR-004 (telegraph derived from server frame data), TR-002, TR-003, TR-007

**ADR Governing Implementation**: ADR-0004
**ADR Decision Summary**: `SwingAnimator` plays windup for `spec.Windup`, swing for `spec.Active`, recovery to `spec.End`, using Motor6D tweens unless a slot names an AnimationId. Flick cue peaks at `Windup - Config.Flicker.Window`.

**Engine**: Roblox / Luau | **Risk**: MEDIUM (Motor6D tweens vs default Animate script; latency shifts the telegraph late by one-way trip)

---

## Acceptance Criteria

- [ ] Server `Swing` payload carries `{ label, windup, active, finish, weapon }` (skills included) so the client never guesses durations.
- [ ] On `Swing`, the attacker's right arm (and weapon, if any) visibly winds back over exactly `windup` seconds, swings over `active`, and returns by `finish`. Works on R15 players and on NPC rigs that lack the Motor6D (degrades to a body lean).
- [ ] A glow on the attacker's weapon/hand ramps up during the windup and peaks `Config.Flicker.Window` before impact (the flick cue); it is brighter/wider when the attacker is in the Zone (`ZoneWindowMult`).
- [ ] Heavy attacks are visually distinct from light attacks (bigger wind-back, colour from `Presentation.Swings.HeavyColor`).
- [ ] An `AnimationId` set in `Presentation.Swings[Family][label]` plays an uploaded animation instead of the tween, with no code change.
- [ ] A feint (`Feint` event) snaps the arm back and kills the glow immediately.
- [ ] Being stunned mid-windup (`Hit`/`Parry`/`GuardBreak` on the attacker) also cancels the telegraph.
- [ ] Playtest: the owner parries the tutorial dummy / a Sledge heavy from another client by reading the windup, 3 of 5 tries, without a timer on screen.

---

## Implementation Notes

- Extend `Combat.Swing` only: `fx("Swing", char, { label = mods.label, windup = spec.Windup, active = spec.Active, finish = spec.End, weapon = char:GetAttribute("Weapon") })`.
- Tween `RightShoulder` / `RightUpperArm` Motor6D `C0` relative to its original; store the original per character so repeated swings don't drift. Cancel tokens per character.
- Glow = `PointLight` + `Highlight` or a neon `Attachment` part on the hand; intensity curve from `Presentation.Swings.CueCurve`.
- Never touch `Humanoid`, attributes, or other players' non-cosmetic instances.

## Out of Scope

- Impact effects (003), weapon geometry (004), sound (005), enemy AI telegraphs (Enemy v2 epic).

## Files

- `src/server/Combat.lua` (Swing payload)
- `src/client/SwingAnimator.lua` (new), `src/client/CombatFX.lua` (register handler), `src/shared/Presentation.lua`
- `tools/smoke/scenario.lua` (assert Swing payload shape)

## QA Test Cases

- **AC-2**: Setup: arena, equip Sledge, press RMB. Verify: wind-back lasts visibly longer than Fists LMB (0.60 s vs 0.10 s). Pass: owner can tell which is which with the HUD hidden.
- **AC-3**: Setup: equip Pipe Club, hold LMB combos, tap E as the glow peaks. Verify: `FLICKER x1` appears more often than when tapping at random. Pass: ≥3 of 5 flicks register.
- **AC-8**: as written.

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**: screenshot(s) in `production/qa/evidence/story-002/` + sign-off in `story-002-evidence.md`.
**Status**: [ ] Not yet created

## Dependencies

- Depends on: story-001; ADR-0004 Accepted
- Unlocks: story-003
