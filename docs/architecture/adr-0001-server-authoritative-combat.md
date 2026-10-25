# ADR-0001: Server-Authoritative Combat

## Status

Accepted

> Reverse-documented 2026-10-25: the existing code in `src/server/Combat.lua` already embodies
> this decision, so it is recorded as `Accepted` rather than `Proposed`.

## Date

2026-10-25 (decision predates the record; inferred from code)

## Last Verified

2026-10-25

## Decision Makers

Project owner (solo developer); recorded by technical-director during reverse-documentation.

## Summary

Clients cannot be trusted with damage, cooldowns or hit detection in an always-on-PvP permadeath
game. The client sends only intent (`Attack`, `Heavy`, `Block`, `Dodge`, `Feint`, `Flicker`,
`UseSkill`) over RemoteEvents; the server owns all combat state, timing and damage, and
broadcasts `CombatEvent` purely so clients can render what happened.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Roblox (Luau), Rojo 7. Rojo syncs `src/server` -> `ServerScriptService.Server`, `src/shared` -> `ReplicatedStorage.Shared`, `src/client` -> `StarterPlayerScripts.Client` per `default.project.json`. |
| **Domain** | Networking / Core |
| **Layer** | Foundation |
| **Knowledge Risk** | LOW — RemoteEvent, attributes, `GetPartBoundsInRadius`, `Raycast` are long-stable APIs |
| **References Consulted** | `src/server/Combat.lua`, `src/shared/Remotes.lua`, `src/client/Main.client.lua`; `roblox-security` skill guidance |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | Multi-client playtest confirming a stunned/dodging client cannot land a hit; verify `Knockback`/`DodgeMove` velocities apply on the owning client (network ownership) |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0003 (module layout gives Combat its home and the shared `Remotes` registry) |
| **Enables** | ADR-0004 (presentation can be a pure consumer of `CombatEvent` only because the server already owns all state) |
| **Blocks** | None (already implemented) |
| **Ordering Note** | Rate limiting (TR-006) is an extension of this decision, not a prerequisite. |

## Context

### Problem Statement
Permadeath plus always-on PvP means a single exploited hit or cooldown bypass deletes a player's
character. Any trust placed in the client is a direct path to that outcome.

### Current State
Implemented. `Combat.lua` keeps a weak-keyed `state[char]` table (block, i-frames, stun, busy,
combo, flicker chain, cooldowns, buffs). All six combat remotes connect straight to validating
functions. Hit detection runs on the server (`GetPartBoundsInRadius` cone or `Raycast` for
`Ranged`). Damage resolution (`applyDamage`) decides `hit | blocked | parried | dodged |
guardbreak | none` and applies `Humanoid:TakeDamage`. The only thing the client does with
authority is set its own `HumanoidRootPart.AssemblyLinearVelocity` when told to
(`DodgeMove`, `Knockback`), because the client owns its character's physics.

### Constraints
- Roblox network ownership: the server cannot reliably apply impulses to a player-owned
  character, hence the two private `CombatEvent` kinds that hand a velocity to the owner.
- Server tick is `Heartbeat`; swing timing uses `task.delay` + `os.clock()`, so timing precision
  is one frame.
- NPCs share the same `Combat.Damage` path (`NPCs.lua`), so there is one rule set for all actors.

### Requirements
- Every damage, posture, stamina, charge and cooldown mutation happens in `src/server/`.
- Remote handlers reject malformed args before touching state.
- Clients receive enough information to render every outcome (`CombatEvent`, attributes).

## Decision

The server is the single authority for combat. Concretely:

1. **Intent in, events out.** Client -> server remotes carry at most a primitive (`boolean`,
   `Vector3`, slot `number`) and never a target, damage or timestamp. Server -> client is
   `CombatEvent(kind, a, b)` (broadcast via `Combat.FX`) plus replicated attributes.
2. **State lives in `Combat.State(char)`.** Cooldowns (`lastHeavy`, `lastDodge`,
   `lastFlickPress`, `skillCD`), windows (`iframes`, `stunned`, `busyUntil`, `windupUntil`),
   and the flicker chain are server-only. A `token` counter cancels in-flight swings on stun,
   dodge or feint.
3. **Hit detection is server-side** using the weapon spec's `Range`/`Arc` from
   `src/shared/Weapons.lua`.
4. **Resolution is a pure function of server state**: `applyDamage` reads victim `Gear`
   (`ParryWindow`, `BlockReduction`, `Resist`) and `Config.Combat`; the result is fired on
   `Combat.Resolved` for other systems.
5. **Presentation is advisory.** Clients may render `CombatEvent` however they like; nothing they
   render feeds back into state.

### Architecture Diagram
```
 Client (LocalScript)                     Server (ModuleScripts)
 ───────────────────                      ───────────────────────────────
 Input ─► Remotes.Attack:FireServer() ──► Combat.Attack(player)
                                          ├─ CanAct / SpendStamina / combo
                                          ├─ Combat.Swing ─► fx("Swing") ─────► CombatEvent (all clients)
                                          │     task.delay(Windup) ─► pulse ─► strike
                                          └─ Combat.Damage ─► applyDamage
                                                ├─ Humanoid:TakeDamage
                                                ├─ fx("Hit"|"Block"|...) ──────► CombatEvent (all clients)
                                                ├─ CombatEvent("Knockback") ──► victim only (velocity)
                                                └─ Combat.Resolved:Fire ───────► Tutorial, (future) Quests
 HUD bars ◄── attribute replication ◄──── SetAttribute(Stamina/Posture/Charge/Flicker/Zone)
```

