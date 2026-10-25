# ADR-0004: Presentation Layer and Asset Slots

## Status

Proposed

> Who may move this to `Accepted`: the user, or `technical-director` on the user's explicit
> confirmation. Stories referencing a `Proposed` ADR are `Blocked`; the "Combat Feel" epic
> requires this ADR to be `Accepted` before its stories start.

## Date

2026-10-25

## Last Verified

2026-10-25

## Decision Makers

Proposed by technical-director / lead-programmer for the "Combat Feel" epic; awaiting project
owner confirmation.

## Summary

Combat is fully simulated on the server but almost invisible on the client: `CombatEvent "Swing"`
is ignored, VFX are 0.15 s highlights inside a 438-line `Main.client.lua`, and there is no
animation or audio pipeline. This ADR puts presentation in client modules under `src/client/`
driven only by `CombatEvent` and attribute changes, ships procedural placeholders first, and
gives every placeholder a data slot in a new `src/shared/Presentation.lua` so real assets drop
in without code changes; windup telegraphs are derived from the same `Weapons` frame data the
server uses.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Roblox (Luau), Rojo 7. New ModuleScripts under `src/client/` sync to `StarterPlayerScripts.Client`; `src/shared/Presentation.lua` syncs to `ReplicatedStorage.Shared.Presentation` and is readable by the client (and by the server for validation). |
| **Domain** | Animation / Audio / Rendering (Presentation) |
| **Layer** | Presentation |
| **Knowledge Risk** | LOW–MEDIUM. `Motor6D` CFrame tweening, `Animator:LoadAnimation`, `Sound`, `ParticleEmitter`, `TweenService` are stable. Medium only because R15/R6 rig differences affect which `Motor6D`s exist. |
| **References Consulted** | `src/client/Main.client.lua`, `src/server/Combat.lua` (`Swing` broadcast timing), `src/shared/Weapons.lua`, `design/game-brief.md` §MVP 1 and §Build order 1; `roblox-ui` skill guidance on TweenService / juice |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | Motor6D tween on an R15 rig does not fight the default `Animate` script; a `Swing` received at time t with `Windup = w` has its telegraph peak land within one frame of the server's hitbox opening; `Sound` with an empty `SoundId` is silent without warnings |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (server owns all state; presentation is a pure consumer), ADR-0002 (frame data and asset slots live in shared data), ADR-0003 (client folder is a module tree) |
| **Enables** | Future ADR for an enemy rig/animation pipeline (Enemy v2); HUD v2 modules reuse the same event-driven pattern |
| **Blocks** | Epic "Combat Feel" and every story in it |
| **Ordering Note** | `Presentation.lua` schema must be fixed before the first placeholder module, or slots will be retrofitted. |

## Context

### Problem Statement
`design/game-brief.md` MVP item 1: "Combat you can see: weapon in hand, a windup you can read
(with the flick-timing cue), a swing, hit sparks, hitstop and sound slots for every CombatEvent."
Today the server fires `CombatEvent("Swing", char, label)` at the start of every swing, before
the windup, so the client has exactly `Windup` seconds of warning — but the client discards it
(`-- TODO: kind == "Swing"`). Parry (0.22 s) and flick (0.28 s) windows are unreadable.

### Current State
- All presentation is in `Main.client.lua`: `FLASH` colour table -> `Highlight`, `blackFlashFx`
  (neon sphere, ColorCorrection, banner), `Bolt` beam, flicker aura from attributes.
- No `Animator`/`AnimationTrack`, no `Sound`, no asset IDs anywhere in `src/`.
- Hand-built art is explicitly out of scope: "Code ships with procedural placeholders and ID
  slots for them."
- The client already mutates one piece of state correctly (own root velocity on
  `DodgeMove`/`Knockback`); nothing else may be mutated.
- Known client defect: `"Dodged"` kind unhandled; `2.5` literal for the Black Flash multiplier.

### Constraints
- Presentation must never change gameplay outcome (TR-003); a client with no presentation
  modules must still be a valid client.
