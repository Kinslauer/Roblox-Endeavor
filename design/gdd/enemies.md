# Enemies

> **Status**: Placeholder (Raider as implemented) + Planned (Enemy v2, proposed)
> **Author**: Claude (reverse-doc) — pending owner review
> **Last Updated**: 2026-10-25
> **Last Verified**: 2026-10-25 against `src/server/NPCs.lua`, `src/server/Events.lua:46-56`, `src/server/Tutorial.lua:97-131`, `src/server/Combat.lua` (NPC paths), `src/shared/Items.lua:53-56`
> **Implements Pillar**: 3 — Skill-based combat (an enemy worth reading) and 4 — A living ruin (ambushes)

## Summary

The only hostile NPC today is the **Raider**: a two-part placeholder rig that walks straight at the
nearest player and deals 9 damage every 1.1 s with no windup. It exists so events, quests, loot and
kill credit have something to hook into. The brief's MVP item 3 ("an enemy worth fighting") replaces it
with **Enemy v2**: a real rig, pathfinding, a telegraphed attack the player can parry or dodge, and
Grunt / Brute / Gunner variants. Section `## Planned (Enemy v2)` below is a **proposal**, not a
description of code.

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `Combat (Damage, GetKiller, Stun), Loot, Items, Quests, Stats, Events`

## Overview

`NPCs.lua` (86 lines) exposes `NPCs.BuildRig(name, typeDef)` and `NPCs.Spawn(typeName, position)`.
The `TYPES` table (`NPCs.lua:14-16`) has one entry. Spawned Raiders run a `task.spawn` loop every
0.2 s that picks a target and either moves or attacks. Death pays XP and quest progress to
`Combat.GetKiller` and drops a `Raider` loot roll. The header comment states the status: "Placeholder
rig + simple chase/attack AI." (`NPCs.lua:1`). `BuildRig` is also used by the tutorial dummy and the
arena dummies (anchored, `Speed 0`, `Health 1000`), which are not enemies.

### Current Presentation
The rig is a 2×5×1 dark-red `HumanoidRootPart` with a ball `Head` welded 3.2 studs up
(`NPCs.lua:21-29`), `HipHeight 2`; no limbs, no animation, no attack telegraph. On attack it snaps to
face the target (`PivotTo(CFrame.lookAt)`, `NPCs.lua:76`) and the victim sees the standard red `Hit`
flash. The tutorial dummy is the only NPC with a telegraph (red Highlight for 0.8 s), and that lives
in `Tutorial.lua`, not in `NPCs.lua`.

## Player Fantasy

`[inferred — confirm]` Raiders are the city's ambient threat: disposable scavengers who ambush in
packs of 2-4 and are mostly a loot and XP source. Enemy v2 is where they become a reading exercise —
the brief's "win a fight against a telegraphed enemy by reading its windup".

## Detailed Rules

### Raider definition (`NPCs.lua:15`) — **Placeholder**
| Field | Value | Used by |
|---|---|---|
| `Health` | 70 | `Humanoid.MaxHealth/Health` |
| `Speed` | 13 | `Humanoid.WalkSpeed` (player base is 15) |
| `Damage` | 9 | `Combat.Damage` amount and posture |
| `Range` | 6 studs | attack if `dist ≤ Range × 0.8 = 4.8`; move otherwise |
| `Cooldown` | 1.1 s | min time between attacks |
| `Aggro` | 90 studs | max target distance |
| `Xp` | 35 | paid to killer |
| `Loot` | `"Raider"` | `Items.LootTables.Raider` |

### AI loop (`NPCs.lua:55-82`), every 0.2 s while alive
1. Target = the living player character with the smallest root distance `< Aggro`. Re-evaluated every tick; no memory, no leash, no line-of-sight check.
2. If `dist > 4.8`: `Humanoid:MoveTo(target.root.Position)` — straight line, no pathfinding; a wall or pillar stops it.
3. Else if `now − lastAttack > 1.1`: snap-face the target, then `Combat.Damage(model, target, 9, { Posture = 9, Knockback = 15 })` **instantly**. No windup, no `Swing`, no `Swing`/`Flick` FX, no arc check (range is the only condition).
4. The loop does **not** check the Raider's own stun: a parried or hit-stunned Raider (`WalkSpeed 0`) keeps attacking on cooldown if the player stays within 4.8 studs.

### Raider as a defender
Uses `Gear.Default()` (`Gear.lua:35-42`): no resistances, `MaxPosture 80`, `DodgeIFrames 0.35`, `DamageMult 1`. It never blocks or dodges, so every player hit is a clean `hit` (posture is irrelevant). Hit stun (0.35 s default) and knockback apply normally; knockback is server-side `AssemblyLinearVelocity` (`Combat.lua:283`). Hyperarmor none. Its hits can be parried, blocked and dodged by the player through the standard `applyDamage` path.