### Key Interfaces
- `Remotes.<Attack|Heavy|Feint|Flicker>:FireServer()`; `Remotes.Block:FireServer(down: boolean)`;
  `Remotes.Dodge:FireServer(direction: Vector3)`; `Remotes.UseSkill:FireServer(slot: number)`.
- `Remotes.CombatEvent.OnClientEvent(kind: string, a: any, b: any)`.
- `Combat.Damage(attacker, victim, amount, opts) -> result`; `Combat.Resolved(attacker, victim, result)`;
  `Combat.Used(name, player)`; `Combat.FX(kind, char, extra)`.

### Implementation Guidelines
- A remote handler **must** validate every argument's type before use and **must** return
  silently on bad input (never error, never kick — see TR-005).
- Client code **must never** call `TakeDamage`, set `Health`, or write any combat attribute.
- New combat outcomes **must** be exposed as a new `CombatEvent` kind (and documented in
  `architecture.md`) rather than a new remote.
- The client **may** set its own root velocity only in response to `DodgeMove` / `Knockback`.
- Remote handlers **should** be rate-limited per player (TR-006, not yet met).

## Alternatives Considered

### Alternative 1: Client-side hit detection with server validation
- **Description**: Client reports "I hit X"; server sanity-checks distance and timing.
- **Pros**: Hits feel instant on the attacker's screen; less server CPU.
- **Cons**: Trivially spoofable target/timing; sanity checks are leaky in a timing game with
  0.22 s parry and 0.28 s flick windows.
- **Estimated Effort**: Similar.
- **Rejection Reason**: Permadeath makes any exploitable hit unacceptable.

### Alternative 2: Server authority with client-side prediction
- **Description**: Server authoritative as now, but the client plays the swing immediately and
  reconciles on server reply.
- **Pros**: Hides latency.
- **Cons**: Two copies of the frame-data logic; reconciliation of cancelled swings (stun/feint)
  is fiddly; roll-back of a Black Flash feels bad.
- **Estimated Effort**: High.
- **Rejection Reason**: Deferred. The current `Swing` broadcast-then-windup design already gives
  the client the windup duration to animate in, so prediction is not needed for feel.

## Consequences

### Positive
- One rule set for players and NPCs (`NPCs.lua` calls `Combat.Damage`).
- Exploits are limited to input spam, which is a rate-limit problem, not a trust problem.
- `Combat.Resolved` / `Combat.Used` make the tutorial and quests pure observers.
- The headless smoke harness can drive the whole fight through remotes with no client code.

### Negative
- Every input has one round-trip of latency before anything visible happens
  (mitigated by the fact that `Swing` is sent at swing start, before the windup).
- The server runs `GetPartBoundsInRadius` every Heartbeat for the `Active` window of every swing.
- `Knockback`/`DodgeMove` depend on the client honouring the velocity; a modified client can
  ignore knockback (cosmetic exploit, not a damage exploit).

### Neutral
- Attributes double as a replication channel; the HUD never needs a "StateChanged" remote.

## Risks
- **Input flooding** — unbounded `OnServerEvent` calls. Mitigation: TR-006 rate limiter.
- **Timing drift** — `os.clock()` vs `task.delay` jitter could make the parry window feel
  inconsistent under load. Mitigation: measure in a 10-player playtest; consider timestamping
  swings on the server and judging windows against the recorded swing start.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| combat.md | Timing-based melee: windup/active/end, parry window, i-frame dodge, posture, guard break | All judged on the server from `Weapons` frame data and `Config.Combat` |
| flicker.md | Flick window judged against impact; chain breaks on parry/dodge; Black Flash x2.5 + Zone | `judgeFlick`, `blackFlash`, `CancelFlicker` are server-only |
| permadeath.md | A death must be legitimate; killer credit | Damage and `tag()` kill attribution happen only on the server |
| enemies.md | NPCs fight with the same rules as players | `NPCs.lua` uses `Combat.Damage` |

## Performance Implications
- **CPU**: One spatial query per Heartbeat per active swing; a 10 Hz regen loop over all tracked characters.
- **Memory**: One small state table per character, weak-keyed so it is collected with the model.
- **Load Time**: None.
- **Network**: One `FireAllClients` per Swing and per outcome; small payloads (string + Instance ref + scalar).

## Migration Plan
None — already implemented. **Rollback plan**: not applicable.

## Validation Criteria
- Smoke scenario `PvP hit lands in the open world` and `black flash landed` pass.
- A client script that fires `Attack` with extra args or fires `Dodge` with a non-Vector3 causes no server error and no state change.
- A client that never handles `CombatEvent` still takes correct damage.

## Related
- ADR-0003 (module layout), ADR-0004 (presentation consumes `CombatEvent`)
- `docs/architecture/architecture.md` §Remote Contract, §Data Flow
- `src/server/Combat.lua`, `src/shared/Remotes.lua`