- The telegraph must match the server: the server opens the hitbox at `swingStart + spec.Windup`
  and judges parry against `blockStart` and flick against `flickPress`, both server clocks.
  The client knows only when `Swing` arrived; latency shifts the telegraph late by one-way
  trip. Acceptable for v1; the slot schema leaves room for a server timestamp later.
- Rigs are default R15 players and procedural NPC rigs (`NPCs.BuildRig`); the placeholder swing
  must degrade gracefully when a named `Motor6D` is missing.
- `StreamingEnabled = false` for now, so `char` Instance references in `CombatEvent` always
  resolve on the client.

### Requirements
- Every `CombatEvent` kind (including `Swing`, `Dodged`) has a visible and an audible slot.
- Windup telegraph duration = `Weapons.Defs[weapon].Attacks[combo].Windup` (or `.Heavy.Windup`),
  read from the same shared module the server uses.
- Replacing a placeholder with a real asset is a data edit in `Presentation.lua`, not a code edit.
- `Main.client.lua` shrinks to input + module wiring; HUD and VFX move to modules.

## Decision

1. **Presentation modules under `src/client/`**, each a ModuleScript with `Init()` wired from
   `Main.client.lua` (mirroring the server composition-root pattern):
   - `CombatFX.lua` — subscribes to `Remotes.CombatEvent`; dispatches by `kind` to handlers;
     owns hit sparks, parry flash, Black Flash, Bolt, hitstop, camera shake.
   - `WeaponView.lua` — builds/attaches the held weapon model per `LoadoutChanged.Weapon`;
     procedural part-built placeholder, or clones `ReplicatedStorage.Assets.Weapons[modelName]`
     when the slot names one.
   - `SwingAnimator.lua` — on `Swing(char, label)`: resolves the weapon and spec, plays the
     windup telegraph for `spec.Windup` seconds (Motor6D tween of the right arm + weapon glow
     ramp), then the swing for `spec.Active`, then recovery to `spec.End`. If the slot has an
     `AnimationId`, loads and plays that track instead of the tween.
   - `FlickerAura.lua` — moves the existing attribute-driven aura out of `Main.client.lua`.
   - `Hud.lua` (bars, panels, hotbar) — moved, not redesigned (HUD v2 is a later epic).
   - `Audio.lua` — one `Sound` per `Presentation.Sounds[kind]` slot, parented to the emitting
     character's root; silent when the slot is `""`.
2. **`src/shared/Presentation.lua` — the asset-slot registry.** Every placeholder has a named
   slot; empty string / nil means "use the procedural placeholder".
3. **Telegraph timing derived from server frame data.** `SwingAnimator` reads
   `Weapons.Defs[weaponId]` and uses `Windup`, `Active`, `End` directly. It must never carry its
   own durations. The flick cue (glow peak) is placed at `Windup - Config.Flicker.Window` so the
   player learns to press as the glow saturates.
4. **Presentation never mutates game state.** Allowed writes: own root velocity on
   `DodgeMove`/`Knockback` (existing), cosmetic instances it creates (parented under the
   character or `workspace.FX`), camera CFrame offsets, `Lighting` effects it owns and removes.
   Forbidden: `Humanoid` properties, attributes, anything under another player's character
   except transient `Highlight`/`Attachment`/`ParticleEmitter` children it also destroys.
5. **Procedural first.** Part-built weapons, Motor6D-tweened swings, code-made sparks
   (`ParticleEmitter` bursts or tweened neon parts), `ColorCorrection` hitstop, camera shake —
   all shipped before any asset exists, so the loop is playable and the slots are proven.

### Architecture Diagram
```
 Server                                   Client
 Combat.Swing ──CombatEvent("Swing",char,label)──► CombatFX.dispatch
 Combat.Damage ─CombatEvent("Hit"|"Parry"|...)───►   ├─ SwingAnimator.play(char,label)
 SetAttribute(Flicker/Zone) ──replication─────────►   │     ├─ Weapons.Defs[id] (Windup/Active/End)
                                                      │     └─ Presentation.Swings[family][label]
                                                      ├─ Audio.play(kind, char)  ← Presentation.Sounds[kind]
                                                      ├─ Sparks / hitstop / shake ← Presentation.Impacts[kind]
 Gear.Push ──LoadoutChanged{Weapon}──────────────► WeaponView.equip(char, weaponId) ← Presentation.Weapons[id]
                                                   FlickerAura (attribute-driven, unchanged)
```