### Death (`NPCs.lua:44-53`)
- `Combat.GetKiller(model)`: if a player hit it within 15 s → `Stats.AddXp(killer, 35)` and `Quests.Progress(killer, "kill", "Raider", 1)`.
- `Loot.Spawn(root.CFrame, Items.Roll("Raider"), { Lifetime = 120 })`; the model is destroyed 0.2 s later. No remains if the roll is empty (`Loot.lua:14`).
- Raider loot table (`Items.lua:53-56`), each line rolled independently: Scrap 90 % ×1-3, Cloth 50 % ×1-2, Wire 35 % ×1-2, Ration 30 %, Pipe Club 10 %, Scav Helm / Scrap Vest / Scrap Greaves 8 % each.

### Spawning
- **Raider ambush** (`Events.lua:46-56`): weight 4 of 7 in the director pool; picks a random player, announces "Raiders have found you." to that player only, spawns `2-4` Raiders on a 55-stud ring at `+4` Y around them. No ground or bounds check — the brief's "stuck-on-wall spawning" and "events that spawn inside the playable area" items.
- Quest `raider_cull` asks for 3 Raider kills (`Quests.lua:13`).
- Tutorial dummy (`Tutorial.lua:97-103`) and arena dummies (`Arena.lua:197-219`) reuse `BuildRig` with `Health 1000, Speed 0`, anchored, no AI loop.

### Tutorial dummy strike (`Tutorial.lua:105-131`) — the only telegraphed NPC attack
Every `DummyInterval 2.8` s during defence steps: red Highlight on the dummy for `DummyTelegraph 0.8` s,
then `Combat.Damage(dummy, player, 6, { Posture = 12 })`. The player cannot die to it (healed to 70 %
below 40 %). This is the pattern Enemy v2 should generalise.

## Formulas

### F1 — Raider damage taken by a player
`taken = 9 × (blocked ? 1 − BlockReduction : 1) × (1 − min(0.75, Resist.Physical))` (`Combat.lua:326-335`); no stat scaling because the Raider bypasses `pulse`.

| Variable | Type | Range | Lives in |
|---|---|---|---|
| `Damage` | number | 9 | `NPCs.lua:15` |
| `BlockReduction` | number | 0.7-0.82 | `Config.Combat.BlockReduction` + `0.02 × WeightScore` (`Gear.lua:91`) |
| `Resist.Physical` | number | 0-0.75 | `Gear.compute` |

Output: 2.25 (blocked, max resist) to 9 (naked).
**Example**: player with Scrap Vest (`Physical 0.06`), Fortitude 0: unblocked `9 × 0.94 = 8.46`; blocked `9 × 0.3 × 0.94 = 2.54`, posture +9.

### F2 — Raider time-to-kill a naked player
`hits = ceil(MaxHealth / 9)`, `time ≈ (hits − 1) × 1.1` (first hit is immediate on entering 4.8 studs).

| Variable | Type | Range | Lives in |
|---|---|---|---|
| `MaxHealth` | number | 100 + Fortitude × 8 (−HealthPenalty), min 40 | `Config.Stats`, `Gear.lua:85` |
| `Cooldown` | s | 1.1 | `NPCs.lua:15` |

**Example**: 100 HP → 12 hits → ≈ 12.1 s of standing still; an ambush of 4 → ≈ 2.2 s.

### F3 — Player hits to kill a Raider
`hits = ceil(70 / (spec.Damage × DamageMult))`.

**Example**: Pipe Club, Strength 0: `12, 12, 18, 12, 12, 18 = 84 ≥ 70` → 6 hits, two full chains (≈ 4.3 s by `weapons.md` F2). Sledge heavy at Strength 10: `44 × 1.3 = 57.2` → 2 heavies.

### F4 — Ambush expected loot
Per Raider: Scrap `0.9 × 2 = 1.8`, Cloth `0.5 × 1.5 = 0.75`, Wire `0.35 × 1.5 = 0.525`; gear pieces `0.1 + 3 × 0.08 = 0.34` items. A 3-Raider ambush ≈ 5.4 Scrap, 2.3 Cloth, 1.6 Wire, ~1 gear piece, 105 XP.

### F5 — Spawn ring
`pos = playerRoot + (55 cos θ, 4, 55 sin θ)`, `θ ~ U(0, 2π)`, count `~ U{2,3,4}` (`Events.lua:52-54`). Aggro 90 > 55, so every spawned Raider targets immediately.

## Edge Cases

