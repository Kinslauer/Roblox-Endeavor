# Gunplay — Tarkov study → the Range's shooting rules

> **Status**: Study + first implementation 2026-10-26 · **Owner ask**: "get some of the gunplay systems from Tarkov"
> **Method**: clean-room, like `momentum.md`. Behaviours described from play and public discussion, re-expressed in
> Conduit's terms and numbers. No BSG code, data or asset is used or needed — every system below is a rule plus a table.
> **Scope**: Universe 2 (the Range now, its own place later). Universe 1 keeps melee as the core; the Arc Pistol
> inherits the rules because it is a gun.

## 1. What makes Tarkov's shooting feel the way it does (behaviours, not content)

| Tarkov behaviour | What it does for the player | Conduit mapping | Status |
|---|---|---|---|
| **Hit zones** (head / thorax / stomach / limbs with their own HP) | Where you hit matters more than how often | **Zones**: damage × a multiplier by the body part the ray lands on; head ×2 and always staggers, limbs ×0.6–0.75 | Implemented |
| **Recoil that moves the camera**, with a per-weapon pattern you learn to pull against | Full-auto is a skill, not a hold | **Honest recoil**: the camera kicks per shot (client, `Weapons.Gun.Recoil`, optional `Pattern`), shots go along the camera, so the next round lands where the kicked view points | Implemented |
| **Ergonomics / sway** when aiming | Heavy guns wander; stamina matters | ADS sway already exists in `ViewModel`; a stamina-driven sway is a follow-up | Later |
| **Spread by stance** (moving, sprinting, jumping widen the cone; ADS tightens it) | Stop and aim, or miss | **Spread**: `Gun.Spread.Hip/ADS` + `Config.Gunplay.Spread.Moving/Sprinting/Airborne`; ADS only counts `ADSSettle` after raising the sights; sprinting drops the sights | Implemented |
| **Magazines and manual reloads** (no ammo counter without checking, reload takes real time) | Counting shots is part of the fight | **Magazines**: `Gun.Magazine` rounds per weapon, `Gun.Reload` seconds; the charged heavy burns 3 rounds; an empty click reloads for you; T reloads manually; a stun or dodge cancels the reload | Implemented (counter is shown — the no-counter rule is Universe-2-place material) |
| **Ammo types / penetration vs armour** | Loadout decisions | `Type = "Arc"` already meets `Resist.Arc` on armour; per-round types are a follow-up | Later |
| **Weapon ergonomics affecting ADS speed** | Build choices | `Presentation.ViewModel.BlendTime` is one number today; per-gun later | Later |
| **Lean / mount** | Cover play | Not for now | Out of scope |

What we deliberately do **not** copy: per-limb HP pools and blacking limbs (Conduit's health is one bar with armour
and posture on top), bleeding/healing minigames, weapon durability and jamming, the inventory-tetris. The Range is
"stop, aim, place the shot", not survival logistics.

## 2. Rules (implemented tonight)

### 2.1 Hit zones
- A ranged pulse raycasts along the (validated) look; the part it lands on names the zone. `Config.Gunplay.Zones[part]`
  (R15 names) multiplies the damage: Head 2.0, torso/root 1.0, upper arm/leg 0.7–0.75, hands/feet 0.6, `Default` 1.0.
- A headshot (`HeadshotStaggers`) always breaks poise and fires `Headshot` → "HEADSHOT" over the target, hit marker for
  the shooter. Zones apply to every ranged hit — a Gunner's shot on your head hurts too. Melee ignores zones.

### 2.2 Recoil (client, honest)
- Every own ranged `Swing` kicks the camera by `Gun.Recoil.Pitch` up and ±`Yaw`, delivered over 0.07 s as rotation
  deltas (Roblox's camera reads its CFrame back each frame), then recovered at `Recover` deg/s. Heavies kick ×2.2, ADS
  ×0.85. With a `Pattern` (list of `{pitch, yaw}`), consecutive shots (<0.6 s apart) walk the list — the Arc Rifle climbs
  and drifts right, then left.
- The kick lands in full within 0.07 s and only then starts to recover, so a single shot peaks at exactly its Pitch
  (offline sim: 1.0° kick → 1.000° peak → 0). The view *climbs* across a burst only when `Recover` is slower than the
  fire cadence (rifle: 0.45 s between shots → Recover 5 leaves ~0.1–0.3° per shot to pull against; a future full-auto
  gun wants Recover ≈ 2–3).
- Because Input sends the camera's LookVector and the server fires along it (inside `Config.Combat.AimCone`), recoil is
  not cosmetic: the kicked view is where the next shot goes. Pulling down against it is the skill; if you pull and the
  recovery also happens, you end up low — that is the trade-off, not a bug.

### 2.3 Spread (server)
- `spread = Gun.Spread.ADS` if ADS has been held ≥ `ADSSettle` (0.15 s) else `Gun.Spread.Hip`; + `Moving` (1.2°) when the
  Humanoid is moving, + `Sprinting` (3.0°) when sprinting (which also drops the sights), + `Airborne` (2.0°) in the air.
  The shot direction is rotated by a random angle inside that cone. NPC shots have no spread (they are tuned by windup).
- ADS is a claimed state (`Remotes.ADS`, rate-limited, `ADS` attribute) like block: it only buys the tighter spread after
  settling, and the aim cone validation still applies. Cheating ADS buys ~2° — not worth protecting further now.

### 2.4 Magazines and reloads
- `Gun.Magazine` rounds, tracked per weapon in `Combat.State(char).ammo`, mirrored to the `Ammo` / `MaxAmmo` attributes
  (HUD counter, bottom right; `RELOADING` while reloading, red at 0). A light shot spends 1 round, the charged heavy
  `Gun.HeavyRounds` (default 3). An empty magazine refuses the shot and starts the reload; T (`Config.Gunplay.ReloadKey`)
  reloads manually. `Gun.Reload` seconds busy; a stun or a dodge interrupts it (token bump) and it can be retried.
- Magazines refill by reload only; there is no ammo inventory yet (Universe-2 place: ammo as an item, like scrap).

### 2.5 Numbers
```
Config.Gunplay: Zones (above), HeadshotStaggers = true,
  Spread = { Moving 1.2, Sprinting 3.0, Airborne 2.0, ADSSettle 0.15 }, ReloadKey = T,
  DefaultGun = { Magazine 10, Reload 1.5, Spread { Hip 3, ADS 0.5 }, Recoil { Pitch 1.2, Yaw 0.4, Recover 7 } }
Weapons.ArcPistol.Gun: Magazine 9, Reload 1.3, Spread { Hip 2.4, ADS 0.5 }, Recoil { Pitch 1.6, Yaw 0.5, Recover 7 }
Weapons.ArcRifle.Gun:  Magazine 18, Reload 1.7, Spread { Hip 3.2, ADS 0.25 }, Recoil { Pitch 0.9, Yaw 0.3, Recover 5, Pattern (7 kicks) }
```

## 3. Acceptance criteria (smoke: 12 checks)
1. Ammo / MaxAmmo follow the equipped gun; a melee weapon clears them.
2. A shot spends one round; the charged heavy three.
3. Reload marks `Reloading`, blocks shots, and refills after `Gun.Reload`; an empty click starts one on its own.
4. `Remotes.ADS` sets the attribute; sprinting clears it.
5. The same shot on the Head does `Zones.Head` × the body damage and fires `Headshot`.
6. Five hip shots at the same aim do not all land on the same point.

## 4. Later
Stamina-driven ADS sway; per-gun ADS speed; ammo as inventory + ammo types vs armour; the no-counter "check magazine"
rule once the Range is its own place; leaning.
