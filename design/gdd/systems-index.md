# Systems Index: Endeavor — Universe 1: Conduit

> **Status**: Draft (reverse-documented)
> **Created**: 2026-10-25
> **Last Updated**: 2026-10-25
> **Source Concept**: design/gdd/game-concept.md (from design/game-brief.md)

---

## Overview

Conduit is a server-authoritative Roblox action game: every gameplay decision runs in
`src/server`, data tables live in `src/shared`, and the single client script only sends intent and
draws the HUD. The mechanical scope is a timing-melee core (Combat, Flicker, Weapons) fed by a
build layer (Stats, Gear, Armor, Cybernetics, Skills), wrapped in a permadeath survival loop
(PlayerData, Permadeath, Loot, Inventory, Quests, Events) and framed by the Prologue → Emergence
structure (WorldPhase, Tutorial, Lifecycle). Status below is read from the code itself:
**Implemented** = runs and is complete for its stated scope; **Placeholder** = runs but is
explicitly a stand-in (comment or brief says so); **Planned** = referenced by docs/brief, not in code.

---

## Systems Enumeration

One row per module in `src/server` and `src/shared` (plus the client and the planned systems the
brief names). "Owning GDD" is a file under `design/gdd/`.

| # | System Name | File(s) | Category | Priority | Status | Owning GDD | Description |
|---|-------------|---------|----------|----------|--------|------------|-------------|
| 1 | Config (tuning) | `src/shared/Config.lua` | Core | MVP | Implemented | combat.md, flicker.md (sections) | Every designer-tunable number: phases, prologue timers, Stats, Flicker, Combat tables. |
| 2 | Remotes | `src/shared/Remotes.lua` | Core | MVP | Implemented | none yet | Creates 14 client→server and 9 server→client RemoteEvents; same API both sides. No rate limiting. |
| 3 | Combat | `src/server/Combat.lua` | Gameplay | MVP | Implemented | combat.md | Frame-data swings, cone/raycast hitboxes, block/parry, posture & guard break, hit stun, dodge, feint, knockback, regen loop, kill credit. |
| 4 | Flicker / Black Flash | `src/server/Combat.lua:124-188, 361-423` | Gameplay | MVP | Implemented | flicker.md | Timed flick chain, Black Flash, the Zone, charge economy. |
| 5 | Weapons (moveset data) | `src/shared/Weapons.lua` | Gameplay | MVP | Implemented | weapons.md | Seven weapons; each defines combo chain, heavy, frame data, reach, arc, damage type. |
| 6 | Gear (derived stats, equip, skill slots) | `src/server/Gear.lua` | Progression | MVP | Implemented | none yet | Computes effective numbers from stats + armor + cybernetics; equip/unequip; auto-slots unlocked skills. |
| 7 | Stats (attributes, XP, level) | `src/server/Stats.lua` | Progression | MVP | Implemented | none yet | Five attributes, XP → level → 3 points; applies derived numbers to the Humanoid. |
| 8 | Armor (data) | `src/shared/Armor.lua` | Progression | MVP | Implemented | none yet | Nine pieces over Head/Chest/Legs: resists, posture, stat bonuses, weight, tags. |
| 9 | Cybernetics (data) | `src/shared/Cybernetics.lua` | Progression | MVP | Implemented (full body 2026-10-27) | `design/gdd/cybernetics.md`, flicker.md (perks) | The whole body is rippable: eight slots (eyes, ears, nose, core, both arms, both legs), thirteen pieces; each slot kind has its own benefit (timing, hearing, scent, engine, force + lift, movement). |
| 10 | Skills (data + unlock/power) | `src/shared/Skills.lua` | Gameplay | MVP | Implemented | none yet | Seven class-free skills gated by effective stats and worn tags; power scales with both. |
| 11 | SkillRunner | `src/server/SkillRunner.lua` | Gameplay | MVP | Implemented | none yet | Executes slotted skills by Kind (Burst/Strike/Dash/Buff/Recover/Flicker); pays costs and cooldowns. |
| 12 | Items / Recipes / Loot tables (data) | `src/shared/Items.lua` | Economy | MVP | Implemented | none yet | Item registry (materials, consumables, gear), 15 recipes, two independent-roll loot tables. |
| 13 | Inventory & Crafting | `src/server/Inventory.lua` | Economy | MVP | Implemented | none yet | Add/remove/use/equip/craft; fires Added/Crafted for quests and tutorial. |
| 14 | Loot (world pickups) | `src/server/Loot.lua` | Economy | MVP | Implemented | none yet | Hold-to-loot ProximityPrompt parts for remains, drops and crates; first looter wins. |
| 15 | Quests | `src/server/Quests.lua` | Narrative | Vertical Slice | Implemented | none yet | One active quest from a pool of four (collect/kill/craft/bounty); XP + item rewards. |
| 16 | Events (director) | `src/server/Events.lua` | Gameplay | Vertical Slice | Implemented | none yet | Weighted roll every 60-150 s once open: supply drop (3) or raider ambush (4). Spawns relative to a random player, not bounded to the map. |
| 17 | NPCs (Enemy v2) | `src/server/NPCs.lua`, `src/shared/Enemies.lua` | Gameplay | MVP | Implemented | enemies.md | Standardized rigs, `Combat.Swing` telegraphed attacks, pathfinding, leash/despawn, Grunt/Brute/Gunner, ground-checked ambush placement |
| 18 | Enemy v2 (Grunt/Brute/Gunner) | — | Gameplay | MVP | Planned | enemies.md (Planned section) | R15 rig, PathfindingService, telegraphed attacks. Brief build-order item 3. |
| 19 | PlayerData | `src/server/PlayerData.lua` | Persistence | MVP | Implemented | none yet | One ProfileService profile per player (`ConduitCharacter_v2`), session-locked; reset in place on death. |
| 20 | ProfileService (vendored) | `src/server/ProfileService.lua` | Persistence | MVP | Implemented (third-party) | none yet | MadStudioRoblox ProfileService, Apache-2.0. Not a game system; listed for completeness. |
| 21 | Permadeath | `src/server/Permadeath.lua` | Gameplay | MVP | Implemented | none yet | Drops all inventory as remains, credits killer, records legacy, wipes the profile. Combat-log variant. |
| 22 | WorldPhase (Prologue → Emergence) | `src/server/WorldPhase.lua` | Core | MVP | Implemented | none yet | Private plots, ready-tracking, timer cap, Emergence cinematic + teleport, CitySpawn selection, placeholder slab. |
| 23 | Tutorial | `src/server/Tutorial.lua` | Meta | MVP | Implemented | none yet | 15 data-driven steps in the private room with a telegraphing dummy; completion marks the player ready. |
| 24 | Lifecycle | `src/server/Lifecycle.lua` | Core | MVP | Implemented | none yet | Join/load → spawn → death → respawn → leave; combat-log check on leave. |
| 25 | Arena (dev) | `src/server/Arena.lua` | Meta | MVP (dev only) | Implemented (dev tool) | none yet | Generated neon coliseum, 8 spawn pads (`CitySpawn` only with `Config.Dev.SpawnInArena`), Test Armory consoles, regenerating dummies. Built at `Config.Dev.ArenaOffset`, behind `Config.Dev.Enabled`. |
| 26 | Client (input + HUD) | `src/client/Main.client.lua` | UI | MVP | Implemented (placeholder presentation) | combat.md (Current Presentation) | Key bindings, bars, panels, tutorial panel, death screen, Highlight-flash combat feedback, client-owned dodge/knockback velocity. |
| 27 | HUD v2 | `src/client/Hud.lua`, `src/client/HudCombat.lua` | UI | MVP | Implemented (owner playtest pending) | combat.md (Current Presentation) | Labelled bars with values, custom health bar, client-drawn damage numbers / BLOCKED / PARRIED / GUARD BREAK / DODGED, aim reticle + hit marker, damage-taken edge flash, PlayerList hidden (Tab conflict), dodge feedback (brief item 4). |
| 28 | Fair Arrival (spawn protection, rate limits) | — | Core | MVP | Planned | none yet | Brief item 5. Nothing in code. |
| 29 | District Blockout | `src/shared/District.lua`, `src/server/District.lua` | Gameplay | Vertical Slice | Implemented (owner playtest pending) | `production/epics/district-blockout/EPIC.md` | Seeded 5×5 block grid: streets (`PlayableArea`), buildings, rubble, cover, lamps, perimeter wall, 8 `CitySpawn` pads, Relay Plaza safe zone (`SafeZone` tag; `Combat` refuses damage in/out, NPCs ignore players inside). Replaces the placeholder slab; arena moved aside (brief item 6). |
| 30 | Smoke harness (tooling) | `tools/smoke/*` | Meta | — | Implemented (tooling) | none yet | Mock-Roblox Luau run of the full join → tutorial → Emergence → PvP → permadeath flow. |
| 31 | Appearance | `src/shared/Appearance.lua` | Shared data | P2 | Implemented | `design/quick-specs/character-creator-2026-10-25.md` | Catalog of body/skin/face/hair choices; the profile stores indices into it |
| 32 | Rig | `src/server/Rig.lua` | Server | P2 | Implemented | `design/quick-specs/character-creator-2026-10-25.md` | Builds the standardized R15 body from the catalog; replaces LoadCharacter |
| 33 | Creator | `src/server/Creator.lua`, `src/client/Creator.client.lua` | Server + Client | P2 | Implemented | `design/quick-specs/character-creator-2026-10-25.md` | First-spawn look picker with live preview |
| 34 | Animate (stopgap) | `src/client/Animate.client.lua` | Client | P3 | Placeholder | `design/quick-specs/character-creator-2026-10-25.md` | Stock R15 locomotion for server-built rigs |
| 35 | Weapon Handling / Sight picture | `src/client/ViewModel.lua`, `SwingAnimator.lua`, `Aim.lua`, `WeaponView.lua` (sights) | Presentation | Post-MVP | Implemented (owner playtest pending) | `production/epics/weapon-handling/EPIC.md` | Two-handed stances, pistol hold, ADS first-person view with real iron sights (`Sight` attachment = aim line), validated camera-direction shots (`Config.Combat.AimCone`). Universe 2 foundation. |
| 36 | The Range (Universe 2 prototype) | `src/server/Range.lua`, `Config.Range`, `Weapons.ArcRifle` | Gameplay | Phase 2 | Implemented (owner playtest pending) | `production/epics/range/EPIC.md` | In-place shooter zone: Rifts, forced first person, Arc Rifle, target lane with distance scoring, Gunner waves, ranged-only rule. |
| 37 | Momentum & Cancels (Nero study) | `Config.Momentum`, `Skills.Snatch/Buster`, `Combat.Dodge`, `SkillRunner` Pull/Grab | Core | Phase 2 | Implemented (owner playtest pending) | `design/gdd/momentum.md` | Dodge-cancel keeps the combo, side dodges longer i-frames, Hop stamina refund, Snatch pull, Buster throw/shove, Launcher (heavy on an open enemy), juggle pops + bonus damage, Enemy Step. |
| 38 | District 2 + gate street | `District.Districts`, `District.Gate`, `server/District.lua` (ctx), `WorldPhase.eligibleSpawns`, `Enemies.Ambush.ByDistrict` | Gameplay | Phase 2 | Implemented (owner playtest pending) | `production/epics/district-2/EPIC.md` | Second seeded district (Ferrite Court) at `District.Pitch()` along +X, gate street through both walls, spawn pads split Fresh/Awakened, heavier ambush mix in D2. |
| 39 | Drone (flying enemy) | `Enemies.Defs.Drone`, `NPCs.buildDroneRig` + flight AI | Gameplay | Phase 2 | Implemented (owner playtest pending) | `design/gdd/enemies.md` (Flying enemies) | Constraint-flown machine body, orbit/strafe in the air, LOS fire along the pitched look; in Range waves 2–3. |
| 40 | Gunplay (Tarkov study) | `Config.Gunplay`, `Weapons.*.Gun`, `Combat` (zones, spread, ammo, ADS), `client/Aim` (recoil), `Hud` (ammo) | Core | Phase 2 | Implemented (owner playtest pending) | `design/gdd/gunplay.md` | Hit zones, honest camera recoil with patterns, stance spread, magazines + reloads, ADS state. |
| 41 | Hideout + extraction + wallet | `server/Hideout.lua`, `server/Wallet.lua`, `Config.Hideout`, `Config.War`, `PlayerData.PERSIST` | Core | Phase 3 | Implemented (owner playtest pending) | `production/epics/hideout/EPIC.md` | Stations in every district (hold X, refused in combat) → private safe hideout: deploy, return, stash (survives permadeath), faction choice; Money wallet on the HUD; the Range leaves into the hideout. |
| 42 | Wardogs (the perpetual war) | `server/War.lua`, `Config.War`, `Enemies.Defs.Recruit`, `NPCs` (faction targeting, `Killed`), `Combat.LethalHook`/`FactionOf`, `Lifecycle.onDied`, `Hud` (war board, DOWNED) | Core | Phase 3 | Implemented (owner playtest pending) | `design/gdd/war.md` | Three sides, one moving hill, tickets; AI recruits by pod and cloning facility; deploy from the hideout; downed/revive/redeploy — a war death never touches the Conduit; hill time, revives, takedowns and round wins pay money. |
| 43 | Supply (faction pool + shipments) | `server/Supply.lua`, `Config.Supply`, `profile.Shipment`, `War` (crates, field kit), `NPCs` (opts.Kit), `Hideout` (two consoles), `Hud` | Core | Phase 3 | Implemented (owner playtest pending) | `design/gdd/war.md` §6 | Donated stash → your side's pool → the kit tier AI recruits spawn with (and pay for); your own stash gear shipped ahead lands as a crate at your base — lose it where you fall, carry it home alive. |
| 44 | Weapon bench (parts + builds) | `shared/Attachments.lua`, `server/Bench.lua`, `profile.Builds`, `Combat.WeaponDefOf`, `client/Aim` (built recoil), `Hud` (Workbench section), `WeaponView`/`ViewModel` (torch, laser), `Remotes.Bench` | Feature | Phase 3 | Implemented (owner playtest pending) | `design/gdd/gunplay.md` §4 | Six slots, eleven parts, regional drops + three recipes; fit / strip / strip-to-frame at the hideout; one effective weapon spec for server shots and client kick; torch and laser visible on the gun. |
| 45 | Open world v1 (regions + transport) | `shared/Regions.lua`, `server/Regions.lua`, `server/Transport.lua`, `profile.Hubs`, `District` north gap, `Hud` (Trader section), `Remotes.Buy` | World | Phase 3 | Implemented (owner playtest pending) | `design/gdd/world.md` | The wasteland road north of District 1 with fixed guards; Verdant Reach (solarpunk enclave) with a safe market and a parts trader; two stations and a train line that unlock by standing on them. |
| 46 | Warmonger | `Enemies.Defs.Warmonger`, `NPCs` (Dash branch), `Items.LootTables.Warmonger` | Enemy | Phase 3 | Implemented (owner playtest pending) | `design/gdd/world.md` §4 | The open world's elite: brute-class heavy, high poise, a flicker-step dash from mid-range; drops cybernetics and the good parts. |
| 47 | The hideout computer (raids, contacts, house, market) | `shared/Raids.lua`, `server/Raids.lua`, `server/Terminal.lua`, `server/Contacts.lua`, `Hud` (Terminal panel, raid line), `client/HouseView.lua`, `profile.Contacts/Board/House/Raid` | Core | Phase 3 | Implemented (owner playtest pending) | `design/gdd/raids.md` | Contracts with kill / reach / hold steps that end in extraction or continue through a lead (×1.5); apps unlocked by meeting the broker / fixer / dealer in the world; house furnishings drawn for their owner; the black market. |
| 48 | Rival crews + everything drops | `server/Rivals.lua`, `Enemies.Defs.Rival`, `Items.LootTables.Rival`, `NPCs.packCarry` / `Carrying` | Enemy | Phase 3 | Implemented (owner playtest pending) | `design/gdd/raids.md` §4–5 | Crews of rival conduits walk routes between raid points unannounced and drop intel; every enemy's carry (weapon, kit armour, one roll) is fixed at spawn and dropped in full. |
| 49 | Places door (Travel) | `server/Travel.lua`, `Config.Places`, hooks in `Hideout`, `War.Deploy`, `Lifecycle.Spawn` | Infrastructure | Phase 3 | Groundwork (places not yet published) | `production/epics/places/EPIC.md` | One call between the worlds: a pivot in one place today, a teleport (profile released, Location set, reserved server for the hideout) once `Config.Places` has ids. |
| 50 | World FX + barks | `client/WorldFX.lua`, `Enemies.Barks`, `NPCs` Bark attribute | Presentation | Phase 3 | Implemented | `design/gdd/raids.md` §7 | First-sight speech bubbles within hearing range; dash streaks, landing shakes, downed / revive / hill / shipment pulses. |
| 51 | Keyframed combos + Magoi polish | `Presentation.Swings` (Keys, Settle), `client/SwingAnimator.lua` (Freeze / Settle), `WeaponView.AddTrail`, `WorldFX.Dust`, `Presentation.Aim.Melee / Ranged`, `Hud.lua` composite bar, `Presentation.Impacts` Freeze, `District.NeonDim`, `client/Prompts.lua`, `client/Nameplates.lua` | Presentation | Phase 3 | Implemented (owner playtest pending) | `production/epics/combat-feel/story-006-keyframed-combos-and-magoi-polish.md` | Per-combo-step keyframed swings (spear = thrust, thrust, swipe), idle stances, landing settle, body freeze on contact, weapon trails, dust, far melee camera, bottom-centre bar + hotbar, dimmed district neon, key-badge prompts, hip-height nameplates. |
| 52 | Destruction & salvage (Conduit world) | `Destructible` / `Breachable` tags, `Config.Destruction`, salvage via `Loot.Spawn`, grab & throw on G, shared `Explosion` | Core | Phase 3+ | Stories 001–002 implemented (Studio push + playtest pending); grab, explosions, breaches next | `design/gdd/destruction.md` | Props break into chunks and salvage, authored breach points open interiors loudly, debris is grabbed and thrown through the combat hit path; resets on the hourly dematerialization (row 54). |
| 53 | War-world destruction | structure stages, terrain craters, body persistence, sector rebuild keyed to `War` hill moves | World | Phase 3+ | Designed (not started) | `design/gdd/destruction.md` §4.7 | Explosives and artillery tear up the sector the hill is in; it rebuilds after the hill moves on and the sector empties. |
| 54 | The cycle (dematerialization) | `server/Cycle.lua`, `Config.Cycle`, `Cycle_Phase` / `Cycle_Index` workspace attributes, `Contacts.Place`, `Regions.SpawnGuards`, `Rivals.Reset`, WorldFX hum / flicker / white-out | World | Phase 3+ | Implemented (Studio push + owner playtest pending) | `design/gdd/dematerialization.md` | Every hour the Conduit world comes apart and is restored exactly; only player / enemy spawns, vendor spots and loot are re-drawn. The conduits read it as proof the world is simulated; each cycle carries clues (contact lines, fragments at anomaly spots, a computer ARCHIVE). |
| 55 | The home computer (acquired) | `Items.Defs.HomeComputer`, `Terminal.Install`, `PlayerData` HIDEOUT_KEPT / MIND_KEPT, `profile.Computer`, HouseView empty desk | Core loop | Phase 3+ | Implemented (Studio push + owner playtest pending) | `design/gdd/dematerialization.md` §6 | A conduit starts with an empty desk; a found or built computer is the upload, and only after it does the mind (contacts, knowledge, board, house) survive permadeath. |
| 56 | Clues + knowledge + ARCHIVE | `shared/Clues.lua`, `server/Clues.lua`, `profile.Knowledge`, Fragment items, `Items.Recipes[*].Needs`, `CycleLine_*` attributes, WorldFX anomalies, the ARCHIVE app | Narrative | Phase 3+ | Implemented (placeholder content; Studio push + owner playtest pending) | `design/gdd/dematerialization.md` §5 | Each cycle draws the contacts' lines and which fragments are out where, marked by anomalies; reading one becomes knowledge (kept once uploaded), fills the ARCHIVE and can teach a recipe. |
| 57 | The Autonet | `server/Autonet.lua`, `Config.Cyber`, `Remotes.Autonet`, `AutonetKit` (knowledge-gated recipe), the hideout bay, `AtAutonet` / `Ripping` attributes, WorldFX rip overlay | Core | Phase 3+ | Implemented (Studio push + owner playtest pending) | `design/gdd/dematerialization.md` §6 | Cybernetics are ripped in or out only at an Autonet you learned, crafted and installed; each rip is a channel that costs health (never lethal), a swap costs two. |
| 58 | Senses (cybernetic ears and nose) | `client/Senses.lua`, player attributes `Hearing` / `Scent` / `Track` (Gear), the `Scent` tag (Loot, Clues) | Progression | Phase 3+ | Implemented (Studio push + owner playtest pending) | `design/gdd/cybernetics.md` §4 | Ears: pips on a ring for unseen moving bodies in range. Nose: markers on loot and fragments in range; Track marks the wounded. |
| 59 | Visible implants | `client/Implants.lua`, `Cyber_<slot>` character attributes, `Presentation.Implants` (art drop-in) | Presentation | Phase 3+ | Implemented (placeholder art) | `design/gdd/cybernetics.md` §5 | Whatever is ripped into a body shows on it for everyone: metal shells on limbs, lit bits on head and chest; meshes replace them when the art lands. |
| 60 | Machine voice (full conversion) | `shared/Voice.lua`, `client/Speech.lua`, `Machine` player attribute, `Lore.FullConversion`, `Presentation.Voice` | Presentation | Phase 3+ | Implemented (Studio check pending: bubble text) | `design/gdd/cybernetics.md` §6 | All metal and you lose your humanity: your chat comes out flat, in capitals, with no laughter, and the bubble turns cold. Rip a piece out and the voice comes back. |

