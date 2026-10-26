# Momentum & Cancels — Nero study → Conduit's melee layer

> **Status**: Study + first implementation 2026-10-25 · **Owner ask**: "use the fluid movement Nero has for our base combat mechanics"
> **Method**: clean-room. Everything below is behaviour described from play and the public DMC frame-data
> community, re-expressed in Conduit's terms and numbers. No Capcom code, animation or asset is used.

## 1. What makes Nero feel fluid (the behaviours, not the moves)

| Nero behaviour | What it does for the player | Conduit mapping | Status |
|---|---|---|---|
| **Exceed** (rev the sword on-hit; perfect rev = MAX-Act) | A rhythm input layered on attacks; perfect timing is a reward you *earn mid-swing* | **Flicker / Black Flash** — identical idea, already core | Shipped (Phase 1) |
| **Jump-cancel / dash-cancel recovery** | You are never locked in an animation you regret; commit is a choice | **Dodge cancels any swing, including its recovery**, and keeps your combo alive | Implemented tonight |
| **Table Hopper** (side-dodge with i-frames, chains into itself) | Lateral evasion that rewards reading the attack | **Side dodges** get longer i-frames than back-steps; dodging *during* an enemy's active frames refunds stamina ("Hop") | Implemented tonight |
| **Snatch** (Devil Bringer pull) | Close the gap on *your* terms; the fight comes to you | **Snatch** skill (Kind `Pull`): yank the nearest target in a cone to arm's length and open them for a hit | Implemented tonight |
| **Buster** (grab finisher; big on staggered enemies) | A punish that *reads* the enemy state — payoff for landing the stagger | **Buster** skill (Kind `Grab`): on a stunned / guard-broken target it is a throw with heavy damage and posture reset; otherwise a shove | Implemented tonight |
| **High Roller / Calibur launch + air juggle** | Vertical space, enemy helpless | **Launcher**: heavies on a staggered enemy launch them; airborne enemies take bonus damage and cannot act | Planned (needs an airborne state in NPC AI) |
| **Enemy Step** | Reset off an enemy's body | Planned with Launcher |
| **Momentum carries** (dash → attack → dash without the combo dropping) | The combo is a *rhythm*, not a wall | **Combo persists through dodges and Snatch**; `ComboReset` timer restarts on each | Implemented tonight |
| **Weight by weapon** (Red Queen heavier than Blue Rose) | Different cadences per tool | Already data: `Weapons.Defs[*].Attacks` timings | Shipped |

What we deliberately do **not** copy: style meters, devil trigger, revving as a separate button spam. Conduit's
tension comes from permadeath and posture, not a grade.

## 2. Detailed rules (tonight's implementation)

### 2.1 Dodge-cancel and the Hop
- `Combat.Dodge` already cancels a swing that has not landed (`token++`) and may be pressed at any time
  outside hit-stun. New: it also clears `busyUntil` (recovery) so a landed swing can be dodge-cancelled.
- **Direction class**: `|dot(direction, look)| < 0.5` is a *side* dodge → i-frames × `Config.Momentum.SideIFrameMult`;
  otherwise back/forward → base `DodgeIFrames`.
- **Hop refund**: if the dodge's i-frames absorb a hit (`Combat.applyDamage` returns `dodged` while `iframes` from
  a dodge), refund `Config.Momentum.HopRefund` stamina and extend the combo window. The `Dodged` event already
  tells the client; the HUD word stays DODGED.
- Combo: `Dodge` and `Snatch` set `comboExpires = now + weapon.ComboReset` instead of letting it lapse.

### 2.2 Snatch (skill, Kind `Pull`)
- Req Agility 5, stamina 14, cooldown 6. Range 22, cone `Arc 0.75` (dot), picks the nearest Humanoid model.
- Effect: target root velocity toward the user so it lands ~3 studs away in `Config.Momentum.PullTime`; target
  stunned `PullStun` (0.6 s) — enough for one light; posture +8. No damage. Players can be snatched (PvP) unless
  in a safe zone (Combat refuses). Fires `CombatEvent("Snatch", user, target)`; client draws a beam (Impacts) and
  plays a sound slot.

### 2.3 Buster (skill, Kind `Grab`)
- Req Strength 6, stamina 22, cooldown 10. Range 7, front cone.
- If the target is **stunned** (`stunned > now`) or **posture-broken in the last 1.5 s**: damage 36, posture reset
  to 0, knockback 70, stun 1.0 ("throw"). Else: damage 8, knockback 35 ("shove"), no stun. Unblockable both ways.
- Fires `CombatEvent("Buster", user, { target, throw = bool })`; client flashes gold on a throw.

### 2.4 Numbers (in `Config.Momentum`, tunable)
```
SideIFrameMult = 1.3,  HopRefund = 10,  PullTime = 0.25,  PullStun = 0.6,  PullStop = 3,
GrabStunWindow = 1.5,  (skill numbers live in Skills.Defs)
```

## 3. Acceptance criteria
1. A dodge pressed during a landed swing's recovery moves the character and the next attack continues the combo
   (combo index does not reset to 1).
2. Side dodges have longer i-frames than back-steps (`Dodged` fires for a hit at 0.4 s on a side dodge, not on a back-step).
3. A dodge that absorbs a hit refunds stamina (stamina after > stamina before + cost − refund).
4. Snatch pulls a target in range to within `PullStop + 1` studs and stuns it `PullStun`.
5. Buster on a stunned target deals the throw damage and resets its posture; on a standing target only the shove.
6. All numbers are data; smoke covers 1–5.

## 4. Later
Launcher + airborne state (NPC AI "Juggled"), Enemy Step, per-weapon dodge-cancel windows if weight needs expressing.
