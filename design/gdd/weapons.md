# Weapons

> **Status**: Implemented (reverse-documented)
> **Author**: Claude (reverse-doc) — pending owner review
> **Last Updated**: 2026-10-25
> **Last Verified**: 2026-10-25 against `src/shared/Weapons.lua`, `src/server/Combat.lua:429-460, 487-529`, `src/shared/Items.lua`, `src/server/Gear.lua:171-179`
> **Implements Pillar**: 3 — Skill-based combat (movesets differ in timing and reach, not in locked abilities)

## Summary

**Weapon = moveset.** A weapon is nothing but a table of attack specs: a light combo chain, one heavy,
and per-attack frame data (windup / active / end), reach, arc, damage type and knockback. Weapons grant
no skills and no resistances (`Weapons.lua:1-2`); those come from stats and armor. Seven weapons exist,
one of which (Arc Pistol) is hitscan.

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Key deps: `Combat (Swing/pulse), Gear (equip), Items (registry, recipes, loot), PlayerData (Equipped)`

## Overview

`Weapons.Defs[id]` (`Weapons.lua:23-86`) holds `Name`, `Family`, `ComboReset`, `ComboCooldown`,
optional `ChargeBonus`, an ordered `Attacks` array and a `Heavy` spec. The `hit()` helper
(`Weapons.lua:12-21`) builds a spec with defaults `Arc = 0.3` and `Stamina = floor(Damage × 0.6 + 2)`;
an `extra` table overrides any field. `Combat.Attack` walks `Attacks` in order and `Combat.Heavy` runs
`Heavy` with `postureMult = 1.75` (`combat.md`). The equipped weapon is `PlayerData.Equipped`
(default `Fists`, new characters start with `PipeClub`; `PlayerData.lua:51-52`). Equipping requires
owning the item (`Gear.EquipWeapon`, `Gear.lua:171-179`); losing the item reverts to Fists
(`Gear.Validate`). Skill strikes borrow the weapon's heavy `Range`, `Arc`, `Ranged` and `Type`
(`SkillRunner.lua:35-43`), so reach is the one weapon property that leaks into skills.

### Current Presentation
No weapon has a model, animation or sound; the equipped weapon is visible only as text in the
Inventory and Loadout panels. The Arc Pistol draws a 0.1 s neon beam (`Bolt`). The Combat Feel epic
adds procedural weapon models and Motor6D swings with animation-ID slots per weapon.

## Player Fantasy

`[inferred — confirm]` Picking up a weapon changes how you fight, not what you are: a spear player
pokes at 11-13 studs in a narrow cone, a sledge player commits to 0.6 s hyperarmored heavies, a baton
player builds charge fast for flicks and Surge.

## Detailed Rules

### Attack spec fields (`Weapons.lua:4-9`)
| Field | Unit | Meaning | Default |
|---|---|---|---|
| `Damage` | HP | Raw damage, scaled by `Gear.DamageMult` | required |
| `Posture` | posture | Raw posture damage, scaled by `Gear.PostureDamageMult`; heavies ×1.75 | required |
| `Windup` | s | Delay before the hitbox opens | required |
| `Active` | s | Hitbox pulses every Heartbeat for this long | required |
| `End` | s | Total time from swing start to next input (minus 0.08 buffer) | required |
| `Range` | studs | Melee: `GetPartBoundsInRadius` radius. Ranged: raycast length | required |
| `Arc` | dot | Min `dot(look, flatToTarget)`; targets < 3.5 studs always hit | 0.3 |
| `Stamina` | stamina | Cost before `StaminaCostMult` | `floor(Damage × 0.6 + 2)` |
| `Knockback` | studs/s | Push on unblocked hit (wall-aware) | nil (none) |
| `Stun` | s | Hit stun on target | nil → `HitStunDefault 0.35` |
| `Hyperarmor` | bool | No stun/knockback during windup + active | nil |
| `Type` | `Physical` / `Arc` | Which resistance applies | nil → Physical |
| `Ranged` | bool | Single raycast instead of cone | nil |

Arc dot → cone: 0.0 = 180°, 0.2 = 157°, 0.3 = 145°, 0.6 = 106°, 0.7 = 91°.