---

## Categories

| Category | Description | Systems here |
|----------|-------------|--------------|
| **Core** | Foundations everything depends on | Config, Remotes, WorldPhase, Lifecycle, Fair Arrival |
| **Gameplay** | What makes the game fun | Combat, Flicker, Weapons, Skills, SkillRunner, NPCs, Enemy v2, Events, Permadeath, District Blockout |
| **Progression** | How the player grows | Stats, Gear, Armor, Cybernetics |
| **Economy** | Resource creation and consumption | Items, Inventory & Crafting, Loot |
| **Persistence** | Save state | PlayerData, ProfileService |
| **UI** | Player-facing displays | Client, HUD v2 |
| **Narrative** | Story and quest delivery | Quests |
| **Meta** | Outside the loop | Tutorial, Arena, Smoke harness |

---

## Priority Tiers

| Tier | Definition | Target Milestone |
|------|------------|------------------|
| **MVP** | Needed for the brief's "working" scenario (tutorial → emerge → beat a telegraphed enemy → Black Flash → loot a drop) | Friend-testing build |
| **Vertical Slice** | One complete district with the full loop | Vertical slice |
| **Alpha** | Deferred features from the brief's out-of-scope list | Alpha |

---

## Dependency Map

Derived from `require` graphs in `src/server` (`Main.server.lua` init order: Arena, WorldPhase, Gear,
Stats, Inventory, Quests, Combat, SkillRunner, Events, Tutorial, Lifecycle).

