# Epic: Destruction & salvage (both worlds)

> **Status**: Designed, not started · **Layer**: Core (combat + world + economy) · **Rigor**: standard
> **GDD**: `design/gdd/destruction.md` (owner decisions locked 2026-10-26; reconciled §13)

## Overview
The environment becomes a weapon, a resource and a door. Destructible props break into pre-fractured chunks and
salvage; authored breach points open locked interiors (loudly); chunks can be grabbed (G) and thrown through the
normal combat hit path; one shared explosion function damages bodies and the world. The Conduit world resets on the
hourly dematerialization (`design/gdd/dematerialization.md`); the war world tears up a sector and rebuilds it after the hill moves on.

## Governing rules
| Rule | From |
|---|---|
| Server-authoritative breaks, chunks, salvage; client-only cosmetics | ADR-0001, GDD §6 |
| Fractures and stages are authored models swapped in; only terrain is cut at runtime | GDD §6 |
| Every tunable in `Config.Destruction` | ADR-0002, GDD §10 |
| Throws validated on the server (reach, velocity clamp, own hit detection) | GDD §6, roblox-security |

## Stories

| # | Story | Type | Est | Status | Blocked by |
|---|---|---|---|---|---|
| 001 | Break types on existing hits (`Break` field, family defaults) + `Destructible` props: health, swap to fractured model, salvage remains | Core | L | Not started | — |
| 002 | Materials (Glass, SheetMetal, Pipe, Battery, Powder) + recipes; Arc Cells as the arc reserve in both worlds (deploy kit, shipments, recruits) | Economy | M | Not started | — |
| 003 | Grab and throw on **G**, Light class, server validation; special moves to MMB only | Core | L | Not started | 001 |
| 004 | Parry deflect, Medium / Heavy classes, improvised melee from chunks | Core | M | Not started | 003 |
| 005 | Shared `Explosion` (falloff, LOS, `Explosive` resist), Pipe Grenade, Breaching Charge | Core | L | Not started | 001 |
| 006 | `Breachable` tiers, authored hole models, noise -> NPC barks, `breach` raid step | World | M | Not started | 005 |
| 007 | The cycle (`design/gdd/dematerialization.md`): hourly clock, warning / white-out FX, respawn draws for enemies, crews, contacts (2–4 spots each) and the trader, ground-loot clear; then destruction's reset hook | World | L | Not started | — |
| 008 | Performance budgets (loose chunks, cosmetic debris, bodies) + 20-player stress test | Infra | M | Not started | 001–006 |
| 009 | War world: structure stages, craters, body persistence, sector rebuild (sectors = hill points) | World | L | Not started | 005 |
| 010 | `GoreLevel` content pass (`Moderate` / `Restricted`) | Presentation | M | Not started | — |
| 011 | Cycle clues (`design/gdd/dematerialization.md` §5): contact cycle lines, Fragment items at anomaly spots with spawn rules, visual anomalies, `profile.Knowledge`, the ARCHIVE app; placeholder content | World / Narrative | L | Not started | 007; owner: knowledge across permadeath? |

## Acceptance
The GDD's §11 criteria, one or more per story; smoke checks for every server rule (break, salvage roll, throw clamp,
explosion falloff and LOS, breach tiers, reset), live Studio verification, then an owner playtest.