- **Stunned Raiders still attack** (loop ignores `Combat.State(model).stunned`), so a parry freezes the Raider in place but does not stop its damage ticks. Parry is therefore weaker vs NPCs than vs players.
- **No stun → no telegraph window**: the brief's "parry or dodge its windup" is impossible against the current Raider; players can only pre-block, which costs posture, or kite at > 4.8 studs (the Raider is slower: 13 vs 15).
- **Straight-line MoveTo**: Raiders pile against cover, pillars and the arena ring; spawns at `+4` Y over a wall drop onto it and stay stuck.
- **Spawn ring ignores bounds**: at the 84-stud arena radius a player near the edge gets Raiders outside the ring (55-stud offset) that cannot path in.
- **Target switching every 0.2 s**: a group of Raiders converges on whichever player is nearest each tick; two players at similar distances cause oscillation.
- **Kill credit steal**: `GetKiller` credits whoever hit last within 15 s, including another Raider? No — NPC-on-NPC damage never happens (Raiders target players only), but a second player can steal the kill with a last hit.
- **No despawn or leash**: Raiders live until killed; they follow across the whole map within 90 studs.
- **Loot lifetime 120 s** vs corpse default 300 s; remains disappear faster than player remains.
- **Dummies share the rig**: anchored root means `knockback` sets velocity on an anchored part (no effect) and `Stun` sets `WalkSpeed 0` on a 0-speed Humanoid (no effect). Harmless.
- **No damage type**: Raider hits are Physical by default; Arc resistance does nothing against them.
- **No posture pressure on the player**: 9 posture per blocked hit vs 80+ max means a blocking player breaks only after 9+ consecutive blocks without regen.

## Dependencies

- **Combat**: `Combat.Damage` (attack), `Combat.GetKiller` (credit), `Combat.Stun`/knockback (when hit), per-character state via `st(model)` with `Gear.Default()`.
- **Loot** + **Items**: drop on death.
- **Stats**: `AddXp`. **Quests**: kill progress.
- **Events**: the only spawner in the open world. **Tutorial** / **Arena**: reuse `BuildRig`.
- **Design docs**: `combat.md` (the defender rules the enemy must respect), `weapons.md` (reach model variants should mirror).

## Tuning Knobs

`NPCs.TYPES.Raider` (all eight fields), ambush count `2-4` and ring radius `55` (`Events.lua:52-54`),
loop period `0.2` s and attack-range factor `0.8` (`NPCs.lua:72, 80`), event pool weight `4`
(`Events.lua:59`), `Items.LootTables.Raider`. None of these are in `Config.lua`.

## Visual/Audio Requirements

Placeholder today. Enemy v2 (brief): a real rig with animation-ID slots for idle/walk/windup/attack/
death, a windup telegraph readable at combat range, hit and death sounds.

## Acceptance Criteria (current Raider)

1. `NPCs.Spawn("Raider", pos)` creates a Model with Humanoid (70 HP, WalkSpeed 13), `HumanoidRootPart` and `Head`, parented to `workspace`.
2. The Raider moves toward the nearest living player within 90 studs and stops moving when within 4.8 studs.
3. Within 4.8 studs it calls `Combat.Damage(…, 9, { Posture = 9, Knockback = 15 })` no more than once per 1.1 s; the hit obeys the player's block/parry/dodge rules.
4. On death the last player to hit it within 15 s gains 35 XP and `kill/Raider` quest progress; a `Raider` loot roll spawns at the body for 120 s; the model is removed.
5. A raider ambush spawns 2-4 Raiders 55 studs from the chosen player and announces only to that player.

---

## Planned (Enemy v2)

> **PROPOSED — NOT IMPLEMENTED.** Nothing in this section exists in `src/`. It is the design target for
> the brief's build-order item 3 ("R15 raider rig, PathfindingService, telegraphed attacks with
> parry/dodge windows, Grunt / Brute / Gunner variants, fixes for stuck-on-wall spawning"). Numbers
> are starting proposals tied to existing `Config.Combat` values so the player's defensive tools work
> unchanged. Mark any number not derived from Config as tuning.

