# ADR-0002: Config as the Single Source of Tuning

## Status

Accepted

> Reverse-documented 2026-10-25: `src/shared/Config.lua` and the shared data modules already
> embody this decision. One known violation exists on the client (see Consequences).

## Date

2026-10-25 (decision predates the record; inferred from code)

## Last Verified

2026-10-25

## Decision Makers

Project owner (solo developer); recorded by technical-director during reverse-documentation.

## Summary

Combat, progression and world-phase tuning must be changeable without touching system code, by a
designer or during a friend-test. All numbers live in `src/shared/Config.lua` (rules) and the
shared data modules (`Weapons`, `Armor`, `Cybernetics`, `Skills`, `Items`); server systems read
them, and the client reads the same modules for display, so what the HUD shows is what the server
enforces.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Roblox (Luau), Rojo 7. `src/shared` is synced to `ReplicatedStorage.Shared`, so both server and client `require` the same ModuleScripts. |
| **Domain** | Core |
| **Layer** | Foundation |
| **Knowledge Risk** | LOW |
| **References Consulted** | `src/shared/Config.lua`, `src/shared/Weapons.lua`, `src/server/Gear.lua`, `src/server/Combat.lua`, `src/client/Main.client.lua` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0003 (the `src/shared` folder is what makes one data module readable on both sides) |
| **Enables** | ADR-0004 (telegraph timing and asset slots must come from shared data, not client constants) |
| **Blocks** | None |
| **Ordering Note** | ADR-0004's `Presentation.lua` is an extension of this rule to non-numeric asset data. |

## Context

### Problem Statement
A timing-based combat game lives or dies on tuning passes. The roadmap's first item after friend
testing is "Tune Flicker/Black Flash timing (`Config.Flicker`), plus weapon numbers". If numbers
are scattered through systems, each pass is a code change and a regression risk, and the client
can drift from the server.

### Current State
Implemented, with one known leak:
- `Config.lua` header: "Every number a designer will want to tweak lives here." Sections:
  `Dev`, `Tutorial`, prologue timers, `Stats`, `Flicker`, `Combat`, loot/respawn.
- `Combat.lua` aliases `local C, F = Config.Combat, Config.Flicker` and reads every window,
  cost, cooldown and multiplier from them. The only literals are structural
  (`BUFFER = 0.08` input buffer, `0.3` knockback travel scalar, `3.5` point-blank radius,
  `0.2` dodge busy time, `0.1` regen tick).
- `Gear.lua` derives all per-player numbers from `Config.Stats`/`Combat`/`Flicker` plus the
  `Armor`/`Cybernetics` piece tables. Some derivation coefficients are literals in `compute`
  (`0.01 * weight`, `0.04 * weight`, `0.02 * weight`, `0.012`, `0.002`, `0.01`).
- Weapons carry their own frame data; `Weapons.hit()` derives `Stamina` from damage.
- Client reads `Config.Stats.Names`, `Config.RespawnDelay`, `Config.EmergenceCinematic`,
  `Skills.*`, `Items.*`, `Armor.Slots`, `Cybernetics.Slots` for display and gating text.
- **Violation**: `Main.client.lua` formats the Black Flash multiplier as `2.5 + loadout.FlashBonus`
  instead of `Config.Flicker.BlackFlashMult + loadout.FlashBonus`.

### Constraints
- Shared modules replicate to clients, so nothing secret may live in `Config` (nothing does).
- ProfileService template defaults reference `Config.Stats.StartingPoints`; changing it only
  affects new characters.

### Requirements
- A designer can retune a flick window, weapon combo or armor piece by editing one shared file.
- The server and client never disagree on a displayed vs enforced number.
- The smoke harness picks up tuning changes with no edits (it loads `src/shared` verbatim).

## Decision

1. **`src/shared/Config.lua` holds every rule-level number**: windows, cooldowns, costs,
   multipliers, timers, regen rates, caps.
2. **Shared data modules hold every per-entity number**: `Weapons.Defs` (frame data, reach,
   damage), `Armor.Pieces`, `Cybernetics.Pieces`, `Skills.Defs`, `Items.Defs/Recipes`.
3. **Systems read, never define.** A number appearing in `src/server/*.lua` or `src/client/*.lua`
   that a designer might want to change is a defect.
4. **The client reads the same modules for display** (loadout panel, hotbar lock state, HUD
   timers). It never re-declares a value.
5. **Derived values are computed in one place** (`Gear.compute`) and pushed to the client via
   `LoadoutChanged`, so the client shows the server's derivation rather than recomputing it.

