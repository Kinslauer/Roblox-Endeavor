# Architecture: CONDUIT (Endeavor, Universe 1)

---
**Status**: Reverse-Documented
**Source**: `default.project.json`, `src/shared/`, `src/server/`, `src/client/`, `tools/smoke/`
**Date**: 2026-10-25
**Decision Makers**: inferred from code (technical-director / lead-programmer reverse-doc pass)
**Implementation Status**: Deployed (friend-testing build, `Config.Dev.Enabled = true`)
---

> **Reverse-Documentation Notice**
> This document was written after the implementation existed. It describes what the code does
> today; rationale is reconstructed from code comments, `README.md`, `docs/DESIGN.md` and
> `design/game-brief.md`. Decisions are recorded as ADR-0001..0004 in this folder.

## Engine API Surface

| Field | Value |
|-------|-------|
| **Engine** | Roblox (Luau), synced with Rojo 7 |
| **APIs Depended On** | `RemoteEvent`, `BindableEvent`, Instance attributes (`SetAttribute`/`GetAttributeChangedSignal`), `Humanoid`, `workspace:GetPartBoundsInRadius`, `workspace:Raycast`, `CollectionService` tags, `ProximityPrompt`, `DataStoreService`, `RunService.Heartbeat`, `task.delay/spawn/wait`, `TweenService`, `Highlight`, `ColorCorrectionEffect`, `Debris` |
| **Third-party** | ProfileService (vendored at `src/server/ProfileService.lua`, Apache-2.0) |
| **Unverified Assumptions** | None in the server logic; the client reads `Players.CharacterAutoLoads = false` behaviour implicitly via `Lifecycle.Spawn` |
| **Engine Upgrade Risk** | LOW. Only stable, long-standing Roblox APIs are used. |

## Overview

CONDUIT is a permadeath, always-on-PvP Roblox action game. Every player begins alone in a private
"prologue" plot running a data-driven tutorial; when every player is ready (or the cap elapses)
the server "emerges" everyone into a shared city. Combat is server-authoritative, frame-data
based (windup / active / end), with posture, parry, i-frame dodge, feint, and a timing-based
"flicker" chain that culminates in a Black Flash. The code base is one Rojo project; this
document maps its layers, boot order, network contract, internal event bus, persistence, and
the headless smoke-test harness.

## Project Layout and Rojo Mapping

`default.project.json` (project name `Conduit`) syncs three folders into the DataModel and sets
`Workspace.StreamingEnabled = false`:

| Source | DataModel path | Role |
|---|---|---|
| `src/shared/` | `ReplicatedStorage.Shared` | Pure data + the remote registry. Readable by server and client. |
| `src/server/` | `ServerScriptService.Server` | Authoritative systems (ModuleScripts) + `Main.server.lua` (Script). |
| `src/client/` | `StarterPlayer.StarterPlayerScripts.Client` | `Main.client.lua` (LocalScript): input, HUD, placeholder VFX. |

`vendor/` is not referenced by the project file and is never loaded.

## Layers

### 1. Shared data layer (`src/shared/`)

| Module | Contents |
|---|---|
| `Config.lua` | All tuning: `Config.Dev`, `Tutorial`, prologue timers, `Stats`, `Flicker`, `Combat`, loot/respawn constants. The file header states that every designer-tweakable number lives here. |
| `Weapons.lua` | `Weapons.Defs[id]` — weapon = moveset. Each attack spec: `Damage, Posture, Windup, Active, End, Range, Arc, Stamina` plus optional `Knockback, Stun, Hyperarmor, Type, Ranged`. Per weapon: `Attacks[]`, `Heavy`, `ComboReset`, `ComboCooldown`, `ChargeBonus`. |
| `Armor.lua`, `Cybernetics.lua` | Wearable pieces: `Slot`, `Stats`, `Resist`, `Tags`, `Weight`, bonus fields (`FlickerRate`, `FlashBonus`, `ParryBonus`, ...). |
| `Skills.lua` | `Skills.Defs`, `Skills.Order`, `SlotCount`, `Skills.Unlocked(def, stats, tags)`, `Skills.Power(...)`. Used on both sides (server gates, client displays "(locked)"). |
| `Items.lua` | `Items.Defs`, `Items.Recipes`, loot tables + `Items.Roll`. |
| `Remotes.lua` | Creates the `ReplicatedStorage.Remotes` folder of `RemoteEvent`s on the server; the client `WaitForChild`s them. Same table API on both sides. |

### 2. Server systems layer (`src/server/`)

