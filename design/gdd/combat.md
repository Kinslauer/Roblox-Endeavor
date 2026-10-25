# Combat

> **Status**: Implemented (reverse-documented; presentation layer is Placeholder)
> **Author**: Claude (reverse-doc) — pending owner review
> **Last Updated**: 2026-10-25
> **Last Verified**: 2026-10-25 against `src/server/Combat.lua`, `src/shared/Config.lua`, `src/server/Gear.lua`, `src/client/Main.client.lua`
> **Implements Pillar**: 3 — Skill-based combat (timing and stamina beat stat checking)

## Summary

Server-authoritative melee/ranged combat where every attack is a timed swing (windup → active hitbox →
recovery), defenders choose between block, parry, dodge and spacing, and two meters (stamina for the
attacker, posture for the defender) decide who runs out of options first. All numbers live in
`Config.Combat`, `Config.Stats` and `Weapons.Defs`; stat and armor scaling is folded in by `Gear`.

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Key deps: `Gear, Weapons, WorldPhase, PlayerData, Remotes`

## Overview

The client only sends intent (`Attack`, `Heavy`, `Feint`, `Flicker`, `Block`, `Dodge`;
`Main.client.lua:405-438`). `Combat.lua` owns a per-character state table (`st`, lines 26-45) that
tracks busy/stun timers, block state, i-frames, combo position, hyperarmor windows, buffs and flicker
state. A swing is `Combat.Swing` (465-485): it marks the character busy for `End` seconds, waits
`Windup`, then pulses a hitbox every Heartbeat for `Active` seconds. Each hit resolves through
`applyDamage` (290-350) in a fixed order: i-frames → facing/block → parry → posture/guard break → block
reduction → buffs → resistance → damage → hit stun & knockback. NPCs bypass `Swing` and call
`Combat.Damage` directly (`NPCs.lua:77`, `Tutorial.lua:126`).

### Current Presentation

Today every combat event is a 0.15 s `Highlight` flash on the character (`Main.client.lua:288-302`):
Hit red, Block blue, Parry white, GuardBreak orange, Dodge mint, Flick red, Feint grey, Buff yellow,
Burst blue. The server fires `CombatEvent("Swing", char, label)` at the start of every swing
(`Combat.lua:472`) but **the client does not handle it** (`Main.client.lua:380`, `TODO`): there is no
windup animation, no weapon model, no swing arc, no hitstop, no sound and no camera shake. The
`Dodged` event (a successful i-frame dodge, `Combat.lua:302`) is fired but has **no entry in the client
`FLASH` table**, so a successful dodge shows nothing — this matches the brief's "dodge feedback bug".
Only the Arc Pistol (`Bolt` beam, 0.1 s) and the Black Flash (expanding red sphere + colour correction
+ banner) have bespoke effects. Damage numbers exist only on the dev-arena dummies (`Arena.lua:183`).
This is what the **Combat Feel** epic (brief, build order 1) replaces: procedural weapon models and
Motor6D swing/windup animation driven by `Swing`, a windup glow for the flick cue, hit sparks,
hitstop, camera shake and sound slots for every `CombatEvent` kind.

## Player Fantasy

`[inferred — confirm]` You win by reading, not by out-statting: a well-timed parry stuns an attacker
for over a second and a dodge through an attack costs nothing but stamina. Heavies feel like
commitments that crush guards; feints make the opponent flinch. Stamina and posture create a visible
rhythm of pressure and recovery.

## Detailed Rules

### Readiness and input buffer
- A character can act when alive, not stunned, and within `BUFFER = 0.08` s of its busy timer ending (`Combat.lua:18, 62-66`). The buffer lets the next combo input land slightly early.
- Stun sets `busyUntil = 0`, so a stunned character may act the moment stun ends (`Combat.lua:246`).