### Architecture Diagram
```
 src/shared/Config.lua ─┬─► src/server/Combat.lua      (C.*, F.*)
 src/shared/Weapons.lua ─┼─► src/server/Gear.lua        (compute -> LoadoutChanged)
 src/shared/Armor.lua ───┼─► src/server/SkillRunner.lua
 src/shared/Skills.lua ──┼─► src/server/Stats.lua / WorldPhase.lua / Tutorial.lua
 src/shared/Items.lua ───┴─► src/client/Main.client.lua (display only)
```

### Key Interfaces
- `Config.Combat.*`, `Config.Flicker.*`, `Config.Stats.*`, `Config.Tutorial.*`, `Config.Dev.*`.
- `Weapons.Defs[id].Attacks[i]` / `.Heavy` spec: `{ Damage, Posture, Windup, Active, End, Range, Arc, Stamina, Knockback?, Stun?, Hyperarmor?, Type?, Ranged? }`.
- `Gear.Get(player)` -> derived table; mirrored to client as the `LoadoutChanged` payload.

### Implementation Guidelines
- A system **must** `require` `Config`/data modules and **must never** inline a gameplay
  literal; structural constants (frame buffers, epsilon radii) **may** be local constants with
  a comment saying why they are not tuning.
- The client **must** read `Config` for any number it displays and **must never** duplicate a
  server-side value as a literal.
- New tuning **must** be added to the relevant `Config` section or data module with a
  one-line comment, not to the consuming system.
- `Gear.compute` coefficients **should** be lifted into `Config.Gear` on the next touch.

## Alternatives Considered

### Alternative 1: Per-system config tables
- **Description**: Each server module owns a `local TUNING = {}` block at its top.
- **Pros**: Locality; no cross-module coupling.
- **Cons**: Client cannot read server modules, so display values would be duplicated; tuning
  passes touch many files.
- **Estimated Effort**: Lower initially.
- **Rejection Reason**: Breaks client/server agreement and the designer's single file.

### Alternative 2: Attributes / Configuration instances in the DataModel
- **Description**: Store tuning on a `Configuration` folder's attributes, editable in Studio.
- **Pros**: Live-editable in a running Studio session.
- **Cons**: Not diffable in git, not loadable by the headless smoke harness, no comments.
- **Estimated Effort**: Moderate.
- **Rejection Reason**: Rojo + Luau tables already give fast iteration with version control.

## Consequences

### Positive
- Tuning is a one-file edit; the README tells testers to set `Config.PrologueSeconds` and
  `Config.Dev.Enabled` directly.
- The smoke harness exercises the real numbers.
- Client gating text ("needs Plated") comes from the same `Skills.Unlocked` the server uses.

### Negative
- `Config` replicates to clients; exploiters can read windows (acceptable — nothing is secret
  and the server still judges).
- Discipline-based: nothing enforces it except review. The `2.5` client literal shows the
  leak is real (tracked as TR-002 and in `architecture.md` §Known Gaps).

### Neutral
- `Config` is a flat Lua table, not typed; a `--!strict` type export would help tooling.

## Risks
- **Drift** — a future contributor adds a literal in a system. Mitigation: TR-002 review rule;
  grep for numeric literals in `src/server` and `src/client` during `/code-review`.
- **Template coupling** — changing `Config.Stats.StartingPoints` does not affect existing
  profiles (`Reconcile` only adds missing keys). Mitigation: document in `PlayerData.lua` (already done).

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| combat.md | Tuning knobs: parry window, posture, stamina costs, dodge i-frames | All in `Config.Combat`; armor modifies via `Gear.compute` |
| flicker.md | Flick window, chain multipliers, Black Flash x2.5, Zone duration | All in `Config.Flicker` |
| weapons.md | Weapon = moveset with per-attack frame data | `Weapons.Defs` is the only place frame data exists |
| progression.md | Stat coefficients, XP curve, points per level | `Config.Stats`; `Stats.XpNeeded` |
| world-phase.md | Prologue cap, minimum, cinematic length | `Config.PrologueSeconds`, `PrologueMinSeconds`, `EmergenceCinematic` |

## Performance Implications
- **CPU / Memory / Load Time / Network**: negligible; one shared table replicated once.

## Migration Plan
Already in place. Follow-up: replace the client's `2.5` literal with
`Config.Flicker.BlackFlashMult`; lift `Gear.compute` coefficients into `Config.Gear`.
**Rollback plan**: not applicable.

## Validation Criteria
- `grep -nE "[0-9]+\.[0-9]+" src/client/*.lua` shows no gameplay multipliers.
- Changing `Config.Flicker.BlackFlashMult` changes both server damage and the loadout panel text.

## Related
- ADR-0003 (shared folder), ADR-0004 (`Presentation.lua` extends this to asset slots)
- `docs/architecture/architecture.md` §Known Gaps
- `src/shared/Config.lua`, `src/shared/Weapons.lua`, `src/server/Gear.lua`
