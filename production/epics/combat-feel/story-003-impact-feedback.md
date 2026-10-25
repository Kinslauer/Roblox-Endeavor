# Story 003: Impact feedback — sparks, hitstop, shake, parry/block/dodge cues

> **Epic**: Combat Feel
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Visual/Feel
> **Estimate**: M
> **Last Updated**: 2026-10-25

## Context

**GDD**: `design/gdd/combat.md` (Current Presentation, Edge Cases), `design/gdd/flicker.md` (Black Flash)
**Requirement**: TR-003, TR-002, TR-007
**ADR**: ADR-0004 — `CombatFX` owns impacts; tuning in `Presentation.Impacts`.
**Engine**: Roblox / Luau | **Risk**: LOW

## Acceptance Criteria

- [ ] `Hit`: spark burst at the victim's torso (ParticleEmitter burst or tweened neon shards), short red Highlight, and for the *local* attacker or victim a hitstop (`Presentation.Impacts.Hit.Stop` seconds of camera FOV punch / brief time-dilation illusion via tweened effects, never `Humanoid` changes) plus a camera shake scaled by damage class.
- [ ] `Block`: blue spark on the blocker's forearm, no shake. `Parry`: white ring flash + metallic cue + heavier shake on both. `GuardBreak`: orange shatter and a longer shake on the victim.
- [ ] `Dodged`: cyan after-image (ghost of the character for `Presentation.Impacts.Dodged.Ghost` seconds).
- [ ] `BlackFlash`: existing sphere + ColorCorrection + banner move into `CombatFX` unchanged in look; banner text reads the multiplier from `Config.Flicker.BlackFlashMult`.
- [ ] `Bolt`: beam stays; add a muzzle flash at the shooter's hand and a spark at the hit point.
- [ ] Every duration, size, colour and shake amplitude comes from `Presentation.Impacts`.
- [ ] Nothing persists: all created instances are destroyed within their effect time (checked by counting `workspace.FX` children after 5 s idle = 0).

## Implementation Notes

- Parent transient parts under a `workspace.FX` folder the client creates; `Debris:AddItem` everything.
- Camera shake = additive `CFrame` offset on `workspace.CurrentCamera` in `RenderStepped`, decaying; single shaker with amplitude stacking, never fights the default camera scripts.

## Out of Scope

- Sound (005), weapon geometry (004), HUD hit markers / damage numbers (HUD v2 epic).

## Files

- `src/client/CombatFX.lua`, `src/client/CameraShake.lua` (new), `src/shared/Presentation.lua`

## QA Test Cases

- **AC-1**: arena dummy, Pipe Club LMB x3. Verify sparks + flash + shake on each hit; heavy shakes more. Pass: owner can tell a heavy landed with eyes on the dummy only.
- **AC-7**: idle 5 s after a fight; `#workspace.FX:GetChildren() == 0` via execute_luau (Client).

## Test Evidence

**Story Type**: Visual/Feel — screenshot(s) in `production/qa/evidence/story-003/` + `story-003-evidence.md`.
**Status**: [ ] Not yet created

## Dependencies

- Depends on: story-002
- Unlocks: None