### Weapon-level fields
- `ComboReset` (s): after the chain's `End` (+ `ComboCooldown` on the last step) the next light must arrive within this time to continue the chain; otherwise step 1 (`Combat.lua:498, 511`).
- `ComboCooldown` (s): extra recovery added after the **last** step of the chain (`Combat.lua:508-510`).
- `ChargeBonus`: added to `ChargePerHit (8)` before `ChargeGain` scaling (`Combat.lua:417`).
- `Family`: label only; nothing reads it today.

### Combo tables (all numbers raw, before stat scaling)

**Fists** — `Family Fists`, `ComboReset 0.7`, `ComboCooldown 0.35`, no ChargeBonus. Always available; the fallback weapon.
| Attack | Dmg | Post | Windup | Active | End | Range | Arc | Stamina | Extra |
|---|---|---|---|---|---|---|---|---|---|
| 1 | 6 | 3 | 0.10 | 0.12 | 0.30 | 6 | 0.3 | 5 | — |
| 2 | 6 | 3 | 0.10 | 0.12 | 0.30 | 6 | 0.3 | 5 | — |
| 3 | 6 | 3 | 0.10 | 0.12 | 0.34 | 6 | 0.3 | 5 | — |
| 4 | 9 | 6 | 0.14 | 0.14 | 0.55 | 6 | 0.3 | 7 | Knockback 30 |
| Heavy | 12 | 8 | 0.30 | 0.15 | 0.80 | 6 | 0.3 | 14 | Knockback 35 |

**Pipe Club** — `Family Blunt`, `ComboReset 0.7`, `ComboCooldown 0.45`. Starting weapon.
| Attack | Dmg | Post | Windup | Active | End | Range | Arc | Stamina | Extra |
|---|---|---|---|---|---|---|---|---|---|
| 1 | 12 | 5 | 0.16 | 0.14 | 0.50 | 7 | 0.3 | 9 | — |
| 2 | 12 | 5 | 0.16 | 0.14 | 0.50 | 7 | 0.3 | 9 | — |
| 3 | 18 | 10 | 0.22 | 0.16 | 0.70 | 7 | 0.3 | 12 | Knockback 35 |
| Heavy | 26 | 14 | 0.40 | 0.16 | 1.00 | 7.5 | 0.3 | 20 | Knockback 45 |

**Rebar Blade** — `Family Blade`, `ComboReset 0.7`, `ComboCooldown 0.45`. Recipe: 6 Scrap + 1 Cloth.
| Attack | Dmg | Post | Windup | Active | End | Range | Arc | Stamina | Extra |
|---|---|---|---|---|---|---|---|---|---|
| 1 | 11 | 4 | 0.12 | 0.14 | 0.40 | 8 | 0.3 | 8 | — |
| 2 | 11 | 4 | 0.12 | 0.14 | 0.40 | 8 | 0.3 | 8 | — |
| 3 | 13 | 5 | 0.14 | 0.14 | 0.45 | 9 | **0.2** | 9 | wide sweep |
| 4 | 17 | 9 | 0.20 | 0.16 | 0.70 | 9 | 0.3 | 12 | Knockback 30 |
| Heavy | 24 | 12 | 0.35 | 0.18 | 0.95 | 8.5 | **0.0** | 20 | 180° spin, no knockback |

**Shock Baton** — `Family Baton`, `ComboReset 0.7`, `ComboCooldown 0.4`, **ChargeBonus 6**. All hits `Type Arc`. Recipe: 1 Pipe Club + 3 Wire + 2 Scrap.
| Attack | Dmg | Post | Windup | Active | End | Range | Arc | Stamina | Extra |
|---|---|---|---|---|---|---|---|---|---|
| 1 | 10 | 4 | 0.12 | 0.12 | 0.40 | 7 | 0.3 | 8 | Arc |
| 2 | 10 | 4 | 0.12 | 0.12 | 0.40 | 7 | 0.3 | 8 | Arc |
| 3 | 16 | 10 | 0.18 | 0.14 | 0.65 | 7 | 0.3 | 11 | Arc, Knockback 25, **Stun 0.6** |
| Heavy | 22 | 12 | 0.35 | 0.16 | 0.90 | 7 | 0.3 | 18 | Arc, **Stun 0.7**, no knockback |