Every system is a ModuleScript exposing an `Init()` plus a small API. Dependencies are plain
`require`s; cross-system notification goes through `BindableEvent`s (see "Event bus").

| Module | Owns | Listens to remotes |
|---|---|---|
| `PlayerData` | ProfileService profiles, template, `Load/Get/Reset/Release`. | — |
| `Gear` | Derived combat numbers from stats + armor + cyber (`Gear.Get/OfChar/Default`), equip/unequip, skill slots, `LoadoutChanged` push. | `Unequip`, `SetSkill` |
| `Stats` | XP/level/points, applies MaxHealth/Stamina/WalkSpeed/Posture/Charge attributes, `StatsChanged` push. | `Allocate` |
| `Inventory` | Item counts, use/equip/craft, `InventoryChanged` push. | `UseItem`, `EquipItem`, `Craft` |
| `Combat` | Per-character combat state (weak-keyed table), swings, hit detection, damage, posture, parry, dodge, feint, flicker/Black Flash, stamina/posture regen tick. | `Attack`, `Heavy`, `Feint`, `Flicker`, `Block`, `Dodge` |
| `SkillRunner` | Skill execution (Burst/Strike/Dash/Buff/Recover/Flicker kinds), cooldowns. | `UseSkill` |
| `WorldPhase` | Prologue plots, ready-set, Emergence, spawn CFrames, `workspace.Phase` attribute. | — |
| `Tutorial` | 15 data-driven steps in the private plot, training dummy, `Tutorial` push. | `TutorialSkip` |
| `Lifecycle` | Join/spawn/death/leave; composition of the above per player. | — |
| `Permadeath` | Drops remains, credits killer, legacy record, `Died` push, profile wipe, combat-log punishment. | — |
| `Loot` | `ProximityPrompt` hold-to-loot crates/remains. | — |
| `NPCs` | Procedural rigs, simple chase/attack loop via `Combat.Damage`. | — |
| `Quests` | Rotating quests, `QuestChanged` push. | — |
| `Events` | Weighted event director (supply drop, raider ambush). | — |
| `Arena` | Dev-only test arena (armory, dummies); gated by `Config.Dev.Enabled`. | — |

### 3. Client presentation layer (`src/client/Main.client.lua`)

A single LocalScript that (a) maps input to remote intents, (b) builds the HUD procedurally,
(c) binds bars to replicated character attributes (`Stamina/MaxStamina`, `Posture/MaxPosture`,
`Charge/MaxCharge`), (d) draws the flicker aura from the `Flicker` / `Zone` attributes every
Heartbeat, and (e) renders placeholder VFX for `CombatEvent`. The only state it mutates is its
own character's `AssemblyLinearVelocity` for `DodgeMove` / `Knockback` (the client owns its
character's physics). See ADR-0004 for where this layer is going.

## Boot Order (`src/server/Main.server.lua`)

```
pcall(Arena.Init)      -- dev arena; isolated so a bug here cannot stop boot; must precede WorldPhase (CitySpawn pads)
WorldPhase.Init()      -- sets workspace.Phase, lays a placeholder slab if no CitySpawn tags exist
Gear.Init()            -- Unequip / SetSkill remotes
Stats.Init()           -- Allocate remote; Gear.Changed -> Apply + Push
Inventory.Init()       -- UseItem / EquipItem / Craft remotes
Quests.Init()          -- Inventory.Added / Crafted -> progress
Combat.Init()          -- six combat remotes + 10 Hz regen tick
SkillRunner.Init()     -- UseSkill remote
Events.Init()          -- director loop (only acts when WorldPhase.IsOpen())
Tutorial.Init()        -- TutorialSkip remote; Combat.Resolved / Combat.Used / Inventory.Crafted listeners
Lifecycle.Init()       -- CharacterAutoLoads = false; PlayerAdded / PlayerRemoving; replays existing players
```

`Lifecycle.Init` is last on purpose: it is the only module that reacts to `PlayerAdded`, so every
remote listener and event subscription exists before the first profile loads. Requiring
`Remotes` from any server module creates the remote folder as a side effect of the first require.

Per-player flow (`Lifecycle`): `PlayerData.Load` (yields; kicks on failure) -> `WorldPhase.StartTimer`
-> `Lifecycle.Spawn`: `LoadCharacter`, `PivotTo(WorldPhase.GetSpawnCFrame)`, `Gear.Recompute`,
`Stats.Apply/Push`, `Inventory.Push`, then either `Quests.Assign` (world open) or `Tutorial.Start`
(prologue), `Quests.Push`, and `Humanoid.Died:Once` -> `Permadeath.Handle` (open world only) ->
respawn after `Config.RespawnDelay`.

