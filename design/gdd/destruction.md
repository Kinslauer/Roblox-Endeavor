# Destruction & Salvage

Status: **Designed, not implemented** · Worlds: **Conduit (Universe 1) and War World** · Owner: solo

> Written 2026-10-26 15:06 in another session on the default branch (`claude/roblox-permadeath-openworld-cj3jfk`,
> which predates Phase 3). Brought onto `claude/combat-feel` and reconciled with the current build the same day,
> 17:30 — see §13 for what changed. The owner's locked decisions (§3) are unchanged. **Epic**:
> `production/epics/destruction/EPIC.md`.

## 1. Overview

The environment is a weapon, a resource and a door. Explosions, heavy hits and thrown debris break props and authored structures. What breaks becomes salvage (crafting materials and ammo), improvised weapons (grab and throw), or a new way in (breaching locked buildings).

The two worlds use the same system with different dials:

| | Conduit world | War world |
|---|---|---|
| What breaks | Authored breach points + destructible props everywhere | Structures in stages, terrain, props |
| Main tools | Heavy melee, thrown debris, scarce explosives | Explosives and artillery everywhere (no vehicles) |
| Terrain craters | No (scorch decals only) | Yes |
| How it resets | Every hourly **dematerialization** | Per sector, after the moving hill leaves it |
| Feel | Scavenger improvising with the ruins | Battlefield spans ground into metal and bodies |

## 2. Player fantasy

- **Conduit:** "I didn't find a key. I blew the wall open, ripped a street sign off its post, cut it into plating, and threw a streetlight at the guy who followed me in."
- **War world:** "By the third push the town we were fighting over is gone. The hill moved on through craters and wreckage that we made."

## 3. Decisions (locked 2026-10-26)

1. **Conduit persistence:** breached walls and broken props stay broken until the world **dematerializes (every hour)**, then everything rematerializes intact.
2. **Scope:** **authored breach points plus destructible props everywhere.** Not every wall breaks. Level designers decide where the alternate entrances are; props are free-form.
3. **Gore:** **as far as Roblox allows.** Built behind a `GoreLevel` setting so the launch label can be chosen without rework (see §9).

## 4. Detailed rules

### 4.1 Damage types and what they can break

Every hit that can break the world carries a **break type**. This is a new field (`Break`) on attack specs, separate
from the `Type` that combat already uses for armour resists (`Physical` / `Arc`, `Combat.lua` resist line), so no
existing armour changes. When an attack has no `Break`, it defaults from the weapon's `Family`: Fists / Blunt / Baton /
Hammer -> Blunt, Blade / Spear -> Blade, any `Type = "Arc"` attack -> Arc. Explosions add a third resist class,
`Explosive`; armour without it resists 0.

| Break type | Sources | Breaks |
|---|---|---|
| Blunt | Fists, pipe club, sledge, shock baton (breaks as Blunt), heavies | Props, glass, weak breach points |
| Blade | Rebar blade, scrap spear | Props (cloth, wood, signs), glass |
| Arc | Arc pistol, arc rifle, Conduit powers | Props, electronics (streetlights, terminals, cameras) |
| Thrown | Grabbed debris | Props, glass, weak breach points |
| Explosive | Grenades, breaching charges, artillery | Everything, including reinforced breach points and war-world structures |

### 4.2 Destructible props (Conduit + war world)

Tagged `Destructible` with CollectionService. Each prop has:

- `Health` and an optional `Resist` per damage type (a streetlight shrugs off Blade).
- `BreakInto`: the pre-fractured model it swaps to (2–6 chunks, not dozens).
- `Salvage`: a salvage table id (§4.4).
- `Grabbable` chunks: which of those chunks can be picked up, and their weight class (§4.5).

On break: the intact prop is hidden, the pre-fractured version replaces it, chunks get a small outward impulse, and the client adds cosmetic dust/sparks/glass.

Starter prop list: streetlight, street sign, traffic light, fence panel, crate, barrel, wrecked car door/hood, bench, vending machine, terminal, window pane.

### 4.3 Breach points (Conduit)

Tagged `Breachable`. Authored by hand on locked-down buildings, vaults, shutters and compound walls.