### Attacks (light combo) — `Combat.Attack` (492-512)
1. Requires `CanAct`. Picks the combo step: if the same weapon is held and `t <= comboExpires`, step = `combo % #Attacks + 1`, else step 1.
2. Spends `spec.Stamina × StaminaCostMult`; if the player cannot afford it nothing happens (no swing, no busy).
3. Drops block. Runs `Swing(spec)` with `chargeBonus = weapon.ChargeBonus`, `label = step`.
4. If this was the last step of the chain, `busyUntil += ComboCooldown` (end-of-chain recovery).
5. `comboExpires = busyUntil + ComboReset`: the chain survives this long after recovery before resetting to step 1.

### Swing frame data — `Combat.Swing` (465-485)
| Phase | Duration | What happens |
|---|---|---|
| Windup | `spec.Windup` | Character is busy; `windupUntil` set (feint allowed); `swingArmorUntil` set if `spec.Hyperarmor`. `Swing` FX fired. |
| Active | `spec.Active` | Hitbox pulses every Heartbeat (`pulse`, 361-460); each target can be hit at most once per swing (`seen`). |
| End | `spec.End` (from swing start) | Busy until here; next input may start `BUFFER` early. |

A swing is cancelled when the character's `token` changes (hit stun, dodge, feint) or it dies, checked
before the windup ends and on every pulse (`Combat.lua:475, 483`).

### Hitbox — `pulse` (361-460)
- **Melee**: `GetPartBoundsInRadius(root, spec.Range)`; a model with a Humanoid is hit if its flat offset is < 3.5 studs (point-blank always counts) or `dot(look, flatOffset) >= spec.Arc` (`Combat.lua:454`). Walls are **not** checked for melee.
- **Ranged** (`spec.Ranged`): a single `workspace:Raycast(origin, look × Range)` on the first pulse only (`seen.__fired`); fires `Bolt` FX to the hit point; damages the first Humanoid model hit. Walls block it.
- Damage and posture are scaled by `Gear` (`DamageMult`, `PostureDamageMult`) unless `mods.noStatScaling` (skill strikes). An active Overload buff adds `arcBonus` flat damage and doubles charge gain.
- Hits and guard breaks grant charge: `(ChargePerHit + weapon.ChargeBonus) × ChargeGain × (2 if overloaded)` (417).

### Damage resolution — `applyDamage` (290-350), in order
1. **None**: dead victim, self-hit, or player-vs-player while the world is not Open (`WorldPhase.IsOpen()`).
1b. **None (protected)**: victim carries a `ForceField` (spawn protection, forfeited by any offensive action), **or** either root is inside a safe zone (`District.InSafeZone` — the Relay Plaza, parts tagged `SafeZone`); the latter fires a `Safe` FX so both sides see why nothing happened.
2. **Dodged**: `t < victim.iframes` → `Dodged` FX, no damage, no tag.
3. **Facing**: `facing = victimLook · (toAttacker) > BlockMinFacing (0.1)` — hits from behind bypass block.
4. **Block branch** (victim blocking, facing, attack not `Unblockable`):
   - **Parry**: `t - blockStart <= victim.ParryWindow` → attacker stunned `ParryStun (1.1 s)`, victim posture −`ParryPostureRelief (25)`, `Parry` FX, return `parried` (no damage, no tag).
   - Otherwise posture += attack posture. If `opts.GuardBreak` or posture ≥ `MaxPosture` → posture reset to 0, victim stunned `GuardBreakStun (1.4 s)`, `GuardBreak` FX, result `guardbreak`, **full damage** continues.
   - Else damage × `(1 − BlockReduction)`, `Block` FX, result `blocked`.
5. **Buffs**: damage × `takenMult` while a `Taken` buff is active (Iron Bastion).
6. **Resistance**: damage × `(1 − min(MaxResist, Resist[type]))`, type = `Physical` or `Arc`.
7. `Humanoid:TakeDamage`, then `tag()` records attacker name/UserId/time on the victim and (PvP only) `LastCombat` on both.
8. **Hit stun & knockback**: if result ≠ `blocked` and the victim is not under hyperarmor (`max(hyperarmorUntil, swingArmorUntil)`): stun `opts.Stun or HitStunDefault (0.35)`, then knockback if `opts.Knockback > 0`.
9. `Hit` FX when result is `hit`. `Combat.Resolved` fires for every non-`none` result.