## Remote Contract

All remotes are `RemoteEvent`s created by `src/shared/Remotes.lua`. Payloads below are exactly
what the code passes.

### Client -> Server (intent only; server validates and decides)

| Remote | Args sent by client | Server handler | Validation present |
|---|---|---|---|
| `Attack` | none | `Combat.Attack` | `CanAct`, stamina |
| `Heavy` | none | `Combat.Heavy` | `CanAct`, `HeavyCooldown`, stamina |
| `Feint` | none | `Combat.Feint` | must be inside windup, not stunned |
| `Flicker` | none | `Combat.Flicker` | alive, `F.Cooldown`, charge cost |
| `Block` | `down: boolean` | `Combat.SetBlock` | `type(down) == "boolean"` |
| `Dodge` | `direction: Vector3` | `Combat.Dodge` | `typeof == "Vector3"`, flattened, magnitude, stamina, cooldown |
| `UseSkill` | `slot: number` (1..3) | `SkillRunner.Use` | integer, slot occupied, unlocked, cooldown, costs |
| `SetSkill` | `slot: number, skillId: string|nil` | `Gear.SetSkill` | integer range, def exists, unlocked |
| `Allocate` | `statName: string` | `Stats.Allocate` | string, stat exists, points, cap |
| `UseItem` | `itemId: string` | `Inventory.Use` | string, Consumable, owned |
| `EquipItem` | `itemId: string` | `Inventory.Equip` | string, Weapon/Armor/Cybernetic, owned |
| `Unequip` | `what: "Weapon" | slotName` | `Gear.Unequip` | string, known slot |
| `Craft` | `recipeId: string` | `Inventory.Craft` | string, recipe exists, inputs owned |
| `TutorialSkip` | none | `Tutorial` | — |

### Server -> Client

| Remote | Scope | Payload as fired |
|---|---|---|
| `CombatEvent` | `FireAllClients(kind, char, extra)` via `Combat.FX`; `FireClient` for private kinds | See table below |
| `StatsChanged` | FireClient | `{ Stats, FreePoints, Level, Xp, XpNeeded, Max }` |
| `InventoryChanged` | FireClient | `(inventory, equipped, armor, cyber)` — four positional tables/strings |
| `LoadoutChanged` | FireClient | `{ Stats, Tags, Resist, MaxPosture, WeightScore, FlickerRate, FlashBonus, Weapon, Armor, Cyber, Slots }` |
| `QuestChanged` | FireClient | `(title, progress, count)` or `(nil)` to clear |
| `Announce` | FireClient / FireAllClients | `(text, kind)` with kind in `Emergence | Event | Kill | Info` |
| `PhaseChanged` | FireAllClients | `"Emerging"` then `"Open"` |
| `Died` | FireClient | `{ Survived, Kills, Level, Killer }` |
| `Tutorial` | FireClient | `(index, total, title, text)` or `(nil)` to hide |

### `CombatEvent` kinds

| kind | Scope | `a` | `b` | Client handling today |
|---|---|---|---|---|
| `Swing` | all | attacker char | combo index, `"Heavy"`, or skill label | **none** (TODO comment) |
| `Hit`, `Block`, `Parry`, `GuardBreak`, `Dodge`, `Feint`, `Buff`, `Burst` | all | char | buff kind / radius | 0.15 s `Highlight` flash |
| `Flick` | all | char (press) or victim (chain link) | chain level on link | `Highlight` flash |
| `BlackFlash` | all | attacker char | victim char | expanding neon sphere, color-correction + banner for participants |
| `Bolt` | all | shooter char | world end position | neon beam, 0.1 s |
| `Dodged` | all | victim char | — | **not handled** |
| `DodgeMove` | victim player only | velocity `Vector3` | — | sets own root `AssemblyLinearVelocity` |
| `Knockback` | victim player only | push `Vector3` | — | sets own root `AssemblyLinearVelocity` |
| `SkillCD` | caster only | skillId | cooldown seconds | hotbar timer |

### Replicated attributes (implicit server -> client channel)

Character: `Stamina, MaxStamina, Posture, MaxPosture, Charge, MaxCharge, Blocking, Flicker, Zone`
(plus server-only bookkeeping `LastAttackerName, LastAttackerUserId, LastHitTime`). Player:
`LastCombat`. Workspace: `Phase`. Loot parts: `Label`. The HUD bars and the flicker aura read
attributes, not remotes.

