# District Blockout evidence — stories 001–003

**Date**: 2026-10-25 · **Build**: branch `claude/combat-feel`, Studio place `Conduit.rbxlx`
**Method**: Studio MCP. Patched Studio from the working tree (`tools/studio_patch.py`: Hud 2/2, HudCombat 1/1,
Arena 7/7, Combat 2/2, Main 2/2, NPCs 2/2, Config 2/2, Presentation 3/3; `District` ×2 written, byte-exact
14026 / 4040). Play; tutorial skipped via `TutorialSkip`; world opened after 7 s; checks read instances and
attributes from the Server and Client datamodels plus a server bridge `Script` for `Combat.Damage` /
`NPCs.Spawn` (see HUD v2 evidence for why a bridge is needed). Studio was not rendering (owner away), so
`screen_capture` timed out; no screenshot.

| AC | Result | Notes |
|---|---|---|
| 1. District at boot | PASS | `workspace.District` with **711** parts: Building 53, Windows 27, Sign 37, Rubble 6 (+6 walls, 24 debris), Pavement 24, Crate 34 / Barrier 37 / Wreck 32 / Dumpster 29, Lamp 164, PerimeterWall 4, SafeRing 48, Beacon, Plaza, SafeZone, SpawnPad 8; `PlaceholderCity` absent; `DistrictBloom` present, `ClockTime 23` |
| 2. Spawn pads on streets, outside the plaza | PASS | `CitySpawns=8 inPlaza=0 farthest=147`; after Emergence the player stood **2.8 studs** from a pad at (−20, 5, −117), `InSafeZone=false` |
| 3. Streets playable, plaza not | PASS | `PlayableArea` tags = 2 (district `Streets` + arena floor); the `Plaza` part carries no tag |
| 4. Safe zone refuses damage both ways | PASS | Player at (0, 6, 10), Grunt at (0, 5, 54): `Combat.Damage(grunt→player)=none`, `(player→grunt)=none`, hp 100→100; client saw `SAFE ZONE` words over **both** characters. Player moved to (0, 6, 60): `hit`, hp 90, `-10` number |
| 5. NPCs ignore players in the zone | PASS | Grunt with the player 44 studs away (inside its 60-stud aggro) moved 4.3 studs (settling) and never entered a windup in 2 s |
| 6. HUD indicator | PASS | Inside: label `SAFE ZONE  ·  Relay Plaza`, banner "You are safe here…"; after leaving: label cleared |
| 7. Arena behind Config.Dev, offset | PASS | `ArenaFloor` at (0, 2.3, 820); arena pads not tagged (`CitySpawn` total stays 8) |
| 8. Smoke | PASS | 41/41, 0 errors (6 new district checks; PvP positions moved to x=120 so they are outside the plaza) |

**Sign-off**: pending project owner playtest (story 004).
