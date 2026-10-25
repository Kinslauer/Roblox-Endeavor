# Story 001: Presentation slots + client module split

> **Epic**: Combat Feel
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: none (no control manifest yet)
> **Last Updated**: 2026-10-25

## Context

**GDD**: `design/gdd/combat.md` (Current Presentation), `design/gdd/flicker.md`
**Requirement**: TR-003 (presentation never mutates state), TR-007 (placeholders have slots), TR-002 (no literals)

**ADR Governing Implementation**: ADR-0003 Rojo module layout; ADR-0004 presentation layer (schema only; Proposed)
**ADR Decision Summary**: Client becomes a composition root over ModuleScripts with `Init()`. Asset IDs and presentation tuning live in `src/shared/Presentation.lua`.

**Engine**: Roblox / Luau, Rojo 7.7.1 | **Risk**: LOW

---

## Acceptance Criteria

- [ ] `src/shared/Presentation.lua` exists with sections `Weapons`, `Swings`, `Impacts`, `Sounds`, `Camera`; every ID field is `""` and documented.
- [ ] `src/client/` contains `Hud.lua`, `CombatFX.lua`, `FlickerAura.lua`, `Input.lua`; `Main.client.lua` only requires and `Init()`s them (under 40 lines).
- [ ] Behaviour is unchanged after the split: bars, panels, skill hotbar, tutorial panel, death screen, Black Flash FX, Bolt, dodge movement all still work in a Studio playtest.
- [ ] The Black Flash banner / multiplier text reads `Config.Flicker.BlackFlashMult`; the `2.5` literal is gone.
- [ ] `CombatEvent "Dodged"` produces visible feedback (the old missing-case bug).
- [ ] Server sets a replicated `Weapon` attribute on every player character (`Gear.Recompute`/`Push`) so other clients can know the held weapon.
- [ ] `tools/smoke` scenario passes (`python3 tools/smoke/gen.py | luau -`), or is NOT ASSESSED if `luau` is unavailable, with the reason recorded.

---

## Implementation Notes

- Move code, don't redesign it. HUD v2 is a later epic.
- `Main.client.lua` order: `Hud.Init()` first (others reference the banner), then `FlickerAura`, `CombatFX`, `Input`.
- `CombatFX` exposes `CombatFX.Handlers[kind] = fn(a, b)` so stories 002–005 register handlers without editing the dispatcher.
- `Presentation.lua` is pure data + tiny accessors; never requires client/server code.

---

## Out of Scope

- Story 002: swing/windup animation. Story 003: sparks/hitstop/shake. Story 004: weapon models. Story 005: sounds.

---

## Files

- `src/shared/Presentation.lua` (new)
- `src/client/Main.client.lua`, `src/client/Hud.lua` (new), `src/client/CombatFX.lua` (new), `src/client/FlickerAura.lua` (new), `src/client/Input.lua` (new)
- `src/server/Gear.lua` (Weapon attribute)
- `tools/smoke/scenario.lua` (assert Weapon attribute)

---

## QA Test Cases

- **AC-3**: Setup: Play in Studio, finish or skip tutorial, reach arena. Verify: stamina/posture/charge bars move, J/Tab/L panels open, R/Y/V hotbar shows cooldowns, Q moves you, arc pistol draws a bolt, Black Flash banner shows. Pass: all present, no red Output.
- **AC-5**: Setup: arena dummy "Attack" or a second client swinging; press Q during its hit. Verify: a cyan flash on your character. Pass: visible flash on a successful dodge.
- **AC-6**: In a Server-datamodel `execute_luau`: `Players[1].Character:GetAttribute("Weapon")` equals the equipped id after equipping from the armory.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: smoke scenario run or Studio playtest note in `production/qa/evidence/story-001/`.
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None
- Unlocks: story-002, story-004, story-005