## Server Event Bus (BindableEvents)

| Event | Fired by | Signature | Subscribers |
|---|---|---|---|
| `Combat.Resolved` | `Combat.Damage` (any result other than `"none"`) | `(attackerChar, victimChar, result)` where result is `hit|blocked|parried|dodged|guardbreak` | `Tutorial` (hit/dodge/parry/block step counters) |
| `Combat.Used` | `Combat.Heavy`, `Combat.Feint`, `blackFlash`, `SkillRunner.Use` | `(abilityName, player)` | `Tutorial` (heavy / flash / feint / skill steps) |
| `Gear.Changed` | `Gear.Recompute` | `(player)` | `Stats` (re-apply attributes, push `StatsChanged`) |
| `Inventory.Added` | `Inventory.Add` | `(player, itemId, count)` | `Quests` (collect progress) |
| `Inventory.Crafted` | `Inventory.Craft` | `(player, itemId, count)` | `Quests` (craft progress), `Tutorial` (craft step) |
| `WorldPhase.Changed` | `WorldPhase.Emerge` | `(phase)` | none yet (hook point) |

Direct calls that are not events but cross systems: `NPCs`/`Permadeath` -> `Combat.GetKiller`,
`Stats.AddXp`, `Quests.Progress`, `Loot.Spawn`; `Inventory.Remove` -> `Gear.Validate`;
`Tutorial.finish` -> `WorldPhase.MarkReady`.

## Data Flow: One Light Attack

1. **Client** `UserInputService.InputBegan` with `MouseButton1`, not `processed` -> `Remotes.Attack:FireServer()` (no args).
2. **Server** `Combat.Attack(player)`: resolves weapon via `PlayerData.Get(player).Equipped` -> `Weapons.Defs` (falls back to `Fists`); checks `Combat.CanAct` (alive, not stunned, `busyUntil - 0.08` buffer); picks the combo index (`comboWeapon == weapon and now <= comboExpires` continues the chain, else 1); `SpendStamina(spec.Stamina * Gear.StaminaCostMult)`; drops block (`Blocking=false` attribute).
3. `Combat.Swing(char, spec, { chargeBonus, label = combo })`: sets `busyUntil = now + End`, `windupUntil = now + Windup`, optional swing hyperarmor; captures `token`; fires **`CombatEvent("Swing", char, combo)` to all clients** (this is the telegraph hook). Then `task.delay(spec.Windup, ...)`.
4. After the windup, if `token` unchanged (no stun / dodge / feint) and alive: loops `pulse` every `Heartbeat` until `now >= start + Active`. `pulse` scales `Damage`/`Posture` by `Gear.OfChar(char).DamageMult`/`PostureDamageMult`, adds Overload arc bonus, then `GetPartBoundsInRadius(root, Range)` filtered to Models with a Humanoid and `look:Dot(flat) >= Arc` (or within 3.5 studs). Each model is struck at most once per swing (`seen`).
5. `strike(model)`: first strike of the swing judges the flick (`judgeFlick`: press within `F.Window * FlickerRate * ZoneWindowMult`); multiplies damage by `F.DamageMult[level]` or `F.BlackFlashMult + FlashBonus`; calls `Combat.Damage`.
6. `applyDamage`: `"none"` if dead/self/PvP-before-Open; `"dodged"` if victim in i-frames (fires `CombatEvent("Dodged")`); if blocking and facing and not unblockable: parry inside `Gear.ParryWindow` (`Stun(attacker, ParryStun)`, `Parry` FX, return), else posture add -> `GuardBreak` or `Block`; applies `Taken` buff and `Resist[Type]` capped at `MaxResist`; `Humanoid:TakeDamage`; `tag()` sets kill-credit attributes; `Stun(victim)` + `knockback` unless blocked or hyperarmored (`Knockback` to a player goes via private `CombatEvent("Knockback", push)`); `Hit` FX on a clean hit.
7. `Combat.Damage` fires `Combat.Resolved(attacker, victim, result)`; `strike` then resolves the flick chain (set `Flicker` attribute + `Flick` FX, or `blackFlash` -> `BlackFlash` FX + `Zone` attribute + `Combat.Used("BlackFlash")`), and adds charge.
8. **All clients** receive `CombatEvent("Swing")` at step 3 and `("Hit"|"Block"|...)` at step 6; the victim additionally receives `Knockback`. HUD bars update through attribute-changed signals, not through these events.