### Key Interfaces
```lua
-- src/shared/Presentation.lua (schema; all IDs are "" until the owner fills them in Studio)
Presentation.Weapons[weaponId]      = { ModelName = "",  Grip = CFrame?, Scale = number? }
Presentation.Swings[family][label]  = { AnimationId = "", TelegraphColor = Color3?, TrailColor = Color3? }
    -- label: 1..n (combo index), "Heavy", or skill id; family from Weapons.Defs[id].Family
Presentation.Sounds[kind]           = { SoundId = "", Volume = number?, PitchJitter = number? }
    -- kind: every CombatEvent kind incl. "Swing", "Dodged", plus "BlackFlashBass"
Presentation.Impacts[kind]          = { HitstopSeconds = number, ShakeMagnitude = number, SparkColor = Color3 }
Presentation.Telegraph              = { GlowRamp = "Quad", MinVisibleSeconds = 0.08 }
```
Client module contract: `Module.Init(deps)`; `CombatFX.Register(kind, handler)` so new kinds are
added by registration, not by editing a dispatch table.

### Implementation Guidelines
- Presentation modules **must** subscribe only to `Remotes.CombatEvent`, `Remotes.LoadoutChanged`
  and attribute-changed signals; they **must never** fire a remote except the existing input
  intents in `Main.client.lua`.
- Durations shown to the player **must** come from `Weapons.Defs` / `Config`; a literal second
  value in a presentation module is a defect (TR-004).
- Every placeholder **must** have a slot in `Presentation.lua` and **must** check it first
  (`if slot.AnimationId ~= "" then load else procedural`) (TR-007).
- Handlers **must** tolerate a missing or streamed-out `char` (`typeof(char) ~= "Instance"`,
  no `HumanoidRootPart`) by returning silently.
- Transient instances **must** be cleaned with `Debris` or a tracked `Destroy`; no per-swing leaks.
- `"Dodged"` **must** get a handler (the current silent gap).
- The `2.5` literal in the loadout panel **must** be replaced by `Config.Flicker.BlackFlashMult`
  when `Hud.lua` is extracted.

## Alternatives Considered

### Alternative 1: Keep everything in `Main.client.lua`, add handlers inline
- **Description**: Extend the `CombatEvent` `if/elseif` chain with swing tweens and sounds.
- **Pros**: No restructuring.
- **Cons**: File already 438 lines; every asset becomes a hardcoded ID in logic; untestable.
- **Estimated Effort**: Lowest.
- **Rejection Reason**: Fails the brief's "ID slots" requirement and makes HUD v2 harder.

### Alternative 2: Server-driven animation (server loads `AnimationTrack`s on the Humanoid)
- **Description**: Server plays the swing animation; Roblox replicates it.
- **Pros**: One source of timing; no `Swing` handling on the client.
- **Cons**: Server pays for every animation load; no hitstop/shake/audio (client-only effects)
  without a client module anyway; couples authority code to asset IDs.
- **Estimated Effort**: Moderate.
- **Rejection Reason**: Half the feel work still needs client modules; keep the server data-only.

### Alternative 3: Wait for real assets before building presentation
- **Description**: Build nothing procedural; author animations and sounds first.
- **Pros**: No throwaway work.
- **Cons**: Blocks the combat-feel proof on art; the brief says art is the owner's job in Studio.
- **Estimated Effort**: Unknown, external.
- **Rejection Reason**: Build order item 1 is "risky and core-fun; prove it first."

## Consequences

### Positive
- Parry and flick windows become readable; the tutorial's "telegraphs its strikes" promise is
  kept for players too.
- Asset swap is a data edit; `Presentation.lua` doubles as the asset request list for the owner.
- `Main.client.lua` becomes input + wiring, matching the server's composition-root shape.