### Foundation Layer (no in-game dependencies)
1. Config — pure data.
2. Remotes — creates events; no game logic.
3. Weapons / Armor / Cybernetics / Skills / Items — pure data modules (Items requires the other three to register them as items).
4. ProfileService — vendored library.

### Core Layer
1. PlayerData — depends on: Config, ProfileService.
2. Gear — depends on: PlayerData, Armor, Cybernetics, Skills, Weapons, Config, Remotes.
3. Stats — depends on: Gear, PlayerData, Config, Remotes.
4. WorldPhase — depends on: PlayerData, Config, Remotes.
5. Inventory — depends on: Items, PlayerData, Gear, Remotes.

### Feature Layer
1. Combat — depends on: Gear, PlayerData, WorldPhase, Weapons, Config, Remotes.
2. SkillRunner — depends on: Combat, Gear, PlayerData, Skills, Weapons, Remotes.
3. Loot — depends on: Inventory, Config.
4. Quests — depends on: PlayerData, Stats, Inventory, Remotes.
5. NPCs — depends on: Combat, Loot, Quests, Stats, Items.
6. Permadeath — depends on: Combat, Loot, PlayerData, Quests, Stats, Remotes, DataStoreService (legacy store).
7. Events — depends on: Loot, NPCs, WorldPhase, Items, Remotes.
8. Tutorial — depends on: Combat, Inventory, Loot, NPCs, PlayerData, WorldPhase, Skills, Config, Remotes.