**Scrap Spear** — `Family Spear`, `ComboReset 0.8`, `ComboCooldown 0.45`. Recipe: 5 Scrap + 2 Cloth.
| Attack | Dmg | Post | Windup | Active | End | Range | Arc | Stamina | Extra |
|---|---|---|---|---|---|---|---|---|---|
| 1 | 8 | 3 | 0.14 | 0.12 | 0.40 | 11 | 0.6 | 6 | thrust |
| 2 | 8 | 3 | 0.14 | 0.12 | 0.40 | 11 | 0.6 | 6 | thrust |
| 3 | 12 | 6 | 0.18 | 0.14 | 0.55 | 12 | 0.6 | 9 | Knockback 25 |
| Heavy | 20 | 10 | 0.35 | 0.16 | 0.90 | 13 | 0.7 | 18 | Knockback 30 |

**Sledge** — `Family Hammer`, `ComboReset 0.9`, `ComboCooldown 0.7`. Recipe: 12 Scrap + 1 Wire.
| Attack | Dmg | Post | Windup | Active | End | Range | Arc | Stamina | Extra |
|---|---|---|---|---|---|---|---|---|---|
| 1 | 24 | 12 | 0.30 | 0.16 | 0.75 | 8 | 0.3 | 16 | Knockback 40 |
| 2 | 24 | 12 | 0.30 | 0.16 | 0.85 | 8 | 0.3 | 16 | Knockback 40 |
| Heavy | 44 | 28 | 0.60 | 0.20 | 1.40 | 9 | 0.3 | 30 | **Hyperarmor**, Knockback 60 |

**Arc Pistol** — `Family Sidearm`, `ComboReset 0.5`, `ComboCooldown 0.3`, **ChargeBonus 3**. All hits `Type Arc`, `Ranged`. Recipe: 6 Scrap + 5 Wire.
| Attack | Dmg | Post | Windup | Active | End | Range | Stamina | Extra |
|---|---|---|---|---|---|---|---|---|
| 1 | 9 | 3 | 0.08 | 0.05 | 0.42 | 90 | 8 | Ranged, Arc type |
| Heavy | 22 | 10 | 0.50 | 0.05 | 1.20 | 110 | 22 | Ranged, Arc type, Knockback 20 |

### The ArcPistol hitscan case (`Combat.lua:429-444`)
- On the **first pulse only** (`seen.__fired`) the server raycasts from the shooter's `HumanoidRootPart` along its `LookVector` for `Range` studs, excluding the shooter. `Active 0.05` means there is at most one extra pulse, which returns immediately.
- The `Bolt` FX is fired to all clients with the end point (hit position or max range) — the beam is drawn even on a miss.
- The first instance hit decides: if its ancestor Model has a Humanoid it is struck (through the normal `strike` path: flick judgement, charge, kill tag); otherwise the shot is absorbed by the geometry. Walls block the pistol; melee cones do not check walls.
- Because the ray starts at the root (torso height) and uses the root's facing, not the camera, aiming is "where the character faces" — the brief's Aiming epic (mouse-facing in combat) is what makes the pistol go where the player looks.
- The pistol is a one-step "combo": `ComboCooldown 0.3` applies after every shot, so cadence is `End 0.42 + 0.3 = 0.72 s` per light shot (F3).
- Flick timing: windup 0.08 s < window 0.28 s, so pressing `E` then firing is always a valid flick (see `flicker.md` edge cases).

### Reach and arc model
- Melee range is a **sphere** around the root; the cone check is on the flat (XZ) vector to the target's root, so vertical offset does not matter.
- Point-blank (< 3.5 studs flat) ignores the arc — all weapons hit someone standing in you from behind.
- Reach tiers today: Fists 6 · Club / Baton 7 · Blade 8-9 · Sledge 8-9 · Spear 11-13 · Pistol 90-110.

### Acquisition
- Starting kit: Pipe Club (`PlayerData.lua:51`). Fists always equippable.
- Crafting (`Items.Recipes`): Rebar Blade, Scrap Spear, Shock Baton, Sledge, Arc Pistol (Pipe Club itself is not craftable).
- Loot (`Items.LootTables`): Supply crate rolls Rebar Blade 15 %, Scrap Spear 12 %, Shock Baton 8 %, Sledge 6 %, Arc Pistol 5 %; Raider drops Pipe Club 10 %.
- Dev armory "Weapons Rack" grants every weapon (`Arena.lua:240`).

## Formulas

### F1 — Default stamina cost of an attack
`Stamina = floor(Damage × 0.6 + 2)` unless overridden (`Weapons.lua:15`).

