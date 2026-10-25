# Story 004 evidence — Procedural weapon in hand

**Date**: 2026-10-25 · **Build**: branch `claude/combat-feel`, Studio place `Conduit.rbxlx`
**Method**: Studio MCP. Play; `Weapon` attribute cycled through all seven ids on the local character; part counts and weld state read back; screenshots captured (poses held via the same Transform path SwingAnimator uses).

| AC | Result | Notes |
|---|---|---|
| 1. Every character with a `Weapon` attribute shows a weapon; 7 distinct silhouettes | PASS | Parts built per id: PipeClub=2, RebarBlade=3, ShockBaton=2, ScrapSpear=2, Sledge=2, ArcPistol=3, Fists=0. Screenshots: `club-at-rest.jpg`, `sledge-overhead.jpg`, `pistol-aimed.jpg` |
| 2. Updates immediately on attribute change; removed on respawn | PASS | Attribute changes rebuilt within 0.3 s; the model is parented under the character so it dies with it |
| 3. Welded to the hand with a per-weapon grip | PASS | `Handle` carries a `WeldConstraint` to `RightHand`; handle centre measured 2.00 studs from the hand for the club (`HandOffset` −0.3 + half length 1.7) |
| 4. `ModelName` slot clones a real asset, falls back with one `warn` | PASS (by construction) | Code path present; no `ReplicatedStorage.Assets.Weapons` exists yet to exercise it |
| 5. Cosmetic only: no collide/query/touch, massless, under the character | PASS | All builder parts set `CanCollide/CanQuery/CanTouch = false`, `Massless = true`; the server's hitbox excludes the whole character model |
| 6. Owner identifies each weapon from 20 studs | NOT ASSESSED | Owner playtest pending |

Tuning done during the test: the pistol first pointed at the ground when the arm was raised; its `Grip` is now `CFrame.Angles(-90°, 0, 0)` so the barrel runs along the arm (`pistol-aimed.jpg` shows the corrected grip).

**Sign-off**: pending project owner playtest.
