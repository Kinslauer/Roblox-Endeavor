# ADR-0003: Rojo Module Layout

## Status

Accepted

> Reverse-documented 2026-10-25: `default.project.json`, the `src/shared|server|client` split,
> `Init()`-style ModuleScripts and `Main.server.lua` as composition root already exist.

## Date

2026-10-25 (decision predates the record; inferred from code)

## Last Verified

2026-10-25

## Decision Makers

Project owner (solo developer); recorded by technical-director during reverse-documentation.

## Summary

The game needs a layout that Rojo can sync, that keeps server-only code off the client, and that
lets one script control boot order. The project uses three folders — `src/shared` (data +
remote registry), `src/server` (authoritative ModuleScript systems each exposing `Init()`), and
`src/client` (presentation) — with `src/server/Main.server.lua` as the single composition root
that requires and initialises every system in a fixed order.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Roblox (Luau), Rojo 7. `default.project.json` maps `src/shared` -> `ReplicatedStorage.Shared`, `src/server` -> `ServerScriptService.Server`, `src/client` -> `StarterPlayer.StarterPlayerScripts.Client`; `Workspace.StreamingEnabled = false`. File suffixes decide class: `.server.lua` -> Script, `.client.lua` -> LocalScript, `.lua` -> ModuleScript. |
| **Domain** | Core |
| **Layer** | Foundation |
| **Knowledge Risk** | LOW |
| **References Consulted** | `default.project.json`, `src/server/Main.server.lua`, `src/shared/Remotes.lua`, `tools/smoke/gen.py`; `roblox-architecture` skill guidance |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None — foundational |
| **Enables** | ADR-0001 (server folder is where authority lives), ADR-0002 (shared folder makes one Config readable on both sides), ADR-0004 (client folder gains presentation modules) |
| **Blocks** | None |
| **Ordering Note** | Any new system is a ModuleScript in `src/server` with `Init()` and a line in `Main.server.lua`. |

## Context

### Problem Statement
A Roblox game needs (a) code that is only ever on the server, (b) data both sides can read, and
(c) a deterministic start-up so remote listeners exist before the first player loads. Studio's
default of many loose Scripts gives none of these.

### Current State
Implemented:
- `src/shared/` — pure data modules plus `Remotes.lua`, which creates the `RemoteEvent` folder on
  the server and `WaitForChild`s it on the client, returning the same name-keyed table on both.
- `src/server/` — 15 ModuleScripts (`Arena, Combat, Events, Gear, Inventory, Lifecycle, Loot,
  NPCs, Permadeath, PlayerData, Quests, SkillRunner, Stats, Tutorial, WorldPhase`) plus the
  vendored `ProfileService.lua` and the one Script `Main.server.lua`.
- `src/client/` — `Main.client.lua`, the only LocalScript.
- Modules `require` siblings via `script.Parent.X` and shared modules via
  `ReplicatedStorage.Shared.X`. There is no `_G`, no `shared`, no service locator.
- `Main.server.lua` requires everything up front and calls `Init()` in order
  (`Arena` in a `pcall`, then `WorldPhase, Gear, Stats, Inventory, Quests, Combat, SkillRunner,
  Events, Tutorial, Lifecycle`). Comments explain the two ordering constraints: Arena before
  WorldPhase (CitySpawn pads), Lifecycle last (it is the only `PlayerAdded` subscriber).
- The smoke harness (`tools/smoke/gen.py`) rebuilds the same three trees from the folder names,
  so the layout is also the test contract.

### Constraints
- Rojo cannot sync into `vendor/`; the reference combat implementation stays unsynced.
- `StarterPlayerScripts` clones to each player; client code must be re-entrant per join.
- Studio Play-Solo runs server and client in one process; `Remotes.lua` branches on
  `RunService:IsServer()`.

### Requirements
- No server logic is reachable from the client bundle.
- Boot order is explicit and reviewable in one file.
- Adding a system touches two files: the new module and `Main.server.lua`.

## Decision

1. **Three roots, mapped once in `default.project.json`.** Shared = data and remote registry;
   server = authoritative systems; client = presentation and input.
2. **Every server system is a ModuleScript returning a table with `Init()`.** `require` has no
   side effects beyond creating `BindableEvent` fields and reading data (exception:
   `Remotes.lua` creates instances on first require, deliberately, so any order works).
3. **`Main.server.lua` is the composition root.** It is the only Script; it decides order and
   isolates optional subsystems (`pcall(Arena.Init)`).
4. **Cross-system communication is `require` for calls and `BindableEvent` for notifications**
   (`Combat.Resolved`, `Combat.Used`, `Gear.Changed`, `Inventory.Added/Crafted`,
   `WorldPhase.Changed`). No global state.
