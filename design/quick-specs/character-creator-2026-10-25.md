# Quick Design — Character Creator & Standardized Rig (New Small System)

> Type: New Small System · Date: 2026-10-25 · Status: Implemented (imported from an uncommitted
> 2026-10-12 working copy, wired and verified in Studio)

## Overview
Every player gets the same standardized R15 body instead of their Roblox avatar, varied only by a
small fixed catalog (body type, skin tone, face, hair style, hair colour). A new character picks
its look once, on first spawn, in a simple cycle-through creator; the choice is permanent for that
character and is wiped with it on permadeath. Rationale: identical hitboxes, reach, joints and gear
attachment points for all players (pillar 3, skill-based combat), plus a small identity beat that
makes permadeath sting.

## Core Rules
- `Rig.Spawn(player)` builds the character server-side from a `HumanoidDescription` made of the
  catalog entries; it replaces `LoadCharacter` in `Lifecycle.Spawn`. Hair is procedural parts.
- Profile stores **indices** into the catalog (`Appearance = {BodyType, SkinTone, Face, Hair, HairColor}`)
  plus `AppearanceSet`. `Appearance.Sanitize` clamps anything the client sends.
- `Creator.Run(player)` yields the spawn until the player confirms or `TIMEOUT` (180 s) passes;
  previews re-skin the live character (`Rig.Apply`). Returning characters (`AppearanceSet = true`)
  skip it. The server always sends `OpenCreator(nil)` when it closes.
- The creator runs before the tutorial; the prologue timer keeps running meanwhile (acceptable:
  180 s ≪ 600 s cap).
- Roblox's default `Animate`/`Health` character scripts do not exist on server-built rigs; a client
  `Animate` LocalScript plays the stock R15 locomotion set.

## Tuning Knobs
| Knob | Where | Value |
|---|---|---|
| Catalog lists | `src/shared/Appearance.lua` | 3 body types, 6 skin tones, 1 face, 5 hair styles, 6 hair colours |
| Body scale band | `Appearance.BodyTypes` | width 0.90–1.10, height 1.0 |
| Creator timeout | `src/server/Creator.lua` `TIMEOUT` | 180 s |
| Locomotion animation ids | `src/client/Animate.client.lua` `IDS` | stock R15 |

## Acceptance Criteria
- [x] New character spawns with the creator open and the standardized body (verified: Porcelain default, hair folder present).
- [x] Cycling a field re-skins the live body within ~1 s (verified: skin Porcelain → Umber, Mohawk + Neon hair).
- [x] Confirm closes the creator and the tutorial starts; the look survives Emergence on the same character.
- [x] Combat, WeaponView and SwingAnimator work unchanged on the server-built rig (hit landed, arm moved 101°, weapon drawn).
- [x] Smoke harness passes with the creator in the loop (26/26).
- [ ] Owner playtest: pick a look with the mouse, confirm, see it in the arena.

## Systems Index
Add rows: `Appearance` (shared catalog), `Rig` (server body builder), `Creator` (server + client),
`Animate` (client stopgap). Owning doc: this quick spec until a full GDD is warranted.

## Follow-ups
- `Creator.client.lua` is a standalone LocalScript; fold it into the `Main.client.lua` module
  pattern (ADR-0003) when HUD v2 lands.
- Permadeath should announce the new creator (currently it just opens on respawn).
- Faces catalog has one entry; add decal ids when art exists.
