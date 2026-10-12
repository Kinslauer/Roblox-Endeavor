# CONDUIT (working title)

A permadeath, always-on-PvP Roblox game. It plays like a solo game until the world "emerges"
into a shared, ruined cyberpunk megacity full of quests, random events and combat.
Combat and progression are inspired by Cursed Gear and Deepwoken.

See [docs/DESIGN.md](docs/DESIGN.md) for the design and roadmap.

## Setup
1. Install [Rojo](https://rojo.space) and the Rojo Studio plugin.
2. `rojo serve` in this folder, then connect from Studio (File > New place first).
3. Press Play. Set `Config.PrologueSeconds` to ~20 while testing the Emergence.
4. Build your city, then tag spawn parts with `CitySpawn` (CollectionService) — until then a
   placeholder slab is generated.

Enable *Game Settings > Security > Enable Studio Access to API Services* to test DataStores.

## Controls
`LMB` attack (4-hit combo) · `F` hold to block (tap right before a hit to parry) · `Q` dodge ·
`R` Surge (needs Charge, built by landing hits) · `K` attributes · `I` inventory/crafting ·
hold `E` on remains/crates to loot them.

## Layout
| Path | Purpose |
|---|---|
| `src/shared` | Config (all tuning), Items/recipes/loot tables, Remotes |
| `src/server` | Authoritative systems: PlayerData, Stats, Combat, WorldPhase, Inventory, Loot, Quests, NPCs, Events, Permadeath, Lifecycle |
| `src/client` | Input and HUD |
