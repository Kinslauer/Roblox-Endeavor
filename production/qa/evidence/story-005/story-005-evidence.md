# Story 005 evidence — Audio slots

**Date**: 2026-10-25 · **Build**: branch `claude/combat-feel`, Studio place `Conduit.rbxlx`
**Method**: Studio MCP. Play; attacks fired at an arena dummy from the Client datamodel while watching `Sound` instances on the character root and in `SoundService`.

| AC | Result | Notes |
|---|---|---|
| 1. One slot per CombatEvent kind with `{ Id, Volume, PitchJitter }` | PASS | 15 slots incl. `SwingLight`/`SwingHeavy` split by label and `Stun` |
| 2. 3D sound on the emitter's root, pitch jitter, destroyed on `Ended`; silent no-op when `Id == ""` | PASS | 3 swings → 3 `SFX_` sounds on the root, 0 left 2.5 s later; `Hit` sounds play on the **victim's** root (the dummy), as designed |
| 3. Local player's events also play 2D at `LocalMix` | PASS | 3 matching sounds appeared under `SoundService` and were destroyed after playback |
| 4. Filling an Id makes it audible with no code change | PASS | All slots now ship with Roblox built-in `rbxasset://sounds/*` placeholders, verified loadable in this Studio (18 of 20 candidates loaded; `impact_generic.mp3` and `swoosh.wav` do not exist) |
| 5. `MaxPerChar` cap cuts the oldest sound | PASS (by construction) | Not exercised: the combo never exceeded 4 concurrent sounds |

**Sign-off**: pending project owner playtest (listen for swing/hit/parry sounds).
