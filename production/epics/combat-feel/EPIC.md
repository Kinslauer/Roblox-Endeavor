# Epic: Combat Feel

> **Status**: In Progress
> **Layer**: Presentation (+ one Core touch: the `Swing` payload)
> **Rigor**: standard
> **Brief item**: `design/game-brief.md` MVP 1, Build order 1

## Overview

Combat is fully simulated on the server but almost invisible on the client. This epic makes
every combat beat *readable* and *felt* without any hand-made art: a weapon in the hand, a
windup you can see (with the flick-timing cue), a swing, impact sparks, hitstop, camera shake,
and a sound slot for every `CombatEvent`. All placeholders are procedural and every one has a
data slot so real animations, models and sounds replace them by editing one table.

Validation question (from the brief's "working" scenario): *Can a new player read a swing's
windup well enough to parry it, and press flick on cue well enough to land a Black Flash,
without being told the numbers?*

## Governing ADRs

| ADR | Status | What it binds here |
|---|---|---|
| ADR-0001 server-authoritative combat | Accepted | Presentation consumes `CombatEvent`; never changes outcome |
| ADR-0002 Config as single source of tuning | Accepted | No durations/colours/multipliers in client code; `Presentation.lua` + `Config` + `Weapons` |
| ADR-0003 Rojo module layout | Accepted | New client modules with `Init()`; `Main.client.lua` is the composition root |
| ADR-0004 presentation layer and asset slots | Accepted | Module split, slot schema, telegraph derived from server frame data |

## GDD Requirements

| Req | GDD | Section | Story |
|---|---|---|---|
| Windup telegraph lasts exactly `spec.Windup` | combat.md | Detailed Rules → Attacks | 002 |
| Flick cue peaks `Config.Flicker.Window` before impact | flicker.md | Detailed Rules → Timing | 002 |
| Parry window `Config.Combat.ParryWindow` is readable | combat.md | Formulas → Parry | 002 |
| Every `CombatEvent` kind has visible + audible feedback | combat.md | Current Presentation | 003, 005 |
| Successful dodge shows feedback (`Dodged` bug) | combat.md | Edge Cases | 003 |
| Weapon visible in hand, per `Weapons.Defs[id].Family` | weapons.md | Overview | 004 |
| Black Flash multiplier read from Config, not literal | flicker.md | Dependencies | 001 |

## Stories

| # | Story | Type | Est | Status |
|---|---|---|---|---|
| 001 | [Presentation slots + client module split](story-001-presentation-slots-and-module-split.md) | Integration | M | Implemented (sign-off pending) |
| 002 | [Readable swing: windup telegraph, flick cue, swing, recovery](story-002-swing-telegraph.md) | Visual/Feel | L | Implemented (sign-off pending) |
| 003 | [Impact feedback: sparks, hitstop, shake, parry/block/dodge cues](story-003-impact-feedback.md) | Visual/Feel | M | Ready |
| 004 | [Procedural weapon in hand](story-004-weapon-view.md) | Visual/Feel | M | Ready |
| 005 | [Audio slots](story-005-audio-slots.md) | Integration | S | Ready |

## Definition of Done

- Every story closed via `/story-done` with its acceptance criteria verified **in a Studio
  playtest** (screenshot retained under `production/qa/evidence/<story-slug>/`).
- `tools/smoke` scenario still passes (server contract unchanged except the documented
  `Swing` payload extension and `Weapon` attribute).
- Zero new literals for timing, colour or multipliers outside `Presentation.lua` / `Config.lua`.
- A playtest answers the validation question with a yes from the project owner.
