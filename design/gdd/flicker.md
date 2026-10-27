# Flicker and Black Flash

> **Status**: Implemented (reverse-documented)
> **Author**: Claude (reverse-doc) — pending owner review
> **Last Updated**: 2026-10-25
> **Last Verified**: 2026-10-25 against `src/server/Combat.lua:124-188, 361-423, 586-594`, `src/shared/Config.lua:59-79`, `src/server/Gear.lua:95-97`, `src/shared/Cybernetics.lua`, `src/client/Main.client.lua:304-355`
> **Implements Pillar**: 3 — Skill-based combat; the brief names the Black Flash chain as "the skill ceiling"

## Summary

A rhythm layer on top of melee: tap the flick key (`E`) just before a swing connects and that hit is
boosted and starts a chain. Three consecutive flicked hits (two inside the Zone) land a **Black
Flash** — x2.5 damage, guard-breaking, long stun, charge refund — and put the attacker in the **Zone**
for 8 s. Flicks cost Charge, which is earned by landing hits; mis-timed flicks only waste charge.

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Key deps: `Combat (pulse/strike), Gear (FlickerRate, FlashBonus, ChargeGain), Cybernetics, Skills (Overclock, Overload)`

## Overview

The server never knows the player's intent beyond a timestamp. `Combat.Flicker` (`Combat.lua:148-164`)
records `flickPress = now` and spends charge. When the player's next swing first connects with any
target, `judgeFlick` (167-176) checks whether that press was recent enough; if so the hit is boosted,
the press is consumed, and the chain level advances on a successful (`hit`/`guardbreak`) result or
breaks on `dodged`/`parried` (`Combat.lua:401-415`). Chain level is replicated as the character
attribute `Flicker` and the Zone as `Zone`; the client draws both as a flickering black/red aura on
every character (`Main.client.lua:306-332`).

### Current Presentation
Press: 0.15 s red Highlight flash on the presser, visible to everyone (`fx("Flick", char)`,
`Combat.lua:163`). Chain advance: red flash on the **victim** (409). Aura: black fill / red outline
blinking at `6 + level × 8` Hz, solid in the Zone. HUD: text label "FLICKER xN" / "ZONE"
(`Main.client.lua:311`). Black Flash: red neon sphere growing 2 → 12 studs over 0.35 s at the victim,
plus a 0.4 s desaturated red colour-correction and a "BLACK FLASH" banner for attacker and victim
(`blackFlashFx`, 334-355). There is **no windup cue** telling the player when to press — the brief's
"windup glow flick cue" is the planned fix. The Loadout panel shows `Flick window xR` and
`Black Flash x(2.5 + FlashBonus)` (`Main.client.lua:213`).

## Player Fantasy

`[inferred — confirm]` The Cursed Gear / Jujutsu Kaisen "black flash": a perfectly timed strike that
distorts the world for a moment, earned by rhythm rather than stats, and the "high" of staying in the
Zone where the next one comes easier.

## Detailed Rules

### The press — `Combat.Flicker` (148-164)
1. Requires: character alive, not stunned, and `≥ Cooldown (0.3 s)` since the last press.
2. Cost `= Cost / FlickerRate` charge (F2). If the player cannot afford it the press is ignored (no timestamp, no FX).
3. Charge is deducted immediately, `flickPress = lastFlickPress = now`, `Flick` FX fires on the presser.
4. Pressing again before a swing connects simply moves the timestamp (and spends charge again).

### The judgement — `judgeFlick` (167-176), once per swing
- Runs at the **first target connection** of a swing (`seen.__flick == nil`, `Combat.lua:383`). Later targets in the same swing reuse the verdict.
- Valid if `now − flickPress ≤ Window × FlickerRate × (inZone ? ZoneWindowMult : 1)` (F1). The window is measured press → impact, so for a weapon whose windup is shorter than the window, pressing `E` and attacking together is a valid flick.
- On a valid press: `flickPress` is consumed (set to 0), `level = flickerLevel + 1`, `flash = level ≥ MaxLevel − (inZone ? 1 : 0)`.
- A swing that hits nobody never judges, so the press stays live until the window expires naturally.

### The boosted hit — `strike` (386-399)
| Verdict | Damage | Posture | Other |
|---|---|---|---|
| Chain link 1 | × `DamageMult[1]` = 1.25 | unchanged | — |
| Chain link 2 | × `DamageMult[2]` = 1.6 | unchanged | — |
| Black Flash | × `(BlackFlashMult + FlashBonus)` = 2.5 + implants | × `BlackFlashPosture` (2) | `GuardBreak = true`; `Stun = max(spec.Stun, 1.0)`; `Knockback = max(spec.Knockback, 55)` |

Multipliers apply after stat scaling and after any Overload `arcBonus` has been added (`Combat.lua:369-378`).

