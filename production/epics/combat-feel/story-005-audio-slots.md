# Story 005: Audio slots

> **Epic**: Combat Feel
> **Status**: Blocked — BLOCKED: depends on story-001
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: S
> **Last Updated**: 2026-10-25

## Context

**GDD**: `design/gdd/combat.md` (Current Presentation)
**Requirement**: TR-003, TR-007
**ADR Governing Implementation**: ADR-0004 (Accepted). `Audio.lua` plays one `Sound` per `Presentation.Sounds[kind]` slot at the emitting character; empty slot = silent.
**Engine**: Roblox / Luau | **Risk**: LOW

## Acceptance Criteria

- [ ] `Presentation.Sounds` has a slot for every `CombatEvent` kind (`Swing` split by `Light`/`Heavy`, plus `Hit`, `Block`, `Parry`, `GuardBreak`, `Dodge`, `Dodged`, `Flick`, `BlackFlash`, `Feint`, `Bolt`, `Buff`, `Burst`) with `{ Id = "", Volume = n, PitchJitter = n }`.
- [ ] With all slots empty, no `Sound` instances are created and no warnings appear in Output.
- [ ] Filling one slot with a valid `rbxassetid://` plays it 3D-positioned at the character's root, with the configured volume and random pitch within `PitchJitter`.
- [ ] Sounds are pooled per kind (max `Presentation.Sounds.PoolSize` concurrent) and cleaned up on character removal.

## Implementation Notes

- Register with `CombatFX.Handlers` via a wrapper so audio runs alongside visuals without ordering dependencies.
- Use `SoundService:PlayLocalSound` only for the local player's UI-ish cues (Black Flash banner); everything else is a `Sound` parented to the root part.

## Out of Scope

- Music, ambience, UI clicks (Audio epic later).

## Files

- `src/client/Audio.lua` (new), `src/shared/Presentation.lua`, `src/client/Main.client.lua`

## QA Test Cases

- **AC-2**: Setup: Play with empty slots. Verify: `#workspace:GetDescendants()` of class `Sound` is 0 after a fight; Output clean.
- **AC-3**: Setup: set `Sounds.Hit.Id` to a free Roblox library sfx id. Verify: hits are audible and pitch varies.

## Test Evidence

**Story Type**: Integration — playtest note in `production/qa/evidence/story-005/`.
**Status**: [ ] Not yet created

## Dependencies

- Depends on: story-001
- Unlocks: None