## Persistence

| Store | API | Key | Contents |
|---|---|---|---|
| `ConduitCharacter_v2` | ProfileService `GetProfileStore` (`src/server/PlayerData.lua`) | `"Char_" .. UserId` | One character: `Created, Stats{}, FreePoints, Level, Xp, Kills, BornAt, Awakened, TutorialDone, Equipped, Armor{}, Cyber{}, SkillSlots{}, Inventory{}` |
| `ConduitLegacy_v1` | `DataStoreService:GetDataStore` (`src/server/Permadeath.lua`) | per `UserId` | Legacy record of dead characters (`recordLegacy`) |

Rules embodied in code: profiles load with `"ForceLoad"` and `ListenToRelease` kicks the player
if another session steals the lock; `Reconcile()` re-adds template keys, so removable things
(inventory, slots) have no template defaults and starting gear is granted once by `newCharacter`;
permadeath is `PlayerData.Reset` -> `wipe` in place (same profile, new character); combat-logging
wipes before `PlayerData.Release` saves. The game brief forbids renaming stores (would wipe saves).

## Smoke-Test Harness (`tools/smoke/`)

`gen.py` concatenates `mock_prelude.lua` (a tiny Roblox mock: instances, services, attributes,
`task`, Heartbeat stepping, a `FireLog` of every `FireClient`/`FireAllClients`), the real
`src/shared`, `src/server` and `src/client` sources as in-memory trees (ProfileService swapped for
`ps_stub.lua`), and `scenario.lua`, then prints a single Luau file:

```
python3 tools/smoke/gen.py > /tmp/harness.lua && luau /tmp/harness.lua
```

`scenario.lua` boots `Main.server.lua`, fakes a player, and drives every remote through the
whole loop: tutorial steps 1-14 with real combat against the dummy (including landing a Black
Flash), Emergence, a second player, a PvP hit, permadeath remains and respawn, then asserts
`#M.errors == 0`. It catches nil indexing, missing functions, bad requires and logic regressions;
it is not Roblox (no physics, no replication, no real DataStore).

## Known Gaps

- **No rate limiting on remotes.** Every `OnServerEvent` handler runs its own gameplay checks
  (cooldowns, stamina) but nothing throttles call volume; `Attack`/`Flicker` spam costs the
  server a handler call each. Listed in `docs/DESIGN.md` roadmap and the brief's "Fair arrival".
- **Client hardcodes the Black Flash multiplier.** `Main.client.lua` renders
  `("Black Flash x%.1f"):format(2.5 + loadout.FlashBonus)` instead of
  `Config.Flicker.BlackFlashMult + loadout.FlashBonus`. Violates ADR-0002 / TR-002.
- **`CombatEvent "Dodged"` is not handled by the client.** The server fires it on an i-frame
  evade; the client's `FLASH` table has no entry, so the player gets no feedback (the brief's
  "dodge feedback bug").
- **`CombatEvent "Swing"` is unused on the client** (TODO comment). There is no telegraph, so
  parry/flick windows are currently unreadable. ADR-0004 addresses this.
- **`StreamingEnabled = false`** is pinned in `default.project.json`. Fine for the dev arena;
  must be revisited before a full city exists (`roblox-performance` guidance).
- **No animation or audio pipeline.** No `Animator`/`AnimationTrack` usage, no `Sound`
  instances, no asset-ID registry anywhere in `src/`. All VFX are code-made `Highlight`/`Part`
  placeholders inside `Main.client.lua`.
- **Presentation and input share one file.** `Main.client.lua` (438 lines) holds HUD, panels,
  input mapping and VFX. ADR-0004 moves presentation into modules under `src/client/`.
- **No automated tests other than the smoke scenario**; no TestEZ, no CI.
- **Type validation is partial.** Handlers check `type()`/`typeof()` for `Block`, `Dodge`,
  `UseSkill`, `SetSkill`, `Allocate`, `UseItem`, `EquipItem`, `Unequip`, `Craft`; `TutorialSkip`
  and the arg-less combat remotes have nothing to validate. No shared validator module exists.

## Related

- ADR-0001 Server-authoritative combat (Accepted)
- ADR-0002 Config as single source of tuning (Accepted)
- ADR-0003 Rojo module layout (Accepted)
- ADR-0004 Presentation layer and asset slots (Proposed, Combat Feel epic)
- `tr-registry.yaml` — technical requirements registry
- `design/game-brief.md`, `docs/DESIGN.md`
