# Epic: District Blockout

> **Status**: Stories 001–003 implemented (owner playtest pending) · **Layer**: Feature · **Rigor**: standard
> **Brief item**: `design/game-brief.md` MVP 6, Build order 6 · **Spec**: this epic + `design/gdd/combat.md` (damage resolution 1b)

## Overview
Until now the shared city was a 1200-stud asphalt slab with the dev arena on it. This epic replaces
it with a generated first district — District 1 — that reads as a wrecked neon megacity at night:
a seeded 5×5 grid of blocks and streets, buildings with lit windows and neon signs, collapsed
blocks of rubble, street cover (crates, barriers, wrecks, dumpsters), lamp posts, a perimeter wall
with the rest of the city "collapsed" beyond it, eight spawn pads in the streets, and one safe zone
at the centre: Relay Plaza. The dev arena still exists but sits outside the wall behind `Config.Dev`.

Design intent (concept GDD → Explorers pillar, brief art direction): heavy readable silhouettes,
cover every few steps so fights have corners, and a visible, lit place of safety you can run for.

## Governing ADRs
ADR-0001 (the safe-zone rule lives in `Combat.applyDamage`, the client only shows it), ADR-0002
(every layout number is data in `shared/District.lua`; the generator has no magic numbers),
ADR-0004 (`Safe` is one more `CombatEvent` kind with slots in `Presentation`).

## Stories
| # | Story | Type | Status |
|---|---|---|---|
| 001 | Generator: `shared/District.lua` data + `server/District.lua` building streets, pavements, buildings/rubble, cover, lamps, wall, plaza, spawn pads from a fixed seed; boot before `WorldPhase`; placeholder slab removed | Logic + Content | Implemented — live: 711 parts, 53 buildings, 6 rubble blocks, 132 cover props, 8 `CitySpawn` pads (nearest 2.8 studs on spawn), 2 `PlayableArea` grounds |
| 002 | Safe zone: `SafeZone` tag + `Radius`; `Combat` refuses damage when either root is inside and fires `Safe`; NPC targeting ignores players inside; HUD shows `SAFE ZONE · Relay Plaza` + enter/leave banners; `SAFE ZONE` word over the refused hit | Logic + UI | Implemented — live: Grunt 8 studs outside the ring did not move or swing; damage in / out → `none`, hp 100→100; outside → `hit`, hp 90; label + banner shown inside, cleared outside |
| 003 | Dev arena behind `Config.Dev`: built at `Config.Dev.ArenaOffset` (0, 0, 820) outside the wall; pads tagged `CitySpawn` only with `Config.Dev.SpawnInArena`; lighting moved to `District.Lighting` | Config | Implemented — live: `ArenaFloor` at (0, 2.3, 820); 8 `CitySpawn`s total, none in the plaza |
| 004 | Owner playtest: walk the district (silhouettes, cover density, lamp count vs. frame rate), find the plaza from a spawn, try to fight across the ring, check the arena is still reachable for armory testing | Visual/Feel | Pending |

## Acceptance criteria
1. The open world has a district at boot with no Studio building; the same seed yields the same city.
2. Every `CitySpawn` pad is on a street, outside the safe zone, within `Spawns.MaxFromSafeZone`.
3. Streets are `PlayableArea` ground; the plaza is not, so ambushes and supply drops never land inside.
4. No damage is applied when the victim or the attacker stands inside the safe zone — players and NPCs alike — and both see why (`Safe` FX / word).
5. NPCs do not chase players who are inside the safe zone.
6. The HUD says when you are in a safe zone and when you leave it.
7. The dev arena still builds under `Config.Dev.Enabled`, outside the district wall, and does not add spawns unless asked.
8. Smoke scenario covers 1–4 (6 new checks) and stays green.

## Definition of Done
AC 1–8 verified live or in smoke; owner playtest sign-off; follow-up list filed (below).

## Follow-ups (not blocking)
- Lamp count is high (164 posts, each with a `PointLight`); if the owner sees frame drops, raise `District.Lamps.Spacing`.
- Buildings are boxes; doorways/alleys and a second district come with hand-built content (concept GDD: Alpha).
- A `Safe` sound slot shares the `Buff` placeholder clip.
