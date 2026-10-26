# Epic: District 2 (Phase 2, build order 4)

> **Status**: Stories 001–003 implemented (owner playtest pending) · **Layer**: Content/Feature · **Rigor**: standard
> **Brief**: `design/phase-2-brief.md` item 4 · **Builds on**: `production/epics/district-blockout` (the generator)

## Overview
The city is bigger than one screen. The District 1 generator now builds every entry of
`District.Districts` (shared/District.lua) — each with its own seed, plaza name, palette, lamp and
ring colours — side by side along +X, and joins neighbours with a **gate street** that passes through
a gap in both perimeter walls under a neon arch. District 2 ("Ferrite Court") is the rust-and-sodium
half: more rubble, heavier ambushes (`Enemies.Ambush.ByDistrict[2]`). Spawn pads carry a `SpawnFor`
attribute so new players wake in District 1 and Awakened ones in District 2. The Rift to the Range
stays in Relay Plaza, so the loop is: wake in D1 → fight → Rift → come back → walk the gate to D2.

## Stories
| # | Story | Type | Status |
|---|---|---|---|
| 001 | Generator parameterised by district (`ctx`): origin, seed, palette/neon, ring/lamp/floor colours, rubble chance, plaza name; `District.Districts` table; `District.Pitch()`, `District.StreetLine(i)`, `District.At(position)`; one shared outskirts apron | Logic | Implemented — live: 1394 parts, 2 plazas (Relay Plaza @0, Ferrite Court @508), 10 wall pieces |
| 002 | Gate street: wall gap (`StreetWidth + 2`) on street line `District.Gate.Line` in D1's east and D2's west wall; `GateStreet` slab tagged `PlayableArea` between the street edges, kerbs, lamps, two neon arches with "→ District 2" / "District 1 ←" labels | Content | Implemented — live: a 100-stud ray along the gate line hits nothing; the same ray off the line hits `PerimeterWall@222` |
| 003 | Spawn split: pads carry `SpawnFor = Fresh/Awakened` (+ `District` name); `WorldPhase.GetSpawnCFrame` filters by `profile.Awakened` (pads without the attribute — the dev arena's — always qualify); Emergence spawns before flipping `Awakened` so emergers land in D1 | Logic | Implemented — live: 8 Fresh + 8 Awakened pads; smoke: fresh → District 1, Awakened → District 2 |
| 004 | Ambush composition per district: `Enemies.Ambush.ByDistrict[2]` = groups of 3–5, Brute 25 %, up to 2 Brutes; `NPCs.SpawnAmbush` layers the override over the defaults via `District.At(center)` | Data | Implemented (not smoke-covered: the mock has no ground for `FindGround`) |
| 005 | Owner playtest: does D2 read as a different place; is the gate findable from the plaza; does the harder mix feel right | Visual/Feel | Pending |

## Acceptance criteria
1. Two plazas, each a `SafeZone` with its own `ZoneName`; the HUD label shows the right name in each.
2. The gate line is walkable from D1's street edge to D2's with nothing solid on it; every other point on both walls is solid.
3. `CitySpawn` pads split `Spawns.Count` / `Spawns.Count` between Fresh and Awakened; a fresh profile spawns inside District 1's footprint and an Awakened one inside District 2's.
4. `District.At` returns 1 / 2 / nil for a D1 point, a D2 point and the gate.
5. Ambushes centred in D2 use the D2 composition.
6. Smoke covers 1–4 (7 new checks: 77/77).

## Follow-ups
- D2-only content: a second Rift, a vendor or quest giver in Ferrite Court, D2-specific lore line.
- A gate "border" event (ambush on the gate street itself — it is already `PlayableArea`).
- Hand-built districts replace the generator later; `District.Districts` stays the registry.
