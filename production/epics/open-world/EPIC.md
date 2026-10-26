# Epic: Open world v1 — the road, Verdant Reach, transport, warmongers (Phase 3, build order 5)

> **Status**: Stories 001–005 implemented (owner playtest pending) · **Layer**: World · **Rigor**: standard
> **Brief**: `design/phase-3-brief.md` item 5 · **GDD**: `design/gdd/world.md` · **Decided**: first region = solarpunk enclave

## Overview
The city grows a north gate and a wasteland road to the first region: Verdant Reach, a solarpunk enclave with a safe
covered market and a trader selling the first parts for the war's money. Two stations and one train line join them;
a station unlocks when you have stood on it once, so the first trip is on foot past the road's guards — a warmonger
holds the gate. The dev arena moved south so the north is the open world's.

## Stories
| # | Story | Type | Status |
|---|---|---|---|
| 001 | `shared/Regions.lua`: road, enclave (palette, counts, market, stock), hubs + lines, `At` / `InMarket`; District 1 `Gates.North`; `District.wall` gaps on X-walls; `Config.Dev.ArenaOffset` → −Z | Data | Implemented — smoke: `At`/`InMarket` |
| 002 | `server/Regions.lua` road: slab (PlayableArea, Region attr), waste apron, centre line, wrecks/rubble, dead trees, half-dead lamps, fixed guards from `Road.Guards` | Content | Implemented — live: 536 parts, 7 guards |
| 003 | `server/Regions.lua` enclave: terrace, paths, covered market (SafeZone, ring), stalls, trader counter + sign, domes with grow-lamps, solar towers, beds, trees, lamps, hedge with the road gap, named arch; `Market` attribute watch; `Regions.Buy` (`Remotes.Buy`, rate-limited); HUD Trader section | Content + Logic | Implemented — live: market flag, buy 100→60 |
| 004 | `server/Transport.lua`: hub platforms (rails, roof, sign, one console per line), unlock by standing (`profile.Hubs`, PERSIST, `HubsKnown`), `Ride` (both ends unlocked, no combat, protected boarding, arrival protection) | Logic + Content | Implemented — live: refused before visit, ride landed 7 studs from the platform |
| 005 | `Enemies.Defs.Warmonger` + `Items.LootTables.Warmonger`; NPC `Dash` branch (flicker-step to Stop studs, busy, `Dash` event, heavy follows) | Logic | Implemented — live: 36 → 6 studs, Chase→Dash→Attack |
| 006 | Owner playtest: walk the road — does the warmonger's step read? Is the enclave a relief after the city? Is the train worth unlocking? | Feel | Pending |

## Acceptance criteria
1. Leave District 1 by the north gap; the road reads as a highway through wasteland with things to fight and hide behind.
2. The enclave reads as green and safe: no ambushes, a market you cannot be hurt in, a trader that takes money for parts.
3. Stations unlock on first visit, refuse rides to places you have not been, and ride you there protected.
4. The warmonger dashes at you from mid-range and hits like a brute; it drops parts and cybernetics.
5. Smoke covers 1–4 (14 checks: 157/157).

## Follow-ups
- Next regions (deeper wasteland, ruined city, coast); planes/cars as lines; per-region ambush tables; Dash FX.
- The hideout computer / raids / contacts / rival crews (brief item 7).
