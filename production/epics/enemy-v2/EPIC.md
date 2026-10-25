# Epic: Enemy v2

> **Status**: Stories 001–002 implemented (owner playtest pending) · **Layer**: Feature · **Rigor**: standard
> **Brief item**: `design/game-brief.md` MVP 3, Build order 3 · **GDD**: `design/gdd/enemies.md` → "Planned (Enemy v2)"

## Overview
Replace the placeholder Raider (capsule rig, straight-line chase, instant hits) with enemies that are a
reading exercise: a standardized body with a visible weapon, a real windup the player can parry or dodge,
pathfinding, a leash, and three variants. Every acceptance criterion below traces to the GDD section.

## Governing ADRs
ADR-0001 (enemy attacks go through the same server combat path as players), ADR-0002 (all numbers in
`shared/Enemies.lua`), ADR-0004 (telegraphs come for free from `Combat.Swing` → client `SwingAnimator`).

## Stories
| # | Story | Type | Status |
|---|---|---|---|
| 001 | Enemy core: `Enemies.lua` data, standardized rig, `Combat.Swing` attacks, stun-aware state machine, pathfinding, leash/despawn, Grunt/Brute/Gunner | Logic + Integration | Implemented — smoke 32/32, live parry 2/2 and dodge 3/3 vs Grunt |
| 002 | Ambush placement: ground raycast, `PlayableArea` tag, weighted composition, ring shrink | Config/Data | Implemented — 3/3 and 2/2 groups placed in-bounds in the arena |
| 003 | Owner playtest: fight a Grunt by reading the windup; Brute hyperarmor; Gunner spacing | Visual/Feel | Pending |

## Definition of Done
GDD acceptance criteria 1–6 verified; smoke scenario passes with the enemy section; owner playtest sign-off.