| Tier | Example | Can be opened by |
|---|---|---|
| Weak | Boarded window, rotten door, drywall | Blunt heavies, thrown Medium/Heavy debris, Explosive |
| Standard | Apartment door, chain-link gate | Sledge heavies (multiple), Explosive |
| Reinforced | Shutter, vault door, corp wall | Explosive only |
| Sealed | Story-critical | Never; key, quest or contact only |

Rules:

- A breached point swaps to its authored "hole" model, so the opening is always a size the level was designed for (players can't crawl through a gap that skips content).
- Breaching is **loud**: it fires an `Events` noise ping that NPCs and nearby players can hear. Breaching is a choice between speed and stealth, not a free skeleton key.
- Interiors behind breach points carry better loot tables, so breaching gear (charges, sledges, Strength) is worth investing in.

### 4.4 Salvage

When a prop breaks, it leaves two things:

1. **Salvage remains**: a hold-to-loot prompt using the existing `Loot.Spawn`, rolling the prop's salvage table. Hold time is the risk window, exactly like body loot.
2. **Usable chunks**: grabbable pieces that can be thrown, wielded or broken down at a bench.

Proposed new materials (initial tuning):

| Material | Comes from |
|---|---|
| Glass | Windows, streetlights, vending machines |
| SheetMetal | Street signs, car panels, shutters |
| Pipe | Streetlight posts, railings, fences |
| Battery | Streetlights, terminals, traffic lights |
| Powder | Barrels, chem crates (rare) |

Proposed recipes, added to `Items.Recipes`:

| Output | Inputs | Notes |
|---|---|---|
| Arc Cell ×6 (arc weapon reserve) | Battery 1, Wire 2 | Arc weapons already have magazines and reloads (`Weapons.Defs[id].Gun`); cells become the reserve a reload draws from (§4.4a) |
| Scrap Rounds ×10 | Scrap 2, Powder 1 | For firearms added later |
| Pipe Grenade ×1 | Pipe 1, Powder 2, Wire 1 | Thrown explosive |
| Breaching Charge ×1 | SheetMetal 1, Powder 3, Wire 2, Battery 1 | Opens Reinforced breach points |
| Sign Plating | SheetMetal 3, Cloth 1 | Armor upgrade material |

A pipe or sign chunk can also be held as an improvised melee weapon. It uses the club moveset (`Presentation.Swings.Families.Blunt`) and breaks after N hits.

#### 4.4a Arc Cells (reconciled; owner, 17:37: "all weapons are consistent")
Today a reload is free: `Gun.Magazine` rounds, `Gun.Reload` seconds, no reserve. With cells, a reload consumes **one
Arc Cell and refills the magazine**; with no cell carried, the reload is refused ("No cells."). **Same rule in both
worlds** — weapons behave the same for everyone; conduits are just stronger and more modified (stats, cybernetics,
bench builds), never on different weapon rules. So the war needs cells: the deploy kit (`Config.Range.Loadout`) grants
a few, shipments and the supply pool carry them, AI recruits draw them from their kit like any other item, and dead
soldiers drop theirs (everything drops). Tuning: cells per reload (`Config.Destruction.CellsPerReload`, default 1),
cells in the deploy kit.

### 4.5 Grab and throw (core Conduit combat)

- **Grab:** **G** (owner, 2026-10-26 17:30; F is block / parry), hold to keep holding, picks up the targeted grabbable
  within 8 studs. Grabbing takes 0.2 s and is interruptible by hits. G is today the second key for the special (the
  heavy on ranged weapons, `Presentation.Aim.SpecialKeys = { MMB, G }`); when grab ships the special stays on the
  middle mouse button only.
- **Weight classes:**

| Class | Examples | Hold | Movement | Throw |
|---|---|---|---|---|
| Light | Bottle, sign piece, brick | One hand, can still block | Normal | Fast, long |
| Medium | Streetlight head, car door, crate | Two hands, no blocking | −20% speed | Medium arc |
| Heavy | Slab, vending machine | Needs Strength threshold | −45% speed, no sprint | Short, crushing |

- **Throw:** release to throw toward the camera aim point. Charging the throw (hold) adds distance and damage, costs stamina, and shows a windup that opponents can read.
- **Interaction with existing combat:**
  - A thrown object is a hit with damage, posture damage and knockback. It uses the existing `Combat` hit path, so stun, guard and wall-aware knockback all apply.
  - It can be **blocked** (posture damage) or **dodged** with i-frames.
  - A well-timed **parry deflects it.** (Stretch goal: parry while empty-handed to **catch** it and throw it back.)
  - Thrown hits count toward the Flicker / Black Flash chain only if the throw itself was flicked.
- **Stats:** Strength raises throw damage and the Heavy threshold; Willpower lowers throw stamina cost.

### 4.6 Explosions (both worlds)

One shared server-side `Explosion` function, not Roblox's built-in `Explosion` instance:

1. **Characters:** damage falls off with distance and is blocked by cover (line-of-sight check from the blast centre). It applies through `Combat` so armor, posture and kill credit all work.
2. **World:** damages every `Destructible` / `Breachable` / war-world structure in radius, also with line-of-sight.
3. **Physics:** impulse to loose chunks, bodies and grabbables in radius.
4. **Terrain (war world only):** carve a crater.
5. **Client:** flash, shockwave, debris and camera shake, scaled by distance.

### 4.7 War world: destruction at scale

- **Structures** have 3–4 authored stages: Intact → Damaged → Ruined → Rubble. Each stage is its own model; a stage swap happens when its health threshold is crossed. Ruins keep partial cover, so destruction reshapes the fight instead of flattening it instantly.
- **Terrain craters:** carve the ground with each explosion (sized by charge) and line the crater with mud/scorched material. Overlapping craters across a long fight produce the torn-up battlefield look.
- **Artillery and explosives** are the main source. With no vehicles, infantry with charges and grenades plus called artillery are how strongpoints get cracked.
- **Bodies and wreckage:**
  - Bodies ragdoll, then freeze in place after settling (~4 s), so they stop costing physics. They stay in the world as cover and as part of the "piles of metal and men".
  - All gear stays lootable on the body (existing rule: everyone drops everything).
  - Each sector has a body cap. Past it, the oldest bodies are cleaned up first.
- **Sectors are the hill points.** The war is built (`server/War.lua`, design/gdd/war.md): the hill already moves
  between `Config.War.HillPoints` (six today) on capture or on a timer (`moveHill`). Each hill point and the ground
  around it is a sector, and "the hill leaves a sector" is `moveHill`. Structures, craters and bodies are tracked per
  sector from the start.
- **Sector reset (the "limitless" part):** the map is split into sectors. When the moving hill leaves a sector and no players have been in it for a set time, the sector rebuilds: terrain is restored from a snapshot taken at server start, structures return to Intact, and bodies and wreckage are cleared. Fiction: rebuild crews and pod-dropped fortifications. Fighting always moves onto ground that can be destroyed again.

### 4.8 Conduit world: hourly dematerialization

> The cycle has its own design note: `design/gdd/dematerialization.md` (owner, 17:37: the conduits believe the world
> is simulated; everything authored resets — terrain, POIs, all of it — and only player / enemy spawns, vendor
> encounters and loot vary). Destruction subscribes to `Cycle.Warning` / `Cycle.Dematerialize` / `Cycle.Rematerialized`.

- When the world dematerializes, every broken prop, breach point and leftover debris chunk returns to its intact state.
- **60 s warning:** broken things start flickering and players hear a rising hum, so no one is caught off guard.
- **Players inside a resealing breach:** a breach point won't rematerialize while a character overlaps it. It retries every few seconds once the space is clear.
- Grabbed items still in a player's hands dematerialize out of them at reset.
- Salvage already taken stays in inventories. Salvage remains nobody looted are cleared.

## 5. Formulas (initial tuning)

```
Explosion damage   = BaseDamage × (1 − (distance / Radius)^1.5)          -- 0 beyond Radius
Throw speed        = BaseSpeed[class] × (1 + 0.6 × charge) × (1 + 0.01 × Strength)
Throw damage       = BaseDamage[class] × (speed / BaseSpeed[class])^1.2
Throw stamina      = BaseStamina[class] × (1 + charge) × (1 − 0.005 × Willpower)
Heavy grab allowed = Strength ≥ HeavyStrengthThreshold
Crater radius      = Radius × CraterScale (war world only)
```

`charge` is 0–1 (how long the throw was held, capped at 0.8 s).

## 6. Networking and performance

This is where destruction systems on Roblox usually fail, so the rules are strict.

- **Server-authoritative gameplay:** prop health, breaches, structure stages, terrain craters, salvage and every grabbable chunk live on the server, so every player sees the same holes and the same loot.
- **Client-only cosmetics:** dust, sparks, glass shards, small non-grabbable chunks and shockwaves are spawned locally and never replicated.
- **Grab feel:** while held, the holder gets physics ownership of the object, so it follows their hand with no lag.
- **Throw validation:** on release, the server clamps velocity to what the formula allows for that player (stat and charge), checks the object was actually in their reach, and runs its own hit detection along the flight path. A client claiming a 900 studs/s throw is rejected. (See `roblox-security`.)
- **Budgets:**
  - Max loose (unanchored) gameplay chunks per region: 150. Past the cap, the oldest settled chunks freeze in place, then fade.
  - Settled chunks freeze after 3 s at rest, unless they are held or within a recent explosion radius.
  - Cosmetic debris per client: 300, oldest removed first.
  - War-world bodies per sector: 60.
- **Fractures are authored, not computed.** Pre-broken models are swapped in. Runtime geometry cutting is too slow for gameplay; the only runtime cut is terrain carving.

## 7. Edge cases

| Case | Handling |
|---|---|
| Player standing in a breach when it would reseal | Waits until the space is clear (§4.8) |
| Explosion through a thin wall | Line-of-sight check stops character damage; the wall itself takes damage |
| Throwing a chunk at point-blank range | Minimum flight distance before it can hit, to stop "spam-drop" damage |
| Two players grab the same chunk on the same frame | Server picks the first request; the second gets nothing |
| Player dies while holding something | It drops with an impulse matching their last movement |
| Combat-logging while holding | Counts as death (existing rule); object drops |
| Breaching charge on a Sealed point | Charge still explodes; point takes no damage; a hint plays once |
| Body pile blocking an objective | Explosions push bodies; past the sector cap, oldest are cleared |
| Exploiter spamming break requests | Rate-limited remote; the server checks weapon reach / explosion origin, never trusts a "this broke" message from a client |

## 8. Dependencies

- **Combat:** hit path, damage types, posture, parry, i-frames, knockback, kill credit.
- **Loot / Items / Inventory:** salvage remains, new materials, recipes, improvised weapons.
- **Events:** breach noise, warnings, dematerialization timer.
- **Enemies / barks (`NPCs`, `client/WorldFX.lua`):** breach noise is a "hear" tell — NPCs within range turn and bark,
  the same unannounced-until-seen-or-heard rule as raids (design/gdd/raids.md §1).
- **Raids:** a breached interior is a natural objective — a `breach` step kind (open this point) and interiors as
  `reach` / loot targets; reinforced points make breaching charges worth ordering off the black market.
- **Bench / Supply:** Sign Plating and salvaged parts feed `Bench`; Glass / SheetMetal / Pipe / Battery / Powder are
  `Material` (supply value 1) and can be donated to the war like any other material.
- **Stats / Gear:** Strength and Willpower scaling.
- **Dematerialization cycle** (Conduit world): reset trigger. Designed in `design/gdd/dematerialization.md`; not built.
- **War world** (built: `server/War.lua`): the moving hill and its points are the sectors (§4.7); artillery calls are new.
- **Level design:** tagging props and authoring breach points and fracture/stage models.

## 9. Gore and content maturity

"As far as we can go" on Roblox means the **Restricted** content label. Restricted allows graphic, realistic violence and heavy realistic blood (dismemberment, pools of blood, up-close spatter). It comes with real trade-offs:

- Only **age-verified players 18+** can play a Restricted experience. That removes a very large share of the Roblox audience.
- **The label can't be changed back** once applied.
- Restricted experiences are **blocked in some regions** (for example Korea, Saudi Arabia and Türkiye).
- The **creator** must verify their own account as 18+ to fill in the questionnaire.
- Even Restricted still bans extreme/realistic extreme gore, torture, and glorifying war crimes. For the war world, that rules out things like executing surrendered soldiers as a mechanic.

The **Moderate** label allows realistic but non-graphic violence and death, with light, distant blood. It stays open to a much wider audience.

**Implementation:** a single `Config.GoreLevel` setting (`Moderate` | `Restricted`) controls blood decals, wound effects, dismemberment, and body persistence detail. Build both, choose the label before launch.

## 10. Tuning knobs (`Config.Destruction`)

- Damage per type per prop/breach tier; `Resist` tables
- `GrabRange`, weight class speeds/damage/stamina, `HeavyStrengthThreshold`, max charge time
- Explosion `Radius`, `BaseDamage`, falloff exponent, `CraterScale`
- Loose chunk cap, settle time, cosmetic debris cap, body cap per sector
- Dematerialization warning length
- `GrabKey` (G), `CellsPerReload` (1)
- Sector rebuild delay
- `GoreLevel`

## 11. Acceptance criteria

1. Hitting a streetlight with a sledge breaks it; every player sees the same break; salvage remains appear and roll Battery/Glass/Pipe.
2. A pipe chunk from that streetlight can be grabbed, thrown, and hits a dummy for damage and knockback through the normal combat path.
3. A parry deflects a thrown chunk; an i-frame dodge avoids it.
4. A Reinforced breach point ignores melee and opens to a Breaching Charge; the opening matches the authored hole model; nearby NPCs react to the noise.
5. At dematerialization, all broken props and breaches in the Conduit world return to intact, with a 60 s warning, and no player gets trapped inside a wall.
6. A client claiming an over-limit throw velocity is rejected and logged.
7. In a 20-player stress test with constant explosions, server frame rate stays above 50 and loose chunks never exceed the cap.
8. War world (once built): a structure goes Intact → Damaged → Ruined → Rubble under sustained explosives; craters accumulate; the sector fully rebuilds after the hill leaves.

## 12. Build order (stories)

1. Damage types on existing hits + `Destructible` prop framework (health, swap to fractured model, salvage remains).
2. New materials and recipes; Arc Cells as the arc weapons' reserve in both worlds (§4.4a).
3. Grab and throw (Light class first), with server validation.
4. Parry deflect + Medium/Heavy classes + improvised melee from chunks.
5. Shared `Explosion` function + Pipe Grenade + Breaching Charge.
6. `Breachable` points with tiers and noise events.
7. The cycle (`design/gdd/dematerialization.md`), then destruction's reset hook.
8. Performance budgets and stress test.
9. War world: structure stages, terrain craters, body persistence, sector rebuild (unblocked: the war exists; sectors = hill points).
10. `GoreLevel` content pass.

## 13. Reconciled with the current build (2026-10-26, 17:30)

The first draft was written against the pre-Phase-3 game. Changes, all compatible with the owner's decisions in §3:

| Was | Now | Why |
|---|---|---|
| Grab on `F` | Grab on **G** (owner's pick) | F is block / parry; G leaves the special on MMB only |
| "Arc pistol moves from unlimited to cell-fed" | Arc Cells are the arc weapons' **reserve**: a reload costs a cell | Arc weapons already have magazines and reloads (gunplay layer) |
| Damage type replaces combat's type | New `Break` field; combat's `Type` stays the resist class; `Explosive` resist added | Armour resists (`Physical` / `Arc`) keep working unchanged |
| "War world (not yet built)" | Built; sectors = `Config.War.HillPoints`, "hill leaves" = `moveHill` | The Wardogs war shipped in Phase 3 |
| Dematerialization assumed | Flagged as unbuilt; needs a design note before story 7 | Nothing in code or briefs defines the hourly cycle yet |
| — | Breach noise drives NPC barks; `breach` raid step; materials feed Bench / Supply | Ties into what Phase 3 built |
| `docs/systems/destruction-and-salvage.md` | `design/gdd/destruction.md` + epic + systems-index rows 52–53 | The project's GDD / epic layout |

**Settled by the owner (17:37):** Arc Cells in both worlds — all weapons are consistent (§4.4a); the cycle resets
everything authored, only spawns, vendor encounters and loot vary (`design/gdd/dematerialization.md`).