### Presentation Layer
1. Client — depends on: Remotes, Config, Items, Skills, Armor, Cybernetics; reads character attributes (`Stamina`, `Posture`, `Charge`, `Flicker`, `Zone`, `Blocking`).
2. Arena — depends on: Gear, Inventory, NPCs, PlayerData, Stats, data modules.

### Orchestration
1. Lifecycle — depends on: Combat, Gear, Inventory, Permadeath, PlayerData, Quests, Stats, Tutorial, WorldPhase, Config.

---

## Recommended Design Order

Systems without a GDD, ordered by how many open MVP epics touch them.

| Order | System | Priority | Layer | Est. Effort |
|-------|--------|----------|-------|-------------|
| 1 | Stats & Gear (attributes, derived numbers, armor, cybernetics) | MVP | Core | M |
| 2 | Skills & SkillRunner | MVP | Feature | M |
| 3 | WorldPhase + Lifecycle (incl. Fair Arrival: spawn protection) | MVP | Core | M |
| 4 | Permadeath + Loot + PlayerData | MVP | Feature | S |
| 5 | Tutorial | MVP | Meta | S |
| 6 | HUD (Client) — as a UX spec, not a GDD | MVP | Presentation | M |
| 7 | Events + Quests + Inventory/Items (economy) | Vertical Slice | Feature | M |