| Variable | Type | Range | Lives in |
|---|---|---|---|
| `Damage` | number | 6-44 | `Weapons.Defs[*].Attacks[*].Damage` |

Output: 5 (Damage 6) to 16 (Damage 24); overrides 8-30.
**Example**: Rebar Blade step 4, Damage 17 → `floor(10.2 + 2) = 12`.

### F2 — Raw combo damage and chain duration
`chainDamage = Σ Attacks[i].Damage`; `chainTime = Σ Attacks[i].End + ComboCooldown` (ignoring the 0.08 s input buffer); `rawDPS = chainDamage / chainTime`.

| Variable | Type | Range | Lives in |
|---|---|---|---|
| `Attacks[i].End` | s | 0.30-0.85 | `Weapons.Defs` |
| `ComboCooldown` | s | 0.3-0.7 | `Weapons.Defs` |

| Weapon | Chain dmg | Chain time | Raw DPS | Stamina/chain |
|---|---|---|---|---|
| Fists | 27 | 1.84 | 14.7 | 22 |
| Pipe Club | 42 | 2.15 | 19.5 | 30 |
| Rebar Blade | 52 | 2.40 | 21.7 | 37 |
| Shock Baton | 36 | 1.85 | 19.5 | 27 |
| Scrap Spear | 28 | 1.80 | 15.6 | 21 |
| Sledge | 48 | 2.30 | 20.9 | 32 |
| Arc Pistol | 9 | 0.72 | 12.5 | 8 |

**Example**: Pipe Club `12 + 12 + 18 = 42` over `0.5 + 0.5 + 0.7 + 0.45 = 2.15 s` → 19.5 raw DPS; at Strength 10 (×1.3) 25.4 DPS.

### F3 — Heavy cadence
`heavyPeriod = max(End, HeavyCooldown)`; `HeavyCooldown = 1.2` (`Config.Combat`, checked at `Combat.lua:520`).

| Weapon | Heavy End | Period | Raw dmg | Raw posture (×1.75) |
|---|---|---|---|---|
| Fists | 0.80 | 1.20 | 12 | 14 |
| Pipe Club | 1.00 | 1.20 | 26 | 24.5 |
| Rebar Blade | 0.95 | 1.20 | 24 | 21 |
| Shock Baton | 0.90 | 1.20 | 22 | 21 |
| Scrap Spear | 0.90 | 1.20 | 20 | 17.5 |
| Sledge | 1.40 | 1.40 | 44 | 49 |
| Arc Pistol | 1.20 | 1.20 | 22 | 17.5 |

**Example**: Sledge heavy posture `28 × 1.75 = 49` raw; versus an 80-posture naked defender, two blocked Sledge heavies break guard.

### F4 — Cone half-angle from Arc
`halfAngle = acos(Arc)`; target is hit if `dot(look, flatUnit) ≥ Arc` or `flatDistance < 3.5` (`Combat.lua:454`).

| Variable | Type | Range | Lives in |
|---|---|---|---|
| `Arc` | number | 0.0-0.7 (Dash skill uses −1 = everything) | `Weapons.Defs`, `SkillRunner.lua:56` |

**Example**: Scrap Spear `Arc 0.6` → `acos(0.6) = 53.1°` half-angle, a 106° cone; Rebar Blade heavy `Arc 0.0` → 180° (everything in front of the hip plane).

### F5 — Combo continuation deadline
`comboExpires = swingStart + End (+ ComboCooldown on the last step) + ComboReset` (`Combat.lua:469, 509-511`).

**Example**: Sledge step 2 at `t0`: `t0 + 0.85 + 0.7 + 0.9 = t0 + 2.45 s` — a third light before then restarts at step 1 anyway (chain length 2, `combo % 2 + 1`), so for Sledge `ComboReset` only matters for whether step 1 or step 2 comes next.

## Edge Cases