### Rig
- R15 Humanoid rig (procedural placeholder parts in code, mesh/animation IDs as slots per the brief's "art is the player's job in Studio"). Keep `HumanoidRootPart` as the hit origin so `Combat.pulse` cone checks and the player's facing test (`BlockMinFacing`) behave as they do for players.
- NPC combat state continues to come from `Combat.State(model)` with `Gear.Default()` unless a variant overrides posture/resist by setting attributes before the first hit (`Combat.lua:39-42` already reads `MaxPosture` if present).

### Movement
- `PathfindingService:CreatePath` with `AgentRadius`/`AgentHeight` matching the rig, recomputed on a 0.5-1 s cadence or when the target moves > N studs; fall back to `MoveTo` when the path is blocked. Leash to the spawn point (proposed 120 studs) and despawn after 60 s without a target so ambush leftovers do not accumulate.
- Spawn fix: raycast down from `+20` Y at the chosen ring point to find ground; reject points whose ray hits nothing or lands outside the playable bounds (arena ring today, district bounds later); retry up to N times, then shrink the ring radius.

### Telegraphed attack — must line up with `Config.Combat`
Use `Combat.Swing(model, spec, mods)` instead of `Combat.Damage` so enemies get the same windup → active → end structure, the `Swing` FX (which the Combat Feel epic turns into a visible windup), swing-cancel on hit stun (token), and hyperarmor flags. Constraints derived from the defender's tools:

| Constraint | Reason | Config source |
|---|---|---|
| `Windup ≥ 0.5 s` for Grunt, longer for Brute | The player needs time to see the cue and press block inside the 0.22 s parry window; the tutorial dummy's 0.8 s telegraph is the proven readable value | `Config.Combat.ParryWindow 0.22`, `Config.Tutorial.DummyTelegraph 0.8` |
| `Active ≤ 0.25 s` for dodgeable attacks | A dodge grants 0.278-0.45 s of i-frames (full Plated → Agility 50); the whole active window must fit inside the worst-case i-frames so a correctly timed dodge always avoids the hit | `Config.Combat.DodgeIFrames 0.35`, `Gear.lua:92` |
| Parry success = block pressed within the last 0.22 s before the first active frame | Already how `applyDamage` judges it; no new code | `Combat.lua:313` |
| Hit stun on the enemy must cancel its windup | Comes free from `Swing`'s token check; the AI loop must also pause while `Combat.State(model).stunned > now` (fixes today's "attacks while frozen" bug) | `Combat.lua:237-262` |
| Attack cadence ≥ `Windup + Active + End` | Replace the fixed `Cooldown` with the spec's `End` plus a per-variant idle so the player gets a punish window | — |

### Variants (proposed starting values)
Reach and frame data mirror an existing weapon so the player's spacing knowledge transfers.

| Variant | Role | Mirrors | HP | Speed | Attack (dmg / posture / windup / active / end / range) | Notes |
|---|---|---|---|---|---|---|
| **Grunt** | baseline melee | Pipe Club step 3 | 70 | 13 | 12 / 8 / **0.6** / 0.16 / 0.9 / 7 | Knockback 25. Replaces the Raider 1:1 in ambushes and the `raider_cull` quest (keep `Target = "Raider"` or rename the quest). |
| **Brute** | hyperarmored heavy | Sledge heavy | 160 | 11 | 30 / 24 / **0.9** / 0.20 / 1.6 / 9 | `Hyperarmor = true` on the swing; `MaxPosture` attribute 140. Teaches "dodge, don't trade"; its 0.20 s active still fits the dodge constraint. |
| **Gunner** | ranged pressure | Arc Pistol | 55 | 14 | 10 / 3 / **0.5** / 0.05 / 1.4 / 60 | `Ranged = true`, `Type = "Arc"`; keeps 20-30 studs distance, fires on line of sight only. Windup 0.5 so the bolt is parryable by facing it; Arc armor matters. |

Loot: Grunt keeps the `Raider` table; Brute adds Sledge 5 % and Plated pieces 6 %; Gunner adds Wire ×2-4 and Arc Pistol 6 %. XP: Grunt 35, Brute 90, Gunner 50. All tuning.

### Ambush composition (proposed)
Weighted pick per slot: Grunt 60 %, Gunner 25 %, Brute 15 %; at most one Brute per ambush; group size still 2-4. Announce stays per-player.

### Acceptance Criteria (Enemy v2 — proposed)
1. Every enemy attack goes through `Combat.Swing` and emits `Swing` before any damage; a `Hit`/`GuardBreak`/`Parry` can only follow ≥ `Windup` seconds later.
2. A player who presses block within 0.22 s before the first active frame, facing the enemy, parries it and stuns it for 1.1 s; the enemy does not attack again until the stun ends.
3. A player who dodges so that the enemy's entire `Active` window falls inside their i-frames takes no damage, for every variant and every armor weight.
4. Enemies reach a player standing behind cover or around a corner within the arena without getting stuck for more than 2 s.
5. No ambush enemy spawns outside the playable bounds or embedded in geometry; failed placements are retried or dropped, never left stuck.
6. Grunt, Brute and Gunner are distinguishable by silhouette and windup length at 20 studs without reading a label.

## Open Questions

- Should the `raider_cull` quest target be renamed to Grunt, or should all melee variants count as "Raider"?
- Does the Gunner's bolt respect `BlockMinFacing` as a parry (face the shooter) or should ranged be block-only?
- Should enemies gain stats (Strength/Fortitude) through `Gear`-like attributes so Brute scaling uses the same formulas as players, or stay on raw numbers?
- Leash/despawn rules: NOT ASSESSED — depends on district size (brief item 6).
