# Story 004: Procedural weapon in hand

> **Epic**: Combat Feel
> **Status**: Blocked — BLOCKED: depends on story-001
> **Layer**: Presentation
> **Type**: Visual/Feel
> **Estimate**: M
> **Last Updated**: 2026-10-25

## Context

**GDD**: `design/gdd/weapons.md` (Overview: weapon = moveset; seven weapons, six families)
**Requirement**: TR-003, TR-007
**ADR Governing Implementation**: ADR-0004 (Accepted). `WeaponView` builds or clones the held weapon from `Presentation.Weapons[id]`; reads the replicated `Weapon` character attribute so every client sees every player's weapon.
**Engine**: Roblox / Luau | **Risk**: LOW

## Acceptance Criteria

- [ ] Each of the 7 weapons has a part-built placeholder model (`Presentation.Weapons[id].Build`), welded to `RightHand` (R15) via a `Motor6D`/`Weld` with a per-weapon grip CFrame; `Fists` shows nothing.
- [ ] Changing `Weapon` attribute (equip at the Test Armory) swaps the model within one frame; unequip/death cleans it up (no orphaned parts in `workspace`).
- [ ] Models are `CanCollide=false`, `CanQuery=false`, `Massless=true` and don't affect movement.
- [ ] Setting `Presentation.Weapons[id].ModelName` to the name of a model under `ReplicatedStorage.Assets.Weapons` clones that instead of building the placeholder — no code change.
- [ ] `SwingAnimator` moves the weapon with the arm (it's welded, so free), and the flick-cue glow attaches to the weapon's `Tip` attachment when present.
- [ ] Other players' weapons are visible (verify with two Studio clients).

## Implementation Notes

- Build functions return a `Model` with a `PrimaryPart` named `Handle` and an `Attachment` named `Tip`. Keep each under ~8 parts.
- Listen to `char:GetAttributeChangedSignal("Weapon")` for every character in `Players` (CharacterAdded + existing), not just the local player.

## Out of Scope

- Animations (002), hit effects (003), armor visuals (later).

## Files

- `src/client/WeaponView.lua` (new), `src/shared/Presentation.lua`, `src/client/Main.client.lua`

## QA Test Cases

- **AC-1/2**: Setup: arena armory, equip each weapon in turn. Verify: a distinct model appears in the right hand each time, the previous one is gone. Pass: 7/7, screenshot of each.
- **AC-6**: Setup: Test > Clients and Servers, 2 players. Verify: each sees the other's weapon.

## Test Evidence

**Story Type**: Visual/Feel — screenshots in `production/qa/evidence/story-004/` + `story-004-evidence.md`.
**Status**: [ ] Not yet created

## Dependencies

- Depends on: story-001
- Unlocks: None