### Resolution (401-415)
- `hit` or `guardbreak` → chain advances: non-flash sets `flickerLevel = level`, `flickerUntil = now + ChainTime (3.5 s)`, `Flick` FX on the victim with the level. Flash → `blackFlash()`.
- `dodged` or `parried` → `CancelFlicker`: level 0, press cleared. "A whiffed flick: the chain is gone."
- `blocked` → **unresolved**: the boosted (then block-reduced) damage lands, the press was consumed, but the chain neither advances nor breaks. A later target in the same swing may still resolve it.
- A Black Flash against a blocker always resolves as `guardbreak` (GuardBreak flag), hence "blocking is not enough against a Flash".

### Black Flash — `blackFlash` (178-188)
Level → 0; `zoneUntil = now + ZoneTime (8 s)`; attribute `Zone = true`; charge `+FlashRefund (25)`;
`BlackFlash` FX (attacker, victim); `Combat.Used("BlackFlash")` for the tutorial.

### The Zone
- Flick window × `ZoneWindowMult (1.5)`.
- Flash needs one fewer link: `level ≥ 2` → a fresh chain flashes on its **second** flicked hit.
- Lasts 8 s from the Flash and is **not** cancelled by being stunned or by whiffing (`CancelFlicker` leaves `zoneUntil` alone). Cleared by the heartbeat loop when `now > zoneUntil` (`Combat.lua:592-594`). A second Flash inside the Zone restarts the 8 s.

### Chain decay and breaks
- Expires `ChainTime (3.5 s)` after the last chain hit (heartbeat loop, 589-591).
- Broken by: any `Combat.Stun` on the attacker (hit stun, guard break, parry stun — `Combat.lua:244`), or a flicked swing that is dodged or parried. **Not** broken by: blocked hits on the attacker's chain, hits absorbed under hyperarmor (no stun), feinting, or swings with no flick.
- Feint keeps the press alive (`Combat.lua:190-191`): press `E`, feint, re-swing inside the window is a legal mind-game.

### Priming — Overclock skill (`SkillRunner.lua:82-85`, `Skills.Defs.Overclock`)
`Combat.SetFlicker(char, 2, 8)`: sets the chain to level II for 8 s (or until broken). The next landed
flick is level 3 → Black Flash. Costs 20 charge, 20 s cooldown; needs Intelligence 8 and two `Cyber`
tags.

### Charge economy
- Pool: `Charge` attribute, `MaxCharge = 100` (`Config.Stats`), starts at 0 on every spawn (`Stats.Apply(fill)`), not persisted.
- Income: every `hit`/`guardbreak` → `(ChargePerHit 8 + weapon.ChargeBonus) × ChargeGain × (Overload ? 2 : 1)` (`combat.md` F9). Black Flash refund 25. Dev-arena Recharge consoles fill it; the tutorial tops it up to 40/20 during the Flicker step and 60 for Skills.
- Spend: flicks (F2), Surge 50, Overload 30, Overclock 20.

## Formulas

### F1 — Flick window
`window = Window × FlickerRate × (inZone ? ZoneWindowMult : 1)` (`Combat.lua:170`)

| Variable | Type | Range | Lives in |
|---|---|---|---|
| `Window` | seconds | 0.28 | `Config.Flicker.Window` |
| `FlickerRate` | number | 1.0-1.9 (F3) | `Gear.compute` |
| `ZoneWindowMult` | number | 1.5 | `Config.Flicker.ZoneWindowMult` |

Output: 0.28 s (rate 1, no Zone) to 0.798 s (rate 1.9, Zone).
**Example**: Intelligence 10, no implants → rate 1.1 → `0.28 × 1.1 = 0.308 s`; in the Zone `0.462 s`. Pipe Club windup is 0.16 s, so `E` + `LMB` together is inside the window; Sledge heavy (0.60 s windup) requires pressing during the windup.

### F2 — Flick cost
`cost = Cost / FlickerRate` (`Combat.lua:157`)

| Variable | Type | Range | Lives in |
|---|---|---|---|
| `Cost` | charge | 6 | `Config.Flicker.Cost` |
| `FlickerRate` | number | 1.0-1.9 | `Gear.compute` |

Output: 6.0 down to 3.16 charge per press.
**Example**: rate 1.1 → `6 / 1.1 = 5.45` charge.

### F3 — FlickerRate
`FlickerRate = 1 + Σ worn Cybernetics.FlickerRate + Intelligence × RatePerIntelligence` (`Gear.lua:96`)

| Variable | Type | Range | Lives in |
|---|---|---|---|
| `Cybernetics.FlickerRate` | number | Reflex Optic 0.15 (Eyes); Neural Core 0.25 or Overclock Core 0.15 (Core) → Σ 0-0.40 | `Cybernetics.Pieces` |
| `Intelligence` | int | 0-50 (effective, incl. armor bonuses) | profile `Stats` + `Armor.Pieces[*].Stats` |
| `RatePerIntelligence` | number | 0.01 | `Config.Flicker` |