---

## Circular Dependencies

- None at module level: `require` edges form a DAG (`Combat` → `Gear` → `PlayerData`; `SkillRunner` → `Combat`). Runtime coupling runs the other way through BindableEvents (`Combat.Resolved`, `Combat.Used`, `Gear.Changed`, `Inventory.Added/Crafted`) so lower layers never require upper ones.

---

## High-Risk Systems

| System | Risk Type | Risk Description | Mitigation |
|--------|-----------|-----------------|------------|
| Combat presentation | Design | All feedback today is a 0.15 s Highlight flash; the `Swing` CombatEvent is fired but unhandled on the client (`Main.client.lua:380`). Combat is unreadable. | Combat Feel epic (brief item 1). |
| NPCs | Design / Scope | Raider attack has no windup — the "read its windup" scenario in the brief cannot happen against it. | Enemy v2 (enemies.md Planned section). |
| Remotes | Technical | No rate limits or payload validation beyond type checks; `Attack` spam is gated only by stamina. | Fair Arrival (brief item 5). |
| Events | Design | Supply drops land at a random ±250-stud offset from a player with no bounds check; can land outside the arena or in a wall. | Brief item 5 ("events that spawn inside the playable area"). |
| Timing windows over network | Technical | Parry (0.22 s) and flick (0.28 s) are judged with server `os.clock()`; no latency compensation. | NOT ASSESSED — needs a networked playtest. |

---

## Progress Tracker

| Metric | Count |
|--------|-------|
| Total systems identified | 41 (37 in code, 4 planned) |
| Design docs started | 4 system GDDs + concept + this index |
| Design docs reviewed | 0 |
| Design docs approved | 0 |
| MVP systems with a GDD | 5/22 (Combat, Flicker, Weapons, NPCs, Client-as-presentation) |

---

## Next Steps

- [ ] Review this enumeration against `Main.server.lua` whenever a module is added.
- [ ] Author the "none yet" MVP GDDs in the recommended order.
- [ ] Run `/design-review` on `design/gdd/combat.md` before the Combat Feel epic.
