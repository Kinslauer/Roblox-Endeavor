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
`LMB` attack (your weapon's combo chain) · `RMB` heavy attack · `F` hold to block (tap right before a hit to parry) ·
`Q` dodge · `1`/`2`/`3` skills · `K` attributes · `I` inventory/crafting/equip · `L` loadout (resists, tags, skills) ·
hold `E` on remains/crates to loot them.

## Build model
- **Weapon = moveset.** Each weapon defines its own combo chain, heavy attack, timings and reach (`src/shared/Weapons.lua`).
- **Stats + armor = everything else.** Skills (`src/shared/Skills.lua`) have no class or weapon lock. They unlock from
  *effective* stats (base + armor bonuses) and armor *tags* (Scav / Plated / Conduit), and their power scales with the same
  stats and tags, so swapping a chest piece can unlock or lock an ability. Armor (`src/shared/Armor.lua`) also sets
  resistances, posture, weight (stamina cost / speed) and block strength.
- Saving uses [ProfileService](https://github.com/MadStudioRoblox/ProfileService) (vendored, Apache-2.0; see `licenses/`).

## Layout
| Path | Purpose |
|---|---|
| `src/shared` | Config (all tuning), Weapons, Armor, Skills, Items/recipes/loot tables, Remotes |
| `src/server` | Authoritative systems: PlayerData (ProfileService), Gear, Stats, Combat, SkillRunner, WorldPhase, Inventory, Loot, Quests, NPCs, Events, Permadeath, Lifecycle |
| `src/client` | Input and HUD |
| `vendor/combat-system` | Reference combat implementation this was ported from (not loaded by Rojo) |
