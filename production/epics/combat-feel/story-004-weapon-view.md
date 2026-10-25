# Story 004: Procedural weapon in hand

> **Epic**: Combat Feel
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Visual/Feel
> **Estimate**: M
> **Last Updated**: 2026-10-25

## Context

**GDD**: `design/gdd/weapons.md` (Overview: weapon = moveset, 7 weapons / 7 families)
**Requirement**: TR-003, TR-007
**ADR**: ADR-0004 — `WeaponView` builds per `Presentation.Weapons[id]`; clones `ReplicatedStorage.Assets.Weapons[Model]` when the slot names one.
**Engine**: Roblox / Luau | **Risk**: LOW

## Acceptance Criteria

- [ ] Every character with a `Weapon` attribute (own and others) shows a weapon welded to the right hand: Fists = nothing; PipeClub = grey pipe; RebarBlade = rusted blade; ShockBaton = baton with neon tip; ScrapSpear = long shaft + head; Sledge = heavy head on a haft; ArcPistol = boxy sidearm with neon emitter.
- [ ] The weapon updates immediately when the attribute changes (armory swap) and is removed on death/respawn without leftovers.
- [ ] Welds use `Motor6D`/`WeldConstraint` to `RightHand` (R15) or `Right Arm` (R6) with a per-weapon grip `CFrame` from `Presentation.Weapons[id].Grip`.
- [ ] Setting `Presentation.Weapons[id].Model = "SomeName"` makes `WeaponView` clone `ReplicatedStorage.Assets.Weapons.SomeName` instead of building parts; missing asset falls back to procedural with one `warn`.
- [ ] All weapon parts are `CanCollide=false`, `CanQuery=false`, `Massless=true`, and never affect the server hitbox (the server uses `GetPartBoundsInRadius` from the root with `FilterDescendantsInstances = {char}`; verify the parts are under `char`).
- [ ] Playtest: owner identifies each of the 7 weapons on another player/dummy from 20 studs away.

## Implementation Notes

- Build once per (character, weaponId); cache; destroy on change. Client-side only, so each client builds its own copies (cheap: ≤6 parts).
- Watch `Players.PlayerAdded/CharacterAdded` + `GetAttributeChangedSignal("Weapon")`. NPC rigs may carry the attribute later (Enemy v2).

## Out of Scope

- Swing animation (002), sheathing/holsters, real meshes.

## Files

- `src/client/WeaponView.lua` (new), `src/shared/Presentation.lua`

## QA Test Cases

- **AC-1/6**: arena armory: equip each weapon in turn, screenshot. Pass: 7 distinct silhouettes.
- **AC-2**: die (dev reset) and respawn; `#char:GetChildren()` has no `WeaponView_*` model before re-equip.

## Test Evidence

**Story Type**: Visual/Feel — screenshots in `production/qa/evidence/story-004/` + `story-004-evidence.md`.
**Status**: [ ] Not yet created

## Dependencies

- Depends on: story-001
- Unlocks: None (002 uses the weapon part if present, but does not require it)
