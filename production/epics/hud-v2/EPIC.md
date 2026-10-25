# Epic: HUD v2

> **Status**: Stories 001–002 implemented (owner playtest pending) · **Layer**: Feature · **Rigor**: standard
> **Brief item**: `design/game-brief.md` MVP 4, Build order 4 · **Spec**: this epic (the HUD is a UX spec, not a GDD — systems-index row 27)

## Overview
Make the HUD explain itself. The old HUD was three unlabelled bars and Roblox's default health bar; the
only numbers in the world were server-drawn billboards on the dev-arena dummies. Players could not tell
what a bar was, how much damage they did, whether a swing was blocked or parried, or where their attack
was going to go. HUD v2 adds labels and values, a custom health bar, client-drawn damage numbers and
outcome words on every target, a reticle with a hit marker, and a damage-taken flash — all driven by
the server's `CombatEvent`, so what the player reads is what was applied (ADR-0001).

## Governing ADRs
ADR-0001 (numbers come from the server; the client draws, never decides), ADR-0004 (every colour,
size and timing is a slot in `Presentation.Hud`; `Hud` / `HudCombat` are modules on the `CombatFX`
dispatcher, not code in `Main.client.lua`).

## Stories
| # | Story | Type | Status |
|---|---|---|---|
| 001 | Bars that say what they are: HEALTH / STAMINA / POSTURE / CHARGE labels with `value / max`, custom health bar bound to `Humanoid.HealthChanged`, Roblox health bar and PlayerList (Tab) hidden | UI | Implemented — live: 4 labels, values `100 / 100`, `0 / 80`…; health text tracked 100→85→75→62 |
| 002 | Combat overlay (`HudCombat`): damage numbers over the victim (`-N` red for you, big for heavy, re-tinted on Black Flash), BLOCKED / PARRIED / GUARD BREAK / DODGED words, aim reticle + hit marker, damage-taken edge flash; server dummy numbers removed | UI | Implemented — live: `12`, `25@34px`, `-10`, BLOCKED, PARRIED, DODGED all spawned and cleaned up; reticle blinked on own hit; flash 1.00→0.81 |
| 003 | Owner playtest: read a fight from the HUD alone (who hit whom for how much, what was blocked); reticle sits where swings land; flash is noticeable but not blinding; toggle Aim hides the reticle | Visual/Feel | Pending |

## Acceptance criteria
1. Every bar has a name and a `current / max` readout that updates on the same frame as the fill.
2. Health is drawn by us (core health bar off) and tracks `Humanoid.Health` exactly.
3. Every `Hit` event spawns a number over the victim's head on every client; the local victim sees `-N` in the Taken colour; amounts ≥ `HeavyAmount` use the heavy size/colour; a Black Flash re-tints the number red with `!`.
4. `Block` / `Parry` / `GuardBreak` / `Dodged` spawn their word in their own colour (so a successful dodge is visible — the brief's "dodge feedback bug").
5. The reticle is visible only while `Aim` is on, and blinks (colour + scale) when the local player's attack connects.
6. Taking damage flashes the screen edges, scaled by damage ÷ max health, never covering the bars (overlay is drawn under the HUD).
7. Numbers are capped (`MaxLive`) and every one destroys itself after `Life` seconds; no server-side billboards remain.
8. No key conflict: Tab opens the inventory with no PlayerList toggle.

## Definition of Done
Acceptance criteria 1–8 verified live or by construction; smoke still green; owner playtest sign-off.
