# Story 003: Impact feedback — sparks, hitstop, shake, parry/block/dodge cues

> **Epic**: Combat Feel
> **Status**: Blocked — BLOCKED: depends on story-002
> **Layer**: Presentation
> **Type**: Visual/Feel
> **Estimate**: M
> **Last Updated**: 2026-10-25

## Context

**GDD**: `design/gdd/combat.md` (Current Presentation, Edge Cases), `design/gdd/flicker.md` (Black Flash)
**Requirement**: TR-003, TR-002, TR-007
**ADR Governing Implementation**: ADR-0004 (Accepted). `CombatFX` owns impacts; every effect's timing/colour lives in `Presentation.Impacts[kind]`.
**Engine**: Roblox / Luau | **Risk**: LOW

## Acceptance Criteria

- [ ] `Hit`: spark burst at the victim's torso (code-made `ParticleEmitter` or tweened neon shards), a short Highlight flash, and a camera shake on the local player when they are attacker or victim (`Presentation.Camera.HitShake`).
- [ ] `Hit` on the local player's own swing applies hitstop: a brief slow-down of the swing tween only (never `Humanoid`/physics), `Presentation.Impacts.Hit.Hitstop` seconds.
- [ ] `Block`: blue-white spark on the blocker's shield-side, smaller shake. `Parry`: white flash + ring burst, distinct sound slot, bigger shake on both parties. `GuardBreak`: orange shatter burst + longer shake.
- [ ] `Dodged`: cyan after-image streak on the dodger (fixes the missing case). `Dodge` (the input) keeps its current flash.
- [ ] `BlackFlash`: existing sphere + ColorCorrection + banner move into `CombatFX`; banner text uses `Config.Flicker.BlackFlashMult`; adds a strong shake and a 0-length hitstop configurable in `Presentation`.
- [ ] `Flick` level-up: brief red pulse on the attacker scaled by level (`Presentation.Impacts.Flick.LevelScale`).
- [ ] All effects self-destroy (Debris) and never exceed `Presentation.Impacts.MaxInstances` live at once.

## Implementation Notes

- Register handlers via `CombatFX.Handlers[kind]`. Shake = tween a `CFrame` offset applied in `RenderStepped` on `Camera`, decaying over `Duration`; one active shake at a time, larger magnitude wins.
- Hitstop pauses `SwingAnimator`'s active tween (expose `SwingAnimator.Hitstop(char, seconds)`).

## Out of Scope

- Sounds (005), damage numbers / hit markers on HUD (HUD v2 epic).

## Files

- `src/client/CombatFX.lua`, `src/client/CameraShake.lua` (new), `src/client/SwingAnimator.lua`, `src/shared/Presentation.lua`

## QA Test Cases

- **AC-1/3/4**: Setup: arena dummies + a second Studio client. Verify each event's effect appears on the right character. Pass: all seven kinds visually distinct with HUD hidden.
- **AC-7**: Setup: spam LMB on three dummies for 30 s. Verify: `workspace.FX` child count stays bounded; no Output errors.

## Test Evidence

**Story Type**: Visual/Feel — screenshots in `production/qa/evidence/story-003/` + `story-003-evidence.md`.
**Status**: [ ] Not yet created

## Dependencies

- Depends on: story-002
- Unlocks: None
