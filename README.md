# CONDUIT (working title)

A permadeath, always-on-PvP Roblox game. It plays like a solo game until the world "emerges"
into a shared, ruined cyberpunk megacity full of quests, random events and combat.
Combat and progression are inspired by Cursed Gear and Deepwoken.

See [docs/DESIGN.md](docs/DESIGN.md) for the design and roadmap.

## Publishing
Both places publish straight to the Endeavor experience (universe 10773835758) through Open Cloud:

    ROBLOX_API_KEY=... tools/publish.sh          # builds and publishes both places (or: endeavor | front)

The key is an Open Cloud API key with Place Management: Write on the experience. Never commit it. Start place
120490278050491 is Endeavor (the city); 81481823786216 is the Front.

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
`Tab` inventory/crafting/equip · `L` loadout · `J` attributes · `M` devour remains · `P` helmetcam (first person, body visible) · `G` grab debris / hold to charge a throw · `H` drop.

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
- **City** (`src/server/City.lua`, map: `docs/maps/conduit_map.png`): four generated districts around the Pit, with ruined outskirts filling the corners between them - Transit Hub (low danger), Corp Plaza and
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

## Destruction & salvage
Built from [docs/systems/destruction-and-salvage.md](docs/systems/destruction-and-salvage.md), stories 1-7.
- **Props** (`src/shared/Props.lua`, `src/server/Destruction.lua`): streetlights, signs, crates, barrels, fences, vending
  machines, terminals, car wrecks, slabs and window panes are placed through the city. Each has health and per-type
  resistances; weapon families map to Blunt / Blade / Arc (sledge heavies count as Sledge). Breaking one spawns
  salvage remains (hold `X`) and grabbable chunks. Volatile barrels explode when broken by Arc or Explosive.
- **Grab and throw**: `G` picks up the nearest chunk within 8 studs; hold `G` to charge, release to throw at the camera
  aim. Light chunks are one-handed (pipes and sign plates double as improvised clubs that wear out); Medium chunks stop
  you blocking and slow you; Heavy ones need Strength 15. Throws run through the normal combat path (block, dodge,
  stun, knockback) and a **parry deflects a thrown chunk back at the thrower**. Speed and damage come from the server
  formula, never the client. **Catching:** press `G` as an incoming chunk is about to hit (0.25s window) to take it out of
  the air with no damage - it is yours to throw back. Pressing early costs stamina and leaves you open for 0.5s.
- **Explosions**: one shared `Destruction.Explode` with distance falloff and line-of-sight for people and world.
  **Pipe Grenade** (throwable) and **Breaching Charge** (plants on the nearest breach point) are crafted from salvage.
- **Breach points**: each district has a locked building with a door tier - Weak (blunt/thrown), Standard (sledge
  heavies), Reinforced (explosive only); Corp Plaza also has a Sealed vault that nothing opens yet. Inside: a Vault
  cache with the best loot (implants, charges, gear). Breaching is loud: nearby NPCs come to look.
- **Salvage materials and recipes**: Glass, Sheet Metal, Pipe, Battery, Powder, Sign Plating; Arc Cells (the Arc Pistol
  is now cell-fed), Pipe Grenade, Breaching Charge, Sign Plating (now part of Riot Plate).
- **Dematerialization**: every hour (10 min in Dev) the city warns for 60s, then every broken prop, door and loose
  chunk returns to intact. Doors won't reseal on someone standing in them. Taken salvage stays yours.
- **Budgets**: loose chunks cap at 150 (oldest settled ones go first), settle after 3s at rest, and fade after 3 min;
  client debris caps at 300. `Config.Destruction` holds every knob.

## Gore (Restricted)
`Config.Destruction.GoreLevel = "Restricted"` (`src/server/Gore.lua`): blood spray and pooling on hits, dismemberment on
explosive and heavy kills, and persistent corpses that settle, freeze into cover and stay for 5 minutes (capped at 60 per
server, cleared by dematerialization). `"Moderate"` keeps only a light distant spray. **The content label itself is set
in the Roblox Creator Dashboard questionnaire** (Restricted = age-verified 18+ only, blocked in some regions, cannot be
changed back - see the design doc, section 9); the code only makes the game match it.

## Hideouts, wear and upgrades
- **Wear**: every conduit weapon, armor piece and implant has a condition (shown in `Tab` and `L`). Landing hits wears
  your weapon; taking hits wears what you wear. Worn gear does less (down to half); at 0% a weapon swings as fists and
  armor protects nothing. Repair costs salvage by kind (weapons: scrap + pipe; armor: sheet metal + cloth; implants:
  wire + batteries). Upgrades (+1/+2/+3) add damage, resist or implant strength and cost more each level.
- **Hideouts** (`src/server/Hideouts.lua`, `src/shared/Hideout.lua`): twelve orange site posts in the city and outskirts;
  claim one for 10 scrap (`X`). `X` at your bench (or `O`) opens the panel. Tiers: Tinkerer's Bench -> Workshop -> Foundry,
  each raising the upgrade cap, vault size and module count. Modules: vault, walls + gate (gate tier rises with your
  workshop), alarm, generator, arc turret, forge (+2 and up), bunks (your crew spawns there), medbay.