### Negative
- One more shared module to keep in sync with `Weapons.Defs` (every family/label needs a slot
  or a fallback).
- Telegraph is late by one-way latency; a later server-timestamp field may be needed.
- Motor6D tweening on R15 may conflict with the default `Animate` script and need the arm's
  animation weight lowered.

### Neutral
- `WorldPhase.Changed` and `PhaseChanged` cinematic can move into the same module pattern later.

## Risks
- **Telegraph/hitbox mismatch** under latency or frame drops. Mitigation: TR-004 derives from
  shared data; add a debug overlay showing server `Swing` arrival vs client glow peak; consider
  a server timestamp in `Swing` later.
- **Instance leaks** from per-swing sparks. Mitigation: `Debris` on every transient; profile
  with the `roblox-performance` checklist.
- **Rig variance** (procedural NPC rigs lack Motor6Ds). Mitigation: `SwingAnimator` falls back
  to a weapon-only tween when the arm joint is missing.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| combat.md | Attacks have readable windup; parry window is learnable | `SwingAnimator` telegraph length = server `Windup`; glow cue placed relative to `Config.Combat.ParryWindow` / `Config.Flicker.Window` |
| flicker.md | Flick-timing cue (windup glow) and a distinct Black Flash moment | Glow ramp peaks at `Windup - Flicker.Window`; `BlackFlash` kind gets sphere + hitstop + bass sound slot |
| weapons.md | Weapon in hand; moveset is visible | `WeaponView` per `Weapon` family; per-label swing slots |
| enemies.md | Telegraphed attacks you can parry or dodge | Same `Swing` path for NPCs since `Combat.Swing` is shared |
| hud.md | Hit markers, damage numbers, dodge feedback | `CombatFX` handles `Dodged`; damage numbers hook `Hit` (HUD v2 scope) |

## Performance Implications
- **CPU**: A few tweens per swing per visible character; ~10 characters in view is trivial.
- **Memory**: Transient parts/particles bounded by `Debris` lifetimes (< 0.5 s each).
- **Load Time**: `Animator:LoadAnimation` on first use per slot; preload via `ContentProvider` optional.
- **Network**: None — no new remotes; uses existing `CombatEvent` and attributes.

## Migration Plan
1. Add `src/shared/Presentation.lua` with the schema above and empty slots for every weapon family, label and `CombatEvent` kind.
2. Create `src/client/CombatFX.lua`; move the `FLASH`, `blackFlashFx`, `Bolt` and `DodgeMove`/`Knockback` handling into it unchanged; add `Dodged`.
3. Create `SwingAnimator.lua` + `WeaponView.lua` with procedural placeholders; wire `Swing`.
4. Create `Audio.lua` with empty-slot silence.
5. Move HUD and aura into `Hud.lua` / `FlickerAura.lua`; fix the `2.5` literal.
6. `Main.client.lua` becomes input mapping + `Init()` calls.

**Rollback plan**: each step is additive; reverting a module's `Init()` call in `Main.client.lua`
restores the previous behaviour.

## Validation Criteria
- Retained screenshot/video in `production/qa/evidence/`: a PipeClub heavy shows a 0.30 s
  glow ramp before contact; parry succeeds when pressed during the last ~0.22 s of the glow.
- `grep -n "[0-9]\.[0-9]" src/client/SwingAnimator.lua` returns no duration literals.
- Setting `Presentation.Swings.Blunt.Heavy.AnimationId` to a valid ID plays the track with no code change.
- Smoke harness still passes (client tree loads; presentation modules tolerate the mock).

## Related
- ADR-0001, ADR-0002, ADR-0003
- `docs/architecture/architecture.md` §Known Gaps (Swing TODO, Dodged, 2.5 literal, no animation/audio pipeline)
- `design/game-brief.md` §MVP item 1, §Build order item 1
- `src/client/Main.client.lua`, `src/server/Combat.lua` (`Combat.Swing`, `Combat.FX`), `src/shared/Weapons.lua`
