# Story 005: Audio slots

> **Epic**: Combat Feel
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: S
> **Last Updated**: 2026-10-25

## Context

**GDD**: `design/gdd/combat.md` (Current Presentation), brief "Art & audio direction"
**Requirement**: TR-003, TR-007
**ADR**: ADR-0004 — `Audio.lua` plays `Presentation.Sounds[kind]`; `""` = silent.
**Engine**: Roblox / Luau | **Risk**: LOW

## Acceptance Criteria

- [ ] `Presentation.Sounds` has one entry per `CombatEvent` kind (`Swing`, `SwingHeavy`, `Hit`, `Block`, `Parry`, `GuardBreak`, `Dodge`, `Dodged`, `Flick`, `BlackFlash`, `Feint`, `Bolt`, `Buff`, `Burst`) with `{ Id = "", Volume = n, PitchJitter = n }`.
- [ ] `Audio.Play(kind, char)` creates a `Sound` parented to the character's root (3D), applies volume and random pitch within jitter, destroys it on `Ended`; it is a no-op (no warning spam) when `Id == ""`.
- [ ] The local player's own events additionally play 2D (parented to `SoundService`) at `Presentation.Sounds.LocalMix`.
- [ ] Entering an ID for `Hit` in `Presentation.lua` makes hits audible with no code change (owner verifies with any free Roblox library SFX).
- [ ] Max concurrent sounds per character is capped by `Presentation.Sounds.MaxPerChar` (oldest is stopped).

## Files

- `src/client/Audio.lua` (new), `src/client/CombatFX.lua` (call `Audio.Play` from the dispatcher), `src/shared/Presentation.lua`

## QA Test Cases

- **AC-2/4**: put a free SFX ID in `Hit`, hit the dummy. Pass: audible, pitch varies, `#root:GetChildren()` returns to baseline after 2 s.

## Test Evidence

**Story Type**: Integration — playtest note in `production/qa/evidence/story-005/`.
**Status**: [ ] Not yet created

## Dependencies

- Depends on: story-001
- Unlocks: None
