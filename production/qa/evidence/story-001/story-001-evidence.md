# Story 001 evidence — Presentation slots + client module split

**Date**: 2026-10-25 · **Build**: branch `claude/combat-feel`, Studio place `Conduit.rbxlx` (unpublished, API services off)
**Method**: Studio MCP: scripts pushed into the place, Play started, remotes fired from the Client datamodel, state read from the Server datamodel, screenshot captured.

| AC | Result | How verified |
|---|---|---|
| 1. `Presentation.lua` with Weapons/Swings/Impacts/Sounds/Camera, all IDs `""` | PASS | File review; module loads on client (CombatFX requires it without error) |
| 2. Client split into Hud / CombatFX / FlickerAura / Input; Main ≤ 40 lines | PASS | `PlayerScripts.Client` children: Main, Input, Hud, CombatFX, FlickerAura; Main is 13 lines |
| 3. Behaviour unchanged after split | PASS | HUD built (15 GUI children), three panels render, bars update (charge bar rose after hits), hotbar visible — see `hud-split-arena.jpg`. Events received on client during a scripted combo: `Swing=4 Hit=3 Dodge=1 DodgeMove=1 Feint=1`; no handler warnings; Output has no errors |
| 4. Black Flash multiplier read from Config | PASS | Loadout panel shows "Black Flash x2.5" computed from `Config.Flicker.BlackFlashMult`; banner format string uses the same value; `grep 2.5 src/client` → none |
| 5. `Dodged` produces visible feedback | PASS (by construction) | Handler is registered for every `Presentation.Impacts` kind with a `Flash`; `Dodged` has `Flash = 0.25`. Not exercised live: arena dummies do not attack. Re-check in story 002/Enemy v2 playtests |
| 6. `Weapon` attribute replicated | PASS | Client read `Character:GetAttribute("Weapon") == "PipeClub"` 4 s after spawn |
| 7. Smoke scenario | NOT ASSESSED | `luau` CLI not installed in the cloud workspace this session; assertion added to `tools/smoke/scenario.lua` |

**Sign-off**: pending project owner (`/story-done`).