Output: 1.0 to 1.9.
**Example**: Reflex Optic + Neural Core, Intelligence 20 → `1 + 0.40 + 0.20 = 1.6` → window 0.448 s, cost 3.75.

### F4 — Chain-link damage
`hitDamage = scaledDamage × DamageMult[level]` (`Combat.lua:397`), `scaledDamage` from `combat.md` F1.

| Variable | Type | Range | Lives in |
|---|---|---|---|
| `DamageMult` | array | {1.25, 1.6}; index 1..MaxLevel−1 | `Config.Flicker.DamageMult` |
| `level` | int | 1..MaxLevel−1 (non-flash) | `st(char).flickerLevel + 1` |

**Example**: Pipe Club step 1 at Strength 10 = 15.6 → link 1 `19.5`, link 2 (step 2, also 12 base) `24.96`.

### F5 — Black Flash hit
`damage = scaledDamage × (BlackFlashMult + FlashBonus)`; `posture = scaledPosture × BlackFlashPosture`; `stun = max(spec.Stun or 0, BlackFlashStun)`; `knockback = max(spec.Knockback or 0, BlackFlashKnockback)` (`Combat.lua:391-395`)

| Variable | Type | Range | Lives in |
|---|---|---|---|
| `BlackFlashMult` | number | 2.5 | `Config.Flicker` |
| `FlashBonus` | number | Σ Servo Arm 0.3 + Overclock Core 0.6 → 0-0.9 | `Cybernetics.Pieces`, summed in `Gear.lua:97` |
| `BlackFlashPosture` | number | 2 | `Config.Flicker` |
| `BlackFlashStun` | seconds | 1.0 | `Config.Flicker` |
| `BlackFlashKnockback` | studs/s | 55 | `Config.Flicker` |

Output: ×2.5 to ×3.4 damage; stun 1.0 s (no weapon exceeds it); knockback 55-60 (Sledge heavy keeps 60).
**Example**: Pipe Club step 3 at Strength 10 = `18 × 1.3 = 23.4` → Black Flash `58.5` damage, posture `10 × 1.2 × 2 = 24`, guard-breaking, 1.0 s stun, 55 studs/s. With Servo Arm: `23.4 × 2.8 = 65.5`.

### F6 — Links needed for a Flash
`linksNeeded = MaxLevel − (inZone ? 1 : 0) − primedLevel` (`Combat.lua:175`, `SetFlicker`)

| Variable | Type | Range | Lives in |
|---|---|---|---|
| `MaxLevel` | int | 3 | `Config.Flicker.MaxLevel` |
| `primedLevel` | int | 0, or 2 under Overclock | `Skills.Defs.Overclock.Level` |

Output: 3 (cold), 2 (Zone), 1 (Overclock), 1 (Overclock in Zone — still ≥ 1).
**Example**: Overclock then one flicked hit → Flash.

### F7 — Charge budget of a full cold chain
`net = FlashRefund + 3 × gainPerHit − 3 × cost`, `gainPerHit` from `combat.md` F9.

**Example**: Pipe Club (no ChargeBonus), Intelligence 10, no Conduit gear: gain `8 × 1.1 = 8.8`, cost 5.45 → `25 + 26.4 − 16.4 = +35` charge. A Flash chain is charge-positive; the only constraint is affording the **first** flick (≥ 5.45), which needs one prior landed hit from an empty bar.

## Edge Cases

- **Blocked flick is a dead press**: charge spent, press consumed, no chain change (`Combat.lua:401-415`, no `blocked` branch). Against a turtling opponent the attacker bleeds charge until a heavy or a Flash breaks guard.
- **Black Flash vs hyperarmor**: GuardBreak only triggers in the block branch; an unblocking hyperarmored target (Sledge windup, Iron Bastion) takes ×2.5 damage but is neither stunned nor knocked back (`Combat.lua:340`).
- **Zone persists through stun**: the attacker can be staggered, lose the chain, and still have the wider window and 2-link Flash for the rest of the 8 s.
- **Chain survives hits that don't stun**: being hit while blocking or under hyperarmor does not break the chain, contrary to the README's "taking a hit … breaks the chain" (only stunning hits do).
- **The press is public**: `Flick` FX is fired to all clients on the press, so an opponent sees a red flash on the attacker ~0.28 s before a flicked hit. `[confirm whether intended as a tell]`
- **Overclock then Zone**: level 2 primed, Zone active → `3 ≥ 2` flash on the next hit; no faster than Overclock alone.
- **Multi-target swings**: one verdict per swing; the first non-blocked target resolves it. A Flash on a crowd applies the ×2.5 to every target hit in that swing (`hitDamage` is computed per target from the shared `flick`).
- **Ranged flick**: the Arc Pistol's single raycast is judged the same way; window 0.28 vs windup 0.08 makes `E` + `RMB`/`LMB` trivial. `[balance — confirm]`
- **DamageMult length is coupled to MaxLevel**: raising `MaxLevel` to 4 without adding a third `DamageMult` entry indexes `nil` and errors at `Combat.lua:397`.
- **Charge resets on spawn** and is not saved; a fresh character cannot flick until it lands a hit.
- **Two presses within 0.3 s**: the second is ignored (cooldown), charge not spent.
- **Press while stunned**: ignored; press before a stun is cleared by `CancelFlicker` inside `Stun`.
- **Tutorial pays for flicks** (`Tutorial.lua:63-68`): the Flicker step tops charge to 40 on entry and keeps it ≥ 20, so the step cannot stall on an empty bar.
- **Chain timer vs combo**: `ChainTime 3.5 s` comfortably outlasts every weapon's `End + ComboReset` (max Sledge 1.40 + 0.9), so walking a full combo keeps the chain alive.