### Block and parry — `Combat.SetBlock` (531-546)
- Block starts only if `CanAct`, not already blocking and `t >= busyUntil` (no buffer). `blockStart` is stamped then; `Blocking` attribute replicates.
- Parry = a facing, blockable hit landing within `ParryWindow` of `blockStart`. Holding block past the window is a normal block.
- Block is dropped by Attack, Heavy, Dodge, skill use, Stun, and key release.
- Stamina does **not** regenerate while blocking (`Combat.lua:596`); blocking has no per-hit stamina cost — posture is the block resource.

### Posture and guard break
- Posture rises only on blocked hits (and via Black Flash guard break). `MaxPosture` is derived by `Gear` (base 80 + Willpower + armor).
- Regenerates at `PostureRegen` per second after `PostureRegenDelay (1.5 s)` without a posture hit (`Combat.lua:599-601`).
- Guard break: posture reset to 0, 1.4 s stun, and the breaking hit does full (unblocked) damage.

### Hit stun and swing-cancel tokens — `Combat.Stun` (237-262)
- Any stun bumps `token` (cancels the victim's in-flight swing), cancels the flick chain, clears busy, drops block, sets `WalkSpeed = 0` for the duration and restores it afterwards.
- A shorter stun never shortens a longer one (`endsAt <= s.stunned` returns early).

### Dodge — `Combat.Dodge` (548-567)
- Requires not stunned, `DodgeCooldown (0.9 s)` since last dodge, a non-zero flat direction, and `DodgeCost (18) × StaminaCostMult` stamina.
- Does **not** check `busyUntil`: a dodge cancels the player's own swing at any point (token bump).
- Grants i-frames for `Gear.DodgeIFrames`, drops block, busy 0.2 s, and tells the client to set its own velocity to `direction × DodgeSpeed (60)` (`DodgeMove`). Default direction when standing still is a backstep (`Main.client.lua:425`).

### Knockback — `knockback` (264-285)
- Flat direction from attacker to victim. A raycast of `magnitude × 0.3` studs ahead shrinks the push to the free distance (minus 2 studs) so nobody is launched through walls.
- Players apply the velocity on their own client (`Knockback` CombatEvent); NPCs get `AssemblyLinearVelocity` on the server.

### Hyperarmor
- Swing hyperarmor: `spec.Hyperarmor` covers windup + active (Sledge heavy, Shatter Strike). Buff hyperarmor: `Combat.AddBuff("Hyperarmor")` (Iron Bastion).
- Effect: no hit stun, no knockback, swing is not cancelled. Damage is still taken. **Guard break still stuns** (applied before the hyperarmor check).

### Heavy — `Combat.Heavy` (514-529)
- Requires `CanAct`, `HeavyCooldown (1.2 s)` since the last heavy, and the heavy's stamina. Resets combo to 0 and drops block.
- Posture damage × `CriticalPostureMult (1.75)`: heavies crush blocks.

### Feint — `Combat.Feint` (192-208)
- Allowed only while `t < windupUntil` and not stunned. Bumps token (cancels the swing), clears hyperarmor, busy for `FeintRecovery (0.18 s)`, refunds `lastCost × FeintRefund (0.6)` stamina, steps the combo back one (so the next light repeats the feinted step), fires `Feint` FX. The pending flick press is **kept**.

### Stamina / posture regen loop — `Combat.Init` (577-604)
Runs every ≥ 0.1 s for every tracked living character: expires flicker level and Zone; regenerates
stamina `StaminaRegenPerSecond (22) × dt` when not blocking and `StaminaRegenDelay (0.9 s)` has passed
since the last spend; regenerates posture when above 0 and past the delay.

### Kill credit — `tag` / `Combat.GetKiller` (215-234)
- Every damaging hit (including blocked and guard-break, not parried/dodged) stamps `LastAttackerName`, `LastAttackerUserId` (0 for NPCs) and `LastHitTime` on the victim.
- `GetKiller` returns the attacker if the last hit was within `KillCreditSeconds (15)`. Used by `Permadeath` (XP `50 + victimLevel × 25`, kill count, bounty quest) and `NPCs` (XP 35, kill quest).
- Combat-log: `LastCombat` is stamped only for PvP hits; leaving within `CombatLogSeconds (15)` of one is a death (`Lifecycle.lua:68`).

## Formulas

Variables marked **Gear** are computed in `Gear.compute` (`Gear.lua:44-100`) from profile stats and worn gear.

### F1 — Outgoing damage per hit
`hitDamage = spec.Damage × damageMult × DamageMult + arcBonus` (`Combat.lua:369-378`), where `DamageMult = 1 + Strength × DamagePerStrength` (`Gear.lua:93`).

| Variable | Type | Range | Lives in |
|---|---|---|---|
| `spec.Damage` | number | 6-44 | `Weapons.Defs[*].Attacks/Heavy` |
| `damageMult` | number | 1 (lights/heavies); skill power for strikes | `mods` |
| `Strength` | int | 0-50 | profile `Stats`, cap `Config.Stats.MaxPerStat` |
| `DamagePerStrength` | number | 0.03 | `Config.Stats` |
| `arcBonus` | number | 0, or 6 × power under Overload | `Skills.Defs.Overload.ArcBonus` |

Output: 6 × 1.0 = 6 (Fists, Strength 0) to 44 × 2.5 = 110 (Sledge heavy, Strength 50), before the Flicker multipliers (see `flicker.md`).
**Example**: Pipe Club step 3 (`Damage 18`), Strength 10 → `18 × (1 + 10 × 0.03) = 23.4`.

### F2 — Incoming damage after defence
`taken = hitDamage × (blocked ? 1 − BlockReduction : 1) × takenMult × (1 − min(MaxResist, Resist[type]))` (`Combat.lua:326-335`).
`BlockReduction = min(0.9, 0.7 + 0.02 × WeightScore)`; `Resist.Physical = min(0.75, Σ armor.Resist.Physical + Fortitude × 0.004)` (`Gear.lua:73-75, 91`).

| Variable | Type | Range | Lives in |
|---|---|---|---|
| `BlockReduction` base | number | 0.7 | `Config.Combat.BlockReduction` |
| `WeightScore` | int | 0-6 (3 slots × Heavy=2) | **Gear**, from `Armor.WeightScore` |
| `takenMult` | number | 0.25-1 (Iron Bastion: `max(0.25, 0.6 / power)`) | `SkillRunner.lua:68` |
| `Resist[type]` | number | 0-0.75 | **Gear**; `Armor.Pieces[*].Resist`, `Cybernetics.Pieces[*].Resist`, `Config.Stats.PhysicalResistPerFortitude`, cap `Config.Combat.MaxResist` |

Output: 0 (parried) to 100 % of F1.
**Example**: 23.4 incoming; victim Fortitude 5 wearing Riot Plate (`Physical 0.16`): resist = `0.16 + 5 × 0.004 = 0.18`. Unblocked: `23.4 × 0.82 = 19.19`. Blocked at weight 2: `23.4 × (1 − 0.74) × 0.82 = 4.99`.

### F3 — Posture damage and blocks-to-break
`postureHit = spec.Posture × postureMult × PostureDamageMult`, `PostureDamageMult = 1 + Strength × PostureDamagePerStrength` (`Combat.lua:370-374`, `Gear.lua:94`); heavies use `postureMult = CriticalPostureMult`.
`MaxPosture = BasePosture + Willpower × PosturePerWillpower + Σ armor.Posture` (`Gear.lua:88`).
Blocks before break = `ceil(MaxPosture / postureHit)` ignoring regen.

| Variable | Type | Range | Lives in |
|---|---|---|---|
| `spec.Posture` | number | 3-28 | `Weapons.Defs` |
| `CriticalPostureMult` | number | 1.75 | `Config.Combat` |
| `PostureDamagePerStrength` | number | 0.02 | `Config.Stats` |
| `BasePosture`, `PosturePerWillpower` | number | 80, 2 | `Config.Combat` |
| `armor.Posture` | number | 0-49 (Plated Helm 12 + Riot Plate 25 + Plated Greaves 12) | `Armor.Pieces` |

Output: MaxPosture 80 (naked, Willpower 0) to 229 (Willpower 50, full Plated).
**Example**: Pipe Club heavy (`Posture 14`), Strength 10: `14 × 1.75 × 1.2 = 29.4`. Defender Willpower 5 + Riot Plate: `80 + 10 + 25 = 115` → the 4th blocked heavy breaks guard (3 × 29.4 = 88.2 < 115 ≤ 117.6).

### F4 — Stamina cost of an action
`cost = base × StaminaCostMult`, `StaminaCostMult = 1 + 0.04 × WeightScore` (`Combat.lua:91`, `Gear.lua:90`). Default attack base = `floor(Damage × 0.6 + 2)` unless the weapon overrides `Stamina` (`Weapons.lua:15`).

| Variable | Type | Range | Lives in |
|---|---|---|---|
| `base` | number | attacks 5-30; dodge 18 | `Weapons.Defs`, `Config.Combat.DodgeCost` |
| `WeightScore` | int | 0-6 | **Gear** |
| `MaxStamina` | number | `100 + Willpower × 4` → 100-300 | `Config.Stats.BaseStamina/StaminaPerWillpower` |

Output: 5 (Fists light, weight 0) to 37.2 (Sledge heavy, weight 6).
**Example**: Sledge heavy `Stamina 30` at weight 6: `30 × 1.24 = 37.2`, i.e. 37 % of a Willpower-0 bar.

### F5 — Dodge i-frames
`DodgeIFrames = max(0.2, 0.35 − 0.012 × WeightScore + Agility × 0.002)` (`Gear.lua:92`).

| Variable | Type | Range | Lives in |
|---|---|---|---|
| base | number | 0.35 | `Config.Combat.DodgeIFrames` |
| `WeightScore` | int | 0-6 | **Gear** |
| `Agility` | int | 0-50 | profile `Stats` |

Output: 0.278 s (weight 6, Agility 0) to 0.45 s (weight 0, Agility 50). The 0.2 floor is never reached with current data.
**Example**: full Plated (6) with Agility 10: `0.35 − 0.072 + 0.02 = 0.298 s`.

### F6 — Parry window
`ParryWindow = Config.Combat.ParryWindow + Σ cyber.ParryBonus` (`Gear.lua:98`). Range 0.22-0.27 s (only Targeting Lens adds 0.05).
**Example**: Targeting Lens worn → `0.22 + 0.05 = 0.27 s`.

### F7 — Regeneration
Stamina: `+22 × dt` per tick after 0.9 s idle, not while blocking → a 100 bar refills in `0.9 + 100/22 ≈ 5.4 s`.
Posture: `PostureRegen = 10 × (1 + Willpower × 0.01)` per second after 1.5 s (`Gear.lua:89`).
**Example**: Willpower 10 → 11/s; 115 posture clears in `1.5 + 115/11 ≈ 12.0 s`.

### F8 — Wall-aware knockback
`travel = Knockback × 0.3`; if a wall is hit at distance `w`: `push = Knockback × clamp((w − 2) / travel, 0, 1)` (`Combat.lua:270-278`).
**Example**: Pipe Club step 3 `Knockback 35` → travel 10.5 studs; wall 6 studs away → `35 × (4 / 10.5) = 13.3 studs/s`.

### F9 — Charge gain per landed hit
`gain = (ChargePerHit + weapon.ChargeBonus) × ChargeGain × (overloaded ? 2 : 1)`, `ChargeGain = 1 + Σ gear.ChargeGain + Intelligence × 0.01` (`Combat.lua:417`, `Gear.lua:95`), capped at `MaxCharge = 100`.
**Example**: Shock Baton (`ChargeBonus 6`), Intelligence 10, no Conduit gear → `(8 + 6) × 1.1 = 15.4` charge; under Overload 30.8.

### F10 — Kill XP
NPC: `def.Xp` (Raider 35, `NPCs.lua:15`). Player: `50 + victimLevel × 25` (`Permadeath.lua:52`). Level-up threshold `100 × level` (`Stats.lua:33`).
**Example**: killing a level 4 player → 150 XP; a level 1 killer (needs 100) levels up with 50 to spare.

## Edge Cases

- **Guard break takes full damage**: when posture overflows, `amount` is not reduced by `BlockReduction` (`Combat.lua:320-329`). Intentional? `[confirm]`.
- **Hyperarmor does not stop guard-break stun**: `Combat.Stun(victim, GuardBreakStun)` runs before the hyperarmor check (322 vs 340). Iron Bastion while blocking can still be broken.
- **Dodge ignores busy**: a dodge cancels the dodger's own swing even during active frames; the only gate is the 0.9 s cooldown and stamina. Also allowed while busy from a skill.
- **Stun clears busy**: after a parry stun (1.1 s) the attacker can act instantly; the parry's advantage is exactly the stun, nothing more.
- **Parry on NPCs**: NPC hits via `Combat.Damage` can be parried; the Raider is stunned 1.1 s (`WalkSpeed 0`), but its attack loop does not check stun, so it keeps attacking on cooldown while frozen in place (`NPCs.lua:74-78`).
- **Blocked hits do not knock back or stun**, but still tag the victim for kill credit.
- **Hits from behind** (`dot ≤ 0.1`) ignore block and parry entirely.
- **Melee ignores walls**: `GetPartBoundsInRadius` has no occlusion check; a swing hits through thin cover. Ranged does respect geometry.
- **Point-blank arc exemption**: targets within 3.5 studs are hit regardless of facing, including directly behind.
- **Multi-target**: one swing can hit every model in range once; charge is granted per target.
- **Zero-direction knockback**: if attacker and victim overlap (`away.Magnitude ≤ 0.1`) direction is zero and the push is skipped.
- **Stale WalkSpeed restore**: `Stun` caches `baseSpeed` when stun begins and restores it; a `Stats.Apply` during the stun is overwritten by the cached value.
- **Prologue PvP**: player-vs-player damage returns `none` before Emergence; NPC-vs-player (the dummy) works.
- **Attack with insufficient stamina**: silently ignored; no FX, no busy, so a spamming client is only rate-limited by stamina.
- **Weapon swap mid-combo**: `comboWeapon ~= weapon` resets the chain to step 1.
- **Feint refund uses `lastCost`**, which is the last `SpendStamina` call — correct for lights/heavies/strikes; a feinted skill strike refunds 60 % of the skill's stamina.
- **Kill credit misattribution**: credit goes to whoever hit last within 15 s; a Raider hit after a player's hit sets `LastAttackerUserId = 0` and erases the player's credit.
- **Combat-log check is PvP-only**: a player leaving mid-fight with a Raider is not punished.
- **No remote rate limiting or ownership checks** beyond type checks: `Dodge` accepts any `Vector3` and the client applies its own velocity, so a modified client could set arbitrary velocity on `DodgeMove`/`Knockback` only for itself (server never trusts position for hits, which use the server-side root).

## Dependencies

- **Gear** (`Gear.OfChar`, `Gear.Get`): every derived number (`DamageMult`, `Resist`, `MaxPosture`, `ParryWindow`, `DodgeIFrames`, `StaminaCostMult`, `ChargeGain`, `FlickerRate`, `FlashBonus`). NPCs use `Gear.Default()`.
- **Weapons**: the `spec` tables (`weapons.md`).
- **WorldPhase.IsOpen**: PvP gate.
- **PlayerData**: equipped weapon id.
- **Remotes**: six input events, `CombatEvent` out.
- **Character attributes** written: `Stamina`, `MaxStamina`, `Posture`, `MaxPosture`, `Charge`, `MaxCharge`, `Blocking`, `Flicker`, `Zone`, `LastAttacker*`, `LastHitTime`; read by the client HUD and by `Tutorial`.
- **Dependents**: `SkillRunner` (Swing/Damage/buffs/i-frames), `NPCs`, `Tutorial` (`Combat.Resolved`, `Combat.Used`), `Permadeath` & `Lifecycle` (`GetKiller`, `InCombat`), `Arena` dummies.
- **Design docs**: `flicker.md` (chain judged inside `pulse`), `weapons.md`, `enemies.md`.

## Tuning Knobs

All in `Config.Combat` (`Config.lua:81-106`) unless noted: `FeintRecovery 0.18`, `FeintRefund 0.6`,
`CriticalPostureMult 1.75`, `ParryWindow 0.22`, `ParryStun 1.1`, `ParryPostureRelief 25`,
`GuardBreakStun 1.4`, `BlockReduction 0.7`, `BlockMinFacing 0.1`, `BasePosture 80`,
`PosturePerWillpower 2`, `PostureRegenPerSecond 10`, `PostureRegenDelay 1.5`, `HitStunDefault 0.35`,
`DodgeCost 18`, `DodgeCooldown 0.9`, `DodgeIFrames 0.35`, `DodgeSpeed 60`, `StaminaRegenPerSecond 22`,
`StaminaRegenDelay 0.9`, `ChargePerHit 8`, `MaxResist 0.75`, `HeavyCooldown 1.2`,
`KillCreditSeconds 15`. Hard-coded (not in Config): input buffer `0.08` (`Combat.lua:18`), point-blank
radius `3.5` (454), knockback travel factor `0.3` (270), wall margin `2` studs (276), dodge busy `0.2`
(563), weight coefficients `0.04 / 0.02 / 0.012 / 0.01` and Agility i-frame bonus `0.002`
(`Gear.lua:79-92`).

## Visual/Audio Requirements

Per the brief: weapon model in hand, Motor6D procedural swing with animation-ID slots, windup glow
(flick cue), hit sparks, hitstop, camera shake, and a sound slot per `CombatEvent` kind (`Swing`, `Hit`,
`Block`, `Parry`, `GuardBreak`, `Dodge`, `Dodged`, `Feint`, `Flick`, `BlackFlash`, `Bolt`, `Buff`,
`Burst`). Audio direction: short, punchy hits; bass-drop Black Flash.

## Acceptance Criteria

1. A light attack starting at `t0` cannot damage before `t0 + Windup` and cannot damage after `t0 + Windup + Active`; a second input is accepted no earlier than `t0 + End − 0.08`.
2. Pressing block ≤ `ParryWindow` before a facing, blockable hit produces result `parried`: zero damage, attacker stunned 1.1 s, defender posture −25.
3. Holding block longer than the window reduces damage by `BlockReduction` and adds the attack's posture; when posture reaches `MaxPosture` the defender is stunned 1.4 s and posture resets to 0.
4. A hit arriving with `victimLook · toAttacker ≤ 0.1` is neither blocked nor parried.
5. Dodge grants exactly `Gear.DodgeIFrames` seconds of `dodged` results, costs `18 × StaminaCostMult`, and cannot repeat within 0.9 s.
6. Hit stun on a non-hyperarmored victim cancels any swing that has not finished its active window and drops their block.
7. A hyperarmored victim (Sledge heavy windup/active, Shatter Strike, Iron Bastion) takes damage but is not stunned or knocked back.
8. Feint during windup refunds 60 % of the swing's stamina, makes the character busy 0.18 s, and the next light attack repeats the same combo step.
9. Stamina does not regenerate while blocking or within 0.9 s of a spend; posture does not regenerate within 1.5 s of a posture hit.
10. Knockback into a wall 6 studs away with magnitude 35 yields ≤ 13.4 studs/s.
11. `GetKiller` returns the last damaging attacker for 15 s and `nil` afterwards; parried and dodged attacks do not update it.
12. PvP `Combat.Damage` returns `none` while the phase is Prologue.
13. (Combat Feel epic) every `CombatEvent` kind, including `Swing` and `Dodged`, produces a visible and audible response on the client.

## Open Questions

- Should a guard break apply block reduction to the breaking hit, or is full damage the intended punishment?
- Should hyperarmor resist guard-break stun (Iron Bastion as a true "bastion")?
- Should melee hitboxes respect walls once the district has interiors?
- Should the Raider's stun interrupt its attack loop (resolved by Enemy v2, see `enemies.md`)?
- Latency compensation for the 0.22 s parry window: NOT ASSESSED — needs a networked playtest.
