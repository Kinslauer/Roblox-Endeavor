# Epic: Aiming + Fair Arrival

> **Status**: Implemented (owner playtest pending) · **Brief**: build-order items 2 and 5 · **Rigor**: standard
> ADRs: ADR-0001 (server owns protection and limits), ADR-0002 (all numbers in Config/Presentation)

## Stories
| # | Story | Type | Status | Evidence |
|---|---|---|---|---|
| 001 | Combat stance (`client/Aim.lua`): body faces camera yaw, shoulder camera, locked cursor, toggle key | Visual/Feel | Implemented | Live: body re-aligned to camera (dot 1.00) with `CameraRelative` + offset applied; mouse lock NOT ASSESSED (Studio was not rendering) |
| 002 | Spawn protection (`Combat.Protect`, ForceField, `Config.SpawnProtectionSeconds`), applied on open-world spawn and at Emergence; forfeited by Attack/Heavy/Skill | Logic | Implemented | Live: present ~0.5 s after arrival, gone after one attack; smoke: "fresh character cannot be hit", "attacking forfeits spawn protection" |
| 003 | Remote rate limits (`server/RateLimit.lua`, `Config.RateLimit`), every client→server remote wrapped | Logic | Implemented | Smoke: 40-call burst capped at 12 (6/s × burst 2); all 15 handlers wrapped |
| 004 | Supply drops land on `PlayableArea` ground near the player; announce text no longer names a place that does not exist | Config/Data | Implemented | Code path shares `NPCs.FindGround`; live NOT ASSESSED (events fire every 60–150 s) |
| 005 | Player list hidden (Tab conflict; prologue feels solo); Config comment fix (loot key is X) | UI | Implemented | `GetCoreGuiEnabled(PlayerList) == false` observed |

## Notes
- TR-006 (rate limits) moves from `not-met` to `met` in `docs/architecture/tr-registry.yaml`.
- Smoke harness is now deterministic (`math.randomseed` in the mock prelude): 35/35.
- `tools/studio_patch.py` emits minimal exact-string hunks (git base → working tree) as one Luau program for the Studio MCP; used for this push (33/33 hunks applied).