- **Crew**: invite other conduits; they use your bench and vault and spawn at your bunks.
- **Raids**: a compound with a vault rolls NPC raids on its own clock, faster at higher tiers and with a bigger crew;
  raiders also work the gate. Any player who breaches the gate can strip the vault - the stolen gear keeps its
  condition and upgrades, so a raid can erase your progress. The hideout outlives permadeath (a crew keeps it) but only
  stands while its owner is on the server; a site taken while you were away is lost.

## The Front (war world)
A second place built from `war.project.json` (`rojo build war.project.json -o build/Front.rbxlx`), sharing the conduit
profile (same ProfileService store, same universe). Code lives in `src/war/` and `src/common/`.
- **Tapping in**: use a Neural Net terminal in any district plaza (`X`). The uplink sequence plays, then you are
  teleported to the Front controlling a recruit. **Set `Config.War.PlaceId`** after publishing the Front place;
  Studio cannot teleport between places, so test the Front by opening `Front.rbxlx` directly.
- **Recruit app** (`M` at a terminal, `N` anywhere in the city, `M` on the Front): credits, locker, shop (your faction's
  gear only), repair, and the order for your next recruit. A conduit with nothing ordered deploys as a conscript with
  the faction sidearm. Everything on a dead recruit stays on the battlefield for anyone to strip (`X`), with every part
  damaged; repair costs credits.
- **Factions and the scales**: Union vs Pact, assigned on first deployment (balanced). Tickets are global across every
  server (DataStore) and decay, so the scales keep tipping forever; a faction's share sets its conduits' credit income.
- **The hill**: one sector of the 3x3 front is hot. Presence earns tickets every 5s, kills inside earn more, holding the
  majority for 60s captures it (+50) and moves it. It moves anyway after 7 minutes. Sectors it leaves rebuild.
- **Weapons** (`src/shared/Firearms.lua`, `src/war/server/Guns.lua`): AKM, SKS, Mosin, Makarov (Pact); M16A1, M14,
  M1911 (Union). Each is a mechanism: chamber, magazine, bolt, safety, selector, and five wearing parts (receiver,
  barrel, bolt, magazine, stock). Worn parts jam, spread and kick more. Reloads are staged (eject, insert, rack) and
  partial mags go back in the pouch. Bullets are simulated with velocity, drop, falloff and hit zones (head x2.5,
  limbs x0.6); armor plates absorb damage by condition and penetration.
- **Controls** (TTK/Tarkov): `LMB` fire · `RMB` aim · `R` reload · `T` rack / clear jam · `B` selector · `1`/`2` weapon ·
  `G` frag · `H` field dressing · `Q`/`E` lean · `K` call artillery on your aim point (inside the hill, 2 min cooldown) ·
  `M` recruit app · `F` dig a foxhole (4s, stay still; a hit stops you) · `V` stack a low sandbag section (3 per
  deployment from the shop). Entrenching only works on open ground, away from buildings and other works; digging
  through fallen recruits buries them. Always first person.
- **Destruction**: structures have four stages (Intact -> Damaged -> Ruined -> Rubble) and only explosives damage them;
  shells and grenades carve craters (terrain when present, scorch otherwise). Bodies persist up to the sector cap.
- Test it without Roblox: `python3 tools/smoke/gen.py tools/smoke/war.lua > /tmp/hw.lua && luau /tmp/hw.lua`.

## Art, sound and animation
- **Models are built by script in Blender** (`tools/models/*.py`, see `tools/models/README.md`), previewed with a
  software rasterizer and uploaded as Model assets through Open Cloud. Every id lives in `src/shared/Assets.lua`;
  `src/common/ModelAssets.lua` loads, caches, dresses (materials ride in part names), anchors and places them, and
  everything falls back to generated blocks if an asset is missing. Done: street props with A/B/C wear, building kits
  per district, the four enemy rigs (R15 skeletons built by `src/server/Rigs.lua`), melee weapons and firearms held in
  the right hand (`src/common/HeldWeapons.lua`), hideout modules, walls and gate, the raid arena, the Front's props,
  staged buildings and faction bases.
- **Sounds are synthesized** (`tools/sounds/synth.py`, numpy + ffmpeg, no samples) and uploaded as Audio assets;
  `src/shared/Sounds.lua` holds the ids and `Sounds.Play(name, at)` is the one call the clients make. Ambient loops:
  city hum and wind in Endeavor, wind and distant guns on the Front.
- **Animation is procedural**: the clients tween Motor6D offsets under Roblox's idle/walk animations for swings (windup,
  slash), hostile telegraphs, flinches, guard poses and guard jolts. Animation assets can't be uploaded through Open
  Cloud, so there are none.
- **The director** (`src/server/Events.lua`) throws events at an open world every 1 to 2.5 minutes: supply drops,
  raider ambushes, blackouts (the city goes dark, Shockers come out), Warden patrols, salvage caches and dead drops at
  hideout sites. Quests (`src/server/Quests.lua`) chain forever and now include breaking things, catches, Black Flash
  and tapping in to the Front.
- **Playtest checklist**: `docs/TESTING.md`.

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