5. **Module naming is the system name** (`Combat`, not `CombatService`); remotes are named for
   the intent (`Attack`) or the fact (`StatsChanged`).

### Architecture Diagram
```
default.project.json
 ├─ ReplicatedStorage.Shared   <- src/shared/   Config Weapons Armor Cybernetics Skills Items Remotes
 ├─ ServerScriptService.Server <- src/server/   Main.server.lua + 15 ModuleScripts + ProfileService
 └─ StarterPlayerScripts.Client<- src/client/   Main.client.lua

Main.server.lua ──require──► {Arena, WorldPhase, Gear, Stats, Inventory, Quests, Combat,
                               SkillRunner, Events, Tutorial, Lifecycle}.Init()  (in that order)
```

### Key Interfaces
- `module.Init(): ()` — connects remotes/events; idempotency not required (called once).
- `module.<Event> : BindableEvent` — declared at module top with a signature comment.
- `Remotes[name] : RemoteEvent` — identical table on both sides.

### Implementation Guidelines
- A new server system **must** live in `src/server/<Name>.lua`, export `Init()`, and be added to
  `Main.server.lua` after the systems it depends on and before `Lifecycle`.
- Modules **must not** use `_G`, `shared`, or `game.<Service>:WaitForChild` for sibling code;
  use `script.Parent.<Name>` / `ReplicatedStorage.Shared.<Name>`.
- Code that must be unreachable by clients **must** live in `src/server`; data a client needs
  **must** live in `src/shared`.
- New remotes **must** be added to the `NAMES` list in `Remotes.lua` (one place) and to the
  remote contract table in `architecture.md`.
- Client code **should** be split into ModuleScripts under `src/client/` with one LocalScript
  requiring them (ADR-0004 makes this a rule for presentation).

## Alternatives Considered

### Alternative 1: Studio-native scripts (no Rojo)
- **Description**: Scripts authored directly in Studio's Explorer.
- **Pros**: Zero tooling.
- **Cons**: No git diffs, no headless testing, no vendoring of ProfileService as a file.
- **Estimated Effort**: Lower initially.
- **Rejection Reason**: The smoke harness and version control depend on files on disk.

### Alternative 2: Framework (Knit / Flamework) with services and controllers
- **Description**: Service registry, automatic `KnitInit/KnitStart` lifecycle, generated remotes.
- **Pros**: Conventions and DI for free.
- **Cons**: Extra dependency and build step; hides boot order; the smoke mock would need to
  emulate the framework.
- **Estimated Effort**: Moderate.
- **Rejection Reason**: An 11-line composition root does the job and is testable headlessly.

## Consequences

### Positive
- Boot order and failure isolation are visible in one 30-line file.
- `gen.py` can reconstruct the DataModel from folder names alone.
- Server-only code (ProfileService, Permadeath, Combat state) never replicates.

### Negative
- `Main.server.lua` must be edited for every new system (acceptable; it is the point).
- `Remotes.lua` creating instances on require is an implicit side effect new contributors
  must know about.
- The client side is a single file today; the layout permits modules but nothing enforces it.

### Neutral
- Luau strict typing is not enabled; module tables are untyped.

## Risks
- **Init order regressions** — a new module subscribing to `PlayerAdded` before `Lifecycle`
  would race profile load. Mitigation: guideline above; `Lifecycle` stays last.
- **Circular requires** — `Combat` requires `Gear`, `PlayerData`, `WorldPhase`; `Lifecycle`
  requires almost everything. Mitigation: keep leaf modules (`PlayerData`, `Gear`) free of
  requires on higher modules; use BindableEvents for upward notification.

## GDD Requirements Addressed

Foundational — no GDD requirement. Enables: combat.md, flicker.md, progression.md,
world-phase.md, tutorial.md, permadeath.md, inventory.md, quests.md, events.md (every system
GDD maps to one `src/server/<System>.lua` module).

## Performance Implications
- **CPU / Memory**: negligible. **Load Time**: all modules required eagerly at boot (fast).
- **Network**: `src/shared` replicates once per client.

## Migration Plan
Already in place. **Rollback plan**: not applicable.

## Validation Criteria
- `rojo build` produces a place with exactly the three mapped folders.
- `python3 tools/smoke/gen.py | luau -` boots `Main` and prints `PASS  no script errors`.

## Related
- ADR-0001, ADR-0002, ADR-0004
- `docs/architecture/architecture.md` §Project Layout, §Boot Order
- `default.project.json`, `src/server/Main.server.lua`, `src/shared/Remotes.lua`
