# Range evidence — stories 001–003

**Date**: 2026-10-25 · **Build**: `claude/combat-feel` (this commit) · **Studio**: `Conduit.rbxlx`, all pushes byte-exact
**Method**: Studio MCP; Play; creator + tutorial skip from the Client datamodel; travel, melee refusal, waves through server
bridge Scripts (they share the game's module cache); ADS through a runtime LocalScript requiring the game's `Aim`.

| AC | Result | Notes |
|---|---|---|
| 1. First-person toggle | PASS (forced path) | `ForceFirstPerson` → `CameraMode=LockFirstPerson`, FOV **75**, view model present with parts `Handle, …, RearSight×2, FrontSight, FrontDot, Hand, Forearm, Sleeve`; hip sight at `(0.65, −0.55, −1.40)`; after leaving: `Classic`, FOV 70, view model gone. The `C` key path is the same function; owner to press it |
| 2. Unlock gate | smoke | `Range.Unlocked` (Dev bypass on in this place); message path by construction |
| 3. Enter | PASS | `entered=true zone=Range ffp=true weapon=ArcRifle pos=(1400, 5, 78)` |
| Sight picture (rifle) | **PASS (exact)** | ADS: FOV 42, `Sight` rel camera `(0.00, −0.00, −0.90)`, lookDot `1.000`, **front post top `(0.000, −0.000, −3.80)`**, reticle hidden |
| 4. Ranged-only | PASS | Club: `Combat.Attack` left no windup (`false`); rifle: swing started (`true`) |
| 5. Targets | PASS | 3 aimed shots: Target 20 hp 40 → 0, pivot moved 1.8 studs (fell), `RangeScore = 20`, announce "Target down at 20 studs (+20, score 20)" |
| 6. Waves | PASS | `StartWave` → `started=true gunners=2 inArena=2`; second start while running → `false` |
| 7. Leave | PASS | `zone=nil ffp=nil pos=(0, 5.5, 28)`; client `Classic`, FOV 70 |
| 8. Smoke | PASS | 54/54 (8 new Range checks; mock `Raycast` now hits HumanoidRootParts so hitscan connects) |

**Sign-off**: pending owner playtest (story 004).
