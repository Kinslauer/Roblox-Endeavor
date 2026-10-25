# Enemy v2 evidence — stories 001 + 002

**Date**: 2026-10-25 · **Build**: `claude/combat-feel` · **Method**: smoke harness (Luau CLI) + Studio MCP live run in the dev arena.

## GDD acceptance criteria (design/gdd/enemies.md → Planned)
| # | Criterion | Result | Evidence |
|---|---|---|---|
| 1 | Every enemy attack goes through `Combat.Swing`; damage only after `Windup` | PASS | Live: `Swing w=0.6 label=3` at t=0.4, `Hit` at t=1.0 (exactly +0.6); smoke: "no damage before the windup ends" |
| 2 | Block within 0.22 s before impact parries and stuns the enemy 1.1 s | PASS | Live reactive test: block at windup−0.12 → `Parry` 2/2, `grunt stunned 1.1s` each, 0 damage; smoke: "timed block parries the grunt", "parried grunt is stunned" |
| 3 | Dodge whose i-frames cover `Active` takes no damage | PASS (Grunt) | Live: dodge at windup−0.10 → `Dodged` 3/3, 0 damage. Brute/Gunner NOT ASSESSED live |
| 4 | Reaches players behind cover without sticking > 2 s | PASS (observed) | PathfindingService path following; one Grunt closed from 49 studs; stuck detection recomputes + jumps. Cover-specific test NOT ASSESSED |
| 5 | No out-of-bounds / embedded spawns | PASS | `FindGround` raycast onto `PlayableArea`-tagged arena floor; groups of 3 and 2 placed at 31–49 studs with the ring shrinking near the wall |
| 6 | Variants distinguishable at 20 studs | PASS (by construction) | Distinct body type / skin / hair / cloth tint and a different visible weapon per variant (club / sledge / pistol); owner confirmation pending |

Also observed: enemies **return home and idle** after a kill, re-engage on respawn, and the Gunner holds its band and fires (`Swing w=0.5`). A stunned/swinging enemy stands still (fixes the "attacks while frozen" bug).

## Testing notes
- Spawning enemies from the MCP VM needs a live `Script` that stays alive: destroying the bridge script kills the AI threads it spawned (the first run looked frozen for that reason).
- Smoke harness: 32/32 after adding `PathfindingService`, tag signals and `SetNetworkOwner` to the mock.

**Sign-off**: pending owner playtest (story 003).