- **Hitscan starts at the torso**: a target lower than the shooter (down a slope) or hidden behind a 2.5-stud rail is missed even if visible from the camera.
- **Beam on miss**: `Bolt` is drawn to max range on a miss, so the pistol always shows where it pointed.
- **Pistol and Flicker**: the 0.08 s windup makes every flick trivially timed; the pistol can chain Black Flashes at 90 studs (22 × 2.5 = 55 raw heavy Flash). `[balance — confirm]`
- **Melee through walls**: the sphere + cone check has no occlusion; only the pistol respects geometry.
- **Rebar Blade heavy `Arc 0.0` has no Knockback**: the only heavy without a push (every other heavy pushes 20-60).
- **Shock Baton stuns longer than default** (0.6 / 0.7 vs 0.35) and is the fastest charge builder (`ChargeBonus 6`), but its heavy has no knockback and the whole kit is `Arc` type — Arc-Lined Hood (12 %) + Conduit Harness (15 %) + Arc Gauntlet (10 %) stack to 37 % resistance against it.
- **Sledge hyperarmor covers windup + active (0.80 s)** but not the 0.60 s of recovery; a parry still stuns the Sledge user (parry stun is applied to the attacker regardless of hyperarmor).
- **Weapon lost mid-combo** (crafted into a baton, dropped): `Gear.Validate` reverts to Fists; `comboWeapon ~= weapon` restarts the chain.
- **Weapon swap costs nothing**: equipping is instant with no busy time; a player can swap Sledge → Pistol between swings. `[confirm]`
- **`Family` is unused**: no system reads it; safe to repurpose for animation sets.
- **Default `Arc = 0.3` applies to ranged specs too** but is ignored by the raycast path.

## Dependencies

- **Combat**: `Swing`, `pulse`, `Attack`, `Heavy` consume specs; `Config.Combat.HeavyCooldown`, `CriticalPostureMult`, `HitStunDefault` fill gaps.
- **Gear**: `EquipWeapon`, `Validate`, `Unequip("Weapon")`; `DamageMult` / `PostureDamageMult` / `StaminaCostMult` scaling.
- **Items**: registers each weapon as an item (`Items.lua:16-18`), recipes, loot tables.
- **PlayerData**: `Equipped` field, starting kit.
- **SkillRunner**: Strike skills borrow heavy `Range`/`Arc`/`Ranged`/`Type`.
- **Client**: Inventory Equip/Unequip buttons (`Main.client.lua:141-145`), `Bolt` FX.
- **Dependents**: `flicker.md` (window vs windup), `enemies.md` (NPC reach is separate: `TYPES.Raider.Range`).

## Tuning Knobs

Everything in `Weapons.Defs`; the `hit()` stamina formula constants `0.6` and `2`; default `Arc 0.3`
(`Weapons.lua:15`). Shared combat constants that shape weapon feel: `HeavyCooldown 1.2`,
`CriticalPostureMult 1.75`, `HitStunDefault 0.35`, input buffer `0.08`, point-blank radius `3.5`.
`docs/DESIGN.md` roadmap lists "weapon numbers" for tuning after friend testing.

## Visual/Audio Requirements

Per the brief: a procedural placeholder model per weapon, Motor6D swing/windup animation with an
animation-ID slot per attack (combo index / Heavy), hit sparks and a sound slot per weapon family.
`Swing` already carries the label (`combo index`, `"Heavy"`, or skill name) needed to pick the clip.

## Acceptance Criteria

1. Every weapon in `Weapons.Defs` is registered in `Items.Defs` with `Type = "Weapon"` and can be equipped only when owned (Fists excepted).
2. Light attacks follow `Attacks` in order and wrap to step 1 after the last; waiting longer than `End (+ ComboCooldown) + ComboReset` restarts at step 1.
3. Each attack opens its hitbox exactly `Windup` s after the input and closes `Active` s later; damage, posture, knockback, stun, type and hyperarmor match the spec row above.
4. A melee target is struck iff within `Range` studs of the attacker's root and (`dot ≥ Arc` or flat distance < 3.5), at most once per swing.
5. An Arc Pistol shot performs one raycast of `Range` studs from the root along its look vector, fires `Bolt` to the hit or end point, and strikes only the first Humanoid model hit; geometry blocks it.
6. Heavy attacks cannot be started within 1.2 s of the previous heavy and apply `Posture × 1.75`.
7. Shock Baton and Arc Pistol hits grant `8 + ChargeBonus` base charge; all others grant 8.
8. Default stamina equals `floor(Damage × 0.6 + 2)` for every spec without an explicit `Stamina`.

## Open Questions

- Should the pistol aim from the camera instead of the root once the Aiming epic lands?
- Should weapon swap have a busy time, or is instant swapping a deliberate Deepwoken-style freedom?
- Is the Rebar Blade heavy's missing knockback intentional (a spin that keeps targets close)?
- Should `Family` drive animation sets and hit sounds in the Combat Feel epic?
