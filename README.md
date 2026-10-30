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

## Controls (Cursed Gear layout)
`LMB` attack (your weapon's combo) · `RMB` heavy/critical · `F` block (tap just before a hit to parry) · `Q` dodge ·
**`E` flicker** · `Z` feint (cancel a swing's windup) · `R` / `Y` / `V` skill slots 1-3 · `X` interact (loot, armory) ·
`Tab` inventory/crafting/equip · `L` loadout · `J` attributes · `M` devour remains · `P` helmetcam (first person, body visible).

## Flickering cursed energy (Black Flash)
Tap `E` just *before* your swing connects (within ~0.28s). A well-timed flick boosts that hit (x1.25) and starts a chain;
the next flicked hit is x1.6; the **third consecutive flicked hit is a Black Flash**: x2.5 damage, guard-breaking, long
stun, charge refund, and you enter **the Zone** for 8s (wider window, Flash needs one fewer link). Each flick costs
Charge (built by landing hits). Mis-timed flicks just waste charge; taking a hit, being dodged or parried breaks the chain.
Blocking is not enough against a Flash - parry or dodge it. Everything is tunable in `Config.Flicker`.

## Tutorial
The prologue room is now a guided tutorial (`src/server/Tutorial.lua`, skippable with the Skip button): move, spend
attributes, loot a locker (hold `X`), craft a Medkit, wear armor, attack, heavy, **flick into a Black Flash**, then dodge,
parry and block a training dummy that telegraphs its strikes, feint, and use a skill. Each step has a live counter. Once
every player has finished or skipped (and 30s have passed) the world opens early; otherwise it opens at the 10-minute cap.
`Config.Tutorial.Enabled = false` restores the short timed prologue.

## The city, raids and devouring
- **City** (`src/server/City.lua`): four generated districts around the Pit - Transit Hub (low danger), Corp Plaza and
  The Sprawl (medium), Blackout Zone (high). Ruined towers with ledges, rubble, neon signage, a pylon per district for
  navigation, refilling loot caches, and a banner when you cross into a district. Replace any district with hand-built
  art later; the generator is only there so the world exists now.
- **Raids** (`src/server/Raids.lua`): the Blackout Gate opens a 20s join window for up to 6 players, teleports them to
  a sealed arena and runs four waves (Raiders, Shockers, a Brute, then the **Warden** boss with a telegraphed slam and
  lunge). Enemies scale with party size. Clearing it drops a vault (3x supply rolls + a guaranteed implant) and 400 xp,
  then extracts you. Dying inside is still permadeath.
- **Enemies** (`src/server/NPCs.lua`): Raider, Brute (hyperarmor, big knockback), Shocker (arc damage, stuns), Warden.
  Every attack is telegraphed with a red flash (orange = unblockable) so parry/dodge timing is readable.
- **Devour** (`M` on remains): consume a body for xp, full charge and a heal instead of looting it. Takes longer than
  looting and destroys the loot, so it is a choice and a risk.
- **Spawn protection**: 8s of invulnerability after spawning into the open world or extracting from a raid.
- **Net** (`src/server/Net.lua`): every client->server remote is rate-limited and type-checked before any system sees it.

## Test arena
With `Config.Dev.Enabled = true` (default for now) the prologue is 15s and the world opens into a generated neon arena:
ring with 4 gates, pillars, cover, a center platform and 8 spawn pads. The **Test Armory** outside the south gate has free
weapons / armor / cybernetics / materials, an Instructor (+10 attribute points), Respec, Recharge (also on the center
platform), and three regenerating dummies that show damage numbers. Set `Dev.Enabled = false` for a real release.

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
