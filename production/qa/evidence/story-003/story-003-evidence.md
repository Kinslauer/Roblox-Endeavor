# Story 003 evidence — Impact feedback

**Date**: 2026-10-25 · **Build**: branch `claude/combat-feel`, Studio place `Conduit.rbxlx`
**Method**: Studio MCP. Scripts pushed into the place; Play; Pipe Club combo fired at an arena dummy from the Client datamodel while sampling camera FOV and `workspace.FX`; every handler then invoked once directly with real characters; screenshot staged (effects held) because capture latency exceeds the 0.3 s effect life.

| AC | Result | Notes |
|---|---|---|
| 1. `Hit`: sparks at the victim's torso, red flash, hitstop + shake for the local attacker/victim | PASS | 3-hit combo: FOV punched 70 → 66 and recovered each hit (`Presentation.Camera.HitstopFov = -4`, `Impacts.Hit.Hitstop = 0.05`); spark anchor appeared in `workspace.FX`. Server now sends `{ attacker, amount }` with `Hit` so the client knows who was involved and scales shake for heavy hits (`HeavyAmount`) |
| 2. `Block` / `Parry` / `GuardBreak` cues | PASS (handlers), live NOT ASSESSED | Blue guard sparks; white sparks + expanding ring; orange tumbling shards. All three handlers run without error against real characters. Arena dummies never attack, so the server-side triggers were not exercised live (Enemy v2 / second client) |
| 3. `Dodged`: after-image ghost | PASS (handler) | Ghost copies of visible parts (ForceField material) fade over `Dodged.Ghost = 0.35` s |
| 4. `BlackFlash` unchanged in look; banner reads Config | PASS | Moved into `Impacts`; banner formats `Config.Flicker.BlackFlashMult`. The direct-invoke test hit a nil banner only because the test VM's `Hud` copy was never `Init()`ed; the real client initialises Hud first |
| 5. `Bolt`: beam + muzzle flash at the hand + spark at the hit point | PASS (handler) | |
| 6. All tuning in `Presentation.Impacts` / `Presentation.Camera` | PASS | No new literals in `Impacts.lua` / `CameraShake.lua` besides geometry ratios |
| 7. Nothing persists (`#workspace.FX == 0` after idle) | PASS | 0 children 1 s after the combo and 2.5 s after the all-handlers test; peak was 2 |

Client Output: no warnings or errors from the game during the run.

## Screenshot
- `impacts-staged.jpg` — staged still: hit highlight on the dummy, spark particles, and the parry ring held mid-expansion.

**Sign-off**: pending project owner playtest.