## Dependencies

- **Combat**: the press, judgement and boost live inside `Combat.lua`; `Stun` cancels the chain; `pulse/strike` applies it. Documented separately because it is its own tuning surface (`Config.Flicker`).
- **Gear**: `FlickerRate`, `FlashBonus`, `ChargeGain` (`Gear.lua:95-97`).
- **Cybernetics**: Reflex Optic, Neural Core, Overclock Core (FlickerRate); Servo Arm, Overclock Core (FlashBonus); Arc Gauntlet (ChargeGain 0.2).
- **Armor**: Arc-Lined Hood (ChargeGain 0.10), Conduit Harness (0.25), Intelligence bonuses.
- **Skills**: Overclock (prime), Overload (double charge income), Surge (charge sink).
- **Tutorial**: step 8 requires one Black Flash (`Combat.Used("BlackFlash")`).
- **Client**: aura, label, Black Flash FX; attributes `Flicker`, `Zone`, `Charge`, `MaxCharge`.

## Tuning Knobs

`Config.Flicker` (`Config.lua:64-79`): `MaxLevel 3`, `Window 0.28`, `Cooldown 0.3`, `Cost 6`,
`ChainTime 3.5`, `DamageMult {1.25, 1.6}`, `BlackFlashMult 2.5`, `BlackFlashPosture 2`,
`BlackFlashStun 1.0`, `BlackFlashKnockback 55`, `ZoneTime 8`, `ZoneWindowMult 1.5`, `FlashRefund 25`,
`RatePerIntelligence 0.01`. Related: `Config.Stats.MaxCharge 100`, `Config.Combat.ChargePerHit 8`,
per-weapon `ChargeBonus` (Shock Baton 6, Arc Pistol 3), implant `FlickerRate`/`FlashBonus`.
`docs/DESIGN.md` roadmap lists "Tune Flicker/Black Flash timing" as the first post-friend-test task.

## Visual/Audio Requirements

Brief: windup glow as the flick-timing cue; "bass-drop Black Flash" audio. Current effects are listed
under Current Presentation. The `Flick` FX on press and the `Flick(level)` FX on the victim should be
distinguishable once real effects exist.

## Acceptance Criteria

1. Pressing `E` with `≥ cost` charge deducts `6 / FlickerRate` and fires `Flick`; pressing within 0.3 s of the previous press does nothing.
2. A swing whose first connection occurs ≤ `0.28 × FlickerRate` s after the press (× 1.5 in the Zone) multiplies that swing's damage by 1.25 / 1.6 / (2.5 + FlashBonus) for chain levels 1 / 2 / Flash; a connection outside the window applies no multiplier and leaves the press unconsumed only if nothing was hit.
3. On the third consecutive flicked `hit`/`guardbreak` (second in the Zone, first after Overclock) the hit is guard-breaking, stuns ≥ 1.0 s, knocks back ≥ 55 studs/s, refunds 25 charge, sets `Zone` for 8 s and fires `BlackFlash`.
4. A flicked swing that is dodged or parried sets `Flicker` to 0; one that is blocked leaves it unchanged.
5. Any stun on the attacker sets `Flicker` to 0 but does not clear `Zone`.
6. `Flicker` returns to 0 if 3.5 s pass without a chain hit; `Zone` clears 8 s after the Flash.
7. The `Flicker` and `Zone` attributes replicate so every client can draw the aura on every character.
8. (Combat Feel epic) the attacker's windup shows a visible cue during the flick window.

## Open Questions

- Should a blocked flick break the chain, refund the press, or stay neutral as now?
- Is the public `Flick` flash on press a deliberate tell for the defender?
- Should the Arc Pistol be flickable at all, given its 0.08 s windup trivialises the timing?
- Should the Zone survive being stunned?
