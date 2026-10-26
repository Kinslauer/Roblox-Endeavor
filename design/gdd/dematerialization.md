# The cycle: dematerialization and rematerialization (Conduit world)

> **Status**: Designed, not implemented · **World**: Conduit (Universe 1) · **Epic**: `production/epics/destruction`
> (story 007) · **Depends on / depended on by**: `design/gdd/destruction.md` §4.8
> **Owner (2026-10-26 17:37)**: "The world may be simulated, or at least that is what the conduits think, and why
> they look for knowledge and try to escape. That's why it always resets, everything in the world: terrain, POI,
> etc. The only variables are player and enemy NPC spawns, encounters with vendor NPCs and loot."

## 1. Fiction
The conduits suspect the world is a simulation, and the reset is the evidence: every hour the world comes apart and
puts itself back exactly as it was. That suspicion is why conduits hunt for knowledge (intel, contacts, lore) and why
they want out. The cycle is the world's heartbeat and the game's central mystery; nothing in the UI explains it.

## 2. The rule
**Everything authored is restored exactly. Only four things vary from cycle to cycle:**

| Varies | What changes each cycle | Today in code |
|---|---|---|
| **Player spawns** | which spawn pad a fresh / respawning body wakes on | `CitySpawn` pads, picked by `WorldPhase.GetSpawnCFrame` |
| **Enemy NPC spawns** | where guards, ambushes, warmongers and rival crews start; which routes the crews walk | fixed lists in `Regions.Guards`, `Raids.Crews`, District ambushes |
| **Vendor encounters** | where each contact and the enclave trader stands this cycle (one of several authored spots) | fixed `Position` per contact / trader |
| **Loot** | every container, body and salvage roll | already random per roll |

**Restored exactly**: terrain, buildings, POIs, roads, props, breach points, lamps, signs, raid points, transport
hubs — anything authored. Destruction (`destruction.md`) is undone; nothing a player broke survives the cycle.

**Not part of the world** (never reset): the player's profile, inventory, money, raid in progress, contacts met,
board, house, builds. The hideout is the conduit's own space and is untouched. The war world keeps its own per-sector
rebuild (`destruction.md` §4.7).

### Reading of "encounters with vendor NPCs" (say the word if wrong)
Contacts and the trader don't stand in the same place every hour: each has 2–4 authored spots in its region and the
cycle picks one. Finding the Broker once unlocks RAIDS for good, but meeting them again means looking again. This
keeps "you have to find the proper contacts" true after the first find.

## 3. What players see
1. **T − 60 s**: broken things start flickering; a low hum rises everywhere in the Conduit world (diegetic only — no
   HUD timer, in keeping with "nothing announced you wouldn't notice yourself").
2. **T − 5 s**: the hum peaks; the whole world flickers; colour drains (a client ColorCorrection ramp).
3. **T**: **dematerialize**. A second of white-out for everyone in the Conduit world. During it, server-side:
   - every enemy NPC, rival crew, contact and trader is removed;
   - everything on the ground nobody looted is cleared: salvage remains, enemy drops, **and dead players' remains**;
   - anything held in hand (grabbed debris) dissolves out of it;
   - every broken prop, breach point, structure and terrain change is restored (§4).
4. **T + 1 s**: **rematerialize**. Colour returns. The new cycle's draw places enemies, crews, contacts and the trader;
   fresh loot is rolled where containers have it.
- **Players stay where they stand**, with their bodies, gear and state. A player inside a resealing breach is not
  moved: that point waits until the space is clear (`destruction.md` §4.8).
- **Fights in progress end**: the enemy you were fighting is gone. A raid in progress continues; its kill targets are
  whatever the new draw puts out there; its points (fixed POIs) are where they were.

## 4. Implementation sketch
- `server/Cycle.lua`: a server clock started when the world opens (`WorldPhase` → Open; emergence is the first
  materialization). `Config.Cycle = { Seconds = 3600, WarningSeconds = 60, FlickerSeconds = 5, WhiteoutSeconds = 1 }`.
- Signals: `Cycle.Warning(secondsLeft)`, `Cycle.Dematerialize()`, `Cycle.Rematerialized(index, rng)`. Each cycle gets
  a seed; systems draw their variables from the cycle's `Random`, so a cycle is reproducible in tests.
- Replicated: `workspace` attributes `Cycle_Index`, `Cycle_At` (when the next one hits) for the client FX
  (`client/WorldFX.lua`: hum, flicker, colour drain, white-out).
- Subscribers: `NPCs` / `Regions` guards / District ambushes / `Rivals` (despawn, respawn from the draw), `Contacts`
  and the trader (pick a spot from `Raids.Contacts[id].Spots`), `Loot` (clear unlooted ground loot), destruction
  (restore props / breaches; `workspace.Terrain` snapshot via `CopyRegion` at boot, `PasteRegion` on reset).
- **Multi-place**: once the Conduit world is its own place (`Config.Places`), each server keeps its own cycle.
- Smoke: advance the mock clock past `Seconds`; check enemies re-spawned from a different draw, contacts moved to a
  listed spot, ground loot cleared, a broken prop restored, the player's inventory and raid untouched.

## 5. Open questions
- Does a dead player's own remains clearing at the reset feel fair, or should a body's remains survive one cycle?
- Should the cycle carry *clues* (a line from a contact that changes each cycle, a lore fragment that only appears on
  certain cycles) to feed the "find knowledge, escape" goal? That's the natural hook for a later story arc.
