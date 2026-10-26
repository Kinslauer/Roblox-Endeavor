# Epic: First-person mode + The Range (Phase 2, build order 1–2)

> **Status**: Stories 001–003 implemented (owner playtest pending) · **Layer**: Feature · **Rigor**: standard
> **Brief**: `design/phase-2-brief.md` items 1–2 · **Builds on**: `production/epics/weapon-handling` (ViewModel, aimed shots)

## Overview
Universe 2 is the shooter. Rather than open a second place before the shooting is fun, the Range is
built inside this place at `Config.Range.Origin`: a target lane with distance markers, a wave arena,
and two Rifts (Relay Plaza ↔ the Range). Inside, first person is forced, only ranged weapons fire,
and you carry the new Arc Rifle. Everything reuses Phase-1 systems: `NPCs` for targets and waves,
`Combat` for hitscan shots along the validated camera direction, `ViewModel` + `Sight` attachments
for iron sights, `Inventory`/`Gear` for the loadout.

## Stories
| # | Story | Type | Status |
|---|---|---|---|
| 001 | First-person toggle in Universe 1: `C` (Presentation.Aim.FirstPersonKey) locks the camera to the head with FOV 75 and shows the hip-fire view model; ADS layers on top and returns to first person; server can force it via the `ForceFirstPerson` player attribute | Input/Presentation | Implemented — live: `LockFirstPerson`, FOV 75, hip view model at (0.65, −0.55, −1.40) |
| 002 | Arc Rifle: `Weapons.ArcRifle` (Family Rifle, 14 dmg hitscan, 160 range; lance heavy 40 dmg, stun 0.6), procedural `Rifle` builder with receiver / barrel / stock / fore-end / power cell and its own `Sights` spec; two-handed low-ready stance; `Rifle` swing family holds the shoulder | Data/Presentation | Implemented — live: ADS sight at (0.00, −0.00, −0.90), front post top at (0.000, −0.000, −3.80), dot 1.000 |
| 003 | The Range: `server/Range.lua` zone (floor, walls, lane wall + gate, firing line, 5 markers, 10 cover, arena pad, lights), 5 pop-up targets at 20–100 studs that fall and reset (score = distance, `RangeScore` attribute + announce), Rifts both ways (`Range.Enter/Leave`: loadout grant + equip, `Zone`/`ForceFirstPerson` attributes, entry protection), Wave Console (`Config.Range.Waves`, Gunners on a ring, scrap reward on clear), ranged-only rule in `Combat.Attack/Heavy`, flags cleared on respawn | Logic + Content | Implemented — live: Rift in → (1400, 5, 78), zone + FFP set, rifle equipped; 3 shots dropped Target 20 (+20 score, announce); club swing refused, rifle shot allowed; Rift out → plaza, flags nil, camera Classic; wave 1 = 2 Gunners in the arena, second start refused |
| 004 | Owner playtest: rifle feel (recoil, hold, hip vs. sights), target lane readability, wave difficulty, travel feel | Visual/Feel | Pending |

## Acceptance criteria
1. `C` toggles first person anywhere; the view model appears with a ranged weapon; `C` again returns to the shoulder camera.
2. The Rift refuses players who have not Awakened with ≥ `UnlockKills` kills (Dev mode bypasses) and tells them why.
3. Entering grants and equips the Arc Rifle, forces first person, marks `Zone = "Range"`, protects for `EntryProtection`.
4. Melee swings and heavies are refused in the zone with a message; ranged ones work.
5. Targets drop when killed, credit the shooter by distance, and stand back up after `ResetSeconds`.
6. The Wave Console spawns `Config.Range.Waves[n]` on the ring; clearing it pays scrap to everyone in the zone; a wave cannot be double-started.
7. Leaving (Rift or death) clears the flags and the camera returns to third person.
8. Smoke covers 2–7 where the mock allows (8 new checks).

## Follow-ups
- Drone enemy (flying strafer) — needs a non-humanoid mover in `NPCs`.
- Range PvP and the multi-place split (brief item 5).
- Hip-fire spread / recoil affecting the shot (currently cosmetic only).
